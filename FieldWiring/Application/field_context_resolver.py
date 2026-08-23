"""Task-neutral Stage/Sub-stage/Scene filesystem context resolver.

This module contains the structured-scope resolution proven by FieldWiring. It
resolves the current marked Stage/Scene root from authoritative identity plus
bounded path/filesystem evidence. Task-specific consumers own what they do
after this root has been resolved.

Do not add Wiring/Procedure content discovery here.
"""
from __future__ import annotations

import re
from pathlib import Path, PureWindowsPath
from typing import Any

DEFAULT_WINDOWS_DRIVE_ROOT = r"G:\Shared drives\Display Folders"
MARKER_NAME = "_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt"
SKIP_SCOPE_SEARCH = {
    "wiring", "procedures", "photos", "previewbackground", "sourcedocs",
    "archive", "archived", "design archive",
}

DEFAULT_STAGE_FALLBACK_WARNING = (
    "No distinct Scene folder matched the current Scene identity; "
    "known marked Stage root retained as the structured field scope."
)


def _canonical_scene_names(scene_name: str) -> set[str]:
    names = {scene_name.strip()}
    stripped = re.sub(r"-[A-Z]{2,3}$", "", scene_name.strip())
    if stripped:
        names.add(stripped)
    return {name.casefold() for name in names if name}


def _windows_relative_parts(path_text: str, root_text: str) -> tuple[str, ...] | None:
    try:
        path_parts = PureWindowsPath(path_text).parts
        root_parts = PureWindowsPath(root_text).parts
    except Exception:
        return None
    if len(path_parts) < len(root_parts):
        return None
    if [p.casefold() for p in path_parts[:len(root_parts)]] != [
        p.casefold() for p in root_parts
    ]:
        return None
    return tuple(path_parts[len(root_parts):])


def _localize_evidence_path(
    path_text: str | None,
    drive_root: Path,
    windows_drive_root: str,
) -> Path | None:
    if not path_text:
        return None
    relative_parts = _windows_relative_parts(path_text, windows_drive_root)
    if relative_parts is not None:
        return drive_root.joinpath(*relative_parts)
    return Path(path_text)


