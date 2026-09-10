/* View-only Stage ordering for Plan / Schedule and Perform Work.
   Existing planned_order/baseline_plan_order remain authoritative planning data. */

function setupStageOrderRank(task) {
  if (task?.stage_id == null) return -1;
  const stages = typeof sortedStages === 'function' ? sortedStages() : (appState.stages || []);
  const index = stages.findIndex((stage) => Number(stage.stage_id) === Number(task.stage_id));
  return index < 0 ? 999999 : index;
}

function setupStageOrderedTasks(tasks) {
  return [...(tasks || [])].sort((a, b) => {
    const stageCompare = setupStageOrderRank(a) - setupStageOrderRank(b);
    if (stageCompare !== 0) return stageCompare;

    const aScene = String(a.scene_name || '');
    const bScene = String(b.scene_name || '');
    if (!aScene && bScene) return -1;
    if (aScene && !bScene) return 1;
    const sceneCompare = aScene.localeCompare(bScene, undefined, { numeric: true });
    if (sceneCompare !== 0) return sceneCompare;

    const ao = a.planned_order == null ? 999999 : Number(a.planned_order);
    const bo = b.planned_order == null ? 999999 : Number(b.planned_order);
    if (ao !== bo) return ao - bo;
    const ab = a.baseline_plan_order == null ? 999999 : Number(a.baseline_plan_order);
    const bb = b.baseline_plan_order == null ? 999999 : Number(b.baseline_plan_order);
    if (ab !== bb) return ab - bb;
    return Number(a.setup_session_task_id || a.setup_task_id) - Number(b.setup_session_task_id || b.setup_task_id);
  });
}

function setupStageHeadingText(task) {
  if (task?.stage_id == null) return 'Site-wide / Infrastructure';
  return `Stage ${task.stage_key || '—'} — ${task.stage_name || 'Unnamed Stage'}`;
}

function setupScopeHeadingText(task) {
  return task?.scene_name ? `Scene — ${task.scene_name}` : 'Stage-level / General';
}

function setupScopeHeadingKey(task) {
  return task?.scene_name ? `scene:${task.scene_name}` : 'stage';
}

function setupPlanningViewMode() {
  return el('next-plan-order-mode')?.value || 'STAGE';
}

function setupPerformViewMode() {
  return el('next-perform-order-mode')?.value || 'STAGE';
}

function setupRefreshMaterialHighlighting() {
  if (typeof applySetupMaterialTaskHighlighting === 'function') {
    applySetupMaterialTaskHighlighting();
  }
}

function setupInstallStageOrderControls() {
  const planFilters = el('next-plan-filters');
  if (planFilters && !el('next-plan-order-mode')) {
    const label = document.createElement('label');
    label.className = 'setup-stage-order-control';
    label.innerHTML = 'View order <select id="next-plan-order-mode"><option value="STAGE">Stage</option><option value="PLANNED">Planned order</option></select>';
    planFilters.prepend(label);
    el('next-plan-order-mode').addEventListener('change', () => {
      renderPlanningBacklog();
      setupRenderScheduleTaskOptions();
    });
    planFilters.querySelectorAll('input[data-plan-filter]').forEach((input) => {
      input.addEventListener('change', () => {
        setupApplyPlanningStageView();
        setupRefreshMaterialHighlighting();
      });
    });
  }

  const performFilter = el('next-perform-filter');
  const performHeader = performFilter?.closest('.section-title');
  if (performHeader && !el('next-perform-order-mode')) {
    const label = document.createElement('label');
    label.className = 'setup-stage-order-control';
    label.innerHTML = 'View order <select id="next-perform-order-mode"><option value="STAGE">Stage</option><option value="PLANNED">Planned order</option></select>';
    performHeader.appendChild(label);
    el('next-perform-order-mode').addEventListener('change', renderNextExecution);
    performFilter.addEventListener('change', () => {
      setupApplyPerformStageView();
      setupRefreshMaterialHighlighting();
    });
  }
}

function setupRenderScheduleTaskOptions() {
  const select = el('next-schedule-task');
  if (!select) return;
  const mode = setupPlanningViewMode();
  const source = (setupNextState.executionTasks || []).filter((task) => task.execution_status !== 'COMPLETE');
  const tasks = mode === 'STAGE' ? setupStageOrderedTasks(source) : nextPlanningOrder(source);
  const selected = select.value;
  select.innerHTML = tasks.map((task) => {
    const plan = task.planned_order ?? '—';
    const label = mode === 'STAGE'
      ? `${nextTaskLabel(task)} · Plan ${plan}`
      : `${plan} — ${nextTaskLabel(task)}`;
    return `<option value="${task.setup_session_task_id}">${escapeHtml(label)}</option>`;
  }).join('');
  if (selected && [...select.options].some((option) => option.value === selected)) select.value = selected;
}

