"""Read-only MSB Procedure browser API.

This backend is intentionally thin.  It consumes the production-accepted
shared Field Context database repository plus the accepted Procedure
orchestration/document adapters.  It does not contain PostgreSQL relationship
SQL, Stage/Scene filesystem resolution, or task-folder discovery rules.

File-serving endpoints never accept a filesystem path.  They re-resolve the
current Procedure package and may serve only a filename rediscovered in the
current direct document/image result.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any

from flask import Flask, Response, jsonify, request, send_file

_FIELDWIRING_APPLICATION = Path(__file__).resolve().parents[2] / "FieldWiring" / "Application"
if str(_FIELDWIRING_APPLICATION) not in sys.path:
    sys.path.insert(0, str(_FIELDWIRING_APPLICATION))

from field_context_hierarchy import FieldHierarchyError, resolve_field_hierarchy
from FieldWiring.Application.field_context_repository import (
    ConfigError,
    FieldContextRepository,
    PostgresFieldContextRepository,
    SQLiteFieldContextRepository,
)
from Procedures.Application.procedure_context import (
    ProcedureContextError,
    resolve_display_procedure,
    resolve_stage_procedure,
)

APP_VERSION = "V0.1.0"
app = Flask(__name__)


class ProcedureAssetError(RuntimeError):
    """Requested current Procedure document/image is not available."""


def repository() -> FieldContextRepository:
    dev_snapshot = os.environ.get("PROCEDURE_DEV_SNAPSHOT", "").strip()
    if dev_snapshot:
        return SQLiteFieldContextRepository(dev_snapshot)

    dsn = os.environ.get("PROCEDURE_DATABASE_DSN", "").strip()
    if dsn:
        return PostgresFieldContextRepository(dsn)

    raise ConfigError(
        "Configure PROCEDURE_DATABASE_DSN for PostgreSQL or "
        "PROCEDURE_DEV_SNAPSHOT for explicit read-only development mode"
    )


def drive_root() -> Path:
    root_text = os.environ.get("PROCEDURE_DRIVE_ROOT", "").strip()
    if not root_text:
        raise ConfigError("Configure PROCEDURE_DRIVE_ROOT for the shared Display Folders filesystem")
    root = Path(root_text)
    if not root.is_dir():
        raise ConfigError(f"Procedure Display Folders root is not available: {root_text}")
    return root


def _optional_int(name: str) -> int | None:
    raw = request.args.get(name, "").strip()
    if not raw:
        return None
    if not raw.isdigit():
        raise ProcedureContextError(f"Invalid {name}")
    return int(raw)


def _optional_bool(name: str) -> bool:
    raw = request.args.get(name, "").strip().casefold()
    if not raw:
        return False
    if raw in {"1", "true", "yes", "on"}:
        return True
    if raw in {"0", "false", "no", "off"}:
        return False
    raise ProcedureContextError(f"Invalid {name}")


def _context_summary(context: dict[str, Any]) -> dict[str, Any]:
    preview = context.get("preview") or {}
    scene = context.get("scene") or {}
    return {
        "preview_uuid": preview.get("preview_uuid"),
        "preview_name": preview.get("preview_name"),
        "scene_uuid": scene.get("scene_uuid"),
        "scene_name": scene.get("scene_name"),
        "scope_kind": context.get("scope_kind"),
        "context_type": context.get("context_type"),
    }


def _public_hierarchy_node(node: dict[str, Any]) -> dict[str, Any]:
    result = {
        "scope_type": node.get("scope_type"),
        "label": node.get("label"),
        "stage_id": node.get("stage_id"),
        "stage_key": node.get("stage_key"),
        "scenes": [
            {
                "scope_type": scene.get("scope_type"),
                "label": scene.get("label"),
                "stage_id": scene.get("stage_id"),
                "stage_key": scene.get("stage_key"),
                "contexts": [
                    _context_summary(context)
                    for context in list(scene.get("contexts") or [])
                ],
            }
            for scene in list(node.get("scenes") or [])
        ],
    }
    if node.get("scope_type") == "STAGE":
        result["sub_stages"] = [
            _public_hierarchy_node(sub_stage)
            for sub_stage in list(node.get("sub_stages") or [])
        ]
    return result


def _hierarchy_scope_by_stage_id(
    hierarchy: dict[str, Any],
    stage_id: int,
) -> dict[str, Any] | None:
    for stage in hierarchy.get("stages") or []:
        if stage.get("stage_id") is not None and int(stage["stage_id"]) == int(stage_id):
            return stage
        for sub_stage in stage.get("sub_stages") or []:
            if sub_stage.get("stage_id") is not None and int(sub_stage["stage_id"]) == int(stage_id):
                return sub_stage
    return None


def _hierarchy_scene_context_is_valid(
    scope: dict[str, Any],
    *,
    preview_uuid: str | None,
    scene_uuid: str | None,
) -> bool:
    requested_preview = (preview_uuid or "").strip() or None
    requested_scene = (scene_uuid or "").strip() or None
    if requested_preview is None and requested_scene is None:
        return False

    matches = 0
    for scene in scope.get("scenes") or []:
        for context in scene.get("contexts") or []:
            preview = context.get("preview") or {}
            scene_data = context.get("scene") or {}
            if requested_preview is not None and str(preview.get("preview_uuid") or "") != requested_preview:
                continue
            if requested_scene is not None and str(scene_data.get("scene_uuid") or "") != requested_scene:
                continue
            matches += 1
    return matches == 1


def _procedure_result() -> dict[str, Any]:
    display_id = _optional_int("display_id")
    stage_id = _optional_int("stage_id")
    if (display_id is None) == (stage_id is None):
        raise ProcedureContextError(
            "Procedure lookup requires exactly one of display_id or stage_id."
        )

    task = request.args.get("task", "").strip()
    preview_uuid = request.args.get("preview_uuid", "").strip() or None
    scene_uuid = request.args.get("scene_uuid", "").strip() or None
    whole_stage = _optional_bool("whole_stage")
    repo = repository()
    root = drive_root()

    if display_id is not None:
        if whole_stage:
            raise ProcedureContextError("whole_stage is valid only for Stage browse.")
        return resolve_display_procedure(
            repo,
            display_id=display_id,
            task=task,
            drive_root=root,
            preview_uuid=preview_uuid,
            scene_uuid=scene_uuid,
        )

    hierarchy = resolve_field_hierarchy(repo, root)
    scope = _hierarchy_scope_by_stage_id(hierarchy, int(stage_id))
    if scope is None:
        raise ProcedureContextError(
            "Stage/Sub-stage is not available in the current field hierarchy."
        )

    if whole_stage:
        if preview_uuid is not None or scene_uuid is not None:
            raise ProcedureContextError(
                "Whole Stage/Sub-stage browse cannot include a Scene selection."
            )
    elif not _hierarchy_scene_context_is_valid(
        scope,
        preview_uuid=preview_uuid,
        scene_uuid=scene_uuid,
    ):
        raise ProcedureContextError(
            "The requested Scene is not a current defined field Scene under this Stage/Sub-stage."
        )

    return resolve_stage_procedure(
        repo,
        stage_id=int(stage_id),
        task=task,
        drive_root=root,
        whole_stage=whole_stage,
        preview_uuid=preview_uuid,
        scene_uuid=scene_uuid,
        resolved_scope_root=Path(str(scope["scope_root"])),
    )


def _resolved_asset(kind: str) -> Path:
    name = request.args.get("name", "")
    if not name or "\x00" in name:
        raise ProcedureAssetError("Current Procedure file name is required.")

    result = _procedure_result()
    if result.get("status") != "AVAILABLE":
        raise ProcedureAssetError("Current Procedure content is not available for this context.")

    if kind == "document":
        items = result.get("documents") or []
        expected_root_text = result.get("task_root")
    elif kind == "image":
        items = result.get("images") or []
        task_root_text = result.get("task_root")
        expected_root_text = str(Path(task_root_text) / "images") if task_root_text else None
    else:  # internal programming error, not user input
        raise RuntimeError("Unknown Procedure asset kind")

    matched = next((item for item in items if item.get("name") == name), None)
    if matched is None:
        raise ProcedureAssetError("Requested file is not a current Procedure asset.")

    candidate = Path(str(matched.get("path") or ""))
    if not candidate.is_file() or not expected_root_text:
        raise ProcedureAssetError("Requested file is not a current Procedure asset.")

    expected_root = Path(expected_root_text)
    try:
        candidate.resolve(strict=True).relative_to(expected_root.resolve(strict=True))
    except (OSError, ValueError) as exc:
        raise ProcedureAssetError("Requested file is outside the current Procedure source root.") from exc

    if candidate.parent.resolve(strict=True) != expected_root.resolve(strict=True):
        raise ProcedureAssetError("Requested file is not a direct current Procedure asset.")

    return candidate


@app.get("/api/health")
def health() -> Response:
    mode = "sqlite-dev" if os.environ.get("PROCEDURE_DEV_SNAPSHOT") else "postgres"
    return jsonify(status="ok", version=APP_VERSION, data_mode=mode)


@app.get("/api/displays")
def api_displays() -> Response:
    query = request.args.get("q", "")
    return jsonify(displays=repository().search_displays(query))


@app.get("/api/displays/<int:display_id>/context")
def api_display_context(display_id: int) -> tuple[Response, int] | Response:
    context = repository().display_context(display_id)
    if context is None:
        return jsonify(error="Display is not available for current field context"), 404
    return jsonify(context=context)


@app.get("/api/stages")
def api_stages() -> Response:
    hierarchy = resolve_field_hierarchy(repository(), drive_root())
    return jsonify(
        stages=[
            _public_hierarchy_node(stage)
            for stage in hierarchy.get("stages") or []
        ]
    )


@app.get("/api/procedures")
def api_procedures() -> Response:
    return jsonify(procedure=_procedure_result())


@app.get("/api/procedure/document")
def api_procedure_document() -> Response:
    path = _resolved_asset("document")
    return send_file(
        path,
        conditional=True,
        max_age=60,
        as_attachment=False,
        download_name=path.name,
    )


@app.get("/api/procedure/image")
def api_procedure_image() -> Response:
    path = _resolved_asset("image")
    return send_file(
        path,
        conditional=True,
        max_age=60,
        as_attachment=False,
        download_name=path.name,
    )


@app.errorhandler(ConfigError)
def config_error(exc: ConfigError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), 503


@app.errorhandler(FieldHierarchyError)
def hierarchy_error(exc: FieldHierarchyError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), 503


@app.errorhandler(ProcedureContextError)
def procedure_context_error(exc: ProcedureContextError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), 400


@app.errorhandler(ProcedureAssetError)
def procedure_asset_error(exc: ProcedureAssetError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), 404


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8792")), debug=False)
