from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path

import pytest

from wiring import MARKER_NAME, build_wiring_package


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

    def display_context(self, display_id: int):
        with self.connect() as conn:
            row = conn.execute(
                """
                SELECT d.display_id, d.display_name, d.stage_id,
                       o.preview_id AS preview_uuid, o.scene_id AS scene_uuid
                FROM ref__display d
                JOIN lor_snap__v_display_lor_occurrence o
                  ON o.display_name = d.display_name
                WHERE d.display_id = ? AND o.location_type='SCENE'
                LIMIT 1
                """,
                (display_id,),
            ).fetchone()
            return dict(row) if row else None


def make_db(path: Path, stage_path: str) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE ref__display (
          display_id INTEGER PRIMARY KEY, display_name TEXT, stage_id INTEGER,
          lor_prop_id TEXT, display_status_id INTEGER
        );
        CREATE TABLE ref__stage (
          stage_id INTEGER PRIMARY KEY, stage_key TEXT, stage_name TEXT,
          folder_path TEXT
        );
        CREATE TABLE lor_snap__v_current_previews (
          import_run_id INTEGER, id TEXT, name TEXT, revision TEXT,
          background_file TEXT, source_filename TEXT
        );
        CREATE TABLE lor_snap__v_current_scenes (
          preview_id TEXT, scene_id TEXT, name TEXT, stage_id TEXT,
          background_file TEXT
        );
        CREATE TABLE lor_snap__v_current_props (
          preview_id TEXT, prop_id TEXT, raw_prop_id TEXT, lor_comment TEXT,
          string_type TEXT, device_type TEXT
        );
        CREATE TABLE lor_snap__v_current_scene_lor_props (
          preview_id TEXT, scene_id TEXT, prop_id TEXT, raw_prop_id TEXT
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
        CREATE TABLE lor_snap__v_display_lor_occurrence (
          display_name TEXT, preview_id TEXT, preview_name TEXT,
          preview_stage_id TEXT, scene_id TEXT, scene_name TEXT,
          scene_stage_id TEXT, location_type TEXT
        );
        """
    )
    conn.execute("INSERT INTO ref__stage VALUES (45,'15','Church',?)", (stage_path,))
    conn.execute("INSERT INTO lor_snap__v_current_previews VALUES (99,'p1','Master Musical Preview','7',NULL,'master.lorprev')")
    conn.execute("INSERT INTO lor_snap__v_current_scenes VALUES ('p1','s1','15-Church-CH','15',NULL)")
    conn.execute("INSERT INTO lor_snap__v_current_run VALUES (99,'x','V7','x','folder','ingest','x')")
    conn.commit(); conn.close()


def add_display(conn, display_id, name, raw_id, controller, string_type='Traditional', device='LOR', channel=1, channel_name=None):
    prop_id = f'p-{display_id}'
    conn.execute("INSERT INTO ref__display VALUES (?,?,?,?,1)", (display_id,name,45,raw_id))
    conn.execute("INSERT INTO lor_snap__v_current_props VALUES ('p1',?,?,?,?,?)", (prop_id,raw_id,name,string_type,device))
    conn.execute("INSERT INTO lor_snap__v_current_scene_lor_props VALUES ('p1','s1',?,?)", (prop_id,raw_id))
    conn.execute("INSERT INTO lor_snap__v_display_lor_occurrence VALUES (?, 'p1','Master Musical Preview','15','s1','15-Church-CH','15','SCENE')", (name,))
    field_name = name.replace(' ','-')
    conn.execute(
        "INSERT INTO lor_snap__preview_wiring_fieldlead_v6 VALUES ('Master Musical Preview','PROP',?,?,?,?,?,?,NULL,?,?, 'FIELD',0,1)",
        (channel_name or name, field_name, 'Regular', controller, channel, channel, device, '')
    )


def test_scene_package_contains_all_scene_displays_and_preserves_space_identity(tmp_path, monkeypatch):
    db = tmp_path/'fw.db'; stage = tmp_path/'15-Church'; stage.mkdir()
    make_db(db, str(stage))
    conn = sqlite3.connect(db)
    add_display(conn, 1, 'Display One', 'r1', '01', channel=1)
    add_display(conn, 2, 'Display-Two', 'r2', '01', channel=2)
    conn.commit(); conn.close()
    monkeypatch.setenv('FIELDWIRING_DRIVE_ROOT', str(tmp_path))
    package = build_wiring_package(SQLiteSnapshotRepository(db), display_id=1)
    assert {r['display_id'] for r in package['rows']} == {1,2}
    assert next(r for r in package['rows'] if r['display_id']==1)['display_name'] == 'Display One'
    assert next(r for r in package['rows'] if r['display_id']==2)['physical_output'] == 2


def test_clean_repeated_pixie_block_derives_two_temporary_groups(tmp_path, monkeypatch):
    db = tmp_path/'fw.db'; stage = tmp_path/'15-Church'; stage.mkdir()
    make_db(db, str(stage))
    conn = sqlite3.connect(db)
    controllers = ['21','22','23','24','21','22','23','24']
    for i, controller in enumerate(controllers, 1):
        add_display(conn, 300+i, f'CH-RGBCandyCane-{i:02d}', f'r{i}', controller, string_type='RGB', channel=1)
    conn.commit(); conn.close()
    monkeypatch.setenv('FIELDWIRING_DRIVE_ROOT', str(tmp_path))
    package = build_wiring_package(SQLiteSnapshotRepository(db), display_id=301)
    pixie = [g for g in package['controller_groups'] if g['family']=='PIXIE']
    assert [g['name'] for g in pixie] == ['Pixie group 1','Pixie group 2']
    assert [r['physical_output'] for r in pixie[0]['rows']] == [1,2,3,4]
    assert [r['physical_output'] for r in pixie[1]['rows']] == [1,2,3,4]


def test_inconsistent_repeated_block_preserves_good_groups_and_flags_bad_block(tmp_path, monkeypatch):
    db = tmp_path/'fw.db'; stage = tmp_path/'17-Candyland'; stage.mkdir()
    make_db(db, str(stage))
    conn = sqlite3.connect(db)
    controllers = ['21','22','23','24','21','22','23','24','21','22','23','22']
    for i, controller in enumerate(controllers, 1):
        add_display(conn, 400+i, f'CL-RGBCandyCane-{i:02d}', f'c{i}', controller, string_type='RGB', channel=1)
    conn.commit(); conn.close()
    monkeypatch.setenv('FIELDWIRING_DRIVE_ROOT', str(tmp_path))
    package = build_wiring_package(SQLiteSnapshotRepository(db), display_id=401)

    by_name = {r['display_name']: r for r in package['rows']}
    first = [by_name[f'CL-RGBCandyCane-{i:02d}'] for i in range(1,5)]
    second = [by_name[f'CL-RGBCandyCane-{i:02d}'] for i in range(5,9)]
    third = [by_name[f'CL-RGBCandyCane-{i:02d}'] for i in range(9,13)]

    assert [r['controller_group'] for r in first] == ['Pixie group 1'] * 4
    assert [r['physical_output'] for r in first] == [1,2,3,4]
    assert [r['controller_group'] for r in second] == ['Pixie group 2'] * 4
    assert [r['physical_output'] for r in second] == [1,2,3,4]

    assert [r['controller'] for r in third] == ['21','22','23','22']
    assert all(r['controller_group'] is None for r in third)
    assert all(r['physical_output'] is None for r in third)
    assert all(r['controller_group_kind'] == 'address-pattern-review' for r in third)


def test_scene_does_not_borrow_stage_wiring_image(tmp_path, monkeypatch):
    root = tmp_path/'Display Folders'; root.mkdir()
    stage = root/'15-Church'; stage.mkdir(); (stage/MARKER_NAME).write_text('stage')
    scene = stage/'15-Church-CH'; scene.mkdir(); (scene/MARKER_NAME).write_text('scene')
    stage_wiring = stage/'Wiring'; stage_wiring.mkdir(); (stage_wiring/MARKER_NAME).write_text('wiring')
    (stage_wiring/'MusicalStage').mkdir(); (stage_wiring/'MusicalStage'/'stage.png').write_bytes(b'x')
    scene_wiring = scene/'Wiring'; scene_wiring.mkdir(); (scene_wiring/MARKER_NAME).write_text('wiring')
    (scene_wiring/'MusicalStage').mkdir()
    scene_bg = scene/'PreviewBackground'; scene_bg.mkdir(); (scene_bg/MARKER_NAME).write_text('bg')
    (scene_bg/'context.png').write_bytes(b'x')

    db = tmp_path/'fw.db'; make_db(db, str(stage))
    conn = sqlite3.connect(db); add_display(conn, 1, 'CH-Test', 'r1', '01'); conn.commit(); conn.close()
    monkeypatch.setenv('FIELDWIRING_DRIVE_ROOT', str(root))
    package = build_wiring_package(SQLiteSnapshotRepository(db), display_id=1)
    assert package['images']['scope_root'] == str(scene)
    assert package['images']['wiring_images'] == []
    assert [i['name'] for i in package['images']['context_images']] == ['context.png']


def test_display_context_rejects_mismatched_stage(tmp_path, monkeypatch):
    db = tmp_path/'fw.db'; stage = tmp_path/'15-Church'; stage.mkdir()
    make_db(db, str(stage))
    conn = sqlite3.connect(db); add_display(conn, 1, 'CH-Test', 'r1', '01'); conn.commit(); conn.close()
    monkeypatch.setenv('FIELDWIRING_DRIVE_ROOT', str(tmp_path))
    from wiring import WiringError
    with pytest.raises(WiringError, match='requested Stage context'):
        build_wiring_package(SQLiteSnapshotRepository(db), display_id=1, stage_id=999)


def test_report_expiration_is_end_of_generated_local_day(tmp_path, monkeypatch):
    db = tmp_path/'fw.db'; stage = tmp_path/'15-Church'; stage.mkdir()
    make_db(db, str(stage))
    conn = sqlite3.connect(db); add_display(conn, 1, 'CH-Test', 'r1', '01'); conn.commit(); conn.close()
    monkeypatch.setenv('FIELDWIRING_DRIVE_ROOT', str(tmp_path))
    package = build_wiring_package(SQLiteSnapshotRepository(db), display_id=1)
    assert package['provenance']['expires_at'].endswith('23:59:59+00:00') or 'T23:59:59' in package['provenance']['expires_at']
    assert 'newer approved wiring snapshot supersedes' in package['provenance']['expiration_rule'].lower()


def test_stale_stage_path_recovers_from_exact_marked_pointer(tmp_path, monkeypatch):
    root = tmp_path/'Display Folders'; root.mkdir()
    stage = root/'15-Church'; stage.mkdir(); (stage/MARKER_NAME).write_text('stage')
    scene = stage/'15-Church-CH'; scene.mkdir(); (scene/MARKER_NAME).write_text('scene')
    preview_bg = scene/'PreviewBackground'; preview_bg.mkdir(); (preview_bg/MARKER_NAME).write_text('bg')
    pointer = preview_bg/'context.png'; pointer.write_bytes(b'x')
    scene_wiring = scene/'Wiring'; scene_wiring.mkdir(); (scene_wiring/MARKER_NAME).write_text('wiring')
    (scene_wiring/'MusicalStage').mkdir()

    db = tmp_path/'fw.db'; make_db(db, str(tmp_path/'stale-15-Church'))
    conn = sqlite3.connect(db)
    conn.execute("UPDATE lor_snap__v_current_scenes SET background_file=? WHERE scene_id='s1'", (str(pointer),))
    add_display(conn, 1, 'CH-Test', 'r1', '01'); conn.commit(); conn.close()
    monkeypatch.setenv('FIELDWIRING_DRIVE_ROOT', str(root))
    package = build_wiring_package(SQLiteSnapshotRepository(db), display_id=1)
    assert package['images']['scope_root'] == str(scene)
    assert any('recovered' in warning.lower() for warning in package['images']['warnings'])