function setupAppendStageAndScopeHeadings(target, task, state) {
  const stageKey = task.stage_id == null ? 'site-wide' : String(task.stage_id);
  if (stageKey !== state.stage) {
    const heading = document.createElement('div');
    heading.className = 'setup-stage-order-heading';
    heading.textContent = setupStageHeadingText(task);
    target.appendChild(heading);
    state.stage = stageKey;
    state.scope = null;
  }

  if (task.stage_id != null) {
    const scopeKey = setupScopeHeadingKey(task);
    if (scopeKey !== state.scope) {
      const scopeHeading = document.createElement('div');
      scopeHeading.className = 'setup-stage-scope-heading';
      scopeHeading.textContent = setupScopeHeadingText(task);
      target.appendChild(scopeHeading);
      state.scope = scopeKey;
    }
  }
}

function setupApplyPlanningStageView() {
  const target = el('next-planning-backlog');
  if (!target) return;
  target.querySelectorAll('.setup-stage-order-heading, .setup-stage-scope-heading, .setup-stage-order-note').forEach((node) => node.remove());
  if (setupPlanningViewMode() !== 'STAGE') return;

  const rows = new Map([...target.querySelectorAll('.next-plan-row')].map((row) => [Number(row.dataset.sessionTaskId), row]));
  if (!rows.size) return;
  const visibleTasks = setupStageOrderedTasks(setupNextState.executionTasks || [])
    .filter((task) => rows.has(Number(task.setup_session_task_id)));

  const note = document.createElement('div');
  note.className = 'setup-stage-order-note';
  note.textContent = 'Stage view only — planned order is unchanged. Switch to Planned order to reorder the annual plan.';
  target.prepend(note);

  const state = { stage: null, scope: null };
  for (const task of visibleTasks) {
    setupAppendStageAndScopeHeadings(target, task, state);
    const row = rows.get(Number(task.setup_session_task_id));
    row.draggable = false;
    row.querySelector('.next-plan-actions')?.setAttribute('hidden', '');
    target.appendChild(row);
  }
}

function setupApplyPerformStageView() {
  const target = el('next-perform-list');
  if (!target) return;
  target.querySelectorAll('.setup-stage-order-heading, .setup-stage-scope-heading').forEach((node) => node.remove());
  if (setupPerformViewMode() !== 'STAGE') return;

  const rows = new Map([...target.querySelectorAll('.next-perform-task')].map((row) => [Number(row.dataset.sessionTaskId), row]));
  if (!rows.size) return;
  const tasks = setupStageOrderedTasks(setupNextState.executionTasks || [])
    .filter((task) => rows.has(Number(task.setup_session_task_id)));

  const state = { stage: null, scope: null };
  for (const task of tasks) {
    setupAppendStageAndScopeHeadings(target, task, state);
    target.appendChild(rows.get(Number(task.setup_session_task_id)));
  }
}

if (typeof renderPlanningBacklog === 'function') {
  const setupBaseRenderPlanningBacklog = renderPlanningBacklog;
  renderPlanningBacklog = function renderPlanningBacklogWithStageOrder(...args) {
    const result = setupBaseRenderPlanningBacklog(...args);
    setupInstallStageOrderControls();
    setupApplyPlanningStageView();
    return result;
  };
}

if (typeof renderNextExecution === 'function') {
  const setupBaseRenderNextExecution = renderNextExecution;
  renderNextExecution = function renderNextExecutionWithStageOrder(...args) {
    const result = setupBaseRenderNextExecution(...args);
    setupInstallStageOrderControls();
    setupApplyPerformStageView();
    return result;
  };
}

if (typeof loadNextSchedule === 'function') {
  const setupBaseLoadNextSchedule = loadNextSchedule;
  loadNextSchedule = async function loadNextScheduleWithStageOrder(...args) {
    const result = await setupBaseLoadNextSchedule(...args);
    setupInstallStageOrderControls();
    setupRenderScheduleTaskOptions();
    setupApplyPlanningStageView();
    return result;
  };
}

setupInstallStageOrderControls();
window.addEventListener('load', setupInstallStageOrderControls);
