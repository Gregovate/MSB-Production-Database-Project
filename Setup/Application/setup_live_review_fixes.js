/* Real Production review corrections discovered during 2025 Manager use. */

(() => {
  /*
   * Setup must not equate every ref.lor_scene row with a real scheduling Scene.
   * Keep this classification aligned with the established Folder Alignment
   * contract:
   *
   *   NN-Name-XY   -> STAGE_ROOT
   *   NNa-Name-XY  -> SUB_STAGE_ROOT
   *   NN-Name       -> SCENE
   *   NNa-Name      -> SCENE
   *   Root          -> ROOT
   *   unprefixed    -> DISPLAY_OR_GROUP
   *
   * Live acceptance examples:
   *   true Scenes: 01-Front Gate, 02-Mega Tree, 02-Fred's Stars
   *   display/group rows: Abominable, CharlieInTheBox, Frosty, Headlights,
   *   Narwhal, Signage, US Flag, Volunteer Path Lights
   */
  const setupScenePrefix = /^\s*(\d{2}[A-Za-z]?)-(.+?)\s*$/;
  const setupRootSuffix = /-[A-Za-z]{2}\s*$/;

  function classifySetupLORSceneName(value) {
    const name = String(value || '').trim();
    if (!name) return 'DISPLAY_OR_GROUP';
    if (name.toLocaleLowerCase() === 'root') return 'ROOT';

    const match = name.match(setupScenePrefix);
    if (!match) return 'DISPLAY_OR_GROUP';

    if (setupRootSuffix.test(name)) {
      return match[1].length === 3 ? 'SUB_STAGE_ROOT' : 'STAGE_ROOT';
    }
    return 'SCENE';
  }

  function setupSceneToken(value) {
    const match = String(value || '').trim().match(setupScenePrefix);
    return match ? match[1].toLocaleLowerCase() : '';
  }

  function setupStageForId(stageId) {
    return (appState.stages || []).find((stage) => Number(stage.stage_id) === Number(stageId));
  }

  function isTrueSetupScene(scene) {
    if (!scene || classifySetupLORSceneName(scene.scene_name) !== 'SCENE') return false;
    const stage = setupStageForId(scene.stage_id);
    if (!stage) return false;
    return setupSceneToken(scene.scene_name) === String(stage.stage_key || '').trim().toLocaleLowerCase();
  }

  function normalizeSetupScope(scope) {
    if (!scope?.lor_scene_id || isTrueSetupScene(scope)) return scope;
    return {
      ...scope,
      source_lor_scene_id: scope.lor_scene_id,
      source_scene_name: scope.scene_name || null,
      scope_warning: 'NON_SCENE_LOR_GROUP_PRESENTED_AT_STAGE',
      lor_scene_id: null,
      scene_name: null
    };
  }

  function normalizeTaskScopeForDisplay(task) {
    if (!task?.lor_scene_id || isTrueSetupScene(task)) return task;
    return {
      ...task,
      lor_scene_id: null,
      scene_name: null
    };
  }

  function normalizeCurrentSetupOrganization() {
    if (typeof setupNextState === 'undefined') return;
    setupNextState.scenes = (setupNextState.scenes || []).filter(isTrueSetupScene);
    setupNextState.taskScopes = new Map(
      [...(setupNextState.taskScopes || new Map()).entries()].map(([taskId, scope]) => [
        taskId,
        normalizeSetupScope(scope)
      ])
    );
    if (typeof applyNextTaskScopes === 'function') applyNextTaskScopes();
  }

  if (typeof loadNextOrganization === 'function') {
    const priorLoadNextOrganization = loadNextOrganization;
    loadNextOrganization = async function loadNextOrganizationWithTrueScenes(render = true) {
      const result = await priorLoadNextOrganization(false);
      normalizeCurrentSetupOrganization();
      if (render && appState.tasks?.length) renderLibrary();
      return result;
    };
  }

  if (typeof nextTaskLabel === 'function') {
    const priorNextTaskLabel = nextTaskLabel;
    nextTaskLabel = function nextTaskLabelWithTrueSceneScope(task) {
      return priorNextTaskLabel(normalizeTaskScopeForDisplay(task));
    };
  }

  if (typeof nextTaskScopeLabel === 'function') {
    const priorNextTaskScopeLabel = nextTaskScopeLabel;
    nextTaskScopeLabel = function nextTaskScopeLabelWithTrueSceneScope(task) {
      return priorNextTaskScopeLabel(normalizeTaskScopeForDisplay(task));
    };
  }

  function ensureTaskSectionPurpose(container, text, anchor = null) {
    if (!container || container.querySelector(':scope > .task-section-purpose')) return;
    const purpose = document.createElement('div');
    purpose.className = 'task-section-purpose';
    purpose.textContent = text;
    if (anchor) anchor.insertAdjacentElement('afterend', purpose);
    else container.prepend(purpose);
  }

  function ensureSectionEyebrow(container, text) {
    if (!container || container.querySelector(':scope > .eyebrow')) return;
    const eyebrow = document.createElement('div');
    eyebrow.className = 'eyebrow';
    eyebrow.textContent = text;
    container.prepend(eyebrow);
  }

  function installTaskDetailHierarchy() {
    const reusableFieldset = document.getElementById('reusable-fieldset');
    const annualFieldset = document.getElementById('annual-fieldset');
    const definitionSection = reusableFieldset?.closest('.detail-section');
    if (definitionSection) {
      definitionSection.classList.add('task-detail-panel', 'task-detail-definition');
      reusableFieldset.classList.add('task-detail-subpanel');
      annualFieldset?.classList.add('task-detail-subpanel');

      const reusableLegend = reusableFieldset.querySelector('legend');
      if (reusableLegend) reusableLegend.textContent = '1. Reusable Task Definition';
      ensureTaskSectionPurpose(
        reusableFieldset,
        'Permanent Setup knowledge used year after year. Change this when the normal task itself changes.',
        reusableLegend
      );

      const annualLegend = annualFieldset?.querySelector('legend');
      ensureTaskSectionPurpose(
        annualFieldset,
        '2025-only historical facts and notes. These annual actuals do not redefine the reusable task.',
        annualLegend
      );
    }

    const prerequisiteSection = document.getElementById('detail-dependencies')?.closest('.detail-section');
    if (prerequisiteSection) {
      prerequisiteSection.classList.add('task-detail-panel', 'task-detail-prerequisites');
      const heading = prerequisiteSection.querySelector(':scope > h3');
      if (heading) heading.textContent = '2. Prerequisites';
      ensureTaskSectionPurpose(
        prerequisiteSection,
        'What must be complete before this task can start. Use prerequisites to teach the work sequence and prevent crews from starting too early.',
        heading
      );
    }

    const resourceSection = document.getElementById('setup-resource-section');
    if (resourceSection) {
      resourceSection.classList.add('task-detail-panel', 'task-detail-resources');
      const heading = resourceSection.querySelector('.resource-section-header h3');
      if (heading) heading.textContent = '3. Equipment / Resources';
      const headerNote = resourceSection.querySelector('.resource-section-header > .muted');
      if (headerNote) headerNote.textContent = 'Current task requirements are listed first.';
      const resourceHeader = resourceSection.querySelector('.resource-section-header');
      ensureTaskSectionPurpose(
        resourceSection,
        'Tools, equipment, vehicles, trailers, and other reusable resources needed to perform this task. Quantity is how many this task needs.',
        resourceHeader
      );

      const existingHeading = resourceSection.querySelector('.resource-existing-block .resource-manager-heading');
      ensureSectionEyebrow(existingHeading, 'Task requirement');
      const existingTitle = existingHeading?.querySelector('h4');
      if (existingTitle) existingTitle.textContent = 'Add or update a resource requirement for this task';

      const catalogBlock = resourceSection.querySelector('.resource-create-block');
      catalogBlock?.classList.add('task-resource-catalog-block');
      const catalogHeading = catalogBlock?.querySelector('.resource-manager-heading');
      ensureSectionEyebrow(catalogHeading, 'Resource catalog');
      const catalogTitle = catalogHeading?.querySelector('h4');
      if (catalogTitle) catalogTitle.textContent = 'Create New Catalog Resource';
      const catalogHint = catalogHeading?.querySelector('.hint');
      if (catalogHint) {
        catalogHint.textContent = 'Use this only when the reusable resource does not already exist. Create it once; it can then be assigned to any task.';
      }
    }

    const procedureSection = document.getElementById('production-current-pdf')?.closest('.detail-section');
    if (procedureSection) {
      procedureSection.classList.add('task-detail-panel', 'task-detail-procedures');
      const heading = procedureSection.querySelector(':scope > h3');
      if (heading) heading.textContent = '4. Setup Procedures';
      ensureTaskSectionPurpose(
        procedureSection,
        'Published field instructions and the editable source used to perform and maintain this task.',
        heading
      );
    }
  }

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

  const priorRenderReviewList = renderReviewList;
  renderReviewList = function renderReviewListWithLiveSearch() {
    priorRenderReviewList();
    applyReviewSearch();
  };

  const priorRenderLibrary = renderLibrary;
  renderLibrary = function renderLibraryWithLiveSearch() {
    normalizeCurrentSetupOrganization();
    priorRenderLibrary();
    applyLibrarySearch();
  };

  normalizeCurrentSetupOrganization();
  installTaskDetailHierarchy();
  installSearch();
  if (appState.tasks?.length) {
    renderReviewList();
    renderLibrary();
  }
})();
