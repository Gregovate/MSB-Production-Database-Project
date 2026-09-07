"""Google-native Setup Procedure discovery across Windows and Linux runtimes.

Windows Google Drive for Desktop exposes native Google Docs as ``.gdoc`` shortcut
files. The normal production rclone mount exports the same Google-native document
as ``.docx``, which is not enough by itself to distinguish it from a real Word
file.

Production therefore uses a second read-only, lazy rclone view configured with
``--drive-export-formats link.html``. Native Google Docs appear there as
``*.link.html`` while native Word files remain ordinary ``.docx`` files. The
Setup/FieldWiring runtime receives only filesystem read access to that link view;
it never receives the rclone OAuth configuration or token.

The older sanitized metadata-index reader remains as a compatibility/test helper,
but production discovery prefers the lazy link view and must not require a
recursive Drive scan at application startup.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

GOOGLE_DOC_CONTENT_TYPE = "application/vnd.google-apps.document"
GOOGLE_DOC_ID_RE = re.compile(r"^[A-Za-z0-9_-]{10,}$")
GOOGLE_DOC_URL_RE = re.compile(
    r"https://docs\.google\.com/document(?:/u/\d+)?/d/([A-Za-z0-9_-]+)(?:/[^\s\"'<>]*)?"
)


def _normalized_relative_task_root(task_root: str, drive_root: str) -> str | None:
    try:
        task = Path(task_root).resolve(strict=False)
        root = Path(drive_root).resolve(strict=False)
        relative = task.relative_to(root)
    except (OSError, ValueError):
        return None
    return relative.as_posix().strip("/")


def _virtual_gdoc_name(exported_name: str) -> str:
    folded = exported_name.casefold()
    if folded.endswith(".link.html"):
        base = exported_name[: -len(".link.html")]
    else:
        base = Path(exported_name).stem
    return f"{base}.gdoc"


def _google_doc_id_from_link_html(path: Path) -> str | None:
    if not path.name.casefold().endswith(".link.html"):
        return None
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")[:65536]
    except OSError:
        return None

    match = GOOGLE_DOC_URL_RE.search(raw)
    if match and GOOGLE_DOC_ID_RE.fullmatch(match.group(1)):
        return match.group(1)
    return None


def linked_google_sources(
    *,
    task_root: str,
    drive_root: str,
    link_root: str | None = None,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Return Google-native editable sources from the lazy rclone link view.

    Only direct children of ``Procedures/Setup/SourceDocs`` or ``Archive`` are
    eligible. A native ``.docx`` never qualifies because only Google-native Docs
    are exposed as ``.link.html`` in this view.
    """
    configured = (
        link_root
        if link_root is not None
        else os.environ.get("SETUP_GOOGLE_DOC_LINK_ROOT", "")
    ).strip()
    if not configured:
        return [], []

    relative_root = _normalized_relative_task_root(task_root, drive_root)
    if not relative_root:
        return [], [
            "Google Doc link view could not map the resolved Setup folder to Display Folders."
        ]

    root = Path(configured)
    if not root.is_dir():
        return [], ["Google Doc link view is unavailable."]

    linked_task_root = root / Path(relative_root)
    results: list[dict[str, Any]] = []
    warnings: list[str] = []

    for role, folder_name in (("SOURCEDOC", "SourceDocs"), ("ARCHIVE", "Archive")):
        folder = linked_task_root / folder_name
        if not folder.is_dir():
            continue
        try:
            files = [
                item
                for item in folder.iterdir()
                if item.is_file() and item.name.casefold().endswith(".link.html")
            ]
        except OSError as exc:
            warnings.append(f"Google Doc link view could not enumerate {folder_name}: {exc}")
            continue

        for path in sorted(files, key=lambda item: item.name.casefold()):
            doc_id = _google_doc_id_from_link_html(path)
            if not doc_id:
                warnings.append(
                    f"Google Doc link could not be parsed for {path.name}."
                )
                continue

            virtual_name = _virtual_gdoc_name(path.name)
            results.append(
                {
                    "name": virtual_name,
                    "path": str(path),
                    "drive_path": f"{relative_root}/{folder_name}/{path.name}",
                    "extension": ".gdoc",
                    "size": None,
                    "role": role,
                    "editable_google_source": True,
                    "edit_url": f"https://docs.google.com/document/d/{doc_id}/edit",
                    "pdf_export_url": f"https://docs.google.com/document/d/{doc_id}/export?format=pdf",
                    "google_doc_id": doc_id,
                    "source_backend": "rclone-link-view",
                }
            )

    return results, warnings


