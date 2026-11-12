/*
 * Setup prototype review clarity / Stage coverage.
 *
 * The 2025 verification queue is annual review state. The reusable task catalog
 * is persistent task knowledge and must not present that annual state as if it
 * were part of the reusable definition.
 *
 * Stage coverage is independent from reconstructed task coverage. Current
 * governed Stage/Sub-stage identities are shown even when no provisional Setup
 * task has yet been reconstructed for that scope.
 */

const setupStageCatalog = [
  ['00', 'HWY 42'],
  ['01', 'Front Entrance'],
  ['02', 'Triangle'],
  ['03', 'Welcome Area'],
  ['03a', 'Mega Cube'],
  ['04', 'Food Collection'],
  ['05', 'Festive Trees'],
  ['05a', 'Mega Star'],
  ['06', 'Post Office'],
  ['07', 'Whoville'],
  ['07a', 'Who Forest'],
  ['08', 'Elf Choir'],
  ['09', 'Global Warming'],
  ['10', 'Stars'],
  ['11', 'Sledders'],
  ['13', 'Winter Wonderland'],
  ['14', 'Icicle Tunnel'],
  ['15', 'Church-Bells'],
  ['16', 'Northern Lights'],
  ['17', 'Candyland'],
  ['18', 'Dancing Forest'],
  ['19', "Santa's Workshop"],
  ['20', 'Snow Storm'],
  ['21', 'Polar Bear Playground'],
  ['22', 'Glistening Grove'],
  ['23', 'Peanuts'],
  ['24', 'Traditional Christmas'],
  ['25', 'Racing Arches'],
  ['26', 'Magic Igloo'],
  ['30', "Santa's Station"]
].map(([stageKey, stageName]) => ({ stageKey, stageName }));

function setupStageSort(a, b) {
  return String(a.stageKey).localeCompare(String(b.stageKey), undefined, {
    numeric: true,
    sensitivity: 'base'
  });
}

function setupStageEntries() {
  const byKey = new Map(setupStageCatalog.map((stage) => [stage.stageKey, { ...stage, governed: true }]));

  // Preserve task contexts that are deliberately outside the normal governed
  // Stage list (for example a special operational area) instead of hiding them.
  state.tasks.forEach((task) => {
    if (!byKey.has(task.stageKey)) {
      byKey.set(task.stageKey, {
        stageKey: task.stageKey,
        stageName: task.stageName || 'Setup context',
        governed: false
      });
    }
  });

  return [...byKey.values()].sort(setupStageSort);
}

function tasksForStageKey(stageKey) {
  return sortedTasks().filter((task) => task.stageKey === stageKey);
}

function addProvisionalTaskForStage(stageKey) {
  const stage = setupStageEntries().find((item) => item.stageKey === stageKey);
  if (!stage) return;

  const name = prompt(`Practical Setup task for Stage ${stage.stageKey} — ${stage.stageName}:`);
  if (!name?.trim()) return;

  const id = `PROV-${Date.now()}`;
  state.tasks.push({
    id,
    stageKey: stage.stageKey,
    stageName: stage.stageName,
    order: 999,
    name: name.trim(),
    verification: 'UNVERIFIED',
    crew: 'To verify',
    duration: 'To verify',
    captain: 'To verify',
    equipment: 'To verify',
    completion: 'To verify',
    notes: 'Added during 2025 Setup verification; reusable definition still requires review.',
    dependencies: [],
    material: 'To verify',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  });

  saveState();
  renderAll();
  showView('review');
  selectTask(id);
}

function setupTaskReviewMarkup(task) {
  const deps = dependencyNames(task);
  const taskContext = task.stageName ? `<div class="task-meta">Task context: ${escapeHtml(task.stageName)}</div>` : '';
  return `
    <article class="task-row ${selectedTaskId === task.id ? 'selected' : ''}" data-task-id="${escapeHtml(task.id)}">
      <div class="task-row-top">
        <div>
          <h3>${escapeHtml(task.name)}</h3>
        </div>
        <span class="pill ${verificationClass(task.verification)}">2025 ${verificationLabel(task.verification)}</span>
      </div>
      ${taskContext}
      <div class="task-meta">Crew: ${escapeHtml(task.crew)} · Time: ${escapeHtml(task.duration)}</div>
      <div class="task-dependency">${deps.length ? `Requires: ${deps.map(escapeHtml).join('; ')}` : 'No task prerequisite recorded'}</div>
    </article>
  `;
}

