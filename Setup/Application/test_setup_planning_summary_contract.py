from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_planning_summary_is_reader_only_reusable_projection() -> None:
    source = read("setup_planning_summary_api.py")
    assert '@setup_planning_summary_api.get("/api/setup/planning-summary")' in source
    assert "require_reader()" in source
    assert "WHERE t.active_flag" in source
    assert "ops.create_setup_session" not in source
    assert "ops.setup_session_task" not in source
    assert "setup_work_day" not in source
    assert "season_year=0" in source


def test_planning_summary_reuses_current_material_and_procedure_resolvers() -> None:
    source = read("setup_planning_summary_api.py")
    assert "SetupNextRepository" in source
    assert ".field_context(" in source
    assert "_task_instructions" in source
    assert "is_real_setup_scene" in source
    assert "ref.lor_scene_display" not in source
    assert "ref.setup_task_display" not in source


def test_planning_summary_preserves_material_relationship_boundaries() -> None:
    source = read("setup_planning_summary_api.py")
    assert "ref.setup_task_container_support" in source
    assert "ref.setup_task_extra_material" in source
    assert "ref.setup_task_extra_material_source" in source
    assert 'row for row in task["extra_materials"]' in source
    assert 'row.get("material_name") == "T-Post"' in source
    assert "inventory_event" not in source
    assert "on_hand_quantity" not in source


def test_planning_summary_does_not_invent_reusable_task_verification() -> None:
    source = read("setup_planning_summary_api.py")
    assert "verification_boundary" in source
    assert "Reusable tasks do not have a reusable task-level verification state" in source
    assert "source_verification_state" in source
    assert "review_indicators" in source


def test_print_surface_is_dated_disposable_and_compact() -> None:
    html = read("planning_summary.html")
    js = read("setup_planning_summary.js")
    css = read("setup_planning_summary.css")

    assert '<option value="stage">Stage</option>' in html
    assert '<option value="scene">Stage + real Scene</option>' in html
    assert '<option value="all">All reusable Setup planning</option>' in html
    assert "Printed:" in html
    assert "DISPOSABLE PLANNING MARKUP" in html
    assert "FOR CATALOG VERIFICATION / REVIEW ONLY" in html
    assert "Print / Save PDF" in html
    assert "window.print()" in js
    assert "correction-space" in js
    assert "T-Post" in js
    assert "grid-template-columns: repeat(2" in css
    assert "size: landscape" in css
    assert "@media print" in css


def test_catalog_exposes_contextual_stage_scene_and_broad_print_launchers() -> None:
    production = read("production.html")
    js = read("setup_planning_summary.js")

    assert 'setup_planning_summary.js?v=2026-09-15.2' in production
    assert "Print Planning Summary…" in js
    assert "Print Stage" in js
    assert "Print Scene" in js
    assert "next-stage-group:not(.next-sitewide-group)" in js
    assert "next-scope-group" in js
    assert "dataset.sceneId" in js
    assert "stage_id" in js
    assert "lor_scene_id" in js
    assert "applyRequestedScope" in js
    assert "await loadSummary()" in js
    assert "window.open" in js
    assert "window.print()" not in js.split("if (!qs('scope-select') || !qs('summary-root'))")[0]


def test_production_host_exposes_planning_summary_without_replacing_main_app() -> None:
    backend = read("production_backend.py")
    assert "setup_planning_summary_api" in backend
    assert '"/planning-summary/"' in backend
    assert '"setup_planning_summary.css"' in backend
    assert '"setup_planning_summary.js"' in backend
    assert backend.count('"setup_planning_summary.js"') >= 2
    assert 'send_from_directory(BASE_DIR, "planning_summary.html")' in backend
