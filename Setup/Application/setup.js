const STORAGE_KEY = 'msb.setup.prototype.2025.v1';

const initialTasks = [
  {
    id: 'MI-FRAME', stageKey: '26', stageName: 'Magic Igloo', order: 10,
    name: 'Layout / Erect Frame / Strap Down', verification: 'UNVERIFIED',
    crew: '8–10 (provisional)', duration: 'About 4 hours (provisional)', captain: 'To verify',
    equipment: 'SkyTrak; 1 boom lift (provisional)',
    completion: 'Magic Igloo structure is laid out, erected, secured, and ready for skins.',
    notes: 'Reusable definition reconstructed from field knowledge; verify wording, crew, equipment, and exact completion point.',
    dependencies: [], material: 'Physical material relationship still to be reviewed against current Production Database.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'MI-SKINS', stageKey: '26', stageName: 'Magic Igloo', order: 20,
    name: 'Install Skins and Bungees', verification: 'UNVERIFIED',
    crew: '4–6 (provisional)', duration: 'About 6 hours (provisional)', captain: 'To verify',
    equipment: '1 boom lift (provisional)',
    completion: 'Skins and required bungees are installed and the enclosure is ready for finish work.',
    notes: 'Warm weather preferred because skins are easier to handle. Verify whether bungees remain in this same practical task.',
    dependencies: ['MI-FRAME'], material: 'Magic Igloo skin/KIT relationships to be resolved from current Production Database and reviewed supplemental KIT relationships.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'MI-FINISH', stageKey: '26', stageName: 'Magic Igloo', order: 30,
    name: 'Install Lighting, Cameras, Mats, Signs, and Finish Setup', verification: 'UNVERIFIED',
    crew: '2–3 (provisional)', duration: 'To verify', captain: 'To verify',
    equipment: '1 boom lift (provisional)',
    completion: 'Lighting, security cameras, mats, signs, and other reviewed finish items are installed and the area is operationally ready.',
    notes: 'May need to split if lighting/cameras and mats/signs prove independently schedulable.',
    dependencies: ['MI-SKINS'], material: 'Required Displays/KITs to be resolved and reviewed.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },

  ...[
    ['RA-UNLOAD', '25', 'Racing Arches', 48],
    ['PB-UNLOAD', '21', 'Polar Bear Playground', 3],
    ['IT-UNLOAD', '14', 'Icicle Tunnel', 36],
    ['ST-UNLOAD', '10', 'Stars', 24],
    ['CL-UNLOAD', '17', 'Candyland', 2],
    ['FC-UNLOAD', '04', 'Food Collection', 8]
  ].map(([id, stageKey, stageName, count], index) => ({
    id, stageKey, stageName, order: 10,
    name: `Unload ${stageName}`,
    verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: `${count} expected ${stageName} Display${count === 1 ? '' : 's'} are unloaded at ${stageName}; all other Display groups remain with Container 34.`,
    notes: 'Reusable movement task. Operator should choose/execute this practical task without scanning every Display individually.',
    dependencies: [],
    material: `Container 34 — Arch Trailer; ${count} expected Displays in this unload group.`,
    unload: { containerId: 34, count, destination: stageName, groupIndex: index },
    actual: { dates: '', crew: '', duration: '', notes: '' }
  }))
];

const initialGroups = [
  { taskId: 'RA-UNLOAD', stageKey: '25', name: 'Racing Arches', count: 48, status: 'ONBOARD', location: null },
  { taskId: 'PB-UNLOAD', stageKey: '21', name: 'Polar Bear Playground', count: 3, status: 'ONBOARD', location: null },
  { taskId: 'IT-UNLOAD', stageKey: '14', name: 'Icicle Tunnel', count: 36, status: 'ONBOARD', location: null },
  { taskId: 'ST-UNLOAD', stageKey: '10', name: 'Stars', count: 24, status: 'ONBOARD', location: null },
  { taskId: 'CL-UNLOAD', stageKey: '17', name: 'Candyland', count: 2, status: 'ONBOARD', location: null },
  { taskId: 'FC-UNLOAD', stageKey: '04', name: 'Food Collection', count: 8, status: 'ONBOARD', location: null }
];

function defaultState() {
  return {
    tasks: structuredClone(initialTasks),
    movement: {
      containerId: 34,
      location: 'Workshop / storage (prototype start)',
      groups: structuredClone(initialGroups),
      events: []
    }
  };
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaultState();
    const parsed = JSON.parse(raw);
    if (!parsed?.tasks || !parsed?.movement?.groups) return defaultState();
    return parsed;
  } catch (_error) {
    return defaultState();
  }
}

