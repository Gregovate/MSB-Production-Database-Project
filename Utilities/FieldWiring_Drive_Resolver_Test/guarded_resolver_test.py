#!/usr/bin/env python3
"""
Safety/contract guard for the FieldWiring Drive-context resolver test harness.

This wrapper enforces current Google Drive rules without modifying data:

1. SourceDocs is a hard traversal boundary.
2. Current application content may be selected only from approved marked source
   folders, and resolved Stage/Substage/Scene roots must carry the structural
   marker.
3. A stale ref.stage.folder_path may be recovered for test purposes only when
   the current LOR pointer resolves beneath Display Folders to one deterministic
   marked top-level Stage root matching the Stage number.

Legacy BackgroundFile paths may still be used as navigation evidence, but loose
legacy files and unmarked folders cannot become published FieldWiring content.
"""
from __future__ import annotations

import sys
from pathlib import Path, PureWindowsPath

import test_drive_context_resolver as base

MARKER_NAME = "_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt"

_original_resolve_one = base.resolve_one
_original_make_candidate = base.make_candidate


def truncate_before_sourcedocs(path_text: str | None) -> tuple[str | None, bool]:
    if not path_text:
        return path_text, False

    parts = PureWindowsPath(path_text).parts
    for index, part in enumerate(parts):
        if part.casefold() == "sourcedocs":
            if index == 0:
                return None, True
            return str(PureWindowsPath(*parts[:index])), True

    return path_text, False


def required_source_marker(candidate_path: Path) -> Path:
    """Return the marker that authorizes this candidate source branch."""
    name = candidate_path.name.casefold()

    # FieldWiring candidate paths point at Wiring/BackgroundStage or
    # Wiring/MusicalStage. The controlled source marker belongs at Wiring root.
    if name in {"backgroundstage", "musicalstage"} and candidate_path.parent.name.casefold() == "wiring":
        return candidate_path.parent / MARKER_NAME

    # PreviewBackground is itself the controlled source folder.
    if name == "previewbackground":
        return candidate_path / MARKER_NAME

    return candidate_path / MARKER_NAME


def marked_make_candidate(label: str, path: Path):
    candidate = _original_make_candidate(label, path)
    marker_path = required_source_marker(path)

    if not marker_path.is_file():
        # Keep the physical-folder evidence visible in the report while making
        # the candidate unusable for selection.
        candidate.label = f"{candidate.label} [UNMARKED - EXCLUDED]"
        candidate.image_count = 0
        candidate.images = []

    return candidate


def top_level_stage_from_pointer(
    pointer_text: str | None,
    drive_root: Path,
    stage_key: str | None,
) -> Path | None:
    """Recover one top-level Stage root from exact current pointer evidence.

    This is deliberately narrow. It is used only when ref.stage.folder_path is
    stale/non-resolving. The pointer must be beneath the configured Display
    Folders root, the first relative component must match the numeric Stage key,
    the folder must exist, and it must carry the structural marker.
    """
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
    numeric_stage = stage_key[:2]
    if not candidate.name.casefold().startswith(numeric_stage.casefold() + "-"):
        return None
    if not candidate.is_dir():
        return None
    if not (candidate / MARKER_NAME).is_file():
        return None
    return candidate


def rebuild_candidates(result, stage_root: Path):
    """Rebuild candidate paths after a stale Stage anchor is recovered."""
    branch = result.wiring_branch
    if not branch:
        return result

    candidates = []
    scope_root = Path(result.resolved_scope_root) if result.resolved_scope_root else stage_root

    if str(scope_root).casefold() != str(stage_root).casefold():
        candidates.extend(
            [
                marked_make_candidate(
                    f"{result.resolved_scope_type.title()} Wiring {branch}",
                    scope_root / "Wiring" / branch,
                ),
                marked_make_candidate(
                    f"{result.resolved_scope_type.title()} PreviewBackground",
                    scope_root / "PreviewBackground",
                ),
            ]
        )

    candidates.extend(
        [
            marked_make_candidate(f"Stage Wiring {branch}", stage_root / "Wiring" / branch),
            marked_make_candidate("Stage PreviewBackground", stage_root / "PreviewBackground"),
        ]
    )

    result.candidates = candidates
    selected = base.select_candidate(candidates)
    result.selected_candidate = selected.label if selected else None
    result.selected_path = selected.path if selected else None
    result.status = "RESOLVED" if selected else "UNRESOLVED"
    return result


