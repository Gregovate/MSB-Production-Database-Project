import ast
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DB_ROOT = ROOT.parent / "Database"


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def read_db(name: str) -> str:
    return (DB_ROOT / name).read_text(encoding="utf-8")


def test_training_ux_assets_are_loaded_after_live_review_fixes():
    html = read("production.html")
    live_index = html.index("setup_live_review_fixes.js?v=2026-09-08.3")
    training_index = html.index("setup_training_ux.js?v=2026-09-08.1")
    assigned_index = html.index("setup_assigned_review.js?v=2026-09-08.2")
    refinement_index = html.index("setup_training_review_refinement.js?v=2026-09-09.2")
    assert "setup_training_ux.css?v=2026-09-08.1" in html
    assert "setup_training_review_refinement.css?v=2026-09-08.1" in html
    assert training_index > live_index
    assert refinement_index > assigned_index > training_index


def test_catalog_open_gets_contextual_return_navigation():
    js = read("setup_training_ux.js")
    assert "#library-view .open-task" in js
    assert "← Back to Reusable Task Catalog" in js
    assert "rememberLibraryOrigin" in js
    assert "showView('library')" in js
    assert "scrollIntoView({ block: 'center', behavior: 'auto' })" in js
    assert "setup-return-highlight" in js


def test_verification_queue_open_clears_catalog_return_context():
    js = read("setup_training_ux.js")
    assert "#review-list .task-row" in js
    assert "clearLibraryOrigin" in js


def test_return_control_moves_beside_reusable_task_actions_and_remains_contextual():
    base_js = read("setup_training_ux.js")
    refinement_js = read("setup_training_review_refinement.js")
    refinement_css = read("setup_training_review_refinement.css")
    assert ".setup-return-library-wrap[hidden]" in read("setup_training_ux.css")
    assert "returnState.fromLibrary" in base_js
    assert "reusable-manager-actions" in refinement_js
    assert "insertBefore(wrap, deleteButton" in refinement_js
    assert "#reusable-manager-actions .setup-return-library-wrap" in refinement_css
    assert "display: contents" in refinement_css
    assert "position: static" in refinement_css


def test_return_control_has_distinct_theme_safe_navigation_treatment():
    css = read("setup_training_review_refinement.css")
    assert "#reusable-manager-actions #setup-return-library" in css
    assert "background: var(--accent-soft)" in css
    assert "color: var(--text)" in css
    assert "border-color: var(--accent)" in css
    assert "#setup-return-library:hover" in css
    assert "#setup-return-library:focus-visible" in css
    assert "color: #ffffff" in css


def test_catalog_detail_adds_database_resolved_material_logistics_section():
    js = read("setup_training_ux.js")
    assert "4. Material / Logistics Context" in js
    assert "5. Setup Procedures" in js
    assert "field-context?season_year=" in js
    assert "Displays resolved" in js
    assert "Containers resolved" in js
    assert "Support / KIT Containers" in js
    assert "Displays without Container" in js
    assert "Current LOR Scene membership" in js
    assert "Explicit reusable-task Display mapping" in js


def test_material_context_exposes_knowledge_gaps_instead_of_hard_coding_ids():
    js = read("setup_training_ux.js")
    assert "No Display or supplemental Container relationship is currently resolved" in js
    assert "Controllers:" in js
    assert "authoritative FieldWiring/controller relationships" in js
    assert "hard-coded Procedure text" in js


def test_material_details_are_collapsed_out_of_the_main_task_page():
    js = read("setup_training_review_refinement.js")
    css = read("setup_training_review_refinement.css")
    assert "View Material Details" in js
    assert "setup-material-details-dialog" in js
    assert "showModal()" in js
    assert ".setup-material-container, .setup-support-container-block" in js
    assert "Open the Container / Display list and relationship reasons only when needed." in js
    assert ".setup-material-details-dialog" in css
    assert "overflow: auto" in css


def test_material_context_has_theme_safe_responsive_styles():
    css = read("setup_training_ux.css")
    refinement_css = read("setup_training_review_refinement.css")
    assert ".setup-material-summary" in css
    assert ".setup-material-container" in css
    assert ".setup-support-container-block" in css
    assert ".setup-controller-context-note" in css
    assert "var(--theme-subtle)" in css
    assert "var(--border)" in css
    assert "var(--card)" in refinement_css
    assert "var(--text)" in refinement_css


def test_captain_ui_uses_directory_people_and_preserves_reusable_knowledge_boundary():
    js = read("setup_training_ux.js")
    css = read("setup_training_ux.css")
    assert "Task Captains / Knowledge Owners" in js
    assert "2025 crew names do not assign Captains automatically" in js
    assert "Person from MSB directory" in js
    assert "CAPTAIN" in js
    assert "ALTERNATE" in js
    assert "ADVISOR" in js
    assert "api/setup/captain-people" in js
    assert "/captains`" in js or "/captains'" in js
    assert "No Captain / Alternate / Advisor assigned" in js
    assert ".setup-captain-section" in css
    assert ".setup-captain-manager[hidden]" in css


