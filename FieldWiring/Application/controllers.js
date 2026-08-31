const searchInput = document.getElementById('controller-search');
const stageFilter = document.getElementById('stage-filter');
const statusFilter = document.getElementById('status-filter');
const modelFilter = document.getElementById('model-filter');
const assignmentFilter = document.getElementById('assignment-filter');
const controllerList = document.getElementById('controller-list');
const controllerCount = document.getElementById('controller-count');
const detail = document.getElementById('detail');
const detailEmpty = document.getElementById('detail-empty');
const themeToggle = document.getElementById('theme-toggle');

let selectedControllerId = null;
let filtersLoaded = false;
let debounceTimer = null;

function esc(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function displayValue(value, fallback = '—') {
  if (value === null || value === undefined || value === '') return fallback;
  return value;
}

function formatDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString();
}

function configureTheme() {
  const saved = localStorage.getItem('msb-theme');
  if (saved === 'light' || saved === 'dark') {
    document.documentElement.dataset.theme = saved;
  }
  syncThemeButton();
}

function currentTheme() {
  if (document.documentElement.dataset.theme) return document.documentElement.dataset.theme;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function syncThemeButton() {
  themeToggle.textContent = currentTheme() === 'dark' ? 'Light mode' : 'Dark mode';
}

themeToggle.addEventListener('click', () => {
  const next = currentTheme() === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  localStorage.setItem('msb-theme', next);
  syncThemeButton();
});

function queryString() {
  const params = new URLSearchParams();
  if (searchInput.value.trim()) params.set('q', searchInput.value.trim());
  if (stageFilter.value) params.set('stage_id', stageFilter.value);
  if (statusFilter.value) params.set('status', statusFilter.value);
  if (modelFilter.value) params.set('model', modelFilter.value);
  if (assignmentFilter.value) params.set('assignment', assignmentFilter.value);
  return params.toString();
}

function populateFilters(payload) {
  if (filtersLoaded) return;

  for (const stage of payload.stages || []) {
    const option = document.createElement('option');
    option.value = stage.stage_id;
    option.textContent = `${stage.stage_key} · ${stage.stage_name}`;
    stageFilter.appendChild(option);
  }

  for (const status of payload.statuses || []) {
    const option = document.createElement('option');
    option.value = status;
    option.textContent = status;
    statusFilter.appendChild(option);
  }

  for (const model of payload.models || []) {
    const option = document.createElement('option');
    option.value = model.model_code;
    option.textContent = `${model.model_code} — ${model.model_name}`;
    modelFilter.appendChild(option);
  }

  filtersLoaded = true;
}

function renderSummary(summary) {
  document.getElementById('sum-total').textContent = summary.total ?? '—';
  document.getElementById('sum-assigned').textContent = summary.assigned ?? '—';
  document.getElementById('sum-unassigned').textContent = summary.unassigned ?? '—';
  document.getElementById('sum-firmware').textContent = summary.firmware_pending ?? '—';
}

function renderControllerList(controllers) {
  controllerCount.textContent = `${controllers.length} shown`;
  if (!controllers.length) {
    controllerList.innerHTML = '<div class="empty-state">No controllers match these filters.</div>';
    return;
  }

  controllerList.innerHTML = controllers.map(item => {
    const active = item.controller_id === selectedControllerId ? ' active' : '';
    const assignmentText = Number(item.assignment_count) === 0
      ? 'Unassigned'
      : item.display_names;
    const stageText = item.stage_names || 'No Stage';
    const firmware = item.installed_firmware
      ? `${item.installed_firmware} · ${item.firmware_verification_state}`
      : item.firmware_verification_state;
    return `
      <div class="controller-row${active}" data-controller-id="${item.controller_id}">
        <div class="controller-row-top">
          <div class="controller-id">CTRL ${item.controller_id}</div>
          <span class="pill ${esc(item.controller_status_name)}">${esc(item.controller_status_name)}</span>
        </div>
        <div class="controller-model">${esc(item.model_code)}</div>
        <div class="controller-stage">${esc(stageText)}</div>
        <div class="controller-meta">${esc(assignmentText)}</div>
        <div class="controller-meta">Firmware: ${esc(firmware)}</div>
      </div>`;
  }).join('');

  for (const row of controllerList.querySelectorAll('.controller-row')) {
    row.addEventListener('click', () => loadControllerDetail(Number(row.dataset.controllerId)));
  }
}

async function loadControllers() {
  controllerList.innerHTML = '<div class="empty-state">Loading controllers…</div>';
  try {
    const response = await fetch(`api/controllers?${queryString()}`);
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || 'Controller Inventory could not be loaded.');
    populateFilters(payload);
    renderSummary(payload.summary || {});
    renderControllerList(payload.controllers || []);
  } catch (error) {
    controllerList.innerHTML = `<div class="error">${esc(error.message)}</div>`;
  }
}

