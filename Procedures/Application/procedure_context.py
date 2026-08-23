"""Procedure orchestration over the shared field-context database layer.

This module does not query PostgreSQL itself and does not resolve filesystem
Stage/Scene scope itself.  It consumes the production-accepted shared
``FieldContextRepository`` contract and passes one selected set of current
Stage/Scene/Preview facts to the accepted Procedure document adapter.

The shared database layer deliberately returns all current Scene/Preview
candidates.  Procedure orchestration must therefore avoid silently importing
FieldWiring's task-specific candidate preferences.  A single candidate may be
used directly; multiple candidates require an explicit browser/operator choice.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from FieldWiring.Application.field_context_repository import FieldContextRepository
from Procedures.Application.procedure_documents import (
    TASK_FOLDERS,
    resolve_procedure_documents,
)


class ProcedureContextError(RuntimeError):
    """Invalid or unavailable current field context for Procedure lookup."""


def _task_name(task: str) -> str:
    key = (task or "").strip().casefold()
    if key not in TASK_FOLDERS:
        raise ProcedureContextError(
            "Unsupported Procedure task. Expected Setup, Takedown, or Inspection."
        )
    return TASK_FOLDERS[key]


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


def _select_context(
    contexts: list[dict[str, Any]],
    *,
    preview_uuid: str | None,
    scene_uuid: str | None,
) -> tuple[dict[str, Any] | None, list[dict[str, Any]] | None]:
    """Select one shared candidate without making a task-neutral guess.

    Returns ``(selected, choices)``.  ``choices`` is non-None only when an
    explicit operator/browser choice is required.
    """
    requested_preview = (preview_uuid or "").strip() or None
    requested_scene = (scene_uuid or "").strip() or None

    if requested_preview is not None or requested_scene is not None:
        matches: list[dict[str, Any]] = []
        for context in contexts:
            preview = context.get("preview") or {}
            scene = context.get("scene") or {}
            if requested_preview is not None and str(preview.get("preview_uuid") or "") != requested_preview:
                continue
            if requested_scene is not None and str(scene.get("scene_uuid") or "") != requested_scene:
                continue
            matches.append(context)
        if len(matches) != 1:
            raise ProcedureContextError(
                "The requested Preview/Scene is not one unique current field context."
            )
        return matches[0], None

    if not contexts:
        return None, None
    if len(contexts) == 1:
        return contexts[0], None
    return None, [_context_summary(context) for context in contexts]


def _result_with_context(
    result: dict[str, Any],
    *,
    trigger: dict[str, Any],
    stage: dict[str, Any],
    selected_context: dict[str, Any] | None,
) -> dict[str, Any]:
    result = dict(result)
    result["trigger"] = trigger
    result["stage"] = dict(stage)
    result["selected_context"] = (
        _context_summary(selected_context) if selected_context is not None else None
    )
    return result


def resolve_display_procedure(
    repo: FieldContextRepository,
    *,
    display_id: int,
    task: str,
    drive_root: Path,
    preview_uuid: str | None = None,
    scene_uuid: str | None = None,
) -> dict[str, Any]:
    """Resolve one Procedure task from permanent Display identity.

    Inventory-only/non-wired Displays remain valid because eligibility comes
    from the shared field-context repository, not FieldWiring's repository.
    """
    task_name = _task_name(task)
    shared = repo.display_context(int(display_id))
    if shared is None:
        raise ProcedureContextError("Display is not available for current field context.")

    stage = shared.get("stage") or {}
    if stage.get("stage_id") is None:
        raise ProcedureContextError("Display has no current Stage relationship.")

    contexts = list(shared.get("contexts") or [])
    selected, choices = _select_context(
        contexts,
        preview_uuid=preview_uuid,
        scene_uuid=scene_uuid,
    )
    trigger = {
        "type": "DISPLAY",
        "display_id": shared.get("display_id"),
        "display_name": shared.get("display_name"),
    }

    if choices is not None:
        return {
            "status": "CONTEXT_SELECTION_REQUIRED",
            "task": task_name,
            "trigger": trigger,
            "stage": dict(stage),
            "contexts": choices,
            "documents": [],
            "images": [],
            "warnings": [],
        }

    preview = (selected or {}).get("preview") or {}
    scene = (selected or {}).get("scene")
    result = resolve_procedure_documents(
        stage,
        scene,
        preview,
        task_name,
        Path(drive_root),
    )
    return _result_with_context(
        result,
        trigger=trigger,
        stage=stage,
        selected_context=selected,
    )


def _stage_from_repository(
    repo: FieldContextRepository,
    stage_id: int,
) -> dict[str, Any]:
    for item in repo.stages():
        stage = item.get("stage") or {}
        if stage.get("stage_id") is not None and int(stage["stage_id"]) == int(stage_id):
            return item
    raise ProcedureContextError("Stage is not available for current field context.")


def resolve_stage_procedure(
    repo: FieldContextRepository,
    *,
    stage_id: int,
    task: str,
    drive_root: Path,
    whole_stage: bool = False,
    preview_uuid: str | None = None,
    scene_uuid: str | None = None,
) -> dict[str, Any]:
    """Resolve a Procedure task from controlled Stage/Scene browse selection."""
    task_name = _task_name(task)
    shared = _stage_from_repository(repo, int(stage_id))
    stage = shared.get("stage") or {}
    contexts = list(shared.get("contexts") or [])
    trigger = {
        "type": "STAGE_BROWSE",
        "stage_id": stage.get("stage_id"),
        "stage_key": stage.get("stage_key"),
        "stage_name": stage.get("stage_name"),
    }

    if whole_stage:
        selected = None
        choices = None
    else:
        selected, choices = _select_context(
            contexts,
            preview_uuid=preview_uuid,
            scene_uuid=scene_uuid,
        )
        if not contexts and selected is None:
            # A Stage with no current Scene/Preview rows can still be an
            # intentional Stage-level Procedure scope.
            selected = None
            choices = None

    if choices is not None:
        return {
            "status": "CONTEXT_SELECTION_REQUIRED",
            "task": task_name,
            "trigger": trigger,
            "stage": dict(stage),
            "contexts": choices,
            "documents": [],
            "images": [],
            "warnings": [],
        }

    preview = (selected or {}).get("preview") or {}
    scene = (selected or {}).get("scene")
    result = resolve_procedure_documents(
        stage,
        scene,
        preview,
        task_name,
        Path(drive_root),
    )
    return _result_with_context(
        result,
        trigger=trigger,
        stage=stage,
        selected_context=selected,
    )
