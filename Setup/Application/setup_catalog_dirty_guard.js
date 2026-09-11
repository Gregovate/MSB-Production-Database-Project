/* Setup reusable/annual review dirty-edit protection.
 *
 * Issue #154: a Manager must never lose pending task edits merely because an
 * annual verification action, prerequisite change, task switch, or season/view
 * navigation reloads the selected task.
 *
 * This guard deliberately tracks only the fields owned by the existing
 * "Save Reusable Task" and "Save Annual Review" commands. Physical Effort,
 * Display/Container Material, resources, and Captains remain independent
 * governed save surfaces and are not folded into either payload here.
 */

(() => {
  'use strict';

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

  let baseline = null;
  let replayDepth = 0;
  let installed = false;

  function controlValue(id) {
    const node = document.getElementById(id);
    if (!node) return null;
    return node.type === 'checkbox' ? Boolean(node.checked) : String(node.value ?? '');
  }

  function snapshot(fieldIds) {
    const values = {};
    fieldIds.forEach((id) => {
      values[id] = controlValue(id);
    });
    return values;
  }

  function sameSnapshot(left, right) {
    return JSON.stringify(left || {}) === JSON.stringify(right || {});
  }

  function captureBaseline(taskId = appState.selectedTaskId) {
    if (taskId == null || Number(taskId) !== Number(appState.selectedTaskId)) {
      baseline = null;
      syncDirtyIndicators();
      return;
    }

    baseline = {
      taskId: Number(taskId),
      reusable: snapshot(reusableFieldIds),
      annual: snapshot(annualFieldIds)
    };
    syncDirtyIndicators();
  }

  function baselineMatchesSelection() {
    return baseline && Number(baseline.taskId) === Number(appState.selectedTaskId);
  }

  function reusableDirty() {
    return Boolean(
      baselineMatchesSelection()
      && !sameSnapshot(baseline.reusable, snapshot(reusableFieldIds))
    );
  }

  function annualDirty() {
    return Boolean(
      baselineMatchesSelection()
      && !sameSnapshot(baseline.annual, snapshot(annualFieldIds))
    );
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

  function syncButtonLabel(id, cleanLabel, dirtyLabel, dirty) {
    const button = document.getElementById(id);
    if (!button) return;
    button.textContent = dirty ? dirtyLabel : cleanLabel;
    button.dataset.unsaved = dirty ? '1' : '0';
  }

  function syncDirtyIndicators() {
    syncButtonLabel(
      'save-reusable-task',
      'Save Reusable Task',
      'Save Reusable Task • Unsaved',
      reusableDirty()
    );
    syncButtonLabel(
      'save-annual-review',
      'Save Annual Review',
      'Save Annual Review • Unsaved',
      annualDirty()
    );
  }

  function reusablePayload() {
    return {
      task_name: el('edit-task-name').value.trim(),
      stage_id: nullableInteger(el('edit-stage-id').value),
      task_action_type: el('edit-action-type').value,
      display_order: nullableInteger(el('edit-display-order').value) ?? 100,
      active_flag: el('edit-active-flag').checked,
      normal_crew_min: nullableInteger(el('edit-crew-min').value),
      normal_crew_max: nullableInteger(el('edit-crew-max').value),
      expected_duration_minutes: nullableInteger(el('edit-duration-minutes').value),
      completion_point: el('edit-completion').value.trim(),
      readiness_note: el('edit-readiness').value.trim(),
      weather_note: el('edit-weather').value.trim(),
      reusable_notes: el('edit-reusable-notes').value.trim()
    };
  }

  function annualDraft() {
    return snapshot(annualFieldIds);
  }

  function restoreSnapshot(values) {
    Object.entries(values || {}).forEach(([id, value]) => {
      const node = document.getElementById(id);
      if (!node) return;
      if (node.type === 'checkbox') node.checked = Boolean(value);
      else node.value = value == null ? '' : String(value);
    });
    syncDirtyIndicators();
  }

  function annualPayload(verificationOverride = null) {
    const task = taskById(appState.selectedTaskId);
    return {
      verification_state: verificationOverride || task?.verification_state || 'UNVERIFIED',
      actual_started_at: task?.actual_started_at || null,
      actual_completed_at: task?.actual_completed_at || null,
      actual_crew_count: nullableInteger(el('edit-actual-crew').value),
      actual_duration_minutes: nullableInteger(el('edit-actual-duration').value),
      annual_notes: el('edit-annual-notes').value.trim()
    };
  }

  async function persistReusableEdits({ announce = true, preserveAnnualDraft = true } = {}) {
    const task = taskById(appState.selectedTaskId);
    if (!task || !appState.access?.can_manage_setup) return false;

    const preservedAnnual = preserveAnnualDraft ? annualDraft() : null;
    try {
      setBusy(true);
      await api(
        `api/setup/tasks/${task.setup_task_id}`,
        commandOptions('PATCH', reusablePayload())
      );
      await reloadTasks(task.setup_task_id);
      if (preservedAnnual && Number(appState.selectedTaskId) === Number(task.setup_task_id)) {
        restoreSnapshot(preservedAnnual);
      }
      if (announce) {
        setAlert(`Reusable task ${task.setup_task_id} saved to Production.`, 'ok');
      }
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
    const task = taskById(appState.selectedTaskId);
    if (!task || task.setup_session_task_id == null || !appState.access?.can_manage_setup) {
      return false;
    }

    try {
      setBusy(true);
      await api(
        `api/setup/session-tasks/${task.setup_session_task_id}/review`,
        commandOptions('PATCH', annualPayload(verificationOverride))
      );
      await reloadTasks(task.setup_task_id);
      if (announce) {
        const state = verificationOverride
          ? String(verificationOverride).replaceAll('_', ' ').toLocaleLowerCase()
          : 'saved';
        setAlert(`${appState.seasonYear} annual review ${state}.`, 'ok');
      }
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
    const taskId = appState.selectedTaskId;
    if (taskId == null || !taskById(taskId)) {
      baseline = null;
      syncDirtyIndicators();
      return;
    }
    selectTask(Number(taskId));
  }

  async function resolveDirtyBeforeNavigation(actionLabel) {
    if (!anyDirty()) return true;

    const saveFirst = window.confirm(
      `You have unsaved ${dirtyDescription()} edits.\n\n`
      + `Save them before ${actionLabel}?\n\n`
      + 'OK = Save and continue\nCancel = choose whether to discard or stay here'
    );

    if (saveFirst) {
      return saveDirtySurfaces();
    }

    const discard = window.confirm(
      `Discard the unsaved ${dirtyDescription()} edits and ${actionLabel}?\n\n`
      + 'OK = Discard and continue\nCancel = Stay on this task'
    );
    if (!discard) return false;

    discardCurrentDrafts();
    return true;
  }

  async function resolveDirtyBeforeDelete() {
    if (!anyDirty()) return true;
    const discard = window.confirm(
      `This task has unsaved ${dirtyDescription()} edits.\n\n`
      + 'Deleting the task cannot preserve those drafts. Discard them and continue to the delete confirmation?'
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

  function taskIdFromClickTarget(target) {
    const row = target.closest('#review-list .task-row, #library-view .open-task');
    if (!row) return null;
    return Number(row.dataset.taskId || 0) || null;
  }

  function installSelectionBaselineWrapper() {
    if (typeof selectTask !== 'function' || selectTask.__dirtyGuardWrapped) return;
    const priorSelectTask = selectTask;
    const wrapped = function selectTaskWithDirtyBaseline(taskId) {
      const result = priorSelectTask(taskId);
      captureBaseline(taskId);
      return result;
    };
    wrapped.__dirtyGuardWrapped = true;
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
        const proceed = await resolveDirtyBeforeNavigation('changing Setup seasons');
        if (!proceed) {
          select.value = currentYear;
          return;
        }
        select.value = requestedYear;
        baseline = null;
        syncDirtyIndicators();
        await loadSeason(requestedYear);
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

      const annualButton = target.closest(
        '#save-annual-review, #mark-verified, #mark-correction, #mark-unverified'
      );
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
          if (await resolveDirtyBeforeNavigation('changing task prerequisites')) {
            replayClick(dependencyAction);
          }
        })();
        return;
      }

      const requestedTaskId = taskIdFromClickTarget(target);
      if (
        requestedTaskId != null
        && Number(requestedTaskId) !== Number(appState.selectedTaskId)
        && anyDirty()
      ) {
        const replayTarget = target.closest('#library-view .open-task')
          || target.closest('#review-list .task-row');
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
          if (await resolveDirtyBeforeNavigation('returning to the Reusable Task Catalog')) {
            replayClick(returnToCatalog);
          }
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

  function initializeDirtyGuard() {
    if (installed) return;
    installed = true;
    installSelectionBaselineWrapper();
    installInputTracking();
    installSeasonGuard();
    installClickGuard();
    installUnloadGuard();
    syncDirtyIndicators();
  }

  if (document.readyState === 'complete') initializeDirtyGuard();
  else window.addEventListener('load', initializeDirtyGuard, { once: true });
})();
