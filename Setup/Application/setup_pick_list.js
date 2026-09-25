(() => {
  'use strict';

  const qs = new URLSearchParams(location.search);
  const seasonSelect = document.getElementById('season-select');
  const dateFilter = document.getElementById('date-filter');
  const summary = document.getElementById('summary');
  const pickList = document.getElementById('pick-list');
  const unresolvedSection = document.getElementById('unresolved-section');
  const unresolvedList = document.getElementById('unresolved-list');
  const statusLine = document.getElementById('status-line');
  const generatedAt = document.getElementById('generated-at');

  let readiness = null;

  function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
  }

  function seasonFromUrl() {
    const raw = qs.get('season_year') || '2026';
    return /^\d{4}$/.test(raw) ? raw : '2026';
  }

  function itemReasonsForDate(item, date) {
    const reasons = Array.isArray(item.reasons) ? item.reasons : [];
    return date ? reasons.filter(r => r.work_date === date) : reasons;
  }

  function stageScene(reason) {
    const stage = [reason.stage_key, reason.stage_name].filter(Boolean).join(' — ');
    return [stage, reason.scene_name].filter(Boolean).join(' / ') || 'Site-wide / no Stage';
  }

  function observationText(item) {
    const o = item.current_observation || {};
    if (o.current_stage_key || o.current_stage_name) {
      return `Current Setup observation: ${[o.current_stage_key, o.current_stage_name].filter(Boolean).join(' — ')}`;
    }
    if (o.current_location_note) return `Current Setup observation: ${o.current_location_note}`;
    return `Home / storage: ${item.home_location_code || 'not recorded'} · Not yet observed/moved in this Setup Session`;
  }

  function reasonText(r) {
    const parts = [
      `Day ${r.setup_day_number ?? '?'} · ${r.work_date || ''} · ${r.shift_code || ''} · Crew ${r.crew_lane || '?'}`,
      stageScene(r),
      r.task_name || 'Unnamed task',
      r.reason_label || r.reason_type || ''
    ].filter(Boolean);
    if (r.extra_material_name) {
      const qty = [r.quantity_required, r.quantity_uom].filter(Boolean).join(' ');
      parts.push([qty, r.extra_material_name].filter(Boolean).join(' '));
    }
    return parts.join(' — ');
  }

  function populateDates() {
    const current = dateFilter.value;
    const dates = [...new Set((readiness?.physical_items || [])
      .flatMap(i => (i.reasons || []).map(r => r.work_date))
      .filter(Boolean))].sort();
    dateFilter.innerHTML = '<option value="">All scheduled dates</option>' +
      dates.map(d => `<option value="${esc(d)}">${esc(d)}</option>`).join('');
    if (dates.includes(current)) dateFilter.value = current;
  }

  function renderSummary(items, unresolved) {
    const s = readiness?.summary || {};
    const cards = [
      ['Scheduled assignments', s.scheduled_assignment_count ?? 0],
      ['Physical items', items.length],
      ['Containers', items.filter(i => i.physical_type === 'CONTAINER').length],
      ['Detached displays', items.filter(i => i.physical_type === 'DISPLAY').length],
      ['Unresolved', unresolved.length]
    ];
    summary.innerHTML = cards.map(([label, value]) =>
      `<div class="summary-card"><strong>${esc(value)}</strong><span>${esc(label)}</span></div>`
    ).join('');
  }

  function renderUnresolved(date) {
    const unresolved = (readiness?.unresolved_requirements || [])
      .filter(r => !date || r.work_date === date);
    unresolvedSection.hidden = unresolved.length === 0;
    unresolvedList.innerHTML = unresolved.map(r => `
      <div class="unresolved">
        <strong>${esc(r.message || r.requirement_type || 'Unresolved requirement')}</strong>
        <div>${esc(stageScene(r))} — ${esc(r.task_name || 'Unnamed task')}</div>
        <div class="meta">Day ${esc(r.setup_day_number ?? '?')} · ${esc(r.work_date || '')} · ${esc(r.shift_code || '')} · Crew ${esc(r.crew_lane || '?')}</div>
      </div>`).join('');
    return unresolved;
  }

  function renderItems(date) {
    const all = readiness?.physical_items || [];
    const items = all.filter(item => itemReasonsForDate(item, date).length > 0);
    const groups = new Map();

    for (const item of items) {
      const reasons = itemReasonsForDate(item, date);
      const staged = date
        ? (reasons.map(r => r.target_staged_by).filter(Boolean).sort()[0] || item.target_staged_by)
        : item.target_staged_by;
      const needed = date || item.earliest_needed_for_work;
      const key = `${staged}|${needed}`;
      if (!groups.has(key)) groups.set(key, { staged, needed, items: [] });
      groups.get(key).items.push({ item, reasons });
    }

    if (!items.length) {
      pickList.innerHTML = '<div class="empty">No physical demand resolves from the selected scheduled work.</div>';
      return items;
    }

    pickList.innerHTML = [...groups.values()].sort((a,b) =>
      `${a.staged}|${a.needed}`.localeCompare(`${b.staged}|${b.needed}`)
    ).map(group => `
      <section class="pick-group">
        <h3>Stage by ${esc(group.staged || '—')} · Needed for ${esc(group.needed || '—')}</h3>
        ${group.items.map(({item, reasons}) => `
          <article class="pick-item">
            <div class="pick-item-head">
              <div>
                <div class="identity">${esc(item.identity)}</div>
                ${item.label ? `<div class="item-label">${esc(item.label)}</div>` : ''}
                <div class="meta">${esc(observationText(item))}</div>
              </div>
              <div class="meta">${esc(item.location_evidence_status || '')}</div>
            </div>
            <details class="reasons">
              <summary>${reasons.length} schedule/material reason${reasons.length === 1 ? '' : 's'}</summary>
              <ul class="reason-list">
                ${reasons.map(r => `<li>${esc(reasonText(r))}</li>`).join('')}
              </ul>
            </details>
          </article>`).join('')}
      </section>`).join('');

    return items;
  }

  function render() {
    if (!readiness) return;
    const date = dateFilter.value;
    const unresolved = renderUnresolved(date);
    const items = renderItems(date);
    renderSummary(items, unresolved);
    generatedAt.textContent = `Generated ${new Date().toLocaleString()}`;
    statusLine.textContent = readiness.session
      ? `Connected live view of ${readiness.session.season_year} scheduled physical demand.`
      : 'No Setup Session exists for this season.';
  }

  async function load() {
    const year = seasonSelect.value;
    statusLine.textContent = 'Loading scheduled physical demand…';
    const response = await fetch(`../api/setup/material-readiness?season_year=${encodeURIComponent(year)}`, {cache: 'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    readiness = data.readiness;
    populateDates();
    render();
  }

  const season = seasonFromUrl();
  for (const year of ['2025', '2026']) {
    const option = document.createElement('option');
    option.value = year;
    option.textContent = year;
    option.selected = year === season;
    seasonSelect.appendChild(option);
  }

  seasonSelect.addEventListener('change', () => {
    const url = new URL(location.href);
    url.searchParams.set('season_year', seasonSelect.value);
    history.replaceState({}, '', url);
    load().catch(showError);
  });
  dateFilter.addEventListener('change', render);
  document.getElementById('print-button').addEventListener('click', () => window.print());
  document.getElementById('back-button').addEventListener('click', () => {
    location.href = `../?season_year=${encodeURIComponent(seasonSelect.value)}`;
  });

  function showError(error) {
    statusLine.textContent = `Pick List unavailable: ${error.message || error}`;
    pickList.innerHTML = '';
  }

  load().catch(showError);
})();
