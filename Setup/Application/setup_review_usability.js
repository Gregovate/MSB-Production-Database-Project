/* Manager review guidance and reusable-task ordering helpers. */

const setupReviewUsability = {
  draggedTaskId: null
};

function setupReviewIsLocalPreview() {
  return ['127.0.0.1', 'localhost', '::1'].includes(window.location.hostname);
}

function setupTaskUpdatePayload(task, overrides = {}) {
  return {
    task_name: task.task_name,
    stage_id: task.stage_id == null ? null : Number(task.stage_id),
    task_action_type: task.task_action_type || 'WORK',
    display_order: Number(task.display_order) || 100,
    active_flag: Boolean(task.active_flag),
    normal_crew_min: task.normal_crew_min == null ? null : Number(task.normal_crew_min),
    normal_crew_max: task.normal_crew_max == null ? null : Number(task.normal_crew_max),
    expected_duration_minutes: task.expected_duration_minutes == null ? null : Number(task.expected_duration_minutes),
    completion_point: task.completion_point || null,
    readiness_note: task.readiness_note || null,
    weather_note: task.weather_note || null,
    reusable_notes: task.reusable_notes || null,
    ...overrides
  };
}

function setupTasksForStage(task) {
  return sortedTasks().filter((candidate) => (
    String(candidate.stage_key ?? '—') === String(task.stage_key ?? '—')
  ));
}