def recover_stale_stage_anchor(result, safe_pointer: str | None, drive_root: Path):
    """Use exact marked pointer evidence when the persisted Stage path is stale."""
    if result.stage_root_exists:
        return result

    recovered = top_level_stage_from_pointer(safe_pointer, drive_root, result.stage_key)
    if recovered is None:
        return result

    old_stage_root = result.stage_root
    result.stage_root = str(recovered)
    result.stage_root_exists = True

    # For a Stage-level result, the recovered top-level folder is also the
    # resolved structured scope. For Scene/Substage results, preserve the more
    # specific resolved scope and use the recovered Stage only for inheritance.
    if result.resolved_scope_type == "STAGE":
        result.resolved_scope_root = str(recovered)

    result.warnings = [
        warning
        for warning in result.warnings
        if not warning.startswith("Stage root does not resolve on the mapped Drive:")
    ]
    result.warnings.insert(
        0,
        "Persisted Stage folder_path did not resolve. Recovered current marked "
        f"Stage root from exact LOR pointer evidence: {recovered} "
        f"(stored Stage path: {old_stage_root})",
    )
    result.resolution_basis = (
        "Stale persisted Stage folder_path recovered from exact marked current "
        "LOR pointer evidence. " + result.resolution_basis
    )
    return rebuild_candidates(result, recovered)


def enforce_structural_markers(result):
    """Require markers on the resolved Stage and selected structured scope."""
    required_roots: list[Path] = []

    if result.stage_root:
        required_roots.append(Path(result.stage_root))

    if result.resolved_scope_root:
        scope = Path(result.resolved_scope_root)
        if all(str(scope).casefold() != str(p).casefold() for p in required_roots):
            required_roots.append(scope)

    missing = [root for root in required_roots if not (root / MARKER_NAME).is_file()]
    if missing:
        result.status = "UNRESOLVED"
        result.selected_candidate = None
        result.selected_path = None
        result.warnings.insert(
            0,
            "Missing structural root marker: " + "; ".join(str(p / MARKER_NAME) for p in missing),
        )

    unmarked_candidates = [c.path for c in result.candidates if "[UNMARKED - EXCLUDED]" in c.label]
    if unmarked_candidates:
        result.warnings.append(
            "Unmarked source candidate(s) were excluded from application selection: "
            + "; ".join(unmarked_candidates)
        )

    return result


def guarded_resolve_one(conn, row, drive_root, drive_root_text):
    raw_scene_pointer = row["scene_background_file"]
    raw_preview_pointer = row["preview_background_file"]
    raw_pointer = raw_scene_pointer or raw_preview_pointer

    safe_pointer, blocked = truncate_before_sourcedocs(raw_pointer)

    if blocked:
        # sqlite3.Row is immutable, but the resolver only needs mapping access.
        safe_row = dict(row)
        if raw_scene_pointer:
            safe_row["scene_background_file"] = safe_pointer
        else:
            safe_row["preview_background_file"] = safe_pointer

        result = _original_resolve_one(conn, safe_row, drive_root, drive_root_text)

        # Preserve the actual stored pointer in the report while making it
        # explicit that SourceDocs itself was never traversed.
        result.scene_background_file = raw_pointer
        result.exact_pointer_resolves = False
        result.warnings = [
            warning
            for warning in result.warnings
            if warning != "Exact BackgroundFile pointer does not currently resolve."
        ]
        result.warnings.insert(
            0,
            "BackgroundFile pointer enters SourceDocs. Traversal was blocked before "
            f"SourceDocs; source content was not accessed. Allowed path evidence: {safe_pointer}",
        )
        result.resolution_basis = "SourceDocs boundary enforced. " + result.resolution_basis
    else:
        result = _original_resolve_one(conn, row, drive_root, drive_root_text)

    result = recover_stale_stage_anchor(result, safe_pointer, drive_root)
    return enforce_structural_markers(result)


# The base resolver dynamically uses these module globals, so patch them before
# running main().
base.make_candidate = marked_make_candidate
base.resolve_one = guarded_resolve_one


if __name__ == "__main__":
    try:
        raise SystemExit(base.main())
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)
