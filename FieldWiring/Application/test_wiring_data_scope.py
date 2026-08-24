from __future__ import annotations

import sqlite3
from contextlib import contextmanager

from wiring_data import load_wiring_data


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


def test_whole_preview_package_is_bounded_to_resolved_stage(tmp_path):
    path = tmp_path / "scope.db"
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

        INSERT INTO lor_snap__v_current_previews
        VALUES (51, 'shared-preview', 'Shared Master Preview', '1', NULL, 'shared.lorprev');
        INSERT INTO lor_snap__v_current_run
        VALUES (51, 'x', 'V7.0.11', 'x', 'folder', 'V0.4.2', 'x');

        INSERT INTO ref__stage VALUES (24, '24', 'Traditional Christmas', 'stage24');
        INSERT INTO ref__stage VALUES (25, '25', 'Other Stage', 'stage25');

        INSERT INTO ref__display VALUES (141, 'TC-ChristmasHippo', 24, 'raw-141', 1);
        INSERT INTO ref__display VALUES (999, 'OTHER-Display', 25, 'raw-999', 1);

        INSERT INTO lor_snap__v_current_props
        VALUES ('shared-preview', 'p141', 'raw-141', 'TC-ChristmasHippo', 'Traditional', 'LOR');
        INSERT INTO lor_snap__v_current_props
        VALUES ('shared-preview', 'p999', 'raw-999', 'OTHER-Display', 'Traditional', 'LOR');

        INSERT INTO lor_snap__preview_wiring_fieldlead_v6
        VALUES ('Shared Master Preview', 'PROP', 'Hippo', 'TC-ChristmasHippo',
                'Regular', '7B', 1, 1, NULL, 'LOR', '', 'FIELD', 0, 1);
        INSERT INTO lor_snap__preview_wiring_fieldlead_v6
        VALUES ('Shared Master Preview', 'PROP', 'Other', 'OTHER-Display',
                'Regular', '7C', 1, 1, NULL, 'LOR', '', 'FIELD', 0, 1);
        """
    )
    conn.commit()
    conn.close()

    package = load_wiring_data(
        SQLiteSnapshotRepository(path),
        "shared-preview",
        None,
        24,
    )

    assert package["scene"] is None
    assert [row["display_id"] for row in package["rows"]] == [141]
    assert [row["display_name"] for row in package["rows"]] == ["TC-ChristmasHippo"]
