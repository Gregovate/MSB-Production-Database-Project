(() => {
  'use strict';

  const qs = new URLSearchParams(location.search);
  const seasonSelect = document.getElementById('season-select');
  const dateFilter = document.getElementById('date-filter');
  const pickStatusFilter = document.getElementById('pick-status-filter');
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

  function itemMoved(item) {
    return Boolean(item?.current_observation?.last_movement_event_id);
  }

  function formatObservedAt(value) {
    if (!value) return '';
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? String(value) : parsed.toLocaleString();
  }

  function formatDate(value) {
    if (!value) return '—';
    const parsed = new Date(`${value}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime())) return String(value);
    return parsed.toLocaleDateString(undefined, {
      weekday: 'short',
      month: 'numeric',
      day: 'numeric',
      year: 'numeric',
      timeZone: 'UTC'
    });
  }

  function currentLocationText(item) {
    const o = item.current_observation || {};
    if (o.current_stage_key || o.current_stage_name) {
      const stage = [o.current_stage_key, o.current_stage_name].filter(Boolean).join(' — ');
      return o.current_location_note ? `${stage} · ${o.current_location_note}` : stage;
    }
    if (o.current_location_note) return o.current_location_note;
    return 'Current location not resolved';
  }

  function pickStatusHtml(item) {
    if (!itemMoved(item)) {
      return '<span class="pick-status needs-pick">NEEDS PICK</span>';
    }
    const o = item.current_observation || {};
    const when = formatObservedAt(o.last_observed_at) || 'time unavailable';
    return `<span class="pick-status picked">PICKED</span><span class="pick-status-detail">${esc(when)} · ${esc(currentLocationText(item))}</span>`;
  }

  function destinationText(reasons) {
    const destinations = [...new Set(
      reasons.map(stageScene).filter(value => value && value !== 'Site-wide / no Stage')
    )];
    if (!destinations.length) return 'Destination not resolved';
    return destinations.join(' · ');
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

  function qrPayload(item) {
    const type = item.physical_type === 'DISPLAY' ? 'DISP' : 'CONT';
    return `https://db.sheboyganlights.org/scan/${type}/${item.physical_id}`;
  }

  function renderQrCodes() {
    document.querySelectorAll('.pick-qr[data-payload]').forEach((target) => {
      const payload = target.dataset.payload || '';
      target.innerHTML = '';
      if (!payload) return;
      if (typeof QRCode !== 'function') {
        target.textContent = 'QR unavailable';
        return;
      }
      new QRCode(target, {
        text: payload,
        width: 92,
        height: 92,
        colorDark: '#000000',
        colorLight: '#ffffff',
        correctLevel: QRCode.CorrectLevel.M
      });
    });
  }

  function populateDates() {
    const current = dateFilter.value;
    const dates = [...new Set((readiness?.physical_items || [])
      .flatMap(i => (i.reasons || []).map(r => r.work_date))
      .filter(Boolean))].sort();
    dateFilter.innerHTML = '<option value="">All scheduled dates</option>' +
      dates.map(d => `<option value="${esc(d)}">${esc(formatDate(d))}</option>`).join('');
    if (dates.includes(current)) dateFilter.value = current;
  }

  function renderSummary(items, unresolved) {
    const s = readiness?.summary || {};
    const cards = [
      ['Scheduled assignments', s.scheduled_assignment_count ?? 0],
      ['Needs pick', items.filter(i => !itemMoved(i)).length],
      ['Picked / moved', items.filter(itemMoved).length],
      ['Physical items', items.length],
      ['Material exceptions', unresolved.length]
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
        <strong>${esc(r.message || r.requirement_type || 'Material data exception')}</strong>
        <div>${esc(stageScene(r))} — ${esc(r.task_name || 'Unnamed task')}</div>
        <div class="meta">Day ${esc(r.setup_day_number ?? '?')} · ${esc(r.work_date || '')} · ${esc(r.shift_code || '')} · Crew ${esc(r.crew_lane || '?')}</div>
      </div>`).join('');
    return unresolved;
  }

  function itemDates(item, reasons, selectedDate) {
    const pickBy = selectedDate
      ? (reasons.map(r => r.target_staged_by).filter(Boolean).sort()[0] || item.target_staged_by)
      : item.target_staged_by;
    const neededFor = selectedDate || item.earliest_needed_for_work;
    return {pickBy, neededFor};
  }

  function renderItems(date) {
    const status = pickStatusFilter?.value || 'ALL';
    const items = (readiness?.physical_items || []).filter((item) => {
      if (!itemReasonsForDate(item, date).length) return false;
      if (status === 'OUTSTANDING') return !itemMoved(item);
      if (status === 'MOVED') return itemMoved(item);
      return true;
    });

    if (!items.length) {
      pickList.innerHTML = '<div class="empty">No physical demand resolves from the selected scheduled work.</div>';
      return items;
    }

    const rows = items.map((item) => {
      const reasons = itemReasonsForDate(item, date);
      const dates = itemDates(item, reasons, date);
      const payload = qrPayload(item);
      return `
        <tbody class="pick-record">
          <tr class="pick-row">
            <td class="pick-identity-cell">
              <div class="identity">${esc(item.identity)}</div>
              ${item.label ? `<div class="item-label">${esc(item.label)}</div>` : ''}
              <div class="pick-state">${pickStatusHtml(item)}</div>
            </td>
            <td class="location-cell">${esc(item.home_location_code || 'Not recorded')}</td>
            <td class="destination-cell">${esc(destinationText(reasons))}</td>
            <td class="date-cell"><strong>${esc(formatDate(dates.pickBy))}</strong></td>
            <td class="date-cell">${esc(formatDate(dates.neededFor))}</td>
            <td class="qr-cell">
              <div class="pick-qr" data-payload="${esc(payload)}" aria-label="QR for ${esc(item.identity)}"></div>
            </td>
          </tr>
          <tr class="pick-reasons-row">
            <td colspan="6">
              <details class="reasons">
                <summary>${reasons.length} reason${reasons.length === 1 ? '' : 's'} this item is needed</summary>
                <ul class="reason-list">
                  ${reasons.map(r => `<li>${esc(reasonText(r))}</li>`).join('')}
                </ul>
              </details>
            </td>
          </tr>
        </tbody>`;
    }).join('');

    pickList.innerHTML = `
      <div class="pick-table-wrap">
        <table class="pick-table">
          <thead>
            <tr>
              <th>Container / Display</th>
              <th>Home Location</th>
              <th>Destination</th>
              <th>Pick By</th>
              <th>Needed For</th>
              <th>QR Code</th>
            </tr>
          </thead>
          ${rows}
        </table>
      </div>`;

    renderQrCodes();
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
      ? `Live ${readiness.session.season_year} schedule → physical Pick List.`
      : 'No Setup Session exists for this season.';
  }

  async function load() {
    const year = seasonSelect.value;
    statusLine.textContent = 'Loading live scheduled material demand…';
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
  pickStatusFilter?.addEventListener('change', render);
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
