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
  const captainState = {
    requestToken: 0,
    people: null
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

  function ensureCaptainSection() {
    const fieldset = document.getElementById('reusable-fieldset');
    const actions = document.getElementById('reusable-manager-actions');
    if (!fieldset || !actions) return null;

    let section = document.getElementById('setup-captain-section');
    if (!section) {
      section = document.createElement('div');
      section.id = 'setup-captain-section';
      section.className = 'setup-captain-section';
      section.innerHTML = `
        <div class="setup-captain-heading">
          <div>
            <h4>Task Captains / Knowledge Owners</h4>
            <div class="muted">Reusable leadership knowledge: who can lead this task, who is the backup, and who can advise. 2025 crew names do not assign Captains automatically.</div>
          </div>
        </div>
        <div id="setup-captain-list" class="setup-captain-list">
          <span class="muted">Select a task to resolve Captain assignments.</span>
        </div>
        <div id="setup-captain-manager" class="setup-captain-manager" hidden>
          <div class="setup-captain-picker-grid">
            <label>Find person
              <input id="setup-captain-search" type="search" placeholder="Type a name or email" autocomplete="off">
            </label>
            <label>Person from MSB directory
              <select id="setup-captain-person" size="5" aria-label="Captain person"></select>
            </label>
          </div>
          <div class="compact-grid three">
            <label>Role
              <select id="setup-captain-role">
                <option value="CAPTAIN">Captain</option>
                <option value="ALTERNATE">Alternate</option>
                <option value="ADVISOR">Advisor</option>
              </select>
            </label>
            <label>Sort order<input id="setup-captain-sort" type="number" min="0" value="100"></label>
            <div></div>
          </div>
          <label>Knowledge / role note<textarea id="setup-captain-notes" rows="2" placeholder="What this person knows or when they should be called"></textarea></label>
          <div class="action-row">
            <button id="setup-captain-save" type="button">Add / Update Captain</button>
            <button id="setup-captain-clear" type="button" class="secondary">Clear Selection</button>
          </div>
        </div>
      `;
      actions.insertAdjacentElement('beforebegin', section);

      document.getElementById('setup-captain-search').addEventListener('input', renderCaptainPeople);
      document.getElementById('setup-captain-save').addEventListener('click', saveCaptainAssignment);
      document.getElementById('setup-captain-clear').addEventListener('click', clearCaptainEditor);
    }

    const manager = document.getElementById('setup-captain-manager');
    if (manager) manager.hidden = !appState.access?.can_manage_setup;
    return section;
  }

  function captainPersonLabel(person) {
    const name = String(person?.display_name || `Person ${person?.person_id ?? ''}`).trim();
    const email = String(person?.email || '').trim();
    return email && !name.toLocaleLowerCase().includes(email.toLocaleLowerCase())
      ? `${name} — ${email}`
      : name;
  }

  function renderCaptainPeople() {
    ensureCaptainSection();
    const select = document.getElementById('setup-captain-person');
    const search = document.getElementById('setup-captain-search');
    if (!select) return;
    const previous = select.value;
    const query = String(search?.value || '').trim().toLocaleLowerCase();
    const people = Array.isArray(captainState.people) ? captainState.people : [];
    const visible = people.filter((person) => {
      if (!query) return true;
      return [person.display_name, person.email, person.person_id]
        .filter((value) => value != null)
        .join(' ')
        .toLocaleLowerCase()
        .includes(query);
    });
    select.innerHTML = visible.map((person) => (
      `<option value="${person.person_id}">${escapeHtml(captainPersonLabel(person))}</option>`
    )).join('');
    if (previous && visible.some((person) => String(person.person_id) === String(previous))) {
      select.value = previous;
    }
  }

  function clearCaptainEditor() {
    const search = document.getElementById('setup-captain-search');
    const person = document.getElementById('setup-captain-person');
    const role = document.getElementById('setup-captain-role');
    const sort = document.getElementById('setup-captain-sort');
    const notes = document.getElementById('setup-captain-notes');
    if (search) search.value = '';
    renderCaptainPeople();
    if (person) person.selectedIndex = -1;
    if (role) role.value = 'CAPTAIN';
    if (sort) sort.value = '100';
    if (notes) notes.value = '';
  }

  function editCaptainAssignment(captain) {
    if (!appState.access?.can_manage_setup) return;
    const search = document.getElementById('setup-captain-search');
    const person = document.getElementById('setup-captain-person');
    const role = document.getElementById('setup-captain-role');
    const sort = document.getElementById('setup-captain-sort');
    const notes = document.getElementById('setup-captain-notes');
    if (search) search.value = '';
    renderCaptainPeople();
    if (person) person.value = String(captain.person_id);
    if (role) role.value = captain.captain_role || 'CAPTAIN';
    if (sort) sort.value = captain.sort_order ?? 100;
    if (notes) notes.value = captain.notes || '';
    document.getElementById('setup-captain-manager')?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }

  function renderCaptainAssignments(captains) {
    ensureCaptainSection();
    const list = document.getElementById('setup-captain-list');
    if (!list) return;
    const rows = Array.isArray(captains) ? captains : [];
    if (!rows.length) {
      list.innerHTML = '<div class="setup-captain-gap"><strong>No Captain / Alternate / Advisor assigned.</strong><div class="muted">This is a visible knowledge-ownership gap. Do not infer a Captain from 2025 crew notes.</div></div>';
      return;
    }

    list.innerHTML = rows.map((captain, index) => `
      <div class="setup-captain-row" data-captain-index="${index}">
        <div>
          <strong>${escapeHtml(captain.display_name || `Person ${captain.person_id}`)}</strong>
          <span class="setup-captain-role">${escapeHtml(String(captain.captain_role || 'CAPTAIN').replaceAll('_', ' '))}</span>
          ${captain.email ? `<div class="muted">${escapeHtml(captain.email)}</div>` : ''}
          ${captain.notes ? `<div class="setup-captain-note">${escapeHtml(captain.notes)}</div>` : ''}
        </div>
        ${appState.access?.can_manage_setup ? `
          <div class="setup-captain-actions">
            <button type="button" class="small secondary setup-captain-edit">Edit</button>
            <button type="button" class="small danger setup-captain-remove">Remove</button>
          </div>
        ` : ''}
      </div>
    `).join('');

    list.querySelectorAll('.setup-captain-row').forEach((row) => {
      const captain = rows[Number(row.dataset.captainIndex)];
      row.querySelector('.setup-captain-edit')?.addEventListener('click', () => editCaptainAssignment(captain));
      row.querySelector('.setup-captain-remove')?.addEventListener('click', () => removeCaptainAssignment(captain));
    });
  }

  async function loadCaptainPeople() {
    if (!appState.access?.can_manage_setup) return;
    if (Array.isArray(captainState.people)) {
      renderCaptainPeople();
      return;
    }
    const payload = await api('api/setup/captain-people');
    captainState.people = payload.people || [];
    renderCaptainPeople();
  }

  async function loadCaptainContext(taskId) {
    const section = ensureCaptainSection();
    if (!section || taskId == null) return;
    const token = ++captainState.requestToken;
    const list = document.getElementById('setup-captain-list');
    if (list) list.innerHTML = '<span class="muted">Resolving reusable Captain / knowledge-owner assignments…</span>';

    try {
      const payload = await api(`api/setup/tasks/${Number(taskId)}/captains`);
      if (token !== captainState.requestToken) return;
      renderCaptainAssignments(payload.captains || []);
      if (appState.access?.can_manage_setup) {
        try {
          await loadCaptainPeople();
        } catch (error) {
          const manager = document.getElementById('setup-captain-manager');
          if (manager) {
            manager.insertAdjacentHTML(
              'afterbegin',
              `<div class="setup-captain-load-error">Person directory could not be loaded: ${escapeHtml(error.message || error)}</div>`
            );
          }
        }
      }
    } catch (error) {
      if (token !== captainState.requestToken) return;
      if (list) list.innerHTML = `<div class="empty-state">Captain assignments could not be resolved: ${escapeHtml(error.message || error)}</div>`;
    }
  }

  async function saveCaptainAssignment() {
    const task = taskById(appState.selectedTaskId);
    const personSelect = document.getElementById('setup-captain-person');
    const personId = Number(personSelect?.value || 0);
    if (!task || !appState.access?.can_manage_setup || !personId) {
      window.alert('Select a person from the MSB directory first.');
      return;
    }
    const role = document.getElementById('setup-captain-role')?.value || 'CAPTAIN';
    const sort = Number(document.getElementById('setup-captain-sort')?.value || 100);
    const notes = document.getElementById('setup-captain-notes')?.value.trim() || null;

    try {
      setBusy(true);
      await api(
        `api/setup/tasks/${task.setup_task_id}/captains/${personId}`,
        commandOptions('PATCH', {
          captain_role: role,
          sort_order: Number.isFinite(sort) ? sort : 100,
          notes,
          active: true
        })
      );
      clearCaptainEditor();
      await loadCaptainContext(task.setup_task_id);
      setAlert('Reusable task Captain / knowledge-owner assignment saved.', 'ok');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
  }

  async function removeCaptainAssignment(captain) {
    const task = taskById(appState.selectedTaskId);
    if (!task || !appState.access?.can_manage_setup) return;
    if (!window.confirm(`Remove ${captain.display_name} as ${String(captain.captain_role || 'Captain').toLocaleLowerCase()} for this reusable task?`)) return;

    try {
      setBusy(true);
      await api(
        `api/setup/tasks/${task.setup_task_id}/captains/${captain.person_id}`,
        commandOptions('PATCH', {
          captain_role: captain.captain_role || 'CAPTAIN',
          sort_order: captain.sort_order ?? 100,
          notes: captain.notes || null,
          active: false
        })
      );
      await loadCaptainContext(task.setup_task_id);
      setAlert('Reusable task Captain / knowledge-owner assignment removed.', 'ok');
    } catch (error) {
      setAlert(error.message || error, 'error');
      window.alert(error.message || error);
    } finally {
      setBusy(false);
    }
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
      captainState.requestToken += 1;
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
      loadCaptainContext(taskId);
      loadMaterialContext(taskId);
      return result;
    };
  }

  ensureLibraryReturnControl();
  ensureCaptainSection();
  ensureMaterialSection();
  ensureReconstructionDeleteControl();
})();
