/* Fast governed predecessor entry for Setup Issue #151.
 *
 * Hold Shift before pressing the left mouse button on a Catalog task. The
 * dragged task is the dependent task; the task released over becomes the
 * prerequisite. Shift mode uses pointer events instead of native HTML5 drag so
 * Windows/browser modifier behavior cannot interfere with the gesture.
 * Ordinary drag remains owned by setup_next_pass.js unchanged.
 */
(() => {
  'use strict';

  const state = {
    active: false,
    pointerId: null,
    sourceTaskId: null,
    targetTaskId: null,
    sourceRow: null
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

  function resetState() {
    clearVisualState();
    state.active = false;
    state.pointerId = null;
    state.sourceTaskId = null;
    state.sourceRow = null;
    document.body.classList.remove('setup-dependency-pointer-drag');
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

  function rowAtPoint(clientX, clientY) {
    const hit = document.elementFromPoint(clientX, clientY);
    return hit instanceof Element ? hit.closest('.next-task-row') : null;
  }

  function updatePointerTarget(clientX, clientY) {
    if (!state.active) return;

    clearVisualState();
    if (state.sourceRow?.isConnected) {
      state.sourceRow.classList.add('dependency-dragging');
      state.sourceRow.dataset.dependencyRole = 'Dependent';
    }

    const row = rowAtPoint(clientX, clientY);
    const targetTaskId = Number(row?.dataset.taskId || 0);
    if (!row || !targetTaskId || targetTaskId === state.sourceTaskId) return;

    state.targetTaskId = targetTaskId;
    row.classList.add('dependency-drop-target');
    row.dataset.dependencyRole = 'Prerequisite target';
  }

  document.addEventListener('pointerdown', (event) => {
    if (state.active || event.button !== 0 || !event.shiftKey || !appState.access?.can_manage_setup) return;

    const target = event.target instanceof Element ? event.target : null;
    if (!target || target.closest('button, input, select, textarea, a')) return;

    const row = target.closest('.next-task-row');
    const taskId = Number(row?.dataset.taskId || 0);
    if (!row || !taskId) return;

    state.active = true;
    state.pointerId = event.pointerId;
    state.sourceTaskId = taskId;
    state.sourceRow = row;
    document.body.classList.add('setup-dependency-pointer-drag');

    row.classList.add('dependency-dragging');
    row.dataset.dependencyRole = 'Dependent';

    try {
      row.setPointerCapture(event.pointerId);
    } catch (_error) {
      // Capture is helpful but the document-level listeners below remain authoritative.
    }

    event.preventDefault();
    event.stopImmediatePropagation();
    setAlert(`Dependency mode: ${taskName(taskId)} is the dependent task. Release over the task that must happen first.`, 'ok');
  }, true);

  document.addEventListener('pointermove', (event) => {
    if (!state.active || event.pointerId !== state.pointerId) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    updatePointerTarget(event.clientX, event.clientY);
  }, true);

  document.addEventListener('pointerup', (event) => {
    if (!state.active || event.pointerId !== state.pointerId) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    updatePointerTarget(event.clientX, event.clientY);
    const dependentTaskId = Number(state.sourceTaskId || 0);
    const prerequisiteTaskId = Number(state.targetTaskId || 0);
    resetState();

    if (!dependentTaskId || !prerequisiteTaskId) {
      setAlert('Dependency drag canceled. Release the dependent task over another Setup task.', 'error');
      return;
    }

    void createPredecessorDependency(dependentTaskId, prerequisiteTaskId);
  }, true);

  document.addEventListener('pointercancel', (event) => {
    if (!state.active || event.pointerId !== state.pointerId) return;
    event.stopImmediatePropagation();
    resetState();
    setAlert('Dependency drag canceled.', 'error');
  }, true);

  // Native drag events must never start while custom Shift-pointer mode owns
  // the gesture. Ordinary non-Shift native drag remains untouched.
  document.addEventListener('dragstart', (event) => {
    if (!state.active) return;
    event.preventDefault();
    event.stopImmediatePropagation();
  }, true);

  installCatalogHint();
})();