let state = loadState();
let selectedTaskId = null;

const el = (id) => document.getElementById(id);

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function taskById(id) {
  return state.tasks.find((task) => task.id === id);
}

function dependencyNames(task) {
  return (task.dependencies || []).map((id) => taskById(id)?.name || id);
}

function verificationClass(status) {
  if (status === 'VERIFIED') return 'verified';
  if (status === 'NEEDS_CORRECTION') return 'correction';
  return 'unverified';
}

function verificationLabel(status) {
  if (status === 'VERIFIED') return 'VERIFIED';
  if (status === 'NEEDS_CORRECTION') return 'NEEDS CORRECTION';
  return 'UNVERIFIED';
}

function sortedTasks(tasks = state.tasks) {
  return [...tasks].sort((a, b) => {
    const stageCompare = String(a.stageKey).localeCompare(String(b.stageKey), undefined, { numeric: true });
    if (stageCompare !== 0) return stageCompare;
    if (a.order !== b.order) return a.order - b.order;
    return a.name.localeCompare(b.name);
  });
}

function renderSummary() {
  const counts = state.tasks.reduce((acc, task) => {
    acc[task.verification] = (acc[task.verification] || 0) + 1;
    return acc;
  }, {});
  el('summary-grid').innerHTML = `
    <div class="summary-card"><span>Provisional tasks</span><strong>${state.tasks.length}</strong></div>
    <div class="summary-card"><span>Unverified</span><strong>${counts.UNVERIFIED || 0}</strong></div>
    <div class="summary-card"><span>Needs correction</span><strong>${counts.NEEDS_CORRECTION || 0}</strong></div>
    <div class="summary-card"><span>Verified</span><strong>${counts.VERIFIED || 0}</strong></div>
  `;
}

function renderReviewList() {
  const filter = el('review-status-filter').value;
  const tasks = sortedTasks().filter((task) => !filter || task.verification === filter);
  el('review-list').innerHTML = tasks.map((task) => {
    const deps = dependencyNames(task);
    return `
      <article class="task-row ${selectedTaskId === task.id ? 'selected' : ''}" data-task-id="${task.id}">
        <div class="task-row-top">
          <div>
            <div class="eyebrow">Stage ${task.stageKey} — ${task.stageName}</div>
            <h3>${escapeHtml(task.name)}</h3>
          </div>
          <span class="pill ${verificationClass(task.verification)}">${verificationLabel(task.verification)}</span>
        </div>
        <div class="task-meta">Crew: ${escapeHtml(task.crew)} · Time: ${escapeHtml(task.duration)}</div>
        <div class="task-dependency">${deps.length ? `Requires: ${deps.map(escapeHtml).join('; ')}` : 'No task prerequisite recorded'}</div>
      </article>
    `;
  }).join('') || '<div class="empty-state">No tasks match this filter.</div>';

  document.querySelectorAll('.task-row').forEach((row) => {
    row.addEventListener('click', () => selectTask(row.dataset.taskId));
  });
}

