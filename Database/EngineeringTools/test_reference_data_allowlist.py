"""#171/#230 reference-data allowlists: exact paths and default-deny policy.

These tests validate candidate policy documents, not Production privileges.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACCEPTANCE = ROOT / "Database" / "Acceptance"


def test_disposable_sql_allowlist_has_only_exact_owned_paths():
    path = ACCEPTANCE / "reference_data_disposable_allowlist.json"
    policy = json.loads(path.read_text(encoding="utf-8"))
    assert policy["schema_version"] == 1
    paths = policy["approved_migration_paths"] + policy["approved_validation_paths"]
    assert len(paths) == len(set(paths))
    assert paths, "An empty reference-data allowlist should be deliberate"
    for item in paths:
        assert isinstance(item, str)
        assert re.fullmatch(r"Database/[A-Za-z0-9_./-]+\.sql", item)
        assert ".." not in item and "*" not in item
        assert (ROOT / item).is_file(), f"Approved candidate path missing: {item}"


def test_manager_table_allowlist_is_default_deny_and_explicit():
    path = ACCEPTANCE / "reference_data_manager_table_allowlist.json"
    policy = json.loads(path.read_text(encoding="utf-8"))
    assert policy["schema_version"] == 1
    assert policy["status"] == "DESIGN_ONLY_NOT_ENFORCED"
    collections = policy["collections"]
    names = [entry["table"] for entry in collections]
    assert len(names) == len(set(names))
    assert {"ref.display", "ref.container", "ref.storage_location",
            "ref.site_waypoint", "ref.site_cable", "ref.site_network"} <= set(names)
    assert all(re.fullmatch(r"ref\.[a-z][a-z_0-9]*", name) for name in names)
    assert all(entry["protected_columns"] for entry in collections)
    assert all(entry["planned_actions"] for entry in collections)
    display = next(item for item in collections if item["table"] == "ref.display")
    assert {"display_id", "display_name", "lor_prop_id",
            "stage_id", "string_type"} <= set(display["protected_columns"])
    assert "ref.site_waypoint_source_binding" in policy["internal_only"]
    assert "ops.linkiq_test" in policy["internal_only"]


def test_shared_disposable_runner_uses_candidate_scoped_allowlist():
    wrapper = (ROOT / "Setup" / "Acceptance"
               / "run_setup_disposable_acceptance.ps1").read_text(encoding="utf-8")
    assert 'reference_data_disposable_allowlist.json' in wrapper
    assert '"${CandidateSha}:$referenceAllowlistPath"' in wrapper
    assert "$referenceMigrationPaths -ccontains $Path" in wrapper
    assert "if (@($referenceSqlPaths).Count -gt 0)" in wrapper
    assert "historical Setup-only previews" in wrapper
    # Historical Setup acceptance still owns these specific shared audit gates;
    # the reference-data extension must never erase their existing contract.
    assert "explicitly approved shared database repair" in wrapper
    assert "explicitly approved shared database validation" in wrapper


def test_disposable_runner_preserves_remote_ref_and_local_review_branch():
    wrapper = (ROOT / 'Setup' / 'Acceptance'
               / 'run_setup_disposable_acceptance.ps1').read_text(encoding='utf-8')
    assert "[string]$LocalReviewBranch = ''" in wrapper
    assert '$LocalReviewBranch = $TargetRef' in wrapper
    assert '$currentBranch -ne $LocalReviewBranch' in wrapper
    assert '"refs/remotes/origin/$TargetRef"' in wrapper
    assert '$remoteHead -ne $CandidateSha' in wrapper
    # Server receives both values through the acceptance manifest, not quoted
    # as standalone shell arguments in the remote command.
    assert '"candidate_sha`t$CandidateSha"' in wrapper
    assert '"target_ref`t$TargetRef"' in wrapper
    assert "'$remoteRunner' '$remoteManifest'" in wrapper
    assert "$referenceValidationPaths -ccontains $Path" in wrapper
    assert "171_site_infrastructure_schema_candidate.sql'" not in wrapper
    assert "171_site_infrastructure_disposable_validation.sql'" not in wrapper


def test_site_reference_sql_and_editor_paths_are_exact_and_ordered():
    """New #171/#230 SQL uses the same reviewed disposable wrapper, not a new clone."""
    policy = json.loads((ACCEPTANCE / "reference_data_disposable_allowlist.json").read_text(
        encoding="utf-8"))
    assert policy["approved_migration_paths"] == [
        "Database/EngineeringTools/sql/171_site_infrastructure_schema_candidate.sql",
        "Database/EngineeringTools/sql/171_panel_circuit_capture_candidate.sql",
        "Database/EngineeringTools/sql/171_site_reference_operations_candidate.sql",
        "Database/EngineeringTools/sql/171_panel_slot_count.sql",
        "Database/EngineeringTools/sql/171_breaker_state.sql",
        "Database/EngineeringTools/sql/171_power_snapshot_performance.sql",
        "Database/EngineeringTools/sql/171_unassigned_breaker_correction.sql",

        "Database/EngineeringTools/sql/171_equipment_lifecycle.sql",
        "Database/EngineeringTools/sql/171_equipment_catalog.sql",
        "Database/EngineeringTools/sql/171_panel_receptacles.sql",
    ]
    assert policy["approved_validation_paths"] == [
        "Database/Acceptance/171_site_infrastructure_disposable_validation.sql",
        "Database/Acceptance/171_site_reference_operations_disposable_validation.sql",
        "Database/Acceptance/171_panel_slot_count_validation.sql",
        "Database/Acceptance/171_breaker_state_validation.sql",
        "Database/Acceptance/171_power_snapshot_performance_validation.sql",
        "Database/Acceptance/171_unassigned_breaker_correction_validation.sql",

        "Database/Acceptance/171_equipment_lifecycle_validation.sql",
        "Database/Acceptance/171_equipment_catalog_validation.sql",
        "Database/Acceptance/171_cable_result_evidence.sql",
        "Database/Acceptance/171_panel_receptacles_validation.sql",
    ]
    editor = json.loads((ACCEPTANCE / "reference_data_manager_table_allowlist.json").read_text(
        encoding="utf-8"))
    assert editor["status"] == "DESIGN_ONLY_NOT_ENFORCED"
    assert editor["gis_candidate_editor"]["status"] == "CANDIDATE_ONLY_NOT_DEPLOYED_NOT_ROLE_GRANTED"
    assert {"ref.site_power_revision", "ref.site_reference_revision",
            "ops.site_reference_edit_log"} <= set(editor["internal_only"])
    tables = {c["table"] for c in editor["collections"]}
    assert {"ref.site_panel", "ref.site_power_circuit", "ref.site_power_feed",
            "ref.site_waypoint_network", "ref.site_power_action"} <= tables


