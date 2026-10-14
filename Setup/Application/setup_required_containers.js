/* #122 DBG-2026-013: require a physical Container without inventing its contents. */
(() => {
  'use strict';
  let currentTask = null;
  let rows = [];
  let busy = false;
  let token = 0;
  const el = id => document.getElementById(id);

  function install() {
    if (el('required-container-section')) return;
    const anchor = el('task-extra-material-section');
    if (!anchor) return;
    const section = document.createElement('section');
    section.id = 'required-container-section';
    section.className = 'detail-section manager-only';
    section.innerHTML = `<h3>Required Containers</h3>
      <p class="hint">Bring an existing Container for this task. No material item or contents entry is needed. Scheduled tasks feed the Pick List; unscheduled annual tasks appear in Material Status for Manager selection.</p>
      <button id="required-container-open" type="button" class="secondary">Add / Remove Container</button>
      <div id="required-container-summary" class="muted"></div>`;
    anchor.insertAdjacentElement('beforebegin', section);
    section.hidden = !appState.access?.can_manage_setup;
    const dialog = document.createElement('dialog');
    dialog.id = 'required-container-dialog';
    dialog.className = 'setup-kit-box-dialog';
    dialog.innerHTML = `<h3>Required Containers</h3>
      <p>Search by Container number or name. Check to require it; changes save immediately.</p>
      <input id="required-container-search" type="search" placeholder="C106, 106, or Who Ville" aria-label="Find Container">
      <div id="required-container-message" role="status"></div>
      <div id="required-container-rows" class="setup-kit-box-content"></div>
      <button id="required-container-close" type="button" class="secondary">Close</button>`;
    document.body.appendChild(dialog);
    el('required-container-close').addEventListener('click', () => dialog.close());
    el('required-container-search').addEventListener('input', render);
    el('required-container-open').addEventListener('click', async () => {
      el('required-container-search').value = '';
      dialog.showModal();
      await load(appState.selectedTaskId);
      el('required-container-search').focus();
    });
    dialog.addEventListener('change', event => {
      const checkbox = event.target.closest('[data-required-container]');
      if (checkbox) void save(Number(checkbox.dataset.requiredContainer), checkbox.checked);
    });
  }

  function render() {
    if (!el('required-container-section')) return;
    el('required-container-section').hidden = !appState.access?.can_manage_setup;
    el('required-container-summary').textContent = rows.filter(row => row.assigned)
      .map(row => `C${row.container_id} — ${row.container_description || 'Container'}`).join('; ') || 'No direct Container requirements.';
    const query = el('required-container-search').value.trim().toLowerCase();
    el('required-container-rows').innerHTML = rows.filter(row =>
      `c${row.container_id} cont:${row.container_id} ${row.container_description || ''} ${row.home_location_code || ''}`.toLowerCase().includes(query)
    ).map(row => {
      // Other relationships already mobilize this Container; never relabel or delete them here.
      const other = row.relationship_type && row.relationship_type !== 'REQUIRED_CONTAINER';
      return `<label class="setup-kit-box-row"><input type="checkbox" data-required-container="${row.container_id}"
        ${row.assigned || other ? 'checked' : ''} ${busy || other ? 'disabled' : ''}>
        <span>C${row.container_id} — ${escapeHtml(row.container_description || 'Container')}
        <span class="muted">${escapeHtml(row.home_location_code || '')}${other ? ` · Already linked: ${escapeHtml(row.relationship_type)}` : ''}</span></span></label>`;
    }).join('') || '<p>No matching Containers.</p>';
  }

  async function load(taskId) {
    install();
    if (!el('required-container-section')) return;
    currentTask = Number(taskId || 0);
    const request = ++token;
    rows = [];
    render();
    if (!currentTask || !appState.access?.can_manage_setup) return;
    el('required-container-message').textContent = 'Loading Containers…';
    try {
      const payload = await api(`api/setup/tasks/${currentTask}/required-containers`);
      if (request !== token) return;
      rows = payload.containers || [];
      el('required-container-message').textContent = '';
      render();
    } catch (error) {
      if (request !== token) return;
      el('required-container-message').textContent = error.message;
      el('required-container-summary').textContent = `Could not load required Containers: ${error.message}`;
    }
  }

  async function save(containerId, assigned) {
    const taskId = currentTask;
    if (busy || !taskId || !appState.access?.can_manage_setup) return;
    busy = true;
    render();
    try {
      const result = await api(`api/setup/tasks/${taskId}/required-containers/${containerId}`,
        commandOptions('PATCH', {assigned}));
      if (taskId !== currentTask) return;
      rows = result.containers || [];
      el('required-container-message').textContent = `C${containerId} ${assigned ? 'required and saved' : 'requirement removed'}.`;
      if (typeof loadSelectedSetupMaterialContext === 'function') await loadSelectedSetupMaterialContext();
    } catch (error) {
      if (taskId === currentTask) el('required-container-message').textContent = error.message;
    } finally {
      busy = false;
      render();
    }
  }

  const priorSelectTask = selectTask;
  selectTask = function selectTaskWithRequiredContainers(taskId) {
    const result = priorSelectTask(taskId);
    void load(taskId);
    return result;
  };
  window.addEventListener('load', () => { install(); if (appState.selectedTaskId) void load(appState.selectedTaskId); });
})();