function selectTask(taskId) {
  selectedTaskId = taskId;
  const task = taskById(taskId);
  if (!task) return;

  el('review-empty').hidden = true;
  el('review-detail').hidden = false;
  el('detail-stage').textContent = `Stage ${task.stageKey} — ${task.stageName}`;
  el('detail-task-name').textContent = task.name;
  el('detail-task-id').textContent = `Stable prototype identity: ${task.id}`;
  el('detail-verification').textContent = verificationLabel(task.verification);
  el('detail-verification').className = `pill ${verificationClass(task.verification)}`;

  el('edit-task-name').value = task.name;
  el('edit-crew').value = task.crew;
  el('edit-duration').value = task.duration;
  el('edit-captain').value = task.captain;
  el('edit-equipment').value = task.equipment;
  el('edit-completion').value = task.completion;
  el('edit-notes').value = task.notes;
  el('edit-actual-dates').value = task.actual?.dates || '';
  el('edit-actual-crew').value = task.actual?.crew || '';
  el('edit-actual-duration').value = task.actual?.duration || '';
  el('edit-actual-notes').value = task.actual?.notes || '';

  const deps = dependencyNames(task);
  el('detail-dependencies').innerHTML = deps.length
    ? deps.map((name) => `<span class="chip">${escapeHtml(name)}</span>`).join('')
    : '<span class="muted">No task prerequisite recorded.</span>';
  el('detail-material').textContent = task.material || 'No physical material relationship recorded.';

  renderReviewList();
}

function saveSelectedTask() {
  const task = taskById(selectedTaskId);
  if (!task) return;
  task.name = el('edit-task-name').value.trim() || task.name;
  task.crew = el('edit-crew').value.trim();
  task.duration = el('edit-duration').value.trim();
  task.captain = el('edit-captain').value.trim();
  task.equipment = el('edit-equipment').value.trim();
  task.completion = el('edit-completion').value.trim();
  task.notes = el('edit-notes').value.trim();
  task.actual = {
    dates: el('edit-actual-dates').value.trim(),
    crew: el('edit-actual-crew').value.trim(),
    duration: el('edit-actual-duration').value.trim(),
    notes: el('edit-actual-notes').value.trim()
  };
  saveState();
  renderAll();
  selectTask(task.id);
}

function setVerification(status) {
  const task = taskById(selectedTaskId);
  if (!task) return;
  saveSelectedTask();
  task.verification = status;
  saveState();
  renderAll();
  selectTask(task.id);
}

function renderLibrary() {
  const grouped = new Map();
  sortedTasks().forEach((task) => {
    const key = `${task.stageKey}|${task.stageName}`;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(task);
  });

  el('library-list').innerHTML = [...grouped.entries()].map(([key, tasks]) => {
    const [stageKey, stageName] = key.split('|');
    return `
      <section class="library-stage">
        <div class="library-stage-heading">Stage ${stageKey} — ${stageName}</div>
        ${tasks.map((task, index) => `
          <div class="library-task">
            <div class="library-order">${index + 1}</div>
            <div>
              <strong>${escapeHtml(task.name)}</strong>
              <div class="task-meta">${task.id} · ${verificationLabel(task.verification)}</div>
            </div>
            <div class="task-meta">${dependencyNames(task).length ? `Requires: ${dependencyNames(task).map(escapeHtml).join('; ')}` : 'No prerequisite'}</div>
            <div class="library-actions">
              <button type="button" class="small secondary move-up" data-task-id="${task.id}" ${index === 0 ? 'disabled' : ''}>↑</button>
              <button type="button" class="small secondary move-down" data-task-id="${task.id}" ${index === tasks.length - 1 ? 'disabled' : ''}>↓</button>
              <button type="button" class="small open-task" data-task-id="${task.id}">Review</button>
            </div>
          </div>
        `).join('')}
      </section>
    `;
  }).join('');

  document.querySelectorAll('.open-task').forEach((button) => {
    button.addEventListener('click', () => {
      showView('review');
      selectTask(button.dataset.taskId);
    });
  });
  document.querySelectorAll('.move-up').forEach((button) => button.addEventListener('click', () => moveTask(button.dataset.taskId, -1)));
  document.querySelectorAll('.move-down').forEach((button) => button.addEventListener('click', () => moveTask(button.dataset.taskId, 1)));
}

