/* Reusable Setup physical-effort and Display-material metadata UI. */

const setupEffortState = new Map();

function setupEffortLabel(value) {
  const normalized = String(value || '').trim().toUpperCase();
  return normalized || 'Not reviewed';
}

function placeSetupEffortSaveControl() {
  const select = el('edit-effort-level');
  const button = el('save-task-effort');
  const label = select?.closest('label');
  if (!select || !button || !label) return;
  if (el('setup-effort-editor-row')) return;

  const row = document.createElement('div');
  row.id = 'setup-effort-editor-row';
  row.className = 'compact-grid';

  const actions = document.createElement('div');
  actions.className = 'action-row manager-only setup-effort-save-actions';

  button.classList.remove('secondary');
  label.parentElement.insertBefore(row, label);
  row.appendChild(label);
  actions.appendChild(button);
  row.appendChild(actions);
}

function applySetupEffortToTasks() {
  for (const task of appState.tasks || []) {
    task.effort_level = setupEffortState.get(Number(task.setup_task_id)) ?? null;
  }
}

function applySetupEffortAccess() {
  const editable = Boolean(appState.access?.can_manage_setup);
  const select = el('edit-effort-level');
  if (select) select.disabled = !editable;
  const button = el('save-task-effort');
  if (button) button.disabled = !editable;
}

function applySetupEffortBadges() {
  document.querySelectorAll('.next-task-row[data-task-id], .library-task[data-task-id]').forEach((row) => {
    const taskId = Number(row.dataset.taskId || 0);
    const task = taskById(taskId);
    if (!task) return;
    const meta = row.querySelector('.next-task-main .task-meta') || row.querySelector('.task-meta');
    if (!meta || meta.querySelector('.setup-effort-badge')) return;
    const badge = document.createElement('span');
    badge.className = 'setup-effort-badge';
    badge.textContent = ` · Effort: ${setupEffortLabel(task.effort_level)}`;
    meta.appendChild(badge);
  });
}

function syncSelectedSetupEffort() {
  const select = el('edit-effort-level');
  if (!select) return;
  const task = taskById(appState.selectedTaskId);
  select.value = task?.effort_level || '';
  applySetupEffortAccess();
}

async function loadSetupEfforts({ rerender = true } = {}) {
  const payload = await api('api/setup/task-efforts');
  setupEffortState.clear();
  for (const item of payload.task_efforts || []) {
    setupEffortState.set(Number(item.setup_task_id), item.effort_level || null);
  }
  applySetupEffortToTasks();
  syncSelectedSetupEffort();
  if (rerender && typeof renderLibrary === 'function') renderLibrary();
  else applySetupEffortBadges();
}

