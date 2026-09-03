from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent


def test_controller_page_loads_management_and_capacity_planner() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")

    assert "static/controllers_management.css" in html
    assert "static/controllers_management.js" in html
    assert "static/controllers_planner.css" in html
    assert "static/controllers_planner_v2.js" in html
    assert "static/controllers_planner.js?" not in html


def test_planning_reference_data_is_network_scoped_and_read_only() -> None:
    source = (BASE_DIR / "controller_management.py").read_text(encoding="utf-8")

    assert 'options["planning_lor_uid_usage"]' in source
    assert "btrim(fw.network) AS network" in source
    assert "upper(btrim(fw.controller)) AS uid_hex" in source
    assert "btrim(fw.controller) ~* '^[0-9a-f]{1,2}$'" in source
    assert 'options["planning_controller_programming"]' in source
    assert 'options["planning_explicit_spares"]' in source
    assert "ILIKE '%SPARE%'" in source
    assert "JOIN lor_snap.v_current_previews" in source
    assert "JOIN ref.stage" in source

    # This helper is a read-side extension only. Controller writes remain in the
    # narrow SECURITY DEFINER command adapter / migration contract.
    assert "UPDATE ref.controller" not in source
    assert "INSERT INTO ref.controller" not in source
    assert "DELETE FROM ref.controller" not in source


def test_stage_probe_uses_resolved_fieldwiring_contexts() -> None:
    source = (
        BASE_DIR / "static" / "controllers_planner_v2.js"
    ).read_text(encoding="utf-8")

    assert "api('api/stages')" in source
    assert "catalog?.contexts || []" in source
    assert "preview_uuid" in source
    assert "scene_uuid" in source
    assert "api(`api/wiring?${q.toString()}`)" in source
    assert "api(`api/wiring?stage_id=${stage.stage_id}`)" not in source


def test_uid_probe_is_network_specific_and_model_capacity_aware() -> None:
    source = (
        BASE_DIR / "static" / "controllers_planner_v2.js"
    ).read_text(encoding="utf-8")

    assert "row.network" in source
    assert "lor_uid_capacity" in source
    assert "start+width-1<=240" in source
    assert "UID availability is scoped to this Network" in source
    assert "same UID on another Network is unrelated" in source
    assert "controller_status_name!=='AVAILABLE'" in source
    assert "controller_status_name==='AVAILABLE'" in source


def test_regular_network_and_map_boundary_are_visible() -> None:
    source = (
        BASE_DIR / "static" / "controllers_planner_v2.js"
    ).read_text(encoding="utf-8")

    assert "network.toLowerCase()==='regular'" in source
    assert "park-wide, slow-speed" in source
    assert "background sequences" in source
    assert "existing park/network map" in source
    assert "currently used by this Stage" in source


def test_capacity_probe_never_issues_a_write_request() -> None:
    source = (
        BASE_DIR / "static" / "controllers_planner_v2.js"
    ).read_text(encoding="utf-8")

    assert "method:'POST'" not in source
    assert 'method: "POST"' not in source
    assert "method:'PATCH'" not in source
    assert 'method: "PATCH"' not in source
    assert "method:'DELETE'" not in source
    assert 'method: "DELETE"' not in source
    assert "X-MSB-Controller-Command" not in source
