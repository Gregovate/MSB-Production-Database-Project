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

  const CLIENT_BUILD = 'V0.3.12-display-ownership';
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
    badge.textContent = 'Client V0.3.12';
    badge.title = CLIENT_BUILD;
    access.insertAdjacentElement('afterend', badge);
  }

  function setBuildBadgeState(serverVersion, ok) {
    const badge = document.getElementById('setup-client-build-badge');
    if (!badge) return;
    badge.textContent = ok ? 'Client V0.3.12' : 'CLIENT / SERVER MISMATCH';
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
    const verification = verificationOverride || task.verification_state || 'UNVERIFIED';
    try {
      setBusy(true);
      await api(
        `api/setup/session-tasks/${task.setup_session_task_id}/review`,
        commandOptions('PATCH', {
          verification_state: verification,
          actual_crew_count: annual.actual_crew_count,
          actual_duration_minutes: annual.actual_duration_minutes,
          annual_notes: annual.annual_notes || null
        })
      );
      await reloadTasks(task.setup_task_id);
      if (announce) setAlert(`Annual ${appState.seasonYear} review saved.`, 'ok');
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

  async function resolveDirtyBeforeNavigation(actionLabel) {
    if (!anyDirty()) return true;
    if (!appState.access?.can_manage_setup) return false;

    const choice = window.prompt(
      `Unsaved ${dirtyDescription()} edits before ${actionLabel}.\n\nType SAVE to save and continue, DISCARD to discard and continue, or STAY to remain on this task.`,
      'STAY'
    );
    const normalized = String(choice || 'STAY').trim().toUpperCase();
    if (normalized === 'SAVE') {
      if (reusableDirty()) {
        const reusableSaved = await persistReusableEdits({ announce: false, preserveAnnualDraft: true });
        if (!reusableSaved) return false;
      }
      if (annualDirty()) {
        const annualSaved = await persistAnnualReview(null, { announce: false });
        if (!annualSaved) return false;
      }
      return true;
    }
    if (normalized === 'DISCARD') return true;
    return false;
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

  function interceptNavigation(event) {
    if (replayDepth > 0) return;

    const target = event.target.closest?.(
      '.task-row[data-task-id], .open-task[data-task-id], #setup-return-library, .tabs .tab, #season-select'
    );
    if (!target || !anyDirty()) return;

    let actionLabel = 'continuing';
    if (target.matches('.task-row[data-task-id], .open-task[data-task-id]')) actionLabel = 'opening another task';
    else if (target.matches('#setup-return-library')) actionLabel = 'returning to the Reusable Task Catalog';
    else if (target.matches('.tabs .tab')) actionLabel = 'changing Setup views';
    else if (target.matches('#season-select')) actionLabel = 'changing Setup seasons';

    event.preventDefault();
    event.stopImmediatePropagation();
    const replayTarget = target;
    resolveDirtyBeforeNavigation(actionLabel).then((allow) => {
      if (!allow) {
        syncDirtyIndicators();
        return;
      }
      replayDepth += 1;
      try {
        if (replayTarget.matches('#season-select')) {
          const selected = replayTarget.value;
          replayTarget.dispatchEvent(new Event('change', { bubbles: true }));
          replayTarget.value = selected;
        } else {
          replayTarget.click();
        }
      } finally {
        window.setTimeout(() => { replayDepth -= 1; }, 0);
      }
    });
  }

  function interceptAction(event) {
    if (replayDepth > 0) return;
    const target = event.target.closest?.(
      '#save-reusable-task, #save-annual-review, #mark-verified, #mark-correction, #mark-unverified, ' +
      '#next-dependency-add-button, .next-dependency-remove'
    );
    if (!target) return;

    const buttonId = target.id;
    if (buttonId === 'save-reusable-task') {
      event.preventDefault();
      event.stopImmediatePropagation();
      persistReusableEdits();
      return;
    }
    if (buttonId === 'save-annual-review') {
      event.preventDefault();
      event.stopImmediatePropagation();
      persistAnnualReview();
      return;
    }

    const annualOverrides = {
      'mark-verified': 'VERIFIED',
      'mark-correction': 'NEEDS_CORRECTION',
      'mark-unverified': 'UNVERIFIED'
    };
    if (Object.prototype.hasOwnProperty.call(annualOverrides, buttonId)) {
      event.preventDefault();
      event.stopImmediatePropagation();
      (async () => {
        if (reusableDirty()) {
          const reusableSaved = await persistReusableEdits({ announce: false, preserveAnnualDraft: true });
          if (!reusableSaved) return;
        }
        await persistAnnualReview(annualOverrides[buttonId]);
      })();
      return;
    }

    if (target.matches('#next-dependency-add-button, .next-dependency-remove') && anyDirty()) {
      event.preventDefault();
      event.stopImmediatePropagation();
      resolveDirtyBeforeNavigation('changing task prerequisites').then((allow) => {
        if (!allow) return;
        replayDepth += 1;
        try {
          target.click();
        } finally {
          window.setTimeout(() => { replayDepth -= 1; }, 0);
        }
      });
    }
  }

  document.addEventListener('input', syncDirtyIndicators, true);
  window.addEventListener('change', syncDirtyIndicators, true);
  window.addEventListener('click', interceptAction, true);
  window.addEventListener('click', interceptNavigation, true);
  window.addEventListener('change', interceptNavigation, true);
  window.addEventListener('beforeunload', (event) => {
    if (!anyDirty()) return;
    event.preventDefault();
    event.returnValue = '';
  });

  installBuildBadge();
  installSelectionRefreshWrapper();
  syncDirtyIndicators();
  ensureServerBuild();
})();
