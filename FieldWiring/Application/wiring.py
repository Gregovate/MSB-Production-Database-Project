"""Read-only FieldWiring renderer package builder.

Connects the accepted browser context to the existing V7/PostgreSQL wiring
read model, accepted physical-presentation rules, and guarded Drive resolver.
"""
from __future__ import annotations

from typing import Any

from wiring_common import MARKER_NAME, WiringError, context_type, end_of_local_day, local_now
from wiring_data import load_wiring_data
from wiring_dmx_source import replace_legacy_dmx_rows
from wiring_dumbrgb import apply_dumbrgb_fixture_presentation
from wiring_e131 import apply_reviewed_e131_mapping
from wiring_images import resolve_images, safe_image_path
from wiring_presentation import apply_physical_presentation, group_rows

__all__ = ["MARKER_NAME", "WiringError", "build_wiring_package", "safe_image_path"]


def build_wiring_package(
    repo: Any,
    *,
    display_id: int | None = None,
    stage_id: int | None = None,
    preview_uuid: str | None = None,
    scene_uuid: str | None = None,
) -> dict[str, Any]:
    trigger_context: dict[str, Any] | None = None
    if display_id is not None:
        # New shared-context-aware repositories first prove that the permanent
        # Display itself is current/valid. FieldWiring eligibility is a separate
        # downstream decision. Older test doubles without the shared method keep
        # the established single-call behavior.
        shared_lookup = getattr(repo, "shared_display_context", None)
        shared_context = shared_lookup(display_id) if callable(shared_lookup) else None

        trigger_context = repo.display_context(display_id)
        if trigger_context is None:
            if shared_context is not None:
                raise WiringError("No applicable field wiring is available for this Display")
            raise WiringError("Display is not available for current FieldWiring")

        resolved_stage_id = trigger_context.get("stage_id")
        resolved_preview_uuid = trigger_context.get("preview_uuid")
        resolved_scene_uuid = trigger_context.get("scene_uuid")
        if stage_id is not None and resolved_stage_id is not None and int(stage_id) != int(resolved_stage_id):
            raise WiringError("Display does not belong to the requested Stage context")
        if preview_uuid and resolved_preview_uuid and str(preview_uuid) != str(resolved_preview_uuid):
            raise WiringError("Display does not belong to the requested Preview context")
        if scene_uuid and resolved_scene_uuid and str(scene_uuid) != str(resolved_scene_uuid):
            raise WiringError("Display does not belong to the requested Scene context")

        stage_id = resolved_stage_id
        preview_uuid = resolved_preview_uuid
        scene_uuid = resolved_scene_uuid

    if stage_id is None or not preview_uuid:
        raise WiringError("FieldWiring requires a resolved Stage and Preview context")

    raw = load_wiring_data(repo, str(preview_uuid), scene_uuid, int(stage_id))
    preview = raw["preview"]
    stage = raw["stage"]
    scene = raw["scene"]
    run = raw["run"]
    scene_name = (scene or {}).get("scene_name")
    scene_scope = bool(scene_name and scene_name.strip().casefold() != "root")

    source_rows = replace_legacy_dmx_rows(
        repo,
        raw["rows"],
        preview_uuid=str(preview_uuid),
        scene_uuid=scene_uuid,
        scene_scope=scene_scope,
        parser_version=run.get("parser_version"),
    )
    rows = apply_physical_presentation(source_rows, scene_name=scene_name)
    rows = apply_dumbrgb_fixture_presentation(rows)
    rows = apply_reviewed_e131_mapping(rows)
    if not rows:
        raise WiringError("No current field wiring rows were found for the resolved context")

    selected_context = context_type(preview.get("preview_name"))
    scope_kind = "Scene" if scene_scope else "Stage / Preview"
    images = resolve_images(stage, scene, preview, selected_context)

    now = local_now()
    expires = end_of_local_day(now)
    return {
        "context": {
            "display_id": display_id,
            "display_name": (trigger_context or {}).get("display_name"),
            "stage_id": stage.get("stage_id"),
            "stage_key": stage.get("stage_key"),
            "stage_name": stage.get("stage_name"),
            "preview_uuid": preview.get("preview_uuid"),
            "preview_name": preview.get("preview_name"),
            "preview_revision": preview.get("preview_revision"),
            "source_filename": preview.get("source_filename"),
            "scene_uuid": (scene or {}).get("scene_uuid"),
            "scene_name": scene_name,
            "scope_kind": scope_kind,
            "context_type": selected_context,
        },
        "provenance": {
            "import_run_id": run.get("import_run_id"),
            "parser_version": run.get("parser_version"),
            "parser_completed_at": run.get("parser_completed_at"),
            "source_preview_folder": run.get("source_preview_folder"),
            "ingest_script_version": run.get("ingest_script_version"),
            "ingest_completed_at": run.get("ingest_completed_at"),
            "generated_at": now.isoformat(timespec="seconds"),
            "expires_at": expires.isoformat(timespec="seconds"),
            "expiration_rule": "End of local calendar day generated; a newer approved wiring snapshot supersedes this copy immediately.",
        },
        "images": images,
        "controller_groups": group_rows(rows),
        "rows": rows,
    }
