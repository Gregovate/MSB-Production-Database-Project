from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from repository import SQLiteSnapshotRepository, classify_context, normalized_display_query
from wiring import WiringError, build_wiring_package


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
        INSERT INTO ref__stage VALUES (15, '15', 'Church', 15, 0);
        INSERT INTO ref__display VALUES (309, 'CH-RGBCandyCane-01', 15, 'lor-309', 1);
        INSERT INTO ref__display VALUES (323, 'CH-RGBTree-Base', 15, 'lor-323', 1);
        INSERT INTO lor_snap__v_current_props VALUES ('lor-309', 'LOR');
        INSERT INTO lor_snap__v_current_props VALUES ('lor-323', 'None');
        INSERT INTO lor_snap__v_display_lor_occurrence VALUES (
            'CH-RGBCandyCane-01','preview-musical','2026 Master Musical Preview','15',
            'scene-church','15-Church-CH','15','SCENE'
        );
        INSERT INTO lor_snap__v_display_lor_occurrence VALUES (
            'CH-RGBTree-Base','preview-musical','2026 Master Musical Preview','15',
            'scene-church','15-Church-CH','15','SCENE'
        );
        """
    )
    conn.commit()
    conn.close()


@pytest.fixture()
def repo(tmp_path):
    path = tmp_path / "fixture.db"
    make_fixture(path)
    return SQLiteSnapshotRepository(str(path))


def test_query_normalization():
    assert normalized_display_query("DISP:309") == ("id", "309")
    assert normalized_display_query("309") == ("id", "309")
    assert normalized_display_query("tree") == ("text", "tree")


def test_context_classification():
    assert classify_context("2026 Master Musical Preview") == "Musical"
    assert classify_context("Show Background Stage 15 Church") == "Background / Static"


def test_search_excludes_device_type_none(repo):
    rows = repo.search_displays("CH-RGB")
    names = [row["display_name"] for row in rows]
    assert "CH-RGBCandyCane-01" in names
    assert "CH-RGBTree-Base" not in names


def test_shared_search_includes_inventory_only_display(repo):
    rows = repo.shared_search_displays("CH-RGB")
    names = [row["display_name"] for row in rows]
    assert names == ["CH-RGBCandyCane-01", "CH-RGBTree-Base"]


def test_canonical_display_id_lookup(repo):
    rows = repo.search_displays("DISP:309")
    assert [row["display_id"] for row in rows] == [309]


def test_display_context_treats_stage_binding_lor_scene_as_stage_scope(repo):
    context = repo.display_context(309)
    assert context is not None
    assert context["stage_key"] == "15"
    assert context["scene_name"] is None
    assert context["context_type"] == "Musical"
    assert context["scope_kind"] == "Stage / Preview"


def test_inventory_only_display_resolves_shared_context_but_not_fieldwiring(repo):
    shared = repo.shared_display_context(323)
    assert shared is not None
    assert shared["display_name"] == "CH-RGBTree-Base"
    assert shared["stage"]["stage_key"] == "15"
    assert shared["contexts"][0]["scene"]["scene_name"] == "15-Church-CH"
    assert repo.display_context(323) is None


def test_inventory_only_direct_fieldwiring_entry_is_not_reported_as_unknown(repo):
    with pytest.raises(WiringError, match="No applicable field wiring"):
        build_wiring_package(repo, display_id=323)


def test_stage_browse_contains_scene(repo):
    stages = repo.stages()
    church = next(s for s in stages if s["stage_key"] == "15")
    assert any(c["scene_name"] == "15-Church-CH" for c in church["contexts"])
