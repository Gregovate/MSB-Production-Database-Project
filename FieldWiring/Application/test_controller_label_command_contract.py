from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent


def test_label_command_is_narrow_security_definer_with_real_actor_handoff() -> None:
    sql = (
        REPO_ROOT
        / "Controllers"
        / "Database"
        / "022_create_controller_label_request_command.sql"
    ).read_text(encoding="utf-8")

    assert "SECURITY DEFINER" in sql
    assert "SET search_path = pg_catalog, ref" in sql
    assert "ref.controller_browser_capabilities" in sql
    assert "app.directus_user_uuid" in sql
    assert "ref.person" in sql
    assert "directus_user_id" in sql
    assert "SET print_label = true" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.request_controller_label" in sql
    assert "TO fieldwiring_app" in sql
    assert "GRANT UPDATE ON ref.controller" not in sql
    assert "fieldwiring_direct_controller_update" in sql


def test_command_adapter_uses_explicit_write_transaction_only_for_narrow_function() -> None:
    source = (BASE_DIR / "controller_commands.py").read_text(encoding="utf-8")

    assert "psycopg2.connect(repo.dsn)" in source
    assert "conn.set_session(readonly=False, autocommit=False)" in source
    assert "FROM ref.request_controller_label(%s, %s)" in source
    assert "UPDATE ref.controller" not in source
    assert "INSERT INTO ref.controller" not in source
    assert "DELETE FROM ref.controller" not in source


def test_backend_label_route_reauthenticates_and_requires_command_guard() -> None:
    source = (BASE_DIR / "backend.py").read_text(encoding="utf-8")

    assert '@app.post("/api/controllers/<int:controller_id>/print-label")' in source
    assert "require_controller_command_request()" in source
    assert "cloudflare_operator_email(request.headers)" in source
    assert "X-MSB-Controller-Command" in source
    assert "request.is_json" in source
    assert "request_controller_label(" in source


def test_browser_label_action_never_supplies_identity_or_role() -> None:
    source = (
        BASE_DIR / "static" / "controllers_detail_extras.js"
    ).read_text(encoding="utf-8")

    assert "api/controller-access" in source
    assert "can_print_label" in source
    assert "method: 'POST'" in source
    assert "X-MSB-Controller-Command" in source
    assert "api/controllers/${controllerId}/print-label" in source
    assert "email:" not in source
    assert "role_name:" not in source


def test_controller_screen_no_longer_directs_manager_workflow_to_directus() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")

    assert "controller-access-status" in html
    assert "Manager maintenance remains governed through Directus" not in html
    assert "Controller actions are enabled here only when the server authorizes them" in html
