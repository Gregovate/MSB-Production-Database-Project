/* Issue #198 — bootstrap an existing Container into durable T-Post inventory. */
(() => {
  'use strict';

  const state = {
    access: null,
    containers: [],
    existingTpostContainerIds: new Set(),
    tpostMaterialId: null,
  };

  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/t-post-inventory';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }

  const APP_BASE = appBasePath();
  function appUrl(path) { return `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`; }

  function numberOrNull(value) {
    const text = String(value ?? '').trim();
    if (!text) return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
  }

  async function api(path, options = {}) {
    const response = await fetch(appUrl(path), {
      credentials: 'same-origin',
      headers: { Accept: 'application/json', ...(options.headers || {}) },
      ...options,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Setup API returned HTTP ${response.status}`);
    return payload;
  }

  function commandOptions(method, body) {
    return {
      method,
      headers: { 'Content-Type': 'application/json', 'X-MSB-Setup-Command': '1' },
      body: JSON.stringify(body),
    };
  }

  function containerTypeLabel(row) {
    if (!row) return 'Container';
    if (row.display_pallet) return 'Display Pallet';
    if (Number(row.container_type_id) === 2) return 'Kit Box';
    return row.container_type_id != null ? `Container Type ${row.container_type_id}` : 'Container';
  }

  function containerLabel(row) {
    const type = containerTypeLabel(row);
    const home = row.home_location_code ? ` · Home ${row.home_location_code}` : '';
    return `C${row.container_id} — ${row.container_description || 'No description'} · ${type}${home}`;
  }

  function renderOptions() {
    const select = el('tpost-bootstrap-container');
    if (!select) return;
    const query = String(el('tpost-bootstrap-search')?.value || '').trim().toLocaleLowerCase();
    const rows = state.containers.filter((row) => {
      if (state.existingTpostContainerIds.has(Number(row.container_id))) return false;
      if (!query) return true;
      return [row.container_id, row.container_description, containerTypeLabel(row), row.home_location_code]
        .filter((value) => value != null)
        .join(' ')
        .toLocaleLowerCase()
        .includes(query);
    });
    select.innerHTML = rows.map((row) => (
      `<option value="${row.container_id}">${containerLabel(row)}</option>`
    )).join('');
  }

  async function saveBootstrap(event) {
    event.preventDefault();
    if (!state.access?.can_manage_setup || !state.tpostMaterialId) return;
    const containerId = Number(el('tpost-bootstrap-container')?.value || 0);
    if (!containerId) {
      window.alert('Choose an existing Container first.');
      return;
    }
    const lengthValue = numberOrNull(el('tpost-bootstrap-length')?.value);
    const lengthUnit = el('tpost-bootstrap-length-unit')?.value || null;
    const sizeText = el('tpost-bootstrap-size')?.value.trim() || null;
    if (lengthValue != null && !lengthUnit) {
      window.alert('Choose a length unit when a T-Post length is entered.');
      return;
    }
    try {
      await api(
        `api/setup/containers/${containerId}/extra-materials`,
        commandOptions('POST', {
          setup_extra_material_id: Number(state.tpostMaterialId),
          expected_quantity: null,
          quantity_uom: 'EA',
          size_text: sizeText,
          length_value: lengthValue,
          length_unit: lengthUnit,
          color: null,
          verification_state: el('tpost-bootstrap-verification')?.value || 'UNVERIFIED',
          notes: el('tpost-bootstrap-notes')?.value.trim() || null,
          active_flag: true,
        }),
      );
      window.location.reload();
    } catch (error) {
      window.alert(error.message || error);
    }
  }

  async function start() {
    const panel = el('tpost-bootstrap-panel');
    if (!panel) return;
    try {
      const [accessPayload, catalogPayload, containerPayload, tpostContainersPayload] = await Promise.all([
        api('api/setup/access'),
        api('api/setup/extra-materials'),
        api('api/setup/containers/source-options'),
        api('api/setup/t-post-inventory/containers'),
      ]);
      state.access = accessPayload.access || {};
      if (!state.access.can_manage_setup) {
        panel.hidden = true;
        return;
      }
      const tpost = (catalogPayload.extra_materials || []).find((row) => row.material_name === 'T-Post');
      state.tpostMaterialId = tpost?.setup_extra_material_id || null;
      state.containers = containerPayload.containers || [];
      state.existingTpostContainerIds = new Set(
        (tpostContainersPayload.containers || []).map((row) => Number(row.container_id)),
      );
      panel.hidden = false;
      renderOptions();
      el('tpost-bootstrap-search')?.addEventListener('input', renderOptions);
      el('tpost-bootstrap-form')?.addEventListener('submit', saveBootstrap);
    } catch (error) {
      panel.hidden = true;
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
