"""Read-only MSB Setup Session prototype host with Manager Procedure review.

The prototype still performs no PostgreSQL or Google Drive writes.  It reuses
accepted field-context / Procedure resolution to expose the current Setup PDFs
plus Manager-only SourceDocs / Archive source metadata.

Manager review is intentionally different from production-crew presentation:
Archive/SourceDocs remain hidden from the field Procedure application, while an
authorized future Manager UI may open an underlying Google Doc for correction.
If that source is changed, the published PDF in Procedures/Setup must be
regenerated/replaced before field publication is current again.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

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

APP_VERSION = "V0.0.3-prototype"
app = Flask(__name__)


class SetupInstructionError(RuntimeError):
    """Setup instruction review request could not be safely resolved."""


def _env_first(*names: str) -> str:
    for name in names:
        value = os.environ.get(name, "").strip()
        if value:
            return value
    return ""


def repository() -> FieldContextRepository:
    snapshot = _env_first("SETUP_DEV_SNAPSHOT", "PROCEDURE_DEV_SNAPSHOT")
    if snapshot:
        return SQLiteFieldContextRepository(snapshot)

    dsn = _env_first(
        "SETUP_DATABASE_DSN",
        "PROCEDURE_DATABASE_DSN",
        "FIELDWIRING_DATABASE_DSN",
    )
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


def _google_doc_links(path: Path) -> tuple[str | None, str | None]:
    """Return (edit_url, pdf_export_url) from a local .gdoc shortcut when safe.

    Google Drive desktop .gdoc files are small shortcut metadata files.  Their
    exact JSON shape is not treated as authority; we only accept a URL actually
    present in the file and only when it resolves to docs.google.com/document.
    """
    if path.suffix.casefold() != ".gdoc":
        return None, None
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")[:65536]
    except OSError:
        return None, None

    candidates: list[str] = []
    try:
        payload = json.loads(raw)

        def walk(value: Any) -> None:
            if isinstance(value, str):
                if value.startswith("https://"):
                    candidates.append(value)
            elif isinstance(value, dict):
                for item in value.values():
                    walk(item)
            elif isinstance(value, list):
                for item in value:
                    walk(item)

        walk(payload)
    except (json.JSONDecodeError, TypeError):
        candidates.extend(re.findall(r"https://[^\s\"']+", raw))

    for candidate in candidates:
        try:
            parsed = urlparse(candidate)
        except ValueError:
            continue
        if parsed.scheme != "https" or parsed.netloc.casefold() != "docs.google.com":
            continue
        match = re.match(r"^/document/d/([^/]+)", parsed.path)
        if not match:
            continue
        doc_id = match.group(1)
        edit_url = f"https://docs.google.com/document/d/{doc_id}/edit"
        export_url = f"https://docs.google.com/document/d/{doc_id}/export?format=pdf"
        return edit_url, export_url

    return None, None


def _direct_review_files(folder: Path, *, role: str) -> list[dict[str, Any]]:
    if not folder.is_dir():
        return []
    try:
        files = [path for path in folder.iterdir() if path.is_file()]
    except OSError:
        return []

    result: list[dict[str, Any]] = []
    for path in sorted(files, key=lambda item: item.name.casefold()):
        try:
            size = path.stat().st_size
        except OSError:
            size = None
        edit_url, export_url = _google_doc_links(path)
        result.append(
            {
                "name": path.name,
                "extension": path.suffix.casefold(),
                "size": size,
                "role": role,
                "editable_google_source": bool(edit_url),
                "edit_url": edit_url,
                "pdf_export_url": export_url,
            }
        )
    return result


def _instruction_package(stage_key: str) -> dict[str, Any]:
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
            "size": item.get("size"),
            "url": f"/api/setup-instructions/current?stage_key={stage_key}&name={item.get('name')}",
        }
        for item in (procedure.get("documents") or [])
        if item.get("name")
    ]

    editable_sources = [
        item for item in [*source_docs, *archive] if item.get("editable_google_source")
    ]

    return {
        "stage_key": stage_key,
        "stage_id": stage_id,
        "status": procedure.get("status"),
        "scope_type": procedure.get("scope_type"),
        "current_documents": current_documents,
        "source_docs": source_docs,
        "archive": archive,
        "editable_sources": editable_sources,
        "manager_rule": (
            "Authorized Managers may edit the chosen Google Doc source during verification. "
            "Archive remains excluded from production-crew navigation, but its .gdoc is not "
            "treated as immutable when the Manager intentionally uses it as the source. "
            "After any source edit, replace the published PDF in Procedures/Setup."
        ),
        "warnings": procedure.get("operator_warnings") or procedure.get("warnings") or [],
    }


def _current_document_path(stage_key: str, name: str) -> Path:
    if not name or "\x00" in name or Path(name).name != name:
        raise SetupInstructionError("Current Setup PDF name is invalid.")

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
    mode = "sqlite-dev" if _env_first("SETUP_DEV_SNAPSHOT", "PROCEDURE_DEV_SNAPSHOT") else "postgres"
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
        error="Setup Instruction review is not connected to the current database/document source.",
        engineering_error=str(exc),
    ), 503


@app.errorhandler(ProcedureContextError)
def procedure_error(exc: ProcedureContextError) -> tuple[Response, int]:
    return jsonify(error="Setup Instruction context could not be resolved.", engineering_error=str(exc)), 400


@app.errorhandler(SetupInstructionError)
def setup_instruction_error(exc: SetupInstructionError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 400


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8780")), debug=False)
