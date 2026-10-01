(() => {
  'use strict';

  const seasonSelect = document.getElementById('season-select');
  const searchFilter = document.getElementById('search-filter');
  const stageFilter = document.getElementById('stage-filter');
  const sceneFilter = document.getElementById('scene-filter');
  const statusFilter = document.getElementById('status-filter');
  const sortMode = document.getElementById('sort-mode');
  const summaryNode = document.getElementById('summary');
  const materialList = document.getElementById('material-list');
  const unresolvedList = document.getElementById('unresolved-list');
  const unresolvedPanel = document.getElementById('unresolved-panel');
  const visibleCount = document.getElementById('visible-count');
  const statusLine = document.getElementById('status-line');
  const generatedAt = document.getElementById('generated-at');
  const dialog = document.getElementById('override-dialog');
  const form = document.getElementById('override-form');
  const containerIdInput = document.getElementById('override-container-id');
  const pickByInput = document.getElementById('override-pick-by');
  const neededForInput = document.getElementById('override-needed-for');
  const destinationInput = document.getElementById('override-destination');
  const reasonInput = document.getElementById('override-reason');
  const formMessage = document.getElementById('override-message');
  const formTitle = document.getElementById('override-title');
  const formItem = document.getElementById('override-item');
  const formSubmit = document.getElementById('override-submit');

  let data = null;
  let editingContainerId = null;

  function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
  }

  function commandOptions(method, payload) {
    return {
      method,
      headers: {'Content-Type': 'application/json', 'X-MSB-Setup-Command': '1'},
      body: JSON.stringify(payload)
    };
  }

  function todayIso() {
    const now = new Date();
    return [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, '0'),
      String(now.getDate()).padStart(2, '0')
    ].join('-');
  }

  function noSundayPickDate(value) {
    if (!value) return value;
    const parsed = new Date(`${value}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime())) return value;
    if (parsed.getUTCDay() === 0) {
      parsed.setUTCDate(parsed.getUTCDate() - 1);
      return parsed.toISOString().slice(0, 10);
    }
    return value;
  }

  function statusLabel(value) {
    return ({
      PICKED_MOVED: 'PICKED / MOVED',
      SCHEDULED_TO_PICK: 'SCHEDULED TO PICK',
      UNSCHEDULED_PICKABLE: 'UNSCHEDULED / PICKABLE',
      WORKSHOP: 'WORKSHOP / DO NOT MOBILIZE'
    })[value] || value || 'UNKNOWN';
  }

  function stageText(reason) {
    const stage = [reason?.stage_key, reason?.stage_name].filter(Boolean).join(' — ');
    return [stage, reason?.scene_name].filter(Boolean).join(' / ') || 'Site-wide / no Stage';
  }

  function primaryStage(item) {
    const rows = (item.reasons || []).filter(r => r.stage_key || r.stage_name || r.scene_name);
    rows.sort((a, b) => stageText(a).localeCompare(stageText(b), undefined, {numeric: true}));
    return rows.length ? stageText(rows[0]) : 'No Stage';
  }

  function stageIds(item) {
    return new Set((item.reasons || []).map(r => String(r.stage_id ?? '')).filter(Boolean));
  }

  function scenesFor(item) {
    return new Set((item.reasons || []).map(r => String(r.scene_name || '')).filter(Boolean));
  }

  function currentLocation(item) {
    const observation = item.current_observation || {};
    return [
      observation.current_stage_key,
      observation.current_stage_name,
      observation.current_location_note
    ].filter(Boolean).join(' — ') || 'No Setup observation';
  }

  function effectivePickBy(item) {
    return item.target_staged_by
      || (item.manager_overrides || [])[0]?.pick_by_date
      || '';
  }

  function effectiveNeededFor(item) {
    return item.earliest_needed_for_work
      || (item.manager_overrides || [])[0]?.needed_for_date
      || effectivePickBy(item);
  }

  function managerTimingText(item) {
    const override = (item.manager_overrides || [])[0];
    if (!override) return '';
    const bits = [
      override.pick_by_date ? `Manager Pick By ${override.pick_by_date}` : '',
      override.needed_for_date ? `Needed For ${override.needed_for_date}` : ''
    ].filter(Boolean);
    return bits.join(' · ');
  }

  function searchText(item) {
    return [
      item.identity,
      item.label,
      item.home_location_code,
      item.status,
      item.demand_source,
      effectivePickBy(item),
      effectiveNeededFor(item),
      ...(item.manager_overrides || []).flatMap(override => [
        override.pick_by_date,
        override.needed_for_date,
        override.destination_stage_key,
        override.destination_stage_name,
        override.override_reason,
        override.requested_by_display
      ]),
      ...(item.reasons || []).flatMap(reason => [
        reason.task_name, reason.stage_key, reason.stage_name, reason.scene_name,
        reason.work_date, reason.target_staged_by,
        reason.override_destination,
        reason.reason_label, reason.reason_detail,
        ...(reason.display_names || []),
        ...(reason.display_ids || [])
      ])
    ].filter(Boolean).join(' ').toLowerCase();
  }

  function filteredItems() {
    if (!data) return [];
    const query = searchFilter.value.trim().toLowerCase();
    const stage = stageFilter.value;
    const scene = sceneFilter.value;
    const status = statusFilter.value;
    if (status === 'UNRESOLVED') return [];

    const rows = (data.items || []).filter(item => {
      if (query && !searchText(item).includes(query)) return false;
      if (stage && !stageIds(item).has(stage)) return false;
      if (scene && !scenesFor(item).has(scene)) return false;
      if (status && item.status !== status) return false;
      return true;
    });

    const mode = sortMode.value;
    rows.sort((a, b) => {
      if (mode === 'STATUS') {
        return statusLabel(a.status).localeCompare(statusLabel(b.status))
          || primaryStage(a).localeCompare(primaryStage(b), undefined, {numeric: true});
      }
      if (mode === 'PICK_BY') {
        return String(effectivePickBy(a) || '9999-12-31').localeCompare(String(effectivePickBy(b) || '9999-12-31'))
          || String(effectiveNeededFor(a) || '9999-12-31').localeCompare(String(effectiveNeededFor(b) || '9999-12-31'))
          || String(a.home_location_code || 'ZZZ').localeCompare(String(b.home_location_code || 'ZZZ'), undefined, {numeric: true});
      }
      if (mode === 'NEEDED_FOR') {
        return String(effectiveNeededFor(a) || '9999-12-31').localeCompare(String(effectiveNeededFor(b) || '9999-12-31'))
          || String(effectivePickBy(a) || '9999-12-31').localeCompare(String(effectivePickBy(b) || '9999-12-31'))
          || String(a.home_location_code || 'ZZZ').localeCompare(String(b.home_location_code || 'ZZZ'), undefined, {numeric: true});
      }
      if (mode === 'HOME') {
        return String(a.home_location_code || 'ZZZ').localeCompare(String(b.home_location_code || 'ZZZ'), undefined, {numeric: true})
          || String(a.identity).localeCompare(String(b.identity), undefined, {numeric: true});
      }
      if (mode === 'IDENTITY') {
        return String(a.identity).localeCompare(String(b.identity), undefined, {numeric: true});
      }
      return primaryStage(a).localeCompare(primaryStage(b), undefined, {numeric: true})
        || String(a.identity).localeCompare(String(b.identity), undefined, {numeric: true});
    });
    return rows;
  }

  function unresolvedSearchText(row) {
    return [
      row.task_name, row.stage_key, row.stage_name, row.scene_name,
      row.requirement_type, row.message, row.extra_material_name
    ].filter(Boolean).join(' ').toLowerCase();
  }

  function filteredUnresolved() {
    if (!data) return [];
    const query = searchFilter.value.trim().toLowerCase();
    const stage = stageFilter.value;
    const scene = sceneFilter.value;
    const status = statusFilter.value;
    if (status && status !== 'UNRESOLVED') return [];
    return (data.unresolved_requirements || []).filter(row => {
      if (query && !unresolvedSearchText(row).includes(query)) return false;
      if (stage && String(row.stage_id ?? '') !== stage) return false;
      if (scene && String(row.scene_name || '') !== scene) return false;
      return true;
    });
  }

  function renderSummary() {
    const s = data?.summary || {};
    summaryNode.innerHTML = [
      ['Picked / moved', s.picked_moved || 0],
      ['Scheduled to pick', s.scheduled_to_pick || 0],
      ['Unscheduled / pickable', s.unscheduled_pickable || 0],
      ['Workshop', s.workshop || 0],
      ['Unresolved', s.unresolved || 0]
    ].map(([label, value]) => `<div class="summary-card"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`).join('');
  }

  function renderContents(item) {
    const displayNames = [...new Set(
      (item.reasons || []).flatMap(reason => reason.display_names || [])
        .map(value => String(value || '').trim())
        .filter(Boolean)
    )].sort((a, b) => a.localeCompare(b, undefined, {numeric: true}));

    const extraMaterialNames = [...new Set(
      (item.reasons || [])
        .map(reason => String(reason.extra_material_name || '').trim())
        .filter(Boolean)
    )].sort((a, b) => a.localeCompare(b, undefined, {numeric: true}));

    const parts = [];
    if (displayNames.length) {
      const shown = displayNames.slice(0, 4);
      parts.push(`<div><strong>${esc(displayNames.length)} Display${displayNames.length === 1 ? '' : 's'}</strong></div>`);
      parts.push(`<div>${shown.map(esc).join(', ')}${displayNames.length > shown.length ? ` +${displayNames.length - shown.length} more` : ''}</div>`);
    }
    if (extraMaterialNames.length) {
      const shown = extraMaterialNames.slice(0, 4);
      parts.push(`<div><strong>Extra material</strong></div>`);
      parts.push(`<div>${shown.map(esc).join(', ')}${extraMaterialNames.length > shown.length ? ` +${extraMaterialNames.length - shown.length} more` : ''}</div>`);
    }

    if (!parts.length) {
      if (item.physical_type === 'DISPLAY') {
        return `<div><strong>Display</strong></div><div>${esc(item.label || item.identity)}</div>`;
      }
      return '<div class="muted">No Display contents recorded.</div>';
    }
    return parts.join('');
  }

  function actionHtml(item) {
    const buttons = [];
    if (item.can_add_to_pick_list) {
      buttons.push(`<button type="button" class="add-pick" data-id="${esc(item.physical_id)}">Add to Pick List</button>`);
    }
    if (item.can_edit_pick_list_override) {
      buttons.push(`<button type="button" class="edit-pick secondary" data-id="${esc(item.physical_id)}">Edit Dates / Override</button>`);
    }
    if (item.can_remove_from_pick_list) {
      buttons.push(`<button type="button" class="remove-pick secondary" data-id="${esc(item.physical_id)}">Remove from Pick List</button>`);
    } else if (item.can_remove_manager_override) {
      buttons.push(`<button type="button" class="remove-pick secondary" data-id="${esc(item.physical_id)}">Remove Override</button>`);
    }
    return buttons.join('');
  }

  function renderItems() {
    const rows = filteredItems();
    visibleCount.textContent = `${rows.length} material item${rows.length === 1 ? '' : 's'} shown`;
    materialList.innerHTML = rows.length ? rows.map(item => `
      <article class="material-row">
        <div class="material-identity">
          <div class="identity">${esc(item.identity)}</div>
          <div class="label">${esc(item.label || '')}</div>
          <div class="home">${esc(item.home_location_code || 'Home not recorded')}</div>
        </div>
        <div class="material-status">
          <div class="status-${esc(item.status)}">${esc(statusLabel(item.status))}</div>
          <div class="badges">
            <span class="badge">${esc(item.demand_source === 'NONE' ? 'NOT ON PICK LIST' : item.demand_source)}</span>
            ${item.workshop_do_not_mobilize && item.status === 'PICKED_MOVED' ? '<span class="badge">WORKSHOP POLICY</span>' : ''}
          </div>
        </div>
        <div class="material-stage"><strong>${esc(primaryStage(item))}</strong></div>
        <div class="material-timing">
          <strong>Pick By</strong><div>${esc(effectivePickBy(item) || 'Not on Pick List')}</div>
          <strong>Needed For</strong><div>${esc(effectiveNeededFor(item) || 'Not scheduled')}</div>
          ${managerTimingText(item) ? `<div class="muted">${esc(managerTimingText(item))}</div>` : ''}
        </div>
        <div class="material-home">
          <strong>Current</strong><div>${esc(currentLocation(item))}</div>
        </div>
        <div class="material-contents">
          <strong class="contents-heading">Contents</strong>
          ${renderContents(item)}
        </div>
        <div class="actions">${actionHtml(item)}</div>
      </article>
    `).join('') : '<div class="empty">No material matches the selected filters.</div>';

    materialList.querySelectorAll('.add-pick').forEach(button => {
      button.addEventListener('click', () => openOverride(Number(button.dataset.id), false));
    });
    materialList.querySelectorAll('.edit-pick').forEach(button => {
      button.addEventListener('click', () => openOverride(Number(button.dataset.id), true));
    });
    materialList.querySelectorAll('.remove-pick').forEach(button => {
      button.addEventListener('click', () => void removeOverride(Number(button.dataset.id)));
    });
  }

  function renderUnresolved() {
    const rows = filteredUnresolved();
    unresolvedPanel.hidden = Boolean(statusFilter.value && statusFilter.value !== 'UNRESOLVED');
    unresolvedList.innerHTML = rows.length ? rows.map(row => `
      <div class="unresolved-row">
        <strong>${esc(row.task_name || row.extra_material_name || row.requirement_type || 'Unresolved material')}</strong>
        <div>${esc([row.stage_key, row.stage_name, row.scene_name].filter(Boolean).join(' — ') || 'No Stage')}</div>
        <div>${esc(row.message || 'Material authority requires review.')}</div>
      </div>
    `).join('') : '<div class="empty">No unresolved material matches the selected filters.</div>';
  }

  function render() {
    renderSummary();
    renderItems();
    renderUnresolved();
  }

  function populateFilters() {
    const stages = data?.stages || [];
    const currentStage = stageFilter.value;
    stageFilter.innerHTML = '<option value="">All Stages</option>' + stages.map(stage =>
      `<option value="${esc(stage.stage_id)}">${esc(stage.stage_key || '')} — ${esc(stage.stage_name || 'Unnamed Stage')}</option>`
    ).join('');
    if ([...stageFilter.options].some(option => option.value === currentStage)) stageFilter.value = currentStage;
    populateScenes();
  }

  function populateScenes() {
    const current = sceneFilter.value;
    const selectedStage = stageFilter.value;
    const scenes = new Set();
    for (const item of data?.items || []) {
      for (const reason of item.reasons || []) {
        if (selectedStage && String(reason.stage_id ?? '') !== selectedStage) continue;
        if (reason.scene_name) scenes.add(String(reason.scene_name));
      }
    }
    for (const row of data?.unresolved_requirements || []) {
      if (selectedStage && String(row.stage_id ?? '') !== selectedStage) continue;
      if (row.scene_name) scenes.add(String(row.scene_name));
    }
    sceneFilter.innerHTML = '<option value="">All Scenes</option>' +
      [...scenes].sort((a, b) => a.localeCompare(b, undefined, {numeric: true}))
        .map(scene => `<option value="${esc(scene)}">${esc(scene)}</option>`).join('');
    if ([...sceneFilter.options].some(option => option.value === current)) sceneFilter.value = current;
  }

  function stageOptions() {
    return (data?.stages || []).map(stage =>
      `<option value="${esc(stage.stage_id)}">${esc(stage.stage_key || '')} — ${esc(stage.stage_name || 'Unnamed Stage')}</option>`
    ).join('');
  }

  function openOverride(containerId, editing) {
    const item = (data?.items || []).find(row =>
      row.physical_type === 'CONTAINER' && Number(row.physical_id) === Number(containerId)
    );
    if (!item) return;
    if (editing && !item.can_edit_pick_list_override) return;
    if (!editing && !item.can_add_to_pick_list) return;

    editingContainerId = editing ? containerId : null;
    containerIdInput.value = String(containerId);
    formTitle.textContent = editing ? 'Edit Pick List override' : 'Add to Pick List';
    formSubmit.textContent = editing ? 'Update Pick List' : 'Add to Pick List';
    formItem.textContent = `${item.identity} · ${item.label || ''}`;
    formMessage.textContent = '';
    destinationInput.innerHTML = '<option value="">Select destination Stage</option>' + stageOptions();

    const override = editing ? (item.manager_overrides || [])[0] : null;
    pickByInput.value = override?.pick_by_date || noSundayPickDate(todayIso());
    neededForInput.value = override?.needed_for_date || '';
    reasonInput.value = override?.override_reason || '';

    const reasonStages = [...new Set((item.reasons || []).map(reason => Number(reason.stage_id)).filter(Number.isFinite))];
    const destination = override?.destination_stage_id ?? (reasonStages.length === 1 ? reasonStages[0] : null);
    destinationInput.value = destination == null ? '' : String(destination);
    dialog.showModal();
  }

  async function submitOverride(event) {
    event.preventDefault();
    const containerId = Number(containerIdInput.value);
    if (!containerId) return;

    const normalized = noSundayPickDate(pickByInput.value);
    if (normalized !== pickByInput.value) {
      pickByInput.value = normalized;
      formMessage.textContent = 'Sunday is not a pick day. Pick By moved to Saturday.';
    }
    if (!pickByInput.value || !destinationInput.value || !reasonInput.value.trim()) {
      formMessage.textContent = 'Pick By, Destination, and Reason are required.';
      return;
    }
    if (neededForInput.value && neededForInput.value < pickByInput.value) {
      formMessage.textContent = 'Needed For cannot be before Pick By.';
      return;
    }

    formSubmit.disabled = true;
    try {
      const response = await fetch('../api/setup/material-readiness/overrides', commandOptions('POST', {
        season_year: Number(seasonSelect.value),
        container_id: containerId,
        pick_by_date: pickByInput.value,
        needed_for_date: neededForInput.value || null,
        destination_stage_id: Number(destinationInput.value),
        override_reason: reasonInput.value.trim()
      }));
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || `HTTP ${response.status}`);
      dialog.close();
      editingContainerId = null;
      await load();
    } catch (error) {
      formMessage.textContent = error.message || error;
    } finally {
      formSubmit.disabled = false;
    }
  }

  async function removeOverride(containerId) {
    const item = (data?.items || []).find(row =>
      row.physical_type === 'CONTAINER' && Number(row.physical_id) === Number(containerId)
    );
    if (!item?.can_remove_from_pick_list && !item?.can_remove_manager_override) return;
    const scheduleRemains = Boolean(item.can_remove_manager_override);
    const prompt = scheduleRemains
      ? `Remove only the Manager override for ${item.identity}? Schedule-derived Pick List demand will remain. The schedule never replaces or edits the Manager override automatically.`
      : `Remove ${item.identity} from the Pick List by cancelling its Manager override? Movement truth is never removed here.`;
    if (!window.confirm(prompt)) return;
    try {
      const response = await fetch(
        `../api/setup/material-readiness/overrides/${encodeURIComponent(containerId)}`,
        commandOptions('DELETE', {season_year: Number(seasonSelect.value)})
      );
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || `HTTP ${response.status}`);
      await load();
    } catch (error) {
      window.alert(error.message || error);
    }
  }

  async function load() {
    const year = seasonSelect.value;
    statusLine.textContent = 'Loading annual material status…';
    const response = await fetch(`../api/setup/material-status?season_year=${encodeURIComponent(year)}`, {cache: 'no-store'});
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || `HTTP ${response.status}`);
    data = payload.material_status;
    populateFilters();
    render();
    statusLine.textContent = data.session
      ? `Live ${data.session.season_year} annual material oversight. Movement truth overrides planning state.`
      : `No Setup Session exists for ${year}.`;
    generatedAt.textContent = `Generated ${new Date().toLocaleString()}`;
  }

  function showError(error) {
    statusLine.textContent = `Material Status unavailable: ${error.message || error}`;
    materialList.innerHTML = '';
    unresolvedList.innerHTML = '';
  }

  const params = new URLSearchParams(location.search);
  const requestedSeason = /^\d{4}$/.test(params.get('season_year') || '') ? params.get('season_year') : '2026';
  for (const year of ['2025', '2026']) {
    const option = document.createElement('option');
    option.value = year;
    option.textContent = year;
    option.selected = year === requestedSeason;
    seasonSelect.appendChild(option);
  }

  seasonSelect.addEventListener('change', () => {
    const url = new URL(location.href);
    url.searchParams.set('season_year', seasonSelect.value);
    history.replaceState({}, '', url);
    load().catch(showError);
  });
  stageFilter.addEventListener('change', () => { populateScenes(); render(); });
  sceneFilter.addEventListener('change', render);
  statusFilter.addEventListener('change', render);
  sortMode.addEventListener('change', render);
  searchFilter.addEventListener('input', render);
  form.addEventListener('submit', event => { void submitOverride(event); });
  document.getElementById('override-cancel').addEventListener('click', () => {
    editingContainerId = null;
    dialog.close();
  });
  document.getElementById('back-button').addEventListener('click', () => {
    location.href = `../?season_year=${encodeURIComponent(seasonSelect.value)}`;
  });

  load().catch(showError);
})();
