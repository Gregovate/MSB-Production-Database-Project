import ast
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
    assert "All 240 addresses (01–F0) are examined on this Network" in source
    assert "const used = lorUsage(network);" in source
    assert "controller_status_name!=='AVAILABLE'" in source
    assert "controller_status_name==='AVAILABLE'" in source


def test_regular_network_and_map_boundary_are_visible() -> None:
    source = (
        BASE_DIR / "static" / "controllers_planner_v2.js"
    ).read_text(encoding="utf-8")

    assert "networkKey(network) === 'regular'" in source
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


def test_network_uid_explorer_is_independent_of_controller_model() -> None:
    source = (BASE_DIR / "static" / "controllers_planner_v2.js").read_text(encoding="utf-8")
    assert "Array.from({length:240}" in source
    assert "const used = lorUsage(network);" in source
    assert "if (model) {" in source
    assert 'id="planner-uid-search"' in source
    assert 'id="planner-uid-filter"' in source
    assert "choices.map(b =>" in source
    assert "blocks.slice(0,24)" not in source
    assert 'No block search' in source


def test_network_identity_deduplicates_regular_case_without_lor_mutation() -> None:
    source = (BASE_DIR / "static" / "controllers_planner_v2.js").read_text(encoding="utf-8")
    assert "const networkKey = value =>" in source
    assert "networkKey(value) === 'regular' ? 'Regular'" in source
    assert "const uniqueNetworks = values =>" in source
    assert "return uniqueNetworks([" in source
    assert "return uniqueNetworks(values);" in source
    assert "method:'POST'" not in source


def test_dmx_universe_values_cannot_occupy_lor_unit_ids() -> None:
    source = (BASE_DIR / "controller_management.py").read_text(encoding="utf-8")
    # Both the network-wide occupied-UID query and the Stage explicit-SPARE
    # query consume the legacy wiring compatibility view. Neither may count
    # E1.31/DMX universe values as traditional LOR addresses.
    gate = "upper(btrim(coalesce(fw.device_type, ''))) <> 'DMX'"
    assert source.count(gate) == 2
    assert "fw.device_type" in source
    assert "options[\"planning_lor_uid_usage\"]" in source
    assert "options[\"planning_explicit_spares\"]" in source
    # FieldWiring's existing DMX/E1.31 rendering must not be modified.
    assert "UPDATE lor_snap." not in source


def test_controller_disposable_preview_proves_clean_exit() -> None:
    server = (BASE_DIR.parents[1] / "Controllers" / "Acceptance"
              / "controller_setup_management_browser_preview_server.sh").read_text(
                  encoding="utf-8"
              )
    wrapper = (BASE_DIR.parents[1] / "Controllers" / "Acceptance"
               / "run_controller_setup_management_browser_preview.ps1").read_text(
                   encoding="utf-8"
               )

    # Cleanup must target the identified fieldwiring-owned Flask process,
    # not just its process group (the previous CLEAN EXIT left an orphan).
    assert 'preview_pid_matches()' in server
    assert 'preview_port_owned_by_pid()' in server
    assert 'sudo kill -TERM "$PREVIEW_PGID"' in server
    assert 'sudo kill -KILL "$PREVIEW_PGID"' in server
    assert 'preview_port_listening' in server
    assert 'sudo docker inspect "$TEST_CONTAINER"' in server
    assert 'worktree list --porcelain' in server
    assert 'CLEANUP FAILED: do not declare CLEAN EXIT' in server
    assert 'CLEAN EXIT: Controller preview owned resources verified absent' in server
    assert 'if (( cleanup_failed )); then' in server
    assert 'rm -rf -- "$SCRIPT_DIR"' in server
    assert "CONTROLLER DISPOSABLE BROWSER PREVIEW: CLEAN EXIT" in wrapper


def test_controller_management_backend_compiles_before_preview() -> None:
    source = (BASE_DIR / "controller_management.py").read_text(encoding="utf-8")
    ast.parse(source, filename="controller_management.py")


def test_contiguous_results_precede_scrollable_uid_inventory() -> None:
    source = (BASE_DIR / "static" / "controllers_planner_v2.js").read_text(encoding="utf-8")
    css = (BASE_DIR / "static" / "controllers_planner.css").read_text(encoding="utf-8")
    assert source.index("      ${blocks}") < source.index("<h3>Network UID inventory")
    assert "candidate starts" in source
    assert "max-height:224px" in css
    assert "overflow-y:auto" in css


def test_single_uid_model_uses_compact_address_grid() -> None:
    source = (BASE_DIR / "static" / "controllers_planner_v2.js").read_text(encoding="utf-8")
    css = (BASE_DIR / "static" / "controllers_planner.css").read_text(encoding="utf-8")
    assert "'Available individual UIDs' : 'Contiguous UID blocks'" in source
    assert "width === 1 ? 'planner-single-uids'" in source
    assert ".planner-single-uids { grid-template-columns:repeat(4,minmax(0,1fr)); }" in css
