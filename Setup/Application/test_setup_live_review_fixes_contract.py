from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent


def test_live_review_dark_mode_defines_next_pass_surface_aliases() -> None:
    css = (APP_DIR / "setup_live_review_fixes.css").read_text(encoding="utf-8")
    assert "--panel: var(--card);" in css
    assert "--soft: var(--theme-subtle);" in css
    assert ".access-badge" in css
    assert "background: var(--soft);" in css
    assert "color: var(--text);" in css
    assert "border-color: var(--border);" in css
    for selector in (
        ".next-stage-body",
        ".next-sitewide-note",
        ".next-scope-group > summary",
        ".next-scope-dropzone",
        ".next-task-row",
        ".acceptance-scope-actions",
    ):
        assert selector in css
    assert "background: var(--panel);" in css
    assert "background: var(--soft);" in css
    assert ".next-task-row .task-meta" in css
    assert 'html[data-theme="dark"] button.warning' in css
    assert "color: #18212b;" in css


def test_live_review_restores_task_and_stage_search() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    js = (APP_DIR / "setup_live_review_fixes.js").read_text(encoding="utf-8")
    backend = (APP_DIR / "production_backend.py").read_text(encoding="utf-8")

    assert "setup_live_review_fixes.css" in html
    assert "setup_live_review_fixes.js" in html
    assert html.index("setup_session_year_guard.js") < html.index("setup_live_review_fixes.js")
    assert '"setup_live_review_fixes.css"' in backend
    assert '"setup_live_review_fixes.js"' in backend

    assert "setup-task-search" in js
    assert "Find task or Stage" in js
    assert "taskMatchesSearch" in js
    assert "renderReviewListWithLiveSearch" in js
    assert "renderLibraryWithLiveSearch" in js
    for field in ("task_name", "stage_key", "stage_name", "scene_name", "task_action_type"):
        assert field in js


def test_changed_live_review_assets_use_fresh_cache_keys() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")

    # Resource assets remain at the accepted 2026-09-08.1 revision. The live
    # review pair advances together for the task-detail hierarchy pass so both
    # the teaching markup behavior and the final dark/light-safe styles refresh.
    for asset in (
        "setup_resource_review.css?v=2026-09-08.1",
        "setup_resource_review.js?v=2026-09-08.1",
        "setup_live_review_fixes.css?v=2026-09-08.3",
        "setup_live_review_fixes.js?v=2026-09-08.3",
    ):
        assert asset in html

    assert "setup_live_review_fixes.js?v=2026-09-08.2" not in html
    assert "setup_live_review_fixes.css?v=2026-09-08.1" not in html
    assert "setup_live_review_fixes.js?v=2026-09-07.1" not in html
    assert "setup_live_review_fixes.css?v=2026-09-07.1" not in html


def test_live_review_filters_raw_lor_rows_to_true_setup_scenes() -> None:
    js = (APP_DIR / "setup_live_review_fixes.js").read_text(encoding="utf-8")

    # The live Setup UI must follow the existing Folder Alignment naming contract
    # rather than treating every ref.lor_scene row as a scheduler Scene.
    for marker in (
        "classifySetupLORSceneName",
        "isTrueSetupScene",
        "DISPLAY_OR_GROUP",
        "STAGE_ROOT",
        "SUB_STAGE_ROOT",
        "NON_SCENE_LOR_GROUP_PRESENTED_AT_STAGE",
        "loadNextOrganizationWithTrueScenes",
        "normalizeCurrentSetupOrganization",
    ):
        assert marker in js

    # Production acceptance fixtures from the Manager review.
    for true_scene in (
        "01-Front Gate",
        "02-Mega Tree",
        "02-Fred's Stars",
    ):
        assert true_scene in js

    for display_group in (
        "Abominable",
        "CharlieInTheBox",
        "Frosty",
        "Headlights",
        "Narwhal",
        "Signage",
        "US Flag",
        "Volunteer Path Lights",
    ):
        assert display_group in js

    # Scheduler / Perform Work labels must use the same normalized scope view.
    assert "nextTaskLabelWithTrueSceneScope" in js
    assert "nextTaskScopeLabelWithTrueSceneScope" in js


def test_library_render_normalizes_scene_scope_before_first_render() -> None:
    js = (APP_DIR / "setup_live_review_fixes.js").read_text(encoding="utf-8")

    # setup_next_pass.js begins initializeNextPass() before this later script
    # loads. The first organization request can therefore already be in flight
    # when loadNextOrganization is wrapped. Normalizing immediately before every
    # library render closes that race: the resumed initializer calls the current
    # global renderLibrary wrapper, which filters raw LOR rows before markup is
    # created.
    marker = "renderLibrary = function renderLibraryWithLiveSearch() {"
    body = js.split(marker, 1)[1].split("};", 1)[0]
    assert "normalizeCurrentSetupOrganization();" in body
    assert "priorRenderLibrary();" in body
    assert body.index("normalizeCurrentSetupOrganization();") < body.index("priorRenderLibrary();")


def test_task_detail_sections_teach_their_purpose_without_visual_noise() -> None:
    js = (APP_DIR / "setup_live_review_fixes.js").read_text(encoding="utf-8")
    css = (APP_DIR / "setup_live_review_fixes.css").read_text(encoding="utf-8")

    for marker in (
        "installTaskDetailHierarchy",
        "1. Reusable Task Definition",
        "2. Prerequisites",
        "3. Equipment / Resources",
        "4. Setup Procedures",
        "Permanent Setup knowledge used year after year",
        "What must be complete before this task can start",
        "Quantity is how many this task needs",
        "Published field instructions and the editable source",
        "Resource catalog",
        "Create New Catalog Resource",
        "Use this only when the reusable resource does not already exist",
    ):
        assert marker in js

    for selector in (
        ".detail-section.task-detail-panel",
        ".task-detail-definition",
        ".task-detail-prerequisites",
        ".task-detail-resources",
        ".task-detail-procedures",
        ".task-detail-subpanel",
        ".task-section-purpose",
        ".task-resource-catalog-block",
    ):
        assert selector in css

    # Use existing theme-safe semantic colors rather than introducing a bright
    # independent palette that would drift between light and dark mode.
    assert "--task-section-accent: var(--accent);" in css
    assert "--task-section-accent: var(--warning);" in css
    assert "--task-section-accent: var(--success);" in css