def test_site_reference_writes_are_explicit_and_audited():
    sql = (ROOT / "Database" / "EngineeringTools" / "sql"
           / "171_site_reference_operations_candidate.sql").read_text(encoding="utf-8")
    assert "CREATE TABLE IF NOT EXISTS ref.site_editor_grant" not in sql
    assert "ref.setup_browser_capabilities(p_email)" in sql
    assert "ref.setup_inventory_actor(p_email,true)" in sql
    assert "ref.site_reference_command(" in sql
    assert "ref.site_reference_revision" in sql and "FOR UPDATE" in sql
    assert "ops.site_reference_edit_log" in sql
    assert "REVOKE ALL ON FUNCTION ref.site_reference_command" in sql
    assert "measured_link_speed_mbps',NULL" in sql
    assert "ref.site_power_feed" in sql and "ref.site_power_action" in sql
    assert "UNREVIEWED" in sql or "UNKNOWN" in sql
    assert "ALTER TABLE ref.display" not in sql
    assert "GRANT UPDATE ON ALL TABLES" not in sql


def test_existing_map_uses_protected_live_references_before_static_fallback():
    app = ROOT / "Setup" / "Application"
    html = (app / "locate_preview.html").read_text(encoding="utf-8")
    backend = (app / "production_backend.py").read_text(encoding="utf-8")
    networks = (app / "setup_locate_networks.js").read_text(encoding="utf-8")
    search = (app / "setup_locate_search.js").read_text(encoding="utf-8")
    client = (app / "setup_site_reference.js").read_text(encoding="utf-8")
    api = (app / "setup_site_reference_api.py").read_text(encoding="utf-8")
    assert html.count('src="assets/setup_site_reference.js?v=2026-10-27-panel-supplies"') == 1
    assert html.index('src="assets/setup_locate_search.js"') < html.index(
        'src="assets/setup_site_reference.js?v=2026-10-27-panel-supplies"') < html.index(
        'src="assets/setup_locate_networks.js')
    assert "app.register_blueprint(site_reference_api)" in backend
    assert '"setup_site_reference.js"' in backend
    assert "window.siteReferenceReady && await window.siteReferenceReady" in networks
    assert "reindexMapReferences()" in search and "replaceSiteReferences(entries)" in search
    assert "mapSearch.reindexMapReferences()" in client
    # Offline work renamed the legacy-only banner to distinguish static GPX
    # from explicitly prepared, dated offline PostgreSQL references.
    assert "STATIC GPX SOURCE ONLY" in client
    assert "OFFLINE SAVED PostgreSQL GIS" in client
    assert "LIVE PostgreSQL GIS" in client
    assert "siteReferenceReady = refresh()" in client
    assert "credentials: 'same-origin'" in client
    assert "require_reader()" in api and "require_setup_command()" in api
    assert "Site reference editor scope not granted" in api
    assert "connection.rollback()" in api and "connection.set_session(readonly=False" in api


