/* Setup V0.2 browser-review UI: Scene organization, scheduling, and field execution. */

const setupNextState = {
  scenes: [],
  taskScopes: new Map(),
  closedStages: new Set(),
  closedScopes: new Set(),
  draggedTaskId: null,
  copySourceId: null,
  schedule: { work_days: [], assignments: [] },
  executionTasks: []
};

function nextScopeKey(stageId, sceneId) {
  return `${stageId ?? 'none'}:${sceneId ?? 'stage'}`;
}

function nextSceneById(sceneId) {
  return setupNextState.scenes.find((scene) => Number(scene.lor_scene_id) === Number(sceneId));
}

function nextScenesForStage(stageId) {
  return setupNextState.scenes
    .filter((scene) => Number(scene.stage_id) === Number(stageId))
    .sort((a, b) => String(a.scene_name).localeCompare(String(b.scene_name), undefined, { numeric: true }));
}

function applyNextTaskScopes() {
  for (const task of appState.tasks || []) {
    const scope = setupNextState.taskScopes.get(Number(task.setup_task_id));
    if (!scope) continue;
    task.stage_id = scope.stage_id;
    task.lor_scene_id = scope.lor_scene_id;
    task.scene_name = scope.scene_name || null;
    if (scope.stage_id != null) {
      const stage = appState.stages.find((item) => Number(item.stage_id) === Number(scope.stage_id));
      if (stage) {
        task.stage_key = stage.stage_key;
        task.stage_name = stage.stage_name;
      }
    }
  }
}

async function loadNextOrganization(render = true) {
  const payload = await api('api/setup/organization');
  const data = payload.organization || {};
  setupNextState.scenes = data.scenes || [];
  setupNextState.taskScopes = new Map(
    (data.task_scopes || []).map((scope) => [Number(scope.setup_task_id), scope])
  );
  applyNextTaskScopes();
  if (render && appState.tasks?.length) renderLibrary();
}

function nextTasksForScope(stageId, sceneId) {
  return sortedTasks().filter((task) => (
    Number(task.stage_id) === Number(stageId)
    && (sceneId == null ? task.lor_scene_id == null : Number(task.lor_scene_id) === Number(sceneId))
  ));
}

function nextTaskLabel(task) {
  const stage = task.stage_key ? `Stage ${task.stage_key}` : 'General';
  const scope = task.scene_name ? ` / ${task.scene_name}` : ' / Stage-level';
  return `${stage}${scope} — ${task.task_name}`;
}

async function nextPersistOrder(tasks) {
  for (let i = 0; i < tasks.length; i += 1) {
    const task = tasks[i];
    const desired = (i + 1) * 10;
    if (Number(task.display_order) === desired) continue;
    await api(
      `api/setup/tasks/${task.setup_task_id}`,
      commandOptions('PATCH', setupTaskUpdatePayload(task, { display_order: desired }))
    );
  }
}

