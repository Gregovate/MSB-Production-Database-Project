// Controller Inventory detail additions that are useful before the write-side
// management workflow is enabled: permanent controller deep links and label state.
(function () {
  'use strict';

  const detailId = document.getElementById('detail-id');
  const detailFacts = document.getElementById('detail-facts');
  if (!detailId || !detailFacts) return;

  let lastRenderedControllerId = null;

  function esc(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&#39;');
  }

  function display(value, fallback = '—') {
    return value === null || value === undefined || value === '' ? fallback : value;
  }

  function formatDate(value) {
    if (!value) return '—';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString();
  }

  function fact(label, value) {
    return `<div class="fact"><span>${esc(label)}</span><strong>${esc(display(value))}</strong></div>`;
  }

  function ensureSection() {
    let section = document.getElementById('controller-label-state');
    if (section) return section;
    section = document.createElement('section');
    section.id = 'controller-label-state';
    section.className = 'detail-section';
    detailFacts.insertAdjacentElement('afterend', section);
    return section;
  }

  async function renderLabelState(controllerId) {
    if (!Number.isInteger(controllerId) || controllerId <= 0) return;
    lastRenderedControllerId = controllerId;
    const section = ensureSection();
    section.innerHTML = '<div class="section-title"><h3>Controller Label</h3></div><div class="muted" style="margin-top:8px">Loading label state…</div>';

    try {
      const response = await fetch(`api/controllers/${controllerId}`, {headers:{Accept:'application/json'}});
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || 'Controller label state could not be loaded.');
      if (lastRenderedControllerId !== controllerId) return;
      const c = payload.controller || {};
      section.innerHTML = `
        <div class="section-title"><h3>Controller Label</h3></div>
        <div class="fact-grid">
          ${fact('Label Required', c.label_required ? 'Yes' : 'No')}
          ${fact('Print Label', c.print_label ? 'Yes' : 'No')}
          ${fact('Print Count', c.label_print_count_cached ?? 0)}
          ${fact('Last Printed', formatDate(c.label_print_last_at_cached))}
        </div>
        <div class="muted">Print Label is the existing ref.controller request flag. Actual printer handoff remains separate from this browse screen until Controller Management / Label Service integration is enabled.</div>`;
    } catch (error) {
      if (lastRenderedControllerId !== controllerId) return;
      section.innerHTML = `<div class="section-title"><h3>Controller Label</h3></div><div class="error">${esc(error.message)}</div>`;
    }
  }

  function controllerIdFromHeading() {
    const match = String(detailId.textContent || '').match(/CTRL\s+(\d+)/i);
    return match ? Number(match[1]) : null;
  }

  new MutationObserver(() => {
    const controllerId = controllerIdFromHeading();
    if (controllerId && controllerId !== lastRenderedControllerId) renderLabelState(controllerId);
  }).observe(detailId, {childList: true, subtree: true, characterData: true});

  const requested = new URLSearchParams(window.location.search).get('controller_id');
  if (requested && /^\d+$/.test(requested) && typeof loadControllerDetail === 'function') {
    const controllerId = Number(requested);
    // The base list may still be loading, but Controller detail is independently
    // addressable and can open immediately from a FieldWiring cross-link.
    window.setTimeout(() => loadControllerDetail(controllerId), 0);
  }
})();
