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
  executionTasks: []
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
  actions.innerHTML = '<button id="next-collapse-all" type="button" class="small secondary">Collapse all</button><button id="next-expand-all" type="button" class="small secondary">Expand all</button>';
  header.appendChild(actions);
  el('next-collapse-all').addEventListener('click', () => document.querySelectorAll('#library-list details').forEach((item) => { item.open = false; }));
  el('next-expand-all').addEventListener('click', () => document.querySelectorAll('#library-list details').forEach((item) => { item.open = true; }));
}

function installNextCopyDialog() {
  if (el('next-copy-dialog')) return;
  const dialog = document.createElement('dialog');
  dialog.id = 'next-copy-dialog';
  dialog.innerHTML = `<form method="dialog" class="next-copy-card"><h3>Copy reusable task</h3><p id="next-copy-source"></p><label>Destination Stage / Site-wide<select id="next-copy-stage"></select></label><label>Destination Scene<select id="next-copy-scene"></select></label><label>New task name<input id="next-copy-name" type="text" required></label><div class="action-row"><button id="next-copy-confirm" type="button">Create Copy</button><button type="submit" class="secondary">Cancel</button></div></form>`;
  document.body.appendChild(dialog);
  el('next-copy-stage').addEventListener('change', populateNextCopyScenes);
  el('next-copy-confirm').addEventListener('click', confirmNextCopy);
}

function openNextCopyDialog(taskId) {
  const task = taskById(taskId); if (!task) return;
  setupNextState.copySourceId = taskId;
  const stageSelect = el('next-copy-stage');
  stageSelect.innerHTML = '<option value="">Site-wide / Infrastructure</option>' + sortedStages().map((stage) => `<option value="${stage.stage_id}">Stage ${escapeHtml(stage.stage_key)} — ${escapeHtml(stage.stage_name || '')}</option>`).join('');
  stageSelect.value = task.stage_id == null ? '' : String(task.stage_id);
  populateNextCopyScenes(task.lor_scene_id);
  el('next-copy-name').value = `${task.task_name} Copy`;
  el('next-copy-source').textContent = nextTaskLabel(task);
  el('next-copy-dialog').showModal();
}

function populateNextCopyScenes(selectedScene = null) {
  const stageId = el('next-copy-stage').value ? Number(el('next-copy-stage').value) : null;
  const sceneSelect = el('next-copy-scene');
  sceneSelect.innerHTML = '<option value="">Stage-level / General</option>' + (stageId == null ? [] : nextScenesForStage(stageId)).map((scene) => `<option value="${scene.lor_scene_id}">${escapeHtml(scene.scene_name)}</option>`).join('');
  sceneSelect.disabled = stageId == null;
  sceneSelect.value = selectedScene == null ? '' : String(selectedScene);
}

async function confirmNextCopy() {
  const source = taskById(setupNextState.copySourceId); if (!source) return;
  const stageId = el('next-copy-stage').value ? Number(el('next-copy-stage').value) : null;
  const sceneId = stageId == null || !el('next-copy-scene').value ? null : Number(el('next-copy-scene').value);
  const name = el('next-copy-name').value.trim(); if (!name) return;
  try {
    setBusy(true);
    const create = await api('api/setup/tasks', commandOptions('POST', { task_name: name, stage_id: stageId, task_action_type: source.task_action_type, display_order: source.display_order }));
    const newId = Number(create.task?.setup_task_id); if (!newId) throw new Error('Copied task did not return an ID.');
    if (sceneId != null) await api(`api/setup/tasks/${newId}/scope`, commandOptions('PATCH', { stage_id: stageId, lor_scene_id: sceneId }));
    const copied = taskById(setupNextState.copySourceId);
    await api(`api/setup/tasks/${newId}`, commandOptions('PATCH', setupTaskUpdatePayload({ ...copied, setup_task_id: newId, task_name: name, stage_id: stageId }, {})));
    for (const dep of copied.dependencies || []) await api(`api/setup/tasks/${newId}/dependencies/${dep.prerequisite_setup_task_id}`, commandOptions('PATCH', { active: true, dependency_note: dep.dependency_note || null }));
    el('next-copy-dialog').close(); await reloadTasks(null); await loadNextOrganization(false); renderLibrary(); setAlert(`Created copied task ${newId}.`, 'ok');
  } catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
}

