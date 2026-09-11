from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def guard_source() -> str:
    return read("setup_catalog_dirty_guard.js")


def test_dirty_guard_asset_is_loaded_last_and_protected():
    html = read("production.html")
    host = read("production_backend.py")
    guard_index = html.index("setup_catalog_dirty_guard.js?v=2026-09-10.1")
    effort_index = html.index("setup_catalog_effort.js?v=2026-09-09.3")
    assert guard_index > effort_index
    assert '"setup_catalog_dirty_guard.js"' in host


def test_dirty_guard_compares_live_form_directly_to_selected_task():
    js = guard_source()
    assert "function reusableFormState()" in js
    assert "function reusableTaskState(task)" in js
    assert "function annualFormState()" in js
    assert "function annualTaskState(task)" in js
    assert "!sameState(reusableFormState(), reusableTaskState(task))" in js
    assert "!sameState(annualFormState(), annualTaskState(task))" in js
    assert "baseline" not in js


def test_dirty_guard_tracks_only_main_reusable_and_annual_save_surfaces():
    js = guard_source()
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

    assert "edit-effort-level" not in js
    assert "edit-requires-display-material" not in js
    assert "setup-resource-select" not in js
    assert "setup-captain-person" not in js


def test_mark_verified_saves_reusable_definition_before_annual_review():
    js = guard_source()
    assert "'mark-verified': 'VERIFIED'" in js
    assert "if (reusableDirty())" in js
    assert "persistReusableEdits({ announce: false, preserveAnnualDraft: true })" in js
    assert "if (!reusableSaved) return;" in js
    assert "await persistAnnualReview(overrides[buttonId]);" in js
    assert "api/setup/tasks/${task.setup_task_id}" in js
    assert "api/setup/session-tasks/${task.setup_session_task_id}/review" in js


def test_reusable_save_preserves_pending_annual_fields_across_reload():
    js = guard_source()
    assert "const preservedAnnual = preserveAnnualDraft ? annualDraft() : null;" in js
    assert "await reloadTasks(task.setup_task_id);" in js
    assert "restoreAnnualDraft(preservedAnnual);" in js


def test_client_build_is_visible_and_write_paths_fail_closed_on_mismatch():
    js = guard_source()
    assert "V0.3.7-catalog-dirty-edit-followup" in js
    assert "setup-client-build-badge" in js
    assert "window.msbSetupClientBuild = CLIENT_BUILD" in js
    assert "async function ensureServerBuild()" in js
    assert "serverVersion === CLIENT_BUILD" in js
    assert "Refresh the page before making changes" in js
    assert "if (!await ensureServerBuild()) return false;" in js


def test_navigation_uses_explicit_save_discard_cancel_decision():
    js = guard_source()
    assert "Save and continue" in js
    assert "Discard and continue" in js
    assert "Stay on this task" in js
    assert "resolveDirtyBeforeNavigation('opening another task')" in js
    assert "resolveDirtyBeforeNavigation('returning to the Reusable Task Catalog')" in js
    assert "changing Setup seasons" in js
    assert "beforeunload" in js


def test_prerequisite_reload_path_is_guarded_too():
    js = guard_source()
    assert "#next-dependency-add-button, .next-dependency-remove" in js
    assert "resolveDirtyBeforeNavigation('changing task prerequisites')" in js


def test_existing_save_handlers_are_preempted_at_window_capture_boundary():
    js = guard_source()
    assert "window.addEventListener('click'" in js
    assert "window.addEventListener('change'" in js
    assert "event.stopImmediatePropagation();" in js
    assert "replayDepth" in js
    assert "installSelectionRefreshWrapper" in js