function moveTask(taskId, direction) {
  const task = taskById(taskId);
  if (!task) return;
  const sameStage = sortedTasks().filter((candidate) => candidate.stageKey === task.stageKey && candidate.stageName === task.stageName);
  const index = sameStage.findIndex((candidate) => candidate.id === taskId);
  const swap = sameStage[index + direction];
  if (!swap) return;
  const old = task.order;
  task.order = swap.order;
  swap.order = old;
  if (task.order === swap.order) {
    task.order = index + direction;
    swap.order = index;
  }
  saveState();
  renderLibrary();
}

function addProvisionalTask() {
  const stageKey = prompt('Stage key (example 26):');
  if (!stageKey) return;
  const stageName = prompt('Stage / area name:');
  if (!stageName) return;
  const name = prompt('Practical Setup task name:');
  if (!name) return;
  const id = `PROV-${Date.now()}`;
  state.tasks.push({
    id, stageKey: stageKey.trim(), stageName: stageName.trim(), order: 999,
    name: name.trim(), verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'To verify', notes: 'Added in prototype for review.', dependencies: [],
    material: 'To verify', actual: { dates: '', crew: '', duration: '', notes: '' }
  });
  saveState();
  renderAll();
  showView('review');
  selectTask(id);
}

function unloadTasks() {
  return sortedTasks().filter((task) => task.unload);
}

function movementGroupForTask(taskId) {
  return state.movement.groups.find((group) => group.taskId === taskId);
}

function renderMovementTaskOptions() {
  const select = el('movement-task-select');
  const previous = select.value;
  select.innerHTML = unloadTasks().map((task) => {
    const group = movementGroupForTask(task.id);
    const suffix = group?.status === 'UNLOADED' ? ' — complete' : '';
    return `<option value="${task.id}">${escapeHtml(task.name)}${suffix}</option>`;
  }).join('');
  if ([...select.options].some((option) => option.value === previous)) select.value = previous;
  renderMovementTaskDetail();
}

function renderMovementTaskDetail() {
  const task = taskById(el('movement-task-select').value);
  if (!task?.unload) {
    el('movement-task-detail').innerHTML = '<span class="muted">No unload task selected.</span>';
    return;
  }
  const group = movementGroupForTask(task.id);
  const inheritedLocation = group.status === 'ONBOARD' ? state.movement.location : group.location;
  el('movement-task-detail').innerHTML = `
    <strong>${escapeHtml(task.name)}</strong><br>
    Destination: ${escapeHtml(task.unload.destination)}<br>
    Expected group: ${task.unload.count} Displays<br>
    Current group state: <span class="pill ${group.status === 'UNLOADED' ? 'unloaded' : 'onboard'}">${group.status === 'UNLOADED' ? 'UNLOADED' : 'WITH CONTAINER 34'}</span><br>
    Current Setup location: ${escapeHtml(inheritedLocation || 'Unknown')}
  `;
  el('confirm-unload').disabled = group.status === 'UNLOADED';
}

function logMovement(type, description) {
  state.movement.events.unshift({
    type,
    description,
    at: new Date().toLocaleString()
  });
}

function moveContainerToSelectedDestination() {
  const task = taskById(el('movement-task-select').value);
  if (!task?.unload) return;
  const previous = state.movement.location;
  state.movement.location = task.unload.destination;
  logMovement('CONTAINER SCAN', `Container 34 moved from ${previous} to ${task.unload.destination}. Only Display groups still with the Container follow this movement.`);
  saveState();
  renderMovement();
}

