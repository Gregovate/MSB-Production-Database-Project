"""Guarded same-scope FieldWiring image resolver."""
from __future__ import annotations

import os
import re
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Any

from field_context_operator_messages import operator_warning
from field_context_resolver import resolve_structured_scope
from wiring_common import DEFAULT_DRIVE_ROOT, IMAGE_EXTENSIONS, MARKER_NAME, WiringError


FIELDWIRING_DIRECT_OWNER_WARNING = (
    "BackgroundFile points directly into the current Stage Wiring branch; "
    "the marked Stage root is the FieldWiring documentation scope."
)
FIELDWIRING_STAGE_FALLBACK_WARNING = (
    "No distinct Scene folder matched the current Scene identity; "
    "known marked Stage root retained as the FieldWiring scope."
)


def _direct_images(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    try:
        return sorted(
            [p for p in folder.iterdir() if p.is_file() and p.suffix.casefold() in IMAGE_EXTENSIONS],
            key=lambda p: p.name.casefold(),
        )
    except OSError:
        return []


def _image_payload(path: Path, drive_root: Path, kind: str) -> dict[str, Any]:
    relative = path.relative_to(drive_root)
    return {
        "name": path.name,
        "kind": kind,
        "relative_path": relative.as_posix(),
        "url": "api/wiring/image?path=" + relative.as_posix().replace(" ", "%20"),
    }


def _join_path_text(base: str, child: str) -> str:
    if "\\" in base or re.match(r"^[A-Za-z]:", base):
        return str(PureWindowsPath(base, child))
    if base.startswith("/"):
        return str(PurePosixPath(base, child))
    return base.rstrip("\\/") + "\\" + child


def _unresolved_expected_scope(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
) -> str | None:
    """Construct an expected scope path from already-known text only."""
    base = str(stage.get("folder_path") or "").strip()
    if not base:
        return None
    scene_name = str((scene or {}).get("scene_name") or "").strip()
    stage_key = str(stage.get("stage_key") or "").strip()
    if (
        scene_name
        and scene_name.casefold() != "root"
        and stage_key
        and scene_name.casefold().startswith(stage_key.casefold() + "-")
    ):
        return _join_path_text(base, scene_name)
    return base


def _diagnostic(
    code: str,
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    *,
    scope_root: str | Path | None,
) -> dict[str, Any]:
    return {
        "code": code,
        "stage_key": stage.get("stage_key"),
        "scene_name": (scene or {}).get("scene_name"),
        "scope_root": str(scope_root) if scope_root is not None else None,
        "database_folder_path": stage.get("folder_path"),
    }


def resolve_images(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    preview: dict[str, Any],
    selected_context: str,
) -> dict[str, Any]:
    # FieldWiring already owns this branch choice. Operator-message formatting
    # receives the same value and performs no additional lookup or resolution.
    branch = "MusicalStage" if selected_context == "Musical" else "BackgroundStage"
    task_relative_folder = f"Wiring\\{branch}"

    root_text = os.environ.get("FIELDWIRING_DRIVE_ROOT", DEFAULT_DRIVE_ROOT).strip()
    drive_root = Path(root_text)
    if not drive_root.is_dir():
        diagnostic = _diagnostic(
            "TASK_SCOPE_UNRESOLVED",
            stage,
            scene,
            scope_root=_unresolved_expected_scope(stage, scene),
        )
        return {
            "scope_type": "UNAVAILABLE",
            "scope_root": None,
            "wiring_images": [],
            "context_images": [],
            "warnings": [f"Display Folders root is not available on this server: {root_text}"],
            "operator_warnings": [
                operator_warning(
                    diagnostic,
                    task="Wiring",
                    task_relative_folder=task_relative_folder,
                )
            ],
        }

    windows_root = (
        os.environ.get("FIELDWIRING_WINDOWS_DRIVE_ROOT", DEFAULT_DRIVE_ROOT).strip()
        or DEFAULT_DRIVE_ROOT
    )
    scope_root, scope_type, warnings = resolve_structured_scope(
        stage,
        scene,
        preview,
        drive_root,
        windows_drive_root=windows_root,
        direct_owner_folder_name="Wiring",
        direct_owner_warning=FIELDWIRING_DIRECT_OWNER_WARNING,
        stage_fallback_warning=FIELDWIRING_STAGE_FALLBACK_WARNING,
    )
    if scope_root is None:
        diagnostic = _diagnostic(
            "TASK_SCOPE_UNRESOLVED",
            stage,
            scene,
            scope_root=_unresolved_expected_scope(stage, scene),
        )
        return {
            "scope_type": scope_type,
            "scope_root": None,
            "wiring_images": [],
            "context_images": [],
            "warnings": warnings,
            "operator_warnings": [
                operator_warning(
                    diagnostic,
                    task="Wiring",
                    task_relative_folder=task_relative_folder,
                )
            ],
        }

    # Everything below this point is intentionally FieldWiring-specific. The
    # shared resolver has already fixed the Stage/Scene root; this adapter now
    # selects only the applicable Wiring branch and supplemental context images.
    wiring_folder = scope_root / "Wiring" / branch
    wiring_images: list[Path] = []
    operator_warnings: list[str] = []
    if (wiring_folder.parent / MARKER_NAME).is_file():
        wiring_images = _direct_images(wiring_folder)
    elif wiring_folder.exists():
        warnings.append(f"Unmarked Wiring source excluded: {wiring_folder}")
        operator_warnings.append(
            operator_warning(
                _diagnostic("TASK_FOLDER_UNAPPROVED", stage, scene, scope_root=scope_root),
                task="Wiring",
                task_relative_folder=task_relative_folder,
            )
        )

    if not wiring_images and not operator_warnings:
        operator_warnings.append(
            operator_warning(
                _diagnostic("TASK_CONTENT_NOT_FOUND", stage, scene, scope_root=scope_root),
                task="Wiring",
                task_relative_folder=task_relative_folder,
            )
        )

    context_folder = scope_root / "PreviewBackground"
    context_images: list[Path] = []
    if (context_folder / MARKER_NAME).is_file():
        context_images = _direct_images(context_folder)
    elif context_folder.exists():
        warnings.append(f"Unmarked PreviewBackground source excluded: {context_folder}")

    return {
        "scope_type": scope_type,
        "scope_root": str(scope_root),
        "wiring_images": [_image_payload(p, drive_root, "wiring") for p in wiring_images],
        "context_images": [_image_payload(p, drive_root, "context") for p in context_images],
        "warnings": warnings,
        "operator_warnings": operator_warnings,
    }


def safe_image_path(relative_path: str) -> Path:
    if not relative_path or "\x00" in relative_path:
        raise WiringError("Invalid image path")
    parts = [part for part in PureWindowsPath(relative_path).parts if part not in {"\\", "/"}]
    if any(part in {"..", "."} for part in parts):
        raise WiringError("Invalid image path")
    if any(part.casefold() == "sourcedocs" for part in parts):
        raise WiringError("SourceDocs content is not a FieldWiring application source")
    drive_root = Path(os.environ.get("FIELDWIRING_DRIVE_ROOT", DEFAULT_DRIVE_ROOT).strip())
    candidate = drive_root.joinpath(*parts)
    if candidate.suffix.casefold() not in IMAGE_EXTENSIONS or not candidate.is_file():
        raise WiringError("Wiring image is not available")
    try:
        candidate.relative_to(drive_root)
    except ValueError as exc:
        raise WiringError("Invalid image path") from exc
    return candidate
