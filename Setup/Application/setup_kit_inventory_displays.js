/* Issue #167 — read-only physical Display contents for standalone Kit Inventory. */
(() => {
  const target = document.getElementById('kit-display-body');
  if (!target) return;

  function appBasePath() {
    const marker = '/kit-inventory';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }

  const APP_BASE = appBasePath();

  function escapeHtml(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  function routeContainerId() {
    const match = window.location.pathname.match(/\/kit-inventory\/(\d+)\/?$/);
    return match ? Number(match[1]) : null;
  }

  function renderEmpty(message) {
    target.innerHTML = `<tr><td colspan="4" class="empty-state">${escapeHtml(message)}</td></tr>`;
  }

  function renderRows(rows) {
    if (!rows.length) {
      renderEmpty('No current Display identities are assigned to this Kit Box.');
      return;
    }

    target.innerHTML = rows.map((row) => {
      const stage = [row.stage_key, row.stage_name].filter(Boolean).join(' — ') || '—';
      return `
        <tr>
          <td>
            <strong>${escapeHtml(row.display_name || `Display ${row.display_id}`)}</strong>
            <div class="muted">Display ${escapeHtml(row.display_id)}</div>
          </td>
          <td>${escapeHtml(row.inventory_type || '—')}</td>
          <td>${escapeHtml(stage)}</td>
          <td>${escapeHtml(row.display_status_name || '—')}</td>
        </tr>`;
    }).join('');
  }

  async function loadDisplays() {
    const containerId = routeContainerId();
    if (!containerId) {
      renderEmpty('Select a Kit Box.');
      return;
    }

    renderEmpty('Loading Displays…');
    try {
      const response = await fetch(
        `${APP_BASE}api/setup/kit-inventory/kit-boxes/${containerId}/displays`,
        { credentials: 'same-origin', headers: { Accept: 'application/json' } },
      );
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.error || `HTTP ${response.status}`);
      renderRows(Array.isArray(payload.displays) ? payload.displays : []);
    } catch (error) {
      console.error('Kit Display contents could not be loaded', error);
      renderEmpty('Display contents are temporarily unavailable.');
    }
  }

  const originalPushState = history.pushState.bind(history);
  history.pushState = function pushStateWithKitDisplayRefresh(...args) {
    originalPushState(...args);
    window.dispatchEvent(new Event('kitinventory:navigate'));
  };

  const originalReplaceState = history.replaceState.bind(history);
  history.replaceState = function replaceStateWithKitDisplayRefresh(...args) {
    originalReplaceState(...args);
    window.dispatchEvent(new Event('kitinventory:navigate'));
  };

  window.addEventListener('kitinventory:navigate', loadDisplays);
  window.addEventListener('popstate', loadDisplays);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadDisplays);
  } else {
    loadDisplays();
  }
})();
