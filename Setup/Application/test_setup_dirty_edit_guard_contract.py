from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_dirty_guard_asset_is_already_part_of_protected_setup_surface():
    html = read("production.html")
    host = read("production_backend.py")
    assert 'setup_review_usability.js?v=2026-09-07.2' in html
    assert '"setup_review_usability.js"' in host


def test_dirty_guard_tracks_only_main_reusable_and_annual_save_surfaces():
    js = read("setup_review_usability.js")
    for field_id in (
        "edit-task-name",
        "edit-stage-id",
        "edit-action-type",
        "edit-display-order",
        "edit-active-flag",
        "edit-crew-min",
        "edit-crew-max",
        "edit-duration-minutes",
        "edit-completion",
        "edit-readiness",
        "edit-weather",
        "edit-reusable-notes",
        "edit-actual-crew",
        "edit-actual-duration",
        "edit-annual-notes",
    ):
        assert field_id in js

    # These have their own governed commands and must not be silently folded
    # into Save Reusable Task merely to implement Issue #154.
    assert "edit-effort-level" not in js
    assert "edit-requires-display-material" not in js
    assert "setup-resource-select" not in js
    assert "setup-captain-person" not in js


def test_mark_verified_saves_dirty_reusable_definition_before_annual_review():
    js = read("setup_review_usability.js")
    assert "'mark-verified': 'VERIFIED'" in js
    assert "if (reusableDirty())" in js
    assert "persistReusableEdits({ announce: false, preserveAnnualDraft: true })" in js
    assert "if (!reusableSaved) return;" in js
    assert "await persistAnnualReview(overrides[buttonId]);" in js
    assert "api/setup/tasks/${task.setup_task_id}" in js
    assert "api/setup/session-tasks/${task.setup_session_task_id}/review" in js


def test_reusable_save_preserves_pending_annual_fields_across_task_reload():
    js = read("setup_review_usability.js")
    assert "const preservedAnnual = preserveAnnualDraft ? annualDraft() : null;" in js
    assert "await reloadTasks(task.setup_task_id);" in js
    assert "restoreSnapshot(preservedAnnual);" in js


def test_navigation_uses_explicit_save_discard_cancel_decision():
    js = read("setup_review_usability.js")
    assert "Save and continue" in js
    assert "Discard and continue" in js
    assert "Stay on this task" in js
    assert "resolveDirtyBeforeNavigation('opening another task')" in js
    assert "resolveDirtyBeforeNavigation('returning to the Reusable Task Catalog')" in js
    assert "changing Setup seasons" in js
    assert "beforeunload" in js


def test_prerequisite_reload_path_is_guarded_too():
    js = read("setup_review_usability.js")
    assert "#next-dependency-add-button, .next-dependency-remove" in js
    assert "resolveDirtyBeforeNavigation('changing task prerequisites')" in js


def test_existing_save_handlers_are_preempted_at_window_capture_boundary():
    js = read("setup_review_usability.js")
    assert "window.addEventListener('click'" in js
    assert "window.addEventListener('change'" in js
    assert "event.stopImmediatePropagation();" in js
    assert "replayDepth" in js
    assert "installSelectionBaselineWrapper" in js
