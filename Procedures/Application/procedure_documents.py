"""Read-only Procedure task adapter over the shared field-context resolver.

This module is the Procedure subsystem's second caller of the canonical
Stage/Sub-stage/Scene resolver.  It does not resolve field context itself.

After ``resolve_structured_scope`` returns one fixed marked structured root,
this adapter validates the marked ``Procedures`` subsystem root, selects one
fixed task child, and discovers only directly published current content.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from FieldWiring.Application.field_context_resolver import (
    MARKER_NAME,
    resolve_structured_scope,
)

TASK_FOLDERS = {
    "setup": "Setup",
    "takedown": "Takedown",
    "inspection": "Inspection",
}

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def _direct_files(folder: Path, extensions: set[str]) -> list[dict[str, Any]]:
    """Return deterministic metadata for allowed direct child files only."""
    try:
        files = [
            path
            for path in folder.iterdir()
            if path.is_file() and path.suffix.casefold() in extensions
        ]
    except OSError:
        return []

    return [
        {
            "name": path.name,
            "path": str(path),
            "size": path.stat().st_size,
        }
        for path in sorted(files, key=lambda item: item.name.casefold())
    ]


def resolve_procedure_documents(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    preview: dict[str, Any],
    task: str,
    drive_root: Path,
) -> dict[str, Any]:
    """Resolve current published Procedure content for one fixed task.

    The shared resolver owns Stage/Sub-stage/Scene resolution.  This adapter
    owns only the marked ``Procedures`` subsystem root and the three fixed task
    branches.  Task folders and their ``images`` children are not separately
    marked; the marker on ``Procedures`` guards those controlled child names.

    Current Procedure PDFs are discovered only as direct files in the selected
    task folder.  There is no recursion or parent/sibling fallback, so
    ``Archive`` and ``SourceDocs`` content cannot become current documents.
    """
    task_key = (task or "").strip().casefold()
    if task_key not in TASK_FOLDERS:
        raise ValueError(
            "Unsupported Procedure task. Expected Setup, Takedown, or Inspection."
        )

    scope_root, scope_type, warnings = resolve_structured_scope(
        stage,
        scene,
        preview,
        Path(drive_root),
    )
    warnings = list(warnings)

    result: dict[str, Any] = {
        "status": "UNRESOLVED_SCOPE",
        "task": TASK_FOLDERS[task_key],
        "scope_type": scope_type,
        "scope_root": str(scope_root) if scope_root is not None else None,
        "procedures_root": None,
        "task_root": None,
        "documents": [],
        "images": [],
        "warnings": warnings,
    }

    if scope_root is None:
        return result

    procedures_root = scope_root / "Procedures"
    result["procedures_root"] = str(procedures_root)

    if not procedures_root.is_dir():
        result["status"] = "PROCEDURES_UNAVAILABLE"
        warnings.append(f"Procedure subsystem folder is missing: {procedures_root}")
        return result

    marker = procedures_root / MARKER_NAME
    if not marker.is_file():
        result["status"] = "PROCEDURES_UNAVAILABLE"
        warnings.append(f"Procedure subsystem marker is missing: {marker}")
        return result

    task_root = procedures_root / TASK_FOLDERS[task_key]
    result["task_root"] = str(task_root)
    if not task_root.is_dir():
        result["status"] = "TASK_UNAVAILABLE"
        warnings.append(f"Procedure task folder is missing: {task_root}")
        return result

    documents = _direct_files(task_root, {".pdf"})

    images_root = task_root / "images"
    images = _direct_files(images_root, IMAGE_EXTENSIONS) if images_root.is_dir() else []

    result["documents"] = documents
    result["images"] = images
    result["status"] = "AVAILABLE" if documents else "NO_CURRENT_DOCUMENTS"
    return result
