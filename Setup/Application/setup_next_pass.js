/* Setup V0.3 browser-review UI: Site-wide/Stage/Scene organization, ordered backlog, crew lanes, and Captain execution. */

const setupNextState = {
  scenes: [],
  taskScopes: new Map(),
  closedStages: new Set(),
  closedScopes: new Set(),
  draggedTaskId: null,
  draggedPlanningSessionTaskId: null,
  copySourceId: null,
  schedule: { work_days: [], assignments: [] },
  executionTasks: [],
  performBoard: { session: null, work_days: [], crews: [], tasks: [], assignments: [] },
  performAssignmentMode: true,
  performCaptainFilter: null
};

function nextIsSitewide(task) {
  return task?.stage_id == null;
}

function nextScopeKey(stageId, sceneId) {
  if (stageId == null) return 'site-wide';
  return `${stageId}:${sceneId ?? 'stage'}`;
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
    task.baseline_plan_order = scope.baseline_plan_order ?? task.baseline_plan_order;
    if (scope.stage_id != null) {
      const stage = appState.stages.find((item) => Number(item.stage_id) === Number(scope.stage_id));
      if (stage) {
        task.stage_key = stage.stage_key;
        task.stage_name = stage.stage_name;
      }
    } else {
      task.stage_key = null;
      task.stage_name = null;
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
  return (appState.tasks || [])
    .filter((task) => {
      if (stageId == null) return nextIsSitewide(task);
      return Number(task.stage_id) === Number(stageId)
        && (sceneId == null ? task.lor_scene_id == null : Number(task.lor_scene_id) === Number(sceneId));
    })
    .sort((a, b) => {
      if (Number(a.display_order) !== Number(b.display_order)) return Number(a.display_order) - Number(b.display_order);
      return Number(a.setup_task_id) - Number(b.setup_task_id);
    });
}

function nextTaskLabel(task) {
  if (nextIsSitewide(task)) return `Site-wide / Infrastructure — ${task.task_name}`;
  const stage = `Stage ${task.stage_key || '—'}`;
  const scope = task.scene_name ? ` / ${task.scene_name}` : ' / Stage-level';
  return `${stage}${scope} — ${task.task_name}`;
}

function nextTaskScopeLabel(task) {
  if (nextIsSitewide(task)) return 'Site-wide / Infrastructure';
  return `Stage ${task.stage_key || '—'}${task.scene_name ? ` / ${task.scene_name}` : ' / Stage-level'}`;
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
  const normalizedStageId = stageId == null ? null : Number(stageId);
  const normalizedSceneId = normalizedStageId == null || sceneId == null ? null : Number(sceneId);
  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${taskId}/scope`,
      commandOptions('PATCH', {
        stage_id: normalizedStageId,
        lor_scene_id: normalizedSceneId
      })
    );
    await reloadTasks(null);
    await loadNextOrganization(false);
    const destination = nextTasksForScope(normalizedStageId, normalizedSceneId);
    const sourceIndex = destination.findIndex((item) => Number(item.setup_task_id) === Number(taskId));
    if (sourceIndex >= 0) destination.splice(sourceIndex, 1);
    const movedTask = taskById(taskId);
    if (beforeTaskId != null) {
      const targetIndex = destination.findIndex((item) => Number(item.setup_task_id) === Number(beforeTaskId));
      destination.splice(targetIndex < 0 ? destination.length : targetIndex, 0, movedTask);
    } else {
      destination.push(movedTask);
    }
    await nextPersistOrder(destination.filter(Boolean));
    await reloadTasks(null);
    await loadNextOrganization(false);
    setupNextState.closedStages.delete(normalizedStageId == null ? 'site-wide' : String(normalizedStageId));
    setupNextState.closedScopes.delete(nextScopeKey(normalizedStageId, normalizedSceneId));
    renderLibrary();
    const moved = taskById(taskId);
    setAlert(`Task moved to ${nextTaskScopeLabel(moved)}.`, 'ok');
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
         data-task-id="${task.setup_task_id}" data-stage-id="${stageId ?? ''}" data-scene-id="${sceneId ?? ''}">
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

function nextSitewideMarkup(tasks) {
  const closed = setupNextState.closedStages.has('site-wide');
  return `
    <details class="library-stage next-stage-group next-sitewide-group" data-stage-id="" ${closed ? '' : 'open'}>
      <summary class="library-stage-heading">
        Site-wide / Infrastructure
        <span class="next-count">${tasks.length} task${tasks.length === 1 ? '' : 's'} · no LOR Stage/Scene</span>
      </summary>
      <div class="next-stage-body">
        <div class="next-sitewide-note">Critical Setup work that does not belong to an LOR Stage or Scene. These tasks use the controlled Site Infrastructure Procedure root.</div>
        <div class="next-scope-dropzone" data-stage-id="" data-scene-id="">
          ${tasks.length ? '' : '<div class="next-inline-gap">No Site-wide / Infrastructure reusable task has been defined yet.</div>'}
          ${tasks.map((task, index) => nextTaskRow(task, null, null, index, tasks.length)).join('')}
        </div>
      </div>
    </details>`;
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
  const stages = sortedStages();
  const sitewide = nextTasksForScope(null, null);
  target.innerHTML = nextSitewideMarkup(sitewide) + stages.map((stage) => {
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
  }).join('');

  el('stage-gap-list').innerHTML = '';
  wireNextLibrary();
}

function nextDatasetStage(value) {
  return String(value || '').trim() ? Number(value) : null;
}

function wireNextLibrary() {
  document.querySelectorAll('.next-stage-group').forEach((details) => {
    details.addEventListener('toggle', () => {
      const id = details.dataset.stageId ? String(details.dataset.stageId) : 'site-wide';
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
    const stageId = nextDatasetStage(row.dataset.stageId);
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
      await nextMoveTask(taskId, nextDatasetStage(zone.dataset.stageId), zone.dataset.sceneId ? Number(zone.dataset.sceneId) : null);
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
    setupNextState.closedStages.add('site-wide');
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
      <label>Destination<select id="next-copy-stage"></select></label>
      <label>Stage area<select id="next-copy-scene"></select></label>
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
  select.innerHTML = `<option value="__SITE_WIDE__">Site-wide / Infrastructure</option>${sortedStages().map((stage) => (
    `<option value="${stage.stage_id}">Stage ${escapeHtml(stage.stage_key)} — ${escapeHtml(stage.stage_name || '')}</option>`
  )).join('')}`;
}

function populateNextCopyScenes() {
  const value = el('next-copy-stage').value;
  const select = el('next-copy-scene');
  if (value === '__SITE_WIDE__') {
    select.innerHTML = '<option value="">No LOR Stage/Scene</option>';
    select.disabled = true;
    return;
  }
  select.disabled = false;
  const stageId = Number(value);
  select.innerHTML = `<option value="">Stage-level / General</option>${nextScenesForStage(stageId).map((scene) => (
    `<option value="${scene.lor_scene_id}">Scene — ${escapeHtml(scene.scene_name)}</option>`
  )).join('')}`;
}

function openNextCopyDialog(taskId) {
  const task = taskById(taskId);
  if (!task) return;
  setupNextState.copySourceId = taskId;
  populateNextCopyStages();
  el('next-copy-stage').value = nextIsSitewide(task) ? '__SITE_WIDE__' : String(task.stage_id);
  populateNextCopyScenes();
  if (!nextIsSitewide(task)) el('next-copy-scene').value = task.lor_scene_id == null ? '' : String(task.lor_scene_id);
  el('next-copy-name').value = task.task_name;
  el('next-copy-dialog').showModal();
}

async function submitNextCopy(event) {
  event.preventDefault();
  const source = taskById(setupNextState.copySourceId);
  if (!source) return;
  const destinationValue = el('next-copy-stage').value;
  const stageId = destinationValue === '__SITE_WIDE__' ? null : Number(destinationValue);
  const sceneId = stageId == null || !el('next-copy-scene').value ? null : Number(el('next-copy-scene').value);
  const name = el('next-copy-name').value.trim();
  if (!name) return;
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
    setupNextState.closedStages.delete(stageId == null ? 'site-wide' : String(stageId));
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

function nextPlanningCategory(task) {
  if (task.execution_status === 'COMPLETE') return 'COMPLETED';
  if (task.execution_status === 'IN_PROGRESS') return 'IN_PROGRESS';
  if (Number(task.scheduled_count || 0) > 0) return 'SCHEDULED';
  return 'UNSCHEDULED';
}

function nextPlanningOrder(tasks = setupNextState.executionTasks) {
  return [...(tasks || [])].sort((a, b) => {
    const ao = a.planned_order == null ? 999999 : Number(a.planned_order);
    const bo = b.planned_order == null ? 999999 : Number(b.planned_order);
    if (ao !== bo) return ao - bo;
    const ab = a.baseline_plan_order == null ? 999999 : Number(a.baseline_plan_order);
    const bb = b.baseline_plan_order == null ? 999999 : Number(b.baseline_plan_order);
    if (ab !== bb) return ab - bb;
    return Number(a.setup_session_task_id) - Number(b.setup_session_task_id);
  });
}

function nextPlanningFilterEnabled(category) {
  const checkbox = document.querySelector(`[data-plan-filter="${category}"]`);
  return checkbox ? checkbox.checked : category !== 'COMPLETED';
}

async function persistAnnualPlanningOrder(tasks) {
  for (let i = 0; i < tasks.length; i += 1) {
    const desired = (i + 1) * 10;
    const task = tasks[i];
    if (Number(task.planned_order) === desired) continue;
    await api(`api/setup/session-tasks/${task.setup_session_task_id}/planned-order`, commandOptions('PATCH', {
      planned_order: desired
    }));
    task.planned_order = desired;
  }
}

async function moveAnnualPlanningTask(sourceSessionTaskId, targetSessionTaskId, after = false) {
  const tasks = nextPlanningOrder();
  const sourceIndex = tasks.findIndex((task) => Number(task.setup_session_task_id) === Number(sourceSessionTaskId));
  const targetIndexOriginal = tasks.findIndex((task) => Number(task.setup_session_task_id) === Number(targetSessionTaskId));
  if (sourceIndex < 0 || targetIndexOriginal < 0 || sourceIndex === targetIndexOriginal) return;
  const [source] = tasks.splice(sourceIndex, 1);
  let targetIndex = tasks.findIndex((task) => Number(task.setup_session_task_id) === Number(targetSessionTaskId));
  if (after) targetIndex += 1;
  tasks.splice(targetIndex, 0, source);
  try {
    setBusy(true);
    await persistAnnualPlanningOrder(tasks);
    await loadNextSchedule();
    setAlert('Annual Setup planned order updated.', 'ok');
  } catch (error) {
    setAlert(error.message || error, 'error'); window.alert(error.message || error);
  } finally { setBusy(false); }
}

function renderPlanningBacklog() {
  const target = el('next-planning-backlog');
  if (!target) return;
  const full = nextPlanningOrder();
  const visible = full.filter((task) => nextPlanningFilterEnabled(nextPlanningCategory(task)));
  target.innerHTML = visible.length ? visible.map((task, index) => {
    const category = nextPlanningCategory(task);
    const blocked = !task.prerequisites_complete || task.execution_status === 'NOT_READY';
    return `
      <div class="next-plan-row" draggable="${appState.access?.can_manage_setup ? 'true' : 'false'}" data-session-task-id="${task.setup_session_task_id}">
        <div class="next-plan-order">${escapeHtml(task.planned_order ?? '—')}</div>
        <div class="next-plan-main"><strong>${escapeHtml(task.task_name)}</strong><div class="muted">${escapeHtml(nextTaskScopeLabel(task))}</div></div>
        <div class="next-plan-state"><span class="pill ${category === 'COMPLETED' ? 'verified' : blocked ? 'correction' : 'unverified'}">${escapeHtml(category.replace('_',' '))}</span>${blocked ? '<span class="next-blocked">Blocked / Not Ready</span>' : ''}</div>
        <div class="next-plan-meta">Baseline ${escapeHtml(task.baseline_plan_order ?? '—')}${task.plan_change_reason ? `<br>${escapeHtml(task.plan_change_reason)}` : ''}</div>
        ${appState.access?.can_manage_setup ? `<div class="next-plan-actions"><button type="button" class="small secondary next-plan-up" ${index === 0 ? 'disabled' : ''}>↑</button><button type="button" class="small secondary next-plan-down" ${index === visible.length - 1 ? 'disabled' : ''}>↓</button></div>` : ''}
      </div>`;
  }).join('') : '<div class="empty-state">No annual tasks match the selected planning filters.</div>';

  const rows = [...target.querySelectorAll('.next-plan-row')];
  rows.forEach((row, index) => {
    const sourceId = Number(row.dataset.sessionTaskId);
    row.querySelector('.next-plan-up')?.addEventListener('click', () => {
      if (index > 0) moveAnnualPlanningTask(sourceId, Number(rows[index - 1].dataset.sessionTaskId), false);
    });
    row.querySelector('.next-plan-down')?.addEventListener('click', () => {
      if (index < rows.length - 1) moveAnnualPlanningTask(sourceId, Number(rows[index + 1].dataset.sessionTaskId), true);
    });
    row.addEventListener('dragstart', (event) => {
      setupNextState.draggedPlanningSessionTaskId = sourceId;
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', String(sourceId));
      row.classList.add('dragging');
    });
    row.addEventListener('dragover', (event) => { event.preventDefault(); row.classList.add('drop-target'); });
    row.addEventListener('dragleave', () => row.classList.remove('drop-target'));
    row.addEventListener('drop', (event) => {
      event.preventDefault(); row.classList.remove('drop-target');
      const dragged = Number(event.dataTransfer.getData('text/plain') || setupNextState.draggedPlanningSessionTaskId || 0);
      if (dragged && dragged !== sourceId) moveAnnualPlanningTask(dragged, sourceId, false);
    });
    row.addEventListener('dragend', () => {
      setupNextState.draggedPlanningSessionTaskId = null;
      rows.forEach((item) => item.classList.remove('dragging', 'drop-target'));
    });
  });
}

function installNextTabs() {
  const tabs = document.querySelector('.tabs');
  if (!tabs || el('schedule-view')) return;
  const movementButton = tabs.querySelector('[data-view="movement"]');
  const scheduleButton = document.createElement('button');
  scheduleButton.className = 'tab'; scheduleButton.dataset.view = 'schedule'; scheduleButton.type = 'button'; scheduleButton.textContent = 'Plan / Schedule';
  const performButton = document.createElement('button');
  performButton.className = 'tab'; performButton.dataset.view = 'perform'; performButton.type = 'button'; performButton.textContent = 'Perform Work';
  tabs.insertBefore(scheduleButton, movementButton);
  tabs.insertBefore(performButton, movementButton);
  scheduleButton.addEventListener('click', async () => {
    if (typeof navigateSetupView === 'function') await navigateSetupView('schedule');
    else { showView('schedule'); await loadNextSchedule(); }
  });
  performButton.addEventListener('click', async () => {
    if (typeof navigateSetupView === 'function') await navigateSetupView('perform');
    else { showView('perform'); await loadNextExecution(); }
  });

  const main = document.querySelector('main');
  const schedule = document.createElement('section');
  schedule.id = 'schedule-view'; schedule.className = 'view';
  schedule.innerHTML = `
    <div class="card">
      <div class="section-title"><div><div class="eyebrow">Ordered backlog first; dates only when useful</div><h2>Setup Planning Queue</h2></div>
      <button id="next-promote-baseline" type="button" class="secondary manager-only">Use Current Order as Future Baseline</button></div>
      <p class="muted">The whole annual backlog stays ordered even when most work is intentionally unscheduled. Reorder this list as constraints change; only schedule the next practical few days.</p>
      <div class="next-plan-filters" id="next-plan-filters">
        <label><input type="checkbox" data-plan-filter="UNSCHEDULED" checked> Unscheduled</label>
        <label><input type="checkbox" data-plan-filter="SCHEDULED" checked> Scheduled</label>
        <label><input type="checkbox" data-plan-filter="IN_PROGRESS" checked> In Progress</label>
        <label><input type="checkbox" data-plan-filter="COMPLETED"> Completed</label>
      </div>
      <div id="next-planning-backlog" class="next-planning-backlog"></div>
    </div>
    <div class="card next-near-term-card">
      <div class="eyebrow">Rolling-horizon dispatch</div><h2>Next Work Days</h2>
      <p class="muted">Assign only the near-term work you actually know. Crew lanes represent parallel groups, not individual volunteer rosters.</p>
      <form id="next-schedule-form" class="next-schedule-form manager-only">
        <label>Date<input id="next-schedule-date" type="date" required></label>
        <label>Shift<select id="next-schedule-shift"><option value="MORNING">Morning</option><option value="AFTERNOON">Afternoon</option><option value="ALL_DAY">All Day</option></select></label>
        <label>Crew lane<select id="next-schedule-lane"><option value="A">Crew A</option><option value="B">Crew B</option><option value="C">Crew C</option></select></label>
        <label>Task<select id="next-schedule-task"></select></label>
        <label>Planned crew<input id="next-schedule-crew" type="number" min="0"></label>
        <button type="submit">Add to Work Day</button>
      </form>
      <div id="next-schedule-list"></div>
    </div>`;
  main.appendChild(schedule);
  el('next-schedule-form').addEventListener('submit', submitNextSchedule);
  el('next-plan-filters').querySelectorAll('input').forEach((input) => input.addEventListener('change', renderPlanningBacklog));
  el('next-promote-baseline').addEventListener('click', promoteNextBaseline);

  const perform = document.createElement('section');
  perform.id = 'perform-view'; perform.className = 'view';
  perform.innerHTML = `
    <div class="card">
      <div class="section-title"><div><div class="eyebrow">Captain / field execution</div><h2>Perform Setup Work</h2></div></div>
      <p class="muted">Only scheduled work appears here. Work is organized by Setup Day, AM/PM, and Crew/Captain. Report Work records actual crew, elapsed time, and percent complete against the exact scheduled assignment.</p>
      <div class="next-perform-toolbar">
        <label>Captain
          <select id="next-perform-captain-filter" aria-label="Filter Perform Work by Captain"></select>
        </label>
        <span id="next-perform-filter-summary" class="muted"></span>
      </div>
      <div id="next-perform-list"></div>
    </div>`;
  main.appendChild(perform);
}

async function promoteNextBaseline() {
  if (!appState.access?.can_manage_setup) return;
  if (!window.confirm(`Use the current ${appState.seasonYear} annual planned order as the reusable starting baseline for future Setup seasons?\n\nDo this only when the order reflects a generally useful pattern, not a one-year constraint such as road construction.`)) return;
  try {
    setBusy(true);
    const payload = await api('api/setup/planning/promote-baseline', commandOptions('POST', { season_year: Number(appState.seasonYear) }));
    await reloadTasks(null);
    await loadNextSchedule();
    setAlert(`${payload.baseline?.updated_task_count ?? 0} reusable task baseline orders updated.`, 'ok');
  } catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); }
  finally { setBusy(false); }
}

async function loadNextSchedule() {
  const [schedulePayload, executionPayload] = await Promise.all([
    api(`api/setup/schedule?season_year=${encodeURIComponent(appState.seasonYear)}`),
    api(`api/setup/execution?season_year=${encodeURIComponent(appState.seasonYear)}`)
  ]);
  setupNextState.schedule = schedulePayload.schedule || { work_days: [], assignments: [] };
  setupNextState.executionTasks = executionPayload.tasks || [];
  const selectable = nextPlanningOrder().filter((task) => task.execution_status !== 'COMPLETE');
  el('next-schedule-task').innerHTML = selectable.map((task) => (
    `<option value="${task.setup_session_task_id}">${escapeHtml(task.planned_order ?? '—')} — ${escapeHtml(nextTaskLabel(task))}</option>`
  )).join('');
  renderPlanningBacklog();
  renderNextSchedule();
}

async function submitNextSchedule(event) {
  event.preventDefault();
  const date = el('next-schedule-date').value;
  const sessionTaskId = Number(el('next-schedule-task').value || 0);
  if (!date || !sessionTaskId) return;
  const task = setupNextState.executionTasks.find((item) => Number(item.setup_session_task_id) === sessionTaskId);
  try {
    setBusy(true);
    const day = await api('api/setup/work-days', commandOptions('POST', {
      season_year: Number(appState.seasonYear), work_date: date, day_status: 'PLANNED'
    }));
    const dayId = day.work_day?.setup_work_day_id;
    await api(`api/setup/work-days/${dayId}/tasks/${sessionTaskId}`, commandOptions('PATCH', {
      active: true,
      shift_code: el('next-schedule-shift').value,
      crew_lane: el('next-schedule-lane').value,
      sort_order: Number(task?.planned_order) || 100,
      planned_crew_count: nullableInteger(el('next-schedule-crew').value)
    }));
    await loadNextSchedule();
    setAlert('Task added to the near-term Setup work day.', 'ok');
  } catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); }
  finally { setBusy(false); }
}

function renderCrewLanes(items) {
  if (!items.length) return '<div class="muted">No tasks scheduled.</div>';
  const lanes = [...new Set(items.map((item) => String(item.crew_lane || 'A').toUpperCase()))].sort();
  return `<div class="next-crew-grid">${lanes.map((lane) => {
    const laneItems = items.filter((item) => String(item.crew_lane || 'A').toUpperCase() === lane);
    return `<section class="next-crew-lane"><h5>Crew ${escapeHtml(lane)}</h5>${laneItems.map((item) => `
      <div class="next-schedule-item"><span><strong>${escapeHtml(item.task_name)}</strong><br><span class="muted">${escapeHtml(nextTaskScopeLabel(item))} · Planned crew ${item.planned_crew_count ?? 'TBD'}</span></span>
      ${appState.access?.can_manage_setup ? `<button type="button" class="small secondary next-unschedule" data-day="${item.setup_work_day_id}" data-task="${item.setup_session_task_id}">Remove</button>` : ''}</div>`).join('')}</section>`;
  }).join('')}</div>`;
}

function renderNextSchedule() {
  const target = el('next-schedule-list');
  const days = setupNextState.schedule.work_days || [];
  const assignments = setupNextState.schedule.assignments || [];
  target.innerHTML = days.length ? days.map((day) => {
    const dayItems = assignments.filter((item) => Number(item.setup_work_day_id) === Number(day.setup_work_day_id));
    const shifts = ['MORNING','AFTERNOON','ALL_DAY'];
    return `<details class="next-schedule-day" open><summary>${escapeHtml(day.work_date)} · ${escapeHtml(day.day_status)}</summary>
      ${shifts.map((shift) => `<div class="next-shift"><h4>${shift.replace('_',' ')}</h4>${renderCrewLanes(dayItems.filter((item) => item.shift_code === shift))}</div>`).join('')}</details>`;
  }).join('') : '<div class="empty-state">No work days have been scheduled yet. That is a normal state until you are ready to commit the next few days.</div>';
  target.querySelectorAll('.next-unschedule').forEach((button) => button.addEventListener('click', async () => {
    await api(`api/setup/work-days/${button.dataset.day}/tasks/${button.dataset.task}`, commandOptions('PATCH', {
      active: false, shift_code: 'ALL_DAY', crew_lane: 'A', sort_order: 100
    }));
    await loadNextSchedule();
  }));
}


async function loadNextExecution() {
  const [executionPayload, boardPayload] = await Promise.all([
    api(`api/setup/execution?season_year=${encodeURIComponent(appState.seasonYear)}`),
    api(`api/setup/scheduling-board?season_year=${encodeURIComponent(appState.seasonYear)}`)
  ]);
  setupNextState.executionTasks = executionPayload.tasks || [];
  setupNextState.performBoard = boardPayload.board || { session: null, work_days: [], crews: [], tasks: [], assignments: [] };
  renderNextExecution();
}

function nextPerformTask(sessionTaskId) {
  return (setupNextState.performBoard.tasks || []).find(
    (task) => Number(task.setup_session_task_id) === Number(sessionTaskId)
  ) || setupNextState.executionTasks.find(
    (task) => Number(task.setup_session_task_id) === Number(sessionTaskId)
  ) || null;
}

function nextPerformCrew(assignment) {
  return (setupNextState.performBoard.crews || []).find(
    (crew) => Number(crew.setup_work_day_crew_id) === Number(assignment.setup_work_day_crew_id)
  ) || null;
}

function nextPerformDay(dayId) {
  return (setupNextState.performBoard.work_days || []).find(
    (day) => Number(day.setup_work_day_id) === Number(dayId)
  ) || null;
}

function nextEnsurePerformToolbar() {
  const list = el('next-perform-list');
  if (!list) return null;

  let toolbar = list.previousElementSibling;
  if (!toolbar?.classList?.contains('next-perform-toolbar')) {
    toolbar = document.createElement('div');
    toolbar.className = 'next-perform-toolbar';
    toolbar.innerHTML = `
      <label>Captain
        <select id="next-perform-captain-filter" aria-label="Filter Perform Work by Captain"></select>
      </label>
      <span id="next-perform-filter-summary" class="muted"></span>
    `;
    list.insertAdjacentElement('beforebegin', toolbar);
  }
  return toolbar;
}

function nextPerformScheduledCaptains() {
  const board = setupNextState.performBoard || {};
  const assignmentCrewIds = new Set(
    (board.assignments || []).map((assignment) => Number(assignment.setup_work_day_crew_id))
  );
  const candidateById = new Map(
    (board.captain_candidates || []).map((candidate) => [Number(candidate.person_id), candidate])
  );
  const rows = new Map();

  for (const crew of board.crews || []) {
    const crewId = Number(crew.setup_work_day_crew_id);
    const personId = Number(crew.captain_person_id);
    if (!assignmentCrewIds.has(crewId) || !personId) continue;
    const candidate = candidateById.get(personId) || {};
    if (!rows.has(personId)) {
      rows.set(personId, {
        person_id: personId,
        display_name: candidate.display_name || crew.captain_display_name || `Captain ${personId}`,
        email: candidate.email || null
      });
    }
  }

  return [...rows.values()].sort((a, b) =>
    String(a.display_name || '').localeCompare(String(b.display_name || ''), undefined, { sensitivity: 'base' })
    || Number(a.person_id) - Number(b.person_id)
  );
}

function nextPerformDefaultCaptainFilter() {
  const email = String(appState.access?.authenticated_email || '').trim().toLowerCase();
  if (!email) return 'ALL';
  const mine = nextPerformScheduledCaptains().find(
    (captain) => String(captain.email || '').trim().toLowerCase() === email
  );
  return mine ? `CAPTAIN:${mine.person_id}` : 'ALL';
}

function nextEnsurePerformCaptainFilter() {
  const valid = new Set([
    'ALL',
    ...nextPerformScheduledCaptains().map((captain) => `CAPTAIN:${captain.person_id}`)
  ]);
  if (!setupNextState.performCaptainFilter || !valid.has(setupNextState.performCaptainFilter)) {
    setupNextState.performCaptainFilter = nextPerformDefaultCaptainFilter();
  }
}

function nextRenderPerformCaptainFilter() {
  const select = el('next-perform-captain-filter');
  if (!select) return;
  nextEnsurePerformCaptainFilter();

  const captains = nextPerformScheduledCaptains();
  select.innerHTML = [
    '<option value="ALL">All scheduled work</option>',
    ...captains.map((captain) => (
      `<option value="CAPTAIN:${captain.person_id}">${escapeHtml(captain.display_name)}</option>`
    ))
  ].join('');
  select.value = setupNextState.performCaptainFilter;

  if (select.dataset.performCaptainFilterInstalled !== '1') {
    select.dataset.performCaptainFilterInstalled = '1';
    select.addEventListener('change', () => {
      setupNextState.performCaptainFilter = select.value || 'ALL';
      renderNextExecution();
    });
  }
}

function nextFilterPerformAssignments(assignments) {
  nextEnsurePerformCaptainFilter();
  const filter = setupNextState.performCaptainFilter || 'ALL';
  if (filter === 'ALL') return assignments;

  const personId = Number(String(filter).split(':', 2)[1]);
  if (!personId) return assignments;

  const crewById = new Map(
    (setupNextState.performBoard.crews || []).map((crew) => [
      Number(crew.setup_work_day_crew_id),
      crew
    ])
  );
  return assignments.filter((assignment) => {
    const crew = crewById.get(Number(assignment.setup_work_day_crew_id));
    return Number(crew?.captain_person_id) === personId;
  });
}

function nextPerformAssignmentCard(assignment) {
  const task = nextPerformTask(assignment.setup_session_task_id) || assignment;
  const crew = nextPerformCrew(assignment);
  const captain = crew?.captain_display_name || 'Captain TBD';
  const executionStatus = String(task.execution_status || 'PLANNED').toUpperCase();
  const boardStatus = String(task.board_status || '').toUpperCase();
  const status = executionStatus === 'COMPLETE' || executionStatus === 'IN_PROGRESS'
    ? executionStatus
    : boardStatus === 'SCHEDULED'
      ? 'SCHEDULED'
      : boardStatus === 'NEEDS_SCHEDULING_AGAIN'
        ? 'IN_PROGRESS'
        : executionStatus;
  const readinessWarning = task.readiness_state === 'NOT_READY'
    ? `<div class="next-perform-readiness-warning"><strong>Readiness condition:</strong> ${escapeHtml(task.readiness_note || 'Marked Not Ready')} <span class="muted">· soft planning condition; actual work may still be reported</span></div>`
    : '';
  return `
    <details class="next-perform-task next-perform-assignment"
      data-assignment-id="${assignment.setup_work_day_task_id}"
      data-session-task-id="${assignment.setup_session_task_id}"
      data-task-id="${assignment.setup_task_id}">
      <summary>
        <span><strong>${escapeHtml(assignment.task_name)}</strong>
          <span class="muted"> · ${escapeHtml(nextTaskScopeLabel(assignment))}</span>
        </span>
        <span class="pill ${status === 'COMPLETE' ? 'verified' : status === 'IN_PROGRESS' ? 'unverified' : ''}">${escapeHtml(status)}</span>
      </summary>
      <div class="next-perform-assignment-context">
        Crew ${escapeHtml(assignment.crew_lane || '—')} · ${escapeHtml(captain)}
        · Planned crew ${escapeHtml(assignment.planned_crew_count ?? 'TBD')}
      </div>
      ${readinessWarning}
      <div class="next-perform-actions">
        <button type="button" class="small secondary next-print-task">Print Task</button>
        <button type="button" class="small next-report-work">Report Work</button>
        <button type="button" class="small secondary next-report-problem" disabled title="Report Correction handoff is owned by #172">Report Correction</button>
      </div>
      <div class="next-perform-body" hidden></div>
    </details>`;
}

function renderNextExecution() {
  const target = el('next-perform-list');
  if (!target) return;
  const board = setupNextState.performBoard || {};
  nextEnsurePerformToolbar();
  nextRenderPerformCaptainFilter();
  const allAssignments = (board.assignments || []).slice();
  const assignments = nextFilterPerformAssignments(allAssignments);
  const summary = el('next-perform-filter-summary');
  if (summary) {
    summary.textContent = assignments.length === allAssignments.length
      ? `${assignments.length} scheduled assignment${assignments.length === 1 ? '' : 's'}`
      : `${assignments.length} of ${allAssignments.length} scheduled assignments shown`;
  }
  const days = (board.work_days || []).filter((day) =>
    assignments.some((assignment) => Number(assignment.setup_work_day_id) === Number(day.setup_work_day_id))
  );

  target.innerHTML = days.length ? days.map((day) => {
    const dayAssignments = assignments.filter(
      (assignment) => Number(assignment.setup_work_day_id) === Number(day.setup_work_day_id)
    );
    const shifts = ['MORNING', 'AFTERNOON', 'ALL_DAY'];
    return `
      <section class="next-perform-day">
        <h3>Setup Day ${escapeHtml(day.setup_day_number ?? '—')} · ${escapeHtml(day.day_of_week || '')} · ${escapeHtml(day.work_date)}</h3>
        ${shifts.map((shift) => {
          const shiftItems = dayAssignments.filter((assignment) => assignment.shift_code === shift);
          if (!shiftItems.length) return '';
          const crewIds = [...new Set(shiftItems.map((assignment) => Number(assignment.setup_work_day_crew_id)))];
          return `
            <div class="next-perform-shift">
              <h4>${escapeHtml(shift === 'MORNING' ? 'AM' : shift === 'AFTERNOON' ? 'PM' : 'All Day')}</h4>
              ${crewIds.map((crewId) => {
                const crew = (board.crews || []).find((item) => Number(item.setup_work_day_crew_id) === crewId);
                const crewItems = shiftItems
                  .filter((assignment) => Number(assignment.setup_work_day_crew_id) === crewId)
                  .sort((a, b) => Number(a.sort_order || 0) - Number(b.sort_order || 0));
                return `
                  <div class="next-perform-crew">
                    <h5>Crew ${escapeHtml(crew?.crew_code || crewItems[0]?.crew_lane || '—')} · ${escapeHtml(crew?.captain_display_name || 'Captain TBD')}</h5>
                    ${crewItems.map(nextPerformAssignmentCard).join('')}
                  </div>`;
              }).join('')}
            </div>`;
        }).join('')}
      </section>`;
  }).join('') : '<div class="empty-state">No scheduled assignments match the selected Captain. Choose All scheduled work to see the full field schedule.</div>';

  target.querySelectorAll('.next-perform-assignment').forEach((details) => {
    details.querySelector('.next-report-work')?.addEventListener('click', async (event) => {
      event.preventDefault();
      details.open = true;
      await loadNextTaskExecution(details, true);
    });
    details.querySelector('.next-print-task')?.addEventListener('click', async (event) => {
      event.preventDefault();
      await printNextPerformTask(details);
    });
    details.addEventListener('toggle', () => {
      if (details.open && !details.dataset.loaded && details.dataset.loading !== '1') {
        loadNextTaskExecution(details, false);
      }
    });
  });
}

async function printNextPerformTask(details) {
  // Do not open the <details> element until its context is ready. Opening it
  // first fires the toggle loader and can race this explicit print load.
  if (!details.dataset.loaded && details.dataset.loading === '1') {
    for (let attempt = 0; attempt < 100 && details.dataset.loading === '1'; attempt += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, 50));
    }
  }
  if (!details.dataset.loaded) {
    await loadNextTaskExecution(details, false);
  }
  if (details.dataset.loaded !== '1') {
    window.alert('Task context could not be loaded, so the task cover sheet cannot be printed.');
    return;
  }
  details.open = true;

  const assignmentId = Number(details.dataset.assignmentId);
  const sessionTaskId = Number(details.dataset.sessionTaskId);
  const assignment = (setupNextState.performBoard.assignments || []).find(
    (item) => Number(item.setup_work_day_task_id) === assignmentId
  );
  const task = nextPerformTask(sessionTaskId) || assignment;
  const day = assignment ? nextPerformDay(assignment.setup_work_day_id) : null;
  const crew = assignment ? nextPerformCrew(assignment) : null;
  const taskContext = details.querySelector('.next-perform-grid');
  const existing = document.getElementById('setup-perform-print-sheet');
  existing?.remove();

  const sheet = document.createElement('section');
  sheet.id = 'setup-perform-print-sheet';
  sheet.innerHTML = `
    <header class="setup-perform-print-header">
      <div>
        <div class="eyebrow">Captain / field execution</div>
        <h1>Setup Task Cover Sheet</h1>
      </div>
      <div class="setup-perform-print-generated"><strong>Generated:</strong> ${escapeHtml(new Date().toLocaleString())}</div>
    </header>
    <h2>${escapeHtml(assignment?.task_name || task?.task_name || 'Setup task')}</h2>
    <div class="setup-perform-print-meta">
      <div><strong>Scope:</strong> ${escapeHtml(nextTaskScopeLabel(assignment || task || {}))}</div>
      <div><strong>Scheduled:</strong> Setup Day ${escapeHtml(day?.setup_day_number ?? '—')} · ${escapeHtml(day?.work_date || assignment?.work_date || '')} · ${escapeHtml(assignment?.shift_code === 'MORNING' ? 'AM' : assignment?.shift_code === 'AFTERNOON' ? 'PM' : 'All Day')}</div>
      <div><strong>Crew / Captain:</strong> Crew ${escapeHtml(crew?.crew_code || assignment?.crew_lane || '—')} · ${escapeHtml(crew?.captain_display_name || 'Captain TBD')}</div>
      <div><strong>Assignment ID:</strong> ${escapeHtml(assignmentId)}</div>
    </div>
    ${task?.readiness_state === 'NOT_READY' ? `<div class="setup-perform-print-warning"><strong>Readiness condition:</strong> ${escapeHtml(task.readiness_note || 'Marked Not Ready')}</div>` : ''}
    ${taskContext ? taskContext.outerHTML : ''}
    <section class="setup-perform-print-notes">
      <h3>Field notes / corrections / problems</h3>
      <div class="setup-perform-print-lines"></div>
    </section>
  `;
  document.body.appendChild(sheet);
  document.body.classList.add('setup-print-perform-task');

  const cleanup = () => {
    document.body.classList.remove('setup-print-perform-task');
    document.getElementById('setup-perform-print-sheet')?.remove();
  };
  window.addEventListener('afterprint', cleanup, { once: true });
  window.print();
}

function nextLocationText(item) {
  if (item.current_stage_key) return `Stage ${item.current_stage_key}${item.current_stage_name ? ` — ${item.current_stage_name}` : ''}${item.current_location_note ? ` · ${item.current_location_note}` : ''}`;
  if (item.current_location_note) return item.current_location_note;
  if (item.home_location_code) return `Home storage ${item.home_location_code}`;
  return 'Location not yet recorded';
}

async function loadNextTaskExecution(details, focusReport = false) {
  if (details.dataset.loading === '1') return;
  details.dataset.loading = '1';
  const taskId = Number(details.dataset.taskId);
  const sessionTaskId = Number(details.dataset.sessionTaskId);
  const assignmentId = Number(details.dataset.assignmentId);
  const assignment = (setupNextState.performBoard.assignments || []).find(
    (item) => Number(item.setup_work_day_task_id) === assignmentId
  );
  const task = nextPerformTask(sessionTaskId) || assignment;
  const day = assignment ? nextPerformDay(assignment.setup_work_day_id) : null;
  const crew = assignment ? nextPerformCrew(assignment) : null;
  const body = details.querySelector('.next-perform-body');
  body.hidden = false;
  body.innerHTML = '<div class="muted">Loading scheduled work context…</div>';
  try {
    const [contextPayload, resourcePayload, progressPayload, procedureResult] = await Promise.all([
      api(`api/setup/tasks/${taskId}/field-context?season_year=${encodeURIComponent(appState.seasonYear)}`),
      api(`api/setup/tasks/${taskId}/resources`),
      api(`api/setup/session-tasks/${sessionTaskId}/progress`),
      api(`api/setup/tasks/${taskId}/procedure`)
        .then((payload) => ({ payload, error: null }))
        .catch((error) => ({ payload: null, error }))
    ]);
    const context = contextPayload.context || {};
    const resources = resourcePayload.resources || [];
    const progress = progressPayload.progress || [];
    const procedurePayload = procedureResult.payload || {};
    const procedureError = procedureResult.error;
    const docs = procedurePayload.instructions?.current_documents || procedurePayload.instructions?.documents || [];
    const assets = [
      ...(context.displays || []).map((item) => `<li>Display ${item.display_id} — ${escapeHtml(item.display_name)}${item.container_id ? ` · Container ${item.container_id}` : ''} · <strong>${escapeHtml(nextLocationText(item))}</strong></li>`),
      ...(context.support_containers || []).map((item) => `<li>Support Container ${item.container_id} · <strong>${escapeHtml(nextLocationText(item))}</strong></li>`)
    ];
    const assignmentProgress = progress.filter((p) => Number(p.setup_work_day_task_id) === assignmentId);
    const lastPercent = assignmentProgress.length
      ? Number(assignmentProgress[assignmentProgress.length - 1].percent_complete || 0)
      : 0;
    const complete = task?.execution_status === 'COMPLETE';

    body.innerHTML = `
      <div class="next-perform-assignment-banner">
        <strong>Scheduled assignment:</strong>
        Setup Day ${escapeHtml(day?.setup_day_number ?? '—')} · ${escapeHtml(day?.work_date || assignment?.work_date || '')}
        · ${escapeHtml(assignment?.shift_code === 'MORNING' ? 'AM' : assignment?.shift_code === 'AFTERNOON' ? 'PM' : 'All Day')}
        · Crew ${escapeHtml(crew?.crew_code || assignment?.crew_lane || '—')}
        · ${escapeHtml(crew?.captain_display_name || 'Captain TBD')}
      </div>
      <div class="next-perform-grid">
        <section><h4>Task</h4><p>${escapeHtml(task?.completion_point || 'Completion point not yet documented.')}</p>
          ${task?.readiness_note ? `<p><strong>Can start when:</strong> ${escapeHtml(task.readiness_note)}</p>` : ''}
          ${task?.weather_note ? `<p><strong>Weather limits:</strong> ${escapeHtml(task.weather_note)}</p>` : ''}
          <p><strong>Expected crew:</strong> ${escapeHtml(formatCrew(task))} · <strong>Expected time:</strong> ${escapeHtml(formatMinutes(task?.expected_duration_minutes))}</p></section>
        <section><h4>Equipment / Resources</h4>${resources.length ? `<ul>${resources.map((r) => `<li>${escapeHtml(r.resource_name)} · Qty ${r.quantity_required} · ${escapeHtml(r.requirement_type)}</li>`).join('')}</ul>` : '<p class="muted">No structured resource requirement recorded.</p>'}</section>
        <section><h4>Material / Current Location</h4>${assets.length ? `<ul>${assets.join('')}</ul>` : '<p class="muted">No Displays or support Containers are mapped to this task.</p>'}</section>
        <section><h4>Published Setup Procedure</h4>${docs.length
          ? docs.map((doc) => `<p><a target="_blank" rel="noopener" href="api/setup/tasks/${taskId}/procedure/current?name=${encodeURIComponent(doc.name || '')}">${escapeHtml(doc.name || 'Open current PDF')}</a></p>`).join('')
          : procedureError
            ? `<p class="next-procedure-warning"><strong>Procedure context unavailable.</strong> ${escapeHtml(procedureError.message || procedureError)} Report Work remains available.</p>`
            : '<p class="muted">No current Setup Procedure is resolved for this task.</p>'}</section>
      </div>
      <section class="next-progress-history"><h4>Progress history</h4>${progress.length ? progress.map((p) => `<div>${escapeHtml(p.performed_on || p.work_date || formatTimestamp(p.recorded_at))} · Crew ${p.crew_count}${p.duration_minutes ? ` · ${escapeHtml(formatMinutes(p.duration_minutes))}` : ''}${p.percent_complete ? ` · ${p.percent_complete}% complete` : ''}${p.progress_note ? ` · ${escapeHtml(p.progress_note)}` : ''}</div>`).join('') : '<div class="muted">No progress recorded yet.</div>'}</section>
      ${complete ? '<div class="next-complete-banner">This annual task is complete.</div>' : `
      <form class="next-completion-form next-report-work-form"
        data-session-task-id="${sessionTaskId}"
        data-assignment-id="${assignmentId}">
        <div class="next-report-work-grid">
          <label>Work completed on<input class="next-performed-on" type="date" value="${escapeHtml(day?.work_date || assignment?.work_date || '')}" required></label>
          <label>Crew size<input class="next-crew" type="number" min="1" required></label>
          <label>Hours<input class="next-duration-hours" type="number" min="0" step="1" required></label>
          <label>Minutes<input class="next-duration-minutes" type="number" min="0" max="59" step="1" value="0" required></label>
          <label>% complete<input class="next-percent-complete" type="number" min="1" max="100" step="1" value="${Math.max(lastPercent, 1)}" required></label>
        </div>
        <label class="next-report-note">What was done / what remains<textarea class="next-note" rows="3" placeholder="Required when the task is not 100% complete"></textarea></label>
        <details class="next-report-quantity-details">
          <summary>Add quantity detail (optional)</summary>
          <div class="next-report-quantity-grid">
            <label class="next-report-quantity">Completed quantity<input class="next-quantity" type="number" min="1"></label>
            <label class="next-report-units">Which units<input class="next-units" type="text"></label>
          </div>
        </details>
        <button type="submit">Save Work Report</button>
        <div class="muted">100% completes the annual task. Anything below 100% records partial work and leaves the task In Progress.</div>
      </form>`}
    `;
    details.dataset.loaded = '1';
    const form = body.querySelector('.next-report-work-form');
    form?.addEventListener('submit', submitNextProgress);
    if (focusReport && form) form.querySelector('.next-crew')?.focus();
  } catch (error) {
    body.innerHTML = `<strong>Scheduled work context could not be loaded.</strong><div class="muted">${escapeHtml(error.message || error)}</div>`;
  } finally {
    delete details.dataset.loading;
  }
}

async function submitNextProgress(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const sessionTaskId = Number(form.dataset.sessionTaskId);
  const assignmentId = Number(form.dataset.assignmentId);
  const performedOn = form.querySelector('.next-performed-on').value;
  const crew = Number(form.querySelector('.next-crew').value || 0);
  const hours = Number(form.querySelector('.next-duration-hours').value || 0);
  const minutes = Number(form.querySelector('.next-duration-minutes').value || 0);
  const percent = Number(form.querySelector('.next-percent-complete').value || 0);
  const note = form.querySelector('.next-note').value.trim();
  const durationMinutes = (hours * 60) + minutes;

  if (!performedOn) return window.alert('Work completed on date is required.');
  if (crew < 1) return window.alert('Crew size must be at least 1.');
  if (hours < 0 || minutes < 0 || minutes > 59 || durationMinutes <= 0) {
    return window.alert('Enter the actual Hours and Minutes worked.');
  }
  if (percent < 1 || percent > 100) return window.alert('Percent complete must be between 1 and 100.');
  if (percent < 100 && !note) return window.alert('For incomplete work, briefly record what was done and what remains.');

  try {
    setBusy(true);
    await api(`api/setup/session-tasks/${sessionTaskId}/progress`, commandOptions('POST', {
      setup_work_day_task_id: assignmentId,
      performed_on: performedOn,
      crew_count: crew,
      duration_minutes: durationMinutes,
      percent_complete: percent,
      completed_quantity: nullableInteger(form.querySelector('.next-quantity').value),
      completed_units: form.querySelector('.next-units').value.trim() || null,
      progress_note: note || null
    }));
    setAlert(percent === 100 ? 'Work reported — task complete.' : `Work reported — task is ${percent}% complete and remains In Progress.`, 'ok');
    await loadNextExecution();
    if (typeof board205Load === 'function') await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

const priorNextPopulateStageSelects = populateStageSelects;
populateStageSelects = function populateStageSelectsNextPass() {
  priorNextPopulateStageSelects();
  const edit = el('edit-stage-id');
  const add = el('add-stage-id');
  if (edit?.options?.length) edit.options[0].textContent = 'Site-wide / Infrastructure (no LOR Stage)';
  if (add?.options?.length) add.options[0].textContent = 'Site-wide / Infrastructure (no LOR Stage)';
  if (add) add.required = false;
};

async function nextLoadProcedure(task) {
  const current = el('production-current-pdf');
  const editable = el('production-editable-procedure');
  const warnings = el('production-procedure-warnings');
  current.innerHTML = '<span class="muted">Resolving current Setup Procedure…</span>';
  if (editable) editable.innerHTML = '<span class="muted">Resolving Manager source…</span>';
  warnings.innerHTML = '';
  try {
    const payload = await api(`api/setup/tasks/${task.setup_task_id}/procedure`);
    const data = payload.instructions || {};
    const files = data.current_documents || data.documents || [];
    if (!files.length) {
      current.innerHTML = `<strong>No published Setup PDF found.</strong><div class="muted">${nextIsSitewide(task) ? 'Site-wide Procedures belong directly in Display Folders\\Site Infrastructure\\Procedures\\Setup.' : 'Published field instructions belong directly in Procedures\\Setup.'}</div>`;
    } else {
      current.innerHTML = files.map((file) => `
        <div class="procedure-file"><strong>${escapeHtml(file.name || 'Unnamed PDF')}</strong>
        <div class="procedure-file-path">${escapeHtml(file.path || '')}</div>
        <div class="procedure-file-actions"><a href="api/setup/tasks/${task.setup_task_id}/procedure/current?name=${encodeURIComponent(file.name || '')}" target="_blank" rel="noopener">Open Current PDF</a></div></div>`).join('');
    }
    renderEditableSources(data.editable_sources || []);
    warnings.innerHTML = (data.warnings || []).map((warning) => `<div>${escapeHtml(warning)}</div>`).join('');
  } catch (error) {
    current.innerHTML = `<strong>Setup Procedure could not be resolved.</strong><div class="muted">${escapeHtml(error.message || error)}</div>`;
    if (editable) editable.innerHTML = '';
  }
}
loadProcedure = nextLoadProcedure;

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
    el('detail-stage').textContent = nextTaskScopeLabel(task);
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
    populateStageSelects();
    if (appState.tasks?.length) renderLibrary();
  } catch (error) {
    console.warn('Setup next-pass organization is not ready:', error);
  }
  const help = el('help-view');
  if (help) {
    const intro = help.querySelector('p');
    if (intro) intro.textContent = 'This review now includes Site-wide / Infrastructure plus Stage/Scene organization, prerequisite maintenance, a reusable/annual ordered backlog, rolling-horizon Crew A/B/C scheduling, and Captain field execution. Container/Display movement writes remain the next guarded integration step.';
  }
}

initializeNextPass();
