"""Task-neutral Stage/Sub-stage/Scene filesystem context resolver.

The governing runtime contract is path-first and bounded:

* start from current Production Database/LOR identity and BackgroundFile evidence;
* use that pointer only as navigation evidence;
* walk upward only as needed to the nearest valid marked structured scope;
* never enumerate the Display Folders root to rediscover the park hierarchy;
* after the structured scope is fixed, task-specific callers choose their own
  relative branches such as Wiring or Procedures.

The authoritative behavior is documented in:

* Docs/00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md
* Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/
  FieldWiring_Drive_Context_Resolver_Engineering_Design.md

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
    "No distinct Scene/Sub-stage scope resolved from current path evidence; "
    "known marked Stage root retained as the structured field scope."
)

_SUBSTAGE_KEY_RE = re.compile(r"^(\d{2})[A-Za-z]$")
_SUBSTAGE_CHILD_RE = re.compile(r"^(\d{2}[A-Za-z])-(?=.)")


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
    if [part.casefold() for part in path_parts[: len(root_parts)]] != [
        part.casefold() for part in root_parts
    ]:
        return None
    return tuple(path_parts[len(root_parts) :])


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


def _same_path(left: Path, right: Path) -> bool:
    return str(left).replace("\\", "/").casefold().rstrip("/") == str(right).replace(
        "\\", "/"
    ).casefold().rstrip("/")


def _anchor_scope_type(stage_root: Path, stage_key: str | None) -> str:
    key = str(stage_key or "").strip()
    if _SUBSTAGE_KEY_RE.fullmatch(key) and stage_root.name.casefold().startswith(
        key.casefold() + "-"
    ):
        return "SUBSTAGE"
    return "STAGE"


def _structured_scope_type(
    candidate: Path,
    stage_root: Path,
    stage_key: str | None,
) -> str | None:
    """Classify one existing ancestor from hierarchy position and naming.

    A nested ``NN-Name-XY`` folder may legitimately be a legacy/current Scene
    even though preferred new Scene names omit the short-code suffix. Position
    under the already-known owning Stage therefore matters more than suffix.
    """
    if _same_path(candidate, stage_root):
        return _anchor_scope_type(stage_root, stage_key)

    key = str(stage_key or "").strip()
    base_match = re.match(r"^(\d{2})", key)
    if not base_match:
        return None
    base = base_match.group(1)

    sub_match = _SUBSTAGE_CHILD_RE.match(candidate.name)
    if sub_match and sub_match.group(1)[:2].casefold() == base.casefold():
        if _same_path(candidate.parent, stage_root):
            return "SUBSTAGE"
        return "SCENE"

    if key and candidate.name.casefold().startswith(key.casefold() + "-"):
        return "SCENE"

    return None


def _walk_up_from_pointer(
    pointer: Path,
    stage_root: Path,
    stage_key: str | None,
) -> tuple[Path | None, str | None, Path | None]:
    """Walk upward from exact path evidence to the nearest structured scope.

    A structured child that exists but is unmarked is a review condition. It
    is not silently skipped in favor of its parent Stage.
    """
    current = pointer.parent if pointer.is_file() else pointer

    while _path_is_under(current, stage_root):
        scope_type = _structured_scope_type(current, stage_root, stage_key)
        if scope_type is not None:
            if (current / MARKER_NAME).is_file():
                return current, scope_type, None
            return None, None, current
        if _same_path(current, stage_root):
            break
        current = current.parent

    return None, None, None


def _bounded_scope_matches(
    stage_root: Path,
    scene_name: str,
    max_depth: int = 2,
) -> list[Path]:
    """Conservative stale/no-pointer recovery inside one known Stage only."""
    targets = _canonical_scene_names(scene_name)
    matches: list[Path] = []

    def walk(path: Path, depth: int) -> None:
        if depth > max_depth:
            return
        try:
            children = [child for child in path.iterdir() if child.is_dir()]
        except OSError:
            return
        for child in children:
            if child.name.casefold() in targets:
                matches.append(child)
            if depth < max_depth and child.name.casefold() not in SKIP_SCOPE_SEARCH:
                walk(child, depth + 1)

    walk(stage_root, 1)
    unique = {str(item).casefold(): item for item in matches}
    return sorted(unique.values(), key=lambda item: str(item).casefold())


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
    """Recover the owning top-level Stage from supplied path evidence only."""
    if pointer is None or not stage_key or not pointer.exists():
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
    """Resolve one current marked Stage/Sub-stage/Scene root.

    Resolution order follows the engineering contract:

    1. use exact current path evidence and walk upward;
    2. if exact evidence is stale/absent, try one bounded Scene/Sub-stage match
       inside the already-known Stage;
    3. only when no more-specific structured scope exists, retain the Stage.

    No Display-Folders root enumeration occurs here.
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
    valid_stage = bool(
        stage_root
        and stage_root.is_dir()
        and (stage_root / MARKER_NAME).is_file()
    )

    if not valid_stage:
        recovered = _recover_stage_root(pointer, drive_root, stage.get("stage_key"))
        if recovered is not None:
            stage_root = recovered
            valid_stage = True
            warnings.append(
                "Persisted Stage folder_path was unavailable or stale; current marked Stage root was recovered from exact LOR path evidence."
            )

    if not valid_stage or stage_root is None:
        warnings.append(
            "Stage has no usable current folder_path anchor."
            if not folder_path
            else f"Stage folder_path is unavailable or unmarked on this server: {folder_path}"
        )
        return None, "UNRESOLVED", warnings

    scene_name = (scene or {}).get("scene_name")
    if not scene_name or scene_name.strip().casefold() == "root":
        return stage_root, _anchor_scope_type(stage_root, stage.get("stage_key")), warnings

    # Exact LOR path evidence is authoritative navigation evidence. Ignore
    # helper and Display/group folders while walking upward until the nearest
    # structured marked Scene/Sub-stage/Stage root is reached.
    if pointer is not None and _path_is_under(pointer, drive_root) and pointer.exists():
        if not _path_is_under(pointer, stage_root):
            warnings.append(
                "BackgroundFile resolves beneath Display Folders but outside the current Stage anchor; exact path evidence was not used for scope selection."
            )
        else:
            resolved, scope_type, unmarked = _walk_up_from_pointer(
                pointer,
                stage_root,
                stage.get("stage_key"),
            )
            if resolved is not None and scope_type is not None:
                direct_owner = _direct_task_owner(pointer, direct_owner_folder_name)
                if (
                    direct_owner_warning
                    and direct_owner is not None
                    and _same_path(direct_owner, resolved)
                ):
                    warnings.append(direct_owner_warning)
                return resolved, scope_type, warnings
            if unmarked is not None:
                warnings.append(
                    f"Structured source-folder marker is missing: {unmarked / MARKER_NAME}"
                )
                return None, "UNRESOLVED", warnings

    # If exact path evidence did not identify a more-specific owner, try the
    # documented Scene/Sub-stage name within the already-known Stage. This is
    # bounded recovery, not hierarchy discovery. A real marked Scene wins; an
    # existing unmarked matching Scene is a review condition; only an absent
    # Scene falls back to Stage.
    matches = _bounded_scope_matches(stage_root, scene_name)
    marked = [match for match in matches if (match / MARKER_NAME).is_file()]

    if len(marked) == 1:
        scope_type = _structured_scope_type(
            marked[0],
            stage_root,
            stage.get("stage_key"),
        )
        if scope_type is None:
            warnings.append(
                "Matching folder exists but is not a structured Stage/Sub-stage/Scene scope under the current path contract."
            )
            return None, "UNRESOLVED", warnings
        if raw_pointer and (pointer is None or not pointer.exists()):
            warnings.append(
                "Stored BackgroundFile did not resolve exactly; one deterministic marked current structured scope was used inside the known Stage."
            )
        return marked[0], scope_type, warnings

    if len(marked) > 1:
        warnings.append(
            "More than one marked structured folder matched the current Scene identity."
        )
        return None, "UNRESOLVED", warnings

    if matches:
        warnings.append(
            "Matching structured folder exists but is not an approved marked source root: "
            + "; ".join(str(match) for match in matches)
        )
        return None, "UNRESOLVED", warnings

    warnings.append(stage_fallback_warning)
    return stage_root, _anchor_scope_type(stage_root, stage.get("stage_key")), warnings
