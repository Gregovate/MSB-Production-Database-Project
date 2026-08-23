"""Fast shared Stage/Sub-stage/Scene lookup hierarchy from current DB/LOR facts.

This module is the shared browse/presentation model for field applications.
It performs **no Google Drive enumeration**.  The hierarchy is built from the
already-reconciled Production Database Stage/Scene relationships plus stored
LOR path strings.  Filesystem access belongs to ``field_context_resolver`` only
after an operator has selected one context and a task needs its documents.

``field_context_browse.py`` remains an engineering/alignment validator that may
inspect the Drive tree.  It is not the normal runtime browse source.
"""
from __future__ import annotations

import re
from pathlib import PurePosixPath, PureWindowsPath
from typing import Any

_STAGE_KEY_RE = re.compile(r"^\d{2}$")
_SUBSTAGE_KEY_RE = re.compile(r"^(\d{2})[A-Za-z]$")


def _path_parts(path_text: str | None) -> tuple[str, ...]:
    if not path_text:
        return ()
    try:
        if "\\" in path_text or re.match(r"^[A-Za-z]:", path_text):
            return tuple(PureWindowsPath(path_text).parts)
        return tuple(PurePosixPath(path_text).parts)
    except Exception:
        return ()


def _path_with_parts(path_text: str, count: int) -> str | None:
    parts = _path_parts(path_text)
    if not parts or count <= 0 or count > len(parts):
        return None
    try:
        if "\\" in path_text or re.match(r"^[A-Za-z]:", path_text):
            return str(PureWindowsPath(*parts[:count]))
        return str(PurePosixPath(*parts[:count]))
    except Exception:
        return None


def _context_pointer(context: dict[str, Any]) -> str | None:
    scene = context.get("scene") or {}
    preview = context.get("preview") or {}
    return scene.get("scene_background_file") or preview.get("preview_background_file")


def _root_part_from_pointer(
    pointer: str | None,
    key: str,
) -> tuple[str | None, str | None]:
    """Return one path segment/root path matching ``key-`` from stored evidence."""
    parts = _path_parts(pointer)
    target = key.casefold() + "-"
    for index, part in enumerate(parts):
        if part.casefold().startswith(target):
            full = _path_with_parts(str(pointer), index + 1) if pointer else None
            return part, full
    return None, None


def _valid_persisted_label(stage: dict[str, Any]) -> tuple[str | None, str | None]:
    path = str(stage.get("folder_path") or "").strip()
    key = str(stage.get("stage_key") or "").strip()
    if not path or not key:
        return None, None
    parts = _path_parts(path)
    if not parts:
        return None, None
    label = parts[-1]
    if label.casefold().startswith(key.casefold() + "-"):
        return label, path
    return None, None


def _unique_pointer_root(
    contexts: list[dict[str, Any]],
    key: str,
) -> tuple[str | None, str | None]:
    found: dict[str, tuple[str, str | None]] = {}
    for context in contexts:
        pointer = _context_pointer(context)
        label, full = _root_part_from_pointer(pointer, key)
        if label:
            found[label.casefold()] = (label, full)
    if len(found) != 1:
        return None, None
    return next(iter(found.values()))


def _node_label_and_path(
    stage: dict[str, Any],
    contexts: list[dict[str, Any]],
) -> tuple[str, str | None, str]:
    key = str(stage.get("stage_key") or "").strip()
    persisted_label, persisted_path = _valid_persisted_label(stage)
    if persisted_label:
        return persisted_label, persisted_path, "PERSISTED_STAGE_PATH"

    pointer_label, pointer_path = _unique_pointer_root(contexts, key)
    if pointer_label:
        return pointer_label, pointer_path, "LOR_PATH_EVIDENCE"

    name = str(stage.get("stage_name") or "").strip()
    return (name or key or "Unresolved"), None, "DATABASE_STAGE_NAME_FALLBACK"


def _context_summary(context: dict[str, Any]) -> dict[str, Any]:
    preview = context.get("preview") or {}
    scene = context.get("scene") or {}
    return {
        "preview_uuid": preview.get("preview_uuid"),
        "preview_name": preview.get("preview_name"),
        "preview_background_file": preview.get("preview_background_file"),
        "scene_uuid": scene.get("scene_uuid"),
        "scene_name": scene.get("scene_name"),
        "scene_stage_key": scene.get("scene_stage_key"),
        "scene_background_file": scene.get("scene_background_file"),
        "scope_kind": context.get("scope_kind"),
        "context_type": context.get("context_type"),
    }