def test_captain_picker_is_collapsed_typeahead_not_always_open_directory_list():
    js = read("setup_training_review_refinement.js")
    css = read("setup_training_review_refinement.css")
    assert "select.removeAttribute('size')" in js
    assert "selectLabel.hidden = true" in js
    assert "Type at least 2 characters" in js
    assert "setup-captain-typeahead-results" in js
    assert ".slice(0, 10)" in js
    assert "Selected:" in js
    assert ".setup-captain-typeahead-results[hidden]" in css
    assert ".setup-captain-picker-grid > label[hidden]" in css
    assert "display: none !important" in css


def test_captain_database_contract_uses_existing_relation_and_narrow_commands():
    sql = read_db("020_add_setup_captain_management_commands.sql")
    assert "ref.setup_task_captain" in sql
    assert "ref.setup_task_captain_list" in sql
    assert "ref.setup_captain_person_list" in sql
    assert "ref.set_setup_task_captain" in sql
    assert "CAPTAIN', 'ALTERNATE', 'ADVISOR" in sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_task_captain" in sql
    assert "DELETE FROM ref.setup_task_captain" in sql
    assert "ref.setup_management_actor(p_email, false)" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_captain" in sql
    assert "TO fieldwiring_app" in sql


def test_captain_api_reads_projections_and_writes_only_security_definer_command():
    api_source = read("setup_training_api.py")
    ast.parse(api_source)
    assert '@setup_training_api.get("/api/setup/tasks/<int:setup_task_id>/captains")' in api_source
    assert '@setup_training_api.get("/api/setup/captain-people")' in api_source
    assert '@setup_training_api.patch("/api/setup/tasks/<int:setup_task_id>/captains/<int:person_id>")' in api_source
    assert "ref.setup_task_captain_list" in api_source
    assert "ref.setup_captain_person_list" in api_source
    assert "ref.set_setup_task_captain" in api_source
    assert "require_manager()" in api_source


def test_reusable_task_match_action_is_explicit_about_target_and_scope():
    js = read("setup_assigned_review.js")
    assert "Confirm Reusable Task Match" in js
    assert "Matched to Reusable Task" in js
    assert "Current reusable scope:" in js
    assert "does NOT move the task or change its Stage / Scene scope" in js
    assert "setup-reusable-match-target" in js
    assert "2025 item → reusable task match" in js
    assert "verification_state: 'ASSIGNED'" in js
    assert "MATCH CONFIRMED" in js


def test_reconstruction_delete_is_visible_for_catalog_only_tasks_in_historical_manager_context():
    base_js = read("setup_training_ux.js")
    refinement_js = read("setup_training_review_refinement.js")
    css = read("setup_training_ux.css")
    combined = base_js + "\n" + refinement_js
    assert "Delete Reconstruction Task" in base_js
    assert "button.textContent = 'Delete Task'" in refinement_js
    assert "HISTORICAL_VERIFICATION" in combined
    assert "appState.access?.can_manage_setup" in refinement_js
    assert "task?.setup_task_id != null" in refinement_js
    assert "catalogDeleteVisibilityObserver" in refinement_js
    assert "attributeFilter: ['hidden']" in refinement_js
    assert "reconstruction-delete" in base_js
    assert "commandOptions('DELETE', {})" in base_js
    assert "work-day, progress, movement, planning, or actual execution history" in base_js
    assert "#delete-reconstruction-task.danger" in css


def test_reconstruction_delete_command_fails_closed_on_real_history():
    sql = read_db("019_add_reconstruction_safe_task_delete.sql")
    assert "ref.delete_setup_reconstruction_task" in sql
    assert "ss.session_status <> 'HISTORICAL_VERIFICATION'" in sql
    assert "ops.setup_work_day_task" in sql
    assert "ops.setup_task_progress" in sql
    assert "ops.setup_movement_event" in sql
    assert "st.actual_started_at IS NOT NULL" in sql
    assert "st.actual_completed_at IS NOT NULL" in sql
    assert "st.completed_by_person_id IS NOT NULL" in sql
    assert "DELETE FROM ops.setup_session_task" in sql
    assert "DELETE FROM ref.setup_task_dependency" in sql
    assert "DELETE FROM ref.setup_task_display" in sql
    assert "DELETE FROM ref.setup_task_container_support" in sql
    assert "DELETE FROM ref.setup_task_captain" in sql
    assert "DELETE FROM ref.setup_task_resource" in sql
    assert "DELETE FROM ref.setup_task t" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) TO fieldwiring_app" in sql
    assert "Do not CASCADE" in sql


def test_training_api_is_registered_and_static_assets_are_allowlisted():
    host = read("production_backend.py")
    api_source = read("setup_training_api.py")
    ast.parse(host)
    ast.parse(api_source)
    assert "from setup_training_api import setup_training_api" in host
    assert "app.register_blueprint(setup_training_api)" in host
    assert '"setup_training_ux.css"' in host
    assert '"setup_training_ux.js"' in host
    assert '"setup_training_review_refinement.css"' in host
    assert '"setup_training_review_refinement.js"' in host
    assert '@setup_training_api.delete("/api/setup/tasks/<int:setup_task_id>/reconstruction-delete")' in api_source
    assert "ref.delete_setup_reconstruction_task" in api_source
    assert "conn.set_session(readonly=False, autocommit=False)" in api_source
    assert "conn.rollback()" in api_source
