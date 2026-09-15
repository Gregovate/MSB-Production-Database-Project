/* Issues #184/#189 — compact Kit review + safe reconciliation/edit/inventory/catalog UX. */
(() => {
  const state = {
    kitBoxes: [],
    byId: new Map(),
    filter: 'all',
    inventoryContentId: null,
    inventoryCurrentOnHand: null,
    inventoryUom: 'EA',
    expectedSubmitPending: false,
  };
  const catalogState = {
    canManage: false,
    activeCatalog: [],
    adminCatalog: [],
    adminLoaded: false,
    returnFocusId: 'extra-material-catalog-toggle',
    returnToExpectedDraft: false,
  };
  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/kit-inventory';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }
  const APP_BASE = appBasePath();
  function appUrl(path) { return `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`; }
  function esc(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&#039;');
  }
  function selectedContainerId() {
    const match = window.location.pathname.match(/\/kit-inventory\/(\d+)\/?$/);
    return match ? Number(match[1]) : null;
  }
  function formatNumber(value) {
    if (value == null || value === '') return '—';
    const n = Number(value);
    if (!Number.isFinite(n)) return String(value);
    return Number.isInteger(n) ? String(n) : String(Number(n.toFixed(3)));
  }
  function numberOrNull(value) {
    const text = String(value ?? '').trim();
    if (!text) return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
  }

  async function loadKitBoxes() {
    const response = await fetch(appUrl('api/setup/kit-inventory/kit-boxes'), {
      credentials: 'same-origin', headers: { Accept: 'application/json' },
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Setup API returned HTTP ${response.status}`);
    state.kitBoxes = payload.kit_boxes || [];
    state.byId = new Map(state.kitBoxes.map((row) => [Number(row.container_id), row]));
    applyFilter();
    renderAssignments();
    updateOverview();
  }

  function setFilter(next) {
    state.filter = next;
    ['all', 'assigned', 'unassigned'].forEach((name) => {
      const button = el(`kit-filter-${name}`);
      button?.classList.toggle('active-filter', name === next);
      button?.setAttribute('aria-pressed', name === next ? 'true' : 'false');
    });
    applyFilter();
  }

  function filterMatches(row) {
    const assigned = Number(row?.assigned_task_count || 0) > 0;
    if (state.filter === 'assigned') return assigned;
    if (state.filter === 'unassigned') return !assigned;
    return true;
  }

  function applyFilter() {
    const assigned = state.kitBoxes.filter((row) => Number(row.assigned_task_count || 0) > 0).length;
    const unassigned = state.kitBoxes.length - assigned;
    const summary = el('kit-filter-status');
    if (summary) summary.textContent = `${state.kitBoxes.length} total · ${assigned} assigned · ${unassigned} unassigned`;

    document.querySelectorAll('.kit-row[data-container-id]').forEach((button) => {
      const row = state.byId.get(Number(button.dataset.containerId));
      button.hidden = row ? !filterMatches(row) : false;
    });
  }

  function normalizeRemainderDisplay() {
    const textarea = el('unverified-items');
    if (!textarea || !textarea.value.includes('\\n')) return;
    textarea.value = textarea.value.replace(/\\n/g, '\n');
  }

  function selectedKit() {
    const containerId = selectedContainerId();
    return containerId ? state.byId.get(containerId) : null;
  }

  function updateOverview() {
    const kit = selectedKit();
    const set = (id, value) => { if (el(id)) el(id).textContent = String(value); };
    if (!kit) {
      ['overview-task-count','overview-display-count','overview-expected-count','overview-counted-count','overview-review-state']
        .forEach((id) => set(id, '—'));
      return;
    }
    set('overview-task-count', Number(kit.assigned_task_count || 0));
    set('overview-display-count', Number(kit.display_rows || 0));
    set('overview-expected-count', Number(kit.expected_item_rows || 0));
    set('overview-counted-count', Number(kit.counted_item_rows || 0));
    set('overview-review-state', kit.has_unverified_items ? 'Review' : 'None');
  }

  function renderAssignments() {
    normalizeRemainderDisplay();
    const body = el('kit-task-assignment-body');
    if (!body) return;
    const containerId = selectedContainerId();
    if (!containerId) {
      body.innerHTML = '<tr><td colspan="4" class="empty-state">Select a Kit Box.</td></tr>';
      return;
    }
    const kit = state.byId.get(containerId);
    const tasks = Array.isArray(kit?.assigned_tasks) ? kit.assigned_tasks : [];
    body.innerHTML = tasks.map((task) => {
      const stage = [task.stage_key, task.stage_name].filter(Boolean).join(' · ') || 'Site-wide / unresolved Stage';
      return `<tr>
        <td>${esc(stage)}</td>
        <td>${esc(task.setup_task_id)}</td>
        <td><strong>${esc(task.task_name || '')}</strong></td>
        <td>${esc(task.relationship_notes || '')}</td>
      </tr>`;
    }).join('') || '<tr><td colspan="4" class="empty-state"><strong>Unassigned Kit.</strong> No reusable Setup task → KIT relationship exists yet.</td></tr>';
    updateOverview();
  }

  function configurePermanentNavigation() {
    const back = el('inventory-back-setup');
    if (back) back.href = APP_BASE;
    const tpost = document.querySelector('a[href*="t-post-inventory"]');
    if (tpost) tpost.href = appUrl('t-post-inventory/');
  }

  function focusEditor(sectionId, focusId) {
    const section = el(sectionId);
    if (!section || section.hidden) return;
    window.requestAnimationFrame(() => {
      section.scrollIntoView({ behavior: 'smooth', block: 'start' });
      window.setTimeout(() => el(focusId)?.focus({ preventScroll: true }), 180);
    });
  }

  function closeExpectedPanel() {
    if (el('expected-editor')) el('expected-editor').hidden = true;
    clearEditDecoration();
  }

  function openExpectedPanel(focusId = 'expected-item') {
    const panel = el('expected-editor');
    if (!panel) return;
    panel.hidden = false;
    if (el('inventory-editor')) el('inventory-editor').hidden = true;
    if (el('extra-material-catalog-manager')) el('extra-material-catalog-manager').hidden = true;
    syncExpectedCatalogAction();
    focusEditor('expected-editor', focusId);
  }

  function closeInventoryPanel() {
    if (el('inventory-editor')) el('inventory-editor').hidden = true;
    state.inventoryContentId = null;
    state.inventoryCurrentOnHand = null;
    syncInventoryMath();
  }

  function openInventoryPanel() {
    const panel = el('inventory-editor');
    if (!panel) return;
    panel.hidden = false;
    if (el('expected-editor')) el('expected-editor').hidden = true;
    closeExtraMaterialCatalog(false);
    focusEditor('inventory-editor', 'inventory-delta');
  }

  function clearEditDecoration() {
    document.querySelectorAll('#kit-content-body tr.editing-source-row').forEach((row) => row.classList.remove('editing-source-row'));
    const editor = el('expected-editor');
    editor?.classList.remove('editing');
    const banner = el('expected-editor-status');
    if (banner) {
      banner.hidden = true;
      banner.textContent = '';
    }
    if (el('expected-editor-title')) el('expected-editor-title').textContent = 'Manager — Add Expected Extra Material';
    if (el('expected-clear')) el('expected-clear').textContent = 'Cancel';
    if (el('expected-item') && el('expected-remove')?.hidden) el('expected-item').disabled = false;
    syncExpectedCatalogAction();
  }

  function markExpectedEdit(button) {
    clearEditDecoration();
    const row = button.closest('tr');
    if (!row) return;
    row.classList.add('editing-source-row');
    const itemName = row.cells?.[0]?.textContent?.trim() || 'expected item';
    const editor = el('expected-editor');
    editor?.classList.add('editing');
    const banner = el('expected-editor-status');
    if (banner) {
      banner.hidden = false;
      banner.textContent = `EDITING EXISTING ROW — ${itemName}. Material identity is locked; save field changes or Cancel edit.`;
    }
    if (el('expected-editor-title')) el('expected-editor-title').textContent = 'Manager — Edit Expected Extra Material';
    if (el('expected-clear')) el('expected-clear').textContent = 'Cancel edit';
    if (el('expected-item')) el('expected-item').disabled = true;
    syncExpectedCatalogAction();
  }

  function compactContentRows() {
    document.querySelectorAll('#kit-content-body tr').forEach((row) => {
      const notes = row.cells?.[5];
      if (notes) {
        notes.classList.add('content-notes');
        notes.title = notes.textContent?.trim() || '';
      }
    });
  }

  function physicalFromRow(row) {
    const text = row?.cells?.[4]?.textContent?.trim() || '';
    if (!text || /not counted/i.test(text)) return { current: null, uom: 'EA' };
    const match = text.match(/(-?\d+(?:\.\d+)?)\s*([A-Za-z]+)?/);
    return match
      ? { current: Number(match[1]), uom: match[2] || 'EA' }
      : { current: null, uom: 'EA' };
  }

  function selectedPhysicalFromLabel() {
    const text = el('inventory-selected')?.textContent || '';
    const match = text.match(/On hand:\s*(not counted|-?\d+(?:\.\d+)?)/i);
    if (!match) return;
    state.inventoryCurrentOnHand = /not counted/i.test(match[1]) ? null : Number(match[1]);
  }

  function syncInventoryMath() {
    const target = el('inventory-math');
    const label = el('inventory-quantity-label');
    if (!target || !label) return;
    selectedPhysicalFromLabel();
    if (!state.inventoryContentId) {
      label.textContent = 'Quantity change (+/-)';
      target.textContent = 'Select an expected item to see the physical inventory calculation.';
      target.dataset.state = '';
      return;
    }

    const eventType = el('inventory-type')?.value || 'OTHER';
    const entered = numberOrNull(el('inventory-delta')?.value);
    const current = state.inventoryCurrentOnHand;
    const uom = state.inventoryUom || 'EA';
    label.textContent = eventType === 'INITIAL_COUNT' ? 'Observed initial count' : 'Change to on-hand (+/-)';
    target.dataset.state = '';

    if (eventType === 'INITIAL_COUNT') {
      target.textContent = entered == null
        ? 'No prior physical count. Enter the observed count; that becomes the on-hand balance.'
        : `No prior physical count → ${formatNumber(entered)} ${uom} on hand.`;
      return;
    }
    if (current == null) {
      target.textContent = 'No baseline physical count exists. Record Initial count before an adjustment.';
      target.dataset.state = 'error';
      return;
    }
    if (entered == null) {
      target.textContent = `Current on hand: ${formatNumber(current)} ${uom}. Enter a +/− change to preview the new balance.`;
      return;
    }
    const next = current + entered;
    target.textContent = `${formatNumber(current)} ${uom} + (${formatNumber(entered)} ${uom}) = ${formatNumber(next)} ${uom} on hand.`;
    if (next < 0) target.dataset.state = 'error';
  }

  async function catalogApi(path, options = {}) {
    const response = await fetch(appUrl(path), {
      credentials: 'same-origin',
      headers: { Accept: 'application/json', ...(options.headers || {}) },
      ...options,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(payload.error || `Setup API returned HTTP ${response.status}`);
      error.status = response.status;
      error.payload = payload;
      throw error;
    }
    return payload;
  }

  function catalogCommandOptions(method, body) {
    return {
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-MSB-Setup-Command': '1',
      },
      body: JSON.stringify(body),
    };
  }

  function setInventoryAlert(message, stateName = 'ok') {
    const target = el('inventory-alert');
    if (!target) return;
    target.textContent = message;
    target.dataset.state = stateName;
  }

  function setCatalogBusy(flag) {
    document.body.classList.toggle('busy', Boolean(flag));
  }

  function normalizeCatalogText(value) {
    return String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  }

  function extraMaterialSearchText(row) {
    return normalizeCatalogText([
      row?.material_name,
      row?.lifecycle_class,
      row?.default_uom,
      row?.notes,
      row?.active_flag ? 'active' : 'inactive',
    ].filter(Boolean).join(' '));
  }

  function compareExtraMaterialName(left, right) {
    return String(left?.material_name || '').localeCompare(String(right?.material_name || ''), undefined, {
      sensitivity: 'base', numeric: true,
    });
  }

  function compareExtraMaterialOrder(left, right) {
    return Number(left?.display_order ?? 100) - Number(right?.display_order ?? 100)
      || compareExtraMaterialName(left, right)
      || Number(left?.setup_extra_material_id || 0) - Number(right?.setup_extra_material_id || 0);
  }

  function adminMaterialById(materialId) {
    return catalogState.adminCatalog.find(
      (row) => Number(row.setup_extra_material_id) === Number(materialId)
    ) || null;
  }

  function isEditingExpectedRow() {
    const remove = el('expected-remove');
    return Boolean(remove && !remove.hidden);
  }

  function syncExpectedCatalogAction() {
    const button = el('expected-new-catalog-item');
    if (!button) return;
    const editing = isEditingExpectedRow();
    button.hidden = !catalogState.canManage || editing;
    button.disabled = editing;
  }

  function cancelExpectedWorkflowForCatalog() {
    const panel = el('expected-editor');
    if (panel && !panel.hidden) el('expected-clear')?.click();
    if (panel) panel.hidden = true;
    clearEditDecoration();
    syncExpectedCatalogAction();
  }

  async function loadCatalogAccess() {
    try {
      const payload = await catalogApi('api/setup/access');
      catalogState.canManage = Boolean(payload.access?.can_manage_setup);
    } catch (_error) {
      catalogState.canManage = false;
    }
    syncCatalogAccess();
  }

  function syncCatalogAccess() {
    ['extra-material-catalog-toggle', 'normalize-remainder-item'].forEach((id) => {
      const node = el(id);
      if (node) node.hidden = !catalogState.canManage;
    });
    syncExpectedCatalogAction();
    if (!catalogState.canManage) closeExtraMaterialCatalog(false);
  }

  async function refreshExpectedItemCatalog(preferredId = null) {
    const select = el('expected-item');
    if (!select) return [];
    const previousId = preferredId == null ? Number(select.value || 0) : Number(preferredId || 0);
    const payload = await catalogApi('api/setup/extra-materials');
    catalogState.activeCatalog = payload.extra_materials || [];
    const activeHasPrevious = catalogState.activeCatalog.some(
      (row) => Number(row.setup_extra_material_id) === previousId
    );
    let preservedInactive = null;
    if (previousId && !activeHasPrevious && isEditingExpectedRow()) {
      preservedInactive = adminMaterialById(previousId);
    }

    select.innerHTML = '<option value="">Select material</option>'
      + catalogState.activeCatalog.map((row) => (
        `<option value="${row.setup_extra_material_id}" data-uom="${esc(row.default_uom || 'EA')}">${esc(row.material_name)}</option>`
      )).join('')
      + (preservedInactive
        ? `<option value="${preservedInactive.setup_extra_material_id}" data-uom="${esc(preservedInactive.default_uom || 'EA')}">${esc(preservedInactive.material_name)} · INACTIVE</option>`
        : '');

    if (previousId && (activeHasPrevious || preservedInactive)) select.value = String(previousId);
    if (preferredId && activeHasPrevious && !isEditingExpectedRow()) {
      const created = catalogState.activeCatalog.find(
        (row) => Number(row.setup_extra_material_id) === Number(preferredId)
      );
      if (created && el('expected-uom') && !el('expected-uom').disabled) {
        el('expected-uom').value = created.default_uom || 'EA';
      }
    }
    return catalogState.activeCatalog;
  }

  async function loadAdminExtraMaterialCatalog(force = false) {
    if (!catalogState.canManage) return [];
    if (catalogState.adminLoaded && !force) return catalogState.adminCatalog;
    const payload = await catalogApi('api/setup/extra-material-catalog');
    catalogState.adminCatalog = payload.extra_materials || [];
    catalogState.adminLoaded = true;
    renderExtraMaterialAdminCatalog();
    renderNewExtraMaterialMatches();
    return catalogState.adminCatalog;
  }

  function filteredSortedAdminMaterials() {
    const query = normalizeCatalogText(el('extra-material-catalog-search')?.value || '');
    const sortMode = el('extra-material-catalog-sort')?.value || 'NAME';
    const rows = catalogState.adminCatalog.filter((row) => (
      !query || extraMaterialSearchText(row).includes(query)
    ));
    rows.sort((left, right) => {
      if (sortMode === 'LIFECYCLE') {
        return String(left.lifecycle_class || '').localeCompare(String(right.lifecycle_class || ''), undefined, { sensitivity: 'base' })
          || compareExtraMaterialName(left, right);
      }
      if (sortMode === 'ACTIVE') {
        return Number(Boolean(right.active_flag)) - Number(Boolean(left.active_flag))
          || compareExtraMaterialName(left, right);
      }
      if (sortMode === 'ORDER') return compareExtraMaterialOrder(left, right);
      return compareExtraMaterialName(left, right)
        || Number(left.setup_extra_material_id) - Number(right.setup_extra_material_id);
    });
    return rows;
  }

  function renderExtraMaterialAdminCatalog() {
    const select = el('extra-material-catalog-select');
    if (!select) return;
    const previous = Number(select.value || 0);
    const rows = filteredSortedAdminMaterials();
    select.innerHTML = rows.length
      ? rows.map((row) => {
          const inactive = row.active_flag ? '' : ' · INACTIVE';
          return `<option value="${row.setup_extra_material_id}">${esc(row.material_name)} · ${esc(row.lifecycle_class)} · ${esc(row.default_uom)}${inactive}</option>`;
        }).join('')
      : '<option value="">No matching catalog materials</option>';
    if (previous && rows.some((row) => Number(row.setup_extra_material_id) === previous)) {
      select.value = String(previous);
    }
    const results = el('extra-material-catalog-results');
    if (results) {
      results.textContent = `${rows.length} of ${catalogState.adminCatalog.length} total catalog materials shown, including inactive entries.`;
    }
    syncExtraMaterialCatalogEditor();
  }

  function syncExtraMaterialCatalogEditor() {
    const select = el('extra-material-catalog-select');
    const name = el('extra-material-catalog-name');
    const lifecycle = el('extra-material-catalog-lifecycle');
    const uom = el('extra-material-catalog-uom');
    const order = el('extra-material-catalog-order');
    const active = el('extra-material-catalog-active');
    const notes = el('extra-material-catalog-notes');
    const save = el('extra-material-catalog-save');
    const status = el('extra-material-catalog-state');
    if (!select || !name || !lifecycle || !uom || !order || !active || !notes || !save) return;

    const row = adminMaterialById(Number(select.value || 0));
    save.disabled = !row;
    if (!row) {
      name.value = '';
      lifecycle.value = 'REUSABLE';
      uom.value = 'EA';
      order.value = '100';
      active.checked = false;
      notes.value = '';
      if (status) status.textContent = 'No Extra Material catalog entry is selected.';
      return;
    }

    name.value = row.material_name || '';
    lifecycle.value = row.lifecycle_class || 'REUSABLE';
    uom.value = row.default_uom || 'EA';
    order.value = String(row.display_order ?? 100);
    active.checked = Boolean(row.active_flag);
    notes.value = row.notes || '';
    if (status) {
      status.textContent = `Extra Material #${row.setup_extra_material_id}. Catalog edits preserve this stable identity.${row.active_flag ? '' : ' This entry is currently inactive.'}`;
    }
  }

  function possibleExistingExtraMaterialMatches(name) {
    const query = normalizeCatalogText(name);
    if (query.length < 2) return [];
    const tokens = query.split(' ').filter((token) => token.length >= 2);
    return catalogState.adminCatalog
      .map((row) => {
        const normalizedName = normalizeCatalogText(row.material_name);
        let score = 0;
        if (normalizedName === query) score = 100;
        else if (normalizedName.includes(query) || query.includes(normalizedName)) score = 80;
        else if (tokens.length && tokens.every((token) => normalizedName.includes(token))) score = 60;
        else if (tokens.some((token) => normalizedName.includes(token))) score = 20;
        return { row, score };
      })
      .filter((item) => item.score > 0)
      .sort((left, right) => right.score - left.score
        || Number(Boolean(right.row.active_flag)) - Number(Boolean(left.row.active_flag))
        || compareExtraMaterialName(left.row, right.row))
      .slice(0, 6)
      .map((item) => item.row);
  }

  function renderNewExtraMaterialMatches() {
    const target = el('extra-material-new-matches');
    const input = el('extra-material-new-name');
    if (!target || !input) return;
    const typed = input.value.trim();
    if (typed.length < 2) {
      target.textContent = 'Start typing a name to check the full active/inactive catalog for possible duplicates.';
      return;
    }
    const matches = possibleExistingExtraMaterialMatches(typed);
    if (!matches.length) {
      target.innerHTML = '<strong>No likely existing catalog matches found.</strong> Review the catalog search before creating.';
      return;
    }
    const exact = matches.find((row) => normalizeCatalogText(row.material_name) === normalizeCatalogText(typed));
    const intro = exact
      ? '<strong>An existing material has the same normalized name. Do not create another identity.</strong>'
      : '<strong>Possible existing catalog matches:</strong>';
    target.innerHTML = `${intro}<ul>${matches.map((row) => `
      <li>${esc(row.material_name)} · ${esc(row.lifecycle_class)} · ${esc(row.default_uom)} · #${esc(row.setup_extra_material_id)}${row.active_flag ? '' : ' · INACTIVE'}</li>
    `).join('')}</ul>`;
  }

  function resetNewExtraMaterialForm() {
    el('extra-material-new-form')?.reset();
    if (el('extra-material-new-lifecycle')) el('extra-material-new-lifecycle').value = 'REUSABLE';
    if (el('extra-material-new-uom')) el('extra-material-new-uom').value = 'EA';
    renderNewExtraMaterialMatches();
  }

  async function openExtraMaterialCatalog(mode = 'manage', returnFocusId = 'extra-material-catalog-toggle') {
    if (!catalogState.canManage) return;
    if (mode === 'new' && isEditingExpectedRow()) {
      setInventoryAlert('Material identity on an existing Expected Kit row is locked. Cancel the edit or add a new expected item before creating/selecting another catalog material.', 'error');
      syncExpectedCatalogAction();
      return;
    }
    const panel = el('extra-material-catalog-manager');
    if (!panel) return;
    catalogState.returnFocusId = returnFocusId;
    catalogState.returnToExpectedDraft = mode === 'new';
    if (mode === 'manage') cancelExpectedWorkflowForCatalog();
    else if (el('expected-editor')) el('expected-editor').hidden = true;
    panel.hidden = false;
    closeInventoryPanel();
    try {
      await loadAdminExtraMaterialCatalog();
      if (mode === 'new') {
        resetNewExtraMaterialForm();
        focusEditor('extra-material-catalog-manager', 'extra-material-new-name');
      } else {
        focusEditor('extra-material-catalog-manager', 'extra-material-catalog-search');
      }
    } catch (error) {
      setInventoryAlert(error.message || error, 'error');
    }
  }

  function closeExtraMaterialCatalog(restoreFocus = true) {
    const panel = el('extra-material-catalog-manager');
    if (panel) panel.hidden = true;
    const returnToExpectedDraft = catalogState.returnToExpectedDraft;
    catalogState.returnToExpectedDraft = false;
    if (restoreFocus && returnToExpectedDraft) {
      openExpectedPanel('expected-item');
      return;
    }
    if (restoreFocus && catalogState.returnFocusId) {
      window.setTimeout(() => el(catalogState.returnFocusId)?.focus({ preventScroll: true }), 0);
    }
  }

  async function saveExtraMaterialCatalogEntry() {
    if (!catalogState.canManage) return;
    const materialId = Number(el('extra-material-catalog-select')?.value || 0);
    const name = el('extra-material-catalog-name')?.value.trim() || '';
    const lifecycle = el('extra-material-catalog-lifecycle')?.value || 'REUSABLE';
    const defaultUom = el('extra-material-catalog-uom')?.value.trim() || '';
    const displayOrder = Number(el('extra-material-catalog-order')?.value ?? -1);
    const activeFlag = Boolean(el('extra-material-catalog-active')?.checked);
    const notes = el('extra-material-catalog-notes')?.value.trim() || null;
    if (!materialId || !name || !defaultUom || !Number.isInteger(displayOrder) || displayOrder < 0) {
      setInventoryAlert('Choose a material, enter its name/default UOM, and use a display order of zero or greater.', 'error');
      return;
    }
    const duplicate = catalogState.adminCatalog.find((row) =>
      Number(row.setup_extra_material_id) !== materialId
      && normalizeCatalogText(row.material_name) === normalizeCatalogText(name)
    );
    if (duplicate) {
      setInventoryAlert(`Cannot rename this material to ${name}. Extra Material #${duplicate.setup_extra_material_id} already uses the same normalized name: ${duplicate.material_name}.`, 'error');
      return;
    }

    const expectedSelection = Number(el('expected-item')?.value || 0);
    try {
      setCatalogBusy(true);
      await catalogApi(
        `api/setup/extra-materials/${materialId}`,
        catalogCommandOptions('PATCH', {
          material_name: name,
          lifecycle_class: lifecycle,
          default_uom: defaultUom,
          notes,
          active_flag: activeFlag,
          display_order: displayOrder,
        }),
      );
      catalogState.adminLoaded = false;
      await loadAdminExtraMaterialCatalog(true);
      const adminSelect = el('extra-material-catalog-select');
      if (adminSelect && catalogState.adminCatalog.some((row) => Number(row.setup_extra_material_id) === materialId)) {
        adminSelect.value = String(materialId);
        syncExtraMaterialCatalogEditor();
      }
      await refreshExpectedItemCatalog(expectedSelection || null);
      setInventoryAlert(`${name} catalog entry updated. Existing Kit/task relationships remain attached to Extra Material #${materialId}.`);
    } catch (error) {
      setInventoryAlert(error.message || error, 'error');
    } finally {
      setCatalogBusy(false);
    }
  }

  async function createExtraMaterialCatalogEntry(event) {
    event.preventDefault();
    if (!catalogState.canManage) return;
    const name = el('extra-material-new-name')?.value.trim() || '';
    const lifecycle = el('extra-material-new-lifecycle')?.value || 'REUSABLE';
    const defaultUom = el('extra-material-new-uom')?.value.trim() || '';
    const notes = el('extra-material-new-notes')?.value.trim() || null;
    if (!name || !defaultUom) {
      setInventoryAlert('Material name and default UOM are required.', 'error');
      return;
    }

    const returnToExpectedDraft = catalogState.returnToExpectedDraft;
    try {
      await loadAdminExtraMaterialCatalog();
      const exactExisting = catalogState.adminCatalog.find((row) =>
        normalizeCatalogText(row.material_name) === normalizeCatalogText(name)
      );
      if (exactExisting) {
        if (returnToExpectedDraft && exactExisting.active_flag) {
          await refreshExpectedItemCatalog(exactExisting.setup_extra_material_id);
          resetNewExtraMaterialForm();
          catalogState.returnToExpectedDraft = false;
          closeExtraMaterialCatalog(false);
          openExpectedPanel('expected-qty');
          setInventoryAlert(`${exactExisting.material_name} already exists and is now selected for this new Expected Kit row. Complete quantity/specification/verification/notes, then save.`);
          return;
        }
        const search = el('extra-material-catalog-search');
        if (search) search.value = exactExisting.material_name;
        renderExtraMaterialAdminCatalog();
        const adminSelect = el('extra-material-catalog-select');
        if (adminSelect) {
          adminSelect.value = String(exactExisting.setup_extra_material_id);
          syncExtraMaterialCatalogEditor();
        }
        setInventoryAlert(`${exactExisting.material_name} already exists as Extra Material #${exactExisting.setup_extra_material_id}${exactExisting.active_flag ? '' : ' and is currently inactive'}. Use or correct that catalog identity instead of creating a duplicate.`, 'error');
        el('extra-material-catalog-search')?.focus({ preventScroll: true });
        return;
      }

      setCatalogBusy(true);
      const payload = await catalogApi(
        'api/setup/extra-materials',
        catalogCommandOptions('POST', {
          material_name: name,
          lifecycle_class: lifecycle,
          default_uom: defaultUom,
          notes,
        }),
      );
      const newId = Number(payload.extra_material?.setup_extra_material_id || 0);
      catalogState.adminLoaded = false;
      await loadAdminExtraMaterialCatalog(true);
      if (returnToExpectedDraft) await refreshExpectedItemCatalog(newId || null);
      else await refreshExpectedItemCatalog();
      resetNewExtraMaterialForm();
      if (newId) {
        const adminSelect = el('extra-material-catalog-select');
        if (adminSelect) {
          adminSelect.value = String(newId);
          syncExtraMaterialCatalogEditor();
        }
      }
      if (returnToExpectedDraft) {
        catalogState.returnToExpectedDraft = false;
        closeExtraMaterialCatalog(false);
        openExpectedPanel('expected-qty');
        setInventoryAlert(`Reusable Extra Material ${name} created and selected for this new Expected Kit row. Complete quantity/specification/verification/notes, then save.`);
      } else {
        setInventoryAlert(`Reusable Extra Material ${name} created in the catalog as a new identity. Expected Kit rows were left unchanged.`);
        el('extra-material-catalog-search')?.focus({ preventScroll: true });
      }
    } catch (error) {
      setInventoryAlert(error.message || error, 'error');
    } finally {
      setCatalogBusy(false);
    }
  }

  function bindExtraMaterialCatalogManagement() {
    el('extra-material-catalog-toggle')?.addEventListener('click', () => {
      openExtraMaterialCatalog('manage', 'extra-material-catalog-toggle');
    });
    el('expected-new-catalog-item')?.addEventListener('click', () => {
      if (isEditingExpectedRow()) {
        setInventoryAlert('Material identity on an existing Expected Kit row is locked. Add a new expected item instead.', 'error');
        return;
      }
      openExtraMaterialCatalog('new', 'expected-new-catalog-item');
    });
    el('extra-material-catalog-close')?.addEventListener('click', () => closeExtraMaterialCatalog(true));
    el('extra-material-catalog-search')?.addEventListener('input', renderExtraMaterialAdminCatalog);
    el('extra-material-catalog-sort')?.addEventListener('change', renderExtraMaterialAdminCatalog);
    el('extra-material-catalog-select')?.addEventListener('change', syncExtraMaterialCatalogEditor);
    el('extra-material-catalog-save')?.addEventListener('click', saveExtraMaterialCatalogEntry);
    el('extra-material-new-name')?.addEventListener('input', renderNewExtraMaterialMatches);
    el('extra-material-new-form')?.addEventListener('submit', createExtraMaterialCatalogEntry);
    el('normalize-remainder-item')?.addEventListener('click', () => {
      el('expected-add')?.click();
      queueMicrotask(() => openExtraMaterialCatalog('new', 'expected-new-catalog-item'));
    });
    el('expected-item')?.addEventListener('change', () => {
      if (isEditingExpectedRow()) return;
      const materialId = Number(el('expected-item')?.value || 0);
      const row = catalogState.activeCatalog.find(
        (item) => Number(item.setup_extra_material_id) === materialId
      );
      if (row && el('expected-uom') && !el('expected-uom').disabled) {
        el('expected-uom').value = row.default_uom || 'EA';
      }
    });
    loadCatalogAccess();
    refreshExpectedItemCatalog().catch(() => {});
  }

  function bindRowActionFocus() {
    document.addEventListener('click', (event) => {
      if (event.target.closest('#expected-add')) {
        el('expected-clear')?.click();
        closeExtraMaterialCatalog(false);
        queueMicrotask(() => {
          openExpectedPanel('expected-item');
          syncExpectedCatalogAction();
        });
        return;
      }
      const editButton = event.target.closest('.expected-edit');
      if (editButton) {
        closeExtraMaterialCatalog(false);
        markExpectedEdit(editButton);
        openExpectedPanel('expected-qty');
        return;
      }
      if (event.target.closest('#expected-clear')) {
        queueMicrotask(() => {
          closeExpectedPanel();
          syncExpectedCatalogAction();
        });
        return;
      }
      const inventoryButton = event.target.closest('.inventory-select');
      if (inventoryButton) {
        state.inventoryContentId = Number(inventoryButton.dataset.contentId);
        const physical = physicalFromRow(inventoryButton.closest('tr'));
        state.inventoryCurrentOnHand = physical.current;
        state.inventoryUom = physical.uom;
        queueMicrotask(syncInventoryMath);
        openInventoryPanel();
        return;
      }
      if (event.target.closest('#inventory-close')) {
        closeInventoryPanel();
        return;
      }
      if (event.target.closest('#kit-list .kit-row')) {
        closeExpectedPanel();
        closeInventoryPanel();
        closeExtraMaterialCatalog(false);
      }
    });
  }

  function bindInventoryMath() {
    el('inventory-type')?.addEventListener('change', syncInventoryMath);
    el('inventory-delta')?.addEventListener('input', syncInventoryMath);
    const selected = el('inventory-selected');
    if (selected) new MutationObserver(syncInventoryMath).observe(selected, { childList: true, subtree: true, characterData: true });
  }

  function bind() {
    configurePermanentNavigation();
    bindRowActionFocus();
    bindInventoryMath();
    bindExtraMaterialCatalogManagement();
    el('expected-form')?.addEventListener('submit', () => { state.expectedSubmitPending = true; });
    el('kit-filter-all')?.addEventListener('click', () => setFilter('all'));
    el('kit-filter-assigned')?.addEventListener('click', () => setFilter('assigned'));
    el('kit-filter-unassigned')?.addEventListener('click', () => setFilter('unassigned'));
    el('kit-search')?.addEventListener('input', () => queueMicrotask(applyFilter));
    el('kit-list')?.addEventListener('click', () => queueMicrotask(renderAssignments));
    window.addEventListener('popstate', () => queueMicrotask(() => { renderAssignments(); updateOverview(); }));

    const list = el('kit-list');
    if (list) new MutationObserver(applyFilter).observe(list, { childList: true, subtree: true });
    const title = el('kit-title');
    if (title) new MutationObserver(() => { renderAssignments(); updateOverview(); }).observe(title, { childList: true, subtree: true, characterData: true });
    const contentBody = el('kit-content-body');
    if (contentBody) new MutationObserver(() => {
      compactContentRows();
      if (state.expectedSubmitPending) {
        state.expectedSubmitPending = false;
        closeExpectedPanel();
      } else if (!contentBody.querySelector('.editing-source-row')) {
        clearEditDecoration();
      }
      syncExpectedCatalogAction();
      queueMicrotask(syncInventoryMath);
    }).observe(contentBody, { childList: true, subtree: true });

    loadKitBoxes().catch((error) => {
      const summary = el('kit-filter-status');
      if (summary) summary.textContent = error.message;
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
