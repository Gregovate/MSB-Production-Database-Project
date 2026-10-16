/* Setup V0.3 browser-review UI: Site-wide/Stage/Scene organization, ordered backlog, crew lanes, and Captain execution. */

const setupNextState = {
  scenes: [],
  taskScopes: new Map(),
  organizationStatus: 'idle',
  organizationPromise: null,
  organizationError: null,
  closedStages: new Set(),
  closedScopes: new Set(),
  draggedTaskId: null,
  draggedPlanningSessionTaskId: null,
  copySourceId: null,
  schedule: { work_days: [], assignments: [] },
  executionTasks: [],
  performBoard: { session: null, work_days: [], crews: [], tasks: [], assignments: [] },
  performAssignmentMode: true,
  performCaptainFilter: null,
  performCaptainFilterKey: null,
  performCaptainFilterTouched: false
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

async function loadNextOrganization(render = true, { force = false } = {}) {
  if (setupNextState.organizationPromise && !force) {
    await setupNextState.organizationPromise;
    if (render && appState.tasks?.length) renderLibrary();
    return;
  }
  if (setupNextState.organizationStatus === 'ready' && !force) {
    if (render && appState.tasks?.length) renderLibrary();
    return;
  }

  setupNextState.organizationStatus = 'loading';
  setupNextState.organizationError = null;

  const request = (async () => {
    try {
      const payload = await api('api/setup/organization');
      const data = payload.organization || {};
      setupNextState.scenes = data.scenes || [];
      setupNextState.taskScopes = new Map(
        (data.task_scopes || []).map((scope) => [Number(scope.setup_task_id), scope])
      );
      setupNextState.organizationStatus = 'ready';
      applyNextTaskScopes();
    } catch (error) {
      setupNextState.organizationStatus = 'failed';
      setupNextState.organizationError = error;
      throw error;
    }
  })();

  setupNextState.organizationPromise = request;
  try {
    await request;
  } finally {
    if (setupNextState.organizationPromise === request) {
      setupNextState.organizationPromise = null;
    }
  }

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

function setupAnnualMilestoneDates(seasonYear) {
  const year = Number(seasonYear);
  if (!Number.isInteger(year) || year < 2000 || year > 2200) return null;

  const novemberFirst = new Date(Date.UTC(year, 10, 1));
  const firstThursday = 1 + ((4 - novemberFirst.getUTCDay() + 7) % 7);
  const thanksgiving = new Date(Date.UTC(year, 10, firstThursday + 21));

  const setupComplete = new Date(thanksgiving);
  setupComplete.setUTCDate(setupComplete.getUTCDate() - 7);

  const foodBankRunWalk = new Date(thanksgiving);
  foodBankRunWalk.setUTCDate(foodBankRunWalk.getUTCDate() - 5);

  const openingNight = new Date(thanksgiving);
  openingNight.setUTCDate(openingNight.getUTCDate() + 1);

  return { setupComplete, foodBankRunWalk, openingNight };
}

function setupMilestoneDateLabel(value) {
  return value.toLocaleDateString(undefined, {
    weekday: 'short',
    month: '2-digit',
    day: '2-digit',
    timeZone: 'UTC'
  });
}

function setupMilestoneCountdown(value) {
  const now = new Date();
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  const target = Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate());
  const days = Math.round((target - today) / 86400000);
  if (days === 0) return 'TODAY';
  if (days === 1) return '1 day';
  if (days > 1) return `${days} days`;
  return 'passed';
}

function renderSetupAnnualMilestones(target, seasonYear) {
  if (!target) return;
  const milestones = setupAnnualMilestoneDates(seasonYear);
  if (!milestones) {
    target.innerHTML = '';
    return;
  }

  target.innerHTML = `
    <div class="setup-annual-milestones" aria-label="Annual Setup launch milestones">
      <div class="setup-annual-milestone primary">
        <span class="setup-annual-milestone-label">COMPLETE SETUP · VIP SPONSOR NIGHT</span>
        <strong>${escapeHtml(setupMilestoneDateLabel(milestones.setupComplete))}</strong>
        <span>${escapeHtml(setupMilestoneCountdown(milestones.setupComplete))}</span>
      </div>
      <div class="setup-annual-milestone">
        <span class="setup-annual-milestone-label">FOOD BANK RUN/WALK</span>
        <strong>${escapeHtml(setupMilestoneDateLabel(milestones.foodBankRunWalk))}</strong>
        <span>${escapeHtml(setupMilestoneCountdown(milestones.foodBankRunWalk))}</span>
      </div>
      <div class="setup-annual-milestone">
        <span class="setup-annual-milestone-label">OPENING NIGHT · BLACK FRIDAY</span>
        <strong>${escapeHtml(setupMilestoneDateLabel(milestones.openingNight))}</strong>
        <span>${escapeHtml(setupMilestoneCountdown(milestones.openingNight))}</span>
      </div>
    </div>`;
}

window.setupAnnualMilestoneDates = setupAnnualMilestoneDates;
window.renderSetupAnnualMilestones = renderSetupAnnualMilestones;


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
  const pickListButton = document.getElementById('setup-pick-list-link');
  const scheduleButton = document.createElement('button');
  scheduleButton.className = 'tab'; scheduleButton.dataset.view = 'schedule'; scheduleButton.type = 'button'; scheduleButton.textContent = 'Plan / Schedule';
  const performButton = document.createElement('button');
  performButton.className = 'tab'; performButton.dataset.view = 'perform'; performButton.type = 'button'; performButton.textContent = 'Perform Work';
  tabs.insertBefore(scheduleButton, pickListButton);
  tabs.insertBefore(performButton, pickListButton);
  const actionButton = document.createElement('button');
  actionButton.className = 'tab manager-only';
  actionButton.dataset.view = 'action-center';
  actionButton.type = 'button';
  actionButton.textContent = 'Manager Action Center';
  actionButton.hidden = !appState.access?.can_manage_setup;
  tabs.insertBefore(actionButton, pickListButton);
  actionButton.addEventListener('click', () => {
    if (appState.access?.can_manage_setup) void navigateSetupView('action-center');
  });
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

  const management = document.createElement('section');
  management.id = 'action-center-view';
  management.className = 'view manager-only';
  management.hidden = !appState.access?.can_manage_setup;
  management.innerHTML = '<div class="card">' +
    '<div class="section-title"><div><div class="eyebrow">Management · 2026 Setup</div>' +
    '<h2>Setup Action Center</h2></div>' +
    '<button type="button" class="secondary" id="setup205-actions-refresh">Refresh current actions</button></div>' +
    '<p class="muted">Review original missing reports, unfinished work, and upcoming scheduling risks. ' +
    'Use the actions to open the exact work or crew. Planning and actual work stay separate.</p>' +
    '<div id="setup205-manager-report" aria-live="polite"></div></div>';
  main.appendChild(management);
  management.querySelector('#setup205-actions-refresh').addEventListener('click', () => {
    void loadSetup205ActionCenter();
  });

  const perform = document.createElement('section');
  perform.id = 'perform-view'; perform.className = 'view';
  perform.innerHTML = `
    <div class="card">
      <div class="section-title"><div><div class="eyebrow">Captain / field execution</div><h2>Perform Setup Work</h2></div></div>
      <div id="next-perform-global-kpis" class="next-perform-global-kpis" aria-label="Whole Setup completion and Manager action center"></div>
      <div id="setup-perform-milestones"></div>
      <p class="muted">Only scheduled work appears here. Work is organized by Setup Day, AM/PM, and Crew/Captain. Report Work records actual crew, elapsed time, and percent complete against the exact scheduled assignment.</p>
      <div class="next-perform-toolbar">
        <label>Captain
          <select id="next-perform-captain-filter" aria-label="Filter Perform Work by Captain"></select>
        </label>
        <label class="next-perform-show-completed">
          <input id="next-perform-show-completed" type="checkbox">
          Show completed
        </label>
        <span id="next-perform-filter-summary" class="muted"></span>
      <div id="next-perform-kpis" class="next-perform-kpis" aria-label="Perform Work labor KPIs"></div>
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
  renderSetupAnnualMilestones(document.getElementById('setup-perform-milestones'), Number(appState.seasonYear));
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

function nextLaborHours(crewCount, durationMinutes) {
  const crew = Number(crewCount);
  const minutes = Number(durationMinutes);
  if (!Number.isFinite(crew) || crew <= 0 || !Number.isFinite(minutes) || minutes <= 0) return null;
  return (crew * minutes) / 60;
}

function nextLaborHoursText(crewCount, durationMinutes) {
  const hours = nextLaborHours(crewCount, durationMinutes);
  if (hours == null) return 'TBD';
  const shown = Number.isInteger(hours) ? String(hours) : hours.toFixed(1).replace(/\.0$/, '');
  return `${shown} person-hour${Number(shown) === 1 ? '' : 's'}`;
}

function nextPerformPlannedCrew(assignment) {
  const crew = nextPerformCrew(assignment);
  const shift = String(assignment?.shift_code || '').toUpperCase();
  const shiftCount = shift === 'MORNING'
    ? crew?.am_planned_crew_count
    : shift === 'AFTERNOON'
      ? crew?.pm_planned_crew_count
      : null;
  // An existing Captain row with NULL shift count is not a staffed crew.
  // Never revive a stale assignment estimate to manufacture a volunteer.
  if (crew) return shiftCount != null && Number(shiftCount) > 0 ? Number(shiftCount) : null;
  if (assignment?.planned_crew_count != null && Number(assignment.planned_crew_count) > 0) {
    return Number(assignment.planned_crew_count);
  }
  return null;
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
      <label class="next-perform-show-completed">
        <input id="next-perform-show-completed" type="checkbox">
        Show completed
      </label>
      <span id="next-perform-filter-summary" class="muted"></span>
      <div id="next-perform-kpis" class="next-perform-kpis" aria-label="Perform Work labor KPIs"></div>
    `;
    list.insertAdjacentElement('beforebegin', toolbar);
  }
  const showCompleted = el('next-perform-show-completed');
  if (showCompleted && showCompleted.dataset.performCompletedFilterInstalled !== '1') {
    showCompleted.dataset.performCompletedFilterInstalled = '1';
    showCompleted.addEventListener('change', renderNextExecution);
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
  const signedInPersonId = Number(appState.access?.captain_person_id || 0);
  const email = String(appState.access?.authenticated_email || '').trim().toLowerCase();
  const signedInName = String(appState.access?.display_name || '').trim().toLowerCase();
  const captains = nextPerformScheduledCaptains();

  const mineByIdentity = signedInPersonId
    ? captains.find((captain) => Number(captain.person_id) === signedInPersonId)
    : null;
  if (mineByIdentity) return `CAPTAIN:${mineByIdentity.person_id}`;

  const mineByEmail = email
    ? captains.find((captain) => String(captain.email || '').trim().toLowerCase() === email)
    : null;
  if (mineByEmail) return `CAPTAIN:${mineByEmail.person_id}`;

  const mineByName = signedInName
    ? captains.find((captain) => String(captain.display_name || '').trim().toLowerCase() === signedInName)
    : null;
  return mineByName ? `CAPTAIN:${mineByName.person_id}` : 'ALL';
}

function nextEnsurePerformCaptainFilter() {
  const contextKey = [
    String(appState.access?.authenticated_email || 'unknown').trim().toLowerCase(),
    Number(appState.seasonYear) || 'none'
  ].join('|');

  if (setupNextState.performCaptainFilterKey !== contextKey) {
    setupNextState.performCaptainFilterKey = contextKey;
    setupNextState.performCaptainFilter = null;
    setupNextState.performCaptainFilterTouched = false;
  }

  const valid = new Set([
    'ALL',
    ...nextPerformScheduledCaptains().map((captain) => `CAPTAIN:${captain.person_id}`)
  ]);

  // Until the operator deliberately changes the dropdown, keep re-evaluating
  // the default as access + schedule data arrive. This avoids the initial
  // empty-board render permanently locking a scheduled Captain onto ALL.
  if (!setupNextState.performCaptainFilterTouched) {
    setupNextState.performCaptainFilter = nextPerformDefaultCaptainFilter();
    return;
  }

  if (!setupNextState.performCaptainFilter || !valid.has(setupNextState.performCaptainFilter)) {
    setupNextState.performCaptainFilter = nextPerformDefaultCaptainFilter();
    setupNextState.performCaptainFilterTouched = false;
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
      setupNextState.performCaptainFilterTouched = true;
      renderNextExecution();
    });
  }
}

function nextPerformCaptainScopedAssignments(assignments) {
  nextEnsurePerformCaptainFilter();
  const filter = setupNextState.performCaptainFilter || 'ALL';
  const crewById = new Map(
    (setupNextState.performBoard.crews || []).map((crew) => [
      Number(crew.setup_work_day_crew_id),
      crew
    ])
  );

  return assignments.filter((assignment) => {
    if (filter === 'ALL') return true;
    const personId = Number(String(filter).split(':', 2)[1]);
    if (!personId) return true;
    const crew = crewById.get(Number(assignment.setup_work_day_crew_id));
    return Number(crew?.captain_person_id) === personId;
  });
}

function nextFilterPerformAssignments(assignments) {
  const showCompleted = Boolean(el('next-perform-show-completed')?.checked);
  return nextPerformCaptainScopedAssignments(assignments).filter((assignment) => (
    showCompleted || !nextAssignmentReported(assignment)
  ));
}


function nextCanSubmitFieldFinding() {
  const access = appState.access || {};
  return Boolean(
    access.can_manage_setup
    || access.role_name === 'Production Crew'
    || (access.policy_names || []).includes('Production Crew')
  );
}

