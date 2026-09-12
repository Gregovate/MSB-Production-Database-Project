/* Issue #141 — explicit reusable Setup task -> physical Kit Box assignments. */

(() => {
  const state = {
    taskId: null,
    kitBoxes: [],
    requestToken: 0
  };

  function ensureControl() {
    const summary = document.getElementById('setup-material-context-summary');
    if (!summary) return null;

    let control = document.getElementById('setup-kit-box-control');
    if (!control) {
      control = document.createElement('div');
      control.id = 'setup-kit-box-control';
      control.className = 'setup-kit-box-control manager-only';
      control.hidden = true;
      control.innerHTML = `
        <button id="setup-kit-box-open" type="button" class="secondary">Kit Boxes</button>
        <span id="setup-kit-box-status" class="setup-kit-box-status"></span>
      `;
      const ownershipControl = document.getElementById('setup-display-ownership-control');
      if (ownershipControl) ownershipControl.insertAdjacentElement('afterend', control);
      else summary.insertAdjacentElement('afterend', control);
      control.querySelector('#setup-kit-box-open')?.addEventListener('click', openDialog);
    }
    control.hidden = !Boolean(appState.access?.can_manage_setup && appState.selectedTaskId);
    return control;
  }

  function ensureDialog() {
    let dialog = document.getElementById('setup-kit-box-dialog');
    if (dialog) return dialog;

    dialog = document.createElement('dialog');
    dialog.id = 'setup-kit-box-dialog';
    dialog.className = 'setup-kit-box-dialog';
    dialog.innerHTML = `
      <div class="setup-kit-box-heading">
        <div>
          <div class="eyebrow">Issue #141 · reusable physical assignment</div>
          <h3 id="setup-kit-box-title">Kit Boxes</h3>
        </div>
        <button id="setup-kit-box-close" type="button" class="secondary">Close</button>
      </div>
      <div class="muted setup-kit-box-rule">
        Only physical Containers whose Production type is <strong>Kit Box</strong> are listed here.
        Kit Boxes are outside LOR and may be assigned to more than one reusable Setup task.
      </div>
      <div id="setup-kit-box-content" class="setup-kit-box-content"></div>
    `;
    document.body.appendChild(dialog);
    dialog.querySelector('#setup-kit-box-close')?.addEventListener('click', () => dialog.close());
    dialog.addEventListener('click', (event) => {
      if (event.target === dialog) dialog.close();
    });
    return dialog;
  }

  function updateStatus() {
    const control = ensureControl();
    if (!control || control.hidden) return;
    const assigned = state.kitBoxes.filter((row) => Boolean(row.assigned)).length;
    const status = control.querySelector('#setup-kit-box-status');
    if (status) status.textContent = `${assigned} assigned`;
  }

  function renderDialog() {
    const dialog = ensureDialog();
    const content = dialog.querySelector('#setup-kit-box-content');
    const title = dialog.querySelector('#setup-kit-box-title');
    const task = typeof taskById === 'function' ? taskById(appState.selectedTaskId) : null;
    if (title) title.textContent = `${task?.task_name || 'Reusable Task'} — Kit Boxes`;
    if (!content) return;

    if (!state.kitBoxes.length) {
      content.innerHTML = '<div class="empty-state">No Production Kit Box containers were found.</div>';
      return;
    }

    content.innerHTML = state.kitBoxes.map((row) => {
      const shared = Number(row.other_task_count || 0);
      const sharedText = shared
        ? `<div class="setup-kit-box-shared"><strong>Shared:</strong> ${escapeHtml(row.other_task_assignments || `${shared} other task${shared === 1 ? '' : 's'}`)}</div>`
        : '<div class="muted">Not assigned to another reusable task.</div>';
      const location = row.home_location_code
        ? `Home ${row.home_location_code}`
        : 'Home location not recorded';
      return `
        <label class="setup-kit-box-row${row.assigned ? ' assigned' : ''}" data-container-id="${row.container_id}">
          <input class="setup-kit-box-toggle" type="checkbox" ${row.assigned ? 'checked' : ''}>
          <span class="setup-kit-box-copy">
            <strong>Container ${escapeHtml(row.container_id)} — ${escapeHtml(row.container_description || 'Kit Box')}</strong>
            <span>${escapeHtml(location)} · Kit Box</span>
            ${sharedText}
          </span>
        </label>
      `;
    }).join('');

    content.querySelectorAll('.setup-kit-box-toggle').forEach((checkbox) => {
      checkbox.addEventListener('change', async (event) => {
        const row = event.target.closest('.setup-kit-box-row');
        const containerId = Number(row?.dataset.containerId || 0);
        if (!containerId) return;
        await setAssignment(containerId, Boolean(event.target.checked), event.target);
      });
    });
  }

  async function loadKitBoxes(taskId = appState.selectedTaskId, { render = false } = {}) {
    const id = Number(taskId || 0);
    if (!id || !appState.access?.can_manage_setup) {
      state.taskId = id || null;
      state.kitBoxes = [];
      updateStatus();
      return;
    }

    const token = ++state.requestToken;
    try {
      const payload = await api(`api/setup/tasks/${id}/kit-boxes`);
      if (token !== state.requestToken || Number(appState.selectedTaskId) !== id) return;
      state.taskId = id;
      state.kitBoxes = Array.isArray(payload.kit_boxes) ? payload.kit_boxes : [];
      updateStatus();
      if (render || ensureDialog().open) renderDialog();
    } catch (error) {
      if (token !== state.requestToken) return;
      console.error('Setup Kit Box assignments could not be loaded', error);
      state.kitBoxes = [];
      updateStatus();
    }
  }

  async function setAssignment(containerId, assigned, checkbox) {
    const taskId = Number(appState.selectedTaskId || 0);
    if (!taskId || !appState.access?.can_manage_setup) return;
    try {
      setBusy(true);
      const payload = await api(
        `api/setup/tasks/${taskId}/kit-boxes/${Number(containerId)}`,
        commandOptions('PATCH', {
          assigned: Boolean(assigned),
          notes: 'Reusable Setup Kit Box assignment.'
        })
      );
      state.kitBoxes = Array.isArray(payload.kit_boxes) ? payload.kit_boxes : [];
      updateStatus();
      renderDialog();
      if (typeof loadSelectedSetupMaterialContext === 'function') {
        await loadSelectedSetupMaterialContext();
      }
      setAlert(
        assigned
          ? `Kit Box ${containerId} assigned to this reusable task.`
          : `Kit Box ${containerId} removed from this reusable task.`,
        'ok'
      );
    } catch (error) {
      if (checkbox) checkbox.checked = !assigned;
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  async function openDialog() {
    const taskId = Number(appState.selectedTaskId || 0);
    if (!taskId || !appState.access?.can_manage_setup) return;
    await loadKitBoxes(taskId, { render: true });
    ensureDialog().showModal();
  }

  if (typeof selectTask === 'function') {
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithKitBoxes(taskId) {
      const result = priorSelectTask(taskId);
      state.taskId = Number(taskId || 0);
      state.kitBoxes = [];
      requestAnimationFrame(() => {
        ensureControl();
        loadKitBoxes(taskId).catch((error) => console.error(error));
      });
      return result;
    };
  }

  window.addEventListener('load', () => {
    ensureControl();
    ensureDialog();
    if (appState.selectedTaskId) loadKitBoxes(appState.selectedTaskId);
  });
})();
