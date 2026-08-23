const taskButtons = [...document.querySelectorAll('.task-button')];
const displaySearch = document.getElementById('display-search');
const displayResults = document.getElementById('display-results');
const stageSelect = document.getElementById('stage-select');
const stageContexts = document.getElementById('stage-contexts');
const clearSelection = document.getElementById('clear-selection');
const contextChoiceCard = document.getElementById('context-choice-card');
const contextChoices = document.getElementById('context-choices');
const procedureCard = document.getElementById('procedure-card');
const procedureTitle = document.getElementById('procedure-title');
const procedureContext = document.getElementById('procedure-context');
const procedureMessage = document.getElementById('procedure-message');
const documentList = document.getElementById('document-list');
const imageList = document.getElementById('image-list');
const warningList = document.getElementById('warning-list');
const scopeBadge = document.getElementById('scope-badge');
const themeToggle = document.getElementById('theme-toggle');
const screenLogo = document.getElementById('screen-logo');

const THEME_KEY = 'msb-procedure-theme';
const LIGHT_LOGO = 'https://webassets.sheboyganlights.org/images/branding/msb-blue-logo-600-plain.svg';
const DARK_LOGO = 'https://webassets.sheboyganlights.org/images/branding/msb-white-logo-600-plain.svg';
const TASKS = ['Setup', 'Takedown', 'Inspection'];

const state = {
  task: 'Setup',
  entry: null,
  stages: [],
  timer: null
};

function esc(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

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

async function api(url) {
  const response = await fetch(url, {headers:{'Accept':'application/json'}});
  const text = await response.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : {};
  } catch (_) {
    throw new Error(response.ok ? 'Procedure server returned an unexpected response.' : `Procedure server error (${response.status})`);
  }
  if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
  return payload;
}

function normalizeTask(value) {
  const match = TASKS.find(task => task.toLowerCase() === String(value || '').toLowerCase());
  return match || 'Setup';
}

function setTask(task, resolve = true) {
  state.task = normalizeTask(task);
  taskButtons.forEach(button => button.classList.toggle('active', button.dataset.task === state.task));
  if (stageSelect.value) renderStageContexts();
  updateLocation();
  if (resolve && state.entry) resolveCurrent();
}

function flattenContext(context) {
  const preview = context?.preview || {};
  const scene = context?.scene || {};
  return {
    preview_uuid: context?.preview_uuid ?? preview.preview_uuid ?? null,
    preview_name: context?.preview_name ?? preview.preview_name ?? null,
    scene_uuid: context?.scene_uuid ?? scene.scene_uuid ?? null,
    scene_name: context?.scene_name ?? scene.scene_name ?? null,
    scope_kind: context?.scope_kind ?? null,
    context_type: context?.context_type ?? null
  };
}

function sceneLabel(context) {
  const c = flattenContext(context);
  if (c.scene_name && c.scene_name.toLowerCase() !== 'root') return c.scene_name;
  return 'Whole Stage';
}

function stageLabel(stage) {
  if (!stage) return 'Unresolved';
  if (stage.label) return stage.label;
  const key = stage.stage_key ? `${stage.stage_key} · ` : '';
  return `${key}${stage.stage_name || 'Unnamed Stage'}`;
}

function updateLocation() {
  const params = new URLSearchParams();
  params.set('task', state.task);
  if (state.entry?.type === 'display') params.set('display_id', state.entry.display_id);
  if (state.entry?.type === 'stage') params.set('stage_id', state.entry.stage.stage_id);
  const query = params.toString();
  try { history.replaceState(null, '', query ? `?${query}` : location.pathname); } catch (_) {}
}