def _path_is_under(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _bounded_scope_matches(
    stage_root: Path,
    scene_name: str,
    max_depth: int = 2,
) -> list[Path]:
    targets = _canonical_scene_names(scene_name)
    matches: list[Path] = []

    def walk(path: Path, depth: int) -> None:
        if depth > max_depth:
            return
        try:
            children = [p for p in path.iterdir() if p.is_dir()]
        except OSError:
            return
        for child in children:
            if child.name.casefold() in targets:
                matches.append(child)
            if depth < max_depth and child.name.casefold() not in SKIP_SCOPE_SEARCH:
                walk(child, depth + 1)

    walk(stage_root, 1)
    unique = {str(item).casefold(): item for item in matches}
    return sorted(unique.values(), key=lambda p: str(p).casefold())


def _truncate_before_sourcedocs(path: Path | None) -> tuple[Path | None, bool]:
    if path is None:
        return None, False
    parts = path.parts
    for index, part in enumerate(parts):
        if part.casefold() == "sourcedocs":
            if index == 0:
                return None, True
            return Path(*parts[:index]), True
    return path, False


def _direct_task_owner(pointer: Path | None, task_root_name: str | None) -> Path | None:
    """Return the structured folder directly above a caller-supplied task root."""
    if pointer is None or not task_root_name:
        return None
    current = pointer.parent if pointer.suffix else pointer
    target = task_root_name.casefold()
    for candidate in (current, *current.parents):
        if candidate.name.casefold() == target:
            return candidate.parent
    return None


def _recover_stage_root(
    pointer: Path | None,
    drive_root: Path,
    stage_key: str | None,
) -> Path | None:
    if pointer is None or not stage_key:
        return None
    if not pointer.exists():
        return None
    try:
        relative = pointer.relative_to(drive_root)
    except ValueError:
        return None
    if not relative.parts:
        return None
    candidate = drive_root / relative.parts[0]
    numeric = re.match(r"^(\d{2})", str(stage_key))
    if not numeric or not candidate.name.casefold().startswith(
        numeric.group(1).casefold() + "-"
    ):
        return None
    if not candidate.is_dir() or not (candidate / MARKER_NAME).is_file():
        return None
    return candidate


def resolve_structured_scope(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    preview: dict[str, Any],
    drive_root: Path,
    *,
    windows_drive_root: str = DEFAULT_WINDOWS_DRIVE_ROOT,
    direct_owner_folder_name: str | None = None,
    direct_owner_warning: str | None = None,
    stage_fallback_warning: str = DEFAULT_STAGE_FALLBACK_WARNING,
) -> tuple[Path | None, str, list[str]]:
    """Resolve one current marked Stage/Scene root without discovering task content.

    ``direct_owner_folder_name`` preserves a caller's existing exact path-owner
    evidence rule without teaching this shared resolver what that task folder
    means. The caller may also supply legacy warning strings so user-visible
    warnings remain byte-for-byte stable during extraction.
    """
    warnings: list[str] = []
    raw_pointer = (scene or {}).get("scene_background_file") or preview.get(
        "preview_background_file"
    )
    localized_pointer = _localize_evidence_path(
        raw_pointer,
        drive_root,
        windows_drive_root,
    )
    pointer, blocked = _truncate_before_sourcedocs(localized_pointer)
    if blocked:
        warnings.append(
            "BackgroundFile path enters SourceDocs. Traversal stopped before SourceDocs; source content was not accessed."
        )

    folder_path = (stage.get("folder_path") or "").strip()
    stage_root = (
        _localize_evidence_path(folder_path, drive_root, windows_drive_root)
        if folder_path
        else None
    )
    valid = bool(
        stage_root
        and stage_root.is_dir()
        and (stage_root / MARKER_NAME).is_file()
    )
    if not valid:
        recovered = _recover_stage_root(pointer, drive_root, stage.get("stage_key"))
        if recovered is not None:
            stage_root = recovered
            valid = True
            warnings.append(
                "Persisted Stage folder_path was unavailable or stale; current marked Stage root was recovered from exact LOR path evidence."
            )
    if not valid or stage_root is None:
        warnings.append(
            "Stage has no usable current folder_path anchor."
            if not folder_path
            else f"Stage folder_path is unavailable or unmarked on this server: {folder_path}"
        )
        return None, "UNRESOLVED", warnings

    # Some callers already use an exact task-root path as explicit
    # documentation-ownership evidence. The shared resolver accepts the task
    # root name as data; it does not select or inspect task content beneath it.
    direct_owner = _direct_task_owner(pointer, direct_owner_folder_name)
    if direct_owner is not None and _path_is_under(direct_owner, drive_root):
        if direct_owner == stage_root:
            if direct_owner_warning:
                warnings.append(direct_owner_warning)
            return stage_root, "STAGE", warnings

    scene_name = (scene or {}).get("scene_name")
    if not scene_name or scene_name.strip().casefold() == "root":
        return stage_root, "STAGE", warnings

    targets = _canonical_scene_names(scene_name)
    if pointer is not None and _path_is_under(pointer, drive_root):
        if pointer.exists():
            current = pointer.parent if pointer.is_file() else pointer
            while _path_is_under(current, stage_root):
                if current.name.casefold() in targets:
                    if (current / MARKER_NAME).is_file():
                        return current, "SCENE", warnings
                    warnings.append(
                        f"Scene source-folder marker is missing: {current / MARKER_NAME}"
                    )
                    return None, "UNRESOLVED", warnings
                if current == stage_root:
                    break
                current = current.parent

    matches = _bounded_scope_matches(stage_root, scene_name)
    marked = [match for match in matches if (match / MARKER_NAME).is_file()]
    if len(marked) == 1:
        if raw_pointer:
            warnings.append(
                "Stored Scene BackgroundFile did not resolve exactly; one deterministic marked current Scene folder was used."
            )
        return marked[0], "SCENE", warnings
    if len(marked) > 1:
        warnings.append("More than one marked Scene folder matched the current Scene identity.")
        return None, "UNRESOLVED", warnings
    if matches:
        warnings.append(
            "Matching Scene folder exists but is not an approved marked source root: "
            + "; ".join(str(match) for match in matches)
        )
        return None, "UNRESOLVED", warnings

    warnings.append(stage_fallback_warning)
    return stage_root, "STAGE", warnings
