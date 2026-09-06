"""MSB Setup Session prototype host with Manager Procedure review.

The prototype still performs no PostgreSQL or Google Drive writes. When a
read-only database source is configured it reuses the accepted shared
field-context / Procedure resolver. For local prototype validation only, when no
database source is configured, it may resolve one uniquely matching Stage or
Sub-stage folder beneath SETUP_DRIVE_ROOT by exact Stage key.

Manager review is intentionally different from production-crew presentation:
production crew sees only the published PDF, while an authorized Manager may
open the underlying Google Doc source for correction. If the source is changed,
the published PDF in Procedures/Setup must be regenerated/replaced before the
instruction is considered current.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from flask import Flask, Response, jsonify, request, send_file, send_from_directory

BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from FieldWiring.Application.field_context_repository import (  # noqa: E402
    ConfigError,
    FieldContextRepository,
    PostgresFieldContextRepository,
    SQLiteFieldContextRepository,
)
from Procedures.Application.procedure_context import (  # noqa: E402
    ProcedureContextError,
    resolve_stage_procedure,
)

APP_VERSION = "V0.0.4-prototype"
app = Flask(__name__)


class SetupInstructionError(RuntimeError):
    """Setup instruction review request could not be safely resolved."""


def _env_first(*names: str) -> str:
    for name in names:
        value = os.environ.get(name, "").strip()
        if value:
            return value
    return ""


def _snapshot_text() -> str:
    return _env_first("SETUP_DEV_SNAPSHOT", "PROCEDURE_DEV_SNAPSHOT")


def _dsn_text() -> str:
    return _env_first(
        "SETUP_DATABASE_DSN",
        "PROCEDURE_DATABASE_DSN",
        "FIELDWIRING_DATABASE_DSN",
    )


def _database_configured() -> bool:
    return bool(_snapshot_text() or _dsn_text())


def repository() -> FieldContextRepository:
    snapshot = _snapshot_text()
    if snapshot:
        return SQLiteFieldContextRepository(snapshot)

    dsn = _dsn_text()
    if dsn:
        return PostgresFieldContextRepository(dsn)

    raise ConfigError(
        "Configure SETUP_DATABASE_DSN (or existing PROCEDURE/FIELDWIRING DSN) "
        "for PostgreSQL, or SETUP_DEV_SNAPSHOT for explicit development snapshot mode."
    )


def drive_root() -> Path:
    root_text = _env_first(
        "SETUP_DRIVE_ROOT",
        "PROCEDURE_DRIVE_ROOT",
        "FIELDWIRING_DRIVE_ROOT",
    )
    if not root_text:
        raise ConfigError(
            "Configure SETUP_DRIVE_ROOT (or existing PROCEDURE/FIELDWIRING drive root) "
            "for the shared Display Folders filesystem."
        )
    root = Path(root_text)
    if not root.is_dir():
        raise ConfigError(f"Setup Display Folders root is not available: {root_text}")
    return root


def _stage_id_for_key(repo: FieldContextRepository, stage_key: str) -> int:
    wanted = (stage_key or "").strip().casefold()
    if not wanted:
        raise SetupInstructionError("Stage key is required.")

    matches: list[int] = []
    for item in repo.stages():
        stage = item.get("stage") or {}
        current_key = str(stage.get("stage_key") or "").strip().casefold()
        stage_id = stage.get("stage_id")
        if current_key == wanted and stage_id is not None:
            matches.append(int(stage_id))

    unique = sorted(set(matches))
    if len(unique) != 1:
        raise SetupInstructionError(
            f"Stage key {stage_key!r} did not resolve to one unique current Stage/Sub-stage."
        )
    return unique[0]


def _folder_stage_key(name: str) -> str | None:
    """Return a leading MSB Stage/Sub-stage key from a folder name."""
    match = re.match(r"^\s*(\d{2}[A-Za-z]?)\s*[-_]", name)
    if not match:
        return None
    return match.group(1).casefold()


def _local_stage_folder(stage_key: str) -> Path:
    """Prototype-only exact-key folder resolver when no DB source is configured.

    It checks direct children first, then one child level below them for
    Sub-stages. It never fuzzy-matches a Stage name and requires exactly one
    matching directory.
    """
    wanted = (stage_key or "").strip().casefold()
    if not wanted:
        raise SetupInstructionError("Stage key is required.")

    root = drive_root()
    direct: list[Path] = []
    try:
        root_children = [path for path in root.iterdir() if path.is_dir()]
    except OSError as exc:
        raise SetupInstructionError("Display Folders root could not be enumerated.") from exc

    for child in root_children:
        if _folder_stage_key(child.name) == wanted:
            direct.append(child)

    matches = direct
    if not matches and re.fullmatch(r"\d{2}[a-z]", wanted):
        nested: list[Path] = []
        for parent in root_children:
            try:
                children = [path for path in parent.iterdir() if path.is_dir()]
            except OSError:
                continue
            for child in children:
                if _folder_stage_key(child.name) == wanted:
                    nested.append(child)
        matches = nested

    unique: dict[str, Path] = {}
    for path in matches:
        try:
            key = str(path.resolve(strict=True)).casefold()
        except OSError:
            key = str(path.absolute()).casefold()
        unique[key] = path

    if len(unique) != 1:
        raise SetupInstructionError(
            f"Prototype Stage key {stage_key!r} resolved to {len(unique)} local folders; expected exactly one."
        )
    return next(iter(unique.values()))


def _google_doc_id_from_url(candidate: str) -> str | None:
    try:
        parsed = urlparse(candidate)
    except ValueError:
        return None
    if parsed.scheme != "https" or parsed.netloc.casefold() != "docs.google.com":
        return None

    match = re.match(r"^/document/d/([A-Za-z0-9_-]+)", parsed.path)
    if match:
        return match.group(1)

    query_id = (parse_qs(parsed.query).get("id") or [None])[0]
    if query_id and re.fullmatch(r"[A-Za-z0-9_-]{10,}", query_id):
        return query_id
    return None


def _google_doc_links(path: Path) -> tuple[str | None, str | None, str | None]:
    """Return (edit_url, pdf_export_url, doc_id) from a local .gdoc shortcut."""
    if path.suffix.casefold() != ".gdoc":
        return None, None, None
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")[:65536]
    except OSError:
        return None, None, None

    urls: list[str] = []
    ids: list[str] = []

    try:
        payload = json.loads(raw)

        def walk(value: Any, key_name: str = "") -> None:
            if isinstance(value, str):
                stripped = value.strip()
                if stripped.startswith("https://"):
                    urls.append(stripped)
                folded_key = key_name.casefold()
                if folded_key in {"doc_id", "document_id"} and re.fullmatch(
                    r"[A-Za-z0-9_-]{10,}", stripped
                ):
                    ids.append(stripped)
                if folded_key == "resource_id":
                    resource_match = re.search(r"(?:document:)?([A-Za-z0-9_-]{10,})$", stripped)
                    if resource_match:
                        ids.append(resource_match.group(1))
            elif isinstance(value, dict):
                for child_key, child_value in value.items():
                    walk(child_value, str(child_key))
            elif isinstance(value, list):
                for child_value in value:
                    walk(child_value, key_name)

        walk(payload)
    except (json.JSONDecodeError, TypeError):
        urls.extend(re.findall(r"https://[^\s\"']+", raw))

    for candidate in urls:
        doc_id = _google_doc_id_from_url(candidate)
        if doc_id:
            ids.insert(0, doc_id)
            break

    doc_id = next((item for item in ids if re.fullmatch(r"[A-Za-z0-9_-]{10,}", item)), None)
    if doc_id:
        return (
            f"https://docs.google.com/document/d/{doc_id}/edit",
            f"https://docs.google.com/document/d/{doc_id}/export?format=pdf",
            doc_id,
        )

    # A direct Google Docs URL is still useful to the Manager even if this
    # shortcut format does not expose an ID we recognize for PDF export.
    for candidate in urls:
        try:
            parsed = urlparse(candidate)
        except ValueError:
            continue
        if parsed.scheme == "https" and parsed.netloc.casefold() == "docs.google.com":
            return candidate, None, None

    return None, None, None


def _review_file_payload(path: Path, *, role: str) -> dict[str, Any]:
    try:
        size = path.stat().st_size
    except OSError:
        size = None
    edit_url, export_url, doc_id = _google_doc_links(path)
    return {
        "name": path.name,
        "path": str(path),
        "extension": path.suffix.casefold(),
        "size": size,
        "role": role,
        "editable_google_source": bool(edit_url),
        "edit_url": edit_url,
        "pdf_export_url": export_url,
        "google_doc_id": doc_id,
    }


def _direct_review_files(folder: Path, *, role: str) -> list[dict[str, Any]]:
    if not folder.is_dir():
        return []
    try:
        files = [path for path in folder.iterdir() if path.is_file()]
    except OSError:
        return []
    return [
        _review_file_payload(path, role=role)
        for path in sorted(files, key=lambda item: item.name.casefold())
    ]


def _published_pdf_payloads(task_root: Path, stage_key: str) -> list[dict[str, Any]]:
    if not task_root.is_dir():
        return []
    try:
        files = [
            path for path in task_root.iterdir()
            if path.is_file() and path.suffix.casefold() == ".pdf"
        ]
    except OSError:
        return []
    return [
        {
            "name": path.name,
            "path": str(path),
            "size": path.stat().st_size if path.exists() else None,
            "url": f"/api/setup-instructions/current?stage_key={stage_key}&name={path.name}",
        }
        for path in sorted(files, key=lambda item: item.name.casefold())
    ]


def _manager_rule() -> str:
    return (
        "Authorized Managers may open and edit the selected Google Doc source during verification. "
        "Archive/SourceDocs remain hidden from production-crew navigation. After any Google Doc "
        "edit, replace the published PDF in Procedures/Setup before marking the instruction verified."
    )


def _local_instruction_package(stage_key: str) -> dict[str, Any]:
    stage_folder = _local_stage_folder(stage_key)
    task_root = stage_folder / "Procedures" / "Setup"
    source_docs = _direct_review_files(task_root / "SourceDocs", role="SOURCEDOC")
    archive = _direct_review_files(task_root / "Archive", role="ARCHIVE")
    current_documents = _published_pdf_payloads(task_root, stage_key)
    editable_sources = [
        item for item in [*source_docs, *archive]
        if item.get("extension") == ".gdoc" and item.get("editable_google_source")
    ]
    status = "AVAILABLE" if current_documents else "NO_CURRENT_DOCUMENTS"
    if not task_root.is_dir():
        status = "TASK_UNAVAILABLE"

    return {
        "stage_key": stage_key,
        "stage_id": None,
        "status": status,
        "scope_type": "LOCAL_STAGE_PROTOTYPE",
        "resolution_mode": "local-drive-prototype",
        "stage_folder": str(stage_folder),
        "task_root": str(task_root),
        "current_documents": current_documents,
        "source_docs": source_docs,
        "archive": archive,
        "editable_sources": editable_sources,
        "manager_rule": _manager_rule(),
        "warnings": [
            "Local prototype exact-Stage-key folder fallback is active; production must use the shared field-context resolver."
        ],
    }


def _resolved_instruction_package(stage_key: str) -> dict[str, Any]:
    repo = repository()
    stage_id = _stage_id_for_key(repo, stage_key)
    procedure = resolve_stage_procedure(
        repo,
        stage_id=stage_id,
        task="Setup",
        drive_root=drive_root(),
        whole_stage=True,
    )

    task_root_text = str(procedure.get("task_root") or "").strip()
    task_root = Path(task_root_text) if task_root_text else None
    source_docs = (
        _direct_review_files(task_root / "SourceDocs", role="SOURCEDOC") if task_root else []
    )
    archive = _direct_review_files(task_root / "Archive", role="ARCHIVE") if task_root else []
    current_documents = [
        {
            "name": item.get("name"),
            "path": item.get("path"),
            "size": item.get("size"),
            "url": f"/api/setup-instructions/current?stage_key={stage_key}&name={item.get('name')}",
        }
        for item in (procedure.get("documents") or [])
        if item.get("name")
    ]
    editable_sources = [
        item for item in [*source_docs, *archive]
        if item.get("extension") == ".gdoc" and item.get("editable_google_source")
    ]

    return {
        "stage_key": stage_key,
        "stage_id": stage_id,
        "status": procedure.get("status"),
        "scope_type": procedure.get("scope_type"),
        "resolution_mode": "shared-field-context",
        "task_root": task_root_text or None,
        "current_documents": current_documents,
        "source_docs": source_docs,
        "archive": archive,
        "editable_sources": editable_sources,
        "manager_rule": _manager_rule(),
        "warnings": procedure.get("operator_warnings") or procedure.get("warnings") or [],
    }


def _instruction_package(stage_key: str) -> dict[str, Any]:
    if _database_configured():
        return _resolved_instruction_package(stage_key)
    return _local_instruction_package(stage_key)


def _current_document_path(stage_key: str, name: str) -> Path:
    if not name or "\x00" in name or Path(name).name != name:
        raise SetupInstructionError("Current Setup PDF name is invalid.")

    if not _database_configured():
        task_root = _local_stage_folder(stage_key) / "Procedures" / "Setup"
        candidate = task_root / name
        if candidate.suffix.casefold() != ".pdf" or not candidate.is_file():
            raise SetupInstructionError("Requested PDF is not a current published Setup document.")
        try:
            candidate.resolve(strict=True).relative_to(task_root.resolve(strict=True))
        except (OSError, ValueError) as exc:
            raise SetupInstructionError("Requested PDF is outside the resolved Setup folder.") from exc
        if candidate.parent.resolve(strict=True) != task_root.resolve(strict=True):
            raise SetupInstructionError("Requested PDF is not directly published in Procedures/Setup.")
        return candidate

    repo = repository()
    stage_id = _stage_id_for_key(repo, stage_key)
    procedure = resolve_stage_procedure(
        repo,
        stage_id=stage_id,
        task="Setup",
        drive_root=drive_root(),
        whole_stage=True,
    )
    task_root_text = str(procedure.get("task_root") or "").strip()
    if not task_root_text:
        raise SetupInstructionError("Current Setup task folder could not be resolved.")
    task_root = Path(task_root_text)

    matched = next(
        (item for item in (procedure.get("documents") or []) if item.get("name") == name),
        None,
    )
    if matched is None:
        raise SetupInstructionError("Requested PDF is not a current published Setup document.")

    candidate = Path(str(matched.get("path") or ""))
    if not candidate.is_file():
        raise SetupInstructionError("Requested current Setup PDF is unavailable.")
    try:
        candidate.resolve(strict=True).relative_to(task_root.resolve(strict=True))
    except (OSError, ValueError) as exc:
        raise SetupInstructionError("Requested PDF is outside the resolved Setup folder.") from exc
    if candidate.parent.resolve(strict=True) != task_root.resolve(strict=True):
        raise SetupInstructionError("Requested PDF is not directly published in Procedures/Setup.")
    return candidate


@app.get("/")
def index() -> Response:
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/<path:name>")
def static_file(name: str) -> Response:
    if name.startswith("api/"):
        raise SetupInstructionError("Unknown Setup API route.")
    return send_from_directory(BASE_DIR, name)


@app.get("/api/health")
def health() -> Response:
    if _snapshot_text():
        mode = "sqlite-dev"
    elif _dsn_text():
        mode = "postgres"
    else:
        mode = "local-drive-prototype"
    return jsonify(status="ok", version=APP_VERSION, data_mode=mode)


@app.get("/api/setup-instructions")
def setup_instructions() -> Response:
    stage_key = request.args.get("stage_key", "").strip()
    return jsonify(instructions=_instruction_package(stage_key))


@app.get("/api/setup-instructions/current")
def setup_current_document() -> Response:
    stage_key = request.args.get("stage_key", "").strip()
    name = request.args.get("name", "").strip()
    path = _current_document_path(stage_key, name)
    return send_file(
        path,
        conditional=True,
        max_age=60,
        as_attachment=False,
        download_name=path.name,
    )


@app.errorhandler(ConfigError)
def config_error(exc: ConfigError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Procedure review is not connected to the current document source.",
        engineering_error=str(exc),
    ), 503


@app.errorhandler(ProcedureContextError)
def procedure_error(exc: ProcedureContextError) -> tuple[Response, int]:
    return jsonify(error="Setup Procedure context could not be resolved.", engineering_error=str(exc)), 400


@app.errorhandler(SetupInstructionError)
def setup_instruction_error(exc: SetupInstructionError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 400


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8780")), debug=False)
