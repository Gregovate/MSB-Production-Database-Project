from __future__ import annotations

import sqlite3
from pathlib import Path

from field_context_repository import SQLiteFieldContextRepository
from field_context_resolver import MARKER_NAME, resolve_structured_scope


def make_fixture(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE ref__display (
            display_id INTEGER PRIMARY KEY,
            display_name TEXT,
            stage_id INTEGER,
            lor_prop_id TEXT,
            display_status_id INTEGER
        );
        CREATE TABLE ref__stage (
            stage_id INTEGER PRIMARY KEY,
            stage_key TEXT,
            stage_name TEXT,
            folder_path TEXT,
            park_order INTEGER,
            sub_order INTEGER
        );
        CREATE TABLE lor_snap__v_current_props (
            raw_prop_id TEXT,
            device_type TEXT
        );
        CREATE TABLE lor_snap__v_display_lor_occurrence (
            display_name TEXT,
            preview_id TEXT,
            preview_name TEXT,
            preview_stage_id TEXT,
            scene_id TEXT,
            scene_name TEXT,
            scene_stage_id TEXT,
            location_type TEXT
        );
        CREATE TABLE lor_snap__v_current_previews (
            id TEXT,
            name TEXT,
            background_file TEXT,
            revision TEXT,
            source_filename TEXT
        );
        CREATE TABLE lor_snap__v_current_scenes (
            preview_id TEXT,
            scene_id TEXT,
            name TEXT,
            stage_id TEXT,
            background_file TEXT
        );

        INSERT INTO ref__stage VALUES (15, '15', 'Church', '/drive/15-Church', 15, 0);
        INSERT INTO ref__stage VALUES (20, '20', 'Steel Arches', '/drive/20-Steel-Arches', 20, 0);

        INSERT INTO ref__display VALUES (309, 'CH-RGBCandyCane-01', 15, 'lor-309', 1);
        INSERT INTO ref__display VALUES (323, 'CH-SteelArch-01', 15, 'lor-323', 1);
        INSERT INTO ref__display VALUES (400, 'SA-SteelArch-InventoryOnly', 20, NULL, 1);
        INSERT INTO ref__display VALUES (401, 'SA-Retired-Arch', 20, NULL, 3);

        INSERT INTO lor_snap__v_current_props VALUES ('lor-309', 'LOR');
        INSERT INTO lor_snap__v_current_props VALUES ('lor-323', 'None');

        INSERT INTO lor_snap__v_current_previews VALUES (
            'preview-musical','2026 Master Musical Preview','G:/Shared drives/Display Folders/15-Church/bg.jpg','7','master.lorprev'
        );
        INSERT INTO lor_snap__v_current_scenes VALUES (
            'preview-musical','scene-church','15-Church-CH','15','G:/Shared drives/Display Folders/15-Church/scene.jpg'
        );

        INSERT INTO lor_snap__v_display_lor_occurrence VALUES (
            'CH-RGBCandyCane-01','preview-musical','2026 Master Musical Preview','15',
            'scene-church','15-Church-CH','15','SCENE'
        );
        INSERT INTO lor_snap__v_display_lor_occurrence VALUES (
            'CH-SteelArch-01','preview-musical','2026 Master Musical Preview','15',
            'scene-church','15-Church-CH','15','SCENE'
        );
        """
    )
    conn.commit()
    conn.close()


def repo(tmp_path: Path) -> SQLiteFieldContextRepository:
    path = tmp_path / "field-context.db"
    make_fixture(path)
    return SQLiteFieldContextRepository(path)


def test_shared_search_includes_wired_and_inventory_only_pattern_matches(tmp_path):
    rows = repo(tmp_path).search_displays("CH-")
    assert [row["display_id"] for row in rows] == [309, 323]


def test_inventory_only_display_with_lor_scene_still_resolves_context(tmp_path):
    context = repo(tmp_path).display_context(323)
    assert context is not None
    assert context["display_name"] == "CH-SteelArch-01"
    assert context["stage"]["stage_key"] == "15"
    assert context["stage"]["folder_path"] == "/drive/15-Church"
    assert len(context["contexts"]) == 1
    candidate = context["contexts"][0]
    assert candidate["scene"]["scene_name"] == "15-Church-CH"
    assert candidate["preview"]["preview_uuid"] == "preview-musical"
    assert candidate["context_type"] == "Musical"


def test_inventory_only_display_without_lor_prop_still_resolves_stage(tmp_path):
    context = repo(tmp_path).display_context(400)
    assert context is not None
    assert context["display_name"] == "SA-SteelArch-InventoryOnly"
    assert context["stage"]["stage_key"] == "20"
    assert context["stage"]["folder_path"] == "/drive/20-Steel-Arches"
    assert context["contexts"] == []


def test_inventory_only_display_reaches_shared_structured_scope(tmp_path):
    shared_repo = repo(tmp_path)
    drive_root = tmp_path / "Display Folders"
    stage_root = drive_root / "20-Steel-Arches"
    stage_root.mkdir(parents=True)
    (stage_root / MARKER_NAME).write_text("stage", encoding="utf-8")

    with sqlite3.connect(shared_repo.path) as conn:
        conn.execute(
            "UPDATE ref__stage SET folder_path = ? WHERE stage_id = 20",
            (str(stage_root),),
        )
        conn.commit()

    context = shared_repo.display_context(400)
    assert context is not None
    scope_root, scope_type, warnings = resolve_structured_scope(
        context["stage"],
        None,
        {},
        drive_root,
    )
    assert scope_root == stage_root
    assert scope_type == "STAGE"
    assert warnings == []


def test_retired_display_is_not_shared_current_context(tmp_path):
    assert repo(tmp_path).display_context(401) is None


def test_shared_stage_browse_does_not_require_wiring(tmp_path):
    stages = repo(tmp_path).stages()
    steel = next(item for item in stages if item["stage"]["stage_key"] == "20")
    assert steel["stage"]["stage_name"] == "Steel Arches"
    assert steel["contexts"] == []