def test_setup_map_is_reference_consumer_not_reference_editor():
    """#171/#230: Setup map must never expose engineering mutation forms."""
    viewer = (ROOT / "Setup" / "Application" / "setup_site_reference.js").read_text(
        encoding="utf-8")
    assert "btn.textContent = 'View circuits and tests'" in viewer
    assert "if (false && (current.permissions.identity || current.permissions.operations))" in viewer
    assert "renderDb(snapshot);" in viewer
    assert "renderNetworks(snapshot);" in viewer
    # #230 needs its own editor. Read-only Setup still consumes current PostGIS.
    assert "SELECT ref.site_reference_snapshot()" in (
        ROOT / "Setup" / "Application" / "setup_site_reference_api.py").read_text(
        encoding="utf-8")


def test_track_popup_is_inspection_not_edit_entrypoint():
    """Keep GIS popup inspection distinct from the provisional Manager sidebar."""
    js = (ROOT / "Setup" / "Application" / "setup_site_reference.js").read_text(encoding="utf-8")
    assert "review.textContent = 'Inspect track'" in js
    assert "Inspect / correct track name" not in js
    assert "marker.on('popupopen', () => showTrack(t.id));" in js
    assert "if (current.permissions?.identity)" in js  # Existing phase-1 Manager sidebar gate.


def test_record_location_dropdown_uses_maintained_gis_and_offline_cache():
    """#171/#88: no legacy fixed Stage JSON can drive the drop selector."""
    source = (ROOT / 'Setup' / 'Application' / 'setup_record_location.js').read_text(
        encoding='utf-8')
    assert "fetch('../api/setup/locate/references'" in source
    assert "normalizeSiteReference(snapshot)" in source
    assert "snapshot.sources?.gpx?.sha256" in source
    assert "'site-waypoint:' + point.id" in source
    assert "cached?.data?.accepted_gpx_sha256" in source
    assert "fetch('location-references.json'" not in source
    assert "CURRENT GIS DROP LOCATIONS UNAVAILABLE" in source
    assert "populateReferenceSelect();" in source
