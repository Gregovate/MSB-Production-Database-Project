/* Fast governed predecessor entry for Setup Issue #151.
 *
 * Hold Shift before starting a Catalog task drag. The dragged task is the
 * dependent task; the task it is dropped onto becomes the prerequisite.
 * Ordinary drag is intentionally left to setup_next_pass.js unchanged.
 */
(() => {
  'use strict';

  const state = {
    shiftArmed: false,
    armedTaskId: null,
    dependencyMode: false,
    sourceTaskId: null,
    targetTaskId: null
  };

  function taskName(taskId) {
    const task = typeof taskById === 'function' ? taskById(Number(taskId)) : null;
    return task?.task_name || `Task ${taskId}`;
  }

  function clearVisualState() {
    document.querySelectorAll('.next-task-row').forEach((row) => {
      row.classList.remove('dependency-dragging', 'dependency-drop-target');
      row.removeAttribute('data-dependency-role');
    });
    state.targetTaskId = null;
  }

  function clearArmedState() {
    state.shiftArmed = false;
    state.armedTaskId = null;
  }

  function finishDependencyDrag() {
    clearVisualState();
    clearArmedState();
    state.dependencyMode = false;
    state.sourceTaskId = null;
  }

  function installCatalogHint() {
    const list = document.getElementById('library-list');
    if (!list || document.getElementById('next-predecessor-drag-hint')) return;
    const hint = document.createElement('div');
    hint.id = 'next-predecessor-drag-hint';
    hint.className = 'hint next-predecessor-drag-hint manager-only';
    hint.innerHTML = '<strong>Fast prerequisite entry:</strong> Hold <kbd>Shift</kbd> before pressing the left mouse button, then drag the later/dependent task onto the task that must happen first. Normal drag still moves/reorders tasks.';
    list.insertAdjacentElement('beforebegin', hint);
  }

  async function createPredecessorDependency(dependentTaskId, prerequisiteTaskId) {
    const dependentName = taskName(dependentTaskId);
    const prerequisiteName = taskName(prerequisiteTaskId);
    try {
      setBusy(true);
      await api(
        `api/setup/tasks/${dependentTaskId}/dependencies/${prerequisiteTaskId}`,
        commandOptions('PATCH', {
          active: true,
          dependency_note: null
        })
      );
      await reloadTasks(null);
      await loadNextOrganization(false);
      renderLibrary();
      setAlert(`Prerequisite saved: ${dependentName} depends on ${prerequisiteName}. Neither task moved.`, 'ok');
    } catch (error) {
      const message = error.message || error;
      setAlert(message, 'error');
      window.alert(message);
    } finally {
      setBusy(false);
    }
  }

  document.addEventListener('pointerdown', (event) => {
    if (state.dependencyMode) return;
    if (event.button !== 0) {
      clearArmedState();
      return;
    }

    const row = event.target instanceof Element ? event.target.closest('.next-task-row') : null;
    if (!row || !event.shiftKey || !appState.access?.can_manage_setup) {
      clearArmedState();
      return;
    }

    const taskId = Number(row.dataset.taskId || 0);
    if (!taskId) {
      clearArmedState();
      return;
    }

    state.shiftArmed = true;
    state.armedTaskId = taskId;
  }, true);

  document.addEventListener('pointerup', () => {
    if (!state.dependencyMode) clearArmedState();
  }, true);

  document.addEventListener('dragstart', (event) => {
    const row = event.target instanceof Element ? event.target.closest('.next-task-row') : null;
    if (!row || !appState.access?.can_manage_setup) return;

    const taskId = Number(row.dataset.taskId || 0);
    const armedForThisTask = state.shiftArmed && Number(state.armedTaskId) === taskId;
    if (!taskId || (!armedForThisTask && !event.shiftKey)) return;

    state.dependencyMode = true;
    state.sourceTaskId = taskId;
    clearVisualState();
    row.classList.add('dependency-dragging');
    row.dataset.dependencyRole = 'Dependent';

    if (event.dataTransfer) {
      // Use a permissive native drag effect. On Windows, Shift influences the
      // browser's requested effect; restricting effectAllowed to "link" can
      // prevent the drag from starting. The application still consumes the
      // drop and performs only the dependency command below.
      event.dataTransfer.effectAllowed = 'all';
      event.dataTransfer.setData('application/x-msb-setup-dependent-task', String(taskId));
      event.dataTransfer.setData('text/plain', String(taskId));
    }

    // Prevent the existing ordinary move/reorder dragstart handler from running.
    event.stopImmediatePropagation();
    setAlert(`Dependency mode: ${taskName(taskId)} is the dependent task. Drop it onto the task that must happen first.`, 'ok');
  }, true);

  document.addEventListener('dragover', (event) => {
    if (!state.dependencyMode) return;

    // Shift-drag must never fall through to the ordinary row/scope move handlers.
    event.preventDefault();
    event.stopImmediatePropagation();
    clearVisualState();

    const row = event.target instanceof Element ? event.target.closest('.next-task-row') : null;
    const targetTaskId = Number(row?.dataset.taskId || 0);
    if (!row || !targetTaskId || targetTaskId === state.sourceTaskId) {
      if (event.dataTransfer) event.dataTransfer.dropEffect = 'none';
      const sourceRow = document.querySelector(`.next-task-row[data-task-id="${state.sourceTaskId}"]`);
      sourceRow?.classList.add('dependency-dragging');
      if (sourceRow) sourceRow.dataset.dependencyRole = 'Dependent';
      return;
    }

    const sourceRow = document.querySelector(`.next-task-row[data-task-id="${state.sourceTaskId}"]`);
    sourceRow?.classList.add('dependency-dragging');
    if (sourceRow) sourceRow.dataset.dependencyRole = 'Dependent';

    state.targetTaskId = targetTaskId;
    row.classList.add('dependency-drop-target');
    row.dataset.dependencyRole = 'Prerequisite target';
    if (event.dataTransfer) event.dataTransfer.dropEffect = 'move';
  }, true);

  document.addEventListener('drop', (event) => {
    if (!state.dependencyMode) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    const dependentTaskId = Number(state.sourceTaskId || 0);
    const row = event.target instanceof Element ? event.target.closest('.next-task-row') : null;
    const prerequisiteTaskId = Number(row?.dataset.taskId || 0);
    finishDependencyDrag();

    if (!dependentTaskId || !prerequisiteTaskId) {
      setAlert('Dependency drag canceled. Drop the dependent task onto another Setup task.', 'error');
      return;
    }
    if (dependentTaskId === prerequisiteTaskId) {
      setAlert('A Setup task cannot depend on itself.', 'error');
      return;
    }

    void createPredecessorDependency(dependentTaskId, prerequisiteTaskId);
  }, true);

  document.addEventListener('dragend', (event) => {
    if (!state.dependencyMode) {
      clearArmedState();
      return;
    }
    event.stopImmediatePropagation();
    finishDependencyDrag();
  }, true);

  installCatalogHint();
})();
