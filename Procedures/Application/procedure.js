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
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}

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

function nodeStage(node) {
  return {
    stage_id: node?.stage_id ?? null,
    stage_key: node?.stage_key ?? null,
    stage_name: node?.label ?? node?.database_stage_name ?? 'Unnamed Stage'
  };
}

function stageLabel(stage) {
  if (!stage) return 'Unresolved';
  if (stage.label) return stage.label;
  const key = stage.stage_key ? `${stage.stage_key} · ` : '';
  return `${key}${stage.stage_name || 'Unnamed Stage'}`;
}

function sceneLabel(context) {
  const c = flattenContext(context);
  return c.scene_name && c.scene_name.toLowerCase() !== 'root' ? c.scene_name : 'Whole Stage';
}

function updateLocation() {
  const params = new URLSearchParams();
  params.set('task', state.task);
  if (state.entry?.type === 'display') params.set('display_id', state.entry.display_id);
  if (state.entry?.type === 'stage') {
    params.set('stage_id', state.entry.stage.stage_id);
    if (state.entry.whole_stage) params.set('whole_stage', 'true');
    if (state.entry.preview_uuid) params.set('preview_uuid', state.entry.preview_uuid);
    if (state.entry.scene_uuid) params.set('scene_uuid', state.entry.scene_uuid);
  }
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
    stageSelect.innerHTML = '<option value="">Select a Stage…</option>' +
      state.stages.map(stage => `<option value="${esc(stage.stage_id)}">${esc(stage.label)}</option>`).join('');
  } catch (err) {
    stageSelect.innerHTML = `<option value="">${esc(err.message)}</option>`;
  }
}

function contextRow(label, badge, meta, attrs) {
  return `<div class="context-choice" ${attrs}>
    <span class="context-badge">${esc(badge)}</span>
    <strong>${esc(label)}</strong>
    <div class="context-meta">${esc(meta)}</div>
  </div>`;
}

function renderStageContexts() {
  const stage = state.stages.find(row => String(row.stage_id) === String(stageSelect.value));
  if (!stage) {
    stageContexts.innerHTML = '';
    return;
  }

  const rows = [];
  rows.push(contextRow(stage.label, 'Stage', `Use the Stage-level ${state.task} procedure.`, 'data-owner="stage"'));

  (stage.scenes || []).forEach((scene, index) => {
    rows.push(contextRow(scene.label, 'Scene', `Use the Scene-level ${state.task} procedure.`, `data-stage-scene="${index}"`));
  });

  (stage.sub_stages || []).forEach((sub, subIndex) => {
    rows.push(contextRow(sub.label, 'Sub-stage', `Use the Sub-stage-level ${state.task} procedure.`, `data-substage="${subIndex}"`));
    (sub.scenes || []).forEach((scene, sceneIndex) => {
      rows.push(contextRow(scene.label, 'Scene', `Use the Scene-level ${state.task} procedure.`, `data-sub-scene="${subIndex}:${sceneIndex}"`));
    });
  });

  stageContexts.innerHTML = rows.join('');
  stageContexts.querySelector('[data-owner="stage"]')?.addEventListener('click', () => selectHierarchyOwner(stage));
  stageContexts.querySelectorAll('[data-stage-scene]').forEach(node => {
    node.addEventListener('click', () => selectHierarchyScene(stage, stage.scenes[Number(node.dataset.stageScene)]));
  });
  stageContexts.querySelectorAll('[data-substage]').forEach(node => {
    node.addEventListener('click', () => selectHierarchyOwner(stage.sub_stages[Number(node.dataset.substage)]));
  });
  stageContexts.querySelectorAll('[data-sub-scene]').forEach(node => {
    node.addEventListener('click', () => {
      const [subIndex, sceneIndex] = node.dataset.subScene.split(':').map(Number);
      const sub = stage.sub_stages[subIndex];
      selectHierarchyScene(sub, sub.scenes[sceneIndex]);
    });
  });
}

