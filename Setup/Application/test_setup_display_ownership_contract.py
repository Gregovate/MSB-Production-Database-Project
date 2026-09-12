from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_migration_reuses_existing_relationship_and_enforces_one_owner() -> None:
    sql = (DB_DIR / "028_harden_setup_task_display_ownership.sql").read_text(encoding="utf-8")
    assert "ref.setup_task_display" in sql
    assert "CREATE UNIQUE INDEX IF NOT EXISTS ux_setup_task_display_one_owner" in sql
    assert "ON ref.setup_task_display(display_id)" in sql
    assert "ref.set_setup_task_display_owner" in sql
    assert "ref.setup_management_actor" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_owner" in sql
    assert "GRANT INSERT ON ref.setup_task_display" not in sql
    assert "GRANT UPDATE ON ref.setup_task_display" not in sql
    assert "UPDATE ref.display" not in sql
    assert "UPDATE ref.lor_" not in sql
    assert "INSERT INTO ref.lor_" not in sql


def test_owner_command_requires_active_material_task_and_active_display() -> None:
    sql = (DB_DIR / "028_harden_setup_task_display_ownership.sql").read_text(encoding="utf-8")
    assert "t.active_flag" in sql
    assert "t.requires_display_material" in sql
    assert "upper(ds.display_status_name) = 'ACTIVE'" in sql
    assert "Display already has an explicit Setup-task owner" in sql
    assert "Display owner changed since it was loaded" in sql


def test_application_layers_ownership_after_existing_material_resolver() -> None:
    backend = read_app("production_backend.py")
    resolver_index = backend.index("install_setup_material_resolution()")
    ownership_index = backend.index("install_setup_display_ownership()")
    assert resolver_index < ownership_index
    assert "V0.3.12-display-ownership" in backend
    assert "app.register_blueprint(setup_display_ownership_api)" in backend

    ownership = read_app("setup_display_ownership.py")
    assert "_BASE_FIELD_CONTEXT" in ownership
    assert "LOR_SCENE" in ownership
    assert "LOR_STAGE_LEVEL" in ownership
    assert "IMPLICIT_SINGLE" in ownership
    assert "UNINITIALIZED_MULTI" in ownership
    assert "EXPLICIT_MULTI" in ownership
    assert "REVIEW_REQUIRED" in ownership


def test_simple_scope_preserves_implicit_current_behavior() -> None:
    ownership = read_app("setup_display_ownership.py")
    assert "len(eligible_tasks) <= 1" in ownership
    assert "effective_displays = source_displays" in ownership
    assert 'ownership_mode = "IMPLICIT_SINGLE"' in ownership
    assert 'coverage_status = "COMPLETE"' in ownership


def test_complex_scope_filters_effective_material_to_explicit_owner() -> None:
    ownership = read_app("setup_display_ownership.py")
    assert "owner_setup_task_id" in ownership
    assert 'item.get("ownership_state") == "ASSIGNED"' in ownership
    assert "int(item.get(\"owner_setup_task_id\") or 0) == int(task_id)" in ownership
    assert "missing_owner_count" in ownership
    assert "invalid_owner_count" in ownership
    assert "duplicate_owner_count" in ownership
    assert "stale_owner_count" in ownership


def test_write_api_is_manager_only_and_uses_governed_command() -> None:
    api = read_app("setup_display_ownership_api.py")
    assert "require_setup_command()" in api
    assert "require_manager()" in api
    assert "/display-ownership/initialize" in api
    assert "/display-ownership/<int:display_id>" in api

    ownership = read_app("setup_display_ownership.py")
    assert "FROM ref.set_setup_task_display_owner" in ownership
    assert "INSERT INTO ref.setup_task_display" not in ownership
    assert "UPDATE ref.setup_task_display" not in ownership


def test_manager_board_supports_initialization_and_drag_reassignment() -> None:
    js = read_app("setup_display_ownership.js")
    html = read_app("production.html")
    backend = read_app("production_backend.py")

    assert "Initialize all resolved Displays to this task" in js
    assert "dragstart" in js
    assert "dragover" in js
    assert "drop" in js
    assert "target_setup_task_id" in js
    assert "Dragging a Display changes Setup task ownership only" in js
    assert "setup_display_ownership.js" in html
    assert "setup_display_ownership.css" in html
    assert '"setup_display_ownership.js"' in backend
    assert '"setup_display_ownership.css"' in backend


def test_container_support_remains_separate_and_nonexclusive() -> None:
    ownership = read_app("setup_display_ownership.py")
    migration = (DB_DIR / "028_harden_setup_task_display_ownership.sql").read_text(encoding="utf-8")
    assert "support_containers" in ownership
    assert "ref.setup_task_container_support" in migration
    assert "UNIQUE INDEX" not in "\n".join(
        line for line in migration.splitlines() if "setup_task_container_support" in line
    )


def test_no_2026_session_creation_is_added_by_issue_141() -> None:
    combined = "\n".join(
        [
            read_app("setup_display_ownership.py"),
            read_app("setup_display_ownership_api.py"),
            (DB_DIR / "028_harden_setup_task_display_ownership.sql").read_text(encoding="utf-8"),
        ]
    )
    assert "create_setup_session(" not in combined
    assert "INSERT INTO ops.setup_session" not in combined
