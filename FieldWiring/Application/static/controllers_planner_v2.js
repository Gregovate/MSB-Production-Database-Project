// Read-only pre-build Controller capacity and LOR UID planning — V0.2.0.
(function () {
  'use strict';
  const headerActions = document.querySelector('.header-actions');
  if (!headerActions) return;

  let options = null;
  let stageCatalog = [];
  let stageWiringRows = [];
  let stageControllers = [];

  const esc = value => String(value ?? '')
    .replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;')
    .replaceAll('"','&quot;').replaceAll("'",'&#39;');

  async function api(url) {
    const response = await fetch(url, {headers:{Accept:'application/json'}});
    const text = await response.text();
    let payload = {};
    try { payload = text ? JSON.parse(text) : {}; }
    catch (_) { throw new Error(`Unexpected Controller response (${response.status}).`); }
    if (!response.ok) throw new Error(payload.error || payload.engineering_error || `Request failed (${response.status}).`);
    return payload;
  }

  function uidNumber(value) {
    const text = String(value || '').trim();
    if (!/^[0-9a-f]{1,2}$/i.test(text)) return null;
    const n = Number.parseInt(text,16);
    return n >= 1 && n <= 240 ? n : null;
  }
  const uidHex = value => Number(value).toString(16).toUpperCase().padStart(2,'0');
  const uidRange = (a,b) => a == null || b == null ? '—' : Number(a) === Number(b) ? uidHex(a) : `${uidHex(a)}-${uidHex(b)}`;
  const unique = values => [...new Set(values.filter(v => v !== null && v !== undefined && String(v).trim()).map(v => String(v).trim()))];

  function selectedStage() {
    const id = Number(document.getElementById('planner-stage')?.value || 0);
    return (options?.planning_stages || []).find(s => Number(s.stage_id) === id) || null;
  }
  function selectedModel() {
    const id = Number(document.getElementById('planner-model')?.value || 0);
    return (options?.models || []).find(m => Number(m.controller_model_id) === id) || null;
  }
  function stageCatalogItem(stageId) {
    return stageCatalog.find(s => Number(s.stage_id) === Number(stageId)) || null;
  }
  function flattenWiring(payload) {
    const wiring = payload?.wiring || {};
    if (Array.isArray(wiring.rows)) return wiring.rows;
    return (wiring.controller_groups || wiring.groups || []).flatMap(g => Array.isArray(g.rows) ? g.rows : []);
  }
  function dedupeRows(rows) {
    const seen = new Set();
    return rows.filter(row => {
      const key = [row.display_id,row.display_name,row.network,row.controller,row.start_channel,row.end_channel,row.channel_name].join('|');
      if (seen.has(key)) return false;
      seen.add(key); return true;
    });
  }

  async function loadReference() {
    if (options) return;
    const [management, stages] = await Promise.all([
      api('api/controller-management/options'),
      api('api/stages'),
    ]);
    options = management.options || {};
    stageCatalog = stages.stages || [];
  }

  function allNetworks() {
    return unique([
      ...(options?.planning_lor_uid_usage || []).map(r => r.network),
      ...(options?.planning_controller_programming || []).map(r => r.lor_network),
    ]).sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));
  }
  function stageOptions() {
    return (options?.planning_stages || []).map(s => `<option value="${s.stage_id}">${esc(s.stage_key)} · ${esc(s.stage_name)}</option>`).join('');
  }
  function modelOptions() {
    return (options?.models || []).map(m => {
      const cap = m.lor_uid_capacity ? ` · ${m.lor_uid_capacity} UID${Number(m.lor_uid_capacity)===1?'':'s'}` : '';
      return `<option value="${m.controller_model_id}">${esc(m.model_code)} — ${esc(m.model_name)}${esc(cap)}</option>`;
    }).join('');
  }
  function networkOptions() {
    return allNetworks().map(n => `<option value="${esc(n)}">${esc(n)}</option>`).join('');
  }

  function stageNetworks() {
    const stage = selectedStage();
    const values = stageWiringRows.map(r => r.network);
    for (const spare of options?.planning_explicit_spares || []) {
      if (stage && Number(spare.stage_id) === Number(stage.stage_id)) values.push(spare.network);
    }
    return unique(values).sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));
  }
  const displayNames = value => String(value || '').split(',').map(x=>x.trim()).filter(Boolean);

  function controllerUsedRows(c) {
    const names = new Set(displayNames(c.display_names));
    const network = String(c.lor_network || '').trim().toLowerCase();
    const start = Number(c.lor_uid_start), end = Number(c.lor_uid_end);
    return stageWiringRows.filter(row => {
      if (String(row.network || '').trim().toLowerCase() !== network) return false;
      const uid = uidNumber(row.controller);
      if (uid == null || uid < start || uid > end) return false;
      return !names.size || names.has(String(row.display_name || '').trim());
    });
  }
  function spareRows(c) {
    const stage = selectedStage();
    const network = String(c.lor_network || '').trim().toLowerCase();
    const start = Number(c.lor_uid_start), end = Number(c.lor_uid_end);
    return (options?.planning_explicit_spares || []).filter(row => {
      if (!stage || Number(row.stage_id) !== Number(stage.stage_id)) return false;
      if (String(row.network || '').trim().toLowerCase() !== network) return false;
      const uid = uidNumber(row.uid_hex);
      return uid != null && uid >= start && uid <= end;
    });
  }
  function sameAddress(c) {
    return stageControllers.filter(other =>
      String(other.lor_network || '').trim().toLowerCase() === String(c.lor_network || '').trim().toLowerCase() &&
      Number(other.lor_uid_start) === Number(c.lor_uid_start) && Number(other.lor_uid_end) === Number(c.lor_uid_end));
  }

  function renderStage() {
    const stage = selectedStage();
    const networks = stageNetworks();
    document.getElementById('planner-stage-networks').innerHTML = networks.length
      ? networks.map(n=>`<span class="planner-chip">${esc(n)}</span>`).join('')
      : '<span class="muted">No current LOR Network resolved for this Stage.</span>';
    const target = document.getElementById('planner-stage-results');
    if (!stageControllers.length) {
      target.innerHTML = '<div class="planner-empty">No physical Controller is currently assigned to a Display in this Stage.</div>';
      return;
    }
    target.innerHTML = stageControllers.map(c => {
      const used = new Set(controllerUsedRows(c).map(r=>[r.network,r.controller,r.start_channel,r.end_channel,r.display_name].join('|')));
      const spares = spareRows(c);
      const shared = sameAddress(c);
      let spare = '';
      if (spares.length && shared.length === 1) {
        const channels = spares.map(s => `${s.uid_hex} Ch ${s.end_channel && Number(s.end_channel)!==Number(s.start_channel) ? `${s.start_channel}-${s.end_channel}` : s.start_channel}`);
        spare = `<div class="planner-spare">Explicit SPARE: ${spares.length} · ${esc(channels.join(', '))}</div>`;
      } else if (spares.length) {
        spare = `<div class="planner-review">${spares.length} explicit SPARE row${spares.length===1?'':'s'} at a shared Network/UID address; physical Controller attribution requires review.</div>`;
      }
      return `<div class="planner-controller">
        <div class="planner-controller-head"><strong>CTRL ${c.controller_id} · ${esc(c.model_code)}</strong><span class="pill ${esc(c.controller_status_name)}">${esc(c.controller_status_name)}</span></div>
        <div class="planner-meta">Programmed: ${esc(c.lor_network || 'Unprogrammed')}${c.lor_uid_start ? ` / ${uidRange(c.lor_uid_start,c.lor_uid_end)}` : ''}</div>
        <div class="planner-meta">Displays: ${esc(c.display_names || 'none')}</div>
        <div class="planner-meta">Current LOR wiring rows for assigned Displays: ${used.size}</div>
        ${shared.length>1 ? `<div class="planner-review">Shared address: ${shared.length} physical Controller IDs use ${esc(c.lor_network)} / ${uidRange(c.lor_uid_start,c.lor_uid_end)} in this Stage.</div>` : ''}
        ${spare}
      </div>`;
    }).join('');
  }

  async function loadStage() {
    const stage = selectedStage();
    const target = document.getElementById('planner-stage-results');
    if (!stage || !target) return;
    target.innerHTML = '<div class="planner-empty">Loading Stage capacity…</div>';
    const catalog = stageCatalogItem(stage.stage_id);
    try {
      const controllerPromise = api(`api/controllers?stage_id=${stage.stage_id}`);
      const contexts = catalog?.contexts || [];
      const wiringPromises = contexts.map(ctx => {
        const q = new URLSearchParams({stage_id:String(stage.stage_id), preview_uuid:String(ctx.preview_uuid)});
        if (ctx.scene_uuid) q.set('scene_uuid',String(ctx.scene_uuid));
        return api(`api/wiring?${q.toString()}`).catch(() => null);
      });
      const [controllersPayload, wiringPayloads] = await Promise.all([controllerPromise, Promise.all(wiringPromises)]);
      stageControllers = controllersPayload.controllers || [];
      stageWiringRows = dedupeRows(wiringPayloads.filter(Boolean).flatMap(flattenWiring));
      renderStage();
      const current = stageNetworks();
      const network = document.getElementById('planner-network');
      if (network && current.length && [...network.options].some(o=>o.value===current[0])) network.value = current[0];
      renderNetwork();
    } catch (error) {
      stageControllers = []; stageWiringRows = [];
      target.innerHTML = `<div class="error">${esc(error.message)}</div>`;
    }
  }

  function lorUsage(network) {
    const map = new Map();
    for (const row of options?.planning_lor_uid_usage || []) {
      if (String(row.network || '').trim().toLowerCase() !== String(network || '').trim().toLowerCase()) continue;
      const uid = uidNumber(row.uid_hex); if (uid == null) continue;
      if (!map.has(uid)) map.set(uid,{displays:new Set(),channels:new Set()});
      const item = map.get(uid);
      if (row.display_name) item.displays.add(String(row.display_name));
      if (row.start_channel != null) item.channels.add(String(row.end_channel && Number(row.end_channel)!==Number(row.start_channel) ? `${row.start_channel}-${row.end_channel}` : row.start_channel));
    }
    return map;
  }
  function physical(network) {
    return (options?.planning_controller_programming || []).filter(c =>
      String(c.lor_network || '').trim().toLowerCase() === String(network || '').trim().toLowerCase() && c.lor_uid_start != null && c.lor_uid_end != null);
  }
  const overlaps = (a,b,c,d) => Number(a)<=Number(d) && Number(c)<=Number(b);

  function candidates(network,width) {
    const used = lorUsage(network), pcs = physical(network), out=[];
    for (let start=1; start+width-1<=240; start++) {
      const end=start+width-1;
      let lorBlocked=false; for (let uid=start;uid<=end;uid++) if (used.has(uid)){lorBlocked=true;break;}
      if (lorBlocked) continue;
      const hard = pcs.filter(c=>c.controller_status_name!=='AVAILABLE' && overlaps(start,end,c.lor_uid_start,c.lor_uid_end));
      if (hard.length) continue;
      const stock = pcs.filter(c=>c.controller_status_name==='AVAILABLE' && overlaps(start,end,c.lor_uid_start,c.lor_uid_end));
      out.push({start,end,stock});
    }
    return out;
  }

  function renderNetwork() {
    const network=document.getElementById('planner-network')?.value || '';
    const model=selectedModel(); const target=document.getElementById('planner-network-results');
    if (!network || !model || !target) return;
    const width=Number(model.lor_uid_capacity || 1), used=lorUsage(network), pcs=physical(network), blocks=candidates(network,width);
    const stageNets=stageNetworks().map(n=>n.toLowerCase());
    const current=stageNets.includes(network.toLowerCase()), regular=network.toLowerCase()==='regular';
    const note=current ? 'This Network is currently used by the selected Stage.' : regular
      ? 'Regular is park-wide, slow-speed, and used primarily for background sequences. Confirm it is appropriate for this Display.'
      : 'This Network is not currently used by the selected Stage. Confirm physical reach on the existing park/network map before planning a new Controller here.';
    const blockHtml=blocks.slice(0,24).map(b=>{
      const matching=b.stock.filter(c=>Number(c.controller_model_id)===Number(model.controller_model_id));
      return `<div class="planner-block"><strong>${esc(network)} / ${uidRange(b.start,b.end)}</strong><div class="muted">${width} sequential UID${width===1?'':'s'} clear in current LOR and no non-AVAILABLE physical Controller overlaps.</div>${matching.length?`<div class="stock">Compatible AVAILABLE stock programmed here: ${matching.map(c=>`CTRL ${c.controller_id}`).join(', ')}</div>`:''}${!matching.length&&b.stock.length?`<div class="caution">AVAILABLE Controller programming overlaps: ${b.stock.map(c=>`CTRL ${c.controller_id} ${c.model_code}`).join(', ')}</div>`:''}</div>`;
    }).join('');
    const keys=new Set([...used.keys()]); pcs.forEach(c=>{for(let u=Number(c.lor_uid_start);u<=Number(c.lor_uid_end);u++)keys.add(u);});
    const rows=[...keys].sort((a,b)=>a-b).map(uid=>{
      const l=used.get(uid), at=pcs.filter(c=>uid>=Number(c.lor_uid_start)&&uid<=Number(c.lor_uid_end));
      return `<tr><td>${uidHex(uid)}</td><td>${l?(l.displays.size>1?'USED / SHARED':'USED'):'UNUSED BY LOR'}</td><td>${l?esc([...l.displays].join(', ')):'—'}</td><td>${at.length?at.map(c=>`CTRL ${c.controller_id} ${esc(c.model_code)} ${esc(c.controller_status_name)}`).join('<br>'):'—'}</td></tr>`;
    }).join('');
    target.innerHTML=`<div class="planner-note ${current?'':'planner-warning'}">${esc(note)}</div><div class="planner-summary"><div><span>Network</span><strong>${esc(network)}</strong></div><div><span>Model</span><strong>${esc(model.model_code)}</strong></div><div><span>Required UID Width</span><strong>${width}</strong></div></div><div class="planner-note">UID availability is scoped to this Network. The same UID on another Network is unrelated. Intentional shared addresses on this Network remain valid and are shown rather than rejected.</div><h3>Candidate contiguous blocks</h3><div class="planner-blocks">${blockHtml||'<div class="planner-empty">No candidate block of this width was found.</div>'}</div><h3 style="margin-top:14px">Current address evidence</h3><div class="planner-table-wrap"><table class="planner-table"><thead><tr><th>UID</th><th>LOR state</th><th>LOR Displays</th><th>Physical Controllers programmed here</th></tr></thead><tbody>${rows||'<tr><td colspan="4">No current usage resolved.</td></tr>'}</tbody></table></div>`;
  }

  async function openPlanner() {
    await loadReference();
    document.getElementById('controller-planner-dialog')?.remove();
    const dialog=document.createElement('dialog'); dialog.id='controller-planner-dialog'; dialog.className='planner-dialog';
    dialog.innerHTML=`<div class="planner-shell"><div class="planner-head"><div><h2>Controller Capacity Planner</h2><div class="muted">Probe before building the Display in LOR: Stage capacity first, then Network-specific UID capacity.</div></div><button type="button" id="planner-close">Close</button></div><div class="planner-body"><div class="planner-grid"><section class="planner-panel"><h3>1. Stage capacity</h3><div class="planner-controls"><label>Intended Stage / Sub-stage<select id="planner-stage">${stageOptions()}</select></label></div><div class="planner-note">Networks shown are <strong>currently used by this Stage</strong>. For a different Network, confirm physical reach on the existing map.</div><div id="planner-stage-networks" class="planner-network-row"></div><div id="planner-stage-results"></div></section><section class="planner-panel"><h3>2. Network / UID probe</h3><div class="planner-controls"><label>Network<select id="planner-network">${networkOptions()}</select></label><label>Controller Model<select id="planner-model">${modelOptions()}</select></label></div><div id="planner-network-results"></div></section></div></div></div>`;
    document.body.appendChild(dialog);
    document.getElementById('planner-close').onclick=()=>{dialog.close();dialog.remove();};
    document.getElementById('planner-stage').onchange=loadStage;
    document.getElementById('planner-network').onchange=renderNetwork;
    document.getElementById('planner-model').onchange=renderNetwork;
    dialog.showModal(); await loadStage(); renderNetwork();
  }

  async function install() {
    try {
      const access=(await api('api/controller-access')).access || null;
      if (!access?.can_manage_controllers) return;
      const button=document.createElement('button'); button.type='button'; button.className='planner-launch'; button.textContent='Plan Capacity';
      button.title='Probe Stage spare channels and Network UID capacity before building a Display';
      button.onclick=()=>openPlanner().catch(e=>window.alert(e.message));
      headerActions.insertBefore(button,document.getElementById('theme-toggle'));
    } catch (_) {}
  }
  install();
})();