function selectHierarchyOwner(owner) {
  state.entry = {
    type: 'stage',
    stage: nodeStage(owner),
    whole_stage: true,
    preview_uuid: null,
    scene_uuid: null,
    scene_name: null
  };
  updateLocation();
  resolveCurrent();
}

function selectHierarchyScene(owner, scene) {
  const contexts = scene?.contexts || [];
  if (!contexts.length) {
    showProcedureError(`No current ${state.task} context is available for ${scene?.label || 'this Scene'}.`);
    return;
  }
  if (contexts.length === 1) {
    selectStageContext(owner, contexts[0]);
    return;
  }

  state.entry = {
    type: 'stage',
    stage: nodeStage(owner),
    whole_stage: false,
    preview_uuid: null,
    scene_uuid: null,
    scene_name: scene.label
  };
  renderDirectContextChoices(owner, scene, contexts);
}

function selectStageContext(owner, context) {
  const c = flattenContext(context);
  state.entry = {
    type: 'stage',
    stage: nodeStage(owner),
    whole_stage: false,
    preview_uuid: c.preview_uuid,
    scene_uuid: c.scene_uuid,
    scene_name: c.scene_name
  };
  updateLocation();
  resolveCurrent();
}

function renderDirectContextChoices(owner, scene, contexts) {
  contextChoices.innerHTML = contexts.map((context, index) => {
    const c = flattenContext(context);
    return contextRow(scene.label, 'Scene', c.preview_name || 'Current field context', `data-choice-index="${index}"`);
  }).join('');
  contextChoices.querySelectorAll('[data-choice-index]').forEach(node => {
    node.addEventListener('click', () => selectStageContext(owner, contexts[Number(node.dataset.choiceIndex)]));
  });
  contextChoiceCard.hidden = false;
  procedureCard.hidden = true;
}

function renderProcedureContext() {
  if (!state.entry) {
    procedureContext.textContent = '';
    return;
  }
  const parts = [];
  if (state.entry.type === 'display') parts.push(`${state.entry.display_name} · DISP:${state.entry.display_id}`);
  parts.push(stageLabel(state.entry.stage));
  parts.push(state.entry.whole_stage ? 'Whole Stage / Sub-stage' : (state.entry.scene_name || 'Current Scene'));
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
    return contextRow(sceneLabel(c), c.scope_kind === 'Scene' ? 'Scene' : 'Stage', c.preview_name || 'Current field context', `data-choice-index="${index}"`);
  }).join('');
  contextChoices.querySelectorAll('[data-choice-index]').forEach(node => {
    node.addEventListener('click', () => {
      const c = flattenContext(choices[Number(node.dataset.choiceIndex)]);
      state.entry.preview_uuid = c.preview_uuid;
      state.entry.scene_uuid = c.scene_uuid;
      state.entry.scene_name = c.scene_name;
      updateLocation();
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
  if (!state.entry.whole_stage && selected.scene_name) state.entry.scene_name = selected.scene_name;
  contextChoiceCard.hidden = true;
  procedureCard.hidden = false;
  procedureTitle.textContent = `${state.task} Instructions`;
  renderProcedureContext();
  scopeBadge.textContent = result.scope_type === 'SCENE' ? 'Scene / Area' :
    (result.scope_type === 'SUBSTAGE' ? 'Sub-stage' :
    (result.scope_type === 'STAGE' ? 'Stage' : result.scope_type || 'Unresolved'));

  const messages = {
    AVAILABLE: 'Current published instructions are available.',
    NO_CURRENT_DOCUMENTS: `No current ${state.task} PDF is published for this field context.`,
    TASK_UNAVAILABLE: `${state.task} is not currently published for this field context.`,
    PROCEDURES_UNAVAILABLE: 'The Procedure source is not currently available for this field context.',
    UNRESOLVED_SCOPE: 'The current Stage / Sub-stage / Scene scope could not be resolved safely.'
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

  const operatorWarnings = result.operator_warnings || [];
  warningList.innerHTML = operatorWarnings.map(warning => `<div class="warning">${esc(warning)}</div>`).join('');
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
