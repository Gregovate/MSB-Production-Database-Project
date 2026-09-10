/* Browser-review fixes discovered while validating explicit Setup material sources.
 * Keeps the global task search truly global for Perform Work and surfaces
 * Display-Setup/material-source state in the Perform Work task list.
 */

(() => {
  function performSearchQuery() {
    return String(document.getElementById('setup-task-search')?.value || '')
      .trim()
      .toLocaleLowerCase();
  }

  function performSearchTask(task) {
    if (!task) return task;
    const catalogTask = typeof taskById === 'function'
      ? taskById(Number(task.setup_task_id))
      : null;
    return {
      ...(catalogTask || {}),
      ...task,
      dependencies: task.dependencies || catalogTask?.dependencies || []
    };
  }

  function performTaskMatchesSearch(task) {
    const query = performSearchQuery();
    if (!query) return true;
    const candidate = performSearchTask(task);
    if (typeof taskMatchesSearch === 'function') {
      return taskMatchesSearch(candidate);
    }
    return [
      candidate?.task_name,
      candidate?.stage_key,
      candidate?.stage_name,
      candidate?.scene_name,
      candidate?.task_action_type,
      ...(candidate?.dependencies || []).map((dep) => dep?.task_name)
    ]
      .filter(Boolean)
      .join(' ')
      .toLocaleLowerCase()
      .includes(query);
  }

  function performMaterialMetadata(taskId) {
    if (typeof setupMaterialMetadata === 'function') {
      return setupMaterialMetadata(taskId);
    }
    return { isDisplaySetupStep: false, sources: [] };
  }

  function appendPerformBadge(host, className, text, title) {
    if (!host) return;
    const badge = document.createElement('span');
    badge.className = `${className} setup-perform-material-badge`;
    badge.textContent = text;
    badge.title = title;
    host.appendChild(badge);
  }

  function applyPerformMaterialBadges() {
    const host = document.getElementById('next-perform-list');
    if (!host) return;
    host.querySelectorAll('.setup-perform-material-badge').forEach((badge) => badge.remove());

    host.querySelectorAll('.next-perform-task[data-task-id]').forEach((row) => {
      const taskId = Number(row.dataset.taskId || 0);
      if (!taskId) return;
      const metadata = performMaterialMetadata(taskId);
      const lead = row.querySelector('summary > span:first-child');
      const sourceCount = Array.isArray(metadata.sources) ? metadata.sources.length : 0;

      if (metadata.isDisplaySetupStep) {
        appendPerformBadge(
          lead,
          'setup-material-badge',
          'DISPLAY SETUP',
          'Physical Display Setup work. Display material is selected separately.'
        );
      }

      if (sourceCount > 0) {
        appendPerformBadge(
          lead,
          'setup-material-source-badge',
          `MATERIAL ${sourceCount}`,
          `${sourceCount} explicit current-LOR material source${sourceCount === 1 ? '' : 's'} selected.`
        );
      } else if (metadata.isDisplaySetupStep) {
        appendPerformBadge(
          lead,
          'setup-material-source-badge',
          'MATERIAL NONE',
          'This Display Setup task currently has no Display material source selected.'
        );
      }
    });
  }

  function applyPerformSearch() {
    const host = document.getElementById('next-perform-list');
    if (!host) return;
    const query = performSearchQuery();
    const rows = [...host.querySelectorAll('.next-perform-task[data-task-id]')];
    let visible = 0;

    rows.forEach((row) => {
      const taskId = Number(row.dataset.taskId || 0);
      const task = (typeof setupNextState !== 'undefined' && Array.isArray(setupNextState.executionTasks))
        ? setupNextState.executionTasks.find((item) => Number(item.setup_task_id) === taskId)
        : (typeof taskById === 'function' ? taskById(taskId) : null);
      const show = !query || performTaskMatchesSearch(task);
      row.hidden = !show;
      if (show) visible += 1;
    });

    host.querySelector('.setup-perform-search-empty')?.remove();
    if (query && rows.length && visible === 0) {
      const empty = document.createElement('div');
      empty.className = 'empty-state setup-perform-search-empty';
      empty.textContent = 'No Perform Work tasks match this search.';
      host.appendChild(empty);
    }

    applyPerformMaterialBadges();
  }

  if (typeof renderNextExecution === 'function') {
    const priorRenderNextExecution = renderNextExecution;
    renderNextExecution = function renderNextExecutionWithGlobalSearch() {
      priorRenderNextExecution();
      applyPerformSearch();
    };
  }

  const search = document.getElementById('setup-task-search');
  if (search) {
    search.addEventListener('input', () => {
      if (typeof renderNextExecution === 'function') renderNextExecution();
    });
  }

  const clear = document.getElementById('setup-task-search-clear');
  if (clear) {
    clear.addEventListener('click', () => {
      if (typeof renderNextExecution === 'function') renderNextExecution();
    });
  }

  if (typeof loadSetupMaterial === 'function') {
    const priorLoadSetupMaterial = loadSetupMaterial;
    loadSetupMaterial = async function loadSetupMaterialWithPerformState(options = {}) {
      const result = await priorLoadSetupMaterial(options);
      applyPerformSearch();
      return result;
    };
  }

  applyPerformSearch();
})();
