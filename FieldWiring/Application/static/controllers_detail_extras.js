// Controller Inventory deep links, authenticated capability display, and the
// first narrow write-side action: request a Controller label.
(function () {
  'use strict';

  const detailId = document.getElementById('detail-id');
  const detailFacts = document.getElementById('detail-facts');
  const accessStatus = document.getElementById('controller-access-status');
  if (!detailId || !detailFacts) return;

  let lastRenderedControllerId = null;
  let controllerAccess = null;

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

  async function responseJson(response) {
    const text = await response.text();
    try {
      return text ? JSON.parse(text) : {};
    } catch (_) {
      throw new Error(`Controller server returned an unexpected response (${response.status}).`);
    }
  }

  async function loadControllerAccess() {
    try {
      const response = await fetch('api/controller-access', {headers:{Accept:'application/json'}});
      const payload = await responseJson(response);
      if (!response.ok) throw new Error(payload.error || 'Controller access could not be resolved.');
      controllerAccess = payload.access || null;
      if (accessStatus && controllerAccess) {
        const role = controllerAccess.role_name || 'Read Only';
        accessStatus.textContent = `${controllerAccess.display_name || controllerAccess.authenticated_email} · ${role}`;
        accessStatus.title = controllerAccess.can_manage_controllers
          ? 'Controller management authorized'
          : (controllerAccess.can_print_label ? 'Controller label requests authorized' : 'Controller browse access');
      }
      return controllerAccess;
    } catch (error) {
      controllerAccess = null;
      if (accessStatus) {
        accessStatus.textContent = 'Read-only';
        accessStatus.title = error.message;
      }
      return null;
    }
  }

  const accessPromise = loadControllerAccess();

  function ensureSection() {
    let section = document.getElementById('controller-label-state');
    if (section) return section;
    section = document.createElement('section');
    section.id = 'controller-label-state';
    section.className = 'detail-section';
    detailFacts.insertAdjacentElement('afterend', section);
    return section;
  }

  function labelAction(c) {
    if (!controllerAccess || !controllerAccess.can_print_label) return '';
    const pending = Boolean(c.print_label);
    return `
      <div class="controller-label-actions">
        <button id="request-controller-label" type="button" ${pending ? 'disabled' : ''}>
          ${pending ? 'Print Requested' : 'Print Label'}
        </button>
        <span class="muted">${pending ? 'Waiting for the label service to consume the request.' : 'Queues this permanent Controller ID for the label service.'}</span>
      </div>`;
  }

  async function requestLabel(controllerId) {
    const button = document.getElementById('request-controller-label');
    if (button) {
      button.disabled = true;
      button.textContent = 'Requesting…';
    }

    try {
      const response = await fetch(`api/controllers/${controllerId}/print-label`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-MSB-Controller-Command': '1',
        },
        body: '{}',
      });
      const payload = await responseJson(response);
      if (!response.ok) throw new Error(payload.error || 'Controller label request failed.');
      const result = payload.controller || {};
      const message = result.request_already_pending
        ? 'A label request was already pending.'
        : `Label requested${result.updated_by ? ` by ${result.updated_by}` : ''}.`;
      await renderLabelState(controllerId, message);
    } catch (error) {
      if (button) {
        button.disabled = false;
        button.textContent = 'Print Label';
      }
      const notice = document.getElementById('controller-label-notice');
      if (notice) {
        notice.className = 'error controller-label-notice';
        notice.textContent = error.message;
      }
    }
  }

  async function renderLabelState(controllerId, noticeText = '') {
    if (!Number.isInteger(controllerId) || controllerId <= 0) return;
    lastRenderedControllerId = controllerId;
    const section = ensureSection();
    section.innerHTML = '<div class="section-title"><h3>Controller Label</h3></div><div class="muted" style="margin-top:8px">Loading label state…</div>';

    try {
      await accessPromise;
      const response = await fetch(`api/controllers/${controllerId}`, {headers:{Accept:'application/json'}});
      const payload = await responseJson(response);
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
        ${labelAction(c)}
        <div id="controller-label-notice" class="controller-label-notice muted">${esc(noticeText)}</div>
        <div class="muted controller-label-help">Print Label uses the existing ref.controller request flag. The separate polling/print service handles the physical print.</div>`;

      const button = document.getElementById('request-controller-label');
      if (button && !button.disabled) {
        button.addEventListener('click', () => requestLabel(controllerId));
      }
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
