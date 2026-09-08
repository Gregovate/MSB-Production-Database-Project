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
