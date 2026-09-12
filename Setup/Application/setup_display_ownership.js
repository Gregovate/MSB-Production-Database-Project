/* Issue #141 — task-specific Display ownership management layered after LOR resolution. */

(() => {
  const state = {
    requestToken: 0,
    taskId: null,
    context: null,
    draggedDisplayId: null
  };

  function ownership(context = state.context) {
    return context?.display_ownership || null;
  }

  function multiScope(context = state.context) {
    const mode = String(ownership(context)?.mode || '');
    return mode === 'UNINITIALIZED_MULTI' || mode === 'EXPLICIT_MULTI';
  }

  function ensureControl() {
    const section = document.getElementById('setup-material-context-section');
    const summary = document.getElementById('setup-material-context-summary');
    if (!section || !summary) return null;

    let control = document.getElementById('setup-display-ownership-control');
    if (!control) {
      control = document.createElement('div');
      control.id = 'setup-display-ownership-control';
      control.className = 'setup-display-ownership-control';
      control.hidden = true;
      control.innerHTML = `
        <button id="setup-display-ownership-open" type="button" class="secondary">Display Ownership</button>
        <span id="setup-display-ownership-status" class="setup-display-ownership-status"></span>
      `;
      summary.insertAdjacentElement('afterend', control);
      control.querySelector('#setup-display-ownership-open')?.addEventListener('click', openOwnershipDialog);
    }
    return control;
  }

  function ensureDialog() {
    let dialog = document.getElementById('setup-display-ownership-dialog');
    if (dialog) return dialog;

    dialog = document.createElement('dialog');
    dialog.id = 'setup-display-ownership-dialog';
    dialog.className = 'setup-display-ownership-dialog';
    dialog.innerHTML = `
      <div class="setup-display-ownership-heading">
        <div>
          <div class="eyebrow">Issue #141 · reusable task material subdivision</div>
          <h3 id="setup-display-ownership-title">Display Ownership</h3>
        </div>
        <button id="setup-display-ownership-close" type="button" class="secondary">Close</button>
      </div>
      <div id="setup-display-ownership-content" class="setup-display-ownership-content"></div>
    `;
    document.body.appendChild(dialog);
    dialog.querySelector('#setup-display-ownership-close')?.addEventListener('click', () => dialog.close());
    dialog.addEventListener('click', (event) => {
      if (event.target === dialog) dialog.close();
    });
    return dialog;
  }

  function ownershipStatusText(data) {
    if (!data) return '';
    if (data.coverage_status === 'COMPLETE') return 'Coverage complete';
    if (data.mode === 'UNINITIALIZED_MULTI') return 'Ownership not initialized';
    return 'Coverage review required';
  }

  function updateControl(context) {
    state.context = context || null;
    const control = ensureControl();
    if (!control) return;
    const data = ownership(context);
    control.hidden = !multiScope(context);
    if (control.hidden) return;

    const status = control.querySelector('#setup-display-ownership-status');
    if (status) {
      status.textContent = ownershipStatusText(data);
      status.className = `setup-display-ownership-status ${data?.coverage_status === 'COMPLETE' ? 'complete' : 'review'}`;
    }
  }

  function taskName(taskId, data) {
    const match = (data?.eligible_tasks || []).find(
      (task) => Number(task.setup_task_id) === Number(taskId)
    );
    return match?.task_name || `Task ${taskId}`;
  }

  function displayCard(row, canManage) {
    const stateLabel = String(row.ownership_state || '').replaceAll('_', ' ');
    const ownerText = row.owner_setup_task_id
      ? `Owner: ${row.owner_task_name || `Task ${row.owner_setup_task_id}`}`
      : 'No effective owner';
    const containerText = row.container_id == null
      ? 'No current Container'
      : `Container ${row.container_id}${row.container_description ? ` — ${row.container_description}` : ''}`;
    const reviewClass = row.ownership_state === 'ASSIGNED' ? '' : ' review';
    return `
      <div class="setup-display-owner-card${reviewClass}"
           data-display-id="${row.display_id}"
           data-owner-task-id="${row.owner_setup_task_id ?? ''}"
           draggable="${canManage ? 'true' : 'false'}">
        <strong>Display ${escapeHtml(row.display_id)} — ${escapeHtml(row.display_name || '')}</strong>
        <span>${escapeHtml(containerText)}</span>
        <span>${escapeHtml(ownerText)} · ${escapeHtml(stateLabel || 'ASSIGNED')}</span>
      </div>
    `;
  }

  function renderOwnershipBoard(context = state.context) {
    const dialog = ensureDialog();
    const content = dialog.querySelector('#setup-display-ownership-content');
    const title = dialog.querySelector('#setup-display-ownership-title');
    const data = ownership(context);
    const selectedTask = typeof taskById === 'function' ? taskById(appState.selectedTaskId) : null;
    if (title) title.textContent = `${selectedTask?.task_name || 'Reusable Task'} — Display Ownership`;
    if (!content) return;

    if (!data || !multiScope(context)) {
      content.innerHTML = '<div class="empty-state">This scope does not require explicit multi-task Display ownership.</div>';
      return;
    }

    const canManage = Boolean(appState.access?.can_manage_setup);
    const assignments = Array.isArray(data.assignments) ? data.assignments : [];
    const eligibleTasks = Array.isArray(data.eligible_tasks) ? data.eligible_tasks : [];
    const assignedByTask = new Map(
      eligibleTasks.map((task) => [Number(task.setup_task_id), []])
    );
    const reviewRows = [];

    assignments.forEach((row) => {
      const ownerId = Number(row.owner_setup_task_id || 0);
      if (row.ownership_state === 'ASSIGNED' && assignedByTask.has(ownerId)) {
        assignedByTask.get(ownerId).push(row);
      } else {
        reviewRows.push(row);
      }
    });

    const columns = eligibleTasks.map((task) => {
      const taskId = Number(task.setup_task_id);
      const rows = assignedByTask.get(taskId) || [];
      return `
        <section class="setup-display-owner-column" data-target-task-id="${taskId}">
          <div class="setup-display-owner-column-heading">
            <strong>${escapeHtml(task.task_name || `Task ${taskId}`)}</strong>
            <span>Reusable task ${taskId} · ${rows.length} Display${rows.length === 1 ? '' : 's'}</span>
          </div>
          <div class="setup-display-owner-cards">
            ${rows.length ? rows.map((row) => displayCard(row, canManage)).join('') : '<div class="setup-display-owner-empty">No Displays currently owned by this task.</div>'}
          </div>
        </section>
      `;
    }).join('');

    const reviewColumn = reviewRows.length ? `
      <section class="setup-display-owner-column setup-display-owner-review-column">
        <div class="setup-display-owner-column-heading">
          <strong>Needs ownership</strong>
          <span>${reviewRows.length} resolved Display${reviewRows.length === 1 ? '' : 's'} missing or conflicting</span>
        </div>
        <div class="setup-display-owner-cards">
          ${reviewRows.map((row) => displayCard(row, canManage)).join('')}
        </div>
      </section>
    ` : '';

    const init = data.can_initialize && canManage ? `
      <div class="setup-display-ownership-actions">
        <button id="setup-display-ownership-initialize" type="button">Initialize all resolved Displays to this task</button>
        <span class="muted">Use the current/default material-bearing task as the starting owner, then move Displays to the other real work packages.</span>
      </div>
    ` : '';

    const warning = data.coverage_status === 'COMPLETE' ? '' : `
      <div class="setup-display-ownership-warning">
        <strong>Coverage is not complete.</strong>
        Every current resolver Display must have exactly one effective reusable Setup-task owner before task-specific material demand is complete.
      </div>
    `;

    const stale = (data.stale_assignments || []).length ? `
      <div class="setup-display-owner-stale">
        <strong>Stale ownership rows requiring review</strong>
        <div class="muted">These rows are owned by tasks in this scope but the Display is no longer in the resolver source set.</div>
        ${(data.stale_assignments || []).map((row) => `
          <div>Display ${escapeHtml(row.display_id)} — ${escapeHtml(row.owner_task_name || `Task ${row.setup_task_id}`)}</div>
        `).join('')}
      </div>
    ` : '';

    content.innerHTML = `
      <div class="setup-display-ownership-facts">
        <div><span>Resolved source Displays</span><strong>${data.resolved_display_count ?? 0}</strong></div>
        <div><span>Owned</span><strong>${data.assigned_display_count ?? 0}</strong></div>
        <div><span>Missing owner</span><strong>${data.missing_owner_count ?? 0}</strong></div>
        <div><span>Invalid / duplicate</span><strong>${Number(data.invalid_owner_count || 0) + Number(data.duplicate_owner_count || 0)}</strong></div>
        <div><span>Stale rows</span><strong>${data.stale_owner_count ?? 0}</strong></div>
      </div>
      ${warning}
      ${init}
      <div class="muted" style="margin-bottom:10px;">
        The LOR resolver defines this source set. Dragging a Display changes Setup task ownership only; it does not change LOR membership or the Display's current Container.
      </div>
      <div class="setup-display-ownership-board">
        ${columns}
        ${reviewColumn}
      </div>
      ${stale}
    `;

    content.querySelector('#setup-display-ownership-initialize')?.addEventListener('click', initializeOwnership);
  }

  function updateMaterialCounts(context) {
    const summary = document.getElementById('setup-material-context-summary');
    if (summary) {
      const displays = Array.isArray(context?.displays) ? context.displays : [];
      const support = Array.isArray(context?.support_containers) ? context.support_containers : [];
      const containers = new Set();
      displays.forEach((row) => {
        if (row.container_id != null) containers.add(Number(row.container_id));
      });
      support.forEach((row) => {
        if (row.container_id != null) containers.add(Number(row.container_id));
      });
      summary.innerHTML = `
        <div><span>Displays resolved</span><strong>${displays.length}</strong></div>
        <div><span>Containers resolved</span><strong>${containers.size}</strong></div>
        <div><span>Support / KIT Containers</span><strong>${support.length}</strong></div>
        <div><span>Displays without Container</span><strong>${displays.filter((row) => row.container_id == null).length}</strong></div>
      `;
    }

    const resolutionTarget = document.getElementById('setup-material-resolution');
    const resolution = context?.material_resolution || {};
    if (resolutionTarget && resolution.requires_display_material) {
      const sourceCount = Number(resolution.source_display_count ?? resolution.display_count ?? 0);
      const ownedCount = Number(resolution.display_count || 0);
      const ownerState = resolution.ownership_status === 'COMPLETE'
        ? 'ownership complete'
        : 'ownership review required';
      resolutionTarget.innerHTML = `<strong>Resolved automatically from LOR</strong><br>${ownedCount} task-owned Display${ownedCount === 1 ? '' : 's'} · ${sourceCount} source Display${sourceCount === 1 ? '' : 's'} · ${escapeHtml(ownerState)}`;
    }
  }

  async function loadOwnership(taskId, { open = false } = {}) {
    const id = Number(taskId || 0);
    if (!id || appState.seasonYear == null) {
      updateControl(null);
      return;
    }
    const token = ++state.requestToken;
    state.taskId = id;
    try {
      const payload = await api(
        `api/setup/tasks/${id}/field-context?season_year=${encodeURIComponent(appState.seasonYear)}`
      );
      if (token !== state.requestToken || Number(appState.selectedTaskId) !== id) return;
      state.context = payload.context || {};
      updateControl(state.context);
      if (open) {
        renderOwnershipBoard(state.context);
        ensureDialog().showModal();
      } else if (ensureDialog().open) {
        renderOwnershipBoard(state.context);
      }
    } catch (error) {
      if (token !== state.requestToken) return;
      console.error('Setup Display ownership could not be loaded', error);
      updateControl(null);
    }
  }

  async function openOwnershipDialog() {
    const taskId = Number(appState.selectedTaskId || 0);
    if (!taskId) return;
    if (state.taskId !== taskId || !state.context) {
      await loadOwnership(taskId, { open: true });
      return;
    }
    renderOwnershipBoard(state.context);
    ensureDialog().showModal();
  }

  async function initializeOwnership() {
    const taskId = Number(appState.selectedTaskId || 0);
    if (!taskId || !appState.access?.can_manage_setup) return;
    if (!window.confirm('Initialize every currently resolved Display in this scope to the selected reusable task, then use the ownership board to move Displays to the other work packages?')) return;

    try {
      setBusy(true);
      const payload = await api(
        `api/setup/tasks/${taskId}/display-ownership/initialize`,
        commandOptions('POST', { season_year: Number(appState.seasonYear) })
      );
      state.context = payload.context || {};
      updateControl(state.context);
      updateMaterialCounts(state.context);
      renderOwnershipBoard(state.context);
      setAlert('Display ownership initialized. Move Displays to the reusable task that actually owns each work package.', 'ok');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  async function moveDisplay(displayId, targetTaskId) {
    const taskId = Number(appState.selectedTaskId || 0);
    if (!taskId || !displayId || !targetTaskId || !appState.access?.can_manage_setup) return;
    const data = ownership();
    const row = (data?.assignments || []).find((item) => Number(item.display_id) === Number(displayId));
    if (Number(row?.owner_setup_task_id || 0) === Number(targetTaskId)) return;

    try {
      setBusy(true);
      const payload = await api(
        `api/setup/tasks/${taskId}/display-ownership/${Number(displayId)}`,
        commandOptions('PATCH', {
          season_year: Number(appState.seasonYear),
          target_setup_task_id: Number(targetTaskId)
        })
      );
      state.context = payload.context || {};
      updateControl(state.context);
      updateMaterialCounts(state.context);
      renderOwnershipBoard(state.context);
      setAlert(`Display ${displayId} moved to ${taskName(targetTaskId, ownership())}.`, 'ok');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  document.addEventListener('dragstart', (event) => {
    const card = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-card[draggable="true"]');
    if (!card || !appState.access?.can_manage_setup) return;
    state.draggedDisplayId = Number(card.dataset.displayId || 0);
    card.classList.add('dragging');
    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', String(state.draggedDisplayId));
    }
  });

  document.addEventListener('dragend', (event) => {
    event.target.closest('.setup-display-owner-card')?.classList.remove('dragging');
    document.querySelectorAll('.setup-display-owner-column.drop-target').forEach((node) => node.classList.remove('drop-target'));
    state.draggedDisplayId = null;
  });

  document.addEventListener('dragover', (event) => {
    const column = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-column[data-target-task-id]');
    if (!column || !appState.access?.can_manage_setup || !state.draggedDisplayId) return;
    event.preventDefault();
    column.classList.add('drop-target');
    if (event.dataTransfer) event.dataTransfer.dropEffect = 'move';
  });

  document.addEventListener('dragleave', (event) => {
    const column = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-column[data-target-task-id]');
    if (!column) return;
    if (!column.contains(event.relatedTarget)) column.classList.remove('drop-target');
  });

  document.addEventListener('drop', (event) => {
    const column = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-column[data-target-task-id]');
    if (!column || !appState.access?.can_manage_setup) return;
    event.preventDefault();
    column.classList.remove('drop-target');
    const displayId = Number(state.draggedDisplayId || event.dataTransfer?.getData('text/plain') || 0);
    const targetTaskId = Number(column.dataset.targetTaskId || 0);
    state.draggedDisplayId = null;
    moveDisplay(displayId, targetTaskId);
  });

  if (typeof selectTask === 'function') {
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithDisplayOwnership(taskId) {
      const result = priorSelectTask(taskId);
      state.context = null;
      state.taskId = Number(taskId || 0);
      requestAnimationFrame(() => loadOwnership(taskId));
      return result;
    };
  }

  window.addEventListener('load', () => {
    ensureControl();
    ensureDialog();
    if (appState.selectedTaskId) loadOwnership(appState.selectedTaskId);
  });
})();