renderSummary = function renderClearAnnualSummary() {
  const counts = state.tasks.reduce((acc, task) => {
    acc[task.verification] = (acc[task.verification] || 0) + 1;
    return acc;
  }, {});
  const missingStageCount = setupStageEntries().filter((stage) => tasksForStageKey(stage.stageKey).length === 0).length;

  el('summary-grid').innerHTML = `
    <div class="summary-card"><span>Reusable tasks</span><strong>${state.tasks.length}</strong></div>
    <div class="summary-card"><span>2025 unverified</span><strong>${counts.UNVERIFIED || 0}</strong></div>
    <div class="summary-card"><span>2025 needs correction</span><strong>${counts.NEEDS_CORRECTION || 0}</strong></div>
    <div class="summary-card"><span>2025 verified</span><strong>${counts.VERIFIED || 0}</strong></div>
    <div class="summary-card"><span>Stages with no tasks yet</span><strong>${missingStageCount}</strong></div>
  `;
};

renderReviewList = function renderAnnualVerificationQueue() {
  const filter = el('review-status-filter').value;
  const sections = [];

  setupStageEntries().forEach((stage) => {
    const allStageTasks = tasksForStageKey(stage.stageKey);
    const visibleTasks = allStageTasks.filter((task) => !filter || task.verification === filter);

    if (!allStageTasks.length) {
      if (filter && filter !== 'UNVERIFIED') return;
      sections.push(`
        <section class="review-stage missing-stage">
          <div class="review-stage-heading">Stage ${escapeHtml(stage.stageKey)} — ${escapeHtml(stage.stageName)}</div>
          <div class="stage-gap-row">
            <div>
              <strong>No provisional 2025 Setup tasks reconstructed yet.</strong>
              <div class="task-meta">This Stage exists; the missing task definition is a reconstruction gap, not proof that no Setup work exists.</div>
            </div>
            <button type="button" class="small add-stage-task" data-stage-key="${escapeHtml(stage.stageKey)}">Add Task</button>
          </div>
        </section>
      `);
      return;
    }

    if (!visibleTasks.length) return;
    sections.push(`
      <section class="review-stage">
        <div class="review-stage-heading">Stage ${escapeHtml(stage.stageKey)} — ${escapeHtml(stage.stageName)}</div>
        ${visibleTasks.map(setupTaskReviewMarkup).join('')}
      </section>
    `);
  });

  const reviewList = el('review-list');
  reviewList.innerHTML = sections.join('') || '<div class="empty-state">No 2025 tasks match this filter.</div>';

  reviewList.querySelectorAll('.task-row').forEach((row) => {
    row.addEventListener('click', () => selectTask(row.dataset.taskId));
  });
  reviewList.querySelectorAll('.add-stage-task').forEach((button) => {
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      addProvisionalTaskForStage(button.dataset.stageKey || '');
    });
  });
};

