from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path

import pytest

from wiring_common import WiringError
from wiring_dmx_source import replace_legacy_dmx_rows


class SQLiteSnapshotRepository:
    def __init__(self, path: Path):
        self.path = path

    @contextmanager
    def connect(self):
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()


def make_snapshot(path: Path, *, source_detail: bool = True) -> None:
    conn = sqlite3.connect(path)
    source_columns = """
        , raw_prop_id TEXT
        , channel_name TEXT
        , channel_grid_row_number INTEGER
    """ if source_detail else ""
    conn.executescript(f"""
        CREATE TABLE ref__display (
            display_id INTEGER PRIMARY KEY,
            display_name TEXT,
            lor_prop_id TEXT,
            display_status_id INTEGER
        );
        CREATE TABLE lor_snap__v_current_props (
            preview_id TEXT,
            prop_id TEXT,
            raw_prop_id TEXT,
            lor_comment TEXT,
            string_type TEXT,
            device_type TEXT,
            tag TEXT
        );
        CREATE TABLE lor_snap__v_current_scene_lor_props (
            preview_id TEXT,
            scene_id TEXT,
            prop_id TEXT,
            raw_prop_id TEXT
        );
        CREATE TABLE lor_snap__v_current_dmx_channels (
            import_run_id INTEGER,
            int_dmx_channel_id INTEGER,
            prop_id TEXT,
            network TEXT,
            start_universe INTEGER,
            start_channel INTEGER,
            end_channel INTEGER,
            unknown TEXT,
            preview_id TEXT
            {source_columns}
        );
    """)
    conn.execute(
        "INSERT INTO ref__display VALUES (956, 'NL-Downspots', 'canonical-raw', 1)"
    )
    conn.execute(
        "INSERT INTO lor_snap__v_current_props VALUES "
        "('preview-1','canonical-prop','canonical-raw','NL-Downspots','DumbRGB','DMX','NL')"
    )
    conn.execute(
        "INSERT INTO lor_snap__v_current_scene_lor_props VALUES "
        "('preview-1','scene-1','canonical-prop','canonical-raw')"
    )
    if source_detail:
        for ordinal, channel in enumerate((1, 2, 3), 1):
            conn.execute(
                "INSERT INTO lor_snap__v_current_dmx_channels VALUES "
                "(51,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    ordinal,
                    'canonical-prop',
                    'Regular',
                    145,
                    channel,
                    channel,
                    '',
                    'preview-1',
                    'source-fixture-raw',
                    'NL DS RGB 01',
                    ordinal,
                ),
            )
    else:
        conn.execute(
            "INSERT INTO lor_snap__v_current_dmx_channels VALUES "
            "(51,1,'canonical-prop','Regular',145,1,1,'','preview-1')"
        )
    conn.commit()
    conn.close()


def legacy_dmx_row() -> dict[str, object]:
    return {
        'display_id': 956,
        'display_name': 'NL-Downspots',
        'channel_name': 'canonical master name',
        'network': 'Regular',
        'controller': '145',
        'start_channel': 1,
        'end_channel': 1,
        'device_type': 'DMX',
        'string_type': 'DumbRGB',
        'source': 'DMX',
        'lor_tag': 'NL',
        'connection_type': 'FIELD',
        'cross_display': 0,
    }


def test_v7011_replaces_legacy_dmx_with_atomic_source_rows(tmp_path: Path) -> None:
    db = tmp_path / 'fieldwiring.db'
    make_snapshot(db)
    rows = replace_legacy_dmx_rows(
        SQLiteSnapshotRepository(db),
        [legacy_dmx_row()],
        preview_uuid='preview-1',
        scene_uuid='scene-1',
        scene_scope=True,
        parser_version='V7.0.11',
    )

    assert len(rows) == 3
    assert [row['channel_name'] for row in rows] == ['NL DS RGB 01'] * 3
    assert [row['channel_grid_row_number'] for row in rows] == [1, 2, 3]
    assert [row['start_channel'] for row in rows] == [1, 2, 3]
    assert {row['source_raw_prop_id'] for row in rows} == {'source-fixture-raw'}
    assert {row['canonical_raw_prop_id'] for row in rows} == {'canonical-raw'}
    assert {row['display_id'] for row in rows} == {956}
    assert all(row['source'] == 'DMX_SOURCE' for row in rows)


def test_source_raw_prop_id_is_not_required_to_match_permanent_display_link(tmp_path: Path) -> None:
    db = tmp_path / 'fieldwiring.db'
    make_snapshot(db)
    rows = replace_legacy_dmx_rows(
        SQLiteSnapshotRepository(db),
        [legacy_dmx_row()],
        preview_uuid='preview-1',
        scene_uuid=None,
        scene_scope=False,
        parser_version='V7.0.11',
    )

    assert {row['canonical_raw_prop_id'] for row in rows} == {'canonical-raw'}
    assert {row['source_raw_prop_id'] for row in rows} == {'source-fixture-raw'}
    assert {row['display_id'] for row in rows} == {956}


def test_v7011_fails_closed_when_snapshot_lacks_source_detail_columns(tmp_path: Path) -> None:
    db = tmp_path / 'fieldwiring.db'
    make_snapshot(db, source_detail=False)

    with pytest.raises(WiringError, match='Regenerate the FieldWiring snapshot'):
        replace_legacy_dmx_rows(
            SQLiteSnapshotRepository(db),
            [legacy_dmx_row()],
            preview_uuid='preview-1',
            scene_uuid='scene-1',
            scene_scope=True,
            parser_version='V7.0.11',
        )


def test_pre_v7011_snapshot_keeps_legacy_dmx_when_source_detail_is_unavailable(tmp_path: Path) -> None:
    db = tmp_path / 'fieldwiring.db'
    make_snapshot(db, source_detail=False)
    legacy = legacy_dmx_row()

    rows = replace_legacy_dmx_rows(
        SQLiteSnapshotRepository(db),
        [legacy],
        preview_uuid='preview-1',
        scene_uuid='scene-1',
        scene_scope=True,
        parser_version='V7.0.10',
    )

    assert rows == [legacy]