function installDependencyEditor() {
  const section = el('detail-dependencies')?.closest('.detail-section');
  if (!section || el('next-dependency-editor')) return;
  const editor = document.createElement('div'); editor.id = 'next-dependency-editor'; editor.className = 'next-dependency-editor manager-only';
  editor.innerHTML = `<select id="next-dependency-select"></select><input id="next-dependency-note" type="text" placeholder="Optional prerequisite note"><button id="next-dependency-add" type="button">Add prerequisite</button>`;
  section.appendChild(editor);
  el('next-dependency-add').addEventListener('click', addNextDependency);
  el('detail-dependencies').addEventListener('click', (event) => { const button = event.target.closest('[data-remove-dependency]'); if (button) removeNextDependency(Number(button.dataset.removeDependency)); });
}

function renderDependencyEditor(task) {
  installDependencyEditor(); const editor = el('next-dependency-editor'); if (!editor) return; editor.hidden = !appState.access?.can_manage_setup;
  const existing = new Set((task.dependencies || []).map((d) => Number(d.prerequisite_setup_task_id)));
  el('next-dependency-select').innerHTML = '<option value="">Select prerequisite…</option>' + (appState.tasks || []).filter((item) => item.active_flag && Number(item.setup_task_id) !== Number(task.setup_task_id) && !existing.has(Number(item.setup_task_id))).map((item) => `<option value="${item.setup_task_id}">${escapeHtml(nextTaskLabel(item))}</option>`).join('');
  el('detail-dependencies').innerHTML = (task.dependencies || []).length ? (task.dependencies || []).map((dep) => `<span class="chip">${escapeHtml(dep.task_name)}${dep.dependency_note ? ` · ${escapeHtml(dep.dependency_note)}` : ''}${appState.access?.can_manage_setup ? ` <button type="button" class="chip-remove" data-remove-dependency="${dep.prerequisite_setup_task_id}">×</button>` : ''}</span>`).join('') : '<span class="muted">No prerequisites.</span>';
}

async function addNextDependency() {
  const task = taskById(appState.selectedTaskId); const prerequisiteId = Number(el('next-dependency-select').value || 0); if (!task || !prerequisiteId) return;
  try { setBusy(true); await api(`api/setup/tasks/${task.setup_task_id}/dependencies/${prerequisiteId}`, commandOptions('PATCH', { active: true, dependency_note: el('next-dependency-note').value.trim() || null })); await reloadTasks(task.setup_task_id); await loadNextOrganization(false); renderDependencyEditor(taskById(task.setup_task_id)); setAlert('Prerequisite added.', 'ok'); }
  catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
}

async function removeNextDependency(prerequisiteId) {
  const task = taskById(appState.selectedTaskId); if (!task) return;
  try { setBusy(true); await api(`api/setup/tasks/${task.setup_task_id}/dependencies/${prerequisiteId}`, commandOptions('PATCH', { active: false })); await reloadTasks(task.setup_task_id); await loadNextOrganization(false); renderDependencyEditor(taskById(task.setup_task_id)); setAlert('Prerequisite removed.', 'ok'); }
  catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
}

function nextPlanningOrder(tasks = appState.tasks || []) {
  return [...tasks].sort((a, b) => {
    const ap = a.planned_order == null ? Number.MAX_SAFE_INTEGER : Number(a.planned_order);
    const bp = b.planned_order == null ? Number.MAX_SAFE_INTEGER : Number(b.planned_order);
    if (ap !== bp) return ap - bp;
    const ab = a.baseline_plan_order == null ? Number.MAX_SAFE_INTEGER : Number(a.baseline_plan_order);
    const bb = b.baseline_plan_order == null ? Number.MAX_SAFE_INTEGER : Number(b.baseline_plan_order);
    if (ab !== bb) return ab - bb;
    return Number(a.setup_task_id) - Number(b.setup_task_id);
  });
}

