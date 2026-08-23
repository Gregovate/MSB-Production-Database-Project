from __future__ import annotations

from pathlib import Path

from field_context_resolver import (
    DEFAULT_STAGE_FALLBACK_WARNING,
    MARKER_NAME,
    resolve_structured_scope,
)


WINDOWS_ROOT = r"G:\Shared drives\Display Folders"


def _mark(path: Path, text: str = "marker") -> Path:
    path.mkdir(parents=True, exist_ok=True)
    (path / MARKER_NAME).write_text(text, encoding="utf-8")
    return path


def test_windows_path_translation_resolves_exact_marked_scene(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    scene_root = _mark(stage_root / "15-Church-CH")
    background = scene_root / "PreviewBackground"
    background.mkdir()
    (background / "Church Context.jpg").write_bytes(b"jpeg")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {
            "stage_key": "15",
            "folder_path": WINDOWS_ROOT + r"\15-Church",
        },
        {
            "scene_name": "15-Church-CH",
            "scene_background_file": (
                WINDOWS_ROOT
                + r"\15-Church\15-Church-CH\PreviewBackground\Church Context.jpg"
            ),
        },
        {"preview_background_file": None},
        drive_root,
        windows_drive_root=WINDOWS_ROOT,
    )

    assert scope_type == "SCENE"
    assert scope_root == scene_root
    assert warnings == []


def test_stale_stage_path_recovers_from_exact_path_evidence(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    background = stage_root / "PreviewBackground"
    background.mkdir()
    pointer = background / "Context.jpg"
    pointer.write_bytes(b"jpeg")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {
            "stage_key": "15",
            "folder_path": str(drive_root / "15-Old-Church"),
        },
        {"scene_name": "Root", "scene_background_file": str(pointer)},
        {"preview_background_file": None},
        drive_root,
    )

    assert scope_type == "STAGE"
    assert scope_root == stage_root
    assert warnings == [
        "Persisted Stage folder_path was unavailable or stale; current marked Stage root was recovered from exact LOR path evidence."
    ]


def test_sourcedocs_is_truncated_and_preserves_existing_scope_classification(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    source_docs = stage_root / "Procedures" / "Setup" / "SourceDocs"
    hidden_scene = _mark(source_docs / "15-Church-CH")
    pointer = hidden_scene / "legacy.pdf"
    pointer.write_bytes(b"pdf")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": str(pointer)},
        {"preview_background_file": None},
        drive_root,
    )

    # Production FieldWiring already canonicalizes 15-Church-CH to include
    # 15-Church. After SourceDocs is truncated to Procedures/Setup, upward
    # matching reaches the marked 15-Church Stage root and classifies that same
    # path as SCENE. Preserve that classification during extraction; changing
    # it here would redesign resolver behavior rather than extract it.
    assert scope_type == "SCENE"
    assert scope_root == stage_root
    assert warnings == [
        "BackgroundFile path enters SourceDocs. Traversal stopped before SourceDocs; source content was not accessed."
    ]


def test_stale_scene_pointer_uses_one_deterministic_marked_scene(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    scene_root = _mark(stage_root / "15-Church-CH")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {
            "scene_name": "15-Church-CH",
            "scene_background_file": str(stage_root / "old" / "missing.jpg"),
        },
        {"preview_background_file": None},
        drive_root,
    )

    assert scope_type == "SCENE"
    assert scope_root == scene_root
    assert warnings == [
        "Stored Scene BackgroundFile did not resolve exactly; one deterministic marked current Scene folder was used."
    ]


def test_ambiguous_marked_scene_matches_are_rejected(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    _mark(stage_root / "Area-A" / "15-Church-CH")
    _mark(stage_root / "Area-B" / "15-Church-CH")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": None},
        {"preview_background_file": None},
        drive_root,
    )

    assert scope_type == "UNRESOLVED"
    assert scope_root is None
    assert warnings == [
        "More than one marked Scene folder matched the current Scene identity."
    ]


def test_exact_unmarked_scene_pointer_is_rejected(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    scene_root = stage_root / "15-Church-CH"
    scene_root.mkdir()
    pointer = scene_root / "Context.jpg"
    pointer.write_bytes(b"jpeg")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": str(pointer)},
        {"preview_background_file": None},
        drive_root,
    )

    assert scope_type == "UNRESOLVED"
    assert scope_root is None
    assert warnings == [
        f"Scene source-folder marker is missing: {scene_root / MARKER_NAME}"
    ]


def test_unmarked_bounded_scene_match_is_rejected_without_stage_fallback(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    scene_root = stage_root / "15-Church-CH"
    scene_root.mkdir()

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": None},
        {"preview_background_file": None},
        drive_root,
    )

    assert scope_type == "UNRESOLVED"
    assert scope_root is None
    assert warnings == [
        "Matching Scene folder exists but is not an approved marked source root: "
        + str(scene_root)
    ]


def test_scene_matching_remains_bounded_to_two_levels(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    _mark(stage_root / "one" / "two" / "15-Church-CH")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": None},
        {"preview_background_file": None},
        drive_root,
    )

    assert scope_type == "STAGE"
    assert scope_root == stage_root
    assert warnings == [DEFAULT_STAGE_FALLBACK_WARNING]


def test_direct_owner_hint_is_generic_and_preserves_caller_warning(tmp_path):
    drive_root = tmp_path / "Display Folders"
    stage_root = _mark(drive_root / "15-Church")
    task_root = stage_root / "TaskBranch"
    task_root.mkdir()
    artifact = task_root / "artifact.dat"
    artifact.write_bytes(b"x")

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": str(artifact)},
        {"preview_background_file": None},
        drive_root,
        direct_owner_folder_name="TaskBranch",
        direct_owner_warning="caller-specific direct-owner warning",
    )

    assert scope_type == "STAGE"
    assert scope_root == stage_root
    assert warnings == ["caller-specific direct-owner warning"]


def test_missing_stage_anchor_fails_visibly_without_guessing(tmp_path):
    drive_root = tmp_path / "Display Folders"
    drive_root.mkdir()
    missing = drive_root / "15-Missing"

    scope_root, scope_type, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(missing)},
        {"scene_name": "Root", "scene_background_file": None},
        {"preview_background_file": None},
        drive_root,
    )

    assert scope_type == "UNRESOLVED"
    assert scope_root is None
    assert warnings == [
        f"Stage folder_path is unavailable or unmarked on this server: {missing}"
    ]