def _load_index(path: Path) -> list[dict[str, Any]]:
    raw = path.read_text(encoding="utf-8", errors="strict")
    payload = json.loads(raw.lstrip("\ufeff"))
    if isinstance(payload, dict):
        payload = payload.get("items")
    if not isinstance(payload, list):
        raise ValueError("Setup Google Doc index must contain a JSON list")
    return [item for item in payload if isinstance(item, dict)]


def indexed_google_sources(
    *,
    task_root: str,
    drive_root: str,
    index_path: str | None = None,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Compatibility reader for a prebuilt sanitized rclone metadata index."""
    configured = (
        index_path
        if index_path is not None
        else os.environ.get("SETUP_GOOGLE_DOC_INDEX", "")
    ).strip()
    if not configured:
        return [], []

    relative_root = _normalized_relative_task_root(task_root, drive_root)
    if not relative_root:
        return [], [
            "Google Doc metadata index could not map the resolved Setup folder to Display Folders."
        ]

    index_file = Path(configured)
    try:
        items = _load_index(index_file)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        return [], [f"Google Doc metadata index is unavailable: {exc}"]

    prefixes = {
        "SOURCEDOC": f"{relative_root}/SourceDocs/",
        "ARCHIVE": f"{relative_root}/Archive/",
    }
    results: list[dict[str, Any]] = []

    for item in items:
        metadata = item.get("Metadata") if isinstance(item.get("Metadata"), dict) else {}
        if str(metadata.get("content-type") or "").casefold() != GOOGLE_DOC_CONTENT_TYPE:
            continue

        remote_path = str(item.get("Path") or "").replace("\\", "/").strip("/")
        role = None
        direct_name = None
        for candidate_role, prefix in prefixes.items():
            if remote_path.startswith(prefix):
                remainder = remote_path[len(prefix):]
                if remainder and "/" not in remainder:
                    role = candidate_role
                    direct_name = remainder
                break
        if not role or not direct_name:
            continue

        doc_id = str(item.get("OrigID") or item.get("ID") or "").strip()
        if not GOOGLE_DOC_ID_RE.fullmatch(doc_id):
            continue

        virtual_name = _virtual_gdoc_name(direct_name)
        virtual_remote_path = remote_path.rsplit("/", 1)[0] + "/" + virtual_name
        results.append(
            {
                "name": virtual_name,
                "path": f"Google Drive:/{virtual_remote_path}",
                "drive_path": remote_path,
                "extension": ".gdoc",
                "size": None,
                "role": role,
                "editable_google_source": True,
                "edit_url": f"https://docs.google.com/document/d/{doc_id}/edit",
                "pdf_export_url": f"https://docs.google.com/document/d/{doc_id}/export?format=pdf",
                "google_doc_id": doc_id,
                "source_backend": "rclone-metadata-index",
            }
        )

    return results, []


def runtime_google_sources(
    *,
    task_root: str,
    drive_root: str,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Use the lazy link view when configured; otherwise use index compatibility."""
    if os.environ.get("SETUP_GOOGLE_DOC_LINK_ROOT", "").strip():
        return linked_google_sources(task_root=task_root, drive_root=drive_root)
    return indexed_google_sources(task_root=task_root, drive_root=drive_root)


def preferred_editable_sources(
    filesystem_sources: list[dict[str, Any]],
    runtime_sources: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Apply the accepted SourceDocs-first, Archive-fallback Manager rule."""
    candidates = [
        item
        for item in [*filesystem_sources, *runtime_sources]
        if item.get("extension") == ".gdoc" and item.get("edit_url")
    ]

    deduped: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for item in candidates:
        identity = str(item.get("google_doc_id") or "").strip()
        if identity:
            key = ("id", identity)
        else:
            key = (
                str(item.get("role") or "").upper(),
                str(item.get("name") or "").casefold(),
            )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)

    source_docs = [
        item
        for item in deduped
        if str(item.get("role") or "").upper() == "SOURCEDOC"
    ]
    if source_docs:
        return source_docs
    return [
        item
        for item in deduped
        if str(item.get("role") or "").upper() == "ARCHIVE"
    ]
