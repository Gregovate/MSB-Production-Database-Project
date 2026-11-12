const params = new URLSearchParams(location.search);
const loading = document.getElementById('loading');
const errorBox = document.getElementById('error');
const workspace = document.getElementById('workspace');
const operatorNotices = document.getElementById('operator-notices');
const imageSection = document.getElementById('image-section');
const imagePane = document.getElementById('image-pane');
const imageScroll = document.getElementById('image-scroll');
const wiringImage = document.getElementById('wiring-image');
const imageEmpty = document.getElementById('image-empty');
const imageEmptyDetail = document.getElementById('image-empty-detail');
const imageClassification = document.getElementById('image-classification');
const divider = document.getElementById('divider');
const contextSwitch = document.getElementById('context-switch');
const themeToggle = document.getElementById('theme-toggle');
const screenLogo = document.getElementById('screen-logo');

const THEME_KEY = 'fieldwiring-theme';
const LIGHT_LOGO = 'https://webassets.sheboyganlights.org/images/branding/msb-blue-logo-600-plain.svg';
const DARK_LOGO = 'https://webassets.sheboyganlights.org/images/branding/msb-white-logo-600-plain.svg';

let packageData = null;
let images = [];
let imageIndex = 0;
let zoom = 1;
let fitMode = 'width';
let imageVisible = window.matchMedia('(min-width: 801px)').matches;
let expandedImageBasis = '';

function storedTheme() {
  try {
    const value = localStorage.getItem(THEME_KEY);
    return value === 'light' || value === 'dark' ? value : null;
  } catch (_) { return null; }
}
function systemTheme() {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}
function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  if (themeToggle) themeToggle.textContent = theme === 'dark' ? 'Light mode' : 'Dark mode';
  if (screenLogo) screenLogo.src = theme === 'dark' ? DARK_LOGO : LIGHT_LOGO;
}
function initTheme() {
  applyTheme(storedTheme() || systemTheme());
  themeToggle?.addEventListener('click', () => {
    const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    try { localStorage.setItem(THEME_KEY, next); } catch (_) {}
    applyTheme(next);
  });
}

