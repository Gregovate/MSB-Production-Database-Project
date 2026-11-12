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
    assert result["warnings"] == [
        "No distinct Scene folder matched the current Scene identity; known marked Stage root retained as the FieldWiring scope."
    ]
    assert result["operator_warnings"] == []


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
    assert musical_result["warnings"] == [
        "BackgroundFile points directly into the current Stage Wiring branch; the marked Stage root is the FieldWiring documentation scope."
    ]
    assert musical_result["operator_warnings"] == []

    background_result = resolve_images(stage, scene, preview, "Background / Static")
    assert background_result["scope_type"] == "STAGE"
    assert background_result["scope_root"] == str(stage_root)
    assert [image["name"] for image in background_result["wiring_images"]] == ["church-background.png"]
    assert background_result["warnings"] == musical_result["warnings"]
    assert background_result["operator_warnings"] == []


def test_unmarked_matching_scene_does_not_fall_back_to_stage(tmp_path, monkeypatch):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    scene_root = stage_root / "15-Church-CH"
    scene_root.mkdir()
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
    assert result["warnings"] == [
        "Matching Scene folder exists but is not an approved marked source root: "
        + str(scene_root)
    ]
    assert len(result["operator_warnings"]) == 1
    assert "LOR_CONTEXT" not in result["operator_warnings"][0]
    assert "15-Church-CH" in result["operator_warnings"][0]
    assert result["operator_warnings"][0].endswith(
        str(scene_root / "Wiring" / "MusicalStage") + "."
    )


def test_missing_wiring_image_reports_exact_selected_branch(tmp_path, monkeypatch):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    (stage_root / "Wiring" / "MusicalStage" / "church.png").unlink()
    monkeypatch.setenv("FIELDWIRING_DRIVE_ROOT", str(root))

    result = resolve_images(
        {"stage_key": "15", "folder_path": str(stage_root)},
        {"scene_name": "Root", "scene_background_file": None},
        {"preview_background_file": None},
        "Musical",
    )

    assert result["scope_type"] == "STAGE"
    assert result["wiring_images"] == []
    assert result["operator_warnings"] == [
        "Wiring not found for Stage 15 in folder "
        + str(stage_root / "Wiring" / "MusicalStage")
        + "."
    ]


def test_wiring_browser_uses_operator_notices_not_raw_resolver_warnings():
    base = Path(__file__).resolve().parent
    html = (base / "wiring.html").read_text(encoding="utf-8")
    js = (base / "wiring.js").read_text(encoding="utf-8")

    assert 'id="operator-notices"' in html
    assert "packageData.images?.operator_warnings" in js
    assert "renderOperatorNotices();" in js
    assert "packageData.images.warnings?.length" not in js


def test_wiring_images_delegates_structured_scope_to_shared_component():
    source = (Path(__file__).resolve().parent / "wiring_images.py").read_text(encoding="utf-8")

    assert "from field_context_resolver import resolve_structured_scope" in source
    assert "resolve_structured_scope(" in source
    assert "branch = \"MusicalStage\"" in source
    assert "scope_root / \"Wiring\" / branch" in source

    assert "def _resolve_scope_root" not in source
    assert "def _canonical_scene_names" not in source
    assert "def _bounded_scope_matches" not in source
    assert "def _recover_stage_root" not in source
    assert "def _truncate_before_sourcedocs" not in source
