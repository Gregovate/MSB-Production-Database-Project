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


def test_correction_allows_active_scope_target_without_prechecked_material_flag() -> None:
    sql = (DB_DIR / "029_correct_setup_assignment_layer.sql").read_text(encoding="utf-8")
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_display_owner" in sql
    assert "t.active_flag" in sql
    assert "t.stage_id IS NOT NULL" in sql
    assert "Target Setup task must be active and have a Stage or Scene scope" in sql
    assert "Assignment establishes Display-material applicability automatically" in sql
    assert "SET requires_display_material = true" in sql
    assert "Target Setup task must be active and use Display / Container Material" not in sql


def test_explicit_owner_still_prevents_disabling_material_flag() -> None:
    sql = (DB_DIR / "028_harden_setup_task_display_ownership.sql").read_text(encoding="utf-8")
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_display_material_requirement" in sql
    assert "NOT v_requires AND EXISTS" in sql
    assert "WHERE td.setup_task_id = p_setup_task_id" in sql
    assert "Cannot disable Display / Container Material while this task owns Displays" in sql


def test_corrected_assignment_layer_installs_after_existing_resolver_and_ownership() -> None:
    backend = read_app("production_backend.py")
    resolver_index = backend.index("install_setup_material_resolution()")
    ownership_index = backend.index("install_setup_display_ownership()")
    correction_index = backend.index("install_setup_assignment_layer()")
    assert resolver_index < ownership_index < correction_index
    assert "V0.3.14-scheduling-board" in backend
    assert "app.register_blueprint(setup_display_ownership_api)" in backend
    assert "app.register_blueprint(setup_assignment_api)" in backend

    assignment = read_app("setup_assignment_layer.py")
    assert "is_stage_level_lor_group" in assignment
    assert 'ownership_mode = "IMPLICIT_SINGLE"' in assignment
    assert 'ownership_mode = "UNINITIALIZED_MULTI"' in assignment
    assert 'ownership_mode = "EXPLICIT_MULTI"' in assignment
    assert '"COMPLETE" if sole_implicit_owner is not None else "REVIEW_REQUIRED"' in assignment
    assert 'coverage_status = (' in assignment


def test_untouched_scope_can_begin_assignment_without_material_seed() -> None:
    assignment = read_app("setup_assignment_layer.py")
    assert "candidate_tasks = _scope_tasks(self, task)" in assignment
    assert "WHERE t.stage_id = %s" in assignment
    assert "AND t.active_flag" in assignment
    assert "AND t.requires_display_material" not in assignment.split("def _scope_tasks", 1)[1].split("def _source_displays", 1)[0]
    assert "len(candidate_tasks) > 1" in assignment
    assert "and source_displays" in assignment
    assert "and not explicit_source_rows" in assignment
    assert "sole_implicit_owner_setup_task_id" in assignment


def test_simple_single_material_behavior_remains_effective_until_subdivision() -> None:
    assignment = read_app("setup_assignment_layer.py")
    assert "sole_implicit_owner =" in assignment
    assert "effective_displays = source_displays if sole_implicit_owner == int(task_id) else []" in assignment
    assert 'coverage_status = "COMPLETE" if sole_implicit_owner is not None else "REVIEW_REQUIRED"' in assignment
    assert "Convert the accepted simple implicit state into complete explicit" in assignment


def test_complex_scope_filters_effective_material_to_explicit_owner() -> None:
    assignment = read_app("setup_assignment_layer.py")
    assert "owner_setup_task_id" in assignment
    assert 'item.get("ownership_state") == "ASSIGNED"' in assignment
    assert "int(item.get(\"owner_setup_task_id\") or 0) == int(task_id)" in assignment
    assert "missing_owner_count" in assignment
    assert "invalid_owner_count" in assignment
    assert "duplicate_owner_count" in assignment
    assert "stale_owner_count" in assignment