async function nextMoveTask(taskId, stageId, sceneId, beforeTaskId = null) {
  const task = taskById(taskId);
  if (!task || !appState.access?.can_manage_setup) return;
  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${taskId}/scope`,
      commandOptions('PATCH', {
        stage_id: Number(stageId),
        lor_scene_id: sceneId == null ? null : Number(sceneId)
      })
    );
    await reloadTasks(null);
    await loadNextOrganization(false);
    const destination = nextTasksForScope(stageId, sceneId);
    const sourceIndex = destination.findIndex((item) => Number(item.setup_task_id) === Number(taskId));
    if (sourceIndex >= 0) destination.splice(sourceIndex, 1);
    if (beforeTaskId != null) {
      const targetIndex = destination.findIndex((item) => Number(item.setup_task_id) === Number(beforeTaskId));
      destination.splice(targetIndex < 0 ? destination.length : targetIndex, 0, taskById(taskId));
    } else {
      destination.push(taskById(taskId));
    }
    await nextPersistOrder(destination.filter(Boolean));
    await reloadTasks(null);
    await loadNextOrganization(false);
    const stage = appState.stages.find((item) => Number(item.stage_id) === Number(stageId));
    const scene = sceneId == null ? null : nextSceneById(sceneId);
    setupNextState.closedStages.delete(String(stageId));
    setupNextState.closedScopes.delete(nextScopeKey(stageId, sceneId));
    renderLibrary();
    setAlert(`Task moved to ${stage?.stage_key || 'Stage'}${scene ? ` / ${scene.scene_name}` : ' / Stage-level'}.`, 'ok');
    requestAnimationFrame(() => {
      document.querySelector(`[data-task-id="${taskId}"]`)?.scrollIntoView({ block: 'center', behavior: 'smooth' });
    });
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function nextTaskRow(task, stageId, sceneId, index, total) {
  const deps = task.dependencies || [];
  const canManage = Boolean(appState.access?.can_manage_setup);
  return `
    <div class="library-task next-task-row" draggable="${canManage ? 'true' : 'false'}"
         data-task-id="${task.setup_task_id}" data-stage-id="${stageId}" data-scene-id="${sceneId ?? ''}">
      <div class="library-order">${escapeHtml(task.display_order)}</div>
      <div class="next-task-main">
        <strong>${escapeHtml(task.task_name)}</strong>
        <div class="task-meta">Task ${task.setup_task_id} · ${escapeHtml(task.task_action_type)}${task.active_flag ? '' : ' · inactive'}</div>
      </div>
      <div class="task-meta">${deps.length ? `Requires: ${deps.map((dep) => escapeHtml(dep.task_name)).join('; ')}` : 'No prerequisite'}</div>
      <div class="library-actions">
        ${canManage ? `<button type="button" class="small secondary next-up" ${index === 0 ? 'disabled' : ''}>↑</button>
        <button type="button" class="small secondary next-down" ${index === total - 1 ? 'disabled' : ''}>↓</button>
        <button type="button" class="small secondary next-copy">Copy</button>` : ''}
        <button type="button" class="small open-task" data-task-id="${task.setup_task_id}">Open</button>
      </div>
    </div>
  `;
}

function nextScopeMarkup(stage, scene, tasks) {
  const sceneId = scene?.lor_scene_id ?? null;
  const key = nextScopeKey(stage.stage_id, sceneId);
  const closed = setupNextState.closedScopes.has(key);
  const title = scene ? `Scene — ${scene.scene_name}` : 'Stage-level / General';
  const gap = tasks.length
    ? ''
    : `<div class="next-inline-gap">No reusable task is assigned to this ${scene ? 'Scene' : 'Stage-level area'} yet.</div>`;
  return `
    <details class="next-scope-group" data-scope-key="${escapeHtml(key)}" data-stage-id="${stage.stage_id}" data-scene-id="${sceneId ?? ''}" ${closed ? '' : 'open'}>
      <summary>${escapeHtml(title)} <span class="next-count">${tasks.length} task${tasks.length === 1 ? '' : 's'}</span></summary>
      <div class="next-scope-dropzone" data-stage-id="${stage.stage_id}" data-scene-id="${sceneId ?? ''}">
        ${gap}
        ${tasks.map((task, index) => nextTaskRow(task, stage.stage_id, sceneId, index, tasks.length)).join('')}
      </div>
    </details>
  `;
}

function renderNextLibrary() {
  const target = el('library-list');
  if (!target) return;
  const activeStageIds = new Set((appState.tasks || []).map((task) => Number(task.stage_id)).filter(Number.isFinite));
  const stages = sortedStages();
  target.innerHTML = stages.map((stage) => {
    const stageId = Number(stage.stage_id);
    const scenes = nextScenesForStage(stageId);
    const stageTasks = nextTasksForScope(stageId, null);
    const allTaskCount = stageTasks.length + scenes.reduce((sum, scene) => sum + nextTasksForScope(stageId, scene.lor_scene_id).length, 0);
    const closed = setupNextState.closedStages.has(String(stageId));
    return `
      <details class="library-stage next-stage-group" data-stage-id="${stageId}" ${closed ? '' : 'open'}>
        <summary class="library-stage-heading">
          Stage ${escapeHtml(stage.stage_key)} — ${escapeHtml(stage.stage_name || stage.folder_name || '')}
          <span class="next-count">${allTaskCount} task${allTaskCount === 1 ? '' : 's'}${scenes.length ? ` · ${scenes.length} Scene${scenes.length === 1 ? '' : 's'}` : ''}</span>
        </summary>
        <div class="next-stage-body">
          ${nextScopeMarkup(stage, null, stageTasks)}
          ${scenes.map((scene) => nextScopeMarkup(stage, scene, nextTasksForScope(stageId, scene.lor_scene_id))).join('')}
          ${!allTaskCount && !scenes.length ? '<div class="next-stage-empty">No reusable Setup work has been defined for this Stage yet.</div>' : ''}
        </div>
      </details>
    `;
  }).join('') || '<div class="empty-state">No Stages are available.</div>';

  el('stage-gap-list').innerHTML = '';
  wireNextLibrary();
}

function wireNextLibrary() {
  document.querySelectorAll('.next-stage-group').forEach((details) => {
    details.addEventListener('toggle', () => {
      const id = String(details.dataset.stageId);
      if (details.open) setupNextState.closedStages.delete(id);
      else setupNextState.closedStages.add(id);
    });
  });
  document.querySelectorAll('.next-scope-group').forEach((details) => {
    details.addEventListener('toggle', () => {
      const key = details.dataset.scopeKey;
      if (details.open) setupNextState.closedScopes.delete(key);
      else setupNextState.closedScopes.add(key);
    });
  });
  document.querySelectorAll('.open-task').forEach((button) => {
    button.addEventListener('click', () => {
      showView('review');
      selectTask(Number(button.dataset.taskId));
    });
  });
  document.querySelectorAll('.next-task-row').forEach((row) => {
    const taskId = Number(row.dataset.taskId);
    const stageId = Number(row.dataset.stageId);
    const sceneId = row.dataset.sceneId ? Number(row.dataset.sceneId) : null;
    const tasks = nextTasksForScope(stageId, sceneId);
    const index = tasks.findIndex((task) => Number(task.setup_task_id) === taskId);
    row.querySelector('.next-up')?.addEventListener('click', async () => {
      if (index <= 0) return;
      [tasks[index - 1], tasks[index]] = [tasks[index], tasks[index - 1]];
      await nextPersistOrder(tasks);
      await reloadTasks(null); await loadNextOrganization(false); renderLibrary();
    });
    row.querySelector('.next-down')?.addEventListener('click', async () => {
      if (index < 0 || index >= tasks.length - 1) return;
      [tasks[index], tasks[index + 1]] = [tasks[index + 1], tasks[index]];
      await nextPersistOrder(tasks);
      await reloadTasks(null); await loadNextOrganization(false); renderLibrary();
    });
    row.querySelector('.next-copy')?.addEventListener('click', () => openNextCopyDialog(taskId));
    row.addEventListener('dragstart', (event) => {
      setupNextState.draggedTaskId = taskId;
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', String(taskId));
      row.classList.add('dragging');
    });
    row.addEventListener('dragover', (event) => {
      event.preventDefault();
      event.dataTransfer.dropEffect = 'move';
      row.classList.add('drop-target');
    });
    row.addEventListener('dragleave', () => row.classList.remove('drop-target'));
    row.addEventListener('drop', async (event) => {
      event.preventDefault();
      row.classList.remove('drop-target');
      const sourceId = Number(event.dataTransfer.getData('text/plain') || setupNextState.draggedTaskId || 0);
      if (sourceId && sourceId !== taskId) await nextMoveTask(sourceId, stageId, sceneId, taskId);
    });
    row.addEventListener('dragend', () => {
      setupNextState.draggedTaskId = null;
      document.querySelectorAll('.next-task-row').forEach((item) => item.classList.remove('dragging', 'drop-target'));
    });
  });
  document.querySelectorAll('.next-scope-dropzone').forEach((zone) => {
    zone.addEventListener('dragover', (event) => { event.preventDefault(); zone.classList.add('drop-target'); });
    zone.addEventListener('dragleave', () => zone.classList.remove('drop-target'));
    zone.addEventListener('drop', async (event) => {
      event.preventDefault(); zone.classList.remove('drop-target');
      if (event.target.closest('.next-task-row')) return;
      const taskId = Number(event.dataTransfer.getData('text/plain') || setupNextState.draggedTaskId || 0);
      if (!taskId) return;
      await nextMoveTask(taskId, Number(zone.dataset.stageId), zone.dataset.sceneId ? Number(zone.dataset.sceneId) : null);
    });
  });
}

function installNextLibraryTools() {
  const header = document.querySelector('#library-view .section-title');
  if (!header || document.getElementById('next-collapse-all')) return;
  const actions = document.createElement('div');
  actions.className = 'next-library-tools';
  actions.innerHTML = `
    <button id="next-expand-all" type="button" class="secondary">Expand All</button>
    <button id="next-collapse-all" type="button" class="secondary">Collapse All</button>
  `;
  header.appendChild(actions);
  el('next-expand-all').addEventListener('click', () => {
    setupNextState.closedStages.clear(); setupNextState.closedScopes.clear(); renderLibrary();
  });
  el('next-collapse-all').addEventListener('click', () => {
    sortedStages().forEach((stage) => setupNextState.closedStages.add(String(stage.stage_id)));
    renderLibrary();
  });
}

function installNextCopyDialog() {
  if (el('next-copy-dialog')) return;
  const dialog = document.createElement('dialog');
  dialog.id = 'next-copy-dialog';
  dialog.className = 'next-dialog';
  dialog.innerHTML = `
    <form method="dialog" id="next-copy-form">
      <h3>Copy Reusable Task</h3>
      <p class="muted">Reusable definition and equipment/resources copy. Prerequisites and prior annual actuals do not.</p>
      <label>Task name<input id="next-copy-name" type="text" required></label>
      <label>Destination Stage<select id="next-copy-stage" required></select></label>
      <label>Destination area<select id="next-copy-scene"></select></label>
      <div class="action-row">
        <button value="cancel" type="button" class="secondary" id="next-copy-cancel">Cancel</button>
        <button value="default" type="submit">Copy Task</button>
      </div>
    </form>
  `;
  document.body.appendChild(dialog);
  el('next-copy-cancel').addEventListener('click', () => dialog.close());
  el('next-copy-stage').addEventListener('change', populateNextCopyScenes);
  el('next-copy-form').addEventListener('submit', submitNextCopy);
}

function populateNextCopyStages() {
  const select = el('next-copy-stage');
  select.innerHTML = sortedStages().map((stage) => (
    `<option value="${stage.stage_id}">${escapeHtml(stage.stage_key)} — ${escapeHtml(stage.stage_name || '')}</option>`
  )).join('');
}

function populateNextCopyScenes() {
  const stageId = Number(el('next-copy-stage').value);
  const select = el('next-copy-scene');
  select.innerHTML = `<option value="">Stage-level / General</option>${nextScenesForStage(stageId).map((scene) => (
    `<option value="${scene.lor_scene_id}">Scene — ${escapeHtml(scene.scene_name)}</option>`
  )).join('')}`;
}

function openNextCopyDialog(taskId) {
  const task = taskById(taskId);
  if (!task) return;
  setupNextState.copySourceId = taskId;
  populateNextCopyStages();
  el('next-copy-stage').value = String(task.stage_id || sortedStages()[0]?.stage_id || '');
  populateNextCopyScenes();
  el('next-copy-scene').value = task.lor_scene_id == null ? '' : String(task.lor_scene_id);
  el('next-copy-name').value = task.task_name;
  el('next-copy-dialog').showModal();
}

async function submitNextCopy(event) {
  event.preventDefault();
  const source = taskById(setupNextState.copySourceId);
  if (!source) return;
  const stageId = Number(el('next-copy-stage').value);
  const sceneId = el('next-copy-scene').value ? Number(el('next-copy-scene').value) : null;
  const name = el('next-copy-name').value.trim();
  if (!name || !stageId) return;
  try {
    setBusy(true);
    const resources = (await api(`api/setup/tasks/${source.setup_task_id}/resources`)).resources || [];
    const created = await api('api/setup/tasks', commandOptions('POST', {
      task_name: name,
      stage_id: stageId,
      task_action_type: source.task_action_type || 'WORK',
      display_order: 999,
      normal_crew_min: source.normal_crew_min,
      normal_crew_max: source.normal_crew_max,
      expected_duration_minutes: source.expected_duration_minutes,
      completion_point: source.completion_point,
      readiness_note: source.readiness_note,
      weather_note: source.weather_note,
      reusable_notes: [source.reusable_notes || '', `[Copied from reusable task ${source.setup_task_id}; verify destination-specific details.]`].filter(Boolean).join('\n')
    }));
    const newId = created.setup_task?.setup_task_id;
    if (!newId) throw new Error('Copied task did not return a new task ID.');
    await api(`api/setup/tasks/${newId}/scope`, commandOptions('PATCH', { stage_id: stageId, lor_scene_id: sceneId }));
    for (const resource of resources) {
      await api(`api/setup/tasks/${newId}/resources/${resource.setup_resource_id}`, commandOptions('PATCH', {
        quantity_required: Number(resource.quantity_required) || 1,
        requirement_type: resource.requirement_type || 'REQUIRED',
        notes: resource.notes || null,
        active_flag: true
      }));
    }
    el('next-copy-dialog').close();
    await reloadTasks(null); await loadNextOrganization(false);
    setupNextState.closedStages.delete(String(stageId));
    setupNextState.closedScopes.delete(nextScopeKey(stageId, sceneId));
    const destination = nextTasksForScope(stageId, sceneId);
    await nextPersistOrder(destination);
    await reloadTasks(null); await loadNextOrganization(false); renderLibrary();
    setAlert(`Copied task ${source.setup_task_id} to reusable task ${newId}. Its new annual occurrence is UNVERIFIED; prior annual actuals were not copied.`, 'ok');
    requestAnimationFrame(() => document.querySelector(`[data-task-id="${newId}"]`)?.scrollIntoView({ block: 'center', behavior: 'smooth' }));
  } catch (error) {
    setAlert(error.message || error, 'error'); window.alert(error.message || error);
  } finally { setBusy(false); }
}

function installDependencyEditor() {
  const section = el('detail-dependencies')?.closest('.detail-section');
  if (!section || el('next-dependency-editor')) return;
  const editor = document.createElement('div');
  editor.id = 'next-dependency-editor';
  editor.className = 'next-dependency-editor manager-only';
  editor.innerHTML = `
    <div class="eyebrow">Manager prerequisite correction</div>
    <div class="next-dependency-add">
      <select id="next-dependency-select"></select>
      <input id="next-dependency-note" type="text" placeholder="Optional prerequisite note">
      <button id="next-dependency-add-button" type="button">Add prerequisite</button>
    </div>
    <div id="next-dependency-current"></div>
  `;
  section.appendChild(editor);
  el('next-dependency-add-button').addEventListener('click', addNextDependency);
}

function renderDependencyEditor(task) {
  installDependencyEditor();
  const editor = el('next-dependency-editor');
  if (!editor) return;
  editor.hidden = !appState.access?.can_manage_setup;
  const options = sortedTasks().filter((candidate) => Number(candidate.setup_task_id) !== Number(task.setup_task_id));
  el('next-dependency-select').innerHTML = options.map((candidate) => (
    `<option value="${candidate.setup_task_id}">${escapeHtml(nextTaskLabel(candidate))}</option>`
  )).join('');
  el('next-dependency-current').innerHTML = (task.dependencies || []).length
    ? (task.dependencies || []).map((dep) => `
      <div class="next-dependency-row">
        <span>${escapeHtml(dep.task_name)}${dep.dependency_note ? ` — ${escapeHtml(dep.dependency_note)}` : ''}</span>
        <button type="button" class="small secondary next-dependency-remove" data-prereq-id="${dep.setup_task_id}">Remove</button>
      </div>`).join('')
    : '<div class="muted">No prerequisite recorded.</div>';
  el('next-dependency-current').querySelectorAll('.next-dependency-remove').forEach((button) => {
    button.addEventListener('click', () => removeNextDependency(task, Number(button.dataset.prereqId)));
  });
}

async function addNextDependency() {
  const task = taskById(appState.selectedTaskId);
  const prereq = Number(el('next-dependency-select').value || 0);
  if (!task || !prereq) return;
  try {
    await api(`api/setup/tasks/${task.setup_task_id}/dependencies/${prereq}`, commandOptions('PATCH', {
      active: true,
      dependency_note: el('next-dependency-note').value.trim() || null
    }));
    el('next-dependency-note').value = '';
    await reloadTasks(task.setup_task_id); await loadNextOrganization(false);
    setAlert('Prerequisite added.', 'ok');
  } catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); }
}

async function removeNextDependency(task, prereqId) {
  if (!window.confirm('Remove this prerequisite?')) return;
  try {
    await api(`api/setup/tasks/${task.setup_task_id}/dependencies/${prereqId}`, commandOptions('PATCH', { active: false }));
    await reloadTasks(task.setup_task_id); await loadNextOrganization(false);
    setAlert('Prerequisite removed.', 'ok');
  } catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); }
}

function installNextTabs() {
  const tabs = document.querySelector('.tabs');
  if (!tabs || el('schedule-view')) return;
  const movementButton = tabs.querySelector('[data-view="movement"]');
  const scheduleButton = document.createElement('button');
  scheduleButton.className = 'tab'; scheduleButton.dataset.view = 'schedule'; scheduleButton.type = 'button'; scheduleButton.textContent = 'Schedule';
  const performButton = document.createElement('button');
  performButton.className = 'tab'; performButton.dataset.view = 'perform'; performButton.type = 'button'; performButton.textContent = 'Perform Work';
  tabs.insertBefore(scheduleButton, movementButton);
  tabs.insertBefore(performButton, movementButton);
  scheduleButton.addEventListener('click', async () => { showView('schedule'); await loadNextSchedule(); });
  performButton.addEventListener('click', async () => { showView('perform'); await loadNextExecution(); });

  const main = document.querySelector('main');
  const schedule = document.createElement('section');
  schedule.id = 'schedule-view'; schedule.className = 'view';
  schedule.innerHTML = `
    <div class="card">
      <div class="eyebrow">Lightweight day/shift planning</div><h2>Setup Schedule</h2>
      <p class="muted">Schedule practical tasks by date and Morning / Afternoon / All Day. Multiple tasks in the same shift are parallel work, not a serial MS Project queue.</p>
      <form id="next-schedule-form" class="next-schedule-form manager-only">
        <label>Date<input id="next-schedule-date" type="date" required></label>
        <label>Shift<select id="next-schedule-shift"><option value="MORNING">Morning</option><option value="AFTERNOON">Afternoon</option><option value="ALL_DAY">All Day</option></select></label>
        <label>Task<select id="next-schedule-task"></select></label>
        <label>Planned crew<input id="next-schedule-crew" type="number" min="0"></label>
        <button type="submit">Add to Schedule</button>
      </form>
      <div id="next-schedule-list"></div>
    </div>`;
  main.appendChild(schedule);
  el('next-schedule-form').addEventListener('submit', submitNextSchedule);

  const perform = document.createElement('section');
  perform.id = 'perform-view'; perform.className = 'view';
  perform.innerHTML = `
    <div class="card">
      <div class="section-title"><div><div class="eyebrow">Captain / field execution</div><h2>Perform Setup Work</h2></div>
      <label>Status<select id="next-perform-filter"><option value="INCOMPLETE">Incomplete</option><option value="COMPLETE">Completed</option><option value="ALL">All</option></select></label></div>
      <p class="muted">This screen combines the task, current published Procedure PDF, equipment, mapped material/location context, progress, and completion. Movement/scanning writes remain a separate guarded implementation step.</p>
      <div id="next-perform-list"></div>
    </div>`;
  main.appendChild(perform);
  el('next-perform-filter').addEventListener('change', renderNextExecution);
}

async function loadNextSchedule() {
  const payload = await api(`api/setup/schedule?season_year=${encodeURIComponent(appState.seasonYear)}`);
  setupNextState.schedule = payload.schedule || { work_days: [], assignments: [] };
  el('next-schedule-task').innerHTML = sortedTasks().filter((task) => task.setup_session_task_id != null).map((task) => (
    `<option value="${task.setup_session_task_id}">${escapeHtml(nextTaskLabel(task))}</option>`
  )).join('');
  renderNextSchedule();
}

async function submitNextSchedule(event) {
  event.preventDefault();
  const date = el('next-schedule-date').value;
  const sessionTaskId = Number(el('next-schedule-task').value || 0);
  if (!date || !sessionTaskId) return;
  try {
    setBusy(true);
    const day = await api('api/setup/work-days', commandOptions('POST', {
      season_year: Number(appState.seasonYear), work_date: date, day_status: 'PLANNED'
    }));
    const dayId = day.work_day?.setup_work_day_id;
    await api(`api/setup/work-days/${dayId}/tasks/${sessionTaskId}`, commandOptions('PATCH', {
      active: true,
      shift_code: el('next-schedule-shift').value,
      sort_order: 100,
      planned_crew_count: nullableInteger(el('next-schedule-crew').value)
    }));
    await loadNextSchedule();
    setAlert('Task added to the lightweight Setup schedule.', 'ok');
  } catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); }
  finally { setBusy(false); }
}

function renderNextSchedule() {
  const target = el('next-schedule-list');
  const days = setupNextState.schedule.work_days || [];
  const assignments = setupNextState.schedule.assignments || [];
  target.innerHTML = days.length ? days.map((day) => {
    const dayItems = assignments.filter((item) => Number(item.setup_work_day_id) === Number(day.setup_work_day_id));
    const shifts = ['ALL_DAY','MORNING','AFTERNOON'];
    return `<details class="next-schedule-day" open><summary>${escapeHtml(day.work_date)} · ${escapeHtml(day.day_status)}</summary>
      ${shifts.map((shift) => {
        const items = dayItems.filter((item) => item.shift_code === shift);
        return `<div class="next-shift"><h4>${shift.replace('_',' ')}</h4>${items.length ? items.map((item) => `
          <div class="next-schedule-item"><span><strong>${escapeHtml(item.task_name)}</strong> · ${escapeHtml(item.stage_key || '—')}${item.scene_name ? ` / ${escapeHtml(item.scene_name)}` : ''} · Crew ${item.planned_crew_count ?? 'TBD'}</span>
          ${appState.access?.can_manage_setup ? `<button type="button" class="small secondary next-unschedule" data-day="${day.setup_work_day_id}" data-task="${item.setup_session_task_id}">Remove</button>` : ''}</div>`).join('') : '<div class="muted">No tasks scheduled.</div>'}</div>`;
      }).join('')}</details>`;
  }).join('') : '<div class="empty-state">No work days have been scheduled yet.</div>';
  target.querySelectorAll('.next-unschedule').forEach((button) => button.addEventListener('click', async () => {
    await api(`api/setup/work-days/${button.dataset.day}/tasks/${button.dataset.task}`, commandOptions('PATCH', { active: false, shift_code: 'ALL_DAY', sort_order: 100 }));
    await loadNextSchedule();
  }));
}

async function loadNextExecution() {
  const payload = await api(`api/setup/execution?season_year=${encodeURIComponent(appState.seasonYear)}`);
  setupNextState.executionTasks = payload.tasks || [];
  renderNextExecution();
}

function renderNextExecution() {
  const filter = el('next-perform-filter')?.value || 'INCOMPLETE';
  let tasks = setupNextState.executionTasks || [];
  if (filter === 'INCOMPLETE') tasks = tasks.filter((task) => task.execution_status !== 'COMPLETE');
  if (filter === 'COMPLETE') tasks = tasks.filter((task) => task.execution_status === 'COMPLETE');
  el('next-perform-list').innerHTML = tasks.map((task) => `
    <details class="next-perform-task" data-session-task-id="${task.setup_session_task_id}" data-task-id="${task.setup_task_id}">
      <summary><span><strong>${escapeHtml(task.task_name)}</strong><span class="muted"> · Stage ${escapeHtml(task.stage_key || '—')}${task.scene_name ? ` / ${escapeHtml(task.scene_name)}` : ' / Stage-level'}</span></span>
      <span class="pill ${task.execution_status === 'COMPLETE' ? 'verified' : task.prerequisites_complete ? 'unverified' : 'correction'}">${escapeHtml(task.execution_status)}</span></summary>
      <div class="next-perform-body"><div class="muted">Open to load Procedure, material locations, resources, and progress.</div></div>
    </details>`).join('') || '<div class="empty-state">No tasks match this filter.</div>';
  document.querySelectorAll('.next-perform-task').forEach((details) => {
    details.addEventListener('toggle', () => { if (details.open && !details.dataset.loaded) loadNextTaskExecution(details); });
  });
}

function nextLocationText(item) {
  if (item.current_stage_key) return `Stage ${item.current_stage_key}${item.current_stage_name ? ` — ${item.current_stage_name}` : ''}${item.current_location_note ? ` · ${item.current_location_note}` : ''}`;
  if (item.current_location_note) return item.current_location_note;
  if (item.home_location_code) return `Home storage ${item.home_location_code}`;
  return 'Location not yet recorded';
}

async function loadNextTaskExecution(details) {
  const taskId = Number(details.dataset.taskId);
  const sessionTaskId = Number(details.dataset.sessionTaskId);
  const task = setupNextState.executionTasks.find((item) => Number(item.setup_session_task_id) === sessionTaskId);
  const body = details.querySelector('.next-perform-body');
  body.innerHTML = '<div class="muted">Loading task field context…</div>';
  try {
    const [contextPayload, resourcePayload, progressPayload, procedurePayload] = await Promise.all([
      api(`api/setup/tasks/${taskId}/field-context?season_year=${encodeURIComponent(appState.seasonYear)}`),
      api(`api/setup/tasks/${taskId}/resources`),
      api(`api/setup/session-tasks/${sessionTaskId}/progress`),
      task.stage_key ? api(`api/setup/procedure?stage_key=${encodeURIComponent(task.stage_key)}`) : Promise.resolve({ instructions: {} })
    ]);
    const context = contextPayload.context || {};
    const resources = resourcePayload.resources || [];
    const progress = progressPayload.progress || [];
    const docs = procedurePayload.instructions?.current_documents || [];
    const assets = [
      ...(context.displays || []).map((item) => `<li>Display ${item.display_id} — ${escapeHtml(item.display_name)}${item.container_id ? ` · Container ${item.container_id}` : ''} · <strong>${escapeHtml(nextLocationText(item))}</strong></li>`),
      ...(context.support_containers || []).map((item) => `<li>Support Container ${item.container_id} · <strong>${escapeHtml(nextLocationText(item))}</strong></li>`)
    ];
    body.innerHTML = `
      <div class="next-perform-grid">
        <section><h4>Task</h4><p>${escapeHtml(task.completion_point || 'Completion point not yet documented.')}</p>
          ${task.readiness_note ? `<p><strong>Readiness:</strong> ${escapeHtml(task.readiness_note)}</p>` : ''}
          ${task.weather_note ? `<p><strong>Weather:</strong> ${escapeHtml(task.weather_note)}</p>` : ''}
          <p><strong>Expected crew:</strong> ${escapeHtml(formatCrew(task))} · <strong>Expected time:</strong> ${escapeHtml(formatMinutes(task.expected_duration_minutes))}</p>
          <p><strong>Prerequisites:</strong> ${task.prerequisites_complete ? 'Complete / no blockers' : 'Not complete'}</p></section>
        <section><h4>Equipment / Resources</h4>${resources.length ? `<ul>${resources.map((r) => `<li>${escapeHtml(r.resource_name)} · Qty ${r.quantity_required} · ${escapeHtml(r.requirement_type)}</li>`).join('')}</ul>` : '<p class="muted">No structured resource requirement recorded.</p>'}</section>
        <section><h4>Material / Current Location</h4>${assets.length ? `<ul>${assets.join('')}</ul>` : '<p class="muted">No Displays or support Containers are mapped to this reusable task yet.</p>'}</section>
        <section><h4>Published Setup Procedure</h4>${docs.length ? docs.map((doc) => `<p><a target="_blank" rel="noopener" href="api/setup/procedure/current?stage_key=${encodeURIComponent(task.stage_key)}&name=${encodeURIComponent(doc.name || '')}">${escapeHtml(doc.name || 'Open current PDF')}</a></p>`).join('') : '<p class="muted">No published Setup PDF resolved for this task scope.</p>'}</section>
      </div>
      <section class="next-progress-history"><h4>Progress history</h4>${progress.length ? progress.map((p) => `<div>${escapeHtml(formatTimestamp(p.recorded_at))} · Crew ${p.crew_count}${p.completed_quantity ? ` · ${p.completed_quantity} completed` : ''}${p.completed_units ? ` · ${escapeHtml(p.completed_units)}` : ''}${p.progress_note ? ` · ${escapeHtml(p.progress_note)}` : ''}${p.marks_task_complete ? ' · COMPLETE' : ''}</div>`).join('') : '<div class="muted">No progress recorded yet.</div>'}</section>
      ${task.execution_status === 'COMPLETE' ? `<div class="next-complete-banner">Completed ${escapeHtml(formatTimestamp(task.actual_completed_at))}${task.completed_by_name ? ` by ${escapeHtml(task.completed_by_name)}` : ''}${task.completion_note ? ` · ${escapeHtml(task.completion_note)}` : ''}</div>` : `
      <form class="next-completion-form" data-session-task-id="${sessionTaskId}">
        <label>Crew size<input class="next-crew" type="number" min="1" required></label>
        <label>Completed quantity <span class="muted">(optional, e.g. 3 trees)</span><input class="next-quantity" type="number" min="1"></label>
        <label>Which units / what was completed <span class="muted">(optional)</span><input class="next-units" type="text" placeholder="Example: Trees 1, 3, 4"></label>
        <label>Progress / completion note <span class="muted">(optional)</span><textarea class="next-note" rows="2"></textarea></label>
        <label class="checkbox-label"><input class="next-mark-complete" type="checkbox"> Entire task complete</label>
        <button type="submit">Save Progress / Completion</button>
      </form>`}
    `;
    details.dataset.loaded = '1';
    body.querySelector('.next-completion-form')?.addEventListener('submit', submitNextProgress);
  } catch (error) {
    body.innerHTML = `<strong>Task field context could not be loaded.</strong><div class="muted">${escapeHtml(error.message || error)}</div>`;
  }
}

async function submitNextProgress(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const sessionTaskId = Number(form.dataset.sessionTaskId);
  const crew = Number(form.querySelector('.next-crew').value || 0);
  if (crew < 1) return;
  try {
    await api(`api/setup/session-tasks/${sessionTaskId}/progress`, commandOptions('POST', {
      shift_code: 'ALL_DAY',
      crew_count: crew,
      completed_quantity: nullableInteger(form.querySelector('.next-quantity').value),
      completed_units: form.querySelector('.next-units').value.trim() || null,
      progress_note: form.querySelector('.next-note').value.trim() || null,
      mark_complete: form.querySelector('.next-mark-complete').checked
    }));
    setAlert(form.querySelector('.next-mark-complete').checked ? 'Task marked complete.' : 'Task progress recorded.', 'ok');
    await loadNextExecution();
  } catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); }
}

const priorNextRenderLibrary = renderLibrary;
renderLibrary = function renderLibraryNextPass() {
  applyNextTaskScopes();
  if (!setupNextState.scenes.length) return priorNextRenderLibrary();
  renderNextLibrary();
  installNextLibraryTools();
};

const priorNextSelectTask = selectTask;
selectTask = function selectTaskNextPass(taskId) {
  priorNextSelectTask(taskId);
  const task = taskById(taskId);
  if (task) {
    const scope = task.scene_name ? `Scene ${task.scene_name}` : 'Stage-level / General';
    el('detail-stage').textContent = `Stage ${task.stage_key || '—'} — ${task.stage_name || 'General'} · ${scope}`;
    renderDependencyEditor(task);
  }
};

const priorNextReloadTasks = reloadTasks;
reloadTasks = async function reloadTasksNextPass(selectTaskId = null) {
  await priorNextReloadTasks(selectTaskId);
  applyNextTaskScopes();
  if (setupNextState.scenes.length) renderLibrary();
};

async function initializeNextPass() {
  installNextCopyDialog();
  installDependencyEditor();
  installNextTabs();
  try {
    await loadNextOrganization(false);
    if (appState.tasks?.length) renderLibrary();
  } catch (error) {
    console.warn('Setup next-pass organization is not ready:', error);
  }
  const help = el('help-view');
  if (help) {
    const intro = help.querySelector('p');
    if (intro) intro.textContent = 'This review now includes Stage/Scene organization, prerequisite maintenance, lightweight day/shift scheduling, and Captain field execution. Container/Display movement writes remain the next guarded integration step.';
  }
}

initializeNextPass();
