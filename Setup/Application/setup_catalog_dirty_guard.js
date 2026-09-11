/* Setup reusable/annual review dirty-edit protection.
 *
 * Issue #154 follow-up after failed Production acceptance on 2026-09-10.
 *
 * The critical change from the first candidate is that dirty detection no longer
 * depends on an initialization baseline. The live form is compared directly to
 * the currently selected server-backed task object every time an action occurs.
 * Reusable edits must save successfully before an annual verification command
 * is allowed to run.
 */

(() => {
  'use strict';

  const CLIENT_BUILD = 'V0.3.8-task-detail-compact';
  const reusableFieldIds = new Set([
    'edit-task-name',
    'edit-stage-id',
    'edit-action-type',
    'edit-display-order',
    'edit-active-flag',
    'edit-crew-min',
    'edit-crew-max',
    'edit-duration-minutes',
    'edit-completion',
    'edit-readiness',
    'edit-weather',
    'edit-reusable-notes'
  ]);
  const annualFieldIds = new Set([
    'edit-actual-crew',
    'edit-actual-duration',
    'edit-annual-notes'
  ]);

  let replayDepth = 0;
  window.msbSetupClientBuild = CLIENT_BUILD;

  function normalizeText(value) {
    return String(value ?? '').trim();
  }

  function normalizeNullableInteger(value) {
    if (value == null || value === '') return null;
    const parsed = Number.parseInt(String(value), 10);
    return Number.isFinite(parsed) ? parsed : null;
  }

  function reusableFormState() {
    return {
      task_name: normalizeText(el('edit-task-name').value),
      stage_id: normalizeNullableInteger(el('edit-stage-id').value),
      task_action_type: el('edit-action-type').value || 'WORK',
      display_order: normalizeNullableInteger(el('edit-display-order').value) ?? 100,
      active_flag: Boolean(el('edit-active-flag').checked),
      normal_crew_min: normalizeNullableInteger(el('edit-crew-min').value),
      normal_crew_max: normalizeNullableInteger(el('edit-crew-max').value),
      expected_duration_minutes: normalizeNullableInteger(el('edit-duration-minutes').value),
      completion_point: normalizeText(el('edit-completion').value),
      readiness_note: normalizeText(el('edit-readiness').value),
      weather_note: normalizeText(el('edit-weather').value),
      reusable_notes: normalizeText(el('edit-reusable-notes').value)
    };
  }

  function reusableTaskState(task) {
    return {
      task_name: normalizeText(task?.task_name),
      stage_id: task?.stage_id == null ? null : Number(task.stage_id),
      task_action_type: task?.task_action_type || 'WORK',
      display_order: normalizeNullableInteger(task?.display_order) ?? 100,
      active_flag: Boolean(task?.active_flag),
      normal_crew_min: normalizeNullableInteger(task?.normal_crew_min),
      normal_crew_max: normalizeNullableInteger(task?.normal_crew_max),
      expected_duration_minutes: normalizeNullableInteger(task?.expected_duration_minutes),
      completion_point: normalizeText(task?.completion_point),
      readiness_note: normalizeText(task?.readiness_note),
      weather_note: normalizeText(task?.weather_note),
      reusable_notes: normalizeText(task?.reusable_notes)
    };
  }

  function annualFormState() {
    return {
      actual_crew_count: normalizeNullableInteger(el('edit-actual-crew').value),
      actual_duration_minutes: normalizeNullableInteger(el('edit-actual-duration').value),
      annual_notes: normalizeText(el('edit-annual-notes').value)
    };
  }

  function annualTaskState(task) {
    return {
      actual_crew_count: normalizeNullableInteger(task?.actual_crew_count),
      actual_duration_minutes: normalizeNullableInteger(task?.actual_duration_minutes),
      annual_notes: normalizeText(task?.annual_notes)
    };
  }

  function sameState(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
  }

  function selectedTask() {
    return taskById(appState.selectedTaskId);
  }

  function reusableDirty() {
    const task = selectedTask();
    return Boolean(task && !sameState(reusableFormState(), reusableTaskState(task)));
  }

  function annualDirty() {
    const task = selectedTask();
    return Boolean(task && !sameState(annualFormState(), annualTaskState(task)));
  }

  function anyDirty() {
    return reusableDirty() || annualDirty();
  }

  function dirtyDescription() {
    const parts = [];
    if (reusableDirty()) parts.push('reusable task');
    if (annualDirty()) parts.push(`${appState.seasonYear || 'annual'} review`);
    return parts.join(' and ') || 'task';
  }

  function installBuildBadge() {
    if (document.getElementById('setup-client-build-badge')) return;
    const access = document.getElementById('access-badge');
    if (!access) return;
    const badge = document.createElement('span');
    badge.id = 'setup-client-build-badge';
    badge.className = 'pill';
    badge.textContent = 'Client V0.3.8';
    badge.title = CLIENT_BUILD;
    access.insertAdjacentElement('afterend', badge);
  }

  function setBuildBadgeState(serverVersion, ok) {
    const badge = document.getElementById('setup-client-build-badge');
    if (!badge) return;
    badge.textContent = ok ? 'Client V0.3.8' : 'CLIENT / SERVER MISMATCH';
    badge.title = `Client ${CLIENT_BUILD}; server ${serverVersion || 'unknown'}`;
    badge.dataset.state = ok ? 'ok' : 'error';
  }

  async function ensureServerBuild() {
    try {
      const health = await api('api/health');
      const serverVersion = String(health?.version || '');
      const ok = serverVersion === CLIENT_BUILD;
      setBuildBadgeState(serverVersion, ok);
      if (!ok) {
        const message = `Setup client/server version mismatch. Client ${CLIENT_BUILD}; server ${serverVersion || 'unknown'}. Refresh the page before making changes.`;
        setAlert(message, 'error');
        window.alert(message);
      }
      return ok;
    } catch (error) {
      setBuildBadgeState('unavailable', false);
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
      return false;
    }
  }

  function syncButtonLabel(id, cleanLabel, dirtyLabel, dirty) {
    const button = document.getElementById(id);
    if (!button) return;
    button.textContent = dirty ? dirtyLabel : cleanLabel;
    button.dataset.unsaved = dirty ? '1' : '0';
  }

  function syncDirtyIndicators() {
    syncButtonLabel('save-reusable-task', 'Save Reusable Task', 'Save Reusable Task • Unsaved', reusableDirty());
    syncButtonLabel('save-annual-review', 'Save Annual Review', 'Save Annual Review • Unsaved', annualDirty());
  }

  function annualDraft() {
    return annualFormState();
  }

  function restoreAnnualDraft(values) {
    if (!values) return;
    el('edit-actual-crew').value = values.actual_crew_count ?? '';
    el('edit-actual-duration').value = values.actual_duration_minutes ?? '';
    el('edit-annual-notes').value = values.annual_notes ?? '';
    syncDirtyIndicators();
  }

  async function persistReusableEdits({ announce = true, preserveAnnualDraft = true } = {}) {
    const task = selectedTask();
    if (!task || !appState.access?.can_manage_setup) return false;
    if (!await ensureServerBuild()) return false;

    const preservedAnnual = preserveAnnualDraft ? annualDraft() : null;
    try {
      setBusy(true);
      await api(`api/setup/tasks/${task.setup_task_id}`, commandOptions('PATCH', reusableFormState()));
      await reloadTasks(task.setup_task_id);
      if (preservedAnnual && Number(appState.selectedTaskId) === Number(task.setup_task_id)) {
        restoreAnnualDraft(preservedAnnual);
      }
      if (announce) setAlert(`Reusable task ${task.setup_task_id} saved to Production.`, 'ok');
      return true;
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
      return false;
    } finally {
      setBusy(false);
      syncDirtyIndicators();
    }
  }

  async function persistAnnualReview(verificationOverride = null, { announce = true } = {}) {
    const task = selectedTask();
    if (!task || task.setup_session_task_id == null || !appState.access?.can_manage_setup) return false;
    if (!await ensureServerBuild()) return false;

    const annual = annualFormState();
    const payload = {
      verification_state: verificationOverride || task.verification_state || 'UNVERIFIED',
      actual_started_at: task.actual_started_at || null,
      actual_completed_at: task.actual_completed_at || null,
      actual_crew_count: annual.actual_crew_count,
      actual_duration_minutes: annual.actual_duration_minutes,
      annual_notes: annual.annual_notes
    };

    try {
      setBusy(true);
      await api(
        `api/setup/session-tasks/${task.setup_session_task_id}/review`,
        commandOptions('PATCH', payload)
      );
      await reloadTasks(task.setup_task_id);
      if (announce) setAlert(`${appState.seasonYear} annual review saved to Production.`, 'ok');
      return true;
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
      return false;
    } finally {
      setBusy(false);
      syncDirtyIndicators();
    }
  }

  async function handleAnnualAction(buttonId) {
    const overrides = {
      'save-annual-review': null,
      'mark-verified': 'VERIFIED',
      'mark-correction': 'NEEDS_CORRECTION',
      'mark-unverified': 'UNVERIFIED'
    };

    if (reusableDirty()) {
      const reusableSaved = await persistReusableEdits({ announce: false, preserveAnnualDraft: true });
      if (!reusableSaved) return;
    }
    await persistAnnualReview(overrides[buttonId]);
  }

  async function saveDirtySurfaces() {
    if (reusableDirty()) {
      const reusableSaved = await persistReusableEdits({ announce: false, preserveAnnualDraft: true });
      if (!reusableSaved) return false;
    }
    if (annualDirty()) {
      const annualSaved = await persistAnnualReview(null, { announce: false });
      if (!annualSaved) return false;
    }
    setAlert('Unsaved Setup task edits saved before continuing.', 'ok');
    return true;
  }

  function discardCurrentDrafts() {
    const task = selectedTask();
    if (task) selectTask(task.setup_task_id);
  }

  async function resolveDirtyBeforeNavigation(actionLabel) {
    if (!anyDirty()) return true;
    const saveFirst = window.confirm(
      `You have unsaved ${dirtyDescription()} edits.\n\nSave them before ${actionLabel}?\n\nOK = Save and continue\nCancel = choose whether to discard or stay here`
    );
    if (saveFirst) return saveDirtySurfaces();

    const discard = window.confirm(
      `Discard the unsaved ${dirtyDescription()} edits and ${actionLabel}?\n\nOK = Discard and continue\nCancel = Stay on this task`
    );
    if (!discard) return false;
    discardCurrentDrafts();
    return true;
  }

  async function resolveDirtyBeforeDelete() {
    if (!anyDirty()) return true;
    const discard = window.confirm(
      `This task has unsaved ${dirtyDescription()} edits.\n\nDeleting the task cannot preserve those drafts. Discard them and continue to the delete confirmation?`
    );
    if (!discard) return false;
    discardCurrentDrafts();
    return true;
  }

  function replayClick(target) {
    replayDepth += 1;
    try {
      target.click();
    } finally {
      replayDepth -= 1;
    }
  }

  function taskIdFromClickTarget(target) {
    const row = target.closest('#review-list .task-row, #library-view .open-task');
    if (!row) return null;
    return Number(row.dataset.taskId || 0) || null;
  }

  function installSelectionRefreshWrapper() {
    if (typeof selectTask !== 'function' || selectTask.__dirtyGuardV2Wrapped) return;
    const priorSelectTask = selectTask;
    const wrapped = function selectTaskWithDirtyRefresh(taskId) {
      const result = priorSelectTask(taskId);
      syncDirtyIndicators();
      return result;
    };
    wrapped.__dirtyGuardV2Wrapped = true;
    selectTask = wrapped;
  }

  function installInputTracking() {
    window.addEventListener('input', (event) => {
      const id = event.target?.id;
      if (reusableFieldIds.has(id) || annualFieldIds.has(id)) syncDirtyIndicators();
    }, true);
    window.addEventListener('change', (event) => {
      const id = event.target?.id;
      if (reusableFieldIds.has(id) || annualFieldIds.has(id)) syncDirtyIndicators();
    }, true);
  }

  function installSeasonGuard() {
    window.addEventListener('change', (event) => {
      if (replayDepth || event.target?.id !== 'season-select' || !anyDirty()) return;
      const select = event.target;
      const requestedYear = select.value;
      const currentYear = String(appState.seasonYear ?? '');
      event.preventDefault();
      event.stopImmediatePropagation();
      select.value = currentYear;
      void (async () => {
        if (!await resolveDirtyBeforeNavigation('changing Setup seasons')) return;
        select.value = requestedYear;
        await loadSeason(requestedYear);
        syncDirtyIndicators();
      })();
    }, true);
  }

  function installClickGuard() {
    window.addEventListener('click', (event) => {
      if (replayDepth) return;
      const target = event.target;
      if (!(target instanceof Element)) return;

      const saveReusable = target.closest('#save-reusable-task');
      if (saveReusable) {
        event.preventDefault();
        event.stopImmediatePropagation();
        void persistReusableEdits();
        return;
      }

      const annualButton = target.closest('#save-annual-review, #mark-verified, #mark-correction, #mark-unverified');
      if (annualButton) {
        event.preventDefault();
        event.stopImmediatePropagation();
        void handleAnnualAction(annualButton.id);
        return;
      }

      const deleteButton = target.closest('#delete-reconstruction-task');
      if (deleteButton && anyDirty()) {
        event.preventDefault();
        event.stopImmediatePropagation();
        void (async () => {
          if (await resolveDirtyBeforeDelete()) replayClick(deleteButton);
        })();
        return;
      }

      const dependencyAction = target.closest('#next-dependency-add-button, .next-dependency-remove');
      if (dependencyAction && anyDirty()) {
        event.preventDefault();
        event.stopImmediatePropagation();
        void (async () => {
          if (await resolveDirtyBeforeNavigation('changing task prerequisites')) replayClick(dependencyAction);
        })();
        return;
      }

      const requestedTaskId = taskIdFromClickTarget(target);
      if (requestedTaskId != null && requestedTaskId !== Number(appState.selectedTaskId) && anyDirty()) {
        const replayTarget = target.closest('#library-view .open-task') || target.closest('#review-list .task-row');
        if (!replayTarget) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        void (async () => {
          if (await resolveDirtyBeforeNavigation('opening another task')) replayClick(replayTarget);
        })();
        return;
      }

      const returnToCatalog = target.closest('#setup-return-library');
      if (returnToCatalog && anyDirty()) {
        event.preventDefault();
        event.stopImmediatePropagation();
        void (async () => {
          if (await resolveDirtyBeforeNavigation('returning to the Reusable Task Catalog')) replayClick(returnToCatalog);
        })();
        return;
      }

      const tab = target.closest('.tabs .tab');
      if (tab && !tab.classList.contains('active') && anyDirty()) {
        event.preventDefault();
        event.stopImmediatePropagation();
        void (async () => {
          if (await resolveDirtyBeforeNavigation(`opening ${tab.textContent.trim()}`)) replayClick(tab);
        })();
      }
    }, true);
  }

  function installUnloadGuard() {
    window.addEventListener('beforeunload', (event) => {
      if (!anyDirty()) return;
      event.preventDefault();
      event.returnValue = '';
    });
  }

  installBuildBadge();
  installSelectionRefreshWrapper();
  installInputTracking();
  installSeasonGuard();
  installClickGuard();
  installUnloadGuard();
  syncDirtyIndicators();
  void ensureServerBuild();
})();