function nextPlanningCategory(task) {
  if (task.execution_status === 'COMPLETE') return 'COMPLETED';
  if (task.execution_status === 'IN_PROGRESS') return 'IN_PROGRESS';
  if (Number(task.scheduled_count || 0) > 0 || task.planned_date) return 'SCHEDULED';
  return 'UNSCHEDULED';
}

function nextPlanningFilterEnabled(category) {
  const box = document.querySelector(`[data-plan-filter="${category}"]`);
  return !box || box.checked;
}

function renderPlanningBacklog() {
  const target = el('next-planning-backlog');
  if (!target) return;
  const full = nextPlanningOrder();
  const visible = full.filter((task) => nextPlanningFilterEnabled(nextPlanningCategory(task)));
  target.innerHTML = visible.length ? visible.map((task, index) => {
    const category = nextPlanningCategory(task);
    return `<div class="next-planning-task" draggable="${appState.access?.can_manage_setup ? 'true' : 'false'}" data-task-id="${task.setup_task_id}"><div class="next-planning-order">${task.planned_order ?? task.baseline_plan_order ?? '—'}</div><div><strong>${escapeHtml(task.task_name)}</strong><div class="muted">${escapeHtml(nextTaskScopeLabel(task))} · ${category.replace('_', ' ')}</div></div><div class="next-planning-actions">${appState.access?.can_manage_setup ? `<button type="button" class="small secondary next-plan-up" ${index === 0 ? 'disabled' : ''}>↑</button><button type="button" class="small secondary next-plan-down" ${index === visible.length - 1 ? 'disabled' : ''}>↓</button>` : ''}</div></div>`;
  }).join('') : '<div class="empty-state">No tasks match the selected planning filters.</div>';
  wirePlanningBacklog(visible);
}

function wirePlanningBacklog(tasks) {
  document.querySelectorAll('.next-planning-task').forEach((row) => {
    const taskId = Number(row.dataset.taskId); const index = tasks.findIndex((t) => Number(t.setup_task_id) === taskId);
    row.querySelector('.next-plan-up')?.addEventListener('click', () => movePlannedTask(tasks, index, index - 1));
    row.querySelector('.next-plan-down')?.addEventListener('click', () => movePlannedTask(tasks, index, index + 1));
    row.addEventListener('dragstart', (event) => { setupNextState.draggedPlanningSessionTaskId = Number(taskById(taskId)?.setup_session_task_id || 0); event.dataTransfer.setData('text/plain', String(setupNextState.draggedPlanningSessionTaskId)); row.classList.add('dragging'); });
    row.addEventListener('dragend', () => { setupNextState.draggedPlanningSessionTaskId = null; row.classList.remove('dragging'); });
  });
}

async function movePlannedTask(tasks, from, to) {
  if (to < 0 || to >= tasks.length) return;
  [tasks[from], tasks[to]] = [tasks[to], tasks[from]];
  try { setBusy(true); for (let i = 0; i < tasks.length; i += 1) { const task = tasks[i]; if (!task.setup_session_task_id) continue; await api(`api/setup/session-tasks/${task.setup_session_task_id}/planned-order`, commandOptions('PATCH', { planned_order: (i + 1) * 10, plan_change_reason: 'Reordered in Setup planning' })); } await reloadTasks(null); renderPlanningBacklog(); setAlert('Annual planned order updated.', 'ok'); }
  catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
}

function shiftLabel(shift) {
  return shift === 'MORNING' ? 'Morning' : shift === 'AFTERNOON' ? 'Afternoon' : 'All day';
}