function nextCorrectionIntakeMarkup(sessionTaskId, assignmentId) {
  if (!nextCanSubmitFieldFinding()) return '';
  return `
    <section class="next-problem-intake">
      <form class="next-problem-form"
        data-session-task-id="${sessionTaskId}"
        data-assignment-id="${assignmentId}"
        hidden>
        <p class="muted">
          Setup already knows the scheduled assignment and current task context.
          This submits to <strong>Work Order Intake for Manager triage</strong>; it does not create an active Work Order.
        </p>
        <label>What did you find?
          <textarea class="next-problem-text" rows="3" maxlength="255" required></textarea>
        </label>
        <label>Suggested correction / evidence <span class="muted">(optional)</span>
          <textarea class="next-suggestion-text" rows="2" maxlength="2000"></textarea>
        </label>
        <button type="submit" class="next-report-correction-submit">Task Feedback</button>
        <div class="next-problem-result" aria-live="polite"></div>
      </form>
    </section>`;
}

function wireNextCorrectionIntake(body) {
  body.querySelector('.next-problem-form')?.addEventListener('submit', submitNextCorrectionIntake);
}

async function submitNextCorrectionIntake(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const sessionTaskId = Number(form.dataset.sessionTaskId);
  const assignmentId = Number(form.dataset.assignmentId);
  const problem = form.querySelector('.next-problem-text').value.trim();
  if (!problem) return;
  const result = form.querySelector('.next-problem-result');
  try {
    const payload = await api(
      `api/setup/session-tasks/${sessionTaskId}/correction-intake`,
      commandOptions('POST', {
        problem,
        suggested_correction_evidence: form.querySelector('.next-suggestion-text').value.trim() || null,
        setup_work_day_task_id: assignmentId
      })
    );
    const intakeId = payload.intake?.intake_id;
    result.textContent = intakeId
      ? `Submitted to Work Order Intake #${intakeId} for Manager triage.`
      : 'Submitted to Work Order Intake for Manager triage.';
    form.querySelector('.next-problem-text').value = '';
    form.querySelector('.next-suggestion-text').value = '';
  } catch (error) {
    result.textContent = error.message || error;
  }
}

async function openNextCorrectionIntake(details) {
  // Match Print Task's load-before-open behavior so the <details> toggle
  // cannot race the explicit Report Correction context load.
  if (!details.dataset.loaded && details.dataset.loading === '1') {
    for (let attempt = 0; attempt < 100 && details.dataset.loading === '1'; attempt += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, 50));
    }
  }
  if (!details.dataset.loaded) {
    await loadNextTaskExecution(details, false);
  }
  if (details.dataset.loaded !== '1') {
    window.alert('Scheduled work context could not be loaded, so Task Feedback is unavailable.');
    return;
  }

  details.open = true;
  const correctionForm = details.querySelector('.next-problem-form');
  if (!correctionForm) {
    window.alert('Task Feedback is not authorized for this account.');
    return;
  }
  correctionForm.hidden = false;
  correctionForm.querySelector('.next-problem-text')?.focus();
}

// Shared assignment state: readiness and historical locking remain separate cues.
// #205: resolve the occurrence from its own report, never annual progress.
// A partial report finishes that day's assignment; continuation stays in backlog.
function nextAssignmentReported(assignment) {
  return Number(assignment.work_report_count || 0) > 0;
}

function nextSetupLocalDate(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Chicago', year: 'numeric', month: '2-digit', day: '2-digit'
  }).formatToParts(now);
  const part = (name) => parts.find((item) => item.type === name).value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function nextAssignmentLate(assignment, workDate = assignment.work_date) {
  return Boolean(workDate && workDate < nextSetupLocalDate()
    && String(assignment.day_status || '').toUpperCase() !== 'CANCELLED'
    && !nextAssignmentReported(assignment));
}

function nextAssignmentReportedLabel(assignment) {
  return Number(assignment.reported_percent_complete) >= 100
    ? 'COMPLETE — Work Reported' : 'INCOMPLETE — Work Reported';
}

function nextScheduleWarning(text) {
  return `<div class="setup-205-action-warning" role="status" style="border:2px solid #a40000;border-left:8px solid #a40000;background:#fff0f0;color:#8b0000;padding:8px 10px;margin:6px 0;font-weight:900;font-size:1rem">${escapeHtml(text)}</div>`;
}

function nextSetupAssignmentStatus(task) {
  const executionStatus = String(task.execution_status || '').toUpperCase();
  const boardStatus = String(task.board_status || '').toUpperCase();
  if (task.effective_complete || executionStatus === 'COMPLETE' || boardStatus === 'COMPLETE') return 'COMPLETE';
  if (executionStatus === 'IN_PROGRESS' || boardStatus === 'NEEDS_SCHEDULING_AGAIN') return 'IN_PROGRESS';
  return 'SCHEDULED';
}

function nextPerformAssignmentStatus(assignment) {
  const task = nextPerformTask(assignment.setup_session_task_id) || assignment;
  return nextSetupAssignmentStatus(task);
}

// A reschedule is a Manager decision that NO actual work happened on this
// original occurrence. Never move or conceal a progress-locked assignment.
function nextCanRescheduleNoWork(assignment, task = null) {
  const annual = task || nextPerformTask(assignment?.setup_session_task_id);
  const day = nextPerformDay(assignment?.setup_work_day_id);
  return Boolean(
    appState.access?.can_manage_setup && assignment?.setup_work_day_task_id
    && !assignment.historical_locked
    && !nextAssignmentReported(assignment)
    && !annual?.effective_complete
    && String(day?.day_status || assignment.day_status || '').toUpperCase() !== 'CANCELLED'
  );
}

