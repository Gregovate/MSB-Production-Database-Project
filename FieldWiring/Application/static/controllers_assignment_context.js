// Read-only Controller-vs-LOR comparison inside assignment dialogs — V0.1.0.
(function () {
  'use strict';

  const esc = value => String(value ?? '')
    .replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;')
    .replaceAll('"','&quot;').replaceAll("'",'&#39;');
  const uidHex = value => Number(value).toString(16).toUpperCase().padStart(2,'0');
  const uidRange = (a,b) => a == null || b == null ? '—' : Number(a) === Number(b) ? uidHex(a) : `${uidHex(a)}-${uidHex(b)}`;

  async function api(url) {
    const response = await fetch(url,{headers:{Accept:'application/json'}});
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || payload.engineering_error || `Request failed (${response.status})`);
    return payload;
  }

  function wiringRows(payload) {
    const wiring = payload?.wiring || {};
    if (Array.isArray(wiring.rows)) return wiring.rows;
    return (wiring.controller_groups || wiring.groups || []).flatMap(group => Array.isArray(group.rows) ? group.rows : []);
  }

  function uidNumber(value) {
    const text = String(value || '').trim();
    if (!/^[0-9a-f]{1,2}$/i.test(text)) return null;
    const n = Number.parseInt(text,16);
    return n >= 1 && n <= 240 ? n : null;
  }

  function addressEvidence(rows) {
    const addresses = [];
    for (const row of rows) {
      const network = String(row.network || '').trim();
      const uid = uidNumber(row.controller);
      if (!network || uid == null) continue;
      addresses.push({network,uid,display_name:row.display_name || '',channel:row.start_channel});
    }
    const keys = new Map();
    for (const item of addresses) {
      const key = `${item.network.toLowerCase()}|${item.uid}`;
      if (!keys.has(key)) keys.set(key,{network:item.network,uid:item.uid,displays:new Set(),channels:new Set()});
      if (item.display_name) keys.get(key).displays.add(String(item.display_name));
      if (item.channel != null) keys.get(key).channels.add(String(item.channel));
    }
    return [...keys.values()];
  }

  function compare(controller,evidence) {
    if (!evidence.length) return {state:'REVIEW_REQUIRED',message:'No numeric LOR Network/UID requirement was resolved for this Display. Review current wiring before relying on this assignment.'};
    if (!controller.lor_network || controller.lor_uid_start == null || controller.lor_uid_end == null) {
      return {state:'UNPROGRAMMED',message:'This physical Controller has no recorded LOR Network/UID programming yet.'};
    }
    const network = String(controller.lor_network).trim().toLowerCase();
    const start = Number(controller.lor_uid_start), end = Number(controller.lor_uid_end);
    const allMatch = evidence.every(item => item.network.trim().toLowerCase() === network && item.uid >= start && item.uid <= end);
    if (allMatch) return {state:'MATCH',message:'The selected Display’s current LOR Network/UID requirement falls inside this Controller’s recorded current programming.'};
    return {state:'MISMATCH',message:'The selected Display’s current LOR Network/UID requirement does not match this Controller’s recorded current programming. Assignment does not reprogram the Controller.'};
  }

  function sameProgrammedAddress(controller,planning) {
    if (!controller.lor_network || controller.lor_uid_start == null || controller.lor_uid_end == null) return [];
    const network = String(controller.lor_network).trim().toLowerCase();
    return (planning || []).filter(c =>
      Number(c.controller_id) !== Number(controller.controller_id) &&
      String(c.lor_network || '').trim().toLowerCase() === network &&
      Number(c.lor_uid_start) === Number(controller.lor_uid_start) &&
      Number(c.lor_uid_end) === Number(controller.lor_uid_end));
  }

  async function enrichDialog(dialog) {
    if (!dialog || dialog.dataset.lorContextInstalled === '1') return;
    const title = dialog.querySelector('.management-dialog-header h2')?.textContent || '';
    const controllerMatch = title.match(/CTRL\s+(\d+)/i);
    const displayText = dialog.querySelector('.readonly-value')?.textContent || '';
    const displayMatch = displayText.match(/Display\s+(\d+)/i);
    if (!controllerMatch || !displayMatch) return;
    dialog.dataset.lorContextInstalled = '1';

    const form = dialog.querySelector('#assignment-edit-form');
    if (!form) return;
    const target = document.createElement('section');
    target.className = 'management-section assignment-lor-context';
    target.innerHTML = '<h3>Controller vs Current LOR</h3><div class="muted">Loading current planning evidence…</div>';
    const actions = form.querySelector('.management-dialog-actions');
    form.insertBefore(target, actions);

    try {
      const controllerId = Number(controllerMatch[1]);
      const displayId = Number(displayMatch[1]);
      const [controllerPayload,wiringPayload,optionsPayload] = await Promise.all([
        api(`api/controllers/${controllerId}`),
        api(`api/wiring?display_id=${displayId}`).catch(() => null),
        api('api/controller-management/options'),
      ]);
      const controller = controllerPayload.controller || {};
      const evidence = wiringPayload ? addressEvidence(wiringRows(wiringPayload)) : [];
      const result = compare(controller,evidence);
      const other = sameProgrammedAddress(controller,optionsPayload.options?.planning_controller_programming || []);
      const expected = evidence.length
        ? evidence.map(item => `${item.network} / ${uidHex(item.uid)}`).join(', ')
        : 'No numeric LOR address resolved';
      const physical = controller.lor_network && controller.lor_uid_start != null
        ? `${controller.lor_network} / ${uidRange(controller.lor_uid_start,controller.lor_uid_end)}`
        : 'UNPROGRAMMED';
      target.innerHTML = `
        <h3>Controller vs Current LOR</h3>
        <div class="assignment-compare-state state-${esc(result.state.toLowerCase())}">${esc(result.state.replaceAll('_',' '))}</div>
        <div class="management-form-grid">
          <label>Physical Controller<div class="readonly-value">${esc(physical)}</div></label>
          <label>Selected Display current LOR<div class="readonly-value">${esc(expected)}</div></label>
        </div>
        <div class="management-capacity">${esc(result.message)}</div>
        ${other.length ? `<div class="management-warning">Other physical Controllers recorded on the same programmed Network/UID range: ${other.map(c=>`CTRL ${c.controller_id} ${esc(c.model_code)} ${esc(c.controller_status_name)}`).join(', ')}. Repeated addresses may be intentional.</div>` : ''}
      `;
    } catch (error) {
      target.innerHTML = `<h3>Controller vs Current LOR</h3><div class="management-error">${esc(error.message)}</div>`;
    }
  }

  async function syncManageAssignmentCapability() {
    const heading = document.getElementById('detail-id');
    const match = String(heading?.textContent || '').match(/CTRL\s+(\d+)/i);
    const button = document.querySelector('#controller-management-actions .manage-assignments-button');
    if (!match || !button) return;
    try {
      const controller = (await api(`api/controllers/${Number(match[1])}`)).controller || {};
      if (controller.display_assignment_capable === false) {
        button.disabled = true;
        button.title = 'This Controller/device model is not a Display-assignment device.';
      }
    } catch (_) {}
  }

  const observer = new MutationObserver(mutations => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (!(node instanceof Element)) continue;
        if (node.id === 'controller-assignment-edit-dialog') enrichDialog(node);
        const nested = node.querySelector?.('#controller-assignment-edit-dialog');
        if (nested) enrichDialog(nested);
      }
    }
    syncManageAssignmentCapability();
  });
  observer.observe(document.body,{childList:true,subtree:true});
  syncManageAssignmentCapability();
})();
