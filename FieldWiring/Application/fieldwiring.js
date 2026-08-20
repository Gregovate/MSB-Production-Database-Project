const displaySearch = document.getElementById('display-search');
const displayResults = document.getElementById('display-results');
const stageSelect = document.getElementById('stage-select');
const stageContexts = document.getElementById('stage-contexts');
const resolved = document.getElementById('resolved');
const resolvedGrid = document.getElementById('resolved-grid');
const technicalGrid = document.getElementById('technical-grid');
const openFieldWiring = document.getElementById('open-fieldwiring');
const clearResolved = document.getElementById('clear-resolved');
const resolvedStatus = document.getElementById('resolved-status');
const themeToggle = document.getElementById('theme-toggle');
const screenLogo = document.getElementById('screen-logo');

const THEME_KEY = 'fieldwiring-theme';
const LIGHT_LOGO = 'https://webassets.sheboyganlights.org/msb-blue-logo-600-plain.svg';
const DARK_LOGO = 'https://webassets.sheboyganlights.org/msb-white-logo-600-plain.svg';

let stages = [];
let timer = null;
let resolvedContext = null;

function storedTheme() {
  try {
    const value = localStorage.getItem(THEME_KEY);
    return value === 'light' || value === 'dark' ? value : null;
  } catch (_) {
    return null;
  }
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

async function api(url) {
  const response = await fetch(url, {headers:{'Accept':'application/json'}});
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
  return payload;
}

async function searchDisplays() {
  const q = displaySearch.value.trim();
  if (!q) {
    displayResults.innerHTML = '<div class="hint" style="padding:10px 4px">Start typing to search current Displays.</div>';
    return;
  }
  displayResults.innerHTML = '<div class="hint" style="padding:10px 4px">Searching…</div>';
  try {
    const payload = await api(`/api/displays?q=${encodeURIComponent(q)}`);
    const items = payload.displays || [];
    if (!items.length) {
      displayResults.innerHTML = '<div class="hint" style="padding:10px 4px">No current wiring Display match.</div>';
      return;
    }
    displayResults.innerHTML = items.map(d => `
      <div class="result" data-display-id="${esc(d.display_id)}">
        <strong>${esc(d.display_name)}</strong>
        <div class="result-meta">
          DISP:${esc(d.display_id)} · Stage ${esc(d.stage_key ?? '—')} ·
          ${esc(d.context_type ?? 'Wiring')} ·
          ${esc(d.scope_kind === 'Scene' ? d.scene_name : 'Whole Stage')}
        </div>
      </div>
    `).join('');
    displayResults.querySelectorAll('.result').forEach(node => {
      node.addEventListener('click', () => selectDisplay(Number(node.dataset.displayId)));
    });
  } catch (err) {
    displayResults.innerHTML = `<div class="hint" style="padding:10px 4px">${esc(err.message)}</div>`;
  }
}

async function selectDisplay(displayId) {
  try {
    const payload = await api(`/api/displays/${displayId}/context`);
    showResolved({...payload.context, source:'Display lookup'});
  } catch (err) {
    alert(err.message);
  }
}

function wiringHref(c) {
  if (!c || !c.stage_id || !c.preview_uuid) return null;
  const params = new URLSearchParams();
  if (c.display_id) params.set('display_id', c.display_id);
  params.set('stage_id', c.stage_id);
  params.set('preview_uuid', c.preview_uuid);
  if (c.scene_uuid) params.set('scene_uuid', c.scene_uuid);
  return '/wiring?' + params.toString();
}

function showResolved(c) {
  resolvedContext = c;
  resolved.hidden = false;
  const isScene = c.scope_kind === 'Scene' && c.scene_name && c.scene_name.toLowerCase() !== 'root';
  const rows = [];
  if (c.display_name) rows.push(['Display', c.display_name]);
  rows.push(
    ['Stage', `${c.stage_key ? c.stage_key + ' · ' : ''}${c.stage_name || 'Unresolved'}`],
    ['Scene / Area', isScene ? c.scene_name : 'Whole Stage'],
    ['Wiring', c.context_type || 'Unknown']
  );
  resolvedGrid.innerHTML = rows.map(([label,value]) => `
    <div class="resolved-row"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>
  `).join('');

  const technical = [];
  if (c.display_id) technical.push(['Display ID', `DISP:${c.display_id}`]);
  if (c.device_type) technical.push(['LOR Device Type', c.device_type]);
  if (c.preview_name) technical.push(['Source Preview', c.preview_name]);
  if (c.preview_uuid) technical.push(['Preview UUID', c.preview_uuid]);
  if (c.scene_uuid) technical.push(['Scene UUID', c.scene_uuid]);
  technicalGrid.innerHTML = technical.length ? technical.map(([label,value]) => `
    <div class="resolved-row"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>
  `).join('') : '<div class="hint">No additional technical details.</div>';

  const href = wiringHref(c);
  openFieldWiring.disabled = !href;
  resolvedStatus.textContent = href
    ? 'Current wiring context resolved. Open Field Wiring to view the field hookup package.'
    : 'This selection does not have enough current context to open Field Wiring.';
  resolved.scrollIntoView({behavior:'smooth', block:'start'});
}

async function loadStages() {
  try {
    const payload = await api('/api/stages');
    stages = payload.stages || [];
    stageSelect.innerHTML = '<option value="">Select a Stage…</option>' +
      stages.map(s => `<option value="${esc(s.stage_key)}">${esc(s.stage_key)} — ${esc(s.stage_name)}</option>`).join('');
  } catch (err) {
    stageSelect.innerHTML = `<option value="">${esc(err.message)}</option>`;
  }
}

function renderStageContexts() {
  const stage = stages.find(s => String(s.stage_key) === String(stageSelect.value));
  if (!stage) {
    stageContexts.innerHTML = '';
    return;
  }
  stageContexts.innerHTML = stage.contexts.map((c, i) => {
    const isScene = c.scope_kind === 'Scene' && c.scene_name && c.scene_name.toLowerCase() !== 'root';
    const label = isScene ? c.scene_name : 'Whole Stage';
    return `
      <div class="context-choice" data-context-index="${i}">
        <span class="context-badge">${esc(c.context_type)}</span>
        <span class="context-badge">${isScene ? 'Scene' : 'Stage'}</span>
        <strong>${esc(label)}</strong>
      </div>`;
  }).join('');
  stageContexts.querySelectorAll('.context-choice').forEach(node => {
    node.addEventListener('click', () => {
      const c = stage.contexts[Number(node.dataset.contextIndex)];
      showResolved({
        ...c,
        source:'Stage / Scene browse',
        stage_id:stage.stage_id,
        stage_key:stage.stage_key,
        stage_name:stage.stage_name,
        display_id:null,
        display_name:null,
        device_type:null
      });
    });
  });
}

displaySearch.addEventListener('input', () => {
  clearTimeout(timer);
  timer = setTimeout(searchDisplays, 180);
});
displaySearch.addEventListener('keydown', e => {
  if (e.key === 'Enter') {
    e.preventDefault();
    clearTimeout(timer);
    searchDisplays();
  }
});
stageSelect.addEventListener('change', renderStageContexts);
openFieldWiring.addEventListener('click', () => {
  const href = wiringHref(resolvedContext);
  if (href) window.location.assign(href);
});
clearResolved.addEventListener('click', () => {
  resolved.hidden = true;
  resolvedContext = null;
  openFieldWiring.disabled = true;
});

initTheme();
loadStages();
searchDisplays();