def test_display_write_api_stays_manager_only_and_uses_governed_command() -> None:
    api = read_app("setup_display_ownership_api.py")
    assert "require_setup_command()" in api
    assert "require_manager()" in api
    assert "/display-ownership/initialize" in api
    assert "/display-ownership/<int:display_id>" in api

    assignment = read_app("setup_assignment_layer.py")
    assert "FROM ref.set_setup_task_display_owner" in assignment
    assert "INSERT INTO ref.setup_task_display" not in assignment
    assert "UPDATE ref.setup_task_display" not in assignment


def test_manager_board_supports_first_use_initialization_drag_multi_select_and_flag_sync() -> None:
    js = read_app("setup_display_ownership.js")
    css = read_app("setup_display_ownership.css")
    html = read_app("production.html")
    backend = read_app("production_backend.py")

    assert "Assign all resolved Displays to this task" in js
    assert "Assignment automatically enables Display / Container Material" in js
    assert "refreshMaterialFlags" in js
    assert "loadSetupMaterialFlags({ rerender: false })" in js
    assert "row.ownership_state === 'ASSIGNED' || row.ownership_state === 'IMPLICIT'" in js
    assert "dragstart" in js
    assert "dragover" in js
    assert "drop" in js
    assert "target_setup_task_id" in js
    assert "LOR defines the current Display source set" in js
    assert "selectedDisplayIds" in js
    assert "event.ctrlKey || event.metaKey" in js
    assert "event.shiftKey" in js
    assert "moveDisplays" in js
    assert "setup-display-ownership-sort" in js
    assert "Shift-click selects a range within a task column" in js
    assert "Drag any selected Display to move the whole selection" in js
    assert ".setup-display-owner-card.selected" in css
    assert "setup_display_ownership.js" in html
    assert "setup_display_ownership.css" in html
    assert '"setup_display_ownership.js"' in backend
    assert '"setup_display_ownership.css"' in backend


def test_kit_box_assignment_is_specific_many_to_many_and_outside_lor() -> None:
    migration = (DB_DIR / "029_correct_setup_assignment_layer.sql").read_text(encoding="utf-8")
    assignment = read_app("setup_assignment_layer.py")
    api = read_app("setup_assignment_api.py")
    ui = read_app("setup_kit_box_assignment.js")

    assert "relationship_type IN ('SUPPORT', 'REQUIRED_CONTAINER', 'KIT')" in migration
    assert "container_type_id=2" in migration
    assert "ref.set_setup_task_kit_box_assignment" in migration
    assert "This task/container pair already has a non-KIT support relationship" in migration
    assert "WHERE c.container_type_id = 2" in assignment
    assert "other_task_count" in assignment
    assert "other_task_assignments" in assignment
    assert "relationship_type = 'KIT'" in assignment
    assert "require_manager()" in api
    assert "/kit-boxes/<int:container_id>" in api
    assert "Kit Boxes are outside LOR" in ui
    assert "may be assigned to more than one reusable Setup task" in ui


def test_existing_nonkit_support_relationships_remain_separate() -> None:
    migration = (DB_DIR / "029_correct_setup_assignment_layer.sql").read_text(encoding="utf-8")
    assert "SUPPORT / REQUIRED_CONTAINER retain existing logistics meaning" in migration
    assert "Existing SUPPORT / REQUIRED_CONTAINER rows are never" in migration
    assert "CREATE UNIQUE INDEX" not in "\n".join(
        line for line in migration.splitlines() if "setup_task_container_support" in line
    )


def test_no_2026_session_creation_is_added_by_issue_141() -> None:
    combined = "\n".join(
        [
            read_app("setup_display_ownership.py"),
            read_app("setup_display_ownership_api.py"),
            read_app("setup_assignment_layer.py"),
            read_app("setup_assignment_api.py"),
            (DB_DIR / "028_harden_setup_task_display_ownership.sql").read_text(encoding="utf-8"),
            (DB_DIR / "029_correct_setup_assignment_layer.sql").read_text(encoding="utf-8"),
        ]
    )
    assert "create_setup_session(" not in combined
    assert "INSERT INTO ops.setup_session" not in combined