def _scene_child_from_pointer(
    context: dict[str, Any],
    owner_key: str,
    owner_label: str,
) -> tuple[str | None, str | None]:
    pointer = _context_pointer(context)
    parts = _path_parts(pointer)
    if not parts:
        return None, None

    owner_index: int | None = None
    for index, part in enumerate(parts):
        if part.casefold() == owner_label.casefold():
            owner_index = index
            break

    if owner_index is None:
        # Fall back to the first owner-key segment.  This still uses only the
        # stored path string and does not inspect the filesystem.
        for index, part in enumerate(parts):
            if part.casefold().startswith(owner_key.casefold() + "-"):
                owner_index = index
                break

    if owner_index is None:
        return None, None

    # BackgroundFile evidence names a file, so its final path segment is never
    # a Stage/Sub-stage/Scene folder.  Excluding the filename prevents a file
    # such as ``03-welcome area.jpg`` from being promoted into the browse
    # hierarchy merely because its basename begins with the owning Stage key.
    target = owner_key.casefold() + "-"
    for index in range(owner_index + 1, max(owner_index + 1, len(parts) - 1)):
        part = parts[index]
        if part.casefold().startswith(target):
            return part, _path_with_parts(str(pointer), index + 1) if pointer else None
    return None, None


def _scene_name_candidate(scene_name: str | None, owner_key: str, owner_label: str) -> str | None:
    name = str(scene_name or "").strip()
    if not name or name.casefold() == "root":
        return None
    if name.casefold() == owner_label.casefold():
        return None
    if not name.casefold().startswith(owner_key.casefold() + "-"):
        return None

    # Without path evidence, an NN-Name-XY value is conservatively treated as
    # Stage-root binding evidence rather than invented as a child.  Exact path
    # evidence may still prove a legacy nested child with such a name.
    if _STAGE_KEY_RE.fullmatch(owner_key) and re.fullmatch(
        rf"{re.escape(owner_key)}-.+-[A-Za-z]{{2,3}}", name
    ):
        return None
    if _SUBSTAGE_KEY_RE.fullmatch(owner_key) and re.fullmatch(
        rf"{re.escape(owner_key)}-.+-[A-Za-z]{{2,3}}", name
    ):
        return None
    return name


def _attach_contexts(node: dict[str, Any], contexts: list[dict[str, Any]]) -> None:
    owner_key = str(node.get("stage_key") or "")
    owner_label = str(node.get("label") or "")
    scene_nodes: dict[str, dict[str, Any]] = {}

    for context in contexts:
        child_label, child_path = _scene_child_from_pointer(context, owner_key, owner_label)
        if child_label is None:
            scene = context.get("scene") or {}
            child_label = _scene_name_candidate(
                scene.get("scene_name"),
                owner_key,
                owner_label,
            )

        if child_label is None:
            node["contexts"].append(_context_summary(context))
            continue

        key = child_label.casefold()
        child = scene_nodes.get(key)
        if child is None:
            child = {
                "scope_type": "SCENE",
                "label": child_label,
                "stage_id": node.get("stage_id"),
                "stage_key": owner_key,
                "scope_path_evidence": child_path,
                "contexts": [],
            }
            scene_nodes[key] = child
        elif child.get("scope_path_evidence") is None and child_path is not None:
            child["scope_path_evidence"] = child_path
        child["contexts"].append(_context_summary(context))

    node["scenes"] = sorted(scene_nodes.values(), key=lambda item: item["label"].casefold())


def _is_animation_only_without_field_path(
    stage: dict[str, Any],
    contexts: list[dict[str, Any]],
) -> bool:
    persisted_label, _ = _valid_persisted_label(stage)
    if persisted_label:
        return False
    if not contexts:
        return False
    return all(str(item.get("context_type") or "") == "Animation" for item in contexts)


