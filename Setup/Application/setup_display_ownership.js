/* Issue #141 — task-specific Display ownership management layered after LOR resolution. */

(() => {
  const state = {
    requestToken: 0,
    taskId: null,
    context: null,
    draggedDisplayIds: [],
    selectedDisplayIds: new Set(),
    lastSelectedDisplayId: null,
    sortMode: 'name'
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
          <div class="eyebrow">Issue #141 · reusable task material assignment</div>
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
    if (data.mode === 'UNINITIALIZED_MULTI') {
      return data.coverage_status === 'COMPLETE'
        ? 'Implicit coverage · ready to subdivide'
        : 'Assignments not started';
    }
    if (data.coverage_status === 'COMPLETE') return 'Coverage complete';
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

  function normalizeDisplayIds(values) {
    return [...new Set((values || []).map((value) => Number(value)).filter((value) => value > 0))];
  }

  function compareDisplayRows(left, right) {
    if (state.sortMode === 'id') {
      return Number(left.display_id || 0) - Number(right.display_id || 0);
    }
    if (state.sortMode === 'container') {
      const leftContainer = left.container_id == null ? Number.MAX_SAFE_INTEGER : Number(left.container_id);
      const rightContainer = right.container_id == null ? Number.MAX_SAFE_INTEGER : Number(right.container_id);
      return leftContainer - rightContainer
        || String(left.display_name || '').localeCompare(String(right.display_name || ''), undefined, { numeric: true, sensitivity: 'base' })
        || Number(left.display_id || 0) - Number(right.display_id || 0);
    }
    return String(left.display_name || '').localeCompare(String(right.display_name || ''), undefined, { numeric: true, sensitivity: 'base' })
      || Number(left.display_id || 0) - Number(right.display_id || 0);
  }

  function pruneSelection(assignments) {
    const validIds = new Set((assignments || []).map((row) => Number(row.display_id)));
    state.selectedDisplayIds.forEach((displayId) => {
      if (!validIds.has(Number(displayId))) state.selectedDisplayIds.delete(Number(displayId));
    });
    if (state.lastSelectedDisplayId != null && !validIds.has(Number(state.lastSelectedDisplayId))) {
      state.lastSelectedDisplayId = null;
    }
  }

  function clearSelection() {
    state.selectedDisplayIds.clear();
    state.lastSelectedDisplayId = null;
    updateSelectionUi();
  }

  function updateSelectionUi() {
    const dialog = ensureDialog();
    dialog.querySelectorAll('.setup-display-owner-card').forEach((card) => {
      const displayId = Number(card.dataset.displayId || 0);
      const selected = state.selectedDisplayIds.has(displayId);
      card.classList.toggle('selected', selected);
      card.setAttribute('aria-selected', selected ? 'true' : 'false');
    });
    const count = dialog.querySelector('#setup-display-ownership-selection-count');
    if (count) {
      const selectedCount = state.selectedDisplayIds.size;
      count.textContent = selectedCount
        ? `${selectedCount} Display${selectedCount === 1 ? '' : 's'} selected`
        : 'No Displays selected';
    }
  }

  function selectDisplayCard(card, event) {
    if (!card || !appState.access?.can_manage_setup) return;
    const displayId = Number(card.dataset.displayId || 0);
    if (!displayId) return;
    const toggle = Boolean(event.ctrlKey || event.metaKey);

    if (event.shiftKey && state.lastSelectedDisplayId != null) {
      const cardsHost = card.closest('.setup-display-owner-cards');
      const cards = cardsHost
        ? [...cardsHost.querySelectorAll('.setup-display-owner-card[draggable="true"]')]
        : [];
      const anchorIndex = cards.findIndex(
        (candidate) => Number(candidate.dataset.displayId || 0) === Number(state.lastSelectedDisplayId)
      );
      const currentIndex = cards.indexOf(card);
      if (anchorIndex >= 0 && currentIndex >= 0) {
        if (!toggle) state.selectedDisplayIds.clear();
        const start = Math.min(anchorIndex, currentIndex);
        const end = Math.max(anchorIndex, currentIndex);
        cards.slice(start, end + 1).forEach((candidate) => {
          const candidateId = Number(candidate.dataset.displayId || 0);
          if (candidateId) state.selectedDisplayIds.add(candidateId);
        });
      } else {
        if (!toggle) state.selectedDisplayIds.clear();
        state.selectedDisplayIds.add(displayId);
      }
    } else if (toggle) {
      if (state.selectedDisplayIds.has(displayId)) {
        state.selectedDisplayIds.delete(displayId);
      } else {
        state.selectedDisplayIds.add(displayId);
      }
    } else {
      state.selectedDisplayIds.clear();
      state.selectedDisplayIds.add(displayId);
    }

    state.lastSelectedDisplayId = displayId;
    updateSelectionUi();
  }

  function displayCard(row, canManage) {
    const displayId = Number(row.display_id || 0);
    const selected = state.selectedDisplayIds.has(displayId);
    const stateLabel = String(row.ownership_state || '').replaceAll('_', ' ');
    const ownerText = row.owner_setup_task_id
      ? `Owner: ${row.owner_task_name || `Task ${row.owner_setup_task_id}`}`
      : 'No effective owner';
    const containerText = row.container_id == null
      ? 'No current Container'
      : `Container ${row.container_id}${row.container_description ? ` — ${row.container_description}` : ''}`;
    const effective = row.ownership_state === 'ASSIGNED' || row.ownership_state === 'IMPLICIT';
    const reviewClass = effective ? '' : ' review';
    const selectedClass = selected ? ' selected' : '';
    return `
      <div class="setup-display-owner-card${reviewClass}${selectedClass}"
           data-display-id="${row.display_id}"
           data-owner-task-id="${row.owner_setup_task_id ?? ''}"
           data-ownership-state="${escapeHtml(row.ownership_state || '')}"
           draggable="${canManage ? 'true' : 'false'}"
           ${canManage ? 'tabindex="0" role="option" title="Right-click an assigned Display to unassign it."' : ''}
           aria-selected="${selected ? 'true' : 'false'}">
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
      clearSelection();
      content.innerHTML = '<div class="empty-state">This scope does not require explicit multi-task Display ownership.</div>';
      return;
    }

    const canManage = Boolean(appState.access?.can_manage_setup);
    const assignments = Array.isArray(data.assignments) ? data.assignments : [];
    const eligibleTasks = Array.isArray(data.eligible_tasks) ? data.eligible_tasks : [];
    pruneSelection(assignments);
    const assignedByTask = new Map(
      eligibleTasks.map((task) => [Number(task.setup_task_id), []])
    );
    const reviewRows = [];

    assignments.forEach((row) => {
      const ownerId = Number(row.owner_setup_task_id || 0);
      const effective = row.ownership_state === 'ASSIGNED' || row.ownership_state === 'IMPLICIT';
      if (effective && assignedByTask.has(ownerId)) {
        assignedByTask.get(ownerId).push(row);
      } else {
        reviewRows.push(row);
      }
    });

    const columns = eligibleTasks.map((task) => {
      const taskId = Number(task.setup_task_id);
      const rows = [...(assignedByTask.get(taskId) || [])].sort(compareDisplayRows);
      const materialStatus = task.requires_display_material
        ? ' · material active'
        : ' · assignment will enable material';
      return `
        <section class="setup-display-owner-column" data-target-task-id="${taskId}">
          <div class="setup-display-owner-column-heading">
            <strong>${escapeHtml(task.task_name || `Task ${taskId}`)}</strong>
            <span>Reusable task ${taskId}${escapeHtml(materialStatus)} · ${rows.length} Display${rows.length === 1 ? '' : 's'}</span>
          </div>
          <div class="setup-display-owner-cards">
            ${rows.length ? rows.map((row) => displayCard(row, canManage)).join('') : '<div class="setup-display-owner-empty">No Displays currently owned by this task.</div>'}
          </div>
        </section>
      `;
    }).join('');

    reviewRows.sort(compareDisplayRows);
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
        <button id="setup-display-ownership-initialize" type="button">Assign all resolved Displays to this task</button>
        <span class="muted">Use the selected task as the starting owner in one step. Assignment automatically enables Display / Container Material for that task; then move Displays to the other real work packages as needed.</span>
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
          <div class="setup-display-owner-stale-row">
            <span>Display ${escapeHtml(row.display_id)} — ${escapeHtml(row.owner_task_name || `Task ${row.setup_task_id}`)}</span>
            ${canManage ? `
              <button
                type="button"
                class="secondary setup-display-stale-remove"
                data-display-id="${escapeHtml(row.display_id)}"
                data-owner-task-id="${escapeHtml(row.setup_task_id)}"
              >Remove stale ownership</button>
            ` : ''}
          </div>
        `).join('')}
      </div>
    ` : '';

    const toolbar = `
      <div class="setup-display-ownership-toolbar">
        <label>Sort Displays
          <select id="setup-display-ownership-sort">
            <option value="name"${state.sortMode === 'name' ? ' selected' : ''}>Name A–Z</option>
            <option value="id"${state.sortMode === 'id' ? ' selected' : ''}>Display ID</option>
            <option value="container"${state.sortMode === 'container' ? ' selected' : ''}>Container</option>
          </select>
        </label>
        ${canManage ? `
          <strong id="setup-display-ownership-selection-count">${state.selectedDisplayIds.size ? `${state.selectedDisplayIds.size} Display${state.selectedDisplayIds.size === 1 ? '' : 's'} selected` : 'No Displays selected'}</strong>
          <span class="muted">Click selects one. Ctrl/Cmd-click toggles. Shift-click selects a range within a task column. Drag any selected Display to move the whole selection.</span>
        ` : ''}
      </div>
    `;

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
      ${toolbar}
      <div class="muted" style="margin-bottom:10px;">
        LOR defines the current Display source set. Setup assignment changes only which reusable task owns each Display. It never changes LOR membership or the Display's current Container.
      </div>
      <div class="setup-display-ownership-board">
        ${columns}
        ${reviewColumn}
      </div>
      ${stale}
    `;

    content.querySelector('#setup-display-ownership-initialize')?.addEventListener('click', initializeOwnership);
    content.querySelector('#setup-display-ownership-sort')?.addEventListener('change', (event) => {
      state.sortMode = String(event.target.value || 'name');
      renderOwnershipBoard(state.context);
    });
    content.querySelectorAll('.setup-display-stale-remove').forEach((button) => {
      button.addEventListener('click', () => {
        clearOwnership(
          Number(button.dataset.displayId || 0),
          Number(button.dataset.ownerTaskId || 0),
          { stale: true }
        );
      });
    });
    updateSelectionUi();
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
        <div><span>Explicit Support / Kit Containers</span><strong>${support.length}</strong></div>
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

  async function refreshMaterialFlags() {
    if (typeof loadSetupMaterialFlags === 'function') {
      await loadSetupMaterialFlags({ rerender: false });
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
    if (!window.confirm('Assign every currently resolved Display in this scope to the selected reusable task as the starting owner? You can then move Displays to the other work packages.')) return;

    try {
      setBusy(true);
      const payload = await api(
        `api/setup/tasks/${taskId}/display-ownership/initialize`,
        commandOptions('POST', { season_year: Number(appState.seasonYear) })
      );
      state.context = payload.context || {};
      await refreshMaterialFlags();
      clearSelection();
      updateControl(state.context);
      updateMaterialCounts(state.context);
      renderOwnershipBoard(state.context);
      setAlert('Display ownership initialized. The target task was made material-bearing automatically. Move Displays to the reusable task that actually owns each work package.', 'ok');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  async function clearOwnership(displayId, expectedTaskId, { stale = false } = {}) {
    const taskId = Number(appState.selectedTaskId || 0);
    if (!taskId || !displayId || !expectedTaskId || !appState.access?.can_manage_setup) return;
    const action = stale ? 'Remove the stale Setup ownership row' : 'Unassign this Display from its current Setup task';
    const consequence = stale
      ? 'This does not change LOR membership, Display status, or Container assignment.'
      : 'The Display will remain in the current LOR source set and will be shown as Missing owner until you assign it again.';
    if (!window.confirm(`${action} for Display ${displayId}?\n\n${consequence}`)) return;

    try {
      setBusy(true);
      const payload = await api(
        `api/setup/tasks/${taskId}/display-ownership/${Number(displayId)}`,
        commandOptions('DELETE', {
          season_year: Number(appState.seasonYear),
          expected_setup_task_id: Number(expectedTaskId)
        })
      );
      state.context = payload.context || {};
      await refreshMaterialFlags();
      clearSelection();
      updateControl(state.context);
      updateMaterialCounts(state.context);
      renderOwnershipBoard(state.context);
      setAlert(stale ? `Stale Display ${displayId} ownership removed.` : `Display ${displayId} unassigned.`, 'ok');
    } catch (error) {
      await loadOwnership(taskId);
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  async function moveDisplays(displayIds, targetTaskId) {
    const taskId = Number(appState.selectedTaskId || 0);
    const ids = normalizeDisplayIds(displayIds);
    if (!taskId || !ids.length || !targetTaskId || !appState.access?.can_manage_setup) return;

    const data = ownership();
    const assignments = Array.isArray(data?.assignments) ? data.assignments : [];
    const movableIds = ids.filter((displayId) => {
      const row = assignments.find((item) => Number(item.display_id) === Number(displayId));
      return row && Number(row.owner_setup_task_id || 0) !== Number(targetTaskId);
    });
    if (!movableIds.length) return;

    let movedCount = 0;
    try {
      setBusy(true);
      let latestContext = state.context;
      for (const displayId of movableIds) {
        const payload = await api(
          `api/setup/tasks/${taskId}/display-ownership/${Number(displayId)}`,
          commandOptions('PATCH', {
            season_year: Number(appState.seasonYear),
            target_setup_task_id: Number(targetTaskId)
          })
        );
        latestContext = payload.context || latestContext;
        movedCount += 1;
      }
      state.context = latestContext;
      await refreshMaterialFlags();
      clearSelection();
      updateControl(state.context);
      updateMaterialCounts(state.context);
      renderOwnershipBoard(state.context);
      setAlert(
        `${movedCount} Display${movedCount === 1 ? '' : 's'} moved to ${taskName(targetTaskId, ownership())}. Display / Container Material was enabled automatically if needed.`,
        'ok'
      );
    } catch (error) {
      clearSelection();
      await loadOwnership(taskId);
      const prefix = movedCount
        ? `${movedCount} of ${movableIds.length} Displays moved before the operation stopped. `
        : '';
      setAlert(`${prefix}${error.message || error}`, 'error');
      window.alert(`${prefix}${error.message || error}`);
    } finally {
      setBusy(false);
    }
  }

  function moveDisplay(displayId, targetTaskId) {
    return moveDisplays([displayId], targetTaskId);
  }

  document.addEventListener('contextmenu', (event) => {
    const card = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-card');
    if (!card || !appState.access?.can_manage_setup) return;
    if (String(card.dataset.ownershipState || '') !== 'ASSIGNED') return;
    const displayId = Number(card.dataset.displayId || 0);
    const ownerTaskId = Number(card.dataset.ownerTaskId || 0);
    if (!displayId || !ownerTaskId) return;
    event.preventDefault();
    clearOwnership(displayId, ownerTaskId);
  });

  document.addEventListener('click', (event) => {
    const card = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-card[draggable="true"]');
    if (!card || !appState.access?.can_manage_setup) return;
    selectDisplayCard(card, event);
  });

  document.addEventListener('keydown', (event) => {
    if (event.key !== ' ' && event.key !== 'Enter') return;
    const card = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-card[draggable="true"]');
    if (!card || !appState.access?.can_manage_setup) return;
    event.preventDefault();
    selectDisplayCard(card, event);
  });

  document.addEventListener('dragstart', (event) => {
    const card = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-card[draggable="true"]');
    if (!card || !appState.access?.can_manage_setup) return;
    const displayId = Number(card.dataset.displayId || 0);
    if (!state.selectedDisplayIds.has(displayId)) {
      state.selectedDisplayIds.clear();
      state.selectedDisplayIds.add(displayId);
      state.lastSelectedDisplayId = displayId;
      updateSelectionUi();
    }
    state.draggedDisplayIds = normalizeDisplayIds([...state.selectedDisplayIds]);
    document.querySelectorAll('#setup-display-ownership-dialog .setup-display-owner-card.selected').forEach((node) => {
      node.classList.add('dragging');
    });
    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', state.draggedDisplayIds.join(','));
    }
  });

  document.addEventListener('dragend', () => {
    document.querySelectorAll('#setup-display-ownership-dialog .setup-display-owner-card.dragging').forEach((node) => {
      node.classList.remove('dragging');
    });
    document.querySelectorAll('.setup-display-owner-column.drop-target').forEach((node) => node.classList.remove('drop-target'));
    state.draggedDisplayIds = [];
  });

  document.addEventListener('dragover', (event) => {
    const column = event.target.closest('#setup-display-ownership-dialog .setup-display-owner-column[data-target-task-id]');
    if (!column || !appState.access?.can_manage_setup || !state.draggedDisplayIds.length) return;
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
    const transferIds = String(event.dataTransfer?.getData('text/plain') || '')
      .split(',')
      .map((value) => Number(value));
    const displayIds = state.draggedDisplayIds.length
      ? [...state.draggedDisplayIds]
      : normalizeDisplayIds(transferIds);
    const targetTaskId = Number(column.dataset.targetTaskId || 0);
    state.draggedDisplayIds = [];
    moveDisplays(displayIds, targetTaskId);
  });

  if (typeof selectTask === 'function') {
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithDisplayOwnership(taskId) {
      const result = priorSelectTask(taskId);
      state.context = null;
      state.taskId = Number(taskId || 0);
      state.draggedDisplayIds = [];
      state.selectedDisplayIds.clear();
      state.lastSelectedDisplayId = null;
      const openFromAudit = typeof consumePendingCorrection === 'function'
        && consumePendingCorrection('display-ownership');
      requestAnimationFrame(() => loadOwnership(taskId, { open: openFromAudit }));
      return result;
    };
  }

  window.addEventListener('load', () => {
    ensureControl();
    ensureDialog();
    if (appState.selectedTaskId) {
      const openFromAudit = typeof consumePendingCorrection === 'function'
        && consumePendingCorrection('display-ownership');
      loadOwnership(appState.selectedTaskId, { open: openFromAudit });
    }
  });
})();