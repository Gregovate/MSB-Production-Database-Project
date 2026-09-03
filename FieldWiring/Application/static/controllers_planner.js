// Read-only pre-build Controller capacity and LOR UID planning — V0.1.0.
(function () {
  'use strict';

  const headerActions = document.querySelector('.header-actions');
  if (!headerActions) return;

  let access = null;
  let options = null;
  let stageWiringRows = [];
  let stageControllers = [];

  function esc(value) {
    return String(value ?? '')
      .replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;')
      .replaceAll('"','&quot;').replaceAll("'",'&#39;');
  }

  async function api(url) {
    const response = await fetch(url, {headers:{Accept:'application/json'}});
    const text = await response.text();
    let payload = {};
    try { payload = text ? JSON.parse(text) : {}; }
    catch (_) { throw new Error(`Controller server returned an unexpected response (${response.status}).`); }
    if (!response.ok) throw new Error(payload.error || payload.engineering_error || `Request failed (${response.status}).`);
    return payload;
  }

  function uidNumber(hex) {
    const text = String(hex || '').trim();
    if (!/^[0-9a-f]{1,2}$/i.test(text)) return null;
    const value = Number.parseInt(text, 16);
    return value >= 1 && value <= 240 ? value : null;
  }

  function uidHex(value) {
    return Number(value).toString(16).toUpperCase().padStart(2,'0');
  }

  function uidRange(start, end) {
    if (start == null || end == null) return '—';
    return Number(start) === Number(end) ? uidHex(start) : `${uidHex(start)}-${uidHex(end)}`;
  }

  function wiringRows(payload) {
    const wiring = payload?.wiring || {};
    if (Array.isArray(wiring.rows)) return wiring.rows;
    const groups = Array.isArray(wiring.groups) ? wiring.groups : [];
    return groups.flatMap(group => Array.isArray(group.rows) ? group.rows : []);
  }

  function unique(values) {
    return [...new Set(values.filter(v => v !== null && v !== undefined && String(v).trim() !== '').map(v => String(v).trim()))];
  }

  function selectedStage() {
    const select = document.getElementById('planner-stage');
    const id = Number(select?.value || 0);
    return (options?.planning_stages || []).find(s => Number(s.stage_id) === id) || null;
  }

  function selectedModel() {
    const select = document.getElementById('planner-model');
    const id = Number(select?.value || 0);
    return (options?.models || []).find(m => Number(m.controller_model_id) === id) || null;
  }

  function stageOptionHtml() {
    return (options?.planning_stages || []).map(s =>
      `<option value="${s.stage_id}">${esc(s.stage_key)} · ${esc(s.stage_name)}</option>`
    ).join('');
  }

  function modelOptionHtml() {
    return (options?.models || []).map(m => {
      const cap = m.lor_uid_capacity ? ` · ${m.lor_uid_capacity} UID${Number(m.lor_uid_capacity) === 1 ? '' : 's'}` : '';
      return `<option value="${m.controller_model_id}">${esc(m.model_code)} — ${esc(m.model_name)}${esc(cap)}</option>`;
    }).join('');
  }

  function allNetworks() {
    const names = [];
    for (const row of options?.planning_lor_uid_usage || []) names.push(row.network);
    for (const row of options?.planning_controller_programming || []) names.push(row.lor_network);
    return unique(names).sort((a,b) => a.localeCompare(b, undefined, {numeric:true}));
  }

  function networkOptionHtml(selected='') {
    return allNetworks().map(n => `<option value="${esc(n)}" ${n === selected ? 'selected' : ''}>${esc(n)}</option>`).join('');
  }

  async function loadOptions() {
    if (options) return options;
    const payload = await api('api/controller-management/options');
    options = payload.options || {};
    return options;
  }

  function stageNetworks() {
    const networks = unique(stageWiringRows.map(row => row.network));
    const stage = selectedStage();
    for (const spare of options?.planning_explicit_spares || []) {
      if (stage && Number(spare.stage_id) === Number(stage.stage_id)) networks.push(spare.network);
    }
    return unique(networks).sort((a,b) => a.localeCompare(b, undefined, {numeric:true}));
  }

  function parseDisplayNames(value) {
    return String(value || '').split(',').map(x => x.trim()).filter(Boolean);
  }

  function controllerUsedRows(controller) {
    const displays = new Set(parseDisplayNames(controller.display_names));
    const net = String(controller.lor_network || '').trim().toLowerCase();
    const start = Number(controller.lor_uid_start);
    const end = Number(controller.lor_uid_end);
    return stageWiringRows.filter(row => {
      if (String(row.network || '').trim().toLowerCase() !== net) return false;
      const uid = uidNumber(row.controller);
      if (uid == null || uid < start || uid > end) return false;
      if (!displays.size) return true;
      return displays.has(String(row.display_name || '').trim());
    });
  }

  function stageSpareRowsForController(controller) {
    const stage = selectedStage();
    if (!stage) return [];
    const net = String(controller.lor_network || '').trim().toLowerCase();
    const start = Number(controller.lor_uid_start);
    const end = Number(controller.lor_uid_end);
    return (options?.planning_explicit_spares || []).filter(row => {
      if (Number(row.stage_id) !== Number(stage.stage_id)) return false;
      if (String(row.network || '').trim().toLowerCase() !== net) return false;
      const uid = uidNumber(row.uid_hex);
      return uid != null && uid >= start && uid <= end;
    });
  }

  function controllersAtSameAddress(controller) {
    const net = String(controller.lor_network || '').trim().toLowerCase();
    const start = Number(controller.lor_uid_start);
    const end = Number(controller.lor_uid_end);
    return stageControllers.filter(other =>
      String(other.lor_network || '').trim().toLowerCase() === net &&
      Number(other.lor_uid_start) === start && Number(other.lor_uid_end) === end
    );
  }

  function renderStageCapacity() {
    const target = document.getElementById('planner-stage-results');
    const networkTarget = document.getElementById('planner-stage-networks');
    const stage = selectedStage();
    if (!target || !networkTarget || !stage) return;

    const networks = stageNetworks();
    networkTarget.innerHTML = networks.length
      ? networks.map(n => `<span class="planner-chip">${esc(n)}</span>`).join('')
      : '<span class="muted">No current LOR Network resolved for this Stage.</span>';

    if (!stageControllers.length) {
      target.innerHTML = '<div class="planner-empty">No physical Controller is currently assigned to a Display in this Stage.</div>';
      return;
    }

    target.innerHTML = stageControllers.map(c => {
      const used = controllerUsedRows(c);
      const uniqueChannels = new Set(used.map(row => `${row.network}|${row.controller}|${row.start_channel}|${row.end_channel}|${row.display_name}`));
      const spares = stageSpareRowsForController(c);
      const shared = controllersAtSameAddress(c);
      let spareLine = '';
      if (spares.length && shared.length === 1) {
        const channels = spares.map(s => {
          const span = s.end_channel && Number(s.end_channel) !== Number(s.start_channel)
            ? `${s.start_channel}-${s.end_channel}` : s.start_channel;
          return `${s.uid_hex} Ch ${span}`;
        });
        spareLine = `<div class="planner-spare">Explicit SPARE: ${spares.length} · ${esc(channels.join(', '))}</div>`;
      } else if (spares.length && shared.length > 1) {
        spareLine = `<div class="planner-review">${spares.length} explicit SPARE row${spares.length === 1 ? '' : 's'} at this shared Network/UID address; physical Controller attribution requires review.</div>`;
      }

      return `<div class="planner-controller">
        <div class="planner-controller-head">
          <strong>CTRL ${c.controller_id} · ${esc(c.model_code)}</strong>
          <span class="pill ${esc(c.controller_status_name)}">${esc(c.controller_status_name)}</span>
        </div>
        <div class="planner-meta">Programmed: ${esc(c.lor_network || 'Unprogrammed')} ${c.lor_uid_start ? `/ ${uidRange(c.lor_uid_start,c.lor_uid_end)}` : ''}</div>
        <div class="planner-meta">Displays: ${esc(c.display_names || 'none')}</div>
        <div class="planner-meta">Current LOR wiring rows resolved for these Displays: ${uniqueChannels.size}</div>
        ${shared.length > 1 ? `<div class="planner-review">Shared physical address in this Stage: ${shared.length} Controller IDs use ${esc(c.lor_network)} / ${uidRange(c.lor_uid_start,c.lor_uid_end)}.</div>` : ''}
        ${spareLine}
      </div>`;
    }).join('');
  }

  async function loadStage() {
    const stage = selectedStage();
    const target = document.getElementById('planner-stage-results');
    if (!stage || !target) return;
    target.innerHTML = '<div class="planner-empty">Loading Stage capacity…</div>';
    try {
      const [wiringPayload, controllersPayload] = await Promise.all([
        api(`api/wiring?stage_id=${stage.stage_id}`),
        api(`api/controllers?stage_id=${stage.stage_id}`),
      ]);
      stageWiringRows = wiringRows(wiringPayload);
      stageControllers = controllersPayload.controllers || [];
      renderStageCapacity();

      const current = stageNetworks();
      const networkSelect = document.getElementById('planner-network');
      if (networkSelect && current.length) {
        networkSelect.value = current[0];
        renderNetworkPlan();
      }
    } catch (error) {
      stageWiringRows = [];
      stageControllers = [];
      target.innerHTML = `<div class="error">${esc(error.message)}</div>`;
    }
  }

  function modelUidWidth(model) {
    if (!model || !model.lor_uid_capacity) return 1;
    return Number(model.lor_uid_capacity);
  }

  function lorUsageForNetwork(network) {
    const usage = new Map();
    for (const row of options?.planning_lor_uid_usage || []) {
      if (String(row.network || '').trim().toLowerCase() !== String(network || '').trim().toLowerCase()) continue;
      const uid = uidNumber(row.uid_hex);
      if (uid == null) continue;
      if (!usage.has(uid)) usage.set(uid, {uid, displays:new Set(), previews:new Set(), channels:new Set()});
      const item = usage.get(uid);
      if (row.display_name) item.displays.add(String(row.display_name));
      if (row.preview_name) item.previews.add(String(row.preview_name));
      const channel = row.end_channel && Number(row.end_channel) !== Number(row.start_channel)
        ? `${row.start_channel}-${row.end_channel}` : row.start_channel;
      if (channel !== null && channel !== undefined) item.channels.add(String(channel));
    }
    return usage;
  }

  function physicalForNetwork(network) {
    return (options?.planning_controller_programming || []).filter(c =>
      String(c.lor_network || '').trim().toLowerCase() === String(network || '').trim().toLowerCase() &&
      c.lor_uid_start != null && c.lor_uid_end != null
    );
  }

  function overlap(aStart,aEnd,bStart,bEnd) {
    return Number(aStart) <= Number(bEnd) && Number(bStart) <= Number(aEnd);
  }

  function candidateBlocks(network, width) {
    const lor = lorUsageForNetwork(network);
    const physical = physicalForNetwork(network);
    const result = [];
    for (let start=1; start + width - 1 <= 240; start++) {
      const end = start + width - 1;
      let lorBlocked = false;
      for (let uid=start; uid<=end; uid++) if (lor.has(uid)) { lorBlocked = true; break; }
      if (lorBlocked) continue;

      const deployedOverlap = physical.filter(c => c.controller_status_name !== 'AVAILABLE' && overlap(start,end,c.lor_uid_start,c.lor_uid_end));
      if (deployedOverlap.length) continue;
      const stockOverlap = physical.filter(c => c.controller_status_name === 'AVAILABLE' && overlap(start,end,c.lor_uid_start,c.lor_uid_end));
      result.push({start,end,stockOverlap});
    }
    return result;
  }

  function renderNetworkPlan() {
    const network = document.getElementById('planner-network')?.value || '';
    const model = selectedModel();
    const target = document.getElementById('planner-network-results');
    if (!target || !network || !model) return;

    const width = modelUidWidth(model);
    const lor = lorUsageForNetwork(network);
    const physical = physicalForNetwork(network);
    const candidates = candidateBlocks(network,width);
    const currentStageNetworks = stageNetworks().map(x => x.toLowerCase());
    const networkIsCurrentAtStage = currentStageNetworks.includes(network.toLowerCase());
    const regular = network.toLowerCase() === 'regular';

    const warning = networkIsCurrentAtStage
      ? `This Network is currently used by the selected Stage.`
      : regular
        ? `Regular is park-wide, slow-speed, and used primarily for background sequences. Confirm it is appropriate for this Display.`
        : `This Network is not currently used by the selected Stage. Confirm physical reach using the existing park/network map before planning a new Controller here.`;

    const candidateHtml = candidates.slice(0,24).map(block => {
      const stock = block.stockOverlap.filter(c => Number(c.controller_model_id) === Number(model.controller_model_id));
      const anyStock = block.stockOverlap;
      return `<div class="planner-block">
        <strong>${esc(network)} / ${uidRange(block.start,block.end)}</strong>
        <div class="muted">${width} sequential UID${width === 1 ? '' : 's'} clear in current LOR and no non-AVAILABLE physical Controller overlaps.</div>
        ${stock.length ? `<div class="stock">Compatible AVAILABLE stock already programmed here: ${stock.map(c => `CTRL ${c.controller_id}`).join(', ')}</div>` : ''}
        ${!stock.length && anyStock.length ? `<div class="caution">AVAILABLE Controller programming overlaps: ${anyStock.map(c => `CTRL ${c.controller_id} ${c.model_code}`).join(', ')}</div>` : ''}
      </div>`;
    }).join('');

    const uidKeys = new Set([...lor.keys()]);
    for (const c of physical) {
      for (let uid=Number(c.lor_uid_start); uid<=Number(c.lor_uid_end); uid++) uidKeys.add(uid);
    }
    const rows = [...uidKeys].sort((a,b)=>a-b).map(uid => {
      const l = lor.get(uid);
      const pcs = physical.filter(c => uid >= Number(c.lor_uid_start) && uid <= Number(c.lor_uid_end));
      return `<tr>
        <td>${uidHex(uid)}</td>
        <td>${l ? (l.displays.size > 1 ? 'USED / SHARED' : 'USED') : 'UNUSED BY LOR'}</td>
        <td>${l ? esc([...l.displays].join(', ')) : '—'}</td>
        <td>${pcs.length ? pcs.map(c => `CTRL ${c.controller_id} ${esc(c.model_code)} ${esc(c.controller_status_name)}`).join('<br>') : '—'}</td>
      </tr>`;
    }).join('');

    target.innerHTML = `
      <div class="planner-note ${networkIsCurrentAtStage ? '' : 'planner-warning'}">${esc(warning)}</div>
      <div class="planner-summary">
        <div><span>Selected Network</span><strong>${esc(network)}</strong></div>
        <div><span>Model</span><strong>${esc(model.model_code)}</strong></div>
        <div><span>Required UID Width</span><strong>${width}</strong></div>
      </div>
      <div class="planner-note">UID availability is always calculated inside the selected Network. Repeated UIDs on different Networks are unrelated. Intentional shared addresses on the same Network remain valid and are shown rather than rejected.</div>
      <h3>Candidate contiguous blocks</h3>
      <div class="planner-blocks">${candidateHtml || '<div class="planner-empty">No candidate block of this width was found.</div>'}</div>
      <h3 style="margin-top:14px">Current address evidence</h3>
      <div class="planner-table-wrap"><table class="planner-table"><thead><tr><th>UID</th><th>LOR state</th><th>LOR Displays</th><th>Physical Controllers programmed here</th></tr></thead><tbody>${rows || '<tr><td colspan="4">No current usage resolved.</td></tr>'}</tbody></table></div>
    `;
  }

  async function openPlanner() {
    await loadOptions();
    const old = document.getElementById('controller-planner-dialog');
    if (old) old.remove();
    const dialog = document.createElement('dialog');
    dialog.id = 'controller-planner-dialog';
    dialog.className = 'planner-dialog';
    dialog.innerHTML = `
      <div class="planner-shell">
        <div class="planner-head">
          <div><h2>Controller Capacity Planner</h2><div class="muted">Probe before building the Display in LOR: Stage capacity first, then Network-specific UID capacity.</div></div>
          <button type="button" id="planner-close">Close</button>
        </div>
        <div class="planner-body">
          <div class="planner-grid">
            <section class="planner-panel">
              <h3>1. Stage capacity</h3>
              <div class="planner-controls"><label>Intended Stage / Sub-stage<select id="planner-stage">${stageOptionHtml()}</select></label></div>
              <div class="planner-note">Networks shown here are <strong>currently used by this Stage</strong>, not a claim that every other Network is physically unavailable. Use the existing map to confirm physical reach when considering another Network.</div>
              <div id="planner-stage-networks" class="planner-network-row"></div>
              <div id="planner-stage-results"></div>
            </section>
            <section class="planner-panel">
              <h3>2. Network / UID probe</h3>
              <div class="planner-controls">
                <label>Network<select id="planner-network">${networkOptionHtml()}</select></label>
                <label>Controller Model<select id="planner-model">${modelOptionHtml()}</select></label>
              </div>
              <div id="planner-network-results"></div>
            </section>
          </div>
        </div>
      </div>`;
    document.body.appendChild(dialog);
    document.getElementById('planner-close').addEventListener('click', () => { dialog.close(); dialog.remove(); });
    document.getElementById('planner-stage').addEventListener('change', loadStage);
    document.getElementById('planner-network').addEventListener('change', renderNetworkPlan);
    document.getElementById('planner-model').addEventListener('change', renderNetworkPlan);
    dialog.showModal();
    await loadStage();
    renderNetworkPlan();
  }

  async function install() {
    try {
      const payload = await api('api/controller-access');
      access = payload.access || null;
      if (!access?.can_manage_controllers) return;
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'planner-launch';
      button.textContent = 'Plan Capacity';
      button.title = 'Probe Stage spare channels and Network UID capacity before building a Display';
      button.addEventListener('click', () => openPlanner().catch(error => window.alert(error.message)));
      headerActions.insertBefore(button, document.getElementById('theme-toggle'));
    } catch (_) {
      // Browse remains available even if Manager planning access cannot resolve.
    }
  }

  install();
})();
