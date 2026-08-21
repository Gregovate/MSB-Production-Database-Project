from pathlib import Path

from wiring_common import MARKER_NAME
from wiring_images import resolve_images


def _stage(root: Path) -> Path:
    stage = root / "15-Church"
    stage.mkdir()
    (stage / MARKER_NAME).write_text("stage", encoding="utf-8")
    wiring = stage / "Wiring"
    wiring.mkdir()
    (wiring / MARKER_NAME).write_text("wiring", encoding="utf-8")
    musical = wiring / "MusicalStage"
    musical.mkdir()
    (musical / "church.png").write_bytes(b"x")
    background = wiring / "BackgroundStage"
    background.mkdir()
    (background / "church-background.png").write_bytes(b"x")
    return stage


def test_no_distinct_scene_folder_retains_stage_scope(tmp_path, monkeypatch):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    monkeypatch.setenv("FIELDWIRING_DRIVE_ROOT", str(root))

    result = resolve_images(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": None},
        {"preview_background_file": None},
        "Musical",
    )

    assert result["scope_type"] == "STAGE"
    assert result["scope_root"] == str(stage_root)
    assert [image["name"] for image in result["wiring_images"]] == ["church.png"]
    assert any("stage root retained" in warning.lower() for warning in result["warnings"])


def test_direct_wiring_pointer_resolves_stage_owner_while_context_selects_branch(tmp_path, monkeypatch):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    monkeypatch.setenv("FIELDWIRING_DRIVE_ROOT", str(root))

    direct_pointer = stage_root / "Wiring" / "MusicalStage" / "church.png"
    stage = {"stage_key": "15", "folder_path": str(stage_root)}
    scene = {
        "scene_name": "15-Church-CH",
        "scene_background_file": str(direct_pointer),
    }
    preview = {"preview_background_file": None}

    musical_result = resolve_images(stage, scene, preview, "Musical")
    assert musical_result["scope_type"] == "STAGE"
    assert musical_result["scope_root"] == str(stage_root)
    assert [image["name"] for image in musical_result["wiring_images"]] == ["church.png"]

    background_result = resolve_images(stage, scene, preview, "Background / Static")
    assert background_result["scope_type"] == "STAGE"
    assert background_result["scope_root"] == str(stage_root)
    assert [image["name"] for image in background_result["wiring_images"]] == ["church-background.png"]


def test_unmarked_matching_scene_does_not_fall_back_to_stage(tmp_path, monkeypatch):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    (stage_root / "15-Church-CH").mkdir()
    monkeypatch.setenv("FIELDWIRING_DRIVE_ROOT", str(root))

    result = resolve_images(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "15-Church-CH", "scene_background_file": None},
        {"preview_background_file": None},
        "Musical",
    )

    assert result["scope_type"] == "UNRESOLVED"
    assert result["scope_root"] is None
    assert result["wiring_images"] == []
    assert any("not an approved marked source root" in warning.lower() for warning in result["warnings"])