function renderNextSchedule() {
  const host = el('next-work-days'); if (!host) return;
  const days = setupNextState.schedule.work_days || []; const assignments = setupNextState.schedule.assignments || [];
  host.innerHTML = days.length ? days.map((day) => {
    const rows = assignments.filter((item) => Number(item.setup_work_day_id) === Number(day.setup_work_day_id));
    return `<section class="next-work-day"><div class="next-work-day-heading"><strong>${escapeHtml(formatDate(day.work_date))}</strong><span>${escapeHtml(day.day_status)}</span></div>${['ALL_DAY','MORNING','AFTERNOON'].map((shift) => `<div class="next-shift"><h4>${shiftLabel(shift)}</h4>${['A','B','C'].map((lane) => { const laneRows = rows.filter((r) => r.shift_code === shift && r.crew_lane === lane); return `<div class="next-crew-lane" data-work-day-id="${day.setup_work_day_id}" data-shift="${shift}" data-lane="${lane}"><strong>Crew ${lane}</strong>${laneRows.map((r) => `<div class="next-scheduled-task">${escapeHtml(r.task_name)}${r.planned_crew_count ? ` · ${r.planned_crew_count} people` : ''}${appState.access?.can_manage_setup ? `<button type="button" class="chip-remove" data-unschedule-session-task="${r.setup_session_task_id}">×</button>` : ''}</div>`).join('') || '<div class="muted">Drop task here</div>'}</div>`; }).join('')}</div>`).join('')}</section>`;
  }).join('') : '<div class="empty-state">No near-term work day is planned yet. Managers can add one when the next date is known.</div>';
  wireNextSchedule();
}

function wireNextSchedule() {
  document.querySelectorAll('.next-crew-lane').forEach((lane) => {
    lane.addEventListener('dragover', (event) => { event.preventDefault(); lane.classList.add('drop-target'); });
    lane.addEventListener('dragleave', () => lane.classList.remove('drop-target'));
    lane.addEventListener('drop', async (event) => {
      event.preventDefault(); lane.classList.remove('drop-target');
      const sessionTaskId = Number(event.dataTransfer.getData('text/plain') || setupNextState.draggedPlanningSessionTaskId || 0); if (!sessionTaskId) return;
      try { setBusy(true); await api(`api/setup/work-days/${lane.dataset.workDayId}/tasks/${sessionTaskId}`, commandOptions('PATCH', { active: true, shift_code: lane.dataset.shift, crew_lane: lane.dataset.lane, sort_order: 100 })); await loadNextSchedule(); setAlert('Task assigned to crew lane.', 'ok'); }
      catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
    });
  });
  document.querySelectorAll('[data-unschedule-session-task]').forEach((button) => button.addEventListener('click', async () => {
    const assignment = setupNextState.schedule.assignments.find((r) => Number(r.setup_session_task_id) === Number(button.dataset.unscheduleSessionTask)); if (!assignment) return;
    try { setBusy(true); await api(`api/setup/work-days/${assignment.setup_work_day_id}/tasks/${assignment.setup_session_task_id}`, commandOptions('PATCH', { active: false, shift_code: assignment.shift_code, crew_lane: assignment.crew_lane, sort_order: assignment.sort_order || 100 })); await loadNextSchedule(); }
    catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
  }));
}

async function loadNextSchedule() {
  const payload = await api(`api/setup/schedule?season_year=${encodeURIComponent(appState.seasonYear)}`); setupNextState.schedule = payload.schedule || { work_days: [], assignments: [] }; renderNextSchedule();
}

async function createNextWorkDay(event) {
  event.preventDefault(); const date = el('next-work-date').value; if (!date) return;
  try { setBusy(true); await api('api/setup/work-days', commandOptions('POST', { season_year: appState.seasonYear, work_date: date, day_status: 'PLANNED', notes: null })); el('next-work-date').value = ''; await loadNextSchedule(); setAlert('Work day added.', 'ok'); }
  catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
}