async function persistSetupStageOrder(orderedIds) {
  if (!appState.access?.can_manage_setup || !orderedIds.length) return;
  const selected = appState.selectedTaskId;
  const firstTask = taskById(orderedIds[0]);
  const stageLabel = firstTask?.stage_key || 'General';

  try {
    setBusy(true);
    for (let index = 0; index < orderedIds.length; index += 1) {
      const task = taskById(orderedIds[index]);
      if (!task) continue;
      const newOrder = (index + 1) * 10;
      if (Number(task.display_order) === newOrder) continue;
      await api(
        `api/setup/tasks/${task.setup_task_id}`,
        commandOptions('PATCH', setupTaskUpdatePayload(task, { display_order: newOrder }))
      );
    }
    setAlert(`Stage ${stageLabel} reusable task sequence updated.`, 'ok');
    await reloadTasks(selected || null);
    showView('library');
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function moveSetupLibraryTask(taskId, direction) {
  const task = taskById(taskId);
  if (!task || !appState.access?.can_manage_setup) return;
  const sameStage = setupTasksForStage(task);
  const index = sameStage.findIndex((item) => Number(item.setup_task_id) === Number(taskId));
  const swapIndex = index + direction;
  if (index < 0 || swapIndex < 0 || swapIndex >= sameStage.length) return;
  const ids = sameStage.map((item) => Number(item.setup_task_id));
  [ids[index], ids[swapIndex]] = [ids[swapIndex], ids[index]];
  await persistSetupStageOrder(ids);
}

async function copySetupReusableTask(taskId) {
  const source = taskById(taskId);
  if (!source || !appState.access?.can_manage_setup) return;

  const proposedName = `${source.task_name} Copy`;
  const newName = window.prompt('Name for the copied reusable task:', proposedName);
  if (newName == null || !newName.trim()) return;

  if (!window.confirm(
    'Copy this reusable task definition and its equipment/resources?\n\n' +
    'Prerequisites and annual history will NOT be copied.'
  )) return;

  try {
    setBusy(true);
    const resourcePayload = await api(`api/setup/tasks/${source.setup_task_id}/resources`);
    const resources = resourcePayload.resources || [];
    const createPayload = {
      task_name: newName.trim(),
      stage_id: source.stage_id == null ? null : Number(source.stage_id),
      task_action_type: source.task_action_type || 'WORK',
      display_order: (Number(source.display_order) || 100) + 5,
      normal_crew_min: source.normal_crew_min == null ? null : Number(source.normal_crew_min),
      normal_crew_max: source.normal_crew_max == null ? null : Number(source.normal_crew_max),
      expected_duration_minutes: source.expected_duration_minutes == null ? null : Number(source.expected_duration_minutes),
      completion_point: source.completion_point || null,
      readiness_note: source.readiness_note || null,
      weather_note: source.weather_note || null,
      reusable_notes: [
        source.reusable_notes || '',
        `[Copied from reusable task ${source.setup_task_id}; review task-specific details before use.]`
      ].filter(Boolean).join('\n')
    };

    const created = await api('api/setup/tasks', commandOptions('POST', createPayload));
    const newId = created.setup_task?.setup_task_id;
    if (!newId) throw new Error('Copied reusable task did not return a new task ID.');

    for (const resource of resources) {
      await api(
        `api/setup/tasks/${newId}/resources/${resource.setup_resource_id}`,
        commandOptions('PATCH', {
          quantity_required: Number(resource.quantity_required) || 1,
          requirement_type: resource.requirement_type || 'REQUIRED',
          notes: resource.notes || null,
          active_flag: true
        })
      );
    }

    setAlert(
      `Reusable task ${source.setup_task_id} copied to task ${newId} with ${resources.length} equipment/resource assignment${resources.length === 1 ? '' : 's'}. Prerequisites and annual history were not copied.`,
      'ok'
    );
    await reloadTasks(null);
    showView('library');
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function enhanceSetupLibrary() {
  const canManage = Boolean(appState.access?.can_manage_setup);
  const rows = [...document.querySelectorAll('#library-list .library-task')];

  rows.forEach((row) => {
    const openButton = row.querySelector('.open-task');
    if (!openButton) return;
    const taskId = Number(openButton.dataset.taskId);
    const task = taskById(taskId);
    if (!task) return;
    const sameStage = setupTasksForStage(task);
    const index = sameStage.findIndex((item) => Number(item.setup_task_id) === taskId);

    row.dataset.taskId = String(taskId);
    row.dataset.stageKey = String(task.stage_key ?? '—');
    row.draggable = canManage;

    if (canManage) {
      const actions = row.querySelector('.library-actions');
      if (actions) {
        const up = document.createElement('button');
        up.type = 'button';
        up.className = 'small secondary stage-move-up';
        up.textContent = '↑';
        up.title = 'Move earlier in this Stage';
        up.disabled = index <= 0;
        up.addEventListener('click', (event) => {
          event.stopPropagation();
          moveSetupLibraryTask(taskId, -1);
        });

        const down = document.createElement('button');
        down.type = 'button';
        down.className = 'small secondary stage-move-down';
        down.textContent = '↓';
        down.title = 'Move later in this Stage';
        down.disabled = index < 0 || index >= sameStage.length - 1;
        down.addEventListener('click', (event) => {
          event.stopPropagation();
          moveSetupLibraryTask(taskId, 1);
        });

        const copy = document.createElement('button');
        copy.type = 'button';
        copy.className = 'small secondary copy-task';
        copy.textContent = 'Copy';
        copy.title = 'Copy reusable definition and equipment/resources';
        copy.addEventListener('click', (event) => {
          event.stopPropagation();
          copySetupReusableTask(taskId);
        });

        actions.insertBefore(up, openButton);
        actions.insertBefore(down, openButton);
        actions.insertBefore(copy, openButton);
      }

      row.addEventListener('dragstart', (event) => {
        setupReviewUsability.draggedTaskId = taskId;
        row.classList.add('dragging');
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', String(taskId));
      });

      row.addEventListener('dragover', (event) => {
        const dragged = taskById(setupReviewUsability.draggedTaskId);
        if (!dragged || String(dragged.stage_key ?? '—') !== String(task.stage_key ?? '—')) return;
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        row.classList.add('drop-target');
      });

      row.addEventListener('dragleave', () => row.classList.remove('drop-target'));
      row.addEventListener('drop', async (event) => {
        event.preventDefault();
        row.classList.remove('drop-target');
        const sourceId = Number(event.dataTransfer.getData('text/plain') || setupReviewUsability.draggedTaskId || 0);
        if (!sourceId || sourceId === taskId) return;
        const source = taskById(sourceId);
        if (!source || String(source.stage_key ?? '—') !== String(task.stage_key ?? '—')) return;

        const ids = setupTasksForStage(task).map((item) => Number(item.setup_task_id));
        const sourceIndex = ids.indexOf(sourceId);
        let targetIndex = ids.indexOf(taskId);
        if (sourceIndex < 0 || targetIndex < 0) return;
        ids.splice(sourceIndex, 1);
        if (sourceIndex < targetIndex) targetIndex -= 1;
        ids.splice(targetIndex, 0, sourceId);
        await persistSetupStageOrder(ids);
      });

      row.addEventListener('dragend', () => {
        setupReviewUsability.draggedTaskId = null;
        document.querySelectorAll('.library-task').forEach((item) => {
          item.classList.remove('dragging', 'drop-target');
        });
      });
    }
  });
}

function installSetupHowItWorks() {
  const tabs = document.querySelector('.tabs');
  if (!tabs || document.getElementById('help-view')) return;

  const pickListButton = document.createElement('button');
  pickListButton.id = 'setup-pick-list-link';
  pickListButton.className = 'tab';
  pickListButton.type = 'button';
  pickListButton.textContent = 'Pick List';
  pickListButton.addEventListener('click', () => {
    const query = appState.seasonYear == null
      ? ''
      : '?season_year=' + encodeURIComponent(appState.seasonYear);
    window.location.href = 'pick-list/' + query;
  });

  const recordLocationButton = document.createElement('button');
  recordLocationButton.id = 'setup-record-location-link';
  recordLocationButton.className = 'tab';
  recordLocationButton.type = 'button';
  recordLocationButton.textContent = 'Record Location';
  recordLocationButton.addEventListener('click', () => {
    const query = appState.seasonYear == null
      ? ''
      : '?season_year=' + encodeURIComponent(appState.seasonYear);
    window.location.href = 'record-location/' + query;
  });

  const helpButton = document.createElement('button');
  helpButton.className = 'tab';
  helpButton.dataset.view = 'help';
  helpButton.type = 'button';
  helpButton.textContent = 'How Setup Works';
  helpButton.addEventListener('click', () => showView('help'));
  tabs.appendChild(pickListButton);
  tabs.appendChild(recordLocationButton);
  tabs.appendChild(helpButton);

  const helpView = document.createElement('section');
  helpView.id = 'help-view';
  helpView.className = 'view';
  helpView.innerHTML = `
    <div class="card setup-help-card">
      <div class="eyebrow">Plain-English Manager guide</div>
      <h2>How Setup Session Works</h2>
      <p>The reusable Catalog holds what we know about recurring Setup work. The annual Session is the live plan for this season. The Scheduling Board connects that plan to Crews/Captains, material demand, field execution, and Report Work. <strong>It is an operational system, not a post-it board.</strong></p>
      <div class="setup-help-grid">
        <section class="setup-help-section">
          <h3>1. Reusable work vs. this season</h3>
          <p><strong>Reusable tasks</strong> hold the normal knowledge we expect to use again: task name, Stage/Scene, crew/time expectations, instructions, resources, and normal sequence.</p>
          <p>The <strong>annual Session</strong> is this season's working copy. Scheduling, readiness, progress, Captains, and actual work can change during Setup without rewriting what happened in another season.</p>
        </section>
        <section class="setup-help-section">
          <h3>2. Prerequisites and readiness</h3>
          <p>A <strong>prerequisite</strong> means another task should be completed first. Blocking ON keeps hard-blocked work out of the normal scheduling candidates so crews are not accidentally sent into work that cannot proceed.</p>
          <p><strong>Readiness</strong> is different. It is a current condition such as weather, leaves, access, or another outside dependency. NOT READY keeps the condition visible and warns a Manager if the task is deliberately scheduled anyway.</p>
        </section>
        <section class="setup-help-section">
          <h3>3. The Scheduling Board is live dispatch</h3>
          <p>Work is assigned to a Setup Day, <strong>AM or PM</strong>, and a Crew. The Captain belongs to that Crew. Moving work to another Crew changes who is responsible for it.</p>
          <p>Unworked assignments are deliberately movable because plans change. Click one task, <strong>Ctrl/Cmd+click</strong> to add or remove individual tasks, or <strong>Shift+click</strong> to select a range, then drag any selected task to move the group. Use <strong>Find scheduled task</strong> when you know the Stage, task name, or Captain but not where the task landed.</p>
          <p>The schedule drives more than the screen: it feeds Captain work, near-term material demand, and the operational record of what we intended to do.</p>
        </section>
        <section class="setup-help-section">
          <h3>4. Materials and movement</h3>
          <p>The <strong>Pick List</strong> is derived from live scheduled work plus bounded early demand. It tells the workshop what physical Displays, Containers, Kits, and Extra Material sources are needed; it does not mean the work itself is complete.</p>
          <p><strong>Record Location</strong> records where a Container or Display actually moved in the field. A normal QR scan identifies the item and opens its actions; scanning by itself is not a movement write.</p>
        </section>
        <section class="setup-help-section">
          <h3>5. Perform Work and Report Work</h3>
          <p>Captains use <strong>Perform Work</strong> for the work assigned to their Crew. <strong>Report Work</strong> records what actually happened: work date, crew size, time spent, cumulative percent complete, and what was done or remains.</p>
          <p>Once work is reported, that scheduled assignment becomes <strong>locked history</strong>. At 100% the task is complete. If it is only partially complete, the task returns to <strong>Needs Scheduling Again</strong> with its progress preserved and can be assigned to a different Crew/Captain later.</p>
          <p>Percent complete describes progress only. It does <strong>not</strong> mean the same percentage of expected hours has been used or remains.</p>
        </section>
        <section class="setup-help-section">
          <h3>6. Corrections preserve history</h3>
          <p>If a work report was entered wrong, use <strong>Report Correction</strong> rather than trying to move or rewrite the historical assignment. Corrections update the reported facts while preserving the work/report identity and audit trail.</p>
          <p>The plan is expected to change frequently. Future unworked assignments can move; reported work stays historical. That distinction lets the board stay flexible without losing what actually happened.</p>
        </section>
      </div>
    </div>
  `;
  document.querySelector('main')?.appendChild(helpView);
}

function clarifySetupOrderLabels() {
  const editOrder = document.getElementById('edit-display-order');
  if (editOrder?.closest('label')) {
    editOrder.closest('label').childNodes[0].nodeValue = 'Stage sequence';
  }
  const addOrder = document.getElementById('add-display-order');
  if (addOrder?.closest('label')) {
    addOrder.closest('label').childNodes[0].nodeValue = 'Stage sequence';
  }

  const libraryHint = document.querySelector('#library-view .hint');
  if (libraryHint && !document.querySelector('.sequence-explainer')) {
    const note = document.createElement('div');
    note.className = 'hint sequence-explainer';
    note.textContent = 'Stage sequence (10, 20, 30...) expresses normal precedence within a Stage. Drag tasks or use ↑ / ↓ to reorder. Daily scheduling will separately support shifts, parallel crews, and multi-day work.';
    libraryHint.insertAdjacentElement('afterend', note);
  }
}

function installPreviewReviewNotice() {
  if (!setupReviewIsLocalPreview() || document.querySelector('.preview-review-notice')) return;
  const notice = document.createElement('section');
  notice.className = 'notice preview-review-notice';
  notice.innerHTML = '<strong>Browser Review — disposable clone.</strong> Changes in this preview are shared only inside the disposable review database and are discarded during cleanup. Production is not being edited.';
  const appAlert = document.getElementById('app-alert');
  appAlert?.insertAdjacentElement('beforebegin', notice);
}

const baseSetupReviewSetAlert = setAlert;
setAlert = function setupReviewAwareAlert(message, state = 'ok') {
  let adjusted = String(message ?? '');
  const target = document.getElementById('app-alert');

  if (
    setupReviewIsLocalPreview()
    && adjusted.includes(' Setup Session loaded from Production. Changes made by authorized Managers are shared immediately.')
  ) {
    if (target) {
      target.textContent = '';
      target.hidden = true;
    }
    return;
  }

  if (target) target.hidden = false;
  if (setupReviewIsLocalPreview()) {
    adjusted = adjusted
      .replaceAll(' saved to Production.', ' saved to the disposable review clone.')
      .replaceAll(' created in Production.', ' created in the disposable review clone.')
      .replaceAll(' loaded from Production.', ' loaded from the disposable review clone.')
      .replaceAll('shared immediately.', 'shared inside this disposable review clone.');
  }
  return baseSetupReviewSetAlert(adjusted, state);
};

const baseSetupReviewRenderLibrary = renderLibrary;
renderLibrary = function renderLibraryWithReviewUsability() {
  baseSetupReviewRenderLibrary();
  enhanceSetupLibrary();
  clarifySetupOrderLabels();
};

installSetupHowItWorks();
installPreviewReviewNotice();
clarifySetupOrderLabels();
if (appState.tasks?.length) renderLibrary();
