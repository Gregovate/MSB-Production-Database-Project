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


def _file(path: Path, data: bytes = b"x") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def test_stage_previewbackground_resolves_stage_without_drive_scan(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    pointer = _file(stage / "PreviewBackground" / "Polar-Bear-Stage.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "Root", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == stage
    assert kind == "STAGE"
    assert warnings == []


def test_scene_previewbackground_walks_up_to_nearest_scene(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    scene = _mark(stage / "21-Sliding Penguins")
    pointer = _file(scene / "PreviewBackground" / "Sliding-Penguins.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "21-Sliding Penguins", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == scene
    assert kind == "SCENE"
    assert warnings == []


def test_display_previewbackground_under_scene_climbs_to_scene(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    scene = _mark(stage / "21-Sliding Penguins")
    display = scene / "PB-SlidingPenguins-07"
    pointer = _file(display / "PreviewBackground" / "Penguin-07.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "21-Sliding Penguins", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == scene
    assert kind == "SCENE"
    assert warnings == []


def test_display_previewbackground_directly_under_stage_climbs_to_stage(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    display = stage / "PB-MommaBear"
    pointer = _file(display / "PreviewBackground" / "MommaBear.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "PB-MommaBear", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == stage
    assert kind == "STAGE"
    assert warnings == []


def test_direct_scene_wiring_path_resolves_scene_then_task_adapter_owns_branch(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    scene = _mark(stage / "21-Sliding Penguins")
    pointer = _file(scene / "Wiring" / "BackgroundStage" / "Tagged.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "21-Sliding Penguins", "scene_background_file": str(pointer)},
        {},
        drive,
        direct_owner_folder_name="Wiring",
    )

    assert root == scene
    assert kind == "SCENE"
    assert warnings == []


def test_direct_stage_wiring_path_resolves_stage(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    pointer = _file(stage / "Wiring" / "MusicalStage" / "Tagged.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "21-Polar-Bear-Stage-PB", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == stage
    assert kind == "STAGE"
    assert warnings == []


def test_substage_path_resolves_substage_without_parent_stage_fallback(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "07-Whoville-WV")
    substage = _mark(stage / "07a-Who Forest-WF")
    pointer = _file(substage / "PreviewBackground" / "Who-Forest.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "07a", "folder_path": None},
        {"scene_name": "07a-Who Forest-WF", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == substage
    assert kind == "SUBSTAGE"
    assert warnings == [
        "Persisted Stage folder_path was unavailable or stale; current marked Stage root was recovered from exact LOR path evidence."
    ]


def test_stage_binding_master_scene_does_not_become_fake_child_scene(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "15-Church-Bells-CH")
    pointer = _file(stage / "PreviewBackground" / "Church.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "15", "folder_path": str(stage)},
        {"scene_name": "15-Church-CH", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == stage
    assert kind == "STAGE"
    assert warnings == []


def test_nested_legacy_scene_with_short_code_is_scene_when_path_says_child(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "03-Welcome Area-WA")
    scene = _mark(stage / "03-Mega Cube-MC")
    pointer = _file(scene / "PreviewBackground" / "Mega-Cube.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "03", "folder_path": str(stage)},
        {"scene_name": "03-Mega Cube-MC", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == scene
    assert kind == "SCENE"
    assert warnings == []


def test_sourcedocs_is_hard_boundary_but_allowed_ancestor_path_still_resolves(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    scene = _mark(stage / "21-Sliding Penguins")
    pointer = _file(
        scene / "Wiring" / "MusicalStage" / "SourceDocs" / "Working.jpg"
    )

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "21-Sliding Penguins", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == scene
    assert kind == "SCENE"
    assert warnings == [
        "BackgroundFile path enters SourceDocs. Traversal stopped before SourceDocs; source content was not accessed."
    ]


def test_stale_pointer_recovery_is_bounded_inside_known_stage(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "13-Winter Wonderland-WW")
    scene = _mark(stage / "13-Christmas Story")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "13", "folder_path": str(stage)},
        {
            "scene_name": "13-Christmas Story",
            "scene_background_file": str(stage / "old" / "missing.jpg"),
        },
        {},
        drive,
    )

    assert root == scene
    assert kind == "SCENE"
    assert warnings == [
        "Stored BackgroundFile did not resolve exactly; one deterministic marked current structured scope was used inside the known Stage."
    ]


def test_missing_scene_folder_falls_back_to_known_stage(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "21-Sliding Penguins", "scene_background_file": None},
        {},
        drive,
    )

    assert root == stage
    assert kind == "STAGE"
    assert warnings == [DEFAULT_STAGE_FALLBACK_WARNING]


def test_unmarked_exact_scene_is_not_silently_promoted(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = _mark(drive / "21-Polar Bear Playground-PB")
    scene = stage / "21-Sliding Penguins"
    pointer = _file(scene / "PreviewBackground" / "Sliding.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "21", "folder_path": str(stage)},
        {"scene_name": "21-Sliding Penguins", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root is None
    assert kind == "UNRESOLVED"
    assert warnings == [
        f"Structured source-folder marker is missing: {scene / MARKER_NAME}"
    ]


def test_stale_stage_path_recovers_only_from_supplied_pointer_not_root_enumeration(tmp_path):
    drive = tmp_path / "Display Folders"
    correct = _mark(drive / "17-Candyland-CL")
    _mark(drive / "17-Other-XX")
    pointer = _file(correct / "PreviewBackground" / "Candyland.jpg")

    root, kind, warnings = resolve_structured_scope(
        {"stage_key": "17", "folder_path": str(drive / "17-Candy Land-CL")},
        {"scene_name": "Root", "scene_background_file": str(pointer)},
        {},
        drive,
    )

    assert root == correct
    assert kind == "STAGE"
    assert warnings == [
        "Persisted Stage folder_path was unavailable or stale; current marked Stage root was recovered from exact LOR path evidence."
    ]