async function promoteNextBaseline() {
  if (!appState.access?.can_manage_setup) return;
  if (!window.confirm(`Use the current ${appState.seasonYear} annual planned order as the reusable starting baseline for future Setup seasons?\n\nThis does not copy annual actuals or create a future season.`)) return;
  try { setBusy(true); const result = await api('api/setup/planning/promote-baseline', commandOptions('POST', { season_year: appState.seasonYear })); setAlert(`Promoted ${result.baseline?.updated_tasks || 0} planned positions to the reusable baseline.`, 'ok'); await reloadTasks(null); renderPlanningBacklog(); }
  catch (error) { setAlert(error.message || error, 'error'); window.alert(error.message || error); } finally { setBusy(false); }
}

async function loadNextExecution() {
  const payload = await api(`api/setup/execution?season_year=${encodeURIComponent(appState.seasonYear)}`);
  setupNextState.executionTasks = payload.tasks || [];
  renderNextExecution();
}

function renderNextExecution() {
  const filter = el('next-perform-filter')?.value || 'INCOMPLETE';
  let tasks = nextPlanningOrder(setupNextState.executionTasks);
  if (filter === 'INCOMPLETE') tasks = tasks.filter((task) => task.execution_status !== 'COMPLETE');
  if (filter === 'COMPLETE') tasks = tasks.filter((task) => task.execution_status === 'COMPLETE');
  el('next-perform-list').innerHTML = tasks.map((task) => `
    <details class="next-perform-task" data-session-task-id="${task.setup_session_task_id}" data-task-id="${task.setup_task_id}">
      <summary><span><strong>${escapeHtml(task.task_name)}</strong><span class="muted"> · ${escapeHtml(nextTaskScopeLabel(task))}</span></span>
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
      api(`api/setup/tasks/${taskId}/procedure`)
    ]);
    const context = contextPayload.context || {};
    const resources = resourcePayload.resources || [];
    const progress = progressPayload.progress || [];
    const docs = procedurePayload.instructions?.current_documents || procedurePayload.instructions?.documents || [];
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
        <section><h4>Material / Current Location</h4>${assets.length ? `<ul>${assets.join('')}</ul>` : '<p class="muted">No Display material source or support Container is selected for this reusable task.</p>'}</section>
        <section><h4>Published Setup Procedure</h4>${docs.length ? docs.map((doc) => `<p><a target="_blank" rel="noopener" href="api/setup/tasks/${taskId}/procedure/current?name=${encodeURIComponent(doc.name || '')}">${escapeHtml(doc.name || 'Open current PDF')}</a></p>`).join('') : `<p class="muted">No published Setup PDF resolved for this task scope.${nextIsSitewide(task) ? ' Site-wide Procedures belong in Display Folders\\Site Infrastructure\\Procedures\\Setup.' : ''}</p>`}</section>
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

function installNextTabs() {
  const tabs = document.querySelector('.tabs');
  if (!tabs || el('schedule-view')) return;
  const movementButton = tabs.querySelector('[data-view="movement"]');
  const scheduleButton = document.createElement('button');
  scheduleButton.className = 'tab'; scheduleButton.dataset.view = 'schedule'; scheduleButton.type = 'button'; scheduleButton.textContent = 'Plan / Schedule';
  tabs.insertBefore(scheduleButton, movementButton);
  const performButton = document.createElement('button');
  performButton.className = 'tab'; performButton.dataset.view = 'perform'; performButton.type = 'button'; performButton.textContent = 'Perform Work';
  tabs.insertBefore(performButton, movementButton);
  const helpButton = document.createElement('button');
  helpButton.className = 'tab'; helpButton.dataset.view = 'help'; helpButton.type = 'button'; helpButton.textContent = 'How Setup Works';
  tabs.appendChild(helpButton);

  const main = document.querySelector('main');
  const schedule = document.createElement('section');
  schedule.id = 'schedule-view'; schedule.className = 'view';
  schedule.innerHTML = `<div class="next-plan-layout"><div class="card"><div class="section-title"><div><div class="eyebrow">Reusable baseline + annual 2025 order</div><h2>Plan / Schedule</h2></div><button id="next-promote-baseline" type="button" class="secondary manager-only">Promote Annual Order to Future Baseline</button></div><p class="muted">The reusable baseline survives seasons. The annual order can change for this Setup without rewriting the future baseline until an Administrator deliberately promotes it.</p><div class="next-plan-filters"><label><input type="checkbox" data-plan-filter="UNSCHEDULED" checked> Unscheduled</label><label><input type="checkbox" data-plan-filter="SCHEDULED" checked> Scheduled</label><label><input type="checkbox" data-plan-filter="IN_PROGRESS" checked> In Progress</label><label><input type="checkbox" data-plan-filter="COMPLETED"> Completed</label></div><div id="next-planning-backlog" class="next-planning-backlog"></div></div><div class="card next-near-term-card"><div class="eyebrow">Rolling-horizon dispatch</div><h2>Next Work Days</h2><p class="muted">Assign only the near-term work you actually know. Crew lanes represent parallel groups, not individual volunteer rosters.</p><form id="next-schedule-form" class="next-schedule-form manager-only"><label>Work date<input id="next-work-date" type="date" required></label><button type="submit">Add Work Day</button></form><div id="next-work-days"></div></div></div>`;
  main.appendChild(schedule);
  const perform = document.createElement('section');
  perform.id = 'perform-view'; perform.className = 'view';
  perform.innerHTML = `<div class="card"><div class="section-title"><div><div class="eyebrow">Captain / field execution</div><h2>Perform Setup Work</h2></div><label>Status<select id="next-perform-filter"><option value="INCOMPLETE">Incomplete</option><option value="COMPLETE">Completed</option><option value="ALL">All</option></select></label></div><p class="muted">This screen combines the task, current published Procedure PDF, equipment, mapped material/location context, progress, and completion. Movement/scanning writes remain a separate guarded implementation step.</p><div id="next-perform-list"></div></div>`;
  main.appendChild(perform);
  const help = document.createElement('section');
  help.id = 'help-view'; help.className = 'view'; help.innerHTML = `<div class="card"><div class="eyebrow">Training reference</div><h2>How Setup Works</h2><p>This shared Setup application separates permanent reusable knowledge from annual planning and field execution.</p><div class="next-help-grid"><section><h3>Reusable Task</h3><p>Name, Stage/Scene scope, normal crew/time, prerequisites, Procedure, material relationships, and reusable resources.</p></section><section><h3>Annual Session</h3><p>Verification, annual order, planned dates, progress, completion, and the things that changed this year.</p></section><section><h3>Plan</h3><p>Maintain the full dependency-aware annual order. Promote a reviewed annual order back to the reusable future baseline only deliberately.</p></section><section><h3>Schedule</h3><p>Use rolling-horizon work days and Crew A/B/C lanes. Do not pretend the whole season is known months ahead.</p></section><section><h3>Perform</h3><p>Captains see the task, Procedure, resources, material location, progress, and completion in one place.</p></section><section><h3>Movement</h3><p>Physical scans identify Containers and Displays. A future guarded command records Setup movement without rewriting permanent storage assignments.</p></section></div></div>`;
  main.appendChild(help);

  scheduleButton.addEventListener('click', async () => { showView('schedule'); renderPlanningBacklog(); await loadNextSchedule(); });
  performButton.addEventListener('click', async () => { showView('perform'); await loadNextExecution(); });
  helpButton.addEventListener('click', () => showView('help'));
  el('next-perform-filter').addEventListener('change', renderNextExecution);
  document.querySelectorAll('[data-plan-filter]').forEach((box) => box.addEventListener('change', renderPlanningBacklog));
  el('next-schedule-form').addEventListener('submit', createNextWorkDay);
  el('next-promote-baseline').addEventListener('click', promoteNextBaseline);
}

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
