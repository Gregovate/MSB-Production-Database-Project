/* #299: browser owns login; local updater receives only #81 source evidence. */
(async function () {
  'use strict';
  const status = document.querySelector('#status');
  // A browser cannot reliably detect a registered Windows protocol handler.
  // Explain the expected prompt without claiming that launch succeeded.
  document.querySelector('#open-updater').addEventListener('click', () => {
    status.textContent = 'Your browser may ask permission to open MSB PC Preview Updater. Allow it only if you requested this update. If no updater window opens, use Install / Repair PC Updater below. If setup is blocked, contact the MSB administrator. No previews change from this button alone.';
  });
  const details = document.querySelector('#handoff-details');
  const diagnostic = { phase: 'idle', sourceHttpStatus: null };
  async function reportFailure(error) {
    // Permission state is evidence, never a substitute for a successful relay.
    for (const name of ['loopback-network', 'local-network']) {
      try {
        const permission = await globalThis.navigator.permissions.query({name});
        diagnostic[name] = permission.state;
      } catch (_) { diagnostic[name] = 'unavailable'; }
    }
    diagnostic.errorName = error.name || 'Error';
    diagnostic.error = error.message;
    // Deliberately omit fragment/nonce, request body, email, cookies and tokens.
    if (details) details.textContent = JSON.stringify(diagnostic, null, 2);
  }
  const args = new URLSearchParams(location.hash.slice(1));
  const port = args.get('port'), nonce = args.get('nonce');
  if (!port && !nonce) return;
  if (!/^\d{1,5}$/.test(port || '') || +port < 1024 || +port > 65535 || !/^[a-f0-9]{64}$/.test(nonce || '')) {
    status.textContent = 'Invalid updater request. Close this tab and reopen the PC updater.';
    return;
  }
  history.replaceState(null, '', location.pathname);
  try {
    status.textContent = 'Checking your access and the latest accepted MSB previews…';
    diagnostic.phase = 'accepted-source-request';
    const response = await fetch('../preflight/api/current-source', {credentials: 'same-origin', cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000)});
    diagnostic.sourceHttpStatus = response.status;
    if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) throw new Error('Your login or Production Crew access could not be verified.');
    const doc = await response.json();
    // Escape Unicode to keep HTTP byte count equal to the relay character count.
    const body = JSON.stringify(doc).replace(/[\u007f-\uffff]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0'));
    diagnostic.phase = 'loopback-request';
    status.textContent = 'MSB access checked. Connecting to the PC updater. Allow the browser request to access apps on this device if prompted…';
    const delivered = await fetch(`http://127.0.0.1:${port}/${nonce}`, {method: 'POST', headers: {'Content-Type': 'text/plain'}, body, credentials: 'omit', redirect: 'error', signal: AbortSignal.timeout(15000)});
    if (!delivered.ok) throw new Error('The PC updater did not accept the handoff.');
    diagnostic.phase = 'complete';
    if (details) details.textContent = JSON.stringify(diagnostic, null, 2);
    status.textContent = 'Access confirmed. Return to the PC updater to review the results. You may close this tab.';
  } catch (error) {
    const step = diagnostic.phase === 'loopback-request' ? 'The browser could not complete the connection to the PC updater.' : 'The browser could not obtain accepted MSB source evidence.';
    status.textContent = `${step} No preview update was authorized. Retain Support details below and the updater diagnostic log for the MSB administrator.`;
    await reportFailure(error);
  }
}());
