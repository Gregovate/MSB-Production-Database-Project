"""Resolved Stage/Sub-stage/Scene browse over shared field-context evidence.

Raw ``ref.stage`` rows and raw LOR Scene rows are evidence, not field browse
nodes.  The released Google Drive hierarchy is represented only after current
filesystem roots have been resolved and validated.

This module does not discover Wiring or Procedure content.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from field_context_resolver import MARKER_NAME, resolve_structured_scope

_STAGE_KEY_RE = re.compile(r"^\d{2}$")
_SUBSTAGE_KEY_RE = re.compile(r"^(\d{2})[A-Za-z]$")
_TOP_STAGE_FOLDER_RE = re.compile(r"^(\d{2})-(?=.)")
_SUBSTAGE_FOLDER_RE = re.compile(r"^(\d{2}[A-Za-z])-(?=.)")


class FieldHierarchyError(RuntimeError):
    pass


def _marked(path: Path) -> bool:
    return path.is_dir() and (path / MARKER_NAME).is_file()


def _path_key(path: Path) -> str:
    return str(path).replace("\\", "/").casefold().rstrip("/")


def _children(path: Path) -> list[Path]:
    try:
        return sorted(
            [item for item in path.iterdir() if item.is_dir()],
            key=lambda item: item.name.casefold(),
        )
    except OSError:
        return []


def _context_key(context: dict[str, Any]) -> tuple[str, str]:
    preview = context.get("preview") or {}
    scene = context.get("scene") or {}
    return (
        str(preview.get("preview_uuid") or ""),
        str(scene.get("scene_uuid") or ""),
    )


def _dedupe_contexts(contexts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for context in contexts:
        key = _context_key(context)
        if key in seen:
            continue
        seen.add(key)
        result.append(context)
    return result


def _review_key(item: dict[str, Any]) -> tuple[Any, ...]:
    return (
        item.get("code"),
        item.get("stage_id"),
        item.get("stage_key"),
        item.get("scope_root"),
        item.get("scene_uuid"),
        item.get("scene_name"),
    )


def _add_review(
    reviews: list[dict[str, Any]],
    seen: set[tuple[Any, ...]],
    item: dict[str, Any],
) -> None:
    key = _review_key(item)
    if key in seen:
        return
    seen.add(key)
    reviews.append(item)


def _node(scope_type: str, root: Path, stage: dict[str, Any]) -> dict[str, Any]:
    return {
        "scope_type": scope_type,
        "label": root.name,
        "scope_root": str(root),
        "stage_id": stage.get("stage_id"),
        "stage_key": stage.get("stage_key"),
        "database_stage_name": stage.get("stage_name"),
        "database_folder_path": stage.get("folder_path"),
        "contexts": [],
        "scenes": [],
    }


def _scan_top_roots(
    drive_root: Path,
) -> tuple[dict[str, list[Path]], dict[str, list[Path]]]:
    marked: dict[str, list[Path]] = {}
    unmarked: dict[str, list[Path]] = {}
    for child in _children(drive_root):
        match = _TOP_STAGE_FOLDER_RE.match(child.name)
        if not match:
            continue
        target = marked if _marked(child) else unmarked
        target.setdefault(match.group(1), []).append(child)
    return marked, unmarked


def _scan_substage_roots(
    stage_root: Path,
    stage_key: str,
) -> tuple[dict[str, list[Path]], dict[str, list[Path]]]:
    marked: dict[str, list[Path]] = {}
    unmarked: dict[str, list[Path]] = {}
    for child in _children(stage_root):
        match = _SUBSTAGE_FOLDER_RE.match(child.name)
        if not match:
            continue
        key = match.group(1)
        if key[:2].casefold() != stage_key.casefold():
            continue
        target = marked if _marked(child) else unmarked
        target.setdefault(key.casefold(), []).append(child)
    return marked, unmarked


def _persisted_path_warnings(
    stage: dict[str, Any],
    actual_root: Path,
    drive_root: Path,
) -> list[str]:
    resolved, _, warnings = resolve_structured_scope(stage, None, {}, drive_root)
    if resolved is not None and _path_key(resolved) == _path_key(actual_root):
        return []
    return warnings or [
        "Persisted Stage folder_path does not resolve to the current marked field root."
    ]


def _context_review(
    code: str,
    stage: dict[str, Any],
    context: dict[str, Any],
    warnings: list[str],
    scope_root: Path | None = None,
) -> dict[str, Any]:
    preview = context.get("preview") or {}
    scene = context.get("scene") or {}
    return {
        "code": code,
        "stage_id": stage.get("stage_id"),
        "stage_key": stage.get("stage_key"),
        "scene_uuid": scene.get("scene_uuid"),
        "scene_name": scene.get("scene_name"),
        "preview_uuid": preview.get("preview_uuid"),
        "preview_name": preview.get("preview_name"),
        "scope_root": str(scope_root) if scope_root is not None else None,
        "warnings": list(warnings),
    }


def _attach_contexts(
    node: dict[str, Any],
    stage: dict[str, Any],
    contexts: list[dict[str, Any]],
    owning_root: Path,
    owning_key: str,
    drive_root: Path,
    reviews: list[dict[str, Any]],
    review_seen: set[tuple[Any, ...]],
) -> None:
    scene_nodes: dict[str, dict[str, Any]] = {}
    resolver_stage = {
        "stage_id": stage.get("stage_id"),
        "stage_key": stage.get("stage_key"),
        "folder_path": str(owning_root),
    }

    for context in contexts:
        preview = context.get("preview") or {}
        scene = context.get("scene")
        scope_root, scope_type, warnings = resolve_structured_scope(
            resolver_stage,
            scene,
            preview,
            drive_root,
        )
        if scope_root is None or scope_type == "UNRESOLVED":
            _add_review(
                reviews,
                review_seen,
                _context_review(
                    "LOR_CONTEXT_UNRESOLVED",
                    stage,
                    context,
                    warnings,
                ),
            )
            continue

        if _path_key(scope_root) == _path_key(owning_root):
            node["contexts"].append(context)
            continue

        try:
            relative = scope_root.relative_to(owning_root)
        except ValueError:
            _add_review(
                reviews,
                review_seen,
                _context_review(
                    "LOR_CONTEXT_OUTSIDE_OWNING_SCOPE",
                    stage,
                    context,
                    warnings,
                    scope_root,
                ),
            )
            continue

        if len(relative.parts) != 1:
            _add_review(
                reviews,
                review_seen,
                _context_review(
                    "LOR_CONTEXT_NESTING_REVIEW_REQUIRED",
                    stage,
                    context,
                    warnings,
                    scope_root,
                ),
            )
            continue

        if not scope_root.name.casefold().startswith(owning_key.casefold() + "-"):
            _add_review(
                reviews,
                review_seen,
                _context_review(
                    "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE",
                    stage,
                    context,
                    warnings,
                    scope_root,
                ),
            )
            continue

        if not _marked(scope_root):
            _add_review(
                reviews,
                review_seen,
                _context_review(
                    "FIELD_SCENE_MARKER_MISSING",
                    stage,
                    context,
                    warnings,
                    scope_root,
                ),
            )
            continue

        key = _path_key(scope_root)
        child = scene_nodes.get(key)
        if child is None:
            child = {
                "scope_type": "SCENE",
                "label": scope_root.name,
                "scope_root": str(scope_root),
                "stage_id": stage.get("stage_id"),
                "stage_key": stage.get("stage_key"),
                "contexts": [],
            }
            scene_nodes[key] = child
        child["contexts"].append(context)

    node["contexts"] = _dedupe_contexts(node["contexts"])
    for child in scene_nodes.values():
        child["contexts"] = _dedupe_contexts(child["contexts"])
    node["scenes"] = sorted(
        scene_nodes.values(),
        key=lambda item: (item["label"].casefold(), item["scope_root"].casefold()),
    )


def build_field_hierarchy(
    raw_stage_items: list[dict[str, Any]],
    drive_root: str | Path,
) -> dict[str, Any]:
    """Return actual field hierarchy plus unresolved alignment evidence."""
    root = Path(drive_root)
    if not root.is_dir():
        raise FieldHierarchyError(f"Display Folders root is not available: {root}")

    marked_top, unmarked_top = _scan_top_roots(root)
    reviews: list[dict[str, Any]] = []
    review_seen: set[tuple[Any, ...]] = set()
    by_key: dict[str, list[dict[str, Any]]] = {}
    for item in raw_stage_items:
        stage = item.get("stage") or {}
        key = str(stage.get("stage_key") or "").strip()
        if key:
            by_key.setdefault(key.casefold(), []).append(item)

    stages: list[dict[str, Any]] = []
    consumed: set[int] = set()

    for stage_key in sorted(marked_top):
        roots = marked_top[stage_key]
        matches = by_key.get(stage_key.casefold(), [])
        if len(roots) != 1 or len(matches) != 1:
            _add_review(
                reviews,
                review_seen,
                {
                    "code": "STAGE_BINDING_REVIEW_REQUIRED",
                    "stage_key": stage_key,
                    "scope_root": str(roots[0]) if roots else None,
                    "warnings": [
                        "No unique current ref.stage row and marked top-level Stage root pair could be established."
                    ],
                },
            )
            continue

        item = matches[0]
        stage = item.get("stage") or {}
        stage_root = roots[0]
        stage_id = stage.get("stage_id")
        if stage_id is not None:
            consumed.add(int(stage_id))
        node = _node("STAGE", stage_root, stage)
        node["sub_stages"] = []

        path_warnings = _persisted_path_warnings(stage, stage_root, root)
        if path_warnings:
            _add_review(
                reviews,
                review_seen,
                {
                    "code": "PERSISTED_STAGE_PATH_REVIEW_REQUIRED",
                    "stage_id": stage_id,
                    "stage_key": stage_key,
                    "scope_root": str(stage_root),
                    "database_folder_path": stage.get("folder_path"),
                    "warnings": path_warnings,
                },
            )

        marked_sub, unmarked_sub = _scan_substage_roots(stage_root, stage_key)
        sub_items: dict[str, list[dict[str, Any]]] = {}
        for key, candidates in by_key.items():
            match = _SUBSTAGE_KEY_RE.fullmatch(key)
            if match and match.group(1).casefold() == stage_key.casefold():
                sub_items[key] = candidates

        for sub_key, sub_roots in sorted(marked_sub.items()):
            sub_matches = sub_items.get(sub_key.casefold(), [])
            if len(sub_roots) != 1 or len(sub_matches) != 1:
                _add_review(
                    reviews,
                    review_seen,
                    {
                        "code": "SUBSTAGE_BINDING_REVIEW_REQUIRED",
                        "stage_key": sub_key,
                        "scope_root": str(sub_roots[0]) if sub_roots else None,
                        "warnings": [
                            "No unique current ref.stage row and marked Sub-stage root pair could be established."
                        ],
                    },
                )
                continue

            sub_item = sub_matches[0]
            sub_stage = sub_item.get("stage") or {}
            sub_root = sub_roots[0]
            sub_id = sub_stage.get("stage_id")
            if sub_id is not None:
                consumed.add(int(sub_id))
            sub_node = _node("SUBSTAGE", sub_root, sub_stage)

            path_warnings = _persisted_path_warnings(sub_stage, sub_root, root)
            if path_warnings:
                _add_review(
                    reviews,
                    review_seen,
                    {
                        "code": "PERSISTED_SUBSTAGE_PATH_REVIEW_REQUIRED",
                        "stage_id": sub_id,
                        "stage_key": sub_stage.get("stage_key"),
                        "scope_root": str(sub_root),
                        "database_folder_path": sub_stage.get("folder_path"),
                        "warnings": path_warnings,
                    },
                )

            _attach_contexts(
                sub_node,
                sub_stage,
                list(sub_item.get("contexts") or []),
                sub_root,
                str(sub_stage.get("stage_key") or sub_key),
                root,
                reviews,
                review_seen,
            )
            node["sub_stages"].append(sub_node)

        for sub_key, sub_roots in sorted(unmarked_sub.items()):
            if sub_key.casefold() not in sub_items or sub_key.casefold() in marked_sub:
                continue
            for sub_root in sub_roots:
                _add_review(
                    reviews,
                    review_seen,
                    {
                        "code": "SUBSTAGE_ROOT_UNMARKED",
                        "stage_key": sub_key,
                        "scope_root": str(sub_root),
                        "warnings": [
                            "Sub-stage-shaped folder exists but is not a current marked field scope."
                        ],
                    },
                )

        for sub_key, sub_matches in sorted(sub_items.items()):
            if sub_key.casefold() in marked_sub:
                continue
            for sub_item in sub_matches:
                sub_stage = sub_item.get("stage") or {}
                _add_review(
                    reviews,
                    review_seen,
                    {
                        "code": "SUBSTAGE_ROOT_NOT_RESOLVED",
                        "stage_id": sub_stage.get("stage_id"),
                        "stage_key": sub_stage.get("stage_key"),
                        "database_folder_path": sub_stage.get("folder_path"),
                        "warnings": [
                            "Current Sub-stage database row has no unique marked child field root."
                        ],
                    },
                )

        _attach_contexts(
            node,
            stage,
            list(item.get("contexts") or []),
            stage_root,
            stage_key,
            root,
            reviews,
            review_seen,
        )
        node["sub_stages"] = sorted(
            node["sub_stages"],
            key=lambda item: (str(item["stage_key"]).casefold(), item["label"].casefold()),
        )
        stages.append(node)

    for stage_key, roots in sorted(unmarked_top.items()):
        if stage_key.casefold() not in by_key:
            continue
        for stage_root in roots:
            _add_review(
                reviews,
                review_seen,
                {
                    "code": "STAGE_ROOT_UNMARKED",
                    "stage_key": stage_key,
                    "scope_root": str(stage_root),
                    "warnings": [
                        "Stage-shaped top-level folder exists but is not a current marked field scope."
                    ],
                },
            )

    for items in by_key.values():
        for item in items:
            stage = item.get("stage") or {}
            stage_id = stage.get("stage_id")
            if stage_id is not None and int(stage_id) in consumed:
                continue
            key = str(stage.get("stage_key") or "")
            if not (_STAGE_KEY_RE.fullmatch(key) or _SUBSTAGE_KEY_RE.fullmatch(key)):
                continue
            _add_review(
                reviews,
                review_seen,
                {
                    "code": "DATABASE_STAGE_NOT_IN_FIELD_HIERARCHY",
                    "stage_id": stage_id,
                    "stage_key": key,
                    "database_stage_name": stage.get("stage_name"),
                    "database_folder_path": stage.get("folder_path"),
                    "warnings": [
                        "Current database Stage/Sub-stage row did not map to one actual marked field hierarchy root."
                    ],
                },
            )

    return {
        "stages": sorted(
            stages,
            key=lambda item: (str(item["stage_key"]).casefold(), item["label"].casefold()),
        ),
        "review_required": sorted(
            reviews,
            key=lambda item: (
                str(item.get("stage_key") or "").casefold(),
                str(item.get("code") or "").casefold(),
                str(item.get("scope_root") or "").casefold(),
                str(item.get("scene_name") or "").casefold(),
            ),
        ),
    }


def resolve_field_hierarchy(repository: Any, drive_root: str | Path) -> dict[str, Any]:
    """Canonical shared browse entry point.

    ``repository.stages()`` is treated only as raw DB/LOR evidence. Applications
    must consume this resolved result rather than present those rows directly.
    """
    return build_field_hierarchy(repository.stages(), drive_root)