function fact(label, value) {
  return `<div class="fact"><span>${esc(label)}</span><strong>${esc(displayValue(value))}</strong></div>`;
}

function renderAssignments(assignments) {
  const target = document.getElementById('assignments');
  document.getElementById('assignment-count').textContent = `${assignments.length} Display${assignments.length === 1 ? '' : 's'}`;

  if (!assignments.length) {
    target.innerHTML = '<div class="no-wiring">No current Display assignment. The controller remains a permanent inventory asset.</div>';
    return;
  }

  target.innerHTML = assignments.map(item => {
    const stage = item.stage_key
      ? `${item.stage_key} · ${item.stage_name || ''}`
      : 'No Stage';
    const source = item.wiring_source_display_id
      ? `${item.wiring_source_display} (Display ${item.wiring_source_display_id})`
      : 'This Display';
    const action = item.has_current_wiring
      ? `<a class="wiring-link" href="wiring?display_id=${item.wiring_display_id}">Open Field Wiring</a>`
      : '<span class="no-wiring">No current LOR wiring</span>';
    return `
      <div class="assignment">
        <div>
          <div class="assignment-name">${esc(item.display_name)}</div>
          <div class="assignment-meta">Display ${item.display_id} · ${esc(stage)}</div>
        </div>
        <div class="assignment-source">
          <span>Wiring source</span>
          ${esc(source)}
        </div>
        <div>${action}</div>
      </div>`;
  }).join('');
}

function renderFirmwareHistory(rows) {
  const target = document.getElementById('firmware-history');
  if (!rows.length) {
    target.innerHTML = '<div class="no-wiring">No recorded firmware history.</div>';
    return;
  }
  target.innerHTML = rows.map(row => `
    <div class="firmware-row">
      <strong>${esc(row.firmware_version)}</strong>
      <div>${esc(row.verification_state)}</div>
      <div>${esc(formatDate(row.firmware_recorded_at))}</div>
      <div>${esc(row.source_note || row.notes || '')}</div>
    </div>`).join('');
}

async function loadControllerDetail(controllerId) {
  selectedControllerId = controllerId;
  for (const row of controllerList.querySelectorAll('.controller-row')) {
    row.classList.toggle('active', Number(row.dataset.controllerId) === controllerId);
  }
  detail.hidden = false;
  detailEmpty.hidden = true;
  document.getElementById('detail-id').textContent = `CTRL ${controllerId}`;
  document.getElementById('detail-model').textContent = 'Loading…';
  document.getElementById('detail-facts').innerHTML = '';
  document.getElementById('assignments').innerHTML = '';
  document.getElementById('firmware-history').innerHTML = '';

  try {
    const response = await fetch(`api/controllers/${controllerId}`);
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || 'Controller could not be loaded.');
    const c = payload.controller;
    document.getElementById('detail-id').textContent = `CTRL ${c.controller_id}`;
    document.getElementById('detail-model').textContent = `${c.manufacturer} · ${c.model_code} · ${c.model_name}`;
    const status = document.getElementById('detail-status');
    status.textContent = c.controller_status_name;
    status.className = `pill ${c.controller_status_name}`;

    document.getElementById('detail-facts').innerHTML = [
      fact('Model', c.model_code),
      fact('Device Family', c.device_family),
      fact('Hardware Revision', c.hardware_revision),
      fact('Serial Number', c.serial_number),
      fact('Year Deployed', c.year_deployed),
      fact('Current Location', c.current_location_code),
      fact('Installed Firmware', c.installed_firmware),
      fact('Firmware State', c.firmware_verification_state),
      fact('Physical Verification', c.verification_state),
      fact('Display Attached', c.is_display_attached === null ? 'Unknown' : (c.is_display_attached ? 'Yes' : 'No')),
      fact('Label Required', c.label_required ? 'Yes' : 'No'),
      fact('Last Updated', formatDate(c.updated_at)),
    ].join('');

    renderAssignments(payload.assignments || []);
    renderFirmwareHistory(payload.firmware_history || []);
  } catch (error) {
    document.getElementById('detail-model').textContent = error.message;
  }
}

function clearFilters() {
  searchInput.value = '';
  stageFilter.value = '';
  statusFilter.value = '';
  modelFilter.value = '';
  assignmentFilter.value = '';
  loadControllers();
}

function scheduleRefresh() {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(loadControllers, 220);
}

searchInput.addEventListener('input', scheduleRefresh);
stageFilter.addEventListener('change', loadControllers);
statusFilter.addEventListener('change', loadControllers);
modelFilter.addEventListener('change', loadControllers);
assignmentFilter.addEventListener('change', loadControllers);
document.getElementById('refresh-button').addEventListener('click', loadControllers);
document.getElementById('clear-filters-button').addEventListener('click', clearFilters);

configureTheme();
loadControllers();
