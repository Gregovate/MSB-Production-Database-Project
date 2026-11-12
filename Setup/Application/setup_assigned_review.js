/* 2025 reconciliation queue semantics: ASSIGNED leaves the active queue. */

(() => {
  function ensureAssignedFilterOption() {
    const select = document.getElementById('review-status-filter');
    if (!select) return;
    let option = select.querySelector('option[value="ASSIGNED"]');
    if (!option) {
      option = document.createElement('option');
      option.value = 'ASSIGNED';
      select.appendChild(option);
    }
    option.textContent = 'Matched to Reusable Task';
  }

  function applyAssignedQueueVisibility() {
    const select = document.getElementById('review-status-filter');
    const target = document.getElementById('review-list');
    if (!select || !target) return;
    const filter = select.value;

    if (filter !== '') return;

    let visible = 0;
    target.querySelectorAll('.task-row').forEach((row) => {
      const task = taskById(Number(row.dataset.taskId));
      const hide = task?.verification_state === 'ASSIGNED';
      row.hidden = hide;
      if (!hide) visible += 1;
    });

    target.querySelector('.setup-assigned-empty')?.remove();
    if (visible === 0 && target.querySelector('.task-row')) {
      const empty = document.createElement('div');
      empty.className = 'empty-state setup-assigned-empty';
      empty.textContent = 'No actionable 2025 reconciliation items remain. Confirmed matches are available from the Matched to Reusable Task filter.';
      target.appendChild(empty);
    }
  }

  function reusableScopeLabel(task) {
    if (!task || task.stage_id == null) return 'Site-wide / Infrastructure';
    const stage = `Stage ${task.stage_key || '—'}${task.stage_name ? ` — ${task.stage_name}` : ''}`;
    return task.scene_name ? `${stage} / Scene ${task.scene_name}` : `${stage} / Stage-level`;
  }

  function reusableMatchSummary(task) {
    if (!task) return '';
    return `Reusable task ${task.setup_task_id}: ${task.task_name} · ${reusableScopeLabel(task)}`;
  }

  function ensureReusableMatchTarget() {
    const actions = document.getElementById('annual-manager-actions');
    if (!actions) return null;
    let target = document.getElementById('setup-reusable-match-target');
    if (!target) {
      target = document.createElement('div');
      target.id = 'setup-reusable-match-target';
      target.className = 'setup-reusable-match-target';
      actions.insertAdjacentElement('beforebegin', target);
    }
    return target;
  }

  function updateReusableMatchTarget(taskId = appState.selectedTaskId) {
    const target = ensureReusableMatchTarget();
    if (!target) return;
    const task = taskById(taskId);
    if (!task || task.setup_session_task_id == null || !appState.access?.can_manage_setup) {
      target.hidden = true;
      target.innerHTML = '';
      return;
    }
    target.hidden = false;
    target.innerHTML = `
      <strong>2025 item → reusable task match</strong>
      <div>${escapeHtml(reusableMatchSummary(task))}</div>
      <div class="muted">Confirming this match does not move the task or change its Stage / Scene scope.</div>
    `;
  }

  if (typeof verificationLabel === 'function') {
    const priorVerificationLabel = verificationLabel;
    verificationLabel = function verificationLabelWithAssigned(status) {
      if (status === 'ASSIGNED') return 'MATCH CONFIRMED';
      return priorVerificationLabel(status);
    };
  }

  if (typeof verificationClass === 'function') {
    const priorVerificationClass = verificationClass;
    verificationClass = function verificationClassWithAssigned(status) {
      if (status === 'ASSIGNED') return 'assigned';
      return priorVerificationClass(status);
    };
  }

  if (typeof renderReviewList === 'function') {
    const priorRenderReviewList = renderReviewList;
    renderReviewList = function renderReviewListWithoutAssignedByDefault() {
      ensureAssignedFilterOption();
      priorRenderReviewList();
      applyAssignedQueueVisibility();
    };
  }

  async function confirmSelectedReusableTaskMatch() {
    const task = taskById(appState.selectedTaskId);
    if (!task || task.setup_session_task_id == null || !appState.access?.can_manage_setup) return;

    const confirmed = window.confirm(
      `Confirm the 2025 item "${task.task_name}" matches reusable task ${task.setup_task_id} "${task.task_name}"?\n\n`
      + `Current reusable scope: ${reusableScopeLabel(task)}\n\n`
      + 'This confirms the annual item is matched to this reusable task. It does NOT move the task or change its Stage / Scene scope. '
      + 'Change Stage / Scene scope in the Reusable Task Definition or Catalog organization.\n\n'
      + 'After confirmation, this item leaves the default Verification Queue and remains available under Matched to Reusable Task.'
    );
    if (!confirmed) return;

    const payload = {
      verification_state: 'ASSIGNED',
      actual_started_at: task.actual_started_at || null,
      actual_completed_at: task.actual_completed_at || null,
      actual_crew_count: nullableInteger(document.getElementById('edit-actual-crew')?.value),
      actual_duration_minutes: nullableInteger(document.getElementById('edit-actual-duration')?.value),
      annual_notes: String(document.getElementById('edit-annual-notes')?.value || '').trim()
    };

    try {
      setBusy(true);
      await api(
        `api/setup/session-tasks/${task.setup_session_task_id}/review`,
        commandOptions('PATCH', payload)
      );
      appState.selectedTaskId = null;
      await reloadTasks(null);
      document.getElementById('review-detail').hidden = true;
      document.getElementById('review-empty').hidden = false;
      setAlert(
        `${task.task_name} is confirmed as matching reusable task ${task.setup_task_id}. Its Stage / Scene scope was not changed.`,
        'ok'
      );
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  function ensureConfirmMatchButton() {
    const actions = document.getElementById('annual-manager-actions');
    if (!actions) return;
    let button = document.getElementById('mark-assigned');
    if (!button) {
      button = document.createElement('button');
      button.id = 'mark-assigned';
      button.type = 'button';
      button.className = 'secondary';
      actions.appendChild(button);
    } else {
      button.replaceWith(button.cloneNode(true));
      button = document.getElementById('mark-assigned');
    }
    button.textContent = 'Confirm Reusable Task Match';
    button.addEventListener('click', confirmSelectedReusableTaskMatch);
  }

  ensureAssignedFilterOption();
  ensureReusableMatchTarget();
  ensureConfirmMatchButton();

  if (typeof selectTask === 'function') {
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithReusableMatchTarget(taskId) {
      const result = priorSelectTask(taskId);
      requestAnimationFrame(() => updateReusableMatchTarget(taskId));
      return result;
    };
  }

  if (appState.tasks?.length) renderReviewList();
})();
