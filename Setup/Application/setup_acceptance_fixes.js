/* Setup acceptance corrections from 2026-09-07 Manager browser review. */

function acceptancePopulateAddScenes(sceneId = null) {
  const select = el('add-scene-id');
  const stageSelect = el('add-stage-id');
  if (!select || !stageSelect) return;
  const stageId = nullableInteger(stageSelect.value);
  if (stageId == null) {
    select.innerHTML = '<option value="">No LOR Stage/Scene</option>';
    select.disabled = true;
    return;
  }
  select.disabled = false;
  select.innerHTML = `<option value="">Stage-level / General</option>${nextScenesForStage(stageId).map((scene) => (
    `<option value="${scene.lor_scene_id}">Scene — ${escapeHtml(scene.scene_name)}</option>`
  )).join('')}`;
  if (sceneId != null) select.value = String(sceneId);
}

function acceptanceEnsureAddSceneSelector() {
  if (el('add-scene-id')) return;
  const stageSelect = el('add-stage-id');
  const stageLabel = stageSelect?.closest('label');
  if (!stageLabel) return;
  const label = document.createElement('label');
  label.textContent = 'Scene / Area';
  const select = document.createElement('select');
  select.id = 'add-scene-id';
  label.appendChild(select);
  stageLabel.insertAdjacentElement('afterend', label);
  stageSelect.addEventListener('change', () => acceptancePopulateAddScenes());
  acceptancePopulateAddScenes();
}

function acceptanceNextSequence(stageId, sceneId) {
  const tasks = nextTasksForScope(stageId, sceneId);
  if (!tasks.length) return 10;
  return Math.max(...tasks.map((task) => Number(task.display_order) || 0)) + 10;
}

function acceptanceOpenAddTask(stageId = null, sceneId = null) {
  acceptanceEnsureAddSceneSelector();
  const form = el('add-task-form');
  form.hidden = false;
  el('add-stage-id').value = stageId == null ? '' : String(stageId);
  acceptancePopulateAddScenes(sceneId);
  el('add-display-order').value = String(acceptanceNextSequence(stageId, sceneId));
  el('add-task-name').value = '';
  form.scrollIntoView({ block: 'center', behavior: 'smooth' });
  requestAnimationFrame(() => el('add-task-name').focus());
}

function acceptanceDecorateLibrary() {
  document.querySelectorAll('.next-sitewide-note').forEach((note) => {
    note.textContent = 'Critical Setup work with no LOR Stage or Scene. Procedures resolve from the controlled 41 Park Infrastructure-PI root.';
  });

  document.querySelectorAll('.next-scope-dropzone').forEach((zone) => {
    if (zone.querySelector('.acceptance-add-here')) return;
    const actions = document.createElement('div');
    actions.className = 'acceptance-scope-actions acceptance-add-here';
    actions.hidden = !appState.access?.can_manage_setup;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'small secondary';
    button.textContent = 'Add Task Here';
    button.addEventListener('click', () => {
      const stageId = String(zone.dataset.stageId || '').trim() ? Number(zone.dataset.stageId) : null;
      const sceneId = String(zone.dataset.sceneId || '').trim() ? Number(zone.dataset.sceneId) : null;
      acceptanceOpenAddTask(stageId, sceneId);
    });
    actions.appendChild(button);
    zone.insertAdjacentElement('afterbegin', actions);
  });
}

const acceptancePriorRenderLibrary = renderLibrary;
renderLibrary = function renderLibraryAcceptance() {
  acceptancePriorRenderLibrary();
  acceptanceDecorateLibrary();
};

