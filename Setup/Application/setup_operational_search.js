/* Extend the existing global Setup task search to Plan / Schedule and Perform Work. */

(() => {
  const SEARCH_HIDDEN_CLASS = 'setup-operational-search-hidden';

  function setSearchVisible(node, visible) {
    if (!node) return;
    node.classList.toggle(SEARCH_HIDDEN_CLASS, !visible);
  }

  function searchQuery() {
    return String(document.getElementById('setup-task-search')?.value || '')
      .trim()
      .toLocaleLowerCase();
  }

  function taskSearchText(task) {
    return [
      task?.task_name,
      task?.stage_key,
      task?.stage_name,
      task?.scene_name,
      task?.task_action_type,
      ...(task?.dependencies || []).map((dep) => dep?.task_name)
    ]
      .filter(Boolean)
      .join(' ')
      .toLocaleLowerCase();
  }

  function taskMatchesSearch(task) {
    const query = searchQuery();
    return !query || taskSearchText(task).includes(query);
  }

  function sessionTaskById(sessionTaskId) {
    if (typeof setupNextState === 'undefined') return null;
    return (setupNextState.executionTasks || []).find(
      (task) => Number(task.setup_session_task_id) === Number(sessionTaskId)
    ) || null;
  }

  function syncFlatStageScopeHeadings(target, visibleRows) {
    const query = searchQuery();
    const headings = [...target.querySelectorAll('.setup-stage-order-heading, .setup-stage-scope-heading')];
    headings.forEach((heading) => setSearchVisible(heading, !query));
    if (!query) return;

    visibleRows.forEach((row) => {
      let cursor = row.previousElementSibling;
      let scopeFound = false;
      while (cursor) {
        if (!scopeFound && cursor.classList.contains('setup-stage-scope-heading')) {
          setSearchVisible(cursor, true);
          scopeFound = true;
        }
        if (cursor.classList.contains('setup-stage-order-heading')) {
          setSearchVisible(cursor, true);
          break;
        }
        cursor = cursor.previousElementSibling;
      }
    });
  }

  function renderEmptySearchState(target, className, message, visibleCount) {
    target.querySelector(`.${className}`)?.remove();
    if (!searchQuery() || visibleCount > 0) return;
    const empty = document.createElement('div');
    empty.className = `${className} empty-state`;
    empty.textContent = message;
    target.appendChild(empty);
  }

  function applyPlanningSearch() {
    const target = document.getElementById('next-planning-backlog');
    if (!target) return;
    const query = searchQuery();
    const rows = [...target.querySelectorAll('.next-plan-row')];
    const visibleRows = [];

    rows.forEach((row) => {
      const task = sessionTaskById(Number(row.dataset.sessionTaskId));
      const show = !query || taskMatchesSearch(task);
      setSearchVisible(row, show);
      if (show) visibleRows.push(row);
    });

    syncFlatStageScopeHeadings(target, visibleRows);
    renderEmptySearchState(
      target,
      'setup-operational-search-empty',
      'No Plan / Schedule tasks match this search.',
      visibleRows.length
    );

    const select = document.getElementById('next-schedule-task');
    if (select) {
      const options = [...select.options];
      options.forEach((option) => {
        const task = sessionTaskById(Number(option.value));
        const hide = Boolean(query) && !taskMatchesSearch(task);
        option.hidden = hide;
        option.disabled = hide;
      });
      if (select.selectedOptions?.[0]?.hidden || select.selectedOptions?.[0]?.disabled) {
        const firstVisible = options.find((option) => !option.hidden && !option.disabled);
        if (firstVisible) select.value = firstVisible.value;
      }
    }
  }

  function applyPerformSearch() {
    const target = document.getElementById('next-perform-list');
    if (!target) return;
    const query = searchQuery();
    const rows = [...target.querySelectorAll('.next-perform-task')];
    const visibleRows = [];

    rows.forEach((row) => {
      const task = sessionTaskById(Number(row.dataset.sessionTaskId));
      const show = !query || taskMatchesSearch(task);
      setSearchVisible(row, show);
      if (show) visibleRows.push(row);
    });

    syncFlatStageScopeHeadings(target, visibleRows);
    renderEmptySearchState(
      target,
      'setup-perform-search-empty',
      'No Perform Work tasks match this search.',
      visibleRows.length
    );
  }

  if (typeof renderPlanningBacklog === 'function') {
    const baseRenderPlanningBacklog = renderPlanningBacklog;
    renderPlanningBacklog = function renderPlanningBacklogWithOperationalSearch(...args) {
      const result = baseRenderPlanningBacklog(...args);
      applyPlanningSearch();
      return result;
    };
  }

  if (typeof renderNextExecution === 'function') {
    const baseRenderNextExecution = renderNextExecution;
    renderNextExecution = function renderNextExecutionWithOperationalSearch(...args) {
      const result = baseRenderNextExecution(...args);
      applyPerformSearch();
      return result;
    };
  }

  function installOperationalSearchListeners() {
    const input = document.getElementById('setup-task-search');
    if (input && input.dataset.operationalSearchInstalled !== '1') {
      input.dataset.operationalSearchInstalled = '1';
      input.addEventListener('input', () => {
        applyPlanningSearch();
        applyPerformSearch();
      });
    }

    const clear = document.getElementById('setup-task-search-clear');
    if (clear && clear.dataset.operationalSearchInstalled !== '1') {
      clear.dataset.operationalSearchInstalled = '1';
      clear.addEventListener('click', () => {
        requestAnimationFrame(() => {
          applyPlanningSearch();
          applyPerformSearch();
        });
      });
    }
  }

  installOperationalSearchListeners();
  window.addEventListener('load', installOperationalSearchListeners);
})();
