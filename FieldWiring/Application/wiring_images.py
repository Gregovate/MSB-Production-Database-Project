"""Guarded same-scope FieldWiring image resolver."""
from __future__ import annotations

import os
import re
from pathlib import Path, PureWindowsPath
from typing import Any

from wiring_common import (
    DEFAULT_DRIVE_ROOT, IMAGE_EXTENSIONS, MARKER_NAME, SKIP_SCOPE_SEARCH, WiringError,
)


def _canonical_scene_names(scene_name: str) -> set[str]:
    names = {scene_name.strip()}
    stripped = re.sub(r"-[A-Z]{2,3}$", "", scene_name.strip())
    if stripped:
        names.add(stripped)
    return {name.casefold() for name in names if name}


def _path_is_under_windows(path_text: str, root_text: str) -> bool:
    try:
        path_parts = [p.casefold() for p in PureWindowsPath(path_text).parts]
        root_parts = [p.casefold() for p in PureWindowsPath(root_text).parts]
    except Exception:
        return False
    return path_parts[:len(root_parts)] == root_parts


def _bounded_scope_matches(stage_root: Path, scene_name: str, max_depth: int = 2) -> list[Path]:
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


def _truncate_before_sourcedocs(path_text: str | None) -> tuple[str | None, bool]:
    if not path_text:
        return path_text, False
    parts = PureWindowsPath(path_text).parts
    for index, part in enumerate(parts):
        if part.casefold() == "sourcedocs":
            if index == 0:
                return None, True
            return str(PureWindowsPath(*parts[:index])), True
    return path_text, False


def _recover_stage_root(pointer_text: str | None, drive_root: Path, stage_key: str | None) -> Path | None:
    if not pointer_text or not stage_key:
        return None
    pointer = Path(pointer_text)
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
    if not numeric or not candidate.name.casefold().startswith(numeric.group(1).casefold() + "-"):
        return None
    if not candidate.is_dir() or not (candidate / MARKER_NAME).is_file():
        return None
    return candidate


def _resolve_scope_root(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    preview: dict[str, Any],
    drive_root: Path,
) -> tuple[Path | None, str, list[str]]:
    warnings: list[str] = []
    raw_pointer = (scene or {}).get("scene_background_file") or preview.get("preview_background_file")
    pointer, blocked = _truncate_before_sourcedocs(raw_pointer)
    if blocked:
        warnings.append(
            "BackgroundFile path enters SourceDocs. Traversal stopped before SourceDocs; source content was not accessed."
        )

    folder_path = (stage.get("folder_path") or "").strip()
    stage_root = Path(folder_path) if folder_path else None
    valid = bool(stage_root and stage_root.is_dir() and (stage_root / MARKER_NAME).is_file())
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
            "Stage has no usable current folder_path anchor." if not folder_path
            else f"Stage folder_path is unavailable or unmarked on this server: {folder_path}"
        )
        return None, "UNRESOLVED", warnings

    scene_name = (scene or {}).get("scene_name")
    if not scene_name or scene_name.strip().casefold() == "root":
        return stage_root, "STAGE", warnings

    targets = _canonical_scene_names(scene_name)
    if pointer and _path_is_under_windows(str(pointer), str(drive_root)):
        pointer_path = Path(str(pointer))
        if pointer_path.exists():
            current = pointer_path.parent if pointer_path.is_file() else pointer_path
            stage_fold = str(stage_root).casefold()
            while str(current).casefold().startswith(stage_fold):
                if current.name.casefold() in targets:
                    if (current / MARKER_NAME).is_file():
                        return current, "SCENE", warnings
                    warnings.append(f"Scene source-folder marker is missing: {current / MARKER_NAME}")
                    return None, "UNRESOLVED", warnings
                if str(current).casefold() == stage_fold:
                    break
                current = current.parent

    matches = _bounded_scope_matches(stage_root, scene_name)
    marked = [m for m in matches if (m / MARKER_NAME).is_file()]
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

    warnings.append(
        "No distinct Scene folder matched the current Scene identity; known marked Stage root retained as the FieldWiring scope."
    )
    return stage_root, "STAGE", warnings


def _direct_images(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    try:
        return sorted(
            [p for p in folder.iterdir() if p.is_file() and p.suffix.casefold() in IMAGE_EXTENSIONS],
            key=lambda p: p.name.casefold(),
        )
    except OSError:
        return []


def _image_payload(path: Path, drive_root: Path, kind: str) -> dict[str, Any]:
    relative = path.relative_to(drive_root)
    return {
        "name": path.name,
        "kind": kind,
        "relative_path": relative.as_posix(),
        "url": "/api/wiring/image?path=" + relative.as_posix().replace(" ", "%20"),
    }


def resolve_images(
    stage: dict[str, Any],
    scene: dict[str, Any] | None,
    preview: dict[str, Any],
    selected_context: str,
) -> dict[str, Any]:
    root_text = os.environ.get("FIELDWIRING_DRIVE_ROOT", DEFAULT_DRIVE_ROOT).strip()
    drive_root = Path(root_text)
    if not drive_root.is_dir():
        return {"scope_type":"UNAVAILABLE", "scope_root":None, "wiring_images":[], "context_images":[],
                "warnings":[f"Display Folders root is not available on this server: {root_text}"]}

    scope_root, scope_type, warnings = _resolve_scope_root(stage, scene, preview, drive_root)
    if scope_root is None:
        return {"scope_type":scope_type, "scope_root":None, "wiring_images":[], "context_images":[], "warnings":warnings}

    branch = "MusicalStage" if selected_context == "Musical" else "BackgroundStage"
    wiring_folder = scope_root / "Wiring" / branch
    wiring_images: list[Path] = []
    if (wiring_folder.parent / MARKER_NAME).is_file():
        wiring_images = _direct_images(wiring_folder)
    elif wiring_folder.exists():
        warnings.append(f"Unmarked Wiring source excluded: {wiring_folder}")

    context_folder = scope_root / "PreviewBackground"
    context_images: list[Path] = []
    if (context_folder / MARKER_NAME).is_file():
        context_images = _direct_images(context_folder)
    elif context_folder.exists():
        warnings.append(f"Unmarked PreviewBackground source excluded: {context_folder}")

    return {
        "scope_type": scope_type,
        "scope_root": str(scope_root),
        "wiring_images": [_image_payload(p, drive_root, "wiring") for p in wiring_images],
        "context_images": [_image_payload(p, drive_root, "context") for p in context_images],
        "warnings": warnings,
    }


def safe_image_path(relative_path: str) -> Path:
    if not relative_path or "\x00" in relative_path:
        raise WiringError("Invalid image path")
    parts = [part for part in PureWindowsPath(relative_path).parts if part not in {"\\", "/"}]
    if any(part in {"..", "."} for part in parts):
        raise WiringError("Invalid image path")
    if any(part.casefold() == "sourcedocs" for part in parts):
        raise WiringError("SourceDocs content is not a FieldWiring application source")
    drive_root = Path(os.environ.get("FIELDWIRING_DRIVE_ROOT", DEFAULT_DRIVE_ROOT).strip())
    candidate = drive_root.joinpath(*parts)
    if candidate.suffix.casefold() not in IMAGE_EXTENSIONS or not candidate.is_file():
        raise WiringError("Wiring image is not available")
    try:
        candidate.relative_to(drive_root)
    except ValueError as exc:
        raise WiringError("Invalid image path") from exc
    return candidate
