from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path

from field_context_hierarchy import build_field_hierarchy
from wiring_data import load_wiring_data


def _context(preview_uuid: str, preview_name: str, stage_key: str = "01"):
    return {
        "preview": {
            "preview_uuid": preview_uuid,
            "preview_name": preview_name,
            "preview_background_file": (
                rf"G:\Shared drives\Display Folders\{stage_key}-Front Entrance-FE"
                rf"\PreviewBackground\{preview_uuid}.jpg"
            ),
        },
        "scene": {
            "scene_uuid": f"scene-{preview_uuid}",
            "scene_name": "Root",
            "scene_stage_key": stage_key,
            "scene_background_file": None,
        },
        "scope_kind": "Scene",
        "context_type": "Background Wiring",
    }


def _stage(contexts):
    return {
        "stage": {
            "stage_id": 31,
            "stage_key": "01",
            "stage_name": "Show Background Stage 01 Front Entrance",
            "folder_path": r"G:\Shared drives\Display Folders\01-Front Entrance-FE",
        },
        "contexts": list(contexts),
    }


def test_one_physical_stage_retains_multiple_preview_contexts():
    preview_names = [
        "Show Background Stage 01 FE Goal Sign",
        "Show Background Stage 01 FE MSB Sign",
        "Show Background Stage 01 FE Open-Close Sign",
        "Show Background Stage 01 FE Outside Gate",
    ]
    result = build_field_hierarchy(
        [_stage([_context(f"preview-{index}", name) for index, name in enumerate(preview_names, 1)])]
    )

    assert len(result["stages"]) == 1
    stage = result["stages"][0]
    assert stage["stage_key"] == "01"
    assert stage["scenes"] == []
    assert [item["preview_name"] for item in stage["contexts"]] == preview_names
    assert [item["preview_uuid"] for item in stage["contexts"]] == [
        "preview-1",
        "preview-2",
        "preview-3",
        "preview-4",
    ]
    assert all(item["scope_kind"] == "Stage / Preview" for item in stage["contexts"])


def test_browser_contract_exposes_preview_name_only_for_multi_preview_whole_scope():
    source = (Path(__file__).resolve().parent / "fieldwiring.js").read_text(encoding="utf-8")

    assert "const multipleWholePreviews = wholeContexts.length > 1;" in source
    assert "multipleWholePreviews && context.preview_name ? context.preview_name : ownerLabel" in source
    assert "multipleWholePreviews\n        ? 'Preview'" in source
    assert "if (c.preview_name) rows.push(['Preview', c.preview_name]);" in source
    assert "params.set('preview_uuid', c.preview_uuid);" in source


class SQLiteSnapshotRepository:
    def __init__(self, path):
        self.path = path

    @contextmanager
    def connect(self):
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()


def test_same_stage_preview_selection_loads_only_selected_preview_wiring(tmp_path):
    path = tmp_path / "multi_preview.db"
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE lor_snap__v_current_previews (
            import_run_id INTEGER, id TEXT, name TEXT, revision TEXT,
            background_file TEXT, source_filename TEXT
        );
        CREATE TABLE ref__stage (
            stage_id INTEGER PRIMARY KEY, stage_key TEXT, stage_name TEXT,
            folder_path TEXT
        );
        CREATE TABLE ref__display (
            display_id INTEGER PRIMARY KEY, display_name TEXT, stage_id INTEGER,
            lor_prop_id TEXT, display_status_id INTEGER
        );
        CREATE TABLE lor_snap__v_current_props (
            preview_id TEXT, prop_id TEXT, raw_prop_id TEXT, lor_comment TEXT,
            string_type TEXT, device_type TEXT
        );
        CREATE TABLE lor_snap__preview_wiring_fieldlead_v6 (
            preview_name TEXT, source TEXT, channel_name TEXT, display_name TEXT,
            network TEXT, controller TEXT, start_channel INTEGER, end_channel INTEGER,
            color TEXT, device_type TEXT, lor_tag TEXT, connection_type TEXT,
            cross_display INTEGER, lead_rank INTEGER
        );
        CREATE TABLE lor_snap__v_current_run (
            import_run_id INTEGER, run_ts TEXT, parser_version TEXT,
            parser_completed_at TEXT, source_preview_folder TEXT,
            ingest_script_version TEXT, ingest_completed_at TEXT
        );
        CREATE TABLE lor_snap__v_current_scenes (
            preview_id TEXT, scene_id TEXT, name TEXT, stage_id TEXT,
            background_file TEXT
        );
        CREATE TABLE lor_snap__v_current_scene_lor_props (
            preview_id TEXT, scene_id TEXT, prop_id TEXT, raw_prop_id TEXT
        );

        INSERT INTO lor_snap__v_current_previews VALUES
            (52, 'preview-goal', 'Show Background Stage 01 FE Goal Sign', '1', NULL, 'goal.lorprev'),
            (52, 'preview-open', 'Show Background Stage 01 FE Open-Close Sign', '1', NULL, 'open.lorprev');
        INSERT INTO lor_snap__v_current_run
            VALUES (52, 'x', 'V7.0.11', 'x', 'folder', 'V0.4.2', 'x');
        INSERT INTO ref__stage
            VALUES (31, '01', 'Front Entrance', '01-Front Entrance-FE');

        INSERT INTO ref__display VALUES
            (101, 'FE-GoalSign', 31, 'raw-goal', 1),
            (102, 'FE-OpenCloseSign', 31, 'raw-open', 1);

        INSERT INTO lor_snap__v_current_props VALUES
            ('preview-goal', 'p-goal', 'raw-goal', 'FE-GoalSign', 'Traditional', 'LOR'),
            ('preview-open', 'p-open', 'raw-open', 'FE-OpenCloseSign', 'Traditional', 'LOR');

        INSERT INTO lor_snap__preview_wiring_fieldlead_v6 VALUES
            ('Show Background Stage 01 FE Goal Sign', 'PROP', 'Goal', 'FE-GoalSign',
             'Regular', '01', 1, 1, NULL, 'LOR', '', 'FIELD', 0, 1),
            ('Show Background Stage 01 FE Open-Close Sign', 'PROP', 'Open', 'FE-OpenCloseSign',
             'Regular', '02', 1, 1, NULL, 'LOR', '', 'FIELD', 0, 1);
        """
    )
    conn.commit()
    conn.close()

    goal = load_wiring_data(SQLiteSnapshotRepository(path), "preview-goal", None, 31)
    opened = load_wiring_data(SQLiteSnapshotRepository(path), "preview-open", None, 31)

    assert goal["preview"]["preview_uuid"] == "preview-goal"
    assert [row["display_name"] for row in goal["rows"]] == ["FE-GoalSign"]

    assert opened["preview"]["preview_uuid"] == "preview-open"
    assert [row["display_name"] for row in opened["rows"]] == ["FE-OpenCloseSign"]
