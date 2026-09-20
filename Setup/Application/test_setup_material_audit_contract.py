"""Contract tests for Issue #145 Manager Material Completeness Audit candidate."""
from pathlib import Path

from setup_material_audit_repository import classify_kit_coverage


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"
ACCEPT_DIR = APP_DIR.parent / "Acceptance"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def read_db(name: str) -> str:
    return (DB_DIR / name).read_text(encoding="utf-8")


def read_accept(name: str) -> str:
    return (ACCEPT_DIR / name).read_text(encoding="utf-8")


def test_kit_classification_is_explicit_and_never_name_inferred() -> None:
    assert classify_kit_coverage(1, 1, False) == "ASSIGNED_ACTIVE"
    assert classify_kit_coverage(2, 2, False) == "ASSIGNED_ACTIVE"
    assert classify_kit_coverage(0, 1, False) == "INACTIVE_OBSOLETE_ONLY"
    assert classify_kit_coverage(0, 0, True) == "REVIEWED_SHARED_NON_TASK"
    assert classify_kit_coverage(0, 0, False) == "UNASSIGNED_UNRESOLVED"


def test_accepted_display_assignment_states_remain_the_audit_authority() -> None:
    assignment = read_app("setup_assignment_layer.py")
    assert 'ownership_mode = "IMPLICIT_SINGLE"' in assignment
    assert 'coverage_status = "COMPLETE"' in assignment
    assert 'ownership_mode = "EXPLICIT_MULTI"' in assignment
    assert 'else "REVIEW_REQUIRED"' in assignment
    for token in (
        "missing_owner_count",
        "invalid_owner_count",
        "duplicate_owner_count",
        "stale_owner_count",
        "sole_implicit_owner_setup_task_id",
    ):
        assert token in assignment


def test_display_audit_reuses_accepted_assignment_resolver() -> None:
    repo = read_app("setup_material_audit_repository.py")
    assert "from setup_assignment_layer import _scope_key" in repo
    assert "next_repo.field_context(" in repo
    assert '"coverage_status": "REVIEW_REQUIRED"' in repo
    for token in (
        "missing_owner_count",
        "invalid_owner_count",
        "duplicate_owner_count",
        "stale_owner_count",
        "uncontained_display_count",
        "sole_implicit_owner_setup_task_id",
    ):
        if token == "sole_implicit_owner_setup_task_id":
            assert token in read_app("setup_assignment_layer.py")
        else:
            assert token in repo
    assert "set_setup_task_display_owner" not in repo


def test_kit_audit_reads_active_and_inactive_relationships() -> None:
    repo = read_app("setup_material_audit_repository.py")
    assert "WHERE tc.relationship_type = 'KIT'" in repo
    assert "t.active_flag AS task_active_flag" in repo
    assert "active_assignments" in repo
    assert "inactive_assignments" in repo
    assert "disposition_conflict" in repo
    assert "container_type_id = 2" in repo


def test_disposition_schema_is_narrow_and_manager_governed() -> None:
    sql = read_db("051_add_setup_material_completeness_audit.sql")
    assert "CREATE TABLE IF NOT EXISTS ref.setup_kit_assignment_disposition" in sql
    assert "CONSTRAINT pk_setup_kit_assignment_disposition" in sql
    assert "PRIMARY KEY (container_id)" in sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_kit_assignment_disposition" in sql
    assert "ON CONFLICT (container_id)" not in sql
    assert "CHECK (disposition = 'SHARED_NON_TASK')" in sql
    assert "reviewed_at timestamptz" in sql
    assert "reviewed_by_person_id integer" in sql
    assert "active_flag boolean" in sql
    assert "ck_setup_kit_assignment_disposition_active_note" in sql
    assert "A Manager review reason is required" in sql
    assert "ref.setup_management_actor(p_email, false)" in sql
    assert "container_type_id=2" in sql
    assert "relationship_type = 'KIT'" in sql
    assert "Remove existing reusable task KIT relationships" in sql
    assert "GRANT SELECT ON TABLE ref.setup_kit_assignment_disposition TO fieldwiring_app" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_kit_assignment_disposition" in sql
    assert "INSERT INTO ref.setup_task_container_support" not in sql
    assert "ops.setup_session" not in sql
    assert "setup_task_extra_material_source" not in sql


def test_audit_api_is_manager_only_and_write_is_governed() -> None:
    api = read_app("setup_material_audit_api.py")
    assert '@setup_material_audit_api.get("/api/setup/material-audit")' in api
    assert "require_manager()" in api
    assert "/shared-non-task" in api
    assert "require_setup_command()" in api
    assert "reviewed_shared_non_task" in api


def test_manager_browser_surface_is_exception_first_and_links_corrections() -> None:
    html = read_app("material_audit.html")
    js = read_app("setup_material_audit.js")
    assert "Material Completeness Audit" in html
    assert '<option value="exceptions">Exceptions only</option>' in html
    assert 'class="display-audit-table"' in html
    css = read_app("setup_material_audit.css")
    assert ".display-audit-table" in css
    assert "min-width: 1580px" in css
    assert "td:nth-child(11) .button" in css
    assert "Open Display Ownership" in js
    assert "Open Kit Inventory" in js
    assert "Open Kit assignment" in js
    assert "correction=display-ownership" in js
    assert "correction=kit-boxes" in js
    assert "consumePendingCorrection('display-ownership')" in read_app("setup_display_ownership.js")
    assert "consumePendingCorrection('kit-boxes')" in read_app("setup_kit_box_assignment.js")
    assert "Mark reviewed shared/non-task" in js
    assert "Clear disposition" in js
    assert "X-MSB-Setup-Command" in js
    assert "container_description" not in js[js.index("function kitIsException"):js.index("function statusClass")]


def test_production_host_registers_audit_without_exposing_source() -> None:
    host = read_app("production_backend.py")
    production = read_app("production.html")
    client = read_app("setup_production.js")
    assert "from setup_material_audit_api import setup_material_audit_api" in host
    assert "app.register_blueprint(setup_material_audit_api)" in host
    assert '@app.get("/material-audit")' in host
    assert '"setup_material_audit.js"' in host
    assert '"setup_material_audit.css"' in host
    assert "material-audit-link" in production
    assert "material-audit/" in client
    assert "URLSearchParams" in client
    assert "setup_task_id" in client
    assert "requestedCorrection" in client
    assert "pendingCorrection" in client
    assert "function consumePendingCorrection(name)" in client
    assert "params.delete('correction')" in client
    assert "window.history.replaceState" in client


def test_disposable_validation_proves_no_fake_assignment_or_annual_state() -> None:
    sql = read_accept("setup_145_material_audit_disposable_validation.sql")
    assert "SETUP_145_MATERIAL_AUDIT_DISPOSABLE_VALIDATION_PASS" in sql
    assert "ref.set_setup_kit_assignment_disposition" in sql
    assert "relationship_type='KIT'" in sql or "relationship_type = 'KIT'" in sql
    assert "ops.setup_session" in sql
    assert "ROLLBACK;" in sql
