/* Setup training/live-use UX corrections discovered during 2025 reconstruction. */

(() => {
  const returnState = {
    fromLibrary: false,
    taskId: null,
    scrollY: 0
  };
  const materialState = {
    requestToken: 0
  };

  function navigationHost() {
    return document.querySelector('#review-detail .detail-heading');
  }

  function ensureLibraryReturnControl() {
    const host = navigationHost();
    if (!host || document.getElementById('setup-return-library-wrap')) return;

    const wrap = document.createElement('div');
    wrap.id = 'setup-return-library-wrap';
    wrap.className = 'setup-return-library-wrap';
    wrap.hidden = true;
    wrap.innerHTML = `
      <button id="setup-return-library" type="button" class="secondary">← Back to Reusable Task Catalog</button>
      <span class="muted">Return to the same reusable task and Catalog position.</span>
    `;
    host.insertAdjacentElement('beforebegin', wrap);

    document.getElementById('setup-return-library').addEventListener('click', () => {
      const taskId = returnState.taskId;
      if (typeof renderLibrary === 'function') renderLibrary();
      showView('library');

      requestAnimationFrame(() => {
        const row = taskId == null
          ? null
          : document.querySelector(`#library-view [data-task-id="${taskId}"]`);
        if (row) {
          row.scrollIntoView({ block: 'center', behavior: 'auto' });
          row.classList.add('setup-return-highlight');
          window.setTimeout(() => row.classList.remove('setup-return-highlight'), 1600);
        } else {
          window.scrollTo({ top: returnState.scrollY, behavior: 'auto' });
        }
      });

      returnState.fromLibrary = false;
      updateLibraryReturnControl();
    });
  }

  function updateLibraryReturnControl() {
    ensureLibraryReturnControl();
    const wrap = document.getElementById('setup-return-library-wrap');
    if (wrap) wrap.hidden = !returnState.fromLibrary;
  }

  function rememberLibraryOrigin(taskId) {
    returnState.fromLibrary = true;
    returnState.taskId = Number(taskId);
    returnState.scrollY = window.scrollY;
  }

  function clearLibraryOrigin() {
    returnState.fromLibrary = false;
    returnState.taskId = null;
    updateLibraryReturnControl();
  }

  function ensureMaterialSection() {
    const procedureSection = document.getElementById('production-current-pdf')?.closest('.detail-section');
    if (!procedureSection) return null;

    let section = document.getElementById('setup-material-context-section');
    if (!section) {
      section = document.createElement('section');
      section.id = 'setup-material-context-section';
      section.className = 'detail-section task-detail-panel task-detail-material';
      section.innerHTML = `
        <h3>4. Material / Logistics Context</h3>
        <div class="task-section-purpose">
          Database-resolved physical context for this reusable task. Use this to verify that Setup knows what is needed and where it currently belongs; do not copy these IDs into the Procedure just to preserve tribal knowledge.
        </div>
        <div id="setup-material-context-summary" class="setup-material-summary"></div>
        <div id="setup-material-context-body" class="setup-material-body">
          <span class="muted">Select a task to resolve current material context.</span>
        </div>
      `;
      procedureSection.insertAdjacentElement('beforebegin', section);
    }

    const procedureHeading = procedureSection.querySelector(':scope > h3');
    if (procedureHeading) procedureHeading.textContent = '5. Setup Procedures';
    return section;
  }

  function contextLocation(row) {
    if (row.current_location_note) return row.current_location_note;
    if (row.current_stage_key || row.current_stage_name) {
      return `Stage ${row.current_stage_key || '—'} — ${row.current_stage_name || ''}`.trim();
    }
    if (row.home_location_code) return `Home ${row.home_location_code}`;
    return 'Location not resolved';
  }

  function whyIncluded(row) {
    if (row.relationship_source === 'SCENE') return 'Current LOR Scene membership';
    if (row.relationship_source === 'TASK_MAP') return 'Explicit reusable-task Display mapping';
    if (row.relationship_type) return String(row.relationship_type).replaceAll('_', ' ');
    return 'Database relationship';
  }

  function renderMaterialContext(context) {
    ensureMaterialSection();
    const summary = document.getElementById('setup-material-context-summary');
    const body = document.getElementById('setup-material-context-body');
    if (!summary || !body) return;

    const displays = Array.isArray(context?.displays) ? context.displays : [];
    const supportContainers = Array.isArray(context?.support_containers) ? context.support_containers : [];
    const containerIds = new Set();
    displays.forEach((row) => {
      if (row.container_id != null) containerIds.add(Number(row.container_id));
    });
    supportContainers.forEach((row) => {
      if (row.container_id != null) containerIds.add(Number(row.container_id));
    });
    const unresolvedDisplays = displays.filter((row) => row.container_id == null);

    summary.innerHTML = `
      <div><span>Displays resolved</span><strong>${displays.length}</strong></div>
      <div><span>Containers resolved</span><strong>${containerIds.size}</strong></div>
      <div><span>Support / KIT Containers</span><strong>${supportContainers.length}</strong></div>
      <div><span>Displays without Container</span><strong>${unresolvedDisplays.length}</strong></div>
    `;

    const groups = new Map();
    displays.forEach((row) => {
      const key = row.container_id == null ? 'UNCONTAINED' : String(row.container_id);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(row);
    });

    const displayGroups = [...groups.entries()].map(([key, rows]) => {
      const first = rows[0] || {};
      const title = key === 'UNCONTAINED'
        ? 'Displays without a current Container relationship'
        : `Container ${escapeHtml(key)}${first.container_description ? ` — ${escapeHtml(first.container_description)}` : ''}`;
      const location = contextLocation(first);
      return `
        <details class="setup-material-container" open>
          <summary>
            <span><strong>${title}</strong></span>
            <span class="setup-material-count">${rows.length} Display${rows.length === 1 ? '' : 's'}</span>
          </summary>
          <div class="setup-material-location">Current / home context: ${escapeHtml(location)}</div>
          <div class="setup-material-display-list">
            ${rows.map((row) => `
              <div class="setup-material-display-row">
                <div><strong>Display ${escapeHtml(row.display_id)} — ${escapeHtml(row.display_name || '')}</strong></div>
                <div class="muted">Why included: ${escapeHtml(whyIncluded(row))}${row.relationship_notes ? ` · ${escapeHtml(row.relationship_notes)}` : ''}</div>
              </div>
            `).join('')}
          </div>
        </details>
      `;
    }).join('');

    const supportMarkup = supportContainers.length ? `
      <div class="setup-support-container-block">
        <h4>Supplemental support / KIT Containers</h4>
        ${supportContainers.map((row) => `
          <div class="setup-support-container-row">
            <strong>Container ${escapeHtml(row.container_id)}${row.container_description ? ` — ${escapeHtml(row.container_description)}` : ''}</strong>
            <div class="muted">${escapeHtml(String(row.relationship_type || 'SUPPORT').replaceAll('_', ' '))}${row.relationship_notes ? ` · ${escapeHtml(row.relationship_notes)}` : ''}</div>
            <div class="muted">Current / home context: ${escapeHtml(contextLocation(row))}</div>
          </div>
        `).join('')}
      </div>
    ` : '';

    const emptyMarkup = !displays.length && !supportContainers.length
      ? '<div class="empty-state">No Display or supplemental Container relationship is currently resolved for this reusable task. That is a visible knowledge gap, not permission to copy IDs from the Procedure.</div>'
      : '';

    body.innerHTML = `
      ${emptyMarkup}
      ${displayGroups}
      ${supportMarkup}
      <div class="setup-controller-context-note">
        <strong>Controllers:</strong> Catalog controller context is not surfaced by this resolver yet. It must come from the existing authoritative FieldWiring/controller relationships rather than from hard-coded Procedure text.
      </div>
    `;
  }

  async function loadMaterialContext(taskId) {
    const section = ensureMaterialSection();
    if (!section || taskId == null || appState.seasonYear == null) return;

    const token = ++materialState.requestToken;
    const summary = document.getElementById('setup-material-context-summary');
    const body = document.getElementById('setup-material-context-body');
    if (summary) summary.innerHTML = '';
    if (body) body.innerHTML = '<span class="muted">Resolving Displays, Containers, and support Containers from the Production Database…</span>';

    try {
      const payload = await api(
        `api/setup/tasks/${Number(taskId)}/field-context?season_year=${encodeURIComponent(appState.seasonYear)}`
      );
      if (token !== materialState.requestToken) return;
      renderMaterialContext(payload.context || {});
    } catch (error) {
      if (token !== materialState.requestToken) return;
      if (body) {
        body.innerHTML = `<div class="empty-state">Material / logistics context could not be resolved: ${escapeHtml(error.message || error)}</div>`;
      }
    }
  }

  function historicalReconstructionSelected() {
    const season = typeof currentSeasonRecord === 'function' ? currentSeasonRecord() : null;
    return season?.session_status === 'HISTORICAL_VERIFICATION';
  }

  function ensureReconstructionDeleteControl() {
    const actions = document.getElementById('reusable-manager-actions');
    if (!actions || document.getElementById('delete-reconstruction-task')) return;

    const button = document.createElement('button');
    button.id = 'delete-reconstruction-task';
    button.type = 'button';
    button.className = 'danger';
    button.textContent = 'Delete Reconstruction Task';
    button.hidden = true;
    actions.appendChild(button);
    button.addEventListener('click', deleteSelectedReconstructionTask);
  }

  function updateReconstructionDeleteControl(taskId = appState.selectedTaskId) {
    ensureReconstructionDeleteControl();
    const button = document.getElementById('delete-reconstruction-task');
    if (!button) return;
    const task = taskById(taskId);
    button.hidden = !(
      appState.access?.can_manage_setup
      && historicalReconstructionSelected()
      && task?.setup_session_task_id != null
    );
  }

  async function deleteSelectedReconstructionTask() {
    const task = taskById(appState.selectedTaskId);
    if (!task || !appState.access?.can_manage_setup || !historicalReconstructionSelected()) return;

    const confirmed = window.confirm(
      `Delete "${task.task_name}" completely from the ${appState.seasonYear} reconstruction and the Reusable Task Catalog?\n\n`
      + 'This is intended for reconstruction mistakes only. The database will refuse the delete if the task has work-day, progress, movement, planning, or actual execution history.\n\n'
      + 'This cannot be undone.'
    );
    if (!confirmed) return;

    const returnToLibrary = returnState.fromLibrary;
    try {
      setBusy(true);
      const result = await api(
        `api/setup/tasks/${task.setup_task_id}/reconstruction-delete`,
        commandOptions('DELETE', {})
      );
      const deleted = result.deleted_task || {};
      materialState.requestToken += 1;
      appState.selectedTaskId = null;
      clearLibraryOrigin();
      await reloadTasks(null);
      if (typeof loadNextOrganization === 'function') await loadNextOrganization(false);
      if (typeof loadNextSchedule === 'function') await loadNextSchedule();

      const detail = document.getElementById('review-detail');
      const empty = document.getElementById('review-empty');
      if (detail) detail.hidden = true;
      if (empty) empty.hidden = false;

      if (returnToLibrary) {
        renderLibrary();
        showView('library');
      } else {
        showView('review');
      }

      setAlert(
        `Deleted reconstruction task ${deleted.setup_task_id || task.setup_task_id}. `
        + `${deleted.deleted_annual_rows ?? 0} annual row(s) and its reusable definition were removed.`,
        'ok'
      );
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
      updateReconstructionDeleteControl();
    }
  }

  /*
   * Capture Catalog Open before the existing bubble handler switches views.
   * This preserves the user's Catalog context without changing the existing
   * task-selection or save behavior.
   */
  document.addEventListener('click', (event) => {
    const catalogOpen = event.target.closest('#library-view .open-task');
    if (catalogOpen) {
      rememberLibraryOrigin(catalogOpen.dataset.taskId);
      requestAnimationFrame(updateLibraryReturnControl);
      return;
    }

    if (event.target.closest('#review-list .task-row')) {
      clearLibraryOrigin();
      return;
    }

    const tab = event.target.closest('.tabs .tab');
    if (tab && tab.dataset.view !== 'library') {
      clearLibraryOrigin();
    }
  }, true);

  /* Keep contextual controls visible across saves/reloads of the open task. */
  if (typeof selectTask === 'function') {
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithTrainingContext(taskId) {
      const result = priorSelectTask(taskId);
      requestAnimationFrame(updateLibraryReturnControl);
      updateReconstructionDeleteControl(taskId);
      loadMaterialContext(taskId);
      return result;
    };
  }

  ensureLibraryReturnControl();
  ensureMaterialSection();
  ensureReconstructionDeleteControl();
})();