function confirmSelectedUnload() {
  const task = taskById(el('movement-task-select').value);
  if (!task?.unload) return;
  const group = movementGroupForTask(task.id);
  if (!group || group.status === 'UNLOADED') return;

  if (state.movement.location !== task.unload.destination) {
    const ok = confirm(`Container 34 is currently at "${state.movement.location}" in the prototype. Move it to ${task.unload.destination} first?`);
    if (!ok) return;
    moveContainerToSelectedDestination();
  }

  group.status = 'UNLOADED';
  group.location = task.unload.destination;
  logMovement('BULK UNLOAD', `${task.name}: ${group.count} Displays detached from Container 34 at ${group.location}. They will not follow later Container scans.`);
  saveState();
  renderAll();
}

function renderMovement() {
  const onboard = state.movement.groups.filter((group) => group.status === 'ONBOARD').reduce((sum, group) => sum + group.count, 0);
  const unloaded = state.movement.groups.filter((group) => group.status === 'UNLOADED').reduce((sum, group) => sum + group.count, 0);
  el('container-location').textContent = state.movement.location;
  el('container-onboard').textContent = `${onboard} Displays`;
  el('container-unloaded').textContent = `${unloaded} Displays`;

  el('arch-groups').innerHTML = state.movement.groups.map((group) => {
    const effectiveLocation = group.status === 'ONBOARD' ? state.movement.location : group.location;
    return `
      <article class="arch-group">
        <div class="eyebrow">Stage ${group.stageKey}</div>
        <h3>${escapeHtml(group.name)}</h3>
        <div class="group-count">${group.count}</div>
        <span class="pill ${group.status === 'UNLOADED' ? 'unloaded' : 'onboard'}">${group.status === 'UNLOADED' ? 'UNLOADED' : 'WITH CONTAINER 34'}</span>
        <div class="task-meta" style="margin-top:8px">Setup location: ${escapeHtml(effectiveLocation || 'Unknown')}</div>
      </article>
    `;
  }).join('');

  el('movement-log').innerHTML = state.movement.events.length
    ? state.movement.events.map((event) => `
        <div class="event-row"><strong>${escapeHtml(event.type)} — ${escapeHtml(event.description)}</strong><span>${escapeHtml(event.at)}</span></div>
      `).join('')
    : '<div class="empty-state">No prototype movement events yet. Choose an unload task and simulate a Container scan.</div>';

  renderMovementTaskOptions();
}

function renderAll() {
  renderSummary();
  renderReviewList();
  renderLibrary();
  renderMovement();
}

function showView(name) {
  document.querySelectorAll('.tab').forEach((button) => button.classList.toggle('active', button.dataset.view === name));
  document.querySelectorAll('.view').forEach((view) => view.classList.remove('active-view'));
  el(`${name}-view`).classList.add('active-view');
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

document.querySelectorAll('.tab').forEach((button) => button.addEventListener('click', () => showView(button.dataset.view)));
el('review-status-filter').addEventListener('change', renderReviewList);
el('save-task').addEventListener('click', saveSelectedTask);
el('mark-verified').addEventListener('click', () => setVerification('VERIFIED'));
el('mark-correction').addEventListener('click', () => setVerification('NEEDS_CORRECTION'));
el('mark-unverified').addEventListener('click', () => setVerification('UNVERIFIED'));
el('add-task').addEventListener('click', addProvisionalTask);
el('movement-task-select').addEventListener('change', renderMovementTaskDetail);
el('move-container').addEventListener('click', moveContainerToSelectedDestination);
el('confirm-unload').addEventListener('click', confirmSelectedUnload);
el('reset-prototype').addEventListener('click', () => {
  if (!confirm('Reset all prototype edits, verification states, and movement events?')) return;
  localStorage.removeItem(STORAGE_KEY);
  state = defaultState();
  selectedTaskId = null;
  el('review-detail').hidden = true;
  el('review-empty').hidden = false;
  renderAll();
});

renderAll();