function esc(value) {
  return String(value ?? '')
    .replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;')
    .replaceAll('"','&quot;').replaceAll("'",'&#39;');
}
function fmt(value) { return value === null || value === undefined || value === '' ? '—' : String(value); }
function fmtDate(value) {
  if (!value) return 'Unknown';
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? String(value) : d.toLocaleString();
}
async function api(url) {
  const response = await fetch(url, {headers:{Accept:'application/json'}});
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
  return payload;
}
function requestedPackageUrl() {
  const q = new URLSearchParams();
  ['display_id','stage_id','preview_uuid','scene_uuid'].forEach(key => {
    const value = params.get(key);
    if (value) q.set(key, value);
  });
  return 'api/wiring?' + q.toString();
}
function stageContextPackageUrl(context) {
  const q = new URLSearchParams();
  q.set('stage_id', packageData.context.stage_id);
  q.set('preview_uuid', context.preview_uuid);
  if (context.scene_uuid) q.set('scene_uuid', context.scene_uuid);
  return 'api/wiring?' + q.toString();
}
function stageContextPageUrl(context) {
  return 'wiring.html?' + stageContextPackageUrl(context).split('?')[1];
}
function normalizedScopeRoot(value) {
  return String(value || '').replaceAll('\\','/').replace(/\/+$/,'').toLowerCase();
}
function contextRows(c) {
  const rows = [
    ['Stage ID', c.stage_id], ['Preview UUID', c.preview_uuid],
    ['Preview revision', c.preview_revision], ['Source Preview', c.preview_name],
    ['Source file', c.source_filename], ['Scene UUID', c.scene_uuid],
  ];
  if (c.display_id) rows.unshift(['Display ID', `DISP:${c.display_id}`]);
  return rows.filter(([,value]) => value !== null && value !== undefined && value !== '');
}
function renderContext() {
  const c = packageData.context;
  document.getElementById('trigger-wrap').hidden = !c.display_name;
  document.getElementById('trigger-display').textContent = c.display_name || '—';
  document.getElementById('stage-name').textContent = `${c.stage_key ? c.stage_key + ' · ' : ''}${c.stage_name || 'Unresolved'}`;
  const isScene = c.scope_kind === 'Scene' && c.scene_name && c.scene_name.toLowerCase() !== 'root';
  document.getElementById('scene-name').textContent = isScene ? c.scene_name : 'Whole Stage';
  document.getElementById('context-type').textContent = c.context_type || 'Unknown';
  document.getElementById('technical-context').innerHTML = contextRows(c).map(([label,value]) => `
    <div><span>${esc(label)}</span><strong>${esc(fmt(value))}</strong></div>`).join('');
}
function renderOperatorNotices() {
  const messages = packageData.images?.operator_warnings || [];
  operatorNotices.hidden = messages.length === 0;
  operatorNotices.innerHTML = messages.map(message => `<div>${esc(message)}</div>`).join('');
}
async function installContextSwitch() {
  contextSwitch.hidden = true;
  contextSwitch.innerHTML = '';
  if (params.get('display_id')) return;
  try {
    const payload = await api('api/stages');
    const stage = (payload.stages || []).find(s => Number(s.stage_id) === Number(packageData.context.stage_id));
    if (!stage) return;
    const backgrounds = stage.contexts.filter(c => c.context_type === 'Background / Static');
    const musicals = stage.contexts.filter(c => c.context_type === 'Musical');
    if (backgrounds.length !== 1 || musicals.length !== 1) return;
    const choices = [backgrounds[0], musicals[0]];
    const currentRoot = normalizedScopeRoot(packageData.images?.scope_root);
    if (!currentRoot) return;
    for (const choice of choices) {
      const isCurrent = choice.preview_uuid === packageData.context.preview_uuid &&
        String(choice.scene_uuid || '') === String(packageData.context.scene_uuid || '');
      if (isCurrent) continue;
      const candidate = await api(stageContextPackageUrl(choice));
      if (normalizedScopeRoot(candidate.wiring?.images?.scope_root) !== currentRoot) return;
    }
    contextSwitch.innerHTML = choices.map(choice => {
      const active = choice.context_type === packageData.context.context_type;
      return `<button type="button" class="${active ? 'active' : ''}" aria-pressed="${active ? 'true' : 'false'}">${esc(choice.context_type)}</button>`;
    }).join('');
    contextSwitch.hidden = false;
    contextSwitch.querySelectorAll('button').forEach((button, index) => {
      button.addEventListener('click', () => {
        const choice = choices[index];
        if (choice.context_type !== packageData.context.context_type) location.assign(stageContextPageUrl(choice));
      });
    });
  } catch (_) {
    contextSwitch.hidden = true;
    contextSwitch.innerHTML = '';
  }
}
function renderCurrentness() {
  const p = packageData.provenance;
  document.getElementById('generated-at').textContent = `Generated: ${fmtDate(p.generated_at)}`;
  document.getElementById('expires-at').textContent = `Expires: ${fmtDate(p.expires_at)}`;
  document.getElementById('snapshot-id').textContent = `Snapshot: ${p.import_run_id ? 'Run ' + p.import_run_id : 'Unknown'}`;
  document.getElementById('print-provenance').textContent = [
    `Generated ${fmtDate(p.generated_at)}`, `Expires ${fmtDate(p.expires_at)}`,
    p.import_run_id ? `LOR import run ${p.import_run_id}` : null,
    p.parser_version ? `Parser ${p.parser_version}` : null,
    p.ingest_script_version ? `Ingest ${p.ingest_script_version}` : null,
    'A newer approved wiring snapshot supersedes this copy immediately.'
  ].filter(Boolean).join(' · ');
}
function uniqueValues(rows, key) {
  return [...new Set(rows.map(row => String(row[key] ?? '').trim()).filter(Boolean))];
}
function groupTitle(group) {
  if (group.family === 'AC') {
    const uid = group.controller_uid_range || uniqueValues(group.rows, 'controller').join(', ') || '—';
    return `A/C CONTROLLER · UNIT ID ${uid}`;
  }
  if (group.family === 'PIXIE') {
    if (group.name === 'Pixie grouping review required') return 'PIXIE · GROUPING REVIEW REQUIRED';
    const model = group.controller_model || 'Pixie';
    return `${model.toUpperCase()} · ${group.name}`;
  }
  if (group.family === 'DUMBRGB') return `DMX / DUMBRGB · ${group.name}`;
  if (group.family === 'E131') return `E1.31 · ${group.name}`;
  if (group.family === 'DMX') return `DMX · ${group.name}`;
  return group.name || 'Other hookup';
}
function groupMetadata(group) {
  const networks = uniqueValues(group.rows, 'network');
  const items = [];
  if (group.family === 'PIXIE' && group.controller_uid_range) {
    items.push(['LOR Unit IDs', group.controller_uid_range]);
  }
  if (networks.length) items.push(['Network', networks.join(', ')]);
  if (group.family === 'E131') {
    items.push(['Controller', group.controller_model || 'Physical mapping pending']);
  }
  return items;
}
function physicalRows(group, triggerId) {
  const grouped = new Map();
  for (const row of group.rows) {
    const hasOutput = row.physical_output !== null && row.physical_output !== undefined;
    const knownContextWithoutOutput = row.controller_group_kind === 'reviewed-separate-controller-context';
    const key = hasOutput
      ? `output:${row.physical_output}`
      : `${knownContextWithoutOutput ? 'known' : 'review'}:${row.display_id ?? row.display_name}:${row.controller ?? ''}:${row.start_channel ?? ''}`;
    const label = hasOutput ? String(row.physical_output) : (knownContextWithoutOutput ? '—' : 'Review');
    if (!grouped.has(key)) grouped.set(key, {label, rows: []});
    grouped.get(key).rows.push(row);
  }

  return [...grouped.values()].map(entry => {
    const trigger = entry.rows.some(row => triggerId && Number(row.display_id) === triggerId);
    const displayLines = entry.rows.map(row => {
      const selected = triggerId && Number(row.display_id) === triggerId;
      return `<div class="connection-line ${selected ? 'selected-connection' : ''}">${esc(row.display_name)}</div>`;
    }).join('');
    const channelLines = entry.rows.map(row => {
      const selected = triggerId && Number(row.display_id) === triggerId;
      return `<div class="connection-line ${selected ? 'selected-connection' : ''}">${esc(row.channel_name || '—')}</div>`;
    }).join('');
    return `<tr class="${trigger ? 'trigger-row' : ''}">
      <td class="output-cell">${esc(entry.label)}</td>
      <td class="display-cell">${displayLines}</td>
      <td class="channel-cell">${channelLines}</td>
    </tr>`;
  }).join('');
}
function physicalTable(group, triggerId) {
  return `<table class="hookup-table physical-table">
    <thead><tr><th>Output / Plug</th><th>Display</th><th>Plug Label / Channel Name</th></tr></thead>
    <tbody>${physicalRows(group, triggerId)}</tbody>
  </table>`;
}
function simpleFamilyTable(group, triggerId) {
  if (group.family === 'DUMBRGB') {
    const display = group.rows[0]?.display_name || group.name;
    const network = uniqueValues(group.rows, 'network').join(', ') || '—';
    return `<table class="hookup-table simple-family-table"><thead><tr><th>Display / Fixture</th><th>Connection</th><th>Network</th></tr></thead>
      <tbody><tr><td>${esc(display)}</td><td>DMX network</td><td>${esc(network)}</td></tr></tbody></table>`;
  }
  if (group.family === 'E131') {
    const display = group.rows[0]?.display_name || group.name;
    return `<table class="hookup-table simple-family-table"><thead><tr><th>Display / Section</th><th>Connection</th><th>Physical Controller</th></tr></thead>
      <tbody><tr><td>${esc(display)}</td><td>E1.31</td><td>${esc(group.controller_model || 'Mapping pending')}</td></tr></tbody></table>`;
  }
  const rows = group.rows.map(row => {
    const trigger = triggerId && Number(row.display_id) === triggerId;
    return `<tr class="${trigger ? 'trigger-row' : ''}">
      <td>${esc(row.display_name)}</td><td>${esc(row.channel_name || '—')}</td><td>${esc(fmt(row.network))}</td><td>${esc(fmt(row.controller))}</td>
    </tr>`;
  }).join('');
  return `<table class="hookup-table simple-family-table"><thead><tr><th>Display</th><th>Channel Name</th><th>Network</th><th>Raw Address</th></tr></thead><tbody>${rows}</tbody></table>`;
}
function renderGroups() {
  const triggerId = Number(packageData.context.display_id || 0);
  const html = packageData.controller_groups.map(group => {
    const metadata = groupMetadata(group).map(([label,value]) => `
      <span class="controller-meta-item"><span class="controller-meta-label">${esc(label)}</span><strong class="controller-meta-value">${esc(value)}</strong></span>`).join('');
    const table = group.family === 'AC' || group.family === 'PIXIE'
      ? physicalTable(group, triggerId)
      : simpleFamilyTable(group, triggerId);
    return `<article class="controller-card ${group.family.toLowerCase()}-card">
      <div class="controller-head">
        <div class="controller-title"><strong>${esc(groupTitle(group))}</strong></div>
        <div class="controller-meta">${metadata}</div>
      </div>
      <div class="hookup-table-wrap">${table}</div>
    </article>`;
  }).join('');
  document.getElementById('controller-groups').innerHTML = html;
  document.getElementById('row-summary').textContent = `${packageData.rows.length} field hookup ${packageData.rows.length === 1 ? 'relationship' : 'relationships'} · ${packageData.controller_groups.length} physical/presentation ${packageData.controller_groups.length === 1 ? 'group' : 'groups'}`;
}
function renderEngineering() {
  document.getElementById('engineering-rows').innerHTML = packageData.rows.map(row => `<tr>
    <td>${esc(row.display_name)}</td><td>${esc(fmt(row.channel_name))}</td><td>${esc(fmt(row.network))}</td>
    <td>${esc(fmt(row.controller))}</td><td>${esc(fmt(row.start_channel))}</td><td>${esc(fmt(row.end_channel))}</td>
    <td>${esc(fmt(row.device_type))}</td><td>${esc(fmt(row.string_type))}</td><td>${esc(fmt(row.source))}</td><td>${esc(fmt(row.lor_tag))}</td>
  </tr>`).join('');
}
function allImages() {
  const wiring = packageData.images.wiring_images || [];
  if (wiring.length) return wiring.map(x => ({...x, contextOnly:false}));
  return (packageData.images.context_images || []).map(x => ({...x, contextOnly:true}));
}
function currentImage() { return images[imageIndex] || null; }
function updatePageControls() {
  document.getElementById('image-page').textContent = `Page ${images.length ? imageIndex + 1 : 0} / ${images.length}`;
  document.getElementById('image-prev').disabled = images.length < 2;
  document.getElementById('image-next').disabled = images.length < 2;
}
function applyImageScale() {
  if (!wiringImage.naturalWidth || !wiringImage.naturalHeight) return;
  let base = 1;
  if (fitMode === 'width') base = Math.max(.05, (imageScroll.clientWidth - 18) / wiringImage.naturalWidth);
  else if (fitMode === 'all') {
    const w = Math.max(.05, (imageScroll.clientWidth - 18) / wiringImage.naturalWidth);
    const h = Math.max(.05, (imageScroll.clientHeight - 18) / wiringImage.naturalHeight);
    base = Math.min(w, h);
  }
  const scale = Math.max(.05, Math.min(6, base * zoom));
  wiringImage.style.width = `${Math.round(wiringImage.naturalWidth * scale)}px`;
  wiringImage.style.height = `${Math.round(wiringImage.naturalHeight * scale)}px`;
  document.getElementById('zoom-value').textContent = `${Math.round(zoom * 100)}%`;
}
function showImage() {
  const item = currentImage();
  updatePageControls();
  if (!item) {
    wiringImage.hidden = true;
    imageScroll.hidden = true;
    imageClassification.hidden = true;
    imageEmpty.hidden = false;
    imageEmptyDetail.textContent = 'The hookup data remains current and usable without an image. See the notice above for the expected Wiring folder.';
    return;
  }
  imageEmpty.hidden = true;
  imageScroll.hidden = false;
  imageClassification.hidden = false;
  imageClassification.classList.toggle('context', Boolean(item.contextOnly));
  imageClassification.textContent = item.contextOnly ? 'NO WIRING IMAGE AVAILABLE · CONTEXT IMAGE — NOT WIRING' : 'WIRING IMAGE';
  wiringImage.hidden = false;
  wiringImage.alt = item.contextOnly ? `Context image, not wiring: ${item.name}` : `Wiring image: ${item.name}`;
  wiringImage.onload = applyImageScale;
  wiringImage.src = item.url;
}
function setImageVisible(value) {
  imageVisible = Boolean(value);
  imageSection.classList.toggle('image-open', imageVisible);
  const desktop = window.matchMedia('(min-width: 801px)').matches;
  if (desktop) {
    if (imageVisible) {
      imageSection.style.flexBasis = expandedImageBasis || '44%';
      imagePane.style.display = '';
      divider.style.display = '';
    } else {
      if (imageSection.style.flexBasis && imageSection.style.flexBasis !== 'auto') expandedImageBasis = imageSection.style.flexBasis;
      imageSection.style.flexBasis = 'auto';
      imagePane.style.display = 'none';
      divider.style.display = 'none';
    }
  } else {
    imageSection.style.flexBasis = '';
    imagePane.style.display = '';
    divider.style.display = '';
  }
  document.getElementById('image-toggle').textContent = imageVisible ? 'Hide Image' : 'Show Image';
  if (imageVisible) setTimeout(applyImageScale, 0);
}
function renderPrintImages() {
  const wiring = packageData.images.wiring_images || [];
  const context = packageData.images.context_images || [];
  const target = document.getElementById('print-images');
  if (wiring.length) {
    target.innerHTML = wiring.map((img, i) => `<div class="print-image-page"><h3>WIRING IMAGE ${i + 1} of ${wiring.length} — ${esc(img.name)}</h3><img src="${esc(img.url)}" alt="Wiring image ${i + 1}"></div>`).join('');
    return;
  }
  if (context.length) {
    target.innerHTML = context.map((img, i) => `<div class="print-image-page"><h3>NO WIRING IMAGE AVAILABLE</h3><p><strong>CONTEXT IMAGE — NOT WIRING</strong> · ${esc(img.name)}</p><img src="${esc(img.url)}" alt="Context image ${i + 1}, not wiring"></div>`).join('');
    return;
  }
  target.innerHTML = '<div class="print-image-page"><h3>Wiring Images</h3><strong>NO WIRING IMAGE AVAILABLE</strong></div>';
}
function renderImages() {
  images = allImages();
  imageIndex = 0;
  showImage();
  setImageVisible(imageVisible);
  renderPrintImages();
  if (!(packageData.images.wiring_images || []).length && (packageData.images.context_images || []).length) {
    imageEmptyDetail.textContent = 'No wiring image exists in this scope. A same-scope PreviewBackground image exists as context only and is not being presented as wiring.';
  }
}
function installControls() {
  document.getElementById('print-button').addEventListener('click', () => window.print());
  document.getElementById('image-toggle').addEventListener('click', () => setImageVisible(!imageVisible));
  document.getElementById('image-prev').addEventListener('click', () => { if (images.length) { imageIndex = (imageIndex - 1 + images.length) % images.length; zoom = 1; showImage(); } });
  document.getElementById('image-next').addEventListener('click', () => { if (images.length) { imageIndex = (imageIndex + 1) % images.length; zoom = 1; showImage(); } });
  document.getElementById('fit-width').addEventListener('click', () => { fitMode='width'; zoom=1; applyImageScale(); });
  document.getElementById('fit-all').addEventListener('click', () => { fitMode='all'; zoom=1; applyImageScale(); });
  document.getElementById('zoom-in').addEventListener('click', () => { zoom=Math.min(4, zoom*1.2); applyImageScale(); });
  document.getElementById('zoom-out').addEventListener('click', () => { zoom=Math.max(.25, zoom/1.2); applyImageScale(); });
  window.addEventListener('resize', () => {
    setImageVisible(imageVisible);
    if (imageVisible) applyImageScale();
  });

  let dragging = false;
  divider.addEventListener('pointerdown', e => { dragging=true; divider.setPointerCapture(e.pointerId); e.preventDefault(); });
  divider.addEventListener('pointermove', e => {
    if (!dragging) return;
    const area = imageSection.parentElement.getBoundingClientRect();
    const min = 160;
    const max = Math.max(min, area.height - 220);
    const px = Math.max(min, Math.min(max, e.clientY - area.top));
    expandedImageBasis = `${px}px`;
    imageSection.style.flexBasis = expandedImageBasis;
    if (imageVisible) applyImageScale();
  });
  divider.addEventListener('pointerup', () => { dragging=false; });
  divider.addEventListener('pointercancel', () => { dragging=false; });
}
async function start() {
  initTheme();
  try {
    const payload = await api(requestedPackageUrl());
    packageData = payload.wiring;
    renderContext();
    renderOperatorNotices();
    renderCurrentness();
    renderGroups();
    renderEngineering();
    renderImages();
    installControls();
    loading.hidden = true;
    workspace.hidden = false;
    await installContextSwitch();
  } catch (err) {
    loading.hidden = true;
    errorBox.hidden = false;
    errorBox.innerHTML = `<strong>Field Wiring could not be opened.</strong><div>${esc(err.message)}</div><div style="margin-top:10px"><a class="button" href="./">Return to lookup</a></div>`;
  }
}
start();
