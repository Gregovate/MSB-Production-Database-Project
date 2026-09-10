from __future__ import annotations

from pathlib import Path

import setup_material_resolution as material_resolution
from setup_material_resolution import (
    classify_lor_group,
    is_real_setup_scene,
    is_stage_level_lor_group,
)


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_folder_alignment_classification_examples_are_preserved() -> None:
    assert classify_lor_group("Root")[0] == "ROOT"
    assert classify_lor_group("Goal Sign")[0] == "DISPLAY_GROUP"
    assert classify_lor_group("Making Spirits Bright")[0] == "DISPLAY_GROUP"
    assert classify_lor_group("Open-Close Sign")[0] == "DISPLAY_GROUP"
    assert classify_lor_group("RotaryGear-01")[0] == "DISPLAY_GROUP"
    assert classify_lor_group("TuneRadio-2CH-01")[0] == "DISPLAY_GROUP"
    assert classify_lor_group("16-Northern Lights-NL")[0] == "STAGE_ROOT"
    assert classify_lor_group("03a-Mega Cube-MC")[0] == "SUB_STAGE"
    assert classify_lor_group("01-Entrance Arch")[0] == "SCENE"
    assert classify_lor_group("01-Front Gate")[0] == "SCENE"
    assert classify_lor_group("02-Volunteer Path Lights")[0] == "SCENE"
    assert classify_lor_group("02-Fred's Stars")[0] == "SCENE"
    assert classify_lor_group("02-Mega Tree")[0] == "SCENE"
    assert classify_lor_group("13-Christmas Story")[0] == "SCENE"


def test_only_true_child_scene_names_become_setup_scene_scopes() -> None:
    for name in (
        "01-Entrance Arch",
        "01-Front Gate",
        "02-Volunteer Path Lights",
        "02-Fred's Stars",
        "02-Mega Tree",
        "13-Christmas Story",
    ):
        assert is_real_setup_scene(name)
        assert not is_stage_level_lor_group(name)

    for name in (
        "Root",
        "Goal Sign",
        "Making Spirits Bright",
        "Open-Close Sign",
        "RotaryGear-01",
        "TuneRadio-2CH-01",
        "16-Northern Lights-NL",
        "03a-Mega Cube-MC",
    ):
        assert not is_real_setup_scene(name)
        assert is_stage_level_lor_group(name)


def test_execution_rows_preserve_real_scenes_and_hide_programming_groups(monkeypatch) -> None:
    rows = [
        {
            "setup_session_task_id": 1,
            "setup_task_id": 1,
            "stage_id": 2,
            "lor_scene_id": 253,
            "scene_name": "01-Entrance Arch",
        },
        {
            "setup_session_task_id": 2,
            "setup_task_id": 108,
            "stage_id": 2,
            "lor_scene_id": 9001,
            "scene_name": "Goal Sign",
        },
    ]
    monkeypatch.setattr(
        material_resolution,
        "_ORIGINAL_EXECUTION_TASKS",
        lambda _self, _year: rows,
    )

    normalized = material_resolution._execution_tasks(object(), 2025)
    assert normalized[0]["lor_scene_id"] == 253
    assert normalized[0]["scene_name"] == "01-Entrance Arch"
    assert normalized[1]["source_lor_scene_id"] == 9001
    assert normalized[1]["lor_scene_id"] is None
    assert normalized[1]["scene_name"] is None


def test_schedule_rows_use_the_same_real_scene_normalization(monkeypatch) -> None:
    monkeypatch.setattr(
        material_resolution,
        "_ORIGINAL_SCHEDULE",
        lambda _self, _year: {
            "work_days": [{"setup_work_day_id": 1}],
            "assignments": [
                {
                    "setup_session_task_id": 1,
                    "stage_id": 2,
                    "lor_scene_id": 254,
                    "scene_name": "01-Front Gate",
                },
                {
                    "setup_session_task_id": 2,
                    "stage_id": 2,
                    "lor_scene_id": 9002,
                    "scene_name": "Making Spirits Bright",
                },
            ],
        },
    )

    normalized = material_resolution._schedule(object(), 2025)
    assert normalized["assignments"][0]["scene_name"] == "01-Front Gate"
    assert normalized["assignments"][1]["lor_scene_id"] is None
    assert normalized["assignments"][1]["scene_name"] is None


def test_material_requirement_migration_is_one_boolean_not_source_selector() -> None:
    sql = (DB_DIR / "025_add_setup_display_material_requirement.sql").read_text(encoding="utf-8")
    assert "requires_display_material boolean" in sql
    assert "DEFAULT false" in sql or "SET DEFAULT false" in sql
    assert "ref.set_setup_task_display_material_requirement" in sql
    assert "ref.setup_management_actor" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_material_requirement" in sql
    assert "GRANT SELECT ON TABLE ref.display_status TO fieldwiring_app" in sql
    assert "LOR_STAGE" not in sql
    assert "LOR_PREVIEW" not in sql
    assert "LOR_SCENE" not in sql
    assert "material_source" not in sql.casefold()


def test_production_host_installs_automatic_material_extension() -> None:
    text = (APP_DIR / "production_backend.py").read_text(encoding="utf-8")
    assert "install_setup_material_resolution()" in text
    assert "app.register_blueprint(setup_material_api)" in text


def test_material_ui_is_checkbox_only_and_has_no_source_chooser() -> None:
    text = (APP_DIR / "setup_catalog_effort.js").read_text(encoding="utf-8")
    rejected_selector = "Choose current LOR " + "material source"
    assert "Uses Display / Container Material" in text
    assert "Resolved automatically from LOR" in text
    assert "requires_display_material" in text
    assert "setup-material-task" in text
    assert rejected_selector not in text
    assert "LOR_PREVIEW" not in text
    assert "LOR_STAGE" not in text
