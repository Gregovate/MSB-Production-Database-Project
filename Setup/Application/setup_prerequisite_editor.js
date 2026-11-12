/* Canonical ordered prerequisite editor for Setup Issue 151. */
(() => {
  'use strict';

  let orderSyncPromise = null;

  function dependencyRowsForTask(taskId) {
    return (taskById(taskId)?.dependencies || []).map((dep) => ({
      setup_task_id: Number(dep.setup_task_id),
      task_name: dep.task_name || `Task ${dep.setup_task_id}`,
      dependency_note: dep.dependency_note || null,
      sort_order: Number(dep.sort_order || 0)
    }));
  }

  function loadOrderedDependencies({ rerender = true } = {}) {
    if (orderSyncPromise) return orderSyncPromise;
    orderSyncPromise = (async () => {
      const payload = await api('api/setup/dependencies/ordered');
      const grouped = new Map();
      for (const row of payload.dependencies || []) {
        const taskId = Number(row.setup_task_id);
        if (!grouped.has(taskId)) grouped.set(taskId, []);
        grouped.get(taskId).push({
          setup_task_id: Number(row.prerequisite_setup_task_id),
          task_name: row.task_name,
          dependency_note: row.dependency_note || null,
          sort_order: Number(row.sort_order || 0)
        });
      }
      for (const task of appState.tasks || []) {
        task.dependencies = grouped.get(Number(task.setup_task_id)) || [];
      }

      if (rerender) {
        if (typeof renderReviewList === 'function') renderReviewList();
        if (typeof renderLibrary === 'function') renderLibrary();
        const selected = taskById(appState.selectedTaskId);
        if (selected) renderCanonicalPrerequisites(selected);
      }
    })().finally(() => {
      orderSyncPromise = null;
    });
    return orderSyncPromise;
  }

  function installCanonicalDependencyEditor() {
    const section = el('detail-dependencies')?.closest('.detail-section');
    if (!section) return null;

    let editor = el('next-dependency-editor');
    if (!editor) {
      editor = document.createElement('div');
      editor.id = 'next-dependency-editor';
      editor.className = 'next-dependency-editor manager-only';
      section.appendChild(editor);
    }

    if (editor.dataset.canonicalPrerequisiteEditor !== '1') {
      editor.dataset.canonicalPrerequisiteEditor = '1';
      editor.innerHTML = `
        <div class="eyebrow">Add prerequisite</div>
        <div class="next-dependency-add">
          <select id="next-dependency-select" aria-label="Prerequisite task"></select>
          <input id="next-dependency-note" type="text" placeholder="Optional prerequisite note">
          <button id="next-dependency-add-button" type="button">Add prerequisite</button>
        </div>
        <div class="hint next-prerequisite-order-hint">Use ↑ / ↓ to change review order only. Every listed prerequisite is still required. Shift-drag in the Catalog remains the fastest way to add several prerequisites.</div>
      `;
      el('next-dependency-add-button').addEventListener('click', addCanonicalDependency);
    }
    return editor;
  }

  function renderCanonicalPrerequisites(task) {
    const target = el('detail-dependencies');
    if (!target || !task) return;
    const deps = dependencyRowsForTask(task.setup_task_id);
    const canManage = Boolean(appState.access?.can_manage_setup);

    target.classList.add('next-prerequisite-list');
    target.innerHTML = deps.length ? deps.map((dep, index) => `
      <div class="next-prerequisite-row" data-prereq-id="${dep.setup_task_id}">
        <div class="next-prerequisite-main">
          <span class="next-prerequisite-position">${index + 1}.</span>
          <div>
            <div class="next-prerequisite-name">${escapeHtml(dep.task_name)}</div>
            ${dep.dependency_note ? `<div class="next-prerequisite-note">${escapeHtml(dep.dependency_note)}</div>` : ''}
          </div>
        </div>
        ${canManage ? `<div class="next-prerequisite-actions">
          <button type="button" class="small secondary next-dependency-up next-dependency-remove" data-prereq-id="${dep.setup_task_id}" ${index === 0 ? 'disabled' : ''} aria-label="Move prerequisite up">↑</button>
          <button type="button" class="small secondary next-dependency-down next-dependency-remove" data-prereq-id="${dep.setup_task_id}" ${index === deps.length - 1 ? 'disabled' : ''} aria-label="Move prerequisite down">↓</button>
          <button type="button" class="small secondary next-dependency-delete next-dependency-remove" data-prereq-id="${dep.setup_task_id}">Remove</button>
        </div>` : ''}
      </div>
    `).join('') : '<div class="muted">No task prerequisite recorded.</div>';

    target.querySelectorAll('.next-dependency-up').forEach((button) => {
      button.addEventListener('click', () => reorderCanonicalDependency(task.setup_task_id, Number(button.dataset.prereqId), -1));
    });
    target.querySelectorAll('.next-dependency-down').forEach((button) => {
      button.addEventListener('click', () => reorderCanonicalDependency(task.setup_task_id, Number(button.dataset.prereqId), 1));
    });
    target.querySelectorAll('.next-dependency-delete').forEach((button) => {
      button.addEventListener('click', () => removeCanonicalDependency(task.setup_task_id, Number(button.dataset.prereqId)));
    });
  }

  function renderCanonicalDependencyEditor(task) {
    const editor = installCanonicalDependencyEditor();
    if (!editor || !task) return;
    editor.hidden = !appState.access?.can_manage_setup;

    const currentIds = new Set((task.dependencies || []).map((dep) => Number(dep.setup_task_id)));
    const options = sortedTasks().filter((candidate) => (
      Number(candidate.setup_task_id) !== Number(task.setup_task_id)
      && !currentIds.has(Number(candidate.setup_task_id))
    ));
    const select = el('next-dependency-select');
    select.innerHTML = options.length
      ? options.map((candidate) => `<option value="${candidate.setup_task_id}">${escapeHtml(nextTaskLabel(candidate))}</option>`).join('')
      : '<option value="">All available tasks are already prerequisites</option>';
    select.disabled = !options.length;
    el('next-dependency-add-button').disabled = !options.length;

    renderCanonicalPrerequisites(task);
  }

  async function refreshPrerequisiteState(taskId, message) {
    await reloadTasks(null);
    const fresh = taskById(taskId);
    if (fresh) selectTask(taskId);
    if (message) setAlert(message, 'ok');
  }

  async function addCanonicalDependency() {
    const task = taskById(appState.selectedTaskId);
    const prerequisiteId = Number(el('next-dependency-select')?.value || 0);
    if (!task || !prerequisiteId) return;
    try {
      setBusy(true);
      await api(
        `api/setup/tasks/${task.setup_task_id}/dependencies/${prerequisiteId}`,
        commandOptions('PATCH', {
          active: true,
          dependency_note: el('next-dependency-note').value.trim() || null
        })
      );
      el('next-dependency-note').value = '';
      await refreshPrerequisiteState(task.setup_task_id, 'Prerequisite added.');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  async function removeCanonicalDependency(taskId, prerequisiteId) {
    if (!window.confirm('Remove this prerequisite?')) return;
    try {
      setBusy(true);
      await api(
        `api/setup/tasks/${taskId}/dependencies/${prerequisiteId}`,
        commandOptions('PATCH', { active: false })
      );
      await refreshPrerequisiteState(taskId, 'Prerequisite removed.');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  async function reorderCanonicalDependency(taskId, prerequisiteId, direction) {
    const deps = dependencyRowsForTask(taskId);
    const index = deps.findIndex((dep) => Number(dep.setup_task_id) === Number(prerequisiteId));
    const destination = index + direction;
    if (index < 0 || destination < 0 || destination >= deps.length) return;

    [deps[index], deps[destination]] = [deps[destination], deps[index]];
    const orderedIds = deps.map((dep) => Number(dep.setup_task_id));
    try {
      setBusy(true);
      await api(
        `api/setup/tasks/${taskId}/dependencies/order`,
        commandOptions('PATCH', { prerequisite_setup_task_ids: orderedIds })
      );
      await refreshPrerequisiteState(taskId, 'Prerequisite review order updated.');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  if (typeof installDependencyEditor === 'function') {
    installDependencyEditor = installCanonicalDependencyEditor;
  }
  if (typeof renderDependencyEditor === 'function') {
    renderDependencyEditor = renderCanonicalDependencyEditor;
  }
  if (typeof addNextDependency === 'function') {
    addNextDependency = addCanonicalDependency;
  }
  if (typeof removeNextDependency === 'function') {
    removeNextDependency = function removeNextDependencyCanonical(task, prereqId) {
      return removeCanonicalDependency(task.setup_task_id, prereqId);
    };
  }

  if (typeof reloadTasks === 'function') {
    const priorReloadTasks = reloadTasks;
    reloadTasks = async function reloadTasksWithOrderedPrerequisites(...args) {
      const result = await priorReloadTasks(...args);
      await loadOrderedDependencies({ rerender: false });
      if (typeof renderReviewList === 'function') renderReviewList();
      if (typeof renderLibrary === 'function') renderLibrary();
      const selected = taskById(appState.selectedTaskId);
      if (selected) renderCanonicalDependencyEditor(selected);
      return result;
    };
  }

  if (typeof selectTask === 'function') {
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithCanonicalPrerequisites(taskId) {
      const result = priorSelectTask(taskId);
      const task = taskById(taskId);
      if (task) renderCanonicalDependencyEditor(task);
      return result;
    };
  }

  if (appState.tasks?.length) {
    void loadOrderedDependencies().catch((error) => {
      setAlert(error.message || error, 'error');
    });
  }
})();