async function saveSelectedSetupEffort() {
  const task = taskById(appState.selectedTaskId);
  if (!task || !appState.access?.can_manage_setup) return;
  const select = el('edit-effort-level');
  if (!select) return;

  const effort = select.value || null;
  const reusableDraft = typeof window.msbSetupCaptureReusableDraft === 'function'
    ? window.msbSetupCaptureReusableDraft()
    : null;

  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${task.setup_task_id}/effort`,
      commandOptions('PATCH', { effort_level: effort })
    );
    setupEffortState.set(Number(task.setup_task_id), effort);
    task.effort_level = effort;

    // Reload the authoritative task row so audit attribution refreshes, then
    // restore any other reusable-field drafts that the operator had not yet
    // chosen to save. Save Effort must never discard unrelated typed edits.
    await reloadTasks(task.setup_task_id);
    if (
      reusableDraft
      && Number(appState.selectedTaskId) === Number(task.setup_task_id)
      && typeof window.msbSetupRestoreReusableDraft === 'function'
    ) {
      window.msbSetupRestoreReusableDraft(reusableDraft);
    }

    setAlert(`Reusable effort saved: ${setupEffortLabel(effort)}.`, 'ok');
  } catch (error) {
    setAlert(error.message || error, 'error');
  } finally {
    setBusy(false);
  }
}

if (typeof renderLibrary === 'function') {
  const setupEffortBaseRenderLibrary = renderLibrary;
  renderLibrary = function renderLibraryWithSetupEffort(...args) {
    const result = setupEffortBaseRenderLibrary(...args);
    applySetupEffortBadges();
    return result;
  };
}

if (typeof selectTask === 'function') {
  const setupEffortBaseSelectTask = selectTask;
  selectTask = function selectTaskWithSetupEffort(taskId) {
    const result = setupEffortBaseSelectTask(taskId);
    syncSelectedSetupEffort();
    return result;
  };
}

if (typeof reloadTasks === 'function') {
  const setupEffortBaseReloadTasks = reloadTasks;
  reloadTasks = async function reloadTasksWithSetupEffort(...args) {
    const result = await setupEffortBaseReloadTasks(...args);
    await loadSetupEfforts({ rerender: false });
    return result;
  };
}

placeSetupEffortSaveControl();
el('save-task-effort')?.addEventListener('click', saveSelectedSetupEffort);

window.addEventListener('load', () => {
  placeSetupEffortSaveControl();
  applySetupEffortAccess();
  loadSetupEfforts().catch((error) => {
    console.error('Setup effort metadata could not be loaded', error);
  });
});

/* --------------------------------------------------------------------------
   Automatic Display/container material applicability
   -------------------------------------------------------------------------- */

const setupMaterialState = new Map();

function installSetupMaterialStyles() {
  if (el('setup-material-inline-style')) return;
  const style = document.createElement('style');
  style.id = 'setup-material-inline-style';
  style.textContent = `
    .setup-material-editor {
      margin: 8px 0 14px;
      padding: 12px 14px;
      border: 1px solid #cfc3ee;
      border-radius: 10px;
      background: #f6f2ff;
    }
    .setup-material-editor .checkbox-label {
      font-weight: 700;
      color: #321a78;
    }
    .setup-material-resolution {
      margin-top: 7px;
      font-size: .92rem;
    }
    .setup-material-task {
      border-left: 5px solid #7657c7 !important;
    }
    .setup-catalog-material-hint {
      margin: 8px 0 12px;
      padding: 9px 11px;
      border: 1px solid #d9d1ee;
      border-radius: 8px;
      background: #faf8ff;
    }
    .setup-catalog-material-toggle {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      min-width: 210px;
      font-size: .88rem;
      font-weight: 700;
      color: #321a78;
      cursor: pointer;
    }
    .setup-catalog-material-toggle input {
      margin: 0;
    }
    .setup-catalog-material-toggle.disabled {
      opacity: .55;
      cursor: not-allowed;
    }
    .setup-display-owner-catalog-hint {
      margin: 0 0 10px;
      padding: 8px 10px;
      border: 1px solid #d9d1ee;
      border-radius: 8px;
      background: #faf8ff;
    }
    html[data-theme='dark'] .setup-material-editor {
      border-color: #6954a5;
      background: #251f35;
    }
    html[data-theme='dark'] .setup-material-editor .checkbox-label,
    html[data-theme='dark'] .setup-catalog-material-toggle {
      color: #ddd1ff;
    }
    html[data-theme='dark'] .setup-catalog-material-hint,
    html[data-theme='dark'] .setup-display-owner-catalog-hint {
      border-color: #51456f;
      background: #211c2d;
    }
  `;
  document.head.appendChild(style);
}

function placeSetupMaterialControl() {
  if (el('setup-material-editor')) return;
  const fieldset = el('reusable-fieldset');
  if (!fieldset) return;

  const anchor = el('setup-effort-editor-row') || el('edit-effort-level')?.closest('label');
  const editor = document.createElement('div');
  editor.id = 'setup-material-editor';
  editor.className = 'setup-material-editor';
  editor.innerHTML = `
    <label class="checkbox-label">
      <input id="edit-requires-display-material" type="checkbox">
      Uses Display / Container Material
    </label>
    <div id="setup-material-resolution" class="setup-material-resolution muted">
      Material resolves automatically from the task's Stage or real Scene.
    </div>
  `;

  if (anchor?.parentElement === fieldset) anchor.insertAdjacentElement('afterend', editor);
  else fieldset.insertBefore(editor, fieldset.querySelector('#edit-completion')?.closest('label') || null);

  el('edit-requires-display-material')?.addEventListener('change', saveSelectedSetupMaterialRequirement);
  applySetupMaterialAccess();
}

function applySetupMaterialToTasks() {
  for (const task of appState.tasks || []) {
    task.requires_display_material = Boolean(
      setupMaterialState.get(Number(task.setup_task_id))
    );
  }
}

function applySetupMaterialAccess() {
  const checkbox = el('edit-requires-display-material');
  if (checkbox) checkbox.disabled = !Boolean(appState.access?.can_manage_setup);
  applySetupCatalogMaterialControls();
}

function taskForMaterialNode(node) {
  const taskId = Number(node?.dataset?.taskId || 0);
  if (taskId) return taskById(taskId);

  const sessionTaskId = Number(node?.dataset?.sessionTaskId || 0);
  if (sessionTaskId && typeof setupNextState !== 'undefined') {
    return (setupNextState.executionTasks || []).find(
      (task) => Number(task.setup_session_task_id) === sessionTaskId
    );
  }
  return null;
}

function applySetupMaterialTaskHighlighting() {
  document.querySelectorAll(
    '.task-row[data-task-id], .next-task-row[data-task-id], .library-task[data-task-id], ' +
    '.next-plan-row[data-session-task-id], .next-perform-task[data-task-id]'
  ).forEach((node) => {
    const task = taskForMaterialNode(node);
    const enabled = Boolean(
      task?.requires_display_material ??
      setupMaterialState.get(Number(task?.setup_task_id || node.dataset.taskId || 0))
    );
    node.classList.toggle('setup-material-task', enabled);
    if (enabled) node.title = 'Display / Container material required';
    else if (node.title === 'Display / Container material required') node.removeAttribute('title');
  });
}

function libraryMaterialTaskId(row) {
  const direct = Number(row?.dataset?.taskId || 0);
  if (direct) return direct;
  const open = row?.querySelector('.open-task[data-task-id]');
  const fromButton = Number(open?.dataset?.taskId || 0);
  return fromButton || null;
}

function isRealSetupSceneName(sceneName) {
  const name = String(sceneName || '').trim();
  if (!/^\d{2}[A-Za-z]?-.+/.test(name)) return false;
  return !/-[A-Za-z]{2}$/.test(name);
}

function setupMaterialScopeKey(task) {
  const stageId = Number(task?.stage_id || 0);
  if (!stageId) return null;
  const sceneId = Number(task?.lor_scene_id || 0);
  if (sceneId && isRealSetupSceneName(task?.scene_name)) return `SCENE:${sceneId}`;
  return `STAGE:${stageId}`;
}

function materialScopeTasks(task) {
  const key = setupMaterialScopeKey(task);
  if (!key) return [];
  return (appState.tasks || []).filter((candidate) => (
    Boolean(candidate?.active_flag)
    && Boolean(candidate?.requires_display_material)
    && setupMaterialScopeKey(candidate) === key
  ));
}

function ensureSetupCatalogMaterialHint() {
  const list = el('library-list');
  if (!list || el('setup-catalog-material-hint')) return;
  const hint = document.createElement('div');
  hint.id = 'setup-catalog-material-hint';
  hint.className = 'setup-catalog-material-hint muted';
  hint.innerHTML = '<strong>Display material:</strong> check Uses Display / Container Material on the reusable tasks that actually need Display material. When more than one task is checked in the same Stage/Scene, open one of those tasks to assign the resolved Displays between only those checked tasks.';
  list.insertAdjacentElement('beforebegin', hint);
}

function applySetupCatalogMaterialControls() {
  const list = el('library-list');
  if (!list) return;
  ensureSetupCatalogMaterialHint();

  list.querySelectorAll('.library-task').forEach((row) => {
    const taskId = libraryMaterialTaskId(row);
    const task = taskId == null ? null : taskById(taskId);
    if (!task) return;

    let label = row.querySelector('.setup-catalog-material-toggle');
    if (!label) {
      label = document.createElement('label');
      label.className = 'setup-catalog-material-toggle';
      label.innerHTML = '<input type="checkbox" class="setup-catalog-material-checkbox"> Uses Display / Container Material';
      const actions = row.querySelector('.library-actions');
      if (actions) actions.insertAdjacentElement('beforebegin', label);
      else row.appendChild(label);

      const input = label.querySelector('.setup-catalog-material-checkbox');
      input?.addEventListener('pointerdown', (event) => event.stopPropagation());
      input?.addEventListener('click', (event) => event.stopPropagation());
      input?.addEventListener('change', (event) => {
        event.stopPropagation();
        void saveCatalogSetupMaterialRequirement(event.currentTarget);
      });
    }

    const input = label.querySelector('.setup-catalog-material-checkbox');
    if (!input) return;
    input.dataset.taskId = String(task.setup_task_id);
    input.checked = Boolean(task.requires_display_material);
    const disabled = !Boolean(appState.access?.can_manage_setup) || !Boolean(task.active_flag) || task.stage_id == null;
    input.disabled = disabled;
    label.classList.toggle('disabled', disabled);
    label.title = task.stage_id == null
      ? 'Display / Container Material requires a Stage or real Scene scope.'
      : task.active_flag
        ? 'Select this task as a Display-material task for its Stage/Scene.'
        : 'Inactive reusable tasks cannot be selected for Display ownership.';
  });
}

async function saveCatalogSetupMaterialRequirement(input) {
  const taskId = Number(input?.dataset?.taskId || 0);
  const task = taskById(taskId);
  if (!task || !appState.access?.can_manage_setup) return;

  const previous = setupMaterialState.has(taskId)
    ? Boolean(setupMaterialState.get(taskId))
    : Boolean(task.requires_display_material);
  const requires = Boolean(input.checked);

  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${task.setup_task_id}/display-material`,
      commandOptions('PATCH', { requires_display_material: requires })
    );
    setupMaterialState.set(taskId, requires);
    task.requires_display_material = requires;

    if (Number(appState.selectedTaskId || 0) === taskId) {
      const detail = el('edit-requires-display-material');
      if (detail) detail.checked = requires;
      await loadSelectedSetupMaterialContext();
    }

    applySetupMaterialTaskHighlighting();
    applySetupCatalogMaterialControls();
    syncDisplayOwnershipCatalogScope();
    setAlert(
      requires
        ? `${task.task_name}: Display / Container Material selected in the reusable Catalog.`
        : `${task.task_name}: Display / Container Material cleared in the reusable Catalog.`,
      'ok'
    );
  } catch (error) {
    input.checked = previous;
    task.requires_display_material = previous;
    setupMaterialState.set(taskId, previous);
    applySetupCatalogMaterialControls();
    syncDisplayOwnershipCatalogScope();
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function syncDisplayOwnershipCatalogScope() {
  const selected = taskById(appState.selectedTaskId);
  const checkedTasks = selected ? materialScopeTasks(selected) : [];
  const selectedChecked = Boolean(selected?.requires_display_material);
  const multiCheckedScope = selectedChecked && checkedTasks.length > 1;

  const control = el('setup-display-ownership-control');
  const shouldHideControl = !multiCheckedScope;
  if (control && control.hidden !== shouldHideControl) control.hidden = shouldHideControl;

  const dialog = el('setup-display-ownership-dialog');
  const content = el('setup-display-ownership-content');
  if (!content) return;

  content.querySelectorAll('.setup-display-owner-column[data-target-task-id]').forEach((column) => {
    const targetId = Number(column.dataset.targetTaskId || 0);
    const targetTask = taskById(targetId);
    const shouldHideColumn = !Boolean(targetTask?.requires_display_material);
    if (column.hidden !== shouldHideColumn) column.hidden = shouldHideColumn;
  });

  let note = content.querySelector('.setup-display-owner-catalog-hint');
  if (!note && content.children.length) {
    note = document.createElement('div');
    note.className = 'setup-display-owner-catalog-hint muted';
    content.insertBefore(note, content.firstChild);
  }
  if (note) {
    const noteHtml = '<strong>Assignment targets:</strong> only reusable tasks checked Uses Display / Container Material in the Catalog are shown. Return to the Catalog to add or remove a task from this assignment set.';
    if (note.innerHTML !== noteHtml) note.innerHTML = noteHtml;
    const shouldHideNote = !multiCheckedScope;
    if (note.hidden !== shouldHideNote) note.hidden = shouldHideNote;
  }

  if (dialog?.open && !multiCheckedScope) dialog.close();
}

function installDisplayOwnershipCatalogScopeObserver() {
  const control = el('setup-display-ownership-control');
  const content = el('setup-display-ownership-content');
  if (control && control.dataset.materialScopeObserver !== '1') {
    control.dataset.materialScopeObserver = '1';
    new MutationObserver(() => syncDisplayOwnershipCatalogScope()).observe(
      control,
      { attributes: true, attributeFilter: ['hidden'] }
    );
  }
  if (content && content.dataset.materialScopeObserver !== '1') {
    content.dataset.materialScopeObserver = '1';
    new MutationObserver(() => syncDisplayOwnershipCatalogScope()).observe(
      content,
      { childList: true, subtree: true }
    );
  }
  syncDisplayOwnershipCatalogScope();
}

function setupMaterialSummaryText(resolution) {
  const displayCount = Number(resolution?.display_count || 0);
  const containerCount = Number(resolution?.container_count || 0);
  const mode = String(resolution?.mode || '').toUpperCase();
  const scope = mode === 'SCENE' ? 'real Scene' : mode === 'STAGE' ? 'Stage-level LOR groups' : 'task scope';
  const containerIds = (resolution?.container_ids || []).join(', ');
  const uncontained = Number(resolution?.uncontained_display_count || 0);
  const details = `${displayCount} Display${displayCount === 1 ? '' : 's'} · ${containerCount} Container${containerCount === 1 ? '' : 's'}`;
  const containerText = containerIds ? ` · Containers ${containerIds}` : '';
  const uncontainedText = uncontained ? ` · ${uncontained} Display${uncontained === 1 ? '' : 's'} not currently assigned to a Container` : '';
  return `<strong>Resolved automatically from LOR</strong><br>${escapeHtml(details)} · ${escapeHtml(scope)}${escapeHtml(containerText)}${escapeHtml(uncontainedText)}`;
}

async function loadSelectedSetupMaterialContext() {
  const target = el('setup-material-resolution');
  const task = taskById(appState.selectedTaskId);
  if (!target || !task) return;

  if (!task.requires_display_material) {
    target.innerHTML = 'No Display material required for this task.';
    return;
  }

  target.innerHTML = 'Resolving current Displays and Containers from LOR…';
  try {
    const payload = await api(
      `api/setup/tasks/${task.setup_task_id}/field-context?season_year=${encodeURIComponent(appState.seasonYear)}`
    );
    const resolution = payload.context?.material_resolution || {};
    target.innerHTML = setupMaterialSummaryText(resolution);
    if (resolution.warning) {
      target.innerHTML += `<div class="muted">${escapeHtml(resolution.warning)}</div>`;
    }
  } catch (error) {
    target.innerHTML = `<strong>Material could not be resolved.</strong><div class="muted">${escapeHtml(error.message || error)}</div>`;
  }
}

function syncSelectedSetupMaterial() {
  placeSetupMaterialControl();
  const checkbox = el('edit-requires-display-material');
  const task = taskById(appState.selectedTaskId);
  if (!checkbox || !task) return;
  checkbox.checked = Boolean(
    setupMaterialState.get(Number(task.setup_task_id)) ?? task.requires_display_material
  );
  task.requires_display_material = checkbox.checked;
  applySetupMaterialAccess();
  loadSelectedSetupMaterialContext();
  syncDisplayOwnershipCatalogScope();
}

async function loadSetupMaterialFlags({ rerender = true } = {}) {
  const payload = await api('api/setup/task-material-flags');
  setupMaterialState.clear();
  for (const item of payload.task_material_flags || []) {
    setupMaterialState.set(
      Number(item.setup_task_id),
      Boolean(item.requires_display_material)
    );
  }
  applySetupMaterialToTasks();
  syncSelectedSetupMaterial();
  if (rerender) {
    if (typeof renderReviewList === 'function') renderReviewList();
    if (typeof renderLibrary === 'function') renderLibrary();
    if (typeof renderPlanningBacklog === 'function') renderPlanningBacklog();
    if (typeof renderNextExecution === 'function') renderNextExecution();
  }
  applySetupMaterialTaskHighlighting();
  applySetupCatalogMaterialControls();
  syncDisplayOwnershipCatalogScope();
}

async function saveSelectedSetupMaterialRequirement() {
  const task = taskById(appState.selectedTaskId);
  const checkbox = el('edit-requires-display-material');
  if (!task || !checkbox || !appState.access?.can_manage_setup) return;

  const previous = Boolean(setupMaterialState.get(Number(task.setup_task_id)));
  const requires = Boolean(checkbox.checked);
  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${task.setup_task_id}/display-material`,
      commandOptions('PATCH', { requires_display_material: requires })
    );
    setupMaterialState.set(Number(task.setup_task_id), requires);
    task.requires_display_material = requires;
    applySetupMaterialTaskHighlighting();
    applySetupCatalogMaterialControls();
    syncDisplayOwnershipCatalogScope();
    await loadSelectedSetupMaterialContext();
    setAlert(
      requires
        ? 'Display / Container material enabled. LOR material resolved automatically.'
        : 'Display / Container material disabled for this task.',
      'ok'
    );
  } catch (error) {
    checkbox.checked = previous;
    task.requires_display_material = previous;
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

if (typeof renderReviewList === 'function') {
  const setupMaterialBaseRenderReviewList = renderReviewList;
  renderReviewList = function renderReviewListWithMaterial(...args) {
    const result = setupMaterialBaseRenderReviewList(...args);
    applySetupMaterialTaskHighlighting();
    return result;
  };
}

if (typeof renderLibrary === 'function') {
  const setupMaterialBaseRenderLibrary = renderLibrary;
  renderLibrary = function renderLibraryWithMaterial(...args) {
    const result = setupMaterialBaseRenderLibrary(...args);
    applySetupMaterialTaskHighlighting();
    applySetupCatalogMaterialControls();
    syncDisplayOwnershipCatalogScope();
    return result;
  };
}

if (typeof renderPlanningBacklog === 'function') {
  const setupMaterialBaseRenderPlanningBacklog = renderPlanningBacklog;
  renderPlanningBacklog = function renderPlanningBacklogWithMaterial(...args) {
    const result = setupMaterialBaseRenderPlanningBacklog(...args);
    applySetupMaterialTaskHighlighting();
    return result;
  };
}

if (typeof renderNextExecution === 'function') {
  const setupMaterialBaseRenderNextExecution = renderNextExecution;
  renderNextExecution = function renderNextExecutionWithMaterial(...args) {
    const result = setupMaterialBaseRenderNextExecution(...args);
    applySetupMaterialTaskHighlighting();
    return result;
  };
}

if (typeof selectTask === 'function') {
  const setupMaterialBaseSelectTask = selectTask;
  selectTask = function selectTaskWithMaterial(taskId) {
    const result = setupMaterialBaseSelectTask(taskId);
    syncSelectedSetupMaterial();
    requestAnimationFrame(syncDisplayOwnershipCatalogScope);
    return result;
  };
}

if (typeof reloadTasks === 'function') {
  const setupMaterialBaseReloadTasks = reloadTasks;
  reloadTasks = async function reloadTasksWithMaterial(...args) {
    const result = await setupMaterialBaseReloadTasks(...args);
    await loadSetupMaterialFlags({ rerender: false });
    return result;
  };
}

installSetupMaterialStyles();
placeSetupMaterialControl();

window.addEventListener('load', () => {
  installSetupMaterialStyles();
  placeSetupMaterialControl();
  applySetupMaterialAccess();
  loadSetupMaterialFlags().catch((error) => {
    console.error('Setup Display-material metadata could not be loaded', error);
  });
  requestAnimationFrame(() => {
    installDisplayOwnershipCatalogScopeObserver();
    applySetupCatalogMaterialControls();
    syncDisplayOwnershipCatalogScope();
  });
});