async function searchDisplays() {
  const q = displaySearch.value.trim();
  if (!q) {
    displayResults.innerHTML = '<div class="hint" style="padding:10px 4px">Start typing to search current inventory Displays.</div>';
    return;
  }
  displayResults.innerHTML = '<div class="hint" style="padding:10px 4px">Searching…</div>';
  try {
    const payload = await api(`api/displays?q=${encodeURIComponent(q)}`);
    const items = payload.displays || [];
    if (!items.length) {
      displayResults.innerHTML = '<div class="hint" style="padding:10px 4px">No current Display match.</div>';
      return;
    }
    displayResults.innerHTML = items.map(item => `
      <div class="result" data-display-id="${esc(item.display_id)}">
        <strong>${esc(item.display_name)}</strong>
        <div class="result-meta">DISP:${esc(item.display_id)} · ${esc(stageLabel(item.stage))}</div>
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
    const payload = await api(`api/displays/${displayId}/context`);
    const context = payload.context;
    state.entry = {
      type: 'display',
      display_id: context.display_id,
      display_name: context.display_name,
      stage: context.stage,
      preview_uuid: null,
      scene_uuid: null,
      scene_name: null
    };
    updateLocation();
    await resolveCurrent();
  } catch (err) {
    showProcedureError(err.message);
  }
}

async function loadStages() {
  try {
    const payload = await api('api/stages');
    state.stages = payload.stages || [];
    stageSelect.innerHTML = '<option value="">Select a Stage…</option>' + state.stages.map(stage =>
      `<option value="${esc(stage.stage_id)}">${esc(stage.label || `Stage ${stage.stage_key || ''}`)}</option>`
    ).join('');
  } catch (err) {
    stageSelect.innerHTML = `<option value="">${esc(err.message)}</option>`;
  }
}

function hierarchySceneContext(scene) {
  const contexts = scene?.contexts || [];
  return contexts.length ? flattenContext(contexts[0]) : null;
}

function renderStageContexts() {
  const stage = state.stages.find(row => String(row.stage_id) === String(stageSelect.value));
  if (!stage) {
    stageContexts.innerHTML = '';
    return;
  }

  const rows = [
    `<div class="context-choice" data-stage-root="true"><span class="context-badge">Stage</span><strong>Whole Stage</strong><div class="context-meta">${esc(stage.label)} · Use the Stage-level ${esc(state.task)} procedure.</div></div>`
  ];

  (stage.scenes || []).forEach((scene, index) => {
    rows.push(`
      <div class="context-choice" data-stage-scene-index="${index}">
        <span class="context-badge">Scene</span>
        <strong>${esc(scene.label)}</strong>
        <div class="context-meta">Use the defined Scene-level ${esc(state.task)} procedure.</div>
      </div>`);
  });

  (stage.sub_stages || []).forEach((subStage, subIndex) => {
    rows.push(`
      <div class="context-choice" data-substage-index="${subIndex}">
        <span class="context-badge">Sub-stage</span>
        <strong>${esc(subStage.label)}</strong>
        <div class="context-meta">Use the Sub-stage-level ${esc(state.task)} procedure.</div>
      </div>`);
    (subStage.scenes || []).forEach((scene, sceneIndex) => {
      rows.push(`
        <div class="context-choice" data-substage-scene="${subIndex}:${sceneIndex}">
          <span class="context-badge">Scene</span>
          <strong>${esc(scene.label)}</strong>
          <div class="context-meta">Under ${esc(subStage.label)}.</div>
        </div>`);
    });
  });

  stageContexts.innerHTML = rows.join('');
  stageContexts.querySelector('[data-stage-root="true"]')?.addEventListener('click', () => selectHierarchyScope(stage));
  stageContexts.querySelectorAll('[data-stage-scene-index]').forEach(node => {
    const scene = stage.scenes[Number(node.dataset.stageSceneIndex)];
    node.addEventListener('click', () => selectHierarchyScope(stage, scene));
  });
  stageContexts.querySelectorAll('[data-substage-index]').forEach(node => {
    const subStage = stage.sub_stages[Number(node.dataset.substageIndex)];
    node.addEventListener('click', () => selectHierarchyScope(subStage));
  });
  stageContexts.querySelectorAll('[data-substage-scene]').forEach(node => {
    const [subIndex, sceneIndex] = node.dataset.substageScene.split(':').map(Number);
    const subStage = stage.sub_stages[subIndex];
    const scene = subStage.scenes[sceneIndex];
    node.addEventListener('click', () => selectHierarchyScope(subStage, scene));
  });
}

function selectHierarchyScope(scope, scene = null) {
  const context = scene ? hierarchySceneContext(scene) : null;
  if (scene && !context) {
    showProcedureError('The selected Scene has no current field-context evidence.');
    return;
  }
  state.entry = {
    type: 'stage',
    stage: scope,
    whole_stage: !scene,
    preview_uuid: context?.preview_uuid || null,
    scene_uuid: context?.scene_uuid || null,
    scene_name: scene?.label || null
  };
  updateLocation();
  resolveCurrent();
}

function renderProcedureContext() {
  if (!state.entry) {
    procedureContext.textContent = '';
    return;
  }
  const parts = [];
  if (state.entry.type === 'display') {
    parts.push(`${state.entry.display_name} · DISP:${state.entry.display_id}`);
  }
  parts.push(stageLabel(state.entry.stage));
  parts.push(state.entry.whole_stage ? 'Whole Stage' : (state.entry.scene_name || 'Current Stage / Scene context'));
  procedureContext.textContent = parts.join(' · ');
}

function clearProcedureContents() {
  documentList.innerHTML = '';
  imageList.innerHTML = '';
  warningList.innerHTML = '';
  scopeBadge.textContent = '';
}

function showProcedureError(message) {
  contextChoiceCard.hidden = true;
  procedureCard.hidden = false;
  procedureTitle.textContent = `${state.task} Instructions`;
  renderProcedureContext();
  procedureMessage.textContent = message;
  clearProcedureContents();
}

function procedureParams(name = null) {
  const params = new URLSearchParams();
  params.set('task', state.task);
  if (state.entry.type === 'display') {
    params.set('display_id', state.entry.display_id);
  } else {
    params.set('stage_id', state.entry.stage.stage_id);
    if (state.entry.whole_stage) params.set('whole_stage', 'true');
  }
  if (state.entry.preview_uuid) params.set('preview_uuid', state.entry.preview_uuid);
  if (state.entry.scene_uuid) params.set('scene_uuid', state.entry.scene_uuid);
  if (name !== null) params.set('name', name);
  return params;
}

function assetHref(kind, name) {
  return `api/procedure/${kind}?${procedureParams(name).toString()}`;
}

function formatBytes(value) {
  const size = Number(value || 0);
  if (!Number.isFinite(size) || size <= 0) return '';
  if (size < 1024) return `${size} bytes`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
}

async function resolveCurrent() {
  if (!state.entry) return;
  contextChoiceCard.hidden = true;
  procedureCard.hidden = false;
  procedureTitle.textContent = `${state.task} Instructions`;
  renderProcedureContext();
  procedureMessage.textContent = `Resolving current ${state.task} instructions…`;
  clearProcedureContents();
  try {
    const payload = await api(`api/procedures?${procedureParams().toString()}`);
    renderProcedure(payload.procedure);
  } catch (err) {
    showProcedureError(err.message);
  }
}

function renderContextChoices(result) {
  const choices = result.contexts || [];
  contextChoices.innerHTML = choices.map((context, index) => {
    const c = flattenContext(context);
    return `
      <div class="context-choice" data-choice-index="${index}">
        <span class="context-badge">${esc(c.scope_kind === 'Scene' ? 'Scene' : 'Stage')}</span>
        <strong>${esc(sceneLabel(c))}</strong>
        <div class="context-meta">${esc(c.preview_name || 'Current field context')}</div>
      </div>`;
  }).join('');
  contextChoices.querySelectorAll('[data-choice-index]').forEach(node => {
    node.addEventListener('click', () => {
      const c = flattenContext(choices[Number(node.dataset.choiceIndex)]);
      state.entry.preview_uuid = c.preview_uuid;
      state.entry.scene_uuid = c.scene_uuid;
      state.entry.scene_name = c.scene_name;
      resolveCurrent();
    });
  });
  contextChoiceCard.hidden = false;
  procedureCard.hidden = true;
}

function renderProcedure(result) {
  if (result.status === 'CONTEXT_SELECTION_REQUIRED') {
    renderContextChoices(result);
    return;
  }

  const selected = flattenContext(result.selected_context || {});
  if (!state.entry.scene_name && selected.scene_name) state.entry.scene_name = selected.scene_name;
  contextChoiceCard.hidden = true;
  procedureCard.hidden = false;
  procedureTitle.textContent = `${state.task} Instructions`;
  renderProcedureContext();
  if (result.scope_type === 'SCENE') {
    scopeBadge.textContent = 'Scene / Area';
  } else if (state.entry.type === 'stage' && state.entry.stage.scope_type === 'SUBSTAGE') {
    scopeBadge.textContent = 'Sub-stage';
  } else {
    scopeBadge.textContent = result.scope_type === 'STAGE' ? 'Stage' : result.scope_type || 'Unresolved';
  }

  const messages = {
    AVAILABLE: 'Current published instructions are available.',
    NO_CURRENT_DOCUMENTS: `No current ${state.task} PDF is published for this field context.`,
    TASK_UNAVAILABLE: `${state.task} is not currently published for this field context.`,
    PROCEDURES_UNAVAILABLE: 'The Procedure source is not currently available for this field context.',
    UNRESOLVED_SCOPE: 'The current Stage / Scene filesystem scope could not be resolved safely.'
  };
  procedureMessage.textContent = messages[result.status] || result.status || 'Procedure status unavailable.';

  const documents = result.documents || [];
  documentList.innerHTML = documents.map(document => `
    <a class="document-link" href="${esc(assetHref('document', document.name))}" target="_blank" rel="noopener">
      <strong>${esc(document.name)}</strong>
      <span class="document-size">${esc(formatBytes(document.size))}</span>
    </a>
  `).join('');

  const images = result.images || [];
  imageList.innerHTML = images.map(image => `
    <div class="image-card">
      <a href="${esc(assetHref('image', image.name))}" target="_blank" rel="noopener">
        <img src="${esc(assetHref('image', image.name))}" alt="${esc(image.name)}" loading="lazy">
      </a>
      <div>${esc(image.name)}</div>
    </div>
  `).join('');

  const warnings = result.warnings || [];
  warningList.innerHTML = warnings.map(warning => `<div class="warning">${esc(warning)}</div>`).join('');
}

function clearCurrentSelection() {
  state.entry = null;
  contextChoiceCard.hidden = true;
  procedureCard.hidden = true;
  stageSelect.value = '';
  stageContexts.innerHTML = '';
  updateLocation();
}

async function initDeepLink() {
  const params = new URLSearchParams(location.search);
  setTask(params.get('task') || 'Setup', false);
  const displayId = params.get('display_id');
  if (displayId && /^\d+$/.test(displayId)) {
    await selectDisplay(Number(displayId));
  }
}

taskButtons.forEach(button => button.addEventListener('click', () => setTask(button.dataset.task)));
displaySearch.addEventListener('input', () => {
  clearTimeout(state.timer);
  state.timer = setTimeout(searchDisplays, 180);
});
displaySearch.addEventListener('keydown', event => {
  if (event.key === 'Enter') {
    event.preventDefault();
    clearTimeout(state.timer);
    searchDisplays();
  }
});
stageSelect.addEventListener('change', renderStageContexts);
clearSelection.addEventListener('click', clearCurrentSelection);

initTheme();
loadStages();
searchDisplays();
initDeepLink();