renderLibrary = function renderReusableTaskCatalog() {
  const sections = setupStageEntries().map((stage) => {
    const tasks = tasksForStageKey(stage.stageKey);
    if (!tasks.length) {
      return `
        <section class="library-stage missing-stage">
          <div class="library-stage-heading">Stage ${escapeHtml(stage.stageKey)} — ${escapeHtml(stage.stageName)}</div>
          <div class="stage-gap-row">
            <div>
              <strong>No reusable Setup tasks reconstructed yet.</strong>
              <div class="task-meta">Add tasks only when the practical work boundary is understood.</div>
            </div>
            <button type="button" class="small add-stage-task" data-stage-key="${escapeHtml(stage.stageKey)}">Add Task</button>
          </div>
        </section>
      `;
    }

    return `
      <section class="library-stage">
        <div class="library-stage-heading">Stage ${escapeHtml(stage.stageKey)} — ${escapeHtml(stage.stageName)}</div>
        ${tasks.map((task, index) => `
          <div class="library-task">
            <div class="library-order">${index + 1}</div>
            <div>
              <strong>${escapeHtml(task.name)}</strong>
              <div class="task-meta">Reusable task ID: ${escapeHtml(task.id)}</div>
            </div>
            <div class="task-meta">${dependencyNames(task).length ? `Requires: ${dependencyNames(task).map(escapeHtml).join('; ')}` : 'No prerequisite'}</div>
            <div class="library-actions">
              <button type="button" class="small secondary move-up" data-task-id="${escapeHtml(task.id)}" ${index === 0 ? 'disabled' : ''}>↑</button>
              <button type="button" class="small secondary move-down" data-task-id="${escapeHtml(task.id)}" ${index === tasks.length - 1 ? 'disabled' : ''}>↓</button>
              <button type="button" class="small open-task" data-task-id="${escapeHtml(task.id)}">Open Detail</button>
            </div>
          </div>
        `).join('')}
      </section>
    `;
  });

  const libraryList = el('library-list');
  libraryList.innerHTML = sections.join('');

  libraryList.querySelectorAll('.open-task').forEach((button) => {
    button.addEventListener('click', () => {
      showView('review');
      selectTask(button.dataset.taskId);
    });
  });
  libraryList.querySelectorAll('.move-up').forEach((button) => button.addEventListener('click', () => moveTask(button.dataset.taskId, -1)));
  libraryList.querySelectorAll('.move-down').forEach((button) => button.addEventListener('click', () => moveTask(button.dataset.taskId, 1)));
  libraryList.querySelectorAll('.add-stage-task').forEach((button) => {
    button.addEventListener('click', () => addProvisionalTaskForStage(button.dataset.stageKey || ''));
  });
};

const baseSelectTaskForReviewClarity = selectTask;
selectTask = function selectTaskWithAnnualClarity(taskId) {
  baseSelectTaskForReviewClarity(taskId);
  const task = taskById(taskId);
  if (!task) return;

  const pill = el('detail-verification');
  if (pill) pill.textContent = `2025 ${verificationLabel(task.verification)}`;

  const verifiedButton = el('mark-verified');
  const correctionButton = el('mark-correction');
  const unverifiedButton = el('mark-unverified');
  if (verifiedButton) verifiedButton.textContent = 'Mark 2025 Verified';
  if (correctionButton) correctionButton.textContent = '2025 Needs Correction';
  if (unverifiedButton) unverifiedButton.textContent = 'Back to 2025 Unverified';
};

function applySetupReviewLabels() {
  const reviewTab = document.querySelector('.tab[data-view="review"]');
  const libraryTab = document.querySelector('.tab[data-view="library"]');
  if (reviewTab) reviewTab.textContent = '2025 Verification';
  if (libraryTab) libraryTab.textContent = 'Manage Reusable Tasks';

  const reviewTitle = document.querySelector('#review-view .section-title h2');
  if (reviewTitle) reviewTitle.textContent = '2025 Verification Queue';
  const reviewHint = document.querySelector('#review-view .hint');
  if (reviewHint) reviewHint.textContent = 'This is the 2025 annual review queue. The status belongs to 2025; the reusable task definition itself carries forward to later seasons.';

  const libraryEyebrow = document.querySelector('#library-view .eyebrow');
  const libraryTitle = document.querySelector('#library-view .section-title h2');
  const libraryHint = document.querySelector('#library-view .hint');
  if (libraryEyebrow) libraryEyebrow.textContent = 'Permanent reusable knowledge';
  if (libraryTitle) libraryTitle.textContent = 'Reusable Task Catalog';
  if (libraryHint) libraryHint.textContent = 'Managers maintain permanent task identity, order, prerequisites, normal crew/resources, and task boundaries here. Annual 2025 verification status is intentionally not shown in this catalog.';
}

applySetupReviewLabels();
renderAll();