async function acceptanceCreateReusableTask(event) {
  event.preventDefault();
  if (!appState.access?.can_manage_setup) return;

  const stageId = nullableInteger(el('add-stage-id').value);
  const sceneId = stageId == null ? null : nullableInteger(el('add-scene-id')?.value);
  const payload = {
    task_name: el('add-task-name').value.trim(),
    stage_id: stageId,
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
    if (!newId) throw new Error('Reusable task creation did not return a task ID.');

    await api(`api/setup/tasks/${newId}/scope`, commandOptions('PATCH', {
      stage_id: stageId,
      lor_scene_id: sceneId
    }));

    el('add-task-form').hidden = true;
    el('add-task-form').reset();
    el('add-display-order').value = '100';
    await reloadTasks(newId);
    await loadNextOrganization(false);
    renderLibrary();
    setAlert(`Reusable task ${newId} created in ${nextTaskScopeLabel(taskById(newId))}.`, 'ok');
    requestAnimationFrame(() => document.querySelector(`[data-task-id="${newId}"]`)?.scrollIntoView({ block: 'center', behavior: 'smooth' }));
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function acceptanceMaterialMarkup(context) {
  const displays = context.displays || [];
  const support = context.support_containers || [];
  if (!displays.length && !support.length) {
    return '<p class="muted">No Displays or support Containers are mapped or derived for this reusable task yet.</p>';
  }

  const grouped = new Map();
  const loose = [];
  for (const item of displays) {
    if (item.container_id == null) {
      loose.push(item);
      continue;
    }
    const key = String(item.container_id);
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(item);
  }

  const blocks = [];
  for (const [containerId, items] of grouped.entries()) {
    const first = items[0];
    const description = first.container_description ? ` — ${escapeHtml(first.container_description)}` : '';
    const sceneCount = items.filter((item) => item.relationship_source === 'SCENE').length;
    blocks.push(`
      <div class="acceptance-material-group">
        <strong>Container ${escapeHtml(containerId)}${description}</strong>
        <div class="muted">${escapeHtml(nextLocationText(first))}${sceneCount ? ` · ${sceneCount} Display${sceneCount === 1 ? '' : 's'} from current Scene membership` : ''}</div>
        <ul>${items.map((item) => `<li>Display ${item.display_id} — ${escapeHtml(item.display_name)}</li>`).join('')}</ul>
      </div>`);
  }

  if (loose.length) {
    blocks.push(`
      <div class="acceptance-material-group">
        <strong>Loose / detached Displays</strong>
        <ul>${loose.map((item) => `<li>Display ${item.display_id} — ${escapeHtml(item.display_name)} · ${escapeHtml(nextLocationText(item))}</li>`).join('')}</ul>
      </div>`);
  }

  for (const item of support) {
    blocks.push(`
      <div class="acceptance-material-group">
        <strong>Support Container ${item.container_id}${item.container_description ? ` — ${escapeHtml(item.container_description)}` : ''}</strong>
        <div class="muted">${escapeHtml(nextLocationText(item))}</div>
      </div>`);
  }
  return blocks.join('');
}

loadNextTaskExecution = async function loadNextTaskExecutionAcceptance(details) {
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

    body.innerHTML = `
      <div class="next-perform-grid">
        <section><h4>Task</h4><p>${escapeHtml(task.completion_point || 'Completion point not yet documented.')}</p>
          ${task.readiness_note ? `<p><strong>Readiness:</strong> ${escapeHtml(task.readiness_note)}</p>` : ''}
          ${task.weather_note ? `<p><strong>Weather:</strong> ${escapeHtml(task.weather_note)}</p>` : ''}
          <p><strong>Expected crew:</strong> ${escapeHtml(formatCrew(task))} · <strong>Expected time:</strong> ${escapeHtml(formatMinutes(task.expected_duration_minutes))}</p>
          <p><strong>Prerequisites:</strong> ${task.prerequisites_complete ? 'Complete / no blockers' : 'Not complete'}</p></section>
        <section><h4>Equipment / Resources</h4>${resources.length ? `<ul>${resources.map((r) => `<li>${escapeHtml(r.resource_name)} · Qty ${r.quantity_required} · ${escapeHtml(r.requirement_type)}</li>`).join('')}</ul>` : '<p class="muted">No structured resource requirement recorded.</p>'}</section>
        <section><h4>Material / Current Location</h4>${acceptanceMaterialMarkup(context)}</section>
        <section><h4>Published Setup Procedure</h4>${docs.length ? docs.map((doc) => `<p><a target="_blank" rel="noopener" href="api/setup/tasks/${taskId}/procedure/current?name=${encodeURIComponent(doc.name || '')}">${escapeHtml(doc.name || 'Open current PDF')}</a></p>`).join('') : `<p class="muted">No published Setup PDF resolved for this task scope.${nextIsSitewide(task) ? ' Park-wide Procedures belong in Display Folders\\41 Park Infrastructure-PI\\Procedures\\Setup.' : ''}</p>`}</section>
      </div>
      <section class="next-progress-history"><h4>Progress history</h4>${progress.length ? progress.map((p) => `<div>${escapeHtml(formatTimestamp(p.recorded_at))} · Crew ${p.crew_count}${p.completed_quantity ? ` · ${p.completed_quantity} completed` : ''}${p.completed_units ? ` · ${escapeHtml(p.completed_units)}` : ''}${p.progress_note ? ` · ${escapeHtml(p.progress_note)}` : ''}${p.marks_task_complete ? ' · COMPLETE' : ''}</div>`).join('') : '<div class="muted">No progress recorded yet.</div>'}</section>
      ${task.execution_status === 'COMPLETE' ? `<div class="next-complete-banner">Completed ${escapeHtml(formatTimestamp(task.actual_completed_at))}${task.completed_by_name ? ` by ${escapeHtml(task.completed_by_name)}` : ''}${task.completion_note ? ` · ${escapeHtml(task.completion_note)}` : ''}</div>` : `
      <form class="next-completion-form acceptance-completion-form" data-session-task-id="${sessionTaskId}">
        <label class="acceptance-crew-label">Crew size<input class="next-crew" type="number" min="1" required></label>
        <label class="acceptance-note-label">Progress / completion note <span class="muted">(optional)</span><textarea class="next-note" rows="2"></textarea></label>
        <details class="acceptance-partial-progress">
          <summary>Partial / multi-unit progress (optional)</summary>
          <div class="acceptance-partial-grid">
            <label>Completed quantity<input class="next-quantity" type="number" min="1" placeholder="Example: 3"></label>
            <label>Which units / what was completed<input class="next-units" type="text" placeholder="Example: Trees 1, 3, 4"></label>
          </div>
        </details>
        <div class="acceptance-completion-actions">
          <label class="checkbox-label acceptance-complete-check"><input class="next-mark-complete" type="checkbox"> Entire task complete</label>
          <button type="submit">Save Progress / Completion</button>
        </div>
      </form>`}
    `;
    details.dataset.loaded = '1';
    body.querySelector('.next-completion-form')?.addEventListener('submit', submitNextProgress);
  } catch (error) {
    body.innerHTML = `<strong>Task field context could not be loaded.</strong><div class="muted">${escapeHtml(error.message || error)}</div>`;
  }
};

loadProcedure = async function loadProcedureAcceptance(task) {
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
      current.innerHTML = `<strong>No published Setup PDF found.</strong><div class="muted">${nextIsSitewide(task) ? 'Park-wide Procedures belong directly in Display Folders\\41 Park Infrastructure-PI\\Procedures\\Setup.' : 'Published field instructions belong directly in Procedures\\Setup.'}</div>`;
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
};

acceptanceEnsureAddSceneSelector();
const acceptanceAddForm = el('add-task-form');
acceptanceAddForm.removeEventListener('submit', createReusableTask);
acceptanceAddForm.addEventListener('submit', acceptanceCreateReusableTask);
el('show-add-task').addEventListener('click', () => acceptanceOpenAddTask(null, null));

if (appState.tasks?.length) renderLibrary();
