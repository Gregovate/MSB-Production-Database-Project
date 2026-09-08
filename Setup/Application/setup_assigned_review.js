/* 2025 reconciliation queue semantics: ASSIGNED leaves the active queue. */

(() => {
  function ensureAssignedFilterOption() {
    const select = document.getElementById('review-status-filter');
    if (!select || select.querySelector('option[value="ASSIGNED"]')) return;
    const option = document.createElement('option');
    option.value = 'ASSIGNED';
    option.textContent = 'Assigned';
    select.appendChild(option);
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
      empty.textContent = 'No actionable 2025 reconciliation items remain. Assigned items are available from the Assigned filter.';
      target.appendChild(empty);
    }
  }

  if (typeof verificationLabel === 'function') {
    const priorVerificationLabel = verificationLabel;
    verificationLabel = function verificationLabelWithAssigned(status) {
      if (status === 'ASSIGNED') return 'ASSIGNED';
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

  async function markSelectedAssigned() {
    const task = taskById(appState.selectedTaskId);
    if (!task || task.setup_session_task_id == null || !appState.access?.can_manage_setup) return;

    const confirmed = window.confirm(
      `Mark "${task.task_name}" as Assigned to reusable task ${task.setup_task_id}?\n\n`
      + 'Assigned means this 2025 reconciliation item is accepted as belonging to this reusable task. '
      + 'It will leave the default Verification Queue but remain available under the Assigned filter.'
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
        `${task.task_name} is Assigned to reusable task ${task.setup_task_id} and has left the active 2025 Verification Queue.`,
        'ok'
      );
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  function ensureMarkAssignedButton() {
    const actions = document.getElementById('annual-manager-actions');
    if (!actions || document.getElementById('mark-assigned')) return;
    const button = document.createElement('button');
    button.id = 'mark-assigned';
    button.type = 'button';
    button.className = 'secondary';
    button.textContent = 'Mark Assigned';
    button.addEventListener('click', markSelectedAssigned);
    actions.appendChild(button);
  }

  ensureAssignedFilterOption();
  ensureMarkAssignedButton();
  if (appState.tasks?.length) renderReviewList();
})();