def build_field_hierarchy(
    raw_stage_items: list[dict[str, Any]],
    drive_root: Any = None,
) -> dict[str, Any]:
    """Return the shared lookup hierarchy without filesystem I/O.

    ``drive_root`` is retained only for compatibility with the earlier API.  It
    is intentionally unused; callers must not rely on browse-time Drive scans.
    """
    del drive_root
    reviews: list[dict[str, Any]] = []
    top_nodes: dict[str, dict[str, Any]] = {}
    sub_items: list[tuple[dict[str, Any], list[dict[str, Any]]]] = []

    for item in raw_stage_items:
        stage = item.get("stage") or {}
        contexts = list(item.get("contexts") or [])
        key = str(stage.get("stage_key") or "").strip()
        if _SUBSTAGE_KEY_RE.fullmatch(key):
            sub_items.append((stage, contexts))
            continue
        if not _STAGE_KEY_RE.fullmatch(key):
            continue
        if _is_animation_only_without_field_path(stage, contexts):
            reviews.append(
                {
                    "code": "DATABASE_STAGE_NOT_IN_FIELD_HIERARCHY",
                    "stage_id": stage.get("stage_id"),
                    "stage_key": key,
                    "warnings": [
                        "Animation-only Stage row has no persisted physical Stage path and is excluded from normal field browse."
                    ],
                }
            )
            continue

        label, path_evidence, label_basis = _node_label_and_path(stage, contexts)
        node = {
            "scope_type": "STAGE",
            "label": label,
            "stage_id": stage.get("stage_id"),
            "stage_key": key,
            "database_stage_name": stage.get("stage_name"),
            "database_folder_path": stage.get("folder_path"),
            "scope_path_evidence": path_evidence,
            "label_basis": label_basis,
            "contexts": [],
            "scenes": [],
            "sub_stages": [],
        }
        if label_basis == "DATABASE_STAGE_NAME_FALLBACK":
            reviews.append(
                {
                    "code": "STAGE_PATH_EVIDENCE_REVIEW_REQUIRED",
                    "stage_id": stage.get("stage_id"),
                    "stage_key": key,
                    "warnings": [
                        "No usable persisted or LOR path string identified the field-facing Stage folder label."
                    ],
                }
            )
        _attach_contexts(node, contexts)
        top_nodes[key.casefold()] = node

    for stage, contexts in sub_items:
        key = str(stage.get("stage_key") or "").strip()
        match = _SUBSTAGE_KEY_RE.fullmatch(key)
        if not match:
            continue
        parent = top_nodes.get(match.group(1).casefold())
        if parent is None:
            reviews.append(
                {
                    "code": "SUBSTAGE_PARENT_REVIEW_REQUIRED",
                    "stage_id": stage.get("stage_id"),
                    "stage_key": key,
                    "warnings": ["No current top-level Stage row owns this Sub-stage key."],
                }
            )
            continue

        label, path_evidence, label_basis = _node_label_and_path(stage, contexts)
        node = {
            "scope_type": "SUBSTAGE",
            "label": label,
            "stage_id": stage.get("stage_id"),
            "stage_key": key,
            "database_stage_name": stage.get("stage_name"),
            "database_folder_path": stage.get("folder_path"),
            "scope_path_evidence": path_evidence,
            "label_basis": label_basis,
            "contexts": [],
            "scenes": [],
        }
        if label_basis == "DATABASE_STAGE_NAME_FALLBACK":
            reviews.append(
                {
                    "code": "SUBSTAGE_PATH_EVIDENCE_REVIEW_REQUIRED",
                    "stage_id": stage.get("stage_id"),
                    "stage_key": key,
                    "warnings": [
                        "No usable persisted or LOR path string identified the field-facing Sub-stage folder label."
                    ],
                }
            )
        _attach_contexts(node, contexts)
        parent["sub_stages"].append(node)

    stages = sorted(top_nodes.values(), key=lambda item: item["stage_key"].casefold())
    for stage in stages:
        stage["sub_stages"] = sorted(
            stage["sub_stages"], key=lambda item: item["stage_key"].casefold()
        )

    return {
        "stages": stages,
        "review_required": sorted(
            reviews,
            key=lambda item: (
                str(item.get("stage_key") or "").casefold(),
                str(item.get("code") or "").casefold(),
            ),
        ),
    }


def resolve_field_hierarchy(repository: Any, drive_root: Any = None) -> dict[str, Any]:
    """Canonical shared field lookup hierarchy entry point."""
    return build_field_hierarchy(repository.stages(), drive_root)