function nextPerformAssignmentCard(assignment) {
  const task = nextPerformTask(assignment.setup_session_task_id) || assignment;
  const crew = nextPerformCrew(assignment);
  const captain = crew?.captain_display_name || 'Captain TBD';
  const late = nextAssignmentLate(assignment);
  const status = nextAssignmentReported(assignment)
    ? nextAssignmentReportedLabel(assignment)
    : late ? 'LATE — NO WORK REPORTED' : nextPerformAssignmentStatus(assignment);
  const plannedCrew = nextPerformPlannedCrew(assignment);
  const plannedLabor = nextLaborHoursText(plannedCrew, task.expected_duration_minutes);
  const effort = String(task.effort_level || 'unknown').toLowerCase();
  const effortLabel = ['light', 'moderate', 'heavy'].includes(effort) ? effort.toUpperCase() : 'EFFORT TBD';
  const minimumCrew = task.normal_crew_min == null ? null : Number(task.normal_crew_min);
  const shortCrew = plannedCrew != null && minimumCrew != null && plannedCrew < minimumCrew;
  const annualComplete = Boolean(task.effective_complete || String(task.execution_status).toUpperCase() === 'COMPLETE');

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
        <span class="next-perform-assignment-pills">
          <span class="setup-board205-badge effort-${escapeHtml(effort)}">${escapeHtml(effortLabel)}</span>
          ${shortCrew ? `<span class="setup-board205-badge short-crew-badge" title="Planned crew ${escapeHtml(plannedCrew)} / minimum ${escapeHtml(minimumCrew)}">SHORT CREW</span>` : ''}
          <span class="pill setup-work-status" ${late ? 'style="background:#a40000;color:#fff;border:2px solid #a40000;font-weight:900"' : ''} data-work-status="${escapeHtml(status)}">${escapeHtml(status.replaceAll('_', ' '))}</span>
        </span>
      </summary>
      <div class="next-perform-assignment-context">
        Crew ${escapeHtml(assignment.crew_lane || '—')} · ${escapeHtml(captain)}
        · Planned crew ${escapeHtml(plannedCrew ?? 'TBD')}
        · Expected ${escapeHtml(formatMinutes(task.expected_duration_minutes))}
        · Est. labor ${escapeHtml(plannedLabor)}
      </div>
      ${readinessWarning}
      ${late ? nextScheduleWarning("LATE — NO WORK REPORTED · Report actual work or ask Manager to review original assignment") : ''}
      <div class="next-perform-actions">
        <button type="button" class="small secondary next-print-task">Print Task</button>
        <button type="button" class="small next-report-work">${annualComplete ? 'Review Work History' : 'Report Work'}</button>
        ${nextCanRescheduleNoWork(assignment, task) ? '<button type="button" class="small secondary next-reschedule-no-work">Reschedule · No work performed</button>' : ''}
        <button type="button" class="small next-report-problem next-report-correction-action"${nextCanSubmitFieldFinding() ? '' : ' disabled title="Task Feedback requires Production Crew or Manager access"'}>Task Feedback</button>
      </div>
      <div class="next-perform-body" hidden></div>
    </details>`;
}

// A Manager can correct a past plan directly from Perform Work, without
// opening the optional task context (which may be unavailable) and without
// creating a zero-hour or fake-progress report.
function nextRescheduleNoWorkDialog() {
  let dialog = document.getElementById('next-reschedule-no-work-dialog');
  if (dialog) return dialog;
  dialog = document.createElement('dialog');
  dialog.id = 'next-reschedule-no-work-dialog';
  dialog.className = 'next-reschedule-no-work-dialog';
  dialog.innerHTML = `
    <form id="next-reschedule-no-work-form">
      <h3>Reschedule — No work performed</h3>
      <p id="next-reschedule-original" class="muted"></p>
      <p>This action means no work happened on the original assignment.
         The original date and crew remain in the scheduling audit. No work report is created.</p>
      <label>New Setup Work Day
        <select id="next-reschedule-day" required></select>
      </label>
      <label>Destination Crew
        <select id="next-reschedule-crew" required></select>
      </label>
      <label>Shift
        <select id="next-reschedule-shift">
          <option value="MORNING">AM</option>
          <option value="AFTERNOON">PM</option>
        </select>
      </label>
      <p id="next-reschedule-shift-note" class="muted"></p>
      <div class="next-reschedule-actions">
        <button type="button" class="secondary next-reschedule-cancel">Cancel</button>
        <button type="submit">Move unworked assignment</button>
      </div>
    </form>`;
  document.body.appendChild(dialog);
  dialog.querySelector('.next-reschedule-cancel').addEventListener('click', () => dialog.close());
  dialog.querySelector('#next-reschedule-day').addEventListener('change', nextRescheduleNoWorkCrewOptions);
  dialog.querySelector('#next-reschedule-crew').addEventListener('change', nextRescheduleNoWorkCrewOptions);
  dialog.querySelector('#next-reschedule-no-work-form').addEventListener('submit', nextSubmitRescheduleNoWork);
  return dialog;
}

function nextRescheduleNoWorkCrewOptions() {
  const dialog = document.getElementById('next-reschedule-no-work-dialog');
  if (!dialog) return;
  const dayId = Number(dialog.querySelector('#next-reschedule-day')?.value || 0);
  const crewSelect = dialog.querySelector('#next-reschedule-crew');
  const selected = crewSelect?.value;
  const crews = (setupNextState.performBoard.crews || [])
    .filter(crew => Number(crew.setup_work_day_id) === dayId);
  // Reuse the accepted atomic create-Crew-and-place operation for New Crew.
  crewSelect.innerHTML = crews.map(crew =>
    '<option value="' + Number(crew.setup_work_day_crew_id) + '">Crew ' +
    escapeHtml(crew.crew_code || '') + ' · ' +
    escapeHtml(crew.captain_display_name || 'Captain TBD') + '</option>'
  ).join('') + '<option value="NEW_CREW">+ Create a new crew</option>';
  if ([...crewSelect.options].some(option => option.value === selected)) crewSelect.value = selected;
  const captainId = Number(dialog.dataset.preferredCaptain || 0);
  const captainCrew = captainId ? crews.find(crew => Number(crew.captain_person_id) === captainId) : null;
  if (captainId && !captainCrew) {
    // A Crew with a different Captain (or TBD) is never an implicit default.
    // The new-crew route records the original Captain atomically.
    crewSelect.value = 'NEW_CREW';
  } else if (captainCrew && !crews.some(crew => Number(crew.setup_work_day_crew_id) === Number(selected))) {
    crewSelect.value = String(captainCrew.setup_work_day_crew_id);
  }
  const isNew = crewSelect.value === 'NEW_CREW';
  const group = Boolean(dialog.dataset.assignmentIds);
  const shift = dialog.querySelector('#next-reschedule-shift');
  if (isNew || group) {
    shift.value = dialog.dataset.originalShift;
    shift.disabled = true;
  } else {
    shift.disabled = false;
  }
  dialog.querySelector('#next-reschedule-shift-note').textContent = isNew
    ? 'Creating a crew keeps the original AM/PM shift. The original Captain is assigned to the new Crew in the same transaction. Review staffing afterward.'
    : 'Choose the destination AM/PM shift.';
}

function nextOpenRescheduleNoWorkDialog(assignmentId) {
  if (!appState.access?.can_manage_setup) return;
  const board = setupNextState.performBoard;
  const assignment = (board.assignments || []).find(
    row => Number(row.setup_work_day_task_id) === Number(assignmentId)
  );
  const task = assignment ? nextPerformTask(assignment.setup_session_task_id) : null;
  if (!assignment || !nextCanRescheduleNoWork(assignment, task)) {
    setAlert('This assignment has actual work/history or is no longer eligible to move. Review the report or schedule a continuation.', 'error');
    return;
  }
  if (!['MORNING','AFTERNOON'].includes(assignment.shift_code)) {
    setAlert('Legacy All Day assignments require individual Manager correction in the Scheduling Board.', 'error');
    return;
  }
  const today = nextSetupLocalDate();
  const days = (board.work_days || []).filter(day =>
    day.work_date >= today && String(day.day_status || '').toUpperCase() !== 'CANCELLED'
  ).sort((a, b) => a.work_date.localeCompare(b.work_date));
  if (!days.length) {
    setAlert('No current/future workdays exist. Add a workday in Plan / Schedule before rescheduling.', 'error');
    return;
  }
  const dialog = nextRescheduleNoWorkDialog();
  const oldDay = nextPerformDay(assignment.setup_work_day_id);
  const oldCrew = nextPerformCrew(assignment);
  dialog.dataset.assignmentId = String(assignmentId);
  dialog.dataset.assignmentIds = '';
  dialog.dataset.originalShift = assignment.shift_code;
  dialog.querySelector('#next-reschedule-original').textContent =
    (task?.task_name || assignment.task_name || 'Setup task') +
    ' · originally ' + (oldDay?.work_date || assignment.work_date || 'unknown day') +
    ' · Crew ' + (oldCrew?.crew_code || assignment.crew_lane || '—') +
    ' · ' + (assignment.shift_code === 'MORNING' ? 'AM' : 'PM');
  const dateControl = dialog.querySelector('#next-reschedule-day');
  dateControl.innerHTML = days.map(day =>
    '<option value="' + Number(day.setup_work_day_id) + '">Setup Day ' +
    escapeHtml(day.setup_day_number ?? '—') + ' · ' +
    escapeHtml(day.work_date) + '</option>'
  ).join('');
  // Suggest the next existing eligible workday staffed by the original Captain.
  // This is selection only: moving still requires explicit Manager confirmation.
  const originalCaptain = oldCrew?.captain_person_id == null ? null : Number(oldCrew.captain_person_id);
  const nextSameCaptain = originalCaptain == null ? null : days.map(day => ({
    day,
    crew: (board.crews || []).find(crew =>
      Number(crew.setup_work_day_id) === Number(day.setup_work_day_id) &&
      Number(crew.captain_person_id) === originalCaptain)
  })).find(candidate => candidate.crew && Number(candidate.day.setup_work_day_id) !== Number(assignment.setup_work_day_id));
  if (nextSameCaptain) dateControl.value = String(nextSameCaptain.day.setup_work_day_id);
  else {
    // Never default a no-work move back to the original historical day.
    const future = days.find(day => Number(day.setup_work_day_id) !== Number(assignment.setup_work_day_id));
    if (future) dateControl.value = String(future.setup_work_day_id);
  }
  dialog.dataset.preferredCaptain = originalCaptain == null ? '' : String(originalCaptain);
  dialog.querySelector('#next-reschedule-shift').value = assignment.shift_code;
  nextRescheduleNoWorkCrewOptions();
  if (nextSameCaptain) {
    dialog.querySelector('#next-reschedule-crew').value = String(nextSameCaptain.crew.setup_work_day_crew_id);
    nextRescheduleNoWorkCrewOptions();
  }
  dialog.showModal();
}

// During weather or a cancelled volunteer shift, the Manager can move every
// confirmed unworked assignment together. If ANY assignment gained a report,
// server progress locks reject the entire transaction, preserving history.
function nextOpenRescheduleNoWorkBatch(dayId, shift) {
  if (!appState.access?.can_manage_setup || !['MORNING','AFTERNOON'].includes(shift)) return;
  const day = nextPerformDay(dayId);
  const items = (setupNextState.performBoard.assignments || [])
    .filter(item => Number(item.setup_work_day_id) === Number(dayId)
      && item.shift_code === shift && nextCanRescheduleNoWork(item));
  if (!items.length) {
    setAlert('No unworked and movable assignments remain in this shift.', 'error');
    return;
  }
  if (items.length > 25) {
    setAlert('This shift has more than 25 unworked tasks. Move smaller groups; no task was changed.', 'error');
    return;
  }
  nextOpenRescheduleNoWorkDialog(Number(items[0].setup_work_day_task_id));
  const dialog = document.getElementById('next-reschedule-no-work-dialog');
  if (!dialog?.open) return;
  dialog.dataset.assignmentIds = JSON.stringify(items.map(item =>
    Number(item.setup_work_day_task_id)));
  dialog.querySelector('#next-reschedule-original').textContent =
    items.length + ' unworked tasks on ' + (day?.work_date || 'original workday') +
    ' · ' + (shift === 'MORNING' ? 'AM' : 'PM') +
    ': ' + items.map(item => item.task_name).join(', ');
  dialog.querySelector('#next-reschedule-shift').value = shift;
  nextRescheduleNoWorkCrewOptions();
}

async function nextSubmitRescheduleNoWork(event) {
  event.preventDefault();
  if (!appState.access?.can_manage_setup) return;
  const dialog = document.getElementById('next-reschedule-no-work-dialog');
  const assignmentId = Number(dialog?.dataset.assignmentId || 0);
  const board = setupNextState.performBoard;
  const groupIds = dialog?.dataset.assignmentIds ? JSON.parse(dialog.dataset.assignmentIds) : null;
  const selectedIds = groupIds || [assignmentId];
  if (!selectedIds.length || selectedIds.length > 25) return;
  const selected = selectedIds.map(id => (board.assignments || []).find(
    row => Number(row.setup_work_day_task_id) === Number(id)));
  const assignment = selected[0];
  if (selected.some(row => !row || !nextCanRescheduleNoWork(row))) {
    setAlert('This original assignment cannot be moved: work/history is present or access changed.', 'error');
    return;
  }
  const dayId = Number(dialog.querySelector('#next-reschedule-day').value);
  const crewChoice = dialog.querySelector('#next-reschedule-crew').value;
  const crewId = Number(crewChoice);
  const shift = crewChoice === 'NEW_CREW' || groupIds ? assignment.shift_code
    : dialog.querySelector('#next-reschedule-shift').value;
  const targetDay = (board.work_days || []).find(day =>
    Number(day.setup_work_day_id) === dayId
    && day.work_date >= nextSetupLocalDate()
    && String(day.day_status || '').toUpperCase() !== 'CANCELLED'
  );
  const crew = (board.crews || []).find(row =>
    Number(row.setup_work_day_crew_id) === crewId
    && Number(row.setup_work_day_id) === dayId
  );
  if (!targetDay || !['MORNING','AFTERNOON'].includes(shift) ||
      (crewChoice !== 'NEW_CREW' && !crew)) {
    setAlert('Choose a valid future workday and destination crew/shift.', 'error');
    return;
  }
  if (selected.every(item => dayId === Number(item.setup_work_day_id) &&
      crewChoice !== 'NEW_CREW' &&
      crewId === Number(item.setup_work_day_crew_id) &&
      shift === item.shift_code)) {
    setAlert('Choose a different day, crew or shift to reschedule.', 'error');
    return;
  }
  if (!window.confirm(
    'Confirm NO WORK WAS PERFORMED on ALL ' + selected.length +
    ' selected original assignment(s)?\\n\\n' +
    'The task will move to ' + targetDay.work_date + ' ' +
    (shift === 'MORNING' ? 'AM' : 'PM') + '.\\n' +
    'This removes its old Late / No Work Reported warning.\\n' +
    'The schedule move remains audited; no work report is invented.'
  )) return;

  try {
    setBusy(true);
    if (crewChoice === 'NEW_CREW') {
      await api('api/setup/scheduling-board/work-days/' + dayId + '/crews/with-tasks',
        commandOptions('POST', {
          items:selectedIds.map(id => ({kind:'assignment',id})),
          captain_person_id: dialog.dataset.preferredCaptain
            ? Number(dialog.dataset.preferredCaptain) : null
        }));
    } else if (groupIds) {
      await api('api/setup/scheduling-board/assignments/bulk-reschedule',
        commandOptions('POST',{
          assignment_ids:selectedIds,
          setup_work_day_id:dayId,
          setup_work_day_crew_id:crewId
        }));
    } else {
      const existing = (board.assignments || []).filter(item =>
        Number(item.setup_work_day_id) === dayId &&
        Number(item.setup_work_day_crew_id) === crewId &&
        item.shift_code === shift
      );
      const sortOrder = existing.length
        ? Math.max(...existing.map(item => Number(item.sort_order) || 0)) + 10 : 10;
      await api('api/setup/scheduling-board/assignments/' + assignmentId,
        commandOptions('PATCH',{
          setup_work_day_id:dayId,setup_work_day_crew_id:crewId,
          shift_code:shift,sort_order:sortOrder
        }));
    }
    dialog.close();
    await loadNextExecution();
    if (typeof board205Load === 'function') await board205Load();
    setAlert('Unworked assignment rescheduled. Old late warning cleared; original plan retained in schedule audit.', 'ok');
  } catch (error) {
    setAlert('Reschedule did not complete: ' + (error.message || error), 'error');
  } finally {
    setBusy(false);
  }
}

// Inline Report Work help never reloads or discards unsaved field inputs.
function nextReportHelpButton(kind) {
  return '<span class="next-report-help" role="button" tabindex="0" data-help="' +
    kind + '" aria-label="How to enter ' + kind + '" title="Show field-specific guidance">How?</span>';
}
const NEXT_REPORT_FIELD_HELP = Object.freeze({
  date: '1. Choose the day the work ACTUALLY happened, not necessarily the scheduled date. 2. Verify both dates before saving.',
  crew: '1. Count people who actually worked, including the Captain if they worked. 2. Do not enter the planned crew estimate.',
  hours: '1. Enter whole elapsed hours actually worked. 2. If the work lasted under one hour, enter 0 Hours and actual Minutes.',
  minutes: '1. Enter remaining minutes 0 through 59. 2. Example: 1 hour 30 minutes is Hours = 1 and Minutes = 30. 3. Do not guess.',
  percent: '1. Enter the percent of the WHOLE task completed cumulatively. 2. It is blank until you enter real progress. 3. Under 100 percent requires a note about what remains.',
  notes: 'Describe work actually done. If the entire task is unfinished, explain what remains. If no work happened, ask a Manager to reschedule—do not invent a report.'
});
function wireNextReportHelp(form) {
  if (!form) return;
  const panel = form.querySelector('.next-report-help-panel');
  const text = panel?.querySelector('.next-report-help-text');
  if (!panel || !text) return;
  const open = (event, button) => {
    const message = NEXT_REPORT_FIELD_HELP[button?.dataset.help];
    if (!message) return;
    event.preventDefault();
    event.stopPropagation();
    text.textContent = message;
    panel.hidden = false;
    button.setAttribute('aria-expanded','true');
  };
  form.querySelectorAll('.next-report-help').forEach(button => {
    button.addEventListener('click', event => open(event, button));
    button.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') open(event, button);
    });
  });
  panel.querySelector('.next-report-help-close')?.addEventListener('click', () => {
    panel.hidden = true;
    form.querySelectorAll('.next-report-help').forEach(button =>
      button.setAttribute('aria-expanded','false'));
  });
}

function nextPerformLaborKpis(assignments) {
  let plannedHours = 0;
  let plannedUnknown = 0;
  let actualHours = 0;
  let completedPlannedHours = 0;
  let completedActualHours = 0;
  let completedPlannedUnknown = 0;
  let completedCount = 0;

  for (const assignment of assignments || []) {
    const task = nextPerformTask(assignment.setup_session_task_id) || assignment;
    const planned = nextLaborHours(
      nextPerformPlannedCrew(assignment),
      task.expected_duration_minutes
    );
    if (planned == null) plannedUnknown += 1;
    else plannedHours += planned;

    const actualPersonMinutes = Number(assignment.actual_person_minutes || 0);
    const actual = Number.isFinite(actualPersonMinutes) && actualPersonMinutes > 0
      ? actualPersonMinutes / 60
      : 0;
    actualHours += actual;

    if (nextPerformAssignmentStatus(assignment) === 'COMPLETE') {
      completedCount += 1;
      completedActualHours += actual;
      if (planned == null) completedPlannedUnknown += 1;
      else completedPlannedHours += planned;
    }
  }

  const formatHours = (hours) => (
    Number.isInteger(hours)
      ? String(hours)
      : hours.toFixed(1).replace(/\.0$/, '')
  );

  return {
    // A missing planned crew does not represent zero labor effort.
    plannedHours: plannedUnknown && plannedHours === 0 ? 'TBD' : formatHours(plannedHours),
    plannedUnknown,
    actualHours: formatHours(actualHours),
    completedPlannedHours: formatHours(completedPlannedHours),
    completedActualHours: formatHours(completedActualHours),
    completedPlannedUnknown,
    completedCount
  };
}

// #205: Linear elapsed-time capacity; never multiply by crew headcount.
// Unknown durations remain unknown rather than being treated as zero work.
function nextPerformShiftWorkload(items, shift) {
  const capacity = shift === 'MORNING' ? 180 : shift === 'AFTERNOON' ? 120 : 300;
  let known = 0, unknown = 0, notReady = 0;
  for (const assignment of items) {
    const task = nextPerformTask(assignment.setup_session_task_id);
    const raw = task?.expected_duration_minutes;
    const minutes = raw == null || raw === '' ? NaN : Number(raw);
    if (!Number.isFinite(minutes) || minutes <= 0) unknown += 1;
    else known += minutes;
    if (task?.readiness_state === 'NOT_READY') notReady += 1;
  }
  return { capacity, known, unknown, notReady, count: items.length, overload: Math.max(0, known - capacity) };
}
function nextPerformWorkloadLabel(items, shift) {
  const w = nextPerformShiftWorkload(items, shift);
  const crew = items.length ? nextPerformCrew(items[0]) : null;
  const count = shift === 'MORNING' ? crew?.am_planned_crew_count
    : shift === 'AFTERNOON' ? crew?.pm_planned_crew_count : null;
  const crewConfirmed = crew?.captain_person_id != null && count != null && Number(count) >= 1;
  // Shift duration is known independently of staffing. Typical hours are
  // guidance, not proven capacity if the Captain-led crew is unavailable.
  const needsReview = !crewConfirmed || w.overload > 0 || w.unknown > 0 || w.notReady > 0;
  const status = !crewConfirmed ? 'STAFFING UNCONFIRMED — REVIEW SHIFT'
    : w.overload > 0 ? 'SHIFT TIME PRESSURE — REVIEW'
    : needsReview ? 'REVIEW REQUIRED' : 'WITHIN TYPICAL TIME';
  const color = needsReview ? '#835900' : '#146044';
  const background = needsReview ? '#fff6dd' : '#eaf8f0';
  const hours = minutes => (minutes / 60).toFixed(2).replace(/0$/, '').replace(/[.]$/, '');
  const note = !crewConfirmed
    ? ' · no confirmed Captain-led crew; work duration still counted'
    : w.overload ? ` · +${hours(w.overload)}h beyond typical shift; review continuation` : '';
  return `<div role="status" style="position:sticky;top:0;z-index:3;border:2px solid ${color};border-radius:7px;padding:9px 12px;margin:6px 0 9px;background:${background};color:${color};font-weight:700">
    <div style="font-size:1.05rem">${status} — ${hours(w.known)} / ${hours(w.capacity)} typical linear hours${note}</div>
    <div style="font-size:.85rem">${w.count} tasks · ${w.unknown} missing duration estimates · ${w.notReady} NOT READY</div>
  </div>`;
}

// Count each crew once per shift; planned counts already include the Captain.
// ALL_DAY remains explicit, and reported labor is never presented as attendance.
function nextDayStaffingSummary(assignments, crews, taskRows = []) {
  return ['MORNING', 'AFTERNOON'].map((shift) => {
    const field = shift === 'MORNING' ? 'am_planned_crew_count' : 'pm_planned_crew_count';
    const tasks = assignments.filter(item => item.shift_code === shift);
    const ids = new Set(tasks.map(item => Number(item.setup_work_day_crew_id)));
    crews.filter(crew => crew[field] != null && Number(crew[field]) > 0)
      .forEach(crew => ids.add(Number(crew.setup_work_day_crew_id)));
    let people = 0, unknownCrews = 0, requiredKnown = 0, requiredUnknown = 0;
    let durationMinutes = 0, durationUnknown = 0;
    for (const taskAssignment of tasks) {
      const task = taskRows.find(row => Number(row.setup_session_task_id) === Number(taskAssignment.setup_session_task_id));
      const raw = task?.expected_duration_minutes ?? taskAssignment.expected_duration_minutes;
      const duration = raw == null || raw === '' ? NaN : Number(raw);
      if (Number.isFinite(duration) && duration > 0) durationMinutes += duration;
      else durationUnknown++;
    }
    ids.forEach(id => {
      const crew = crews.find(item => Number(item.setup_work_day_crew_id) === id);
      const crewTasks = tasks.filter(item => Number(item.setup_work_day_crew_id) === id);
      const mins = crewTasks.map(item => {
        const task = taskRows.find(row => Number(row.setup_session_task_id) === Number(item.setup_session_task_id));
        const raw = task?.normal_crew_min ?? item.normal_crew_min;
        return raw == null || raw === '' ? NaN : Number(raw);
      });
      if (mins.length) {
        const valid = mins.filter(value => Number.isFinite(value) && value >= 1);
        if (valid.length) requiredKnown += Math.max(...valid);
        if (valid.length !== mins.length) requiredUnknown++;
      }
      if (crew?.[field] == null || crew[field] === '') unknownCrews++;
      else if (Number(crew[field]) > 0) people += Number(crew[field]);
    });
    const staffing = unknownCrews
      ? (people > 0 ? `${people} known volunteers + ${unknownCrews} unconfirmed crew(s)` : `${unknownCrews} unconfirmed crew(s); volunteers TBD`)
      : `${people} volunteers planned`;
    const minimum = requiredUnknown
      ? (requiredKnown ? `${requiredKnown} known minimum + ${requiredUnknown} TBD` : 'minimum crew TBD')
      : `${requiredKnown} minimum needed`;
    const taskHours = durationUnknown && durationMinutes === 0
      ? 'task duration TBD'
      : `${(durationMinutes / 60).toFixed(1)} known task-hours${durationUnknown ? ` + ${durationUnknown} duration(s) TBD` : ''}`;
    return `${shift === 'MORNING' ? 'AM' : 'PM'}: ${ids.size} crews · ${tasks.length} tasks · ${staffing} / ${minimum} · ${taskHours}`;
  }).join('\n') + (assignments.some(item => item.shift_code === 'ALL_DAY')
    ? ` · All Day: ${assignments.filter(item => item.shift_code === 'ALL_DAY').length} tasks` : '');
}

// Use the existing Captain scope and authorized board response. No identity lookup
// or hidden-day expansion is required to discover an outstanding report.
function nextLateWorkSummary(assignments, board) {
  const late = assignments.filter((item) => {
    const day = (board.work_days || []).find((d) => Number(d.setup_work_day_id) === Number(item.setup_work_day_id));
    return nextAssignmentLate(item, day?.work_date || item.work_date);
  });
  if (!late.length) return '';
  return `<section aria-label="Late unreported work">${nextScheduleWarning(`${late.length} LATE / UNREPORTED TASKS`)}${late.map((item) => {
    const crew = (board.crews || []).find((c) => Number(c.setup_work_day_crew_id) === Number(item.setup_work_day_crew_id));
    const day = (board.work_days || []).find((d) => Number(d.setup_work_day_id) === Number(item.setup_work_day_id));
    const captain = crew?.captain_display_name || 'CAPTAIN TBD';
    return `<div style="border-left:5px solid #a40000;padding:10px;margin-bottom:8px">${nextScheduleWarning(`Captain: ${captain} — LATE / UNREPORTED`)}<strong>${escapeHtml(item.task_name || 'Task')}</strong> · ${escapeHtml(day?.work_date || item.work_date || '')} · Crew ${escapeHtml(crew?.crew_code || item.crew_lane || 'TBD')} · ${escapeHtml(item.shift_code === 'MORNING' ? 'AM' : item.shift_code === 'AFTERNOON' ? 'PM' : 'All Day')}<br><button type="button" class="small next-late-report" data-assignment-id="${Number(item.setup_work_day_task_id)}">Report Work</button></div>`;
  }).join('')}</section>`;
}


/* #205 Whole-Setup deadline dashboard. Read-only; annual tasks are counted once.
   A historical assignment report does not imply annual-task completion. */
function setup205DeadlineKpiModel(board, year, today = nextSetupLocalDate()) {
  const tasks = [...new Map((board.tasks || []).filter(t => t.setup_session_task_id != null)
    .map(t => [Number(t.setup_session_task_id), t])).values()];
  const incomplete = tasks.filter(t => !t.effective_complete);
  const complete = tasks.filter(t => Boolean(t.effective_complete));
  const deferred = incomplete.filter(t => t.execution_status === 'DEFERRED');
  const actionable = incomplete.filter(t => t.execution_status !== 'DEFERRED');
  // Only a current/future unworked assignment is a continuation. An old missed
  // occurrence remains a reporting obligation, not an active schedule.
  const scheduled = actionable.filter(t => Number(t.future_assignment_count || 0) > 0);
  const needsRescheduling = actionable.filter(t => t.execution_status === 'IN_PROGRESS' && Number(t.future_assignment_count || 0) === 0);
  const needsFirstScheduling = actionable.filter(t => t.execution_status !== 'IN_PROGRESS' && Number(t.future_assignment_count || 0) === 0);
  const notReady = actionable.filter(t => t.readiness_state === 'NOT_READY');
  const blocked = actionable.map(t => {
    const reasons = [];
    if (t.prerequisites_complete === false) reasons.push('Incomplete prerequisite');
    if (t.linked_work_order_gate && t.linked_work_order_id && !t.linked_work_order_completed_at) reasons.push('Open Work Order gate');
    if (t.readiness_state === 'NOT_READY') reasons.push('NOT READY');
    return {task: t, reasons};
  }).filter(t => t.reasons.length);
  const assignments = board.assignments || [];
  const dayById = new Map((board.work_days || []).map(d => [Number(d.setup_work_day_id), d]));
  const overdue = assignments.filter(a => {
    const day = dayById.get(Number(a.setup_work_day_id));
    const date = a.work_date || day?.work_date;
    // A cancelled day has no historical reporting obligation.
    return date && date < today && String(day?.day_status || a.day_status || '').toUpperCase() !== 'CANCELLED'
      && Number(a.work_report_count || 0) === 0;
  });
  const partial = actionable.filter(t => Number(t.percent_complete || 0) > 0 && Number(t.percent_complete || 0) < 100);
  const lateNoReportTaskCount = new Set(overdue.map(a => Number(a.setup_session_task_id))).size;
  const due = setupAnnualMilestoneDates(year)?.setupComplete;
  const deadline = due ? due.toISOString().slice(0, 10) : null;
  const epochDay = d => Date.parse(d + 'T00:00:00Z') / 86400000;
  const daysLeft = deadline ? Math.max(0, epochDay(deadline) - epochDay(today)) : null;
  const required = daysLeft > 0 ? actionable.length / daysLeft : null;
  // The rolling schedule has not committed every future workday.
  // Non-Sunday days are potential workdays, not confirmed staffed days.
  const datesBetween = (from, to) => {
    const out = [];
    for (let day = epochDay(from); day <= epochDay(to); day++) {
      out.push({date: new Date(day * 86400000).toISOString().slice(0, 10),
        sunday: new Date(day * 86400000).getUTCDay() === 0});
    }
    return out;
  };
  const futureDays = deadline && today < deadline
    ? datesBetween(new Date((epochDay(today) + 1) * 86400000).toISOString().slice(0, 10), deadline) : [];
  const potentialWorkdays = futureDays.filter(d => !d.sunday).length;
  const scheduledWorkdays = new Set((board.work_days || [])
    .filter(d => String(d.day_status || '').toUpperCase() !== 'CANCELLED')
    .map(d => d.work_date).filter(d => d && d > today && d <= deadline)).size;
  const requiredPerPotentialWorkday = potentialWorkdays > 0 ? actionable.length / potentialWorkdays : null;
  const windowStart = new Date((epochDay(today) - 6) * 86400000).toISOString().slice(0, 10);
  let recent = 0, recentNonSunday = 0, undated = 0, futureDated = 0;
  for (const t of complete) {
    // The repository supplies only verified work dates (100% performed_on)
    // and completed linked WO dates. NEVER use the entry/audit timestamp.
    const date = String(t.completion_work_date || '').slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(epochDay(date))) {
      undated++; continue;
    }
    if (date > today) { futureDated++; undated++; continue; }
    if (date >= windowStart) {
      recent++;
      if (new Date(date + 'T00:00:00Z').getUTCDay() !== 0) recentNonSunday++;
    }
  }
  const pace = recent / 7;
  const recentPotentialWorkdays = datesBetween(windowStart, today).filter(d => !d.sunday).length;
  const workdayPace = recentPotentialWorkdays ? recentNonSunday / recentPotentialWorkdays : null;
  // A task whose completion date cannot be established must never produce a green forecast.
  // One lucky completion cannot justify an on-track claim for a season.
  // Require seven distinct dated annual completions in the explicit 7-day
  // window, as well as complete provenance, before giving any projection.
  const reliable = undated === 0 && recent >= 7;
  const projectedDays = reliable ? Math.ceil(actionable.length / pace) : null;
  const projectedFinish = projectedDays == null ? null :
    new Date((epochDay(today) + projectedDays) * 86400000).toISOString().slice(0, 10);
  return {tasks, incomplete, complete, deferred, actionable, blocked, notReady,
    scheduled, needsRescheduling, needsFirstScheduling, overdue, lateNoReportTaskCount, partial,
    deadline, daysLeft, required, potentialWorkdays, scheduledWorkdays, requiredPerPotentialWorkday,
    recent, recentNonSunday, recentSunday: recent - recentNonSunday,
    recentPotentialWorkdays, workdayPace, pace, undated, futureDated, reliable, projectedFinish};
}

function setup205ManagementReportHtml(board, year) {
  const k = setup205DeadlineKpiModel(board, year);
  const safe = v => escapeHtml(String(v ?? ''));
  const n = (x) => x == null ? '—' : x.toFixed(2);
  const fmt = d => d || 'Unavailable';
  const canManage = Boolean(appState.access?.can_manage_setup);
  const action = (type, id, caption) => canManage && Number(id) > 0
    ? ' <button type="button" class="small secondary setup205-action" data-205-action="' +
       type + '" data-id="' + Number(id) + '">' + safe(caption) + '</button>' : '';
  const dependencyReasons = task => (board.dependencies || [])
    .filter(d => Number(d.setup_session_task_id) === Number(task.setup_session_task_id)
      && d.prerequisite_complete !== true)
    .map(d => d.prerequisite_task_name || ('Prerequisite task ' + (d.prerequisite_setup_session_task_id || 'unresolved')));
  const blockerRows = k.blocked.map(({task, reasons}) =>
    '<li><strong>' + safe(task.task_name || ('Task ' + task.setup_session_task_id)) +
    '</strong> — ' + safe(reasons.map(reason =>
      reason === 'Incomplete prerequisite'
        ? reason + ': ' + (dependencyReasons(task).join(', ') || 'prerequisite not identified')
        : reason === 'Open Work Order gate'
          ? reason + ' #' + task.linked_work_order_id
          : reason === 'NOT READY'
            ? reason + ': ' + (task.readiness_note || 'reason not documented')
            : reason).join('; ')) + action('planning',task.setup_session_task_id,'Inspect blocker') + '</li>').join('');
  const lateRows = k.overdue.map(a => {
    const task = k.tasks.find(t => Number(t.setup_session_task_id) === Number(a.setup_session_task_id));
    const day = (board.work_days || []).find(d => Number(d.setup_work_day_id) === Number(a.setup_work_day_id));
    const crew = (board.crews || []).find(c => Number(c.setup_work_day_crew_id) === Number(a.setup_work_day_crew_id));
    return '<li>' + safe(task?.task_name || ('Task ' + a.setup_session_task_id)) +
      ' — Setup Day ' + safe(day?.setup_day_number ?? a.setup_day_number ?? '—') +
      ' · ' + safe(a.work_date || day?.work_date || 'unknown') +
      ' · Crew ' + safe(crew?.crew_code || a.crew_lane || '—') +
      ' ' + safe(a.shift_code === 'MORNING' ? 'AM' : a.shift_code === 'AFTERNOON' ? 'PM' : 'All Day') +
      ' · ' + safe(crew?.captain_display_name || 'Captain TBD') +
      ': no report for original assignment' +
      action('report',a.setup_work_day_task_id,'Open original work report') + '</li>';
  }).join('');
  const taskList = (rows, actionType) => rows.map(t => '<li><strong>' +
    safe(t.task_name || ('Task ' + t.setup_session_task_id)) + '</strong> — ' +
    safe([t.stage_name || t.stage_key || 'Site-wide', t.scene_name].filter(Boolean).join(' / ')) +
    ' · ' + safe(t.percent_complete == null ? 'progress unknown' : t.percent_complete + '% reported') +
    action(actionType,t.setup_session_task_id,actionType === 'schedule' ? 'Schedule task' : 'Review task') +
    '</li>').join('');
  const details = (label, tasks, note, actionType = 'planning') =>
    '<details><summary>' + safe(label) + ' (' + tasks.length +
    ')</summary>' + (note ? '<p>' + safe(note) + '</p>' : '') +
    (canManage ? '<ul>' + (taskList(tasks,actionType) || '<li>None</li>') + '</ul>'
               : '<p>Manager task details require Setup Manager access.</p>') + '</details>';
  const dateStatus = !k.deadline ? 'Deadline unavailable'
    : !k.actionable.length ? 'All non-deferred tasks complete'
    : k.daysLeft === 0 ? 'Hard deadline reached with unfinished work'
    : !k.reliable ? 'Insufficient verified work-date evidence or 7-day sample to forecast'
    : k.projectedFinish > k.deadline ? 'Task-count estimate beyond deadline; confirm staffing' : 'Task-count estimate only; future staffing/weather unknown';
  // A schedule is an operational workspace, not a dashboard report.
  // Keep the season-wide progress and deadline always visible but place detailed
  // KPI reasons / Manager actions behind a CLOSED disclosure by default.
  const glance = '<div class="setup205-kpi-glance" aria-label="Whole Setup progress at a glance">' +
    '<span>Total <strong>' + k.tasks.length + '</strong></span>' +
    '<span>Completed <strong>' + k.complete.length + '</strong></span>' +
    '<span>Remaining <strong>' + k.incomplete.length + '</strong></span>' +
    '<span>Blocked / NOT READY <strong>' + k.blocked.length + '</strong></span>' +
    '<span>Actual last 7 days <strong>' + n(k.pace) + '/day</strong></span>' +
    '<span>Required <strong>' + n(k.required) + '/day</strong></span>' +
    '<span>Deadline <strong>' + safe(fmt(k.deadline)) + '</strong></span>' +
    '<span>Projected finish <strong>' +
      safe(k.reliable ? fmt(k.projectedFinish) : 'INSUFFICIENT DATA') + '</strong></span>' +
    '</div>';
  return '<section class="setup-205-deadline-kpis" aria-label="Whole Setup schedule performance">' +
    glance +
    '<details class="setup205-kpi-expand"><summary>Detailed performance numbers and task categories</summary>' +
    '<div class="setup205-kpi-expanded">' +
    '<div style="font-weight:800;margin-bottom:8px">Setup performance · all tasks (task-count estimates)</div>' +
    '<div style="display:flex;flex-wrap:wrap;gap:18px;margin-bottom:8px">' +
    '<span>Total <strong>' + k.tasks.length + '</strong></span>' +
    '<span>Completed <strong>' + k.complete.length + '</strong></span>' +
    '<span>Remaining <strong>' + k.incomplete.length + '</strong></span>' +
    '<span>Blocked / NOT READY <strong>' + k.blocked.length + '</strong></span>' +
    '<span>Past assignments with no report <strong>' + k.overdue.length + '</strong> (' +
    k.lateNoReportTaskCount + ' tasks)</span>' +
    '<span>NOT READY <strong>' + k.notReady.length + '</strong></span>' +
    '<span>Scheduled <strong>' + k.scheduled.length + '</strong></span>' +
    '<span>Needs rescheduling <strong>' + k.needsRescheduling.length + '</strong></span>' +
    '<span>Unstarted, no future assignment <strong>' + k.needsFirstScheduling.length + '</strong></span>' +
    '<span>Started, unfinished <strong>' + k.partial.length + '</strong></span>' +
    '</div><div style="display:flex;flex-wrap:wrap;gap:18px;margin-bottom:8px">' +
    '<span>Last 7 days: <strong>' + k.recent + '</strong> dated completions · <strong>' + n(k.pace) + '/day</strong></span>' +
    '<span>Required calendar pace: <strong>' + n(k.required) + '/day</strong></span>' +
    '<span>Required potential workday pace: <strong>' + n(k.requiredPerPotentialWorkday) + '/day</strong></span>' +
    '<span>Recent non-Sunday pace: <strong>' + n(k.workdayPace) + '/day</strong> (' + k.recentSunday + ' Sunday completions separately)</span>' +
    '<span>Deadline: <strong>' + safe(fmt(k.deadline)) + '</strong> (' + safe(k.daysLeft == null ? '?' : k.daysLeft) + ' calendar days · ' +
    k.potentialWorkdays + ' possible non-Sunday workdays · ' + k.scheduledWorkdays + ' currently scheduled dates)</span>' +
    '<span>Projected finish: <strong>' + safe(k.reliable ? fmt(k.projectedFinish) : 'INSUFFICIENT DATA') + '</strong></span>' +
    '</div><strong>' + safe(dateStatus) + '</strong>' +
    '<div style="font-size:.88rem;margin-top:6px">Task-count forecast only; tasks vary in size. ' +
    safe(k.undated) + ' completions without usable *physical work dates* (' + safe(k.futureDated) + ' future-dated); ' +
    'completion pace uses distinct completed annual tasks and their Report Work performed-on / completed Work Order dates, never report entry time. ' +
    'Potential workdays exclude Sundays only; they are NOT confirmed crew days. Scheduled dates cover only the rolling plan. ' +
    'Recent non-Sunday pace excludes Sunday completions, including zero-completion weekdays. ' +
    safe(k.deferred.length) + ' deferred tasks included in remaining, excluded from required pace; ' +
    safe(k.partial.length) + ' unfinished tasks show partial progress. Captain filters do not change this summary.</div>' +
    '<details style="margin-top:8px"><summary>Blocked / NOT READY (' + k.blocked.length +
    ') — task and reason</summary>' +
    (canManage ? '<ul>' + (blockerRows || '<li>No recorded readiness blockers</li>') + '</ul>'
               : '<p>Manager task details require Setup Manager access.</p>') + '</details>' +
    (appState.access?.can_manage_setup ? '<details><summary>Past scheduled assignments with no report (' + k.overdue.length +
    ')</summary><ul>' + (lateRows || '<li>None</li>') + '</ul></details>' : '') +
    details('Scheduled', k.scheduled, 'Open the Scheduling Board to view assigned dates and crews.') +
    details('Needs rescheduling', k.needsRescheduling, 'Started work with no active continuation.', 'schedule') +
    details('Unstarted work without a future assignment', k.needsFirstScheduling, 'Includes tasks blocked by prerequisites or not ready; it does not mean every task is ready to schedule.', 'schedule') +
    details('NOT READY', k.notReady, 'Readiness is separate from hard prerequisites.') +
    details('Partially reported', k.partial, 'A progress count, not a scheduling count: a task may also need a new assignment or already be scheduled.') +
    details('Deferred', k.deferred, 'Excluded from required rate, but included in remaining scope.') +
    '</div></details></section>';
}


// Operator-facing summary must not render the Manager worklist over the
// Scheduling Board. All detailed work and explanations live on its own tab.
function setup205DeadlineKpiHtml(board, year) {
  const k = setup205DeadlineKpiModel(board, year);
  const safe = x => escapeHtml(String(x ?? ''));
  const fmt = x => x == null || !Number.isFinite(x) ? '—' : x.toFixed(1);
  const projection = k.reliable && k.projectedFinish
    ? 'Estimate ' + k.projectedFinish : 'Not enough data';
  return '<section class="setup-205-deadline-kpis" aria-label="Setup progress summary">' +
    '<div class="setup205-kpi-glance">' +
      '<span>Total <strong>' + k.tasks.length + '</strong></span>' +
      '<span>Completed <strong>' + k.complete.length + '</strong></span>' +
      '<span>Remaining <strong>' + k.incomplete.length + '</strong></span>' +
      '<span>Need attention <strong>' + k.blocked.length + '</strong></span>' +
      '<span>Actual last 7 days <strong>' + fmt(k.pace) + '/day</strong></span>' +
      '<span>Required <strong>' + fmt(k.required) + '/day</strong></span>' +
      '<span>Deadline <strong>' + safe(k.deadline || 'Unavailable') + '</strong></span>' +
      '<span>Projected finish <strong>' + safe(projection) + '</strong></span>' +
      (appState.access?.can_manage_setup
        ? '<button type="button" class="small secondary setup205-open-action-center">Manager Action Center →</button>'
        : '') +
    '</div></section>';
}

async function loadSetup205ActionCenter() {
  if (!appState.access?.can_manage_setup) return;
  const target = document.getElementById('setup205-manager-report');
  if (!target) return;
  target.textContent = 'Loading current Setup actions…';
  try {
    const payload = await api('api/setup/scheduling-board?season_year=' +
      encodeURIComponent(appState.seasonYear));
    if (!appState.access?.can_manage_setup) return;
    const board = payload.board || {};
    setup205WireActionCenter(target);
    target.innerHTML = setup205ActionCenterHtml(board) +
      setup205ManagementReportHtml(board, appState.seasonYear);
  } catch (error) {
    target.textContent = 'Unable to load current Setup actions: ' + (error.message || error);
    setAlert(error.message || error, 'error');
  }
}

function setup205WireManagementNavigation(root) {
  if (!root || root.dataset.setup205NavInstalled === '1') return;
  root.dataset.setup205NavInstalled = '1';
  root.addEventListener('click', event => {
    const button = event.target.closest('.setup205-open-action-center');
    if (!button || !root.contains(button) || !appState.access?.can_manage_setup) return;
    event.preventDefault();
    void navigateSetupView('action-center');
  });
}

// Manager-only #205 Action Center: one source classifier shared by both pages.
// No email or history writes happen from this read-only worklist.
function setup205ActionCenterHtml(board, model) {
  if (!appState.access?.can_manage_setup) return '';
  const k = model || setup205DeadlineKpiModel(board, appState.seasonYear);
  const safe = value => escapeHtml(String(value ?? ''));
  const taskById = new Map(k.tasks.map(t => [Number(t.setup_session_task_id), t]));
  const crewById = new Map((board.crews || []).map(c => [Number(c.setup_work_day_crew_id), c]));
  const dayById = new Map((board.work_days || []).map(d => [Number(d.setup_work_day_id), d]));
  const today = nextSetupLocalDate();
  const dayPlus = n => new Date(Date.parse(today + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10);
  const imminentThrough = dayPlus(7);
  const context = t => [
    t?.stage_name || t?.stage_key || 'Site-wide',
    t?.scene_name || null
  ].filter(Boolean).join(' / ');
  const assignmentLabel = a => {
    const t = taskById.get(Number(a.setup_session_task_id));
    const d = dayById.get(Number(a.setup_work_day_id));
    const c = crewById.get(Number(a.setup_work_day_crew_id));
    const shift = a.shift_code === 'MORNING' ? 'AM' : a.shift_code === 'AFTERNOON' ? 'PM' : 'All Day';
    return '<strong>' + safe(t?.task_name || a.task_name || 'Task') + '</strong> · ' +
      safe(context(t)) + ' · Setup Day ' + safe(d?.setup_day_number ?? a.setup_day_number ?? '—') +
      ' / ' + safe(a.work_date || d?.work_date || 'unknown date') + ' · Crew ' +
      safe(c?.crew_code || a.crew_lane || '—') + ' ' + safe(shift) +
      ' · ' + safe(c?.captain_display_name || 'Captain TBD');
  };
  const button = (action, id, label) => '<button type="button" class="small secondary setup205-action" data-205-action="' +
    action + '" data-id="' + Number(id) + '">' + safe(label) + '</button>';
  const section = (title, rows, explanatory) => '<details class="setup205-action-group"><summary>' +
    safe(title) + ' (' + rows.length + ')</summary><p class="muted">' + safe(explanatory) +
    '</p><ul>' + (rows.length ? rows.map(x => '<li>' + x + '</li>').join('') : '<li>None</li>') +
    '</ul></details>';
  const missed = k.overdue.map(a => '<span>' + assignmentLabel(a) +
    ' — No matched report for this original occurrence. ' +
    button('report',a.setup_work_day_task_id,
      taskById.get(Number(a.setup_session_task_id))?.effective_complete
        ? 'Review original / Correct report' : 'Review original / Report Work') + '</span>');
  const continuations = k.needsRescheduling.map(t => '<strong>' + safe(t.task_name) +
    '</strong> · ' + safe(context(t)) + ' · ' + safe(t.percent_complete ?? 0) +
    '% reported; no current/future continuation. ' +
    button('schedule',t.setup_session_task_id,'Plan continuation'));
  const imminent = (board.assignments || []).filter(a => {
    const d = dayById.get(Number(a.setup_work_day_id));
    const date = a.work_date || d?.work_date;
    const t = taskById.get(Number(a.setup_session_task_id));
    return t && !t.effective_complete && date && date >= today && date <= imminentThrough &&
      String(d?.day_status || a.day_status || '').toUpperCase() !== 'CANCELLED' &&
      (t.prerequisites_complete === false ||
       (t.linked_work_order_gate && t.linked_work_order_id && !t.linked_work_order_completed_at) ||
       t.readiness_state === 'NOT_READY');
  }).map(a => {
    const t = taskById.get(Number(a.setup_session_task_id));
    const reasons = [
      ...(t.prerequisites_complete === false ? ['hard predecessor'] : []),
      ...(t.linked_work_order_gate && t.linked_work_order_id && !t.linked_work_order_completed_at ? ['open Work Order gate'] : []),
      ...(t.readiness_state === 'NOT_READY' ? ['NOT READY: ' + (t.readiness_note || 'reason not documented')] : [])
    ];
    return assignmentLabel(a) + ' — ' + safe(reasons.join('; ')) +
      ' ' + button('planning',t.setup_session_task_id,'Review readiness');
  });
  // Real scheduled execution consumes elapsed linear time in each crew/shift.
  // Avoid treating logistics-only Pick demand or unestimated work as free capacity.
  const workloadGroups = new Map();
  for (const a of board.assignments || []) {
    const d = dayById.get(Number(a.setup_work_day_id));
    const date = a.work_date || d?.work_date;
    if (!date || date < today || date > imminentThrough ||
        String(d?.day_status || a.day_status || '').toUpperCase() === 'CANCELLED' ||
        a.historical_locked) continue;
    const key = [a.setup_work_day_id,a.setup_work_day_crew_id,a.shift_code].join(':');
    if (!workloadGroups.has(key)) workloadGroups.set(key,{date,day:d,crew:crewById.get(Number(a.setup_work_day_crew_id)),
      shift:a.shift_code,items:[],known:0,unknown:0});
    const g = workloadGroups.get(key);
    const t = taskById.get(Number(a.setup_session_task_id));
    const mins = Number(t?.expected_duration_minutes);
    if (t?.expected_duration_minutes == null || !Number.isFinite(mins) || mins <= 0) g.unknown++;
    else g.known += mins;
    g.items.push(t?.task_name || a.task_name || 'Task');
  }
  const allCapacityGroups = [...workloadGroups.values()];
  const overCapacity = allCapacityGroups
    .filter(g => g.known > (g.shift === 'MORNING' ? 180 : g.shift === 'AFTERNOON' ? 120 : 300))
    .sort((a,b) => a.date.localeCompare(b.date))
    .map(g => {
      const max = g.shift === 'MORNING' ? 180 : g.shift === 'AFTERNOON' ? 120 : 300;
      const pm = allCapacityGroups.find(p => p.day?.setup_work_day_id === g.day?.setup_work_day_id &&
        p.crew?.setup_work_day_crew_id === g.crew?.setup_work_day_crew_id &&
        p.shift === 'AFTERNOON');
      const pmCount = Number(g.crew?.pm_planned_crew_count || 0);
      const amCount = Number(g.crew?.am_planned_crew_count || 0);
      const canReviewPm = g.shift === 'MORNING' && amCount > 0 && pmCount > 0 &&
        g.known + (pm?.known || 0) <= 300;
      const status = canReviewPm ? 'AM pressure — PM continuation requires review'
        : g.shift === 'MORNING' && (!amCount || !pmCount)
          ? 'AM pressure — PM staffing unconfirmed; Manager scheduling review needed'
          : 'Shift overload';
      return '<strong>' + safe(g.date) + ' · Setup Day ' + safe(g.day?.setup_day_number ?? '—') +
        ' · Crew ' + safe(g.crew?.crew_code || '—') + ' · ' + safe(g.shift) + '</strong> — ' +
        safe(status) + ': ' +
        safe((g.known/60).toFixed(2)) + ' planned linear hours / ' + safe((max/60).toFixed(2)) +
        ' typical shift hours; ' + safe(g.unknown) + ' tasks lack duration. ' +
        safe(g.items.join(', ')) + ' ' +
        button('day',g.day?.setup_work_day_id,'Review shift capacity');
    });
  const captainTbd = (board.assignments || []).filter(a => {
    const d = dayById.get(Number(a.setup_work_day_id));
    const date = a.work_date || d?.work_date;
    return date && date >= today &&
      String(d?.day_status || a.day_status || '').toUpperCase() !== 'CANCELLED' &&
      !crewById.get(Number(a.setup_work_day_crew_id))?.captain_person_id;
  }).map(a => assignmentLabel(a) + ' ' +
    button('day',a.setup_work_day_id,'Assign / review Captain'));
  return '<section class="setup205-action-center" aria-label="Manager Setup Action Center" ' +
    'style="border-top:2px solid #647888;margin-top:12px;padding-top:12px">' +
    '<h3>Manager Setup Action Center</h3>' +
    '<p><strong>' + k.overdue.length + ' past assignments to check</strong> · ' +
      '<strong>' + k.needsRescheduling.length + ' started tasks without future work</strong> · ' +
      '<strong>' + k.notReady.length + ' tasks marked NOT READY</strong></p>' +
    '<details class="setup205-action-help"><summary>What do these task counts mean?</summary>' +
      '<p>These categories overlap and must not be added together. ' +
      k.blocked.length + ' different unfinished tasks need a prerequisite, Work Order or readiness decision; ' +
      k.notReady.length + ' are explicitly marked NOT READY (possibly also blocked for another reason). ' +
      k.needsFirstScheduling.length + ' unstarted tasks have no future assignment, including blocked work. ' +
      k.partial.length + ' unfinished tasks have progress reported; ' +
      k.needsRescheduling.length + ' started tasks lack a future continuation. ' +
      'A partial task may already have a future schedule. No-work moves are different from missing actual reports.</p>' +
    '</details>' +
    '<p class="muted">Choose a task below to report actual work, move an assignment where no work happened, ' +
    'or plan unfinished work. Reported history is protected; a confirmed no-work reschedule preserves the original schedule in the audit. ' +
    'No email is sent from this screen.</p>' +
    section('Past occurrences awaiting reports',missed,'Includes unresolved older work periods, even if the annual task later completed or moved.') +
    section('Incomplete tasks needing continuation',continuations,'A reported partial work period is not the same as a future assignment.') +
    section('Upcoming scheduled readiness exceptions (7 days)',imminent,'Hard prerequisite/Work Order gates and independent NOT READY conditions can overlap.') +
    section('Upcoming linear-hour overloads (7 days)',overCapacity,'These crews have more planned task duration than the shift permits, before weather, travel or unestimated tasks. This is not available labor forecast.') +
    section('Scheduled assignments without Captain',captainTbd,'A Captain TBD or unverified organizational mailbox must be followed up by a Manager.') +
    '</section>';
}

// The same action buttons work on Schedule and Perform Work without inventing
// unaccepted external URL parameters. All writes remain in existing guarded UI.
function setup205WireActionCenter(root) {
  if (!root || root.dataset.setup205ActionsInstalled === '1') return;
  root.dataset.setup205ActionsInstalled = '1';
  root.addEventListener('click', async event => {
    const button = event.target.closest('.setup205-action[data-205-action]');
    if (!button || !root.contains(button)) return;
    event.preventDefault();
    event.stopPropagation();
    if (!appState.access?.can_manage_setup) return;
    const id = Number(button.dataset.id);
    if (!Number.isSafeInteger(id) || id < 1) return;
    try {
      if (button.dataset['205Action'] === 'report') {
        if (await navigateSetupView('perform') === false) return;
        // A Manager may see all Captains and historic reported occurrences.
        setupNextState.performCaptainFilter = 'ALL';
        setupNextState.performCaptainFilterTouched = true;
        const showAll = document.getElementById('next-perform-show-completed');
        if (showAll) showAll.checked = true;
        renderNextExecution();
        const details = [...document.querySelectorAll('#next-perform-list .next-perform-assignment')]
          .find(node => Number(node.dataset.assignmentId) === id);
        if (!details) throw new Error('Original assignment not visible. Verify the 2026 Session and refresh.');
        const dayContent = details.closest('.next-perform-day-content');
        if (dayContent?.hidden) {
          dayContent.hidden = false;
          const toggle = dayContent.closest('.next-perform-day')?.querySelector('.next-perform-toggle-complete-day');
          if (toggle) toggle.setAttribute('aria-expanded','true');
        }
        details.open = true;
        details.scrollIntoView({block:'center',behavior:'auto'});
        await loadNextTaskExecution(details,false);
        details.querySelector('.next-performed-on')?.focus();
      } else if (button.dataset['205Action'] === 'schedule' ||
                 button.dataset['205Action'] === 'planning') {
        if (await navigateSetupView('schedule') === false) return;
        if (button.dataset['205Action'] === 'schedule') {
          board205OpenScheduleDialog({kind:'task',id});
        } else {
          board205OpenPlanningInfoDialog(id);
        }
      } else if (button.dataset['205Action'] === 'day') {
        const d = (setupBoard205State.board.work_days || []).find(x => Number(x.setup_work_day_id) === id);
        if (await navigateSetupView('schedule') === false) return;
        if (d) board205FocusWorkDate(d.work_date);
      }
    } catch (error) {
      setAlert(error.message || String(error),'error');
    }
  });
}

function renderNextExecution() {
  const target = el('next-perform-list');
  if (!target) return;
  const board = setupNextState.performBoard || {};
  nextEnsurePerformToolbar();
  nextRenderPerformCaptainFilter();
  const allAssignments = (board.assignments || []).slice();
  const scopedAssignments = nextPerformCaptainScopedAssignments(allAssignments);
  const assignments = nextFilterPerformAssignments(allAssignments);
  const labor = nextPerformLaborKpis(scopedAssignments);
  const summary = el('next-perform-filter-summary');
  if (summary) {
    summary.textContent = assignments.length === allAssignments.length
      ? `${assignments.length} scheduled assignment${assignments.length === 1 ? '' : 's'}`
      : `${assignments.length} of ${allAssignments.length} scheduled assignments shown`;
  }

  const kpis = el('next-perform-kpis');
  if (kpis) {
    const varianceReady = labor.completedCount > 0 && labor.completedPlannedUnknown === 0;
    const varianceValue = varianceReady
      ? Number(labor.completedActualHours) - Number(labor.completedPlannedHours)
      : null;
    const varianceText = varianceReady
      ? `${varianceValue > 0 ? '+' : ''}${Number.isInteger(varianceValue) ? varianceValue : varianceValue.toFixed(1)} hr`
      : 'TBD';
    const plannedNote = labor.plannedUnknown
      ? `${labor.plannedUnknown} assignment${labor.plannedUnknown === 1 ? '' : 's'} with staffing/duration TBD; known person-hours are partial`
      : 'all assignments in Captain scope estimated';
    const varianceNote = labor.completedCount === 0
      ? 'no completed assignments in Captain scope'
      : labor.completedPlannedUnknown
        ? `${labor.completedPlannedUnknown} completed assignment${labor.completedPlannedUnknown === 1 ? '' : 's'} missing plan estimate`
        : `Completed: ${labor.completedActualHours} hr actual vs ${labor.completedPlannedHours} hr planned`;
    kpis.innerHTML = `
      <div class="next-perform-kpi"><span>Planned labor</span><strong>${escapeHtml(labor.plannedHours === 'TBD' ? 'TBD' : labor.plannedHours + ' hr')}</strong><small>${escapeHtml(plannedNote)}</small></div>
      <div class="next-perform-kpi"><span>Actual labor</span><strong>${escapeHtml(labor.actualHours)} hr</strong><small>reported work in Captain scope</small></div>
      <div class="next-perform-kpi"><span>Completed-work variance</span><strong>${escapeHtml(varianceText)}</strong><small>${escapeHtml(varianceNote)}</small></div>
    `;
  }
  const days = (board.work_days || []).filter((day) =>
    assignments.some((assignment) => Number(assignment.setup_work_day_id) === Number(day.setup_work_day_id))
  );

  // The whole-season progress and Manager exceptions outrank filtered labor,
  // individual Captain cards and milestone detail on the Perform Work screen.
  const globalKpis = el('next-perform-global-kpis');
  if (globalKpis) {
    setup205WireManagementNavigation(globalKpis);
    globalKpis.innerHTML = setup205DeadlineKpiHtml(board, appState.seasonYear);
  } else {
    setup205WireManagementNavigation(target); // compatibility with older static fixtures
  }
  target.innerHTML = (globalKpis ? '' : setup205DeadlineKpiHtml(board, appState.seasonYear)) +
    nextLateWorkSummary(scopedAssignments, board) + (days.length ? days.map((day) => {
    const dayAssignments = assignments.filter(
      (assignment) => Number(assignment.setup_work_day_id) === Number(day.setup_work_day_id)
    );
    // Evaluate the entire day, not a Captain-filtered subset that could hide late work.
    const wholeDay = allAssignments.filter((item) => Number(item.setup_work_day_id) === Number(day.setup_work_day_id));
    const dayCanCollapse = day.work_date < nextSetupLocalDate()
      && wholeDay.length > 0 && wholeDay.every(nextAssignmentReported);
    const lateCount = wholeDay.filter((item) => nextAssignmentLate(item, day.work_date)).length;
    const scopedDayAssignments = scopedAssignments.filter((item) => Number(item.setup_work_day_id) === Number(day.setup_work_day_id));
    const reportedPersonHours = (scopedDayAssignments.reduce((sum, item) => sum + Number(item.actual_person_minutes || 0), 0) / 60).toFixed(1);
    const shifts = ['MORNING', 'AFTERNOON', 'ALL_DAY'];
    return `
      <section class="next-perform-day">
        ${dayCanCollapse ? `<button type="button" class="small secondary next-perform-toggle-complete-day" aria-expanded="false">▶ SETUP DAY ${escapeHtml(day.setup_day_number ?? '—')} · ${escapeHtml(day.work_date)} · ${dayAssignments.length} reported assignments · ${reportedPersonHours} reported person-hours</button>` : ''}
        <div class="next-perform-day-content" ${dayCanCollapse ? 'hidden' : ''}>
        <div style="border-top:5px solid var(--accent, #466a86);padding:12px 0;margin-top:22px;display:flex;justify-content:space-between;gap:12px;align-items:center;flex-wrap:wrap">
          <h3 style="margin:0;font-size:1.25rem">SETUP DAY ${escapeHtml(day.setup_day_number ?? '—')} · ${escapeHtml(day.day_of_week || '')} · ${escapeHtml(day.work_date)}</h3>
          ${appState.access?.can_manage_setup ? `<button type="button" class="small secondary next-perform-manage-day" data-work-date="${escapeHtml(day.work_date)}">Manage Schedule →</button>` : ''}
        </div>
        ${lateCount ? nextScheduleWarning(`${lateCount} LATE TASK${lateCount === 1 ? '' : 'S'} — NO WORK REPORTED`) : ''}
        ${(() => {
          const crewShifts = ['MORNING', 'AFTERNOON'].flatMap((shift) =>
            [...new Set(dayAssignments.filter((a) => a.shift_code === shift).map((a) => Number(a.setup_work_day_crew_id)))]
              .map((id) => nextPerformShiftWorkload(dayAssignments.filter((a) => a.shift_code === shift && Number(a.setup_work_day_crew_id) === id), shift))
          );
          const overloaded = crewShifts.filter((w) => w.overload > 0).length;
          const unknown = crewShifts.reduce((n, w) => n + w.unknown, 0);
          const notReady = crewShifts.reduce((n, w) => n + w.notReady, 0);
          const color = overloaded ? '#9d2424' : unknown || notReady ? '#835900' : '#146044';
          return `<div role="status" style="border:3px solid ${color};border-radius:8px;padding:12px;margin:8px 0;background:var(--surface, #f7f7f7);font-size:1.05rem;font-weight:700;white-space:pre-line">
            ${escapeHtml(nextDayStaffingSummary(scopedAssignments.filter((a) => Number(a.setup_work_day_id) === Number(day.setup_work_day_id)), (board.crews || []).filter((c) => Number(c.setup_work_day_id) === Number(day.setup_work_day_id) && (setupNextState.performCaptainFilter === 'ALL' || Number(c.captain_person_id) === Number(String(setupNextState.performCaptainFilter).split(':')[1]))), board.tasks || []))}<br>${day.work_date < nextSetupLocalDate() ? `${scopedDayAssignments.filter(nextAssignmentReported).length} tasks reported · ${reportedPersonHours} actual person-hours reported so far` : ''}${overloaded || unknown || notReady ? '<br>Warnings:' : ''}${overloaded ? ` ${overloaded} crew shifts overloaded` : ''}${unknown ? ` · ${unknown} missing time estimates` : ''}${notReady ? ` · ${notReady} tasks not ready` : ''}
          </div>`;
        })()}
        ${shifts.map((shift) => {
          const shiftItems = dayAssignments.filter((assignment) => assignment.shift_code === shift);
          if (!shiftItems.length) return '';
          const crewIds = [...new Set(shiftItems.map((assignment) => Number(assignment.setup_work_day_crew_id)))];
          return `
            <div class="next-perform-shift">
              <h4>${escapeHtml(shift === 'MORNING' ? 'AM' : shift === 'AFTERNOON' ? 'PM' : 'All Day')}</h4>
              ${appState.access?.can_manage_setup && shift !== 'ALL_DAY' &&
                shiftItems.some(a => nextCanRescheduleNoWork(a))
                ? '<button type="button" class="small secondary next-reschedule-unworked-shift" data-day-id="' +
                  Number(day.setup_work_day_id) + '" data-shift="' + escapeHtml(shift) +
                  '">Reschedule unworked ' + escapeHtml(shift === 'MORNING' ? 'AM' : 'PM') + ' tasks…</button>'
                : ''}
              ${crewIds.map((crewId) => {
                const crew = (board.crews || []).find((item) => Number(item.setup_work_day_crew_id) === crewId);
                const crewItems = shiftItems
                  .filter((assignment) => Number(assignment.setup_work_day_crew_id) === crewId)
                  .sort((a, b) => Number(a.sort_order || 0) - Number(b.sort_order || 0));
                return `
                  <div class="next-perform-crew">
                    <h5>Crew ${escapeHtml(crew?.crew_code || crewItems[0]?.crew_lane || '—')} · ${escapeHtml(crew?.captain_display_name || 'Captain TBD')}</h5>
                    ${crew?.captain_person_id == null ? nextScheduleWarning('CAPTAIN TBD — NEEDS CAPTAIN') : ''}
                    ${nextPerformWorkloadLabel(crewItems, shift)}
                    ${crewItems.map(nextPerformAssignmentCard).join('')}
                  </div>`;
              }).join('')}
            </div>`;
        }).join('')}
        </div>
      </section>`;
  }).join('') : '<div class="empty-state">No scheduled or in-progress assignments match this view. Turn on Show completed to include completed work, or choose All scheduled work to see every Captain.</div>');

  target.querySelectorAll('.next-late-report').forEach((button) => {
    button.addEventListener('click', () => {
      const details = [...target.querySelectorAll('details[data-assignment-id]')].find((item) => item.dataset.assignmentId === button.dataset.assignmentId);
      details?.querySelector('.next-report-work')?.click();
      details?.scrollIntoView({ block: 'center' });
    });
  });

  // Navigate through the existing route to preserve browser history and view guards.
  if (target.dataset.completedDayToggleInstalled !== '1') {
    target.dataset.completedDayToggleInstalled = '1';
    target.addEventListener('click', (event) => {
      const button = event.target.closest('.next-perform-toggle-complete-day');
      if (!button) return;
      const content = button.closest('.next-perform-day').querySelector('.next-perform-day-content');
      content.hidden = !content.hidden;
      button.setAttribute('aria-expanded', String(!content.hidden));
      button.textContent = content.hidden
        ? button.textContent.replace('▼', '▶')
        : button.textContent.replace('▶', '▼');
    });
  }
  // Delegated listener is installed once on the stable Perform Work root.
  // renderNextExecution replaces innerHTML repeatedly; child listeners are fragile.
  if (target.dataset.manageScheduleInstalled !== '1') {
    target.dataset.manageScheduleInstalled = '1';
    target.addEventListener('click', async (event) => {
      const button = event.target.closest('.next-perform-manage-day');
      if (!button) return;
      event.preventDefault();
      event.stopPropagation();
      const date = button.dataset.workDate;
      try {
        const navigated = await navigateSetupView('schedule');
        if (navigated && typeof board205FocusWorkDate === 'function') {
          board205FocusWorkDate(date);
        }
      } catch (error) {
        setAlert(error.message || error, 'error');
      }
    });
  }

  target.querySelectorAll('.next-reschedule-unworked-shift').forEach(button => {
    button.addEventListener('click', event => {
      event.preventDefault();
      nextOpenRescheduleNoWorkBatch(Number(button.dataset.dayId), button.dataset.shift);
    });
  });

  target.querySelectorAll('.next-perform-assignment').forEach((details) => {
    details.querySelector('.next-report-work')?.addEventListener('click', async (event) => {
      event.preventDefault();
      details.open = true;
      await loadNextTaskExecution(details, true);
    });
    details.querySelector('.next-reschedule-no-work')?.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      nextOpenRescheduleNoWorkDialog(Number(details.dataset.assignmentId));
    });
    details.querySelector('.next-report-problem')?.addEventListener('click', async (event) => {
      event.preventDefault();
      await openNextCorrectionIntake(details);
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
  // Include recorded evidence on paper without expanding the live task rows.
  sheet.querySelectorAll('details.setup-location-details').forEach((detail) => { detail.open = true; });
  document.body.classList.add('setup-print-perform-task');

  const cleanup = () => {
    document.body.classList.remove('setup-print-perform-task');
    document.getElementById('setup-perform-print-sheet')?.remove();
  };
  window.addEventListener('afterprint', cleanup, { once: true });
  window.print();
}

function nextLocationText(item) {
  if (item.current_location_inferred && item.current_location_kind === 'UNRESOLVED_FIELD') return 'Current: unloaded — location unresolved';
  if (item.current_stage_key) return `Current: Stage ${item.current_stage_key}${item.current_stage_name ? ` — ${item.current_stage_name}` : ''}${item.current_location_note ? ` · ${item.current_location_note}` : ''}`;
  if (item.current_location_note?.trim()) return `Current: ${item.current_location_note.trim()}`;
  if (item.current_location_kind === 'GPS') {
    // This is a recorded observation, not live GPS or proof of a park boundary.
    const quality = ['QUESTIONABLE', 'BAD'].includes(item.current_gps_quality)
      ? ` · GPS quality ${item.current_gps_quality.toLowerCase()}` : '';
    const reference = item.current_nearest_reference;
    if (reference?.name && Number.isFinite(Number(reference.distance_ft))) {
      // A nearby waypoint is context for the recorded fix, not confirmed placement.
      return `Current: near ${reference.name} (${Math.round(Number(reference.distance_ft))} ft)${quality}`;
    }
    const coordinates = nextRecordedGpsText(item);
    return `Current: GPS ${coordinates || 'observation'}${quality}`;
  }
  if (item.current_location_kind === 'UNRESOLVED_FIELD') {
    // A Pick or other movement can be recorded without a destination or GPS.
    // Show that recorded action without implying that Home is the current place.
    const labels = {
      PICKED: 'Picked', LOADED: 'Loaded', IN_TRANSIT: 'In transit',
      DELIVERED: 'Delivered', UNLOADED: 'Unloaded', TASK_UNLOAD: 'Unloaded',
      STAGED: 'Staged', PLACED: 'Placed', RELOCATED: 'Moved',
      CONTAINER_MOVE: 'Moved', DISPLAY_MOVE: 'Moved', RETURNED: 'Returned',
      DISPLAY_REATTACH: 'Reattached to container'
    };
    const status = item.current_movement_status;
    const movement = Object.prototype.hasOwnProperty.call(labels, status)
      ? labels[status] : 'Movement recorded';
    return `${movement} — current location not recorded`;
  }
  return 'Current location not recorded';
}

function nextRecordedGpsText(item) {
  const lat = item.current_gps_latitude;
  const lon = item.current_gps_longitude;
  if (lat === null || lat === undefined || lat === '' || lon === null || lon === undefined || lon === '') return '';
  const latitude = Number(lat);
  const longitude = Number(lon);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return '';
  return `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`;
}

function nextLocationMarkup(item) {
  const coordinates = nextRecordedGpsText(item);
  const accuracy = item.current_gps_accuracy_m;
  const accuracyText = accuracy !== null && accuracy !== undefined && accuracy !== '' && Number.isFinite(Number(accuracy)) && Number(accuracy) >= 0
    ? `<br>Accuracy: ±${Math.ceil(Number(accuracy) / 0.3048)} ft` : '';
  // Keep the field list compact; native details work with touch and keyboard.
  const recorded = coordinates
    ? ` <details class="setup-location-details"><summary>GPS</summary><span class="muted">Recorded GPS: ${escapeHtml(coordinates)}${accuracyText}</span></details>`
    : '';
  // Home is useful only when a usable recorded GPS location is unavailable.
  const home = !coordinates && item.home_location_code
    ? `<span class="muted"> · Home: ${escapeHtml(item.home_location_code)}</span>` : '';
  const provenance = item.current_location_inferred
    ? ' · inferred unload from prior Container observation'
    : (item.current_named_context_inherited ? ' · earlier named context retained' : '');
  return `<strong>${escapeHtml(nextLocationText(item))}</strong>${escapeHtml(provenance)}${recorded}${home}`;
}

function nextProgressAuditText(progress) {
  if (!progress?.updated_at || !progress?.recorded_at) return '';
  const recorded = new Date(progress.recorded_at).getTime();
  const updated = new Date(progress.updated_at).getTime();
  if (!Number.isFinite(recorded) || !Number.isFinite(updated) || updated - recorded < 1000) return '';
  const who = progress.updated_by_name ? ` by ${progress.updated_by_name}` : '';
  return ` · corrected${who} ${formatTimestamp(progress.updated_at)}`;
}

function nextProgressCorrectionForm(progress) {
  if (!appState.access?.can_manage_setup) return '';
  const duration = Number(progress.duration_minutes || 0);
  const hours = Math.floor(duration / 60);
  const minutes = duration % 60;
  return `
    <details class="next-progress-correction">
      <summary>Correct report</summary>
      <form class="next-progress-correction-form" data-progress-id="${progress.setup_task_progress_id}">
        <div class="next-report-work-grid">
          <label>Work completed on<input class="next-correction-performed-on" type="date" value="${escapeHtml(progress.performed_on || progress.work_date || '')}" required></label>
          <label>Crew size<input class="next-correction-crew" type="number" min="1" value="${escapeHtml(progress.crew_count || '')}" required></label>
          <label>Hours<input class="next-correction-hours" type="number" min="0" step="1" value="${hours}" required></label>
          <label>Minutes<input class="next-correction-minutes" type="number" min="0" max="59" step="1" value="${minutes}" required></label>
          <label>% complete<input class="next-correction-percent" type="number" min="1" max="100" step="1" value="${escapeHtml(progress.percent_complete || '')}" required></label>
        </div>
        <label>What was done / what remains<textarea class="next-correction-note" rows="3">${escapeHtml(progress.progress_note || '')}</textarea></label>
        <details class="next-report-quantity-details">
          <summary>Add quantity detail (optional)</summary>
          <div class="next-report-quantity-grid">
            <label>Completed quantity<input class="next-correction-quantity" type="number" min="1" value="${escapeHtml(progress.completed_quantity || '')}"></label>
            <label>Which units<input class="next-correction-units" type="text" value="${escapeHtml(progress.completed_units || '')}"></label>
          </div>
        </details>
        <button type="submit">Save Correction</button>
      </form>
    </details>
  `;
}

function nextProgressEntryHtml(progress) {
  return `
    <div class="next-progress-entry">
      <div>
        ${escapeHtml(progress.performed_on || progress.work_date || formatTimestamp(progress.recorded_at))}
        · Crew ${escapeHtml(progress.crew_count)}
        ${progress.duration_minutes ? ` · ${escapeHtml(formatMinutes(progress.duration_minutes))}` : ''}
        ${progress.duration_minutes && progress.crew_count ? ` · Labor ${escapeHtml(nextLaborHoursText(progress.crew_count, progress.duration_minutes))}` : ''}
        ${progress.percent_complete ? ` · ${progress.percent_complete}% complete` : ''}
        ${progress.progress_note ? ` · ${escapeHtml(progress.progress_note)}` : ''}
        ${escapeHtml(nextProgressAuditText(progress))}
      </div>
      ${nextProgressCorrectionForm(progress)}
    </div>
  `;
}

async function submitNextProgressCorrection(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const progressId = Number(form.dataset.progressId);
  const performedOn = form.querySelector('.next-correction-performed-on').value;
  const crew = Number(form.querySelector('.next-correction-crew').value || 0);
  const hours = Number(form.querySelector('.next-correction-hours').value || 0);
  const minutes = Number(form.querySelector('.next-correction-minutes').value || 0);
  const percent = Number(form.querySelector('.next-correction-percent').value || 0);
  const note = form.querySelector('.next-correction-note').value.trim();
  const durationMinutes = (hours * 60) + minutes;

  if (!performedOn) return window.alert('Work completed on date is required.');
  if (crew < 1) return window.alert('Crew size must be at least 1.');
  if (hours < 0 || minutes < 0 || minutes > 59 || durationMinutes <= 0) {
    return window.alert('Enter the corrected Hours and Minutes worked.');
  }
  if (percent < 1 || percent > 100) return window.alert('Percent complete must be between 1 and 100.');
  if (percent < 100 && !note) return window.alert('For incomplete work, briefly record what was done and what remains.');

  try {
    setBusy(true);
    await api(`api/setup/progress/${progressId}`, commandOptions('PATCH', {
      performed_on: performedOn,
      crew_count: crew,
      duration_minutes: durationMinutes,
      percent_complete: percent,
      completed_quantity: nullableInteger(form.querySelector('.next-correction-quantity').value),
      completed_units: form.querySelector('.next-correction-units').value.trim() || null,
      progress_note: note || null
    }));
    setAlert('Work report corrected.', 'ok');
    await loadNextExecution();
    if (typeof board205Load === 'function') await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
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
    // Field context/resources/procedure are optional references, not a gate
    // for reporting actual labor or progress. Season-only annual tasks may
    // have no reusable setup_task_id at all: never call tasks/NaN or tasks/0.
    const reusableTaskId = Number.isSafeInteger(taskId) && taskId > 0;
    const optional = (promise, fallback) => promise
      .then(payload => ({...payload, contextError:null}))
      .catch(error => ({...fallback, contextError:error}));
    const [contextPayload, resourcePayload, progressPayload, procedureResult] = await Promise.all([
      reusableTaskId
        ? optional(api(`api/setup/tasks/${taskId}/field-context?season_year=${encodeURIComponent(appState.seasonYear)}`),{context:{}})
        : Promise.resolve({context:{},contextError:null}),
      reusableTaskId
        ? optional(api(`api/setup/tasks/${taskId}/resources`),{resources:[]})
        : Promise.resolve({resources:[],contextError:null}),
      // Progress is authoritative. Do NOT treat a failed progress fetch as
      // empty history: it could cause a false new percentage/report.
      api(`api/setup/session-tasks/${sessionTaskId}/progress`),
      reusableTaskId
        ? api(`api/setup/tasks/${taskId}/procedure`)
            .then(payload => ({payload,error:null}))
            .catch(error => ({payload:null,error}))
        : Promise.resolve({payload:null,error:null})
    ]);
    const context = contextPayload.context || {};
    const resources = resourcePayload.resources || [];
    const progress = progressPayload.progress || [];
    const procedurePayload = procedureResult.payload || {};
    const procedureError = procedureResult.error;
    const docs = procedurePayload.instructions?.current_documents || procedurePayload.instructions?.documents || [];
    // Stable Container ID deep links resolve the latest #88 position when opened.
    // The Locate reader owns map focus and handles missing coordinates honestly.
    const containerMapLink = (rawId) => {
      const id = Number(rawId);
      if (!Number.isSafeInteger(id) || id <= 0) return escapeHtml(String(rawId ?? '—'));
      const code = `C${String(id).padStart(3, '0')}`;
      return `<a href="/setup/locate/?container_id=${id}" target="_blank" rel="noopener" title="Show ${code} on Park Map">${code}</a>`;
    };
    const assets = [
      ...(context.displays || []).map((item) => `<li>Display ${item.display_id} — ${escapeHtml(item.display_name)}${item.container_id ? ` · Container ${containerMapLink(item.container_id)}` : ''} · ${nextLocationMarkup(item)}</li>`),
      ...(context.support_containers || []).map((item) => `<li>Support Container ${containerMapLink(item.container_id)} · ${nextLocationMarkup(item)}</li>`)
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
        <section><h4>Equipment / Resources</h4>${resourcePayload.contextError
          ? '<p class="next-procedure-warning">Equipment context unavailable; Report Work is still available.</p>'
          : resources.length ? `<ul>${resources.map((r) => `<li>${escapeHtml(r.resource_name)} · Qty ${r.quantity_required} · ${escapeHtml(r.requirement_type)}</li>`).join('')}</ul>`
            : '<p class="muted">No structured resource requirement recorded.</p>'}</section>
        <section><h4>Material / Current Location</h4>${contextPayload.contextError
          ? '<p class="next-procedure-warning">Location context unavailable; Report Work is still available.</p>'
          : assets.length ? `<ul>${assets.join('')}</ul>`
            : '<p class="muted">No Displays or support Containers are mapped to this task.</p>'}</section>
        <section><h4>Published Setup Procedure</h4>${docs.length
          ? docs.map((doc) => `<p><a target="_blank" rel="noopener" href="api/setup/tasks/${taskId}/procedure/current?name=${encodeURIComponent(doc.name || '')}">${escapeHtml(doc.name || 'Open current PDF')}</a></p>`).join('')
          : procedureError
            ? `<p class="next-procedure-warning"><strong>Procedure context unavailable.</strong> ${escapeHtml(procedureError.message || procedureError)} Report Work remains available.</p>`
            : '<p class="muted">No current Setup Procedure is resolved for this task.</p>'}</section>
      </div>
      <section class="next-progress-history"><h4>Progress history</h4>${progress.length ? progress.map(nextProgressEntryHtml).join('') : '<div class="muted">No progress recorded yet.</div>'}</section>
      ${complete ? '<div class="next-complete-banner">This annual task is complete. Review Progress history above. If an earlier work period has no report, ask a Manager to reconcile the original assignment; do not enter duplicate work.</div>' : `
      <form class="next-completion-form next-report-work-form"
        data-scheduled-date="${escapeHtml(day?.work_date || assignment?.work_date || '')}"
        data-session-task-id="${sessionTaskId}"
        data-assignment-id="${assignmentId}">
        <div class="next-report-work-grid">
          <label class="next-work-key-field next-work-date-field"><span class="next-work-field-label">Date work actually happened ${nextReportHelpButton('date')}</span><input class="next-performed-on" type="date" value="${escapeHtml(day?.work_date || assignment?.work_date || '')}" required><small>Scheduled: ${escapeHtml(day?.work_date || assignment?.work_date || 'unknown')}. Change this if the crew worked another day.</small></label>
          <label class="next-work-key-field next-work-crew-field"><span class="next-work-field-label">Actual crew size ${nextReportHelpButton('crew')}</span><input class="next-crew" type="number" min="1" inputmode="numeric" placeholder="Number of volunteers" required><small>Include the Captain if they worked.</small></label>
          <label class="next-work-key-field next-work-hours-field"><span class="next-work-field-label">Hours worked ${nextReportHelpButton('hours')}</span><input class="next-duration-hours" type="number" min="0" step="1" inputmode="numeric" placeholder="0" required></label>
          <label class="next-work-key-field next-work-minutes-field"><span class="next-work-field-label">Minutes worked ${nextReportHelpButton('minutes')}</span><input class="next-duration-minutes" type="number" min="0" max="59" step="1" inputmode="numeric" placeholder="0–59" required><small>Enter minutes, even when less than one hour.</small></label>
          <label class="next-work-key-field next-work-percent-field"><span class="next-work-field-label">Whole task % complete ${nextReportHelpButton('percent')}</span><input class="next-percent-complete" type="number" min="1" max="100" step="1" inputmode="numeric" value="${lastPercent >= 1 ? lastPercent : ''}" required></label>
          <div class="next-report-help-panel" role="note" aria-live="polite" hidden>
            <span class="next-report-help-text"></span>
            <button type="button" class="small secondary next-report-help-close">Close help</button>
            <a target="_blank" rel="noopener" href="https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Perform_and_Report_Setup_Work.md">Full Report Work instructions</a>
          </div>
        </div>
        <label class="next-report-note"><span class="next-work-field-label">What was done / what remains ${nextReportHelpButton('notes')}</span><textarea class="next-note" rows="3" placeholder="Required when the task is not 100% complete"></textarea></label>
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
      ${nextCorrectionIntakeMarkup(sessionTaskId, assignmentId)}
    `;
    details.dataset.loaded = '1';
    const form = body.querySelector('.next-report-work-form');
    form?.addEventListener('submit', submitNextProgress);
    wireNextReportHelp(form);
    wireNextCorrectionIntake(body);
    body.querySelectorAll('.next-progress-correction-form').forEach(
      (correctionForm) => correctionForm.addEventListener('submit', submitNextProgressCorrection)
    );
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
  const scheduledDate = form.querySelector('.next-performed-on')?.closest('form')?.dataset.scheduledDate || '';
  // Both dates stay visible during confirmation, even when they match.
  // Cancel keeps every form value intact; neither date is silently replaced.
  if (!window.confirm(`Scheduled assignment date: ${scheduledDate || 'unknown'}\nDate work ACTUALLY happened: ${performedOn}\n\nAre both dates correct? Save Work Report?`)) return;


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

function renderNextLibraryReadiness() {
  const target = el('library-list');
  if (!target) return false;

  if (setupNextState.organizationStatus === 'ready') return false;

  document.querySelector('#library-view .next-library-tools')?.remove();
  el('stage-gap-list').innerHTML = '';

  if (setupNextState.organizationStatus === 'failed') {
    const message = setupNextState.organizationError?.message || setupNextState.organizationError || 'Unknown organization load error';
    target.innerHTML = `
      <div class="empty-state">
        <strong>Reusable Catalog organization could not be loaded.</strong>
        <div class="muted">${escapeHtml(message)}</div>
        <button id="next-organization-retry" type="button" class="secondary">Retry Catalog Organization</button>
      </div>`;
    el('next-organization-retry')?.addEventListener('click', () => {
      setupNextState.organizationStatus = 'idle';
      setupNextState.organizationError = null;
      renderLibrary();
    });
    return true;
  }

  target.innerHTML = '<div class="empty-state">Loading reusable Catalog organization…</div>';
  if (setupNextState.organizationStatus === 'idle') {
    void loadNextOrganization(true).catch(() => renderLibrary());
  }
  return true;
}

renderLibrary = function renderLibraryNextPass() {
  if (renderNextLibraryReadiness()) return;
  applyNextTaskScopes();
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
  renderLibrary();
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
    if (intro) intro.textContent = 'This review now includes Site-wide / Infrastructure plus Stage/Scene organization, prerequisite maintenance, a reusable/annual ordered backlog, rolling-horizon Crew A/B/C scheduling, and Captain field execution. Physical material handling is split deliberately: Pick List records workshop PICKED events, while Record Location records field Container/Display observations.';
  }
}

initializeNextPass();

