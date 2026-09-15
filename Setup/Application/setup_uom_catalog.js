/* Issue #191 — shared governed Unit-of-Measure selectors and Manager catalog UX. */
(() => {
  'use strict';

  const state = {
    active: [],
    admin: [],
    activeLoaded: false,
    adminLoaded: false,
  };

  const ACTIVE_SELECT_IDS = [
    'expected-uom',
    'extra-material-new-uom',
    'task-extra-material-uom',
    'extra-material-uom',
  ];
  const ADMIN_SELECT_IDS = ['extra-material-catalog-uom'];
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

  async function api(path, options = {}) {
    const response = await fetch(appUrl(path), {
      credentials: 'same-origin',
      headers: { Accept: 'application/json', ...(options.headers || {}) },
      ...options,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(payload.error || `Setup API returned HTTP ${response.status}`);
      error.status = response.status;
      throw error;
    }
    return payload;
  }

  function commandOptions(method, body) {
    return {
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-MSB-Setup-Command': '1',
      },
      body: JSON.stringify(body),
    };
  }

  function replaceInputWithSelect(id) {
    const node = el(id);
    if (!node || node.tagName === 'SELECT') return node;
    if (node.tagName !== 'INPUT') return node;

    const select = document.createElement('select');
    for (const attr of Array.from(node.attributes)) {
      if (attr.name === 'type' || attr.name === 'value') continue;
      select.setAttribute(attr.name, attr.value);
    }
    select.id = id;
    select.dataset.previousValue = node.value || '';
    select.disabled = node.disabled;
    select.required = node.required;
    node.replaceWith(select);
    return select;
  }

  function optionLabel(row) {
    const name = String(row?.display_name || '').trim();
    return name && name.toUpperCase() !== String(row?.uom_code || '').toUpperCase()
      ? `${row.uom_code} — ${name}`
      : String(row?.uom_code || '');
  }

  function renderSelect(id, rows, preferredValue = null) {
    const select = replaceInputWithSelect(id);
    if (!select) return;
    const previous = preferredValue ?? select.value ?? select.dataset.previousValue ?? '';
    const normalizedPrevious = String(previous || '').trim().toUpperCase();

    select.innerHTML = rows.map((row) => {
      const inactive = row.active_flag ? '' : ' · INACTIVE';
      return `<option value="${esc(row.uom_code)}">${esc(optionLabel(row))}${inactive}</option>`;
    }).join('');

    if (normalizedPrevious && rows.some((row) => row.uom_code === normalizedPrevious)) {
      select.value = normalizedPrevious;
    } else if (rows.some((row) => row.uom_code === 'EA')) {
      select.value = 'EA';
    } else if (rows.length) {
      select.value = rows[0].uom_code;
    }
    delete select.dataset.previousValue;
  }

  function renderAllSelectors() {
    if (state.activeLoaded) {
      ACTIVE_SELECT_IDS.forEach((id) => renderSelect(id, state.active));
    }
    if (state.adminLoaded) {
      ADMIN_SELECT_IDS.forEach((id) => renderSelect(id, state.admin));
    } else if (state.activeLoaded) {
      ADMIN_SELECT_IDS.forEach((id) => renderSelect(id, state.active));
    }
  }

  async function loadActive(force = false) {
    if (state.activeLoaded && !force) {
      renderAllSelectors();
      return state.active;
    }
    const payload = await api('api/setup/uoms');
    state.active = payload.uoms || [];
    state.activeLoaded = true;
    renderAllSelectors();
    return state.active;
  }

  async function loadAdmin(force = false) {
    if (state.adminLoaded && !force) {
      renderAllSelectors();
      return state.admin;
    }
    const payload = await api('api/setup/uom-catalog');
    state.admin = payload.uoms || [];
    state.adminLoaded = true;
    renderAllSelectors();
    renderUomCatalog();
    return state.admin;
  }

  function setLocalStatus(message, stateName = 'ok') {
    const target = el('setup-uom-state');
    if (!target) return;
    target.textContent = message;
    target.dataset.state = stateName;
  }

  function injectManager() {
    const host = el('extra-material-catalog-manager');
    if (!host || el('setup-uom-manager')) return;

    const close = el('extra-material-catalog-close');
    if (close && !el('setup-uom-manager-open')) {
      const open = document.createElement('button');
      open.id = 'setup-uom-manager-open';
      open.type = 'button';
      open.className = 'small secondary';
      open.textContent = 'Manage UOMs…';
      close.insertAdjacentElement('beforebegin', open);
    }

    const details = document.createElement('details');
    details.id = 'setup-uom-manager';
    details.className = 'compact-details uom-manager-details';
    details.innerHTML = `
      <summary>Unit of Measure (UOM) Catalog</summary>
      <div class="details-body">
        <div class="hint">UOM codes are stable identities. Use an existing code whenever possible; add a new code only for a genuinely new unit. A UOM that is still used by active Extra Material rows cannot be deactivated.</div>
        <div class="catalog-manager-grid">
          <section class="catalog-manager-block">
            <div class="catalog-manager-heading">
              <h3>Existing UOMs</h3>
              <div class="hint">Edit the display name, notes, order, or active state. The code itself cannot be renamed.</div>
            </div>
            <label>UOM
              <select id="setup-uom-catalog-select"></select>
            </label>
            <div class="catalog-edit-grid">
              <label>Code<input id="setup-uom-code" type="text" readonly></label>
              <label>Display name<input id="setup-uom-name" type="text"></label>
              <label>Optional display order<input id="setup-uom-order" type="number" min="0" value="100"></label>
              <label class="checkbox-label"><input id="setup-uom-active" type="checkbox"> Active UOM</label>
            </div>
            <label>Notes<input id="setup-uom-notes" type="text"></label>
            <div class="action-row"><button id="setup-uom-save" type="button">Save UOM</button></div>
          </section>
          <section class="catalog-manager-block">
            <div class="catalog-manager-heading">
              <h3>Add a new UOM</h3>
              <div class="hint">Use a short canonical code such as EA, FT, SHEET, ROLL, PAIR, or BOX. The code becomes permanent identity.</div>
            </div>
            <form id="setup-uom-new-form">
              <div class="catalog-edit-grid">
                <label>Code<input id="setup-uom-new-code" type="text" maxlength="16" required></label>
                <label>Display name<input id="setup-uom-new-name" type="text" required></label>
              </div>
              <label>Notes<input id="setup-uom-new-notes" type="text"></label>
              <div class="action-row"><button id="setup-uom-new-save" type="submit">Save New UOM</button></div>
            </form>
          </section>
        </div>
        <div id="setup-uom-state" class="catalog-match-list muted" aria-live="polite">UOM changes are governed and validated by the Setup database.</div>
      </div>`;
    host.appendChild(details);

    el('setup-uom-manager-open')?.addEventListener('click', async () => {
      details.open = true;
      try {
        await loadAdmin();
        details.scrollIntoView({ behavior: 'smooth', block: 'start' });
        window.setTimeout(() => el('setup-uom-catalog-select')?.focus({ preventScroll: true }), 180);
      } catch (error) {
        setLocalStatus(error.message || error, 'error');
      }
    });
    el('setup-uom-catalog-select')?.addEventListener('change', syncUomEditor);
    el('setup-uom-save')?.addEventListener('click', saveUom);
    el('setup-uom-new-form')?.addEventListener('submit', createUom);
  }

  function renderUomCatalog(preferredCode = null) {
    const select = el('setup-uom-catalog-select');
    if (!select || !state.adminLoaded) return;
    const previous = preferredCode || select.value;
    select.innerHTML = state.admin.map((row) => {
      const inactive = row.active_flag ? '' : ' · INACTIVE';
      return `<option value="${esc(row.uom_code)}">${esc(optionLabel(row))}${inactive}</option>`;
    }).join('');
    if (previous && state.admin.some((row) => row.uom_code === previous)) select.value = previous;
    syncUomEditor();
  }

  function syncUomEditor() {
    const code = el('setup-uom-catalog-select')?.value || '';
    const row = state.admin.find((item) => item.uom_code === code);
    const save = el('setup-uom-save');
    if (save) save.disabled = !row;
    if (!row) return;
    if (el('setup-uom-code')) el('setup-uom-code').value = row.uom_code;
    if (el('setup-uom-name')) el('setup-uom-name').value = row.display_name || '';
    if (el('setup-uom-order')) el('setup-uom-order').value = String(row.display_order ?? 100);
    if (el('setup-uom-active')) el('setup-uom-active').checked = Boolean(row.active_flag);
    if (el('setup-uom-notes')) el('setup-uom-notes').value = row.notes || '';
  }

  async function saveUom() {
    const code = el('setup-uom-catalog-select')?.value || '';
    const name = el('setup-uom-name')?.value.trim() || '';
    const order = Number(el('setup-uom-order')?.value ?? -1);
    const active = Boolean(el('setup-uom-active')?.checked);
    const notes = el('setup-uom-notes')?.value.trim() || null;
    if (!code || !name || !Number.isInteger(order) || order < 0) {
      setLocalStatus('Choose a UOM, enter its display name, and use a nonnegative display order.', 'error');
      return;
    }
    try {
      await api(`api/setup/uoms/${encodeURIComponent(code)}`, commandOptions('PATCH', {
        display_name: name,
        display_order: order,
        active_flag: active,
        notes,
      }));
      state.activeLoaded = false;
      state.adminLoaded = false;
      await Promise.all([loadActive(true), loadAdmin(true)]);
      renderUomCatalog(code);
      setLocalStatus(`${code} saved. UOM selectors have been refreshed.`);
    } catch (error) {
      setLocalStatus(error.message || error, 'error');
    }
  }

  async function createUom(event) {
    event.preventDefault();
    const code = el('setup-uom-new-code')?.value.trim().toUpperCase() || '';
    const name = el('setup-uom-new-name')?.value.trim() || '';
    const notes = el('setup-uom-new-notes')?.value.trim() || null;
    if (!code || !name) {
      setLocalStatus('UOM code and display name are required.', 'error');
      return;
    }
    try {
      await api('api/setup/uoms', commandOptions('POST', {
        uom_code: code,
        display_name: name,
        notes,
      }));
      el('setup-uom-new-form')?.reset();
      state.activeLoaded = false;
      state.adminLoaded = false;
      await Promise.all([loadActive(true), loadAdmin(true)]);
      renderUomCatalog(code);
      setLocalStatus(`${code} created as a new UOM. It is now available in UOM selectors; choose it explicitly where needed.`);
    } catch (error) {
      setLocalStatus(error.message || error, 'error');
    }
  }

  function installSelectors() {
    renderAllSelectors();
    injectManager();
  }

  async function initialize() {
    injectManager();
    try {
      await loadActive();
    } catch (error) {
      const target = el('inventory-alert') || el('app-alert');
      if (target) {
        target.textContent = `Setup UOM catalog could not be loaded: ${error.message || error}`;
        target.dataset.state = 'error';
      }
    }
    try {
      await loadAdmin();
    } catch (error) {
      if (error.status !== 403) console.warn('Setup UOM admin catalog unavailable', error);
    }
  }

  window.MSBSetupUom = {
    loadActive,
    loadAdmin,
    refresh: async () => {
      state.activeLoaded = false;
      state.adminLoaded = false;
      await loadActive(true);
      try { await loadAdmin(true); } catch (_error) {}
    },
  };

  const observer = new MutationObserver(installSelectors);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
