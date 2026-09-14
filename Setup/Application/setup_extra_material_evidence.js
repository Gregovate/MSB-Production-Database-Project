/* Issue #167 — query normalized findings before final assignment. */
(() => {
  const state = { access: null, sources: [] };
  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/extra-material-evidence';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }
  const APP_BASE = appBasePath();
  function appUrl(path) { return `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`; }
  function esc(value) { return String(value ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#039;'); }
  function arr(value) { return Array.isArray(value) ? value : []; }

  async function api(path) {
    const response = await fetch(appUrl(path), { credentials:'same-origin', headers:{Accept:'application/json'} });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Setup API returned HTTP ${response.status}`);
    return payload;
  }

  function setAlert(message, stateName='ok') {
    const target = el('evidence-alert');
    target.textContent = message;
    target.dataset.state = stateName;
  }

  function configureTheme() {
    try {
      const saved = localStorage.getItem('msb-theme');
      if (saved === 'light' || saved === 'dark') document.documentElement.dataset.theme = saved;
    } catch (_error) {}
    syncTheme();
    el('theme-toggle')?.addEventListener('click', () => {
      const current = document.documentElement.dataset.theme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      document.documentElement.dataset.theme = current === 'dark' ? 'light' : 'dark';
      try { localStorage.setItem('msb-theme', document.documentElement.dataset.theme); } catch (_error) {}
      syncTheme();
    });
  }
  function syncTheme() {
    const current = document.documentElement.dataset.theme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    el('theme-toggle').textContent = current === 'dark' ? 'Light mode' : 'Dark mode';
  }

  function populateFilters() {
    const stages = [...new Set(state.sources.map((row) => row.stage_key).filter(Boolean))].sort((a,b) => String(a).localeCompare(String(b), undefined, {numeric:true}));
    el('filter-stage').innerHTML = '<option value="">All stages</option>' + stages.map((value) => `<option>${esc(value)}</option>`).join('');
    const materials = [...new Set(state.sources.flatMap((row) => arr(row.material_families)))].sort((a,b) => a.localeCompare(b));
    el('filter-material').innerHTML = '<option value="">All materials</option>' + materials.map((value) => `<option>${esc(value)}</option>`).join('');
  }

  function textHaystack(row) {
    return [row.stage_key,row.source_file,row.family_page_index,...arr(row.material_families),...arr(row.material_keys),...arr(row.source_mapping_statuses),...arr(row.task_mapping_statuses),...arr(row.requirement_preload_states),...arr(row.catalog_dispositions),...arr(row.legacy_container_refs),...arr(row.current_id_refs),...arr(row.noncurrent_or_legacy_refs)].filter(Boolean).join(' ').toLocaleLowerCase();
  }

  function matches(row) {
    const search = el('filter-search').value.trim().toLocaleLowerCase();
    const stage = el('filter-stage').value;
    const material = el('filter-material').value;
    const verification = el('filter-verification').value;
    const container = Number(el('filter-container').value || 0);
    if (search && !textHaystack(row).includes(search)) return false;
    if (stage && row.stage_key !== stage) return false;
    if (material && !arr(row.material_families).includes(material)) return false;
    if (verification === 'yes' && !row.verification_needed) return false;
    if (verification === 'no' && row.verification_needed) return false;
    if (container) {
      const candidates = [...arr(row.proposed_current_source_container_ids), ...arr(row.current_stage_kit_candidate_ids)];
      const legacyText = [...arr(row.legacy_container_refs), ...arr(row.current_id_refs), ...arr(row.noncurrent_or_legacy_refs)].join(' ');
      if (!candidates.map(Number).includes(container) && !new RegExp(`(^|\\D)${container}(\\D|$)`).test(legacyText)) return false;
    }
    return true;
  }

  function pills(values, className='') {
    return arr(values).map((value) => `<span class="pill ${className}">${esc(value)}</span>`).join('');
  }

  function containerEvidence(row) {
    const sections = [];
    if (arr(row.proposed_current_source_container_ids).length) sections.push(`<div><strong>Proposed source:</strong> ${pills(row.proposed_current_source_container_ids)}</div>`);
    if (arr(row.current_stage_kit_candidate_ids).length) sections.push(`<div><strong>Stage Kit candidates:</strong> ${pills(row.current_stage_kit_candidate_ids)}</div>`);
    if (arr(row.legacy_container_refs).length) sections.push(`<div class="small"><strong>Legacy refs:</strong> ${esc(row.legacy_container_refs.join(' · '))}</div>`);
    if (arr(row.noncurrent_or_legacy_refs).length) sections.push(`<div class="small"><strong>Lookup refs:</strong> ${esc(row.noncurrent_or_legacy_refs.join(' · '))}</div>`);
    return sections.join('') || '<span class="muted">No Container candidate resolved yet.</span>';
  }

  function render() {
    const rows = state.sources.filter(matches);
    el('summary-sources').textContent = state.sources.length;
    el('summary-containers').textContent = state.sources.filter((row) => arr(row.proposed_current_source_container_ids).length || arr(row.current_stage_kit_candidate_ids).length).length;
    el('summary-verify').textContent = state.sources.filter((row) => row.verification_needed).length;
    el('summary-visible').textContent = rows.length;
    el('result-count').textContent = `${rows.length} of ${state.sources.length} source procedures`;

    el('evidence-body').innerHTML = rows.map((row) => `
      <tr>
        <td><strong>${esc(row.stage_key || '—')}</strong></td>
        <td><div class="source-name">${esc(row.source_file)}</div><div class="small muted">Pages: ${esc(arr(row.source_pages).join(', ') || '—')}</div></td>
        <td><div class="pill-row">${pills(row.material_families)}</div><div class="small muted">${esc(row.family_page_index || '')}</div></td>
        <td>${containerEvidence(row)}</td>
        <td><div class="pill-row">${pills(row.suggested_setup_task_ids)}</div></td>
        <td>
          <div class="pill-row">${pills(row.source_mapping_statuses)}${pills(row.task_mapping_statuses)}</div>
          <div class="pill-row">${pills(row.requirement_preload_states)}${row.verification_needed ? '<span class="pill warn">Additional verification</span>' : ''}</div>
        </td>
      </tr>`).join('') || '<tr><td colspan="6" class="empty-state">No evidence matches these filters.</td></tr>';
  }

  function bindFilters() {
    ['filter-search','filter-stage','filter-material','filter-container','filter-verification'].forEach((id) => {
      el(id).addEventListener(id === 'filter-search' || id === 'filter-container' ? 'input' : 'change', render);
    });
    el('clear-filters').addEventListener('click', () => {
      ['filter-search','filter-stage','filter-material','filter-container','filter-verification'].forEach((id) => { el(id).value = ''; });
      render();
    });
  }

  async function load() {
    configureTheme();
    bindFilters();
    try {
      const [accessPayload, sourcePayload] = await Promise.all([
        api('api/setup/access'),
        api('api/setup/extra-material-evidence/sources'),
      ]);
      state.access = accessPayload.access || {};
      state.sources = sourcePayload.sources || [];
      el('evidence-access').textContent = `${state.access.display_name || state.access.authenticated_email || 'Signed in'} · ${state.access.role_name || 'No role'}`;
      populateFilters();
      render();
      setAlert(`Loaded ${state.sources.length} normalized procedure evidence sources. Unresolved mappings remain visible for verification.`);
    } catch (error) {
      setAlert(error.message, 'error');
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', load);
  else load();
})();
