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

  const helpButton = document.createElement('button');
  helpButton.className = 'tab';
  helpButton.dataset.view = 'help';
  helpButton.type = 'button';
  helpButton.textContent = 'How Setup Works';
  helpButton.addEventListener('click', () => showView('help'));
  tabs.appendChild(helpButton);

  const helpView = document.createElement('section');
  helpView.id = 'help-view';
  helpView.className = 'view';
  helpView.innerHTML = `
    <div class="card setup-help-card">
      <div class="eyebrow">Plain-English Manager guide</div>
      <h2>How Setup Session Works</h2>
      <p>This browser review is validating the reusable Setup plan and the 2025 reconstruction. Scheduling, Pick Lists, and field movement/scanning are the next operational layer and are not active in this candidate yet.</p>
      <div class="setup-help-grid">
        <section class="setup-help-section">
          <h3>1. Verify 2025</h3>
          <p><strong>Reusable Task Definition</strong> is the normal job we expect to do again. <strong>2025 Annual Historical Actual</strong> is what happened in 2025.</p>
          <ul>
            <li><strong>Verified</strong>: the reusable task and 2025 information are reasonable.</li>
            <li><strong>Needs Correction</strong>: something needs to be fixed before accepting it.</li>
            <li><strong>Unverified</strong>: nobody has accepted it yet.</li>
          </ul>
        </section>
        <section class="setup-help-section">
          <h3>2. Reusable tasks and Stage sequence</h3>
          <p>A reusable task is practical work worth planning each season. Sequence numbers 10, 20, 30, etc. mean the normal precedence <strong>within that Stage</strong>. They do not mean the entire Setup day runs as one serial queue.</p>
          <p>Managers can drag tasks within a Stage or use ↑ / ↓. Use <strong>Copy</strong> for a similar task; equipment/resources copy, but prerequisites and annual history do not.</p>
        </section>
        <section class="setup-help-section">
          <h3>3. Prerequisites and readiness</h3>
          <p>A prerequisite means the next task cannot practically proceed until another task is complete. Dependencies may cross Stages, such as the Arch Trailer unload route.</p>
          <p>Readiness is different: a task such as Festive Trees can remain NOT_READY until an outside condition is satisfied, such as leaves falling from the trees.</p>
          <p>Dependency editing is not exposed yet. During this review, flag missing or wrong prerequisites.</p>
        </section>
        <section class="setup-help-section">
          <h3>4. Scheduling model coming next</h3>
          <p>One task can span multiple days. One day can have parallel crews. Scheduled work is grouped by <strong>Morning</strong>, <strong>Afternoon</strong>, or <strong>All Day</strong>.</p>
          <p>The reusable Stage sequence is a planning starting point; the actual work-day plan can intentionally run Stow Storm, Elf Choir, and other work in parallel.</p>
        </section>
        <section class="setup-help-section">
          <h3>5. Pick Lists</h3>
          <p>The Pick List will be derived from the tasks scheduled for a work day/shift: required Displays → their current Containers + supplemental support/KIT Containers → deduplicated physical pull list.</p>
          <p>A Pick List replaces manual material bookkeeping, not real labor. A true Prepare/Load task remains a task if people actually spend meaningful time doing that work.</p>
        </section>
        <section class="setup-help-section">
          <h3>6. Movement and scanning</h3>
          <p>Scanning identifies the physical Display, Container, or Location. Setup Session owns what that scan means operationally. The audited movement command layer is not active in this browser candidate.</p>
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
