/* MSB Setup Session shared Production browser. No localStorage/prototype state. */

const appState = {
  access: null,
  seasons: [],
  stages: [],
  tasks: [],
  seasonYear: null,
  selectedTaskId: null,
  movementSummary: null
};

const el = (id) => document.getElementById(id);

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

async function api(path, options = {}) {
  const response = await fetch(path.replace(/^\/+/, ''), {
    credentials: 'same-origin',
    headers: {
      Accept: 'application/json',
      ...(options.headers || {})
    },
    ...options
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload.error || `Setup API returned HTTP ${response.status}`);
    error.status = response.status;
    error.payload = payload;
    throw error;
  }
  return payload;
}

function commandOptions(method, body) {
  return {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-MSB-Setup-Command': '1'
    },
    body: JSON.stringify(body)
  };
}

function setAlert(message, state = 'ok') {
  const target = el('app-alert');
  target.textContent = message;
  target.dataset.state = state;
}

function setBusy(flag) {
  document.body.classList.toggle('busy', Boolean(flag));
}

function nullableInteger(value) {
  const text = String(value ?? '').trim();
  if (!text) return null;
  const parsed = Number.parseInt(text, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function formatMinutes(value) {
  if (value == null || value === '') return 'To verify';
  const minutes = Number(value);
  if (!Number.isFinite(minutes)) return String(value);
  if (minutes < 60) return `${minutes} min`;
  const hours = minutes / 60;
  return Number.isInteger(hours) ? `${hours} hr` : `${hours.toFixed(1)} hr`;
}

function formatCrew(task) {
  const min = task.normal_crew_min;
  const max = task.normal_crew_max;
  if (min == null && max == null) return 'To verify';
  if (min != null && max != null && min !== max) return `${min}–${max}`;
  return String(min ?? max);
}

function formatTimestamp(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleString();
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

function taskById(id) {
  return appState.tasks.find((task) => Number(task.setup_task_id) === Number(id));
}

function sortedTasks(tasks = appState.tasks) {
  return [...tasks].sort((a, b) => {
    const stageA = String(a.stage_key ?? 'zzzz');
    const stageB = String(b.stage_key ?? 'zzzz');
    const stageCompare = stageA.localeCompare(stageB, undefined, { numeric: true });
    if (stageCompare !== 0) return stageCompare;
    if (Number(a.display_order) !== Number(b.display_order)) {
      return Number(a.display_order) - Number(b.display_order);
    }
    return String(a.task_name).localeCompare(String(b.task_name));
  });
}

function showView(name) {
  document.querySelectorAll('.tab').forEach((button) => {
    button.classList.toggle('active', button.dataset.view === name);
  });
  document.querySelectorAll('.view').forEach((view) => view.classList.remove('active-view'));
  el(`${name}-view`).classList.add('active-view');
}

function applyAccess() {
  const access = appState.access || {};
  const role = access.role_name || 'No Directus role';
  el('access-badge').textContent = `${access.display_name || access.authenticated_email || 'Signed in'} · ${role}`;

  document.querySelectorAll('.manager-only').forEach((node) => {
    node.hidden = !access.can_manage_setup;
  });

  const editable = Boolean(access.can_manage_setup);
  [
    'edit-task-name', 'edit-stage-id', 'edit-action-type', 'edit-display-order',
    'edit-active-flag', 'edit-crew-min', 'edit-crew-max', 'edit-duration-minutes',
    'edit-completion', 'edit-readiness', 'edit-weather', 'edit-reusable-notes',
    'edit-actual-crew', 'edit-actual-duration', 'edit-annual-notes'
  ].forEach((id) => {
    const node = el(id);
    if (node) node.disabled = !editable;
  });
}

function renderSeasonOptions() {
  const select = el('season-select');
  select.innerHTML = appState.seasons.map((season) => {
    const label = season.setup_session_id
      ? `${season.season_year} — ${String(season.session_status || '').replaceAll('_', ' ')}`
      : `${season.season_year} — no Setup Session`;
    return `<option value="${season.season_year}">${escapeHtml(label)}</option>`;
  }).join('');

  if (appState.seasonYear != null) select.value = String(appState.seasonYear);
}

function populateStageSelects() {
  const options = sortedStages().map((stage) => (
    `<option value="${stage.stage_id}">${escapeHtml(stage.stage_key)} — ${escapeHtml(stage.stage_name || stage.folder_name || '')}</option>`
  )).join('');
  el('edit-stage-id').innerHTML = `<option value="">No Stage / general context</option>${options}`;
  el('add-stage-id').innerHTML = `<option value="">No Stage / general context</option>${options}`;
}

function sortedStages() {
  return [...appState.stages].sort((a, b) => {
    const ao = a.park_order == null ? 9999 : Number(a.park_order);
    const bo = b.park_order == null ? 9999 : Number(b.park_order);
    if (ao !== bo) return ao - bo;
    const as = a.sub_order == null ? 9999 : Number(a.sub_order);
    const bs = b.sub_order == null ? 9999 : Number(b.sub_order);
    if (as !== bs) return as - bs;
    return String(a.stage_key).localeCompare(String(b.stage_key), undefined, { numeric: true });
  });
}

function currentSeasonRecord() {
  return appState.seasons.find((season) => Number(season.season_year) === Number(appState.seasonYear));
}

function renderSummary() {
  const annual = appState.tasks.filter((task) => task.setup_session_task_id != null);
  const counts = annual.reduce((acc, task) => {
    const key = task.verification_state || 'UNVERIFIED';
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});
  const activeReusable = appState.tasks.filter((task) => task.active_flag).length;
  const stageKeysWithTasks = new Set(appState.tasks.filter((task) => task.active_flag && task.stage_key).map((task) => String(task.stage_key)));
  const gapCount = appState.stages.filter((stage) => stage.stage_key && !stageKeysWithTasks.has(String(stage.stage_key))).length;

  el('summary-grid').innerHTML = `
    <div class="summary-card"><span>Reusable tasks</span><strong>${activeReusable}</strong></div>
    <div class="summary-card"><span>${appState.seasonYear || ''} unverified</span><strong>${counts.UNVERIFIED || 0}</strong></div>
    <div class="summary-card"><span>${appState.seasonYear || ''} needs correction</span><strong>${counts.NEEDS_CORRECTION || 0}</strong></div>
    <div class="summary-card"><span>${appState.seasonYear || ''} verified</span><strong>${counts.VERIFIED || 0}</strong></div>
    <div class="summary-card"><span>Stages with no tasks yet</span><strong>${gapCount}</strong></div>
  `;
}

function renderReviewList() {
  const filter = el('review-status-filter').value;
  const annualTasks = sortedTasks().filter((task) => task.setup_session_task_id != null);
  const tasks = annualTasks.filter((task) => !filter || task.verification_state === filter);

  el('review-list').innerHTML = tasks.map((task) => {
    const deps = task.dependencies || [];
    return `
      <article class="task-row ${Number(appState.selectedTaskId) === Number(task.setup_task_id) ? 'selected' : ''}" data-task-id="${task.setup_task_id}">
        <div class="task-row-top">
          <div>
            <div class="eyebrow">Stage ${escapeHtml(task.stage_key || '—')} — ${escapeHtml(task.stage_name || 'General')}</div>
            <h3>${escapeHtml(task.task_name)}</h3>
          </div>
          <span class="pill ${verificationClass(task.verification_state)}">${verificationLabel(task.verification_state)}</span>
        </div>
        <div class="task-meta">Crew: ${escapeHtml(formatCrew(task))} · Time: ${escapeHtml(formatMinutes(task.expected_duration_minutes))}</div>
        <div class="task-dependency">${deps.length ? `Requires: ${deps.map((dep) => escapeHtml(dep.task_name)).join('; ')}` : 'No task prerequisite recorded'}</div>
      </article>
    `;
  }).join('') || '<div class="empty-state">No annual tasks match this filter.</div>';

  document.querySelectorAll('.task-row').forEach((row) => {
    row.addEventListener('click', () => selectTask(Number(row.dataset.taskId)));
  });
}

function renderStageGaps() {
  const taskStageKeys = new Set(appState.tasks.filter((task) => task.active_flag && task.stage_key).map((task) => String(task.stage_key)));
  const gaps = sortedStages().filter((stage) => stage.stage_key && !taskStageKeys.has(String(stage.stage_key)));
  const target = el('stage-gap-list');
  if (!gaps.length) {
    target.innerHTML = '';
    return;
  }
  target.innerHTML = `
    <div class="eyebrow">Reconstruction gaps</div>
    ${gaps.map((stage) => `
      <div class="stage-gap-row">
        <strong>Stage ${escapeHtml(stage.stage_key)} — ${escapeHtml(stage.stage_name || stage.folder_name || '')}</strong>
        <div class="muted">No active reusable Setup task has been defined for this Stage yet. Stage existence is not evidence that no Setup work exists.</div>
      </div>
    `).join('')}
  `;
}

function renderLibrary() {
  const grouped = new Map();
  sortedTasks().forEach((task) => {
    const key = `${task.stage_key || '—'}|${task.stage_name || 'General / no Stage'}`;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(task);
  });

  el('library-list').innerHTML = [...grouped.entries()].map(([key, tasks]) => {
    const [stageKey, stageName] = key.split('|');
    return `
      <section class="library-stage">
        <div class="library-stage-heading">Stage ${escapeHtml(stageKey)} — ${escapeHtml(stageName)}</div>
        ${tasks.map((task) => `
          <div class="library-task">
            <div class="library-order">${escapeHtml(task.display_order)}</div>
            <div>
              <strong>${escapeHtml(task.task_name)}</strong>
              <div class="task-meta">Task ${task.setup_task_id} · ${escapeHtml(task.task_action_type)}${task.active_flag ? '' : ' · inactive'}</div>
            </div>
            <div class="task-meta">${(task.dependencies || []).length ? `Requires: ${(task.dependencies || []).map((dep) => escapeHtml(dep.task_name)).join('; ')}` : 'No prerequisite'}</div>
            <div class="library-actions"><button type="button" class="small open-task" data-task-id="${task.setup_task_id}">Open</button></div>
          </div>
        `).join('')}
      </section>
    `;
  }).join('') || '<div class="empty-state">No reusable Setup tasks exist.</div>';

  document.querySelectorAll('.open-task').forEach((button) => {
    button.addEventListener('click', () => {
      showView('review');
      selectTask(Number(button.dataset.taskId));
    });
  });
  renderStageGaps();
}

function renderDependencyChips(task) {
  const deps = task.dependencies || [];
  el('detail-dependencies').innerHTML = deps.length
    ? deps.map((dep) => `<span class="chip">${escapeHtml(dep.task_name)}${dep.dependency_note ? ` — ${escapeHtml(dep.dependency_note)}` : ''}</span>`).join('')
    : '<span class="muted">No task prerequisite recorded.</span>';
}

function selectTask(taskId) {
  const task = taskById(taskId);
  if (!task) return;
  appState.selectedTaskId = Number(taskId);

  el('review-empty').hidden = true;
  el('review-detail').hidden = false;
  el('detail-stage').textContent = `Stage ${task.stage_key || '—'} — ${task.stage_name || 'General'}`;
  el('detail-task-name').textContent = task.task_name;
  el('detail-task-id').textContent = `Reusable task ID ${task.setup_task_id} · Annual task ID ${task.setup_session_task_id || 'not in selected season'}`;
  el('detail-verification').textContent = verificationLabel(task.verification_state);
  el('detail-verification').className = `pill ${verificationClass(task.verification_state)}`;

  el('edit-task-name').value = task.task_name || '';
  el('edit-stage-id').value = task.stage_id == null ? '' : String(task.stage_id);
  el('edit-action-type').value = task.task_action_type || 'WORK';
  el('edit-display-order').value = task.display_order ?? 100;
  el('edit-active-flag').checked = Boolean(task.active_flag);
  el('edit-crew-min').value = task.normal_crew_min ?? '';
  el('edit-crew-max').value = task.normal_crew_max ?? '';
  el('edit-duration-minutes').value = task.expected_duration_minutes ?? '';
  el('edit-completion').value = task.completion_point || '';
  el('edit-readiness').value = task.readiness_note || '';
  el('edit-weather').value = task.weather_note || '';
  el('edit-reusable-notes').value = task.reusable_notes || '';

  const annualAvailable = task.setup_session_task_id != null;
  el('annual-legend').textContent = `${appState.seasonYear} Annual Historical Actual`;
  el('annual-execution-status').value = task.execution_status || '';
  el('edit-actual-crew').value = task.actual_crew_count ?? '';
  el('edit-actual-duration').value = task.actual_duration_minutes ?? '';
  el('annual-started-at').value = formatTimestamp(task.actual_started_at);
  el('annual-completed-at').value = formatTimestamp(task.actual_completed_at);
  el('edit-annual-notes').value = task.annual_notes || '';
  el('annual-fieldset').disabled = !annualAvailable || !appState.access?.can_manage_setup;

  renderDependencyChips(task);
  renderReviewList();
  loadProcedure(task);
}

async function saveReusableTask() {
  const task = taskById(appState.selectedTaskId);
  if (!task || !appState.access?.can_manage_setup) return;

  const payload = {
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

  try {
    setBusy(true);
    await api(`api/setup/tasks/${task.setup_task_id}`, commandOptions('PATCH', payload));
    setAlert(`Reusable task ${task.setup_task_id} saved to Production.`, 'ok');
    await reloadTasks(task.setup_task_id);
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function saveAnnualReview(verificationOverride = null) {
  const task = taskById(appState.selectedTaskId);
  if (!task || task.setup_session_task_id == null || !appState.access?.can_manage_setup) return;

  const payload = {
    verification_state: verificationOverride || task.verification_state || 'UNVERIFIED',
    actual_started_at: task.actual_started_at || null,
    actual_completed_at: task.actual_completed_at || null,
    actual_crew_count: nullableInteger(el('edit-actual-crew').value),
    actual_duration_minutes: nullableInteger(el('edit-actual-duration').value),
    annual_notes: el('edit-annual-notes').value.trim()
  };

  try {
    setBusy(true);
    await api(
      `api/setup/session-tasks/${task.setup_session_task_id}/review`,
      commandOptions('PATCH', payload)
    );
    setAlert(`${appState.seasonYear} annual review saved to Production.`, 'ok');
    await reloadTasks(task.setup_task_id);
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function createReusableTask(event) {
  event.preventDefault();
  if (!appState.access?.can_manage_setup) return;

  const payload = {
    task_name: el('add-task-name').value.trim(),
    stage_id: nullableInteger(el('add-stage-id').value),
    task_action_type: el('add-action-type').value,
    display_order: nullableInteger(el('add-display-order').value) ?? 100,
    normal_crew_min: null,
    normal_crew_max: null,
    expected_duration_minutes: null,
    completion_point: null,
    readiness_note: null,
    weather_note: null,
    reusable_notes: 'Added through the shared Setup Manager application; complete reusable knowledge during verification.'
  };

  if (!payload.task_name) return;

  try {
    setBusy(true);
    const result = await api('api/setup/tasks', commandOptions('POST', payload));
    const newId = result.setup_task?.setup_task_id;
    setAlert(`Reusable task ${newId || ''} created in Production.`, 'ok');
    el('add-task-form').hidden = true;
    el('add-task-form').reset();
    el('add-display-order').value = '100';
    await reloadTasks(newId || null);
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function renderCurrentPdfs(files, task) {
  const target = el('production-current-pdf');
  if (!files?.length) {
    target.innerHTML = '<strong>No published Setup PDF found.</strong><div class="muted">Published field instructions belong directly in Procedures\\Setup.</div>';
    return;
  }
  target.innerHTML = files.map((file) => {
    const href = `api/setup/procedure/current?stage_key=${encodeURIComponent(task.stage_key)}&name=${encodeURIComponent(file.name || '')}`;
    return `
      <div class="procedure-file">
        <strong>${escapeHtml(file.name || 'Unnamed PDF')}</strong>
        <div class="procedure-file-path">${escapeHtml(file.path || '')}</div>
        <div class="procedure-file-actions"><a href="${href}" target="_blank" rel="noopener">Open Current PDF</a></div>
      </div>
    `;
  }).join('');
}

function renderEditableSources(files) {
  const target = el('production-editable-procedure');
  if (!appState.access?.can_manage_setup) {
    target.innerHTML = '';
    return;
  }
  if (!files?.length) {
    target.innerHTML = '<strong>No editable .gdoc source found.</strong><div class="muted">SourceDocs is preferred; Archive is accepted as the 2025 compatibility fallback.</div>';
    return;
  }
  target.innerHTML = files.map((file) => {
    const edit = file.edit_url
      ? `<a href="${escapeHtml(file.edit_url)}" target="_blank" rel="noopener">Open Editable Procedure</a>`
      : '<span class="muted">Google document link could not be resolved.</span>';
    const exportPdf = file.pdf_export_url
      ? `<a href="${escapeHtml(file.pdf_export_url)}" target="_blank" rel="noopener">Export Updated PDF</a>`
      : '';
    return `
      <div class="procedure-file">
        <strong>${escapeHtml(file.name || 'Unnamed .gdoc')}</strong>
        <div class="procedure-file-path">${escapeHtml(file.path || '')}</div>
        <div class="procedure-file-actions">${edit}${exportPdf}</div>
      </div>
    `;
  }).join('');
}

async function loadProcedure(task) {
  const current = el('production-current-pdf');
  const editable = el('production-editable-procedure');
  const warnings = el('production-procedure-warnings');
  current.innerHTML = '<span class="muted">Resolving current Setup Procedure…</span>';
  if (editable) editable.innerHTML = '<span class="muted">Resolving Manager source…</span>';
  warnings.innerHTML = '';

  if (!task.stage_key) {
    current.innerHTML = '<span class="muted">No Stage context is assigned to this task.</span>';
    if (editable) editable.innerHTML = '';
    return;
  }

  try {
    const payload = await api(`api/setup/procedure?stage_key=${encodeURIComponent(task.stage_key)}`);
    const data = payload.instructions || {};
    renderCurrentPdfs(data.current_documents || [], task);
    renderEditableSources(data.editable_sources || []);
    warnings.innerHTML = (data.warnings || []).map((warning) => `<div>${escapeHtml(warning)}</div>`).join('');
  } catch (error) {
    current.innerHTML = `<strong>Setup Procedure could not be resolved.</strong><div class="muted">${escapeHtml(error.message || error)}</div>`;
    if (editable) editable.innerHTML = '';
  }
}

function renderMovementSummary() {
  const summary = appState.movementSummary || {};
  el('movement-display-state').textContent = summary.display_state_rows ?? '—';
  el('movement-container-state').textContent = summary.container_state_rows ?? '—';
  el('movement-event-count').textContent = summary.movement_event_rows ?? '—';
}

async function reloadTasks(selectTaskId = null) {
  const payload = await api(`api/setup/tasks?season_year=${encodeURIComponent(appState.seasonYear)}`);
  appState.tasks = payload.tasks || [];
  renderSummary();
  renderReviewList();
  renderLibrary();
  if (selectTaskId != null && taskById(selectTaskId)) {
    selectTask(Number(selectTaskId));
  } else if (appState.selectedTaskId && taskById(appState.selectedTaskId)) {
    selectTask(appState.selectedTaskId);
  } else {
    appState.selectedTaskId = null;
    el('review-detail').hidden = true;
    el('review-empty').hidden = false;
  }
}

async function loadSeason(year) {
  appState.seasonYear = Number(year);
  renderSeasonOptions();
  const season = currentSeasonRecord();
  el('review-season-label').textContent = `${appState.seasonYear} season`;
  el('app-subhead').textContent = season?.session_status === 'HISTORICAL_VERIFICATION'
    ? `${appState.seasonYear} historical verification — shared Production data`
    : `${appState.seasonYear} Setup Session — shared Production data`;

  try {
    setBusy(true);
    const [tasksPayload, movementPayload] = await Promise.all([
      api(`api/setup/tasks?season_year=${encodeURIComponent(appState.seasonYear)}`),
      api(`api/setup/movement-summary?season_year=${encodeURIComponent(appState.seasonYear)}`)
    ]);
    appState.tasks = tasksPayload.tasks || [];
    appState.movementSummary = movementPayload.movement || null;
    appState.selectedTaskId = null;
    el('review-detail').hidden = true;
    el('review-empty').hidden = false;
    renderSummary();
    renderReviewList();
    renderLibrary();
    renderMovementSummary();
    setAlert(
      season?.setup_session_id
        ? `${appState.seasonYear} Setup Session loaded from Production. Changes made by authorized Managers are shared immediately.`
        : `${appState.seasonYear} has no annual Setup Session yet. The reusable catalog remains available.`,
      'ok'
    );
  } catch (error) {
    setAlert(error.message || error, 'error');
    throw error;
  } finally {
    setBusy(false);
  }
}

function chooseInitialSeason() {
  const historical = appState.seasons.find((season) => season.session_status === 'HISTORICAL_VERIFICATION');
  if (historical) return Number(historical.season_year);
  const activeWithSession = appState.seasons.find((season) => season.active_flag && season.setup_session_id);
  if (activeWithSession) return Number(activeWithSession.season_year);
  const anySession = appState.seasons.find((season) => season.setup_session_id);
  if (anySession) return Number(anySession.season_year);
  return appState.seasons.length ? Number(appState.seasons[0].season_year) : null;
}

async function initialize() {
  try {
    setBusy(true);
    const accessPayload = await api('api/setup/access');
    appState.access = accessPayload.access || {};
    applyAccess();

    if (!appState.access.can_read_setup) {
      throw new Error('Your Directus role/policy does not currently authorize Setup access.');
    }

    const [seasonsPayload, stagesPayload] = await Promise.all([
      api('api/setup/seasons'),
      api('api/setup/stages')
    ]);
    appState.seasons = seasonsPayload.seasons || [];
    appState.stages = stagesPayload.stages || [];
    appState.seasonYear = chooseInitialSeason();
    renderSeasonOptions();
    populateStageSelects();
    applyAccess();

    if (appState.seasonYear == null) {
      throw new Error('No Setup season is available.');
    }
    await loadSeason(appState.seasonYear);
  } catch (error) {
    setAlert(error.message || error, 'error');
    el('access-badge').textContent = 'Setup access unavailable';
  } finally {
    setBusy(false);
  }
}

document.querySelectorAll('.tab').forEach((button) => {
  button.addEventListener('click', () => showView(button.dataset.view));
});
el('season-select').addEventListener('change', () => loadSeason(el('season-select').value));
el('review-status-filter').addEventListener('change', renderReviewList);
el('save-reusable-task').addEventListener('click', saveReusableTask);
el('save-annual-review').addEventListener('click', () => saveAnnualReview());
el('mark-verified').addEventListener('click', () => saveAnnualReview('VERIFIED'));
el('mark-correction').addEventListener('click', () => saveAnnualReview('NEEDS_CORRECTION'));
el('mark-unverified').addEventListener('click', () => saveAnnualReview('UNVERIFIED'));
el('show-add-task').addEventListener('click', () => { el('add-task-form').hidden = false; });
el('cancel-add-task').addEventListener('click', () => { el('add-task-form').hidden = true; });
el('add-task-form').addEventListener('submit', createReusableTask);

initialize();
