"""Read-only Procedure task adapter over the shared field-context resolver."""
from __future__ import annotations

from pathlib import Path, PureWindowsPath
from typing import Any

from FieldWiring.Application.field_context_operator_messages import operator_warning
from FieldWiring.Application.field_context_resolver import MARKER_NAME, resolve_structured_scope

TASK_FOLDERS = {
    "setup": "Setup",
    "takedown": "Takedown",
    "inspection": "Inspection",
}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def _direct_files(folder: Path, extensions: set[str]) -> list[dict[str, Any]]:
    try:
        files = [p for p in folder.iterdir() if p.is_file() and p.suffix.casefold() in extensions]
    except OSError:
        return []
    return [
        {"name": p.name, "path": str(p), "size": p.stat().st_size}
        for p in sorted(files, key=lambda item: item.name.casefold())
    ]


def _stage_fallback_warning(stage: dict[str, Any], scene: dict[str, Any] | None, task_name: str) -> str:
    stage_folder = str(stage.get("folder_path") or "").strip()
    scene_name = str((scene or {}).get("scene_name") or "").strip()
    if stage_folder and scene_name and scene_name.casefold() != "root":
        windows_stage = PureWindowsPath(stage_folder)
        expected = (
            windows_stage / scene_name / "Procedures" / task_name
            if windows_stage.drive
            else Path(stage_folder) / scene_name / "Procedures" / task_name
        )
        return f"No {task_name} procedure found in {expected}. Using the Stage-level {task_name} procedure instead."
    return f"No Scene-level {task_name} procedure found. Using the Stage-level {task_name} procedure instead."


def _diagnostic(stage: dict[str, Any], scene: dict[str, Any] | None, scope_root: Path | None, code: str) -> dict[str, Any]:
    return {
        "code": code,
        "stage_key": stage.get("stage_key"),
        "scene_name": (scene or {}).get("scene_name"),
        "scope_root": str(scope_root) if scope_root is not None else None,
        "database_folder_path": stage.get("folder_path"),
    }


def _task_operator_warning(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    scope_root: Path | None,
    task_name: str,
    code: str,
) -> str:
    return operator_warning(
        _diagnostic(stage, scene, scope_root, code),
        task=f"{task_name} procedure",
        task_relative_folder=fr"Procedures\{task_name}",
    )


def resolve_procedure_documents(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    preview: dict[str, Any],
    task: str,
    drive_root: Path,
) -> dict[str, Any]:
    task_key = (task or "").strip().casefold()
    if task_key not in TASK_FOLDERS:
        raise ValueError("Unsupported Procedure task. Expected Setup, Takedown, or Inspection.")

    task_name = TASK_FOLDERS[task_key]
    fallback_message = _stage_fallback_warning(stage, scene, task_name)
    scope_root, scope_type, warnings = resolve_structured_scope(
        stage,
        scene,
        preview,
        Path(drive_root),
        stage_fallback_warning=fallback_message,
    )
    warnings = list(warnings)
    operator_warnings: list[str] = []
    if fallback_message in warnings:
        operator_warnings.append(fallback_message)

    result: dict[str, Any] = {
        "status": "UNRESOLVED_SCOPE",
        "task": task_name,
        "scope_type": scope_type,
        "scope_root": str(scope_root) if scope_root is not None else None,
        "procedures_root": None,
        "task_root": None,
        "documents": [],
        "images": [],
        "warnings": warnings,
        "operator_warnings": operator_warnings,
    }

    if scope_root is None:
        operator_warnings.append(
            _task_operator_warning(stage, scene, None, task_name, "TASK_SCOPE_UNRESOLVED")
        )
        return result

    procedures_root = scope_root / "Procedures"
    result["procedures_root"] = str(procedures_root)
    task_root = procedures_root / task_name
    result["task_root"] = str(task_root)

    if not procedures_root.is_dir():
        result["status"] = "PROCEDURES_UNAVAILABLE"
        warnings.append(f"Procedure subsystem folder is missing: {procedures_root}")
        operator_warnings.append(
            _task_operator_warning(stage, scene, scope_root, task_name, "TASK_CONTENT_NOT_FOUND")
        )
        return result

    marker = procedures_root / MARKER_NAME
    if not marker.is_file():
        result["status"] = "PROCEDURES_UNAVAILABLE"
        warnings.append(f"Procedure subsystem marker is missing: {marker}")
        operator_warnings.append(
            _task_operator_warning(stage, scene, scope_root, task_name, "TASK_FOLDER_UNAPPROVED")
        )
        return result

    if not task_root.is_dir():
        result["status"] = "TASK_UNAVAILABLE"
        warnings.append(f"Procedure task folder is missing: {task_root}")
        operator_warnings.append(
            _task_operator_warning(stage, scene, scope_root, task_name, "TASK_CONTENT_NOT_FOUND")
        )
        return result

    documents = _direct_files(task_root, {".pdf"})
    images_root = task_root / "images"
    images = _direct_files(images_root, IMAGE_EXTENSIONS) if images_root.is_dir() else []

    result["documents"] = documents
    result["images"] = images
    result["status"] = "AVAILABLE" if documents else "NO_CURRENT_DOCUMENTS"
    if not documents:
        operator_warnings.append(
            _task_operator_warning(stage, scene, scope_root, task_name, "TASK_CONTENT_NOT_FOUND")
        )
    result["operator_warnings"] = list(dict.fromkeys(operator_warnings))
    return result
