from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent


def test_management_sql_keeps_narrow_security_definer_boundary() -> None:
    sql = (
        REPO_ROOT
        / "Controllers"
        / "Database"
        / "023_create_controller_management_commands.sql"
    ).read_text(encoding="utf-8")

    assert "ref.controller_management_actor" in sql
    assert "ref.controller_browser_capabilities" in sql
    assert "app.directus_user_uuid" in sql
    assert "SECURITY DEFINER" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.create_controller" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.update_controller" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.assign_controller_display" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.reassign_controller_display" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.unassign_controller_display" in sql
    assert "GRANT UPDATE ON ref.controller" not in sql
    assert "GRANT INSERT ON ref.controller" not in sql
    assert "GRANT DELETE ON ref.controller" not in sql
    assert "GRANT INSERT ON ref.controller_display" not in sql
    assert "GRANT DELETE ON ref.controller_display" not in sql


def test_management_sql_preserves_identity_and_assignment_rules() -> None:
    sql = (
        REPO_ROOT
        / "Controllers"
        / "Database"
        / "023_create_controller_management_commands.sql"
    ).read_text(encoding="utf-8")

    assert "INSERT INTO ref.controller (" in sql
    assert "controller_id" not in sql.split("INSERT INTO ref.controller (", 1)[1].split(")", 1)[0]
    assert "INSERT INTO ref.controller_display" in sql
    assert "DELETE FROM ref.controller_display" in sql
    assert "DELETE FROM ref.controller AS" not in sql
    assert "v_status IN ('REPAIR', 'RETIRED')" in sql
    assert "v_status = 'AVAILABLE'" in sql
    assert "v_status = 'DEPLOYED'" in sql
    assert "p_return_available" in sql
    assert "p_wiring_source_display_id" in sql


def test_management_command_adapter_calls_only_governed_functions() -> None:
    source = (BASE_DIR / "controller_commands.py").read_text(encoding="utf-8")

    assert "psycopg2.connect(pg.dsn)" in source
    assert "conn.set_session(readonly=False, autocommit=False)" in source
    for function_name in (
        "ref.create_controller",
        "ref.update_controller",
        "ref.assign_controller_display",
        "ref.update_controller_display_assignment",
        "ref.reassign_controller_display",
        "ref.unassign_controller_display",
    ):
        assert function_name in source
    assert "UPDATE ref.controller" not in source
    assert "INSERT INTO ref.controller" not in source
    assert "DELETE FROM ref.controller" not in source
    assert "INSERT INTO ref.controller_display" not in source
    assert "DELETE FROM ref.controller_display" not in source


def test_backend_exposes_guarded_management_routes() -> None:
    source = (BASE_DIR / "backend.py").read_text(encoding="utf-8")

    assert 'APP_VERSION = "V0.4.0"' in source
    assert '@app.post("/api/controllers")' in source
    assert '@app.patch("/api/controllers/<int:controller_id>")' in source
    assert '@app.post("/api/controllers/<int:controller_id>/assignments")' in source
    assert '@app.patch("/api/controllers/<int:controller_id>/assignments/<int:display_id>")' in source
    assert '/reassign")' in source
    assert '@app.delete("/api/controllers/<int:controller_id>/assignments/<int:display_id>")' in source
    assert "require_controller_command_request()" in source
    assert "cloudflare_operator_email(request.headers)" in source
    assert "require_controller_manager()" in source


def test_manager_ui_is_capability_loaded_and_keeps_print_service_separate() -> None:
    extras = (BASE_DIR / "static" / "controllers_detail_extras.js").read_text(encoding="utf-8")
    management = (BASE_DIR / "static" / "controllers_management.js").read_text(encoding="utf-8")

    assert "can_manage_controllers" in extras
    assert "controllers_management.js" in extras
    assert "Add Controller" in management
    assert "Edit Controller" in management
    assert "Manage Assignments" in management
    assert "LOR/V7 remains authority" in management
    assert "X-MSB-Controller-Command" in management
    assert "Controller asset itself will NOT be deleted" in management
    assert "LabelPrintService" not in management


def test_label_notice_uses_human_facing_authenticated_display_name() -> None:
    commands = (BASE_DIR / "controller_commands.py").read_text(encoding="utf-8")
    extras = (BASE_DIR / "static" / "controllers_detail_extras.js").read_text(encoding="utf-8")

    assert 'result["requested_by"]' in commands
    assert "controller_browser_capabilities" in commands
    assert "result.requested_by" in extras
