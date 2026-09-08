/* Real Production review corrections discovered during 2025 Manager use. */

(() => {
  function normalizedSearch() {
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
    const query = normalizedSearch();
    return !query || taskSearchText(task).includes(query);
  }

  function installSearch() {
    if (document.getElementById('setup-task-search')) return;
    const summary = document.getElementById('summary-grid');
    if (!summary) return;

    const search = document.createElement('section');
    search.className = 'setup-live-search';
    search.setAttribute('aria-label', 'Find Setup tasks');
    search.innerHTML = `
      <label>Find task or Stage
        <input id="setup-task-search" type="search"
               placeholder="Example: Street Lights, Mega Tree, Stage 02"
               autocomplete="off" spellcheck="false">
      </label>
      <div class="search-help">Searches task name, Stage, Scene, type, and prerequisites.</div>
      <button id="setup-task-search-clear" type="button" class="secondary">Clear</button>
    `;
    summary.insertAdjacentElement('beforebegin', search);

    document.getElementById('setup-task-search').addEventListener('input', () => {
      renderReviewList();
      renderLibrary();
    });
    document.getElementById('setup-task-search-clear').addEventListener('click', () => {
      const input = document.getElementById('setup-task-search');
      input.value = '';
      renderReviewList();
      renderLibrary();
      input.focus();
    });
  }

  function applyReviewSearch() {
    const target = document.getElementById('review-list');
    if (!target) return;
    const query = normalizedSearch();
    const rows = [...target.querySelectorAll('.task-row')];
    let visible = 0;

    rows.forEach((row) => {
      const task = taskById(Number(row.dataset.taskId));
      const show = !query || taskMatchesSearch(task);
      row.hidden = !show;
      if (show) visible += 1;
    });

    target.querySelector('.setup-live-search-empty')?.remove();
    if (query && rows.length && visible === 0) {
      const empty = document.createElement('div');
      empty.className = 'setup-live-search-empty';
      empty.textContent = 'No Setup tasks match this search.';
      target.appendChild(empty);
    }
  }

  function applyLibrarySearch() {
    const target = document.getElementById('library-list');
    if (!target) return;
    const query = normalizedSearch();

    const rows = [...target.querySelectorAll('[data-task-id].next-task-row, .library-task')];
    rows.forEach((row) => {
      const taskId = Number(row.dataset.taskId || row.querySelector('.open-task')?.dataset.taskId || 0);
      const task = taskById(taskId);
      row.hidden = Boolean(query) && !taskMatchesSearch(task);
    });

    target.querySelectorAll('.next-scope-group').forEach((scope) => {
      if (!query) {
        scope.hidden = false;
        return;
      }
      const summaryText = String(scope.querySelector(':scope > summary')?.textContent || '').toLocaleLowerCase();
      const hasVisibleTask = [...scope.querySelectorAll(':scope .next-task-row')].some((row) => !row.hidden);
      scope.hidden = !hasVisibleTask && !summaryText.includes(query);
    });

    target.querySelectorAll('.next-stage-group').forEach((stage) => {
      if (!query) {
        stage.hidden = false;
        return;
      }
      const summaryText = String(stage.querySelector(':scope > summary')?.textContent || '').toLocaleLowerCase();
      const hasVisibleTask = [...stage.querySelectorAll('.next-task-row')].some((row) => !row.hidden);
      stage.hidden = !hasVisibleTask && !summaryText.includes(query);
    });

    target.querySelectorAll('.library-stage:not(.next-stage-group)').forEach((stage) => {
      if (!query) {
        stage.hidden = false;
        return;
      }
      const heading = String(stage.querySelector('.library-stage-heading')?.textContent || '').toLocaleLowerCase();
      const hasVisibleTask = [...stage.querySelectorAll('.library-task')].some((row) => !row.hidden);
      stage.hidden = !hasVisibleTask && !heading.includes(query);
    });
  }

  /* The Equipment / Resources section is inserted dynamically. During live
     Manager review the resource list rendered correctly while its manager
     editor remained hidden even for an Administrator. Re-apply the capability
     after access and resource rendering so the existing governed Create and
     Add / Update controls cannot be stranded by script/render timing. */
  function syncAuthorizedResourceEditor() {
    if (typeof ensureSetupResourceSection === 'function') ensureSetupResourceSection();
    const manager = document.getElementById('setup-resource-manager');
    if (!manager) return;
    const canManage = Boolean(appState?.access?.can_manage_setup);
    manager.hidden = !canManage;
    manager.querySelectorAll('select, input, button').forEach((control) => {
      control.disabled = !canManage;
    });
  }

  const priorRenderReviewList = renderReviewList;
  renderReviewList = function renderReviewListWithLiveSearch() {
    priorRenderReviewList();
    applyReviewSearch();
  };

  const priorRenderLibrary = renderLibrary;
  renderLibrary = function renderLibraryWithLiveSearch() {
    priorRenderLibrary();
    applyLibrarySearch();
  };

  if (typeof applyAccess === 'function') {
    const priorApplyAccess = applyAccess;
    applyAccess = function applyAccessWithLiveFixes(...args) {
      const result = priorApplyAccess(...args);
      syncAuthorizedResourceEditor();
      return result;
    };
  }

  if (typeof renderSetupTaskResources === 'function') {
    const priorRenderSetupTaskResources = renderSetupTaskResources;
    renderSetupTaskResources = function renderSetupTaskResourcesWithManagerAccess(...args) {
      const result = priorRenderSetupTaskResources(...args);
      syncAuthorizedResourceEditor();
      return result;
    };
  }

  installSearch();
  syncAuthorizedResourceEditor();
  if (appState.tasks?.length) {
    renderReviewList();
    renderLibrary();
  }
})();
