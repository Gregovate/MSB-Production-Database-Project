/* Issue #167 — show unresolved procedure evidence beside one Kit Box. */
(() => {
  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/kit-inventory';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }
  const APP_BASE = appBasePath();
  function appUrl(path) { return `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`; }
  function esc(value) { return String(value ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#039;'); }
  function arr(value) { return Array.isArray(value) ? value : []; }
  function selectedContainerId() {
    const match = window.location.pathname.match(/\/kit-inventory\/(\d+)\/?$/);
    return match ? Number(match[1]) : null;
  }

  async function loadEvidence() {
    const containerId = selectedContainerId();
    const body = el('kit-evidence-body');
    const summary = el('kit-evidence-summary');
    if (!body || !containerId) return;
    body.innerHTML = '<tr><td colspan="4" class="empty-state">Loading procedure evidence…</td></tr>';
    try {
      const response = await fetch(appUrl('api/setup/extra-material-evidence/sources'), {
        credentials: 'same-origin', headers: { Accept: 'application/json' },
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.error || `Setup API returned HTTP ${response.status}`);
      const rows = (payload.sources || []).filter((row) => {
        const candidates = [...arr(row.proposed_current_source_container_ids), ...arr(row.current_stage_kit_candidate_ids)].map(Number);
        return candidates.includes(containerId);
      });
      body.innerHTML = rows.map((row) => {
        const why = [];
        if (arr(row.proposed_current_source_container_ids).map(Number).includes(containerId)) why.push('Proposed current source');
        if (arr(row.current_stage_kit_candidate_ids).map(Number).includes(containerId)) why.push('Current Stage Kit candidate');
        const taskState = arr(row.task_mapping_statuses).join(' · ') || 'Task/step not mapped';
        const sourceState = arr(row.source_mapping_statuses).join(' · ') || 'Source mapping unresolved';
        return `
          <tr>
            <td><strong>${esc(row.stage_key || '')} ${esc(row.stage_name || '')}</strong><div class="muted">${esc(row.source_file || '')}</div></td>
            <td>${arr(row.material_families).map((v) => `<span class="pill">${esc(v)}</span>`).join(' ')}</td>
            <td>${why.map((v) => `<span class="pill">${esc(v)}</span>`).join(' ')}</td>
            <td>${esc(sourceState)}<br><span class="muted">${esc(taskState)}</span>${row.verification_needed ? '<br><span class="pill">Additional verification</span>' : ''}</td>
          </tr>`;
      }).join('') || '<tr><td colspan="4" class="empty-state">No procedure evidence currently points at this Kit Box.</td></tr>';
      if (summary) summary.textContent = rows.length
        ? `${rows.length} source procedure${rows.length === 1 ? '' : 's'} currently point at Container ${containerId}. These are review candidates, not accepted Kit contents.`
        : `No source procedure currently identifies Container ${containerId} as a proposed source or Stage Kit candidate.`;
    } catch (error) {
      body.innerHTML = `<tr><td colspan="4" class="empty-state">${esc(error.message)}</td></tr>`;
      if (summary) summary.textContent = '';
    }
  }

  function watchRoute() {
    loadEvidence();
    const originalPush = history.pushState.bind(history);
    history.pushState = (...args) => { originalPush(...args); queueMicrotask(loadEvidence); };
    window.addEventListener('popstate', loadEvidence);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', watchRoute);
  else watchRoute();
})();
