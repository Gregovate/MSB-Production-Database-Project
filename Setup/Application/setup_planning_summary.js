(() => {
  'use strict';

  const state = {
    access: null,
    stages: [],
    scenes: [],
    summary: null,
  };

  const qs = (id) => document.getElementById(id);

  function planningSummaryUrl(scope = null, stageId = null, sceneId = null) {
    const url = new URL('planning-summary/', window.location.href);
    if (scope) url.searchParams.set('scope', scope);
    if (stageId != null) url.searchParams.set('stage_id', String(stageId));
    if (sceneId != null) url.searchParams.set('lor_scene_id', String(sceneId));
    return url;
  }

  function openPlanningSummary(scope = null, stageId = null, sceneId = null) {
    window.open(planningSummaryUrl(scope, stageId, sceneId).toString(), '_blank', 'noopener');
  }

  function catalogPrintButton(label, scope, stageId = null, sceneId = null) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'small secondary planning-summary-catalog-print';
    button.textContent = label;
    button.style.marginLeft = 'auto';
    button.style.whiteSpace = 'nowrap';
    button.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      openPlanningSummary(scope, stageId, sceneId);
    });
    return button;
  }

  function decorateCatalogPrintLaunchers() {
    const library = document.getElementById('library-view');
    if (!library) return;

    if (!document.getElementById('planning-summary-launch')) {
      const tools = library.querySelector('.next-library-tools');
      const header = library.querySelector('.section-title');
      if (tools || header) {
        const button = document.createElement('button');
        button.id = 'planning-summary-launch';
        button.type = 'button';
        button.className = 'secondary';
        button.textContent = 'Print Planning Summary…';
        button.addEventListener('click', () => openPlanningSummary());
        (tools || header).append(button);
      }
    }

    library.querySelectorAll('.next-stage-group:not(.next-sitewide-group)').forEach((group) => {
      const stageId = String(group.dataset.stageId || '').trim();
      const summary = group.firstElementChild;
      if (!stageId || !summary || summary.querySelector('.planning-summary-stage-print')) return;
      const button = catalogPrintButton('Print Stage', 'stage', stageId);
      button.classList.add('planning-summary-stage-print');
      const count = summary.querySelector('.next-count');
      if (count) {
        count.style.marginLeft = '0';
        count.before(button);
      } else {
        summary.append(button);
      }
    });

    library.querySelectorAll('.next-scope-group').forEach((group) => {
      const stageId = String(group.dataset.stageId || '').trim();
      const sceneId = String(group.dataset.sceneId || '').trim();
      const summary = group.firstElementChild;
      if (!stageId || !sceneId || !summary || summary.querySelector('.planning-summary-scene-print')) return;
      summary.style.display = 'flex';
      summary.style.alignItems = 'center';
      summary.style.gap = '0.5rem';
      const button = catalogPrintButton('Print Scene', 'scene', stageId, sceneId);
      button.classList.add('planning-summary-scene-print');
      const count = summary.querySelector('.next-count');
      if (count) {
        count.style.marginLeft = '0';
        count.before(button);
      } else {
        summary.append(button);
      }
    });
  }

  function installCatalogPrintLaunchers() {
    const list = document.getElementById('library-list');
    if (!list) return;
    decorateCatalogPrintLaunchers();
    const observer = new MutationObserver(() => decorateCatalogPrintLaunchers());
    observer.observe(list, { childList: true, subtree: true });
  }

  if (!qs('scope-select') || !qs('summary-root')) {
    installCatalogPrintLaunchers();
    return;
  }

  function escapeHtml(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  async function api(path) {
    const response = await fetch(path, { credentials: 'same-origin', cache: 'no-store' });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error || `Request failed (${response.status})`);
    }
    return payload;
  }

  function setStatus(message, error = false) {
    const node = qs('status');
    node.textContent = message;
    node.classList.toggle('error', error);
  }

  function option(value, label) {
    const node = document.createElement('option');
    node.value = String(value);
    node.textContent = label;
    return node;
  }

  function stageLabel(stage) {
    const key = String(stage.stage_key || '').trim();
    const name = String(stage.stage_name || '').trim();
    return key && name ? `${key} — ${name}` : (key || name || `Stage ${stage.stage_id}`);
  }

  function refreshStageOptions() {
    const select = qs('stage-select');
    const previous = select.value;
    select.replaceChildren();
    for (const stage of state.stages) {
      select.append(option(stage.stage_id, stageLabel(stage)));
    }
    if (previous && [...select.options].some((item) => item.value === previous)) {
      select.value = previous;
    }
    refreshSceneOptions();
  }

  function refreshSceneOptions() {
    const select = qs('scene-select');
    const stageId = Number(qs('stage-select').value || 0);
    const previous = select.value;
    select.replaceChildren();
    const scenes = state.scenes.filter((scene) => Number(scene.stage_id) === stageId);
    for (const scene of scenes) {
      select.append(option(scene.lor_scene_id, scene.scene_name || `Scene ${scene.lor_scene_id}`));
    }
    if (previous && [...select.options].some((item) => item.value === previous)) {
      select.value = previous;
    }
    qs('scene-control').hidden = qs('scope-select').value !== 'scene';
  }

  function refreshScopeControls() {
    const scope = qs('scope-select').value;
    qs('stage-control').hidden = scope === 'all';
    qs('scene-control').hidden = scope !== 'scene';
    if (scope === 'scene') refreshSceneOptions();
  }

  function resourceText(rows) {
    return (rows || []).map((row) => {
      const bits = [row.resource_name];
      if (row.quantity_required != null) bits.push(`x${row.quantity_required}`);
      if (row.requirement_type && row.requirement_type !== 'REQUIRED') bits.push(row.requirement_type);
      if (row.notes) bits.push(row.notes);
      return bits.filter(Boolean).join(' · ');
    }).join('; ');
  }

  function supportContainerText(rows) {
    return (rows || []).map((row) => {
      const name = row.container_description || `Container ${row.container_id}`;
      const rel = row.relationship_type || 'SUPPORT';
      return `${name} [${rel}]`;
    }).join('; ');
  }

  function extraMaterialText(rows) {
    return (rows || []).map((row) => {
      const bits = [row.material_name];
      if (row.quantity_text) bits.push(row.quantity_text);
      if (row.spec_text) bits.push(row.spec_text);
      if (row.verification_state && row.verification_state !== 'VERIFIED') bits.push(row.verification_state);
      if (row.sources?.length) {
        const sources = row.sources.map((source) => {
          const label = source.container_description || `Container ${source.container_id}`;
          const qty = source.expected_quantity != null ? ` x${source.expected_quantity}` : '';
          const verify = source.verification_state && source.verification_state !== 'VERIFIED'
            ? ` ${source.verification_state}`
            : '';
          return `${label}${qty}${verify}`;
        });
        bits.push(`source: ${sources.join(', ')}`);
      }
      if (row.notes) bits.push(row.notes);
      return bits.filter(Boolean).join(' · ');
    }).join('; ');
  }

  function displayMaterialText(material) {
    if (!material?.requires_display_material) return 'Not a Display-material step';
    const bits = [`${material.display_count || 0} Display(s)`];
    if (material.container_count != null) bits.push(`${material.container_count} Container(s)`);
    if (material.containers?.length) {
      bits.push(material.containers.map((row) => row.container_description || `Container ${row.container_id}`).join(', '));
    }
    if (material.uncontained_display_count) bits.push(`${material.uncontained_display_count} uncontained`);
    if (material.ownership_status && material.ownership_status !== 'COMPLETE') {
      bits.push(`ownership ${material.ownership_status}`);
    }
    return bits.join(' · ');
  }

  function procedureHtml(task) {
    const procedure = task.procedure || {};
    const docs = procedure.documents || [];
    if (!docs.length) {
      return escapeHtml(procedure.status || 'No current published PDF');
    }
    return docs.map((doc) => {
      const name = String(doc.name || '').trim();
      if (!name) return '';
      const href = `../api/setup/tasks/${encodeURIComponent(task.setup_task_id)}/procedure/current?name=${encodeURIComponent(name)}`;
      return `<a href="${href}" target="_blank" rel="noopener">${escapeHtml(name)}</a>`;
    }).filter(Boolean).join(', ');
  }

  function indicatorText(rows) {
    return (rows || []).map((row) => {
      const detail = row.detail ? ` — ${row.detail}` : '';
      return `${row.state}: ${row.source}${detail}`;
    }).join('; ');
  }

  function optionalLine(label, value, { html = false } = {}) {
    if (value == null || String(value).trim() === '') return '';
    return `<div class="compact-line"><strong>${escapeHtml(label)}:</strong> ${html ? value : escapeHtml(value)}</div>`;
  }

  function taskById(taskId) {
    return (state.summary?.tasks || []).find((task) => Number(task.setup_task_id) === Number(taskId)) || null;
  }

  function sameScope(left, right) {
    if (!left || !right) return false;
    const leftStage = left.stage_id == null ? null : Number(left.stage_id);
    const rightStage = right.stage_id == null ? null : Number(right.stage_id);
    const leftScene = left.lor_scene_id == null ? null : Number(left.lor_scene_id);
    const rightScene = right.lor_scene_id == null ? null : Number(right.lor_scene_id);
    return leftStage === rightStage && leftScene === rightScene;
  }

  function shortScopeLabel(task) {
    if (!task || task.stage_id == null) return 'Site-wide';
    if (task.lor_scene_id == null) return 'Stage / General';
    return `Scene — ${task.scene_name || task.lor_scene_id}`;
  }

  function crewText(task) {
    const min = task.normal_crew_min;
    const max = task.normal_crew_max;
    if (min == null || max == null) return null;
    return Number(min) === Number(max) ? String(min) : `${min}–${max}`;
  }

  function durationText(task) {
    if (task.expected_duration_minutes == null) return null;
    const totalMinutes = Number(task.expected_duration_minutes);
    if (!Number.isInteger(totalMinutes) || totalMinutes < 1) return `${task.expected_duration_minutes} min`;
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (!hours) return `${minutes} min`;
    return minutes ? `${hours} hr ${minutes} min` : `${hours} hr`;
  }

  function predecessorHtml(task) {
    const rows = task.dependencies || [];
    if (!rows.length) {
      return '<span class="review-value">REVIEW — none recorded; confirm none required</span>';
    }
    return rows.map((row) => {
      const predecessor = taskById(row.prerequisite_setup_task_id);
      const scope = predecessor && !sameScope(task, predecessor) ? `${shortScopeLabel(predecessor)} · ` : '';
      const step = predecessor?.display_order != null ? `Step ${predecessor.display_order} — ` : '';
      const note = row.dependency_note ? ` — ${row.dependency_note}` : '';
      return escapeHtml(`${scope}${step}${row.task_name}${note}`);
    }).join('; ');
  }

  function hasUnverifiedPickListFacts(task) {
    const rows = [...(task.extra_materials || []), ...(task.tpost_requirements || [])];
    return rows.some((row) => {
      if (row.verification_state && row.verification_state !== 'VERIFIED') return true;
      return (row.sources || []).some((source) => source.verification_state && source.verification_state !== 'VERIFIED');
    });
  }

  function schedulerReviewItems(task) {
    const items = [];
    if (task.display_order == null) items.push('Step order is missing.');
    if (!crewText(task)) items.push('Crew size is missing or incomplete.');
    if (!durationText(task)) items.push('Estimated setup time is missing.');
    if (!(task.dependencies || []).length) {
      items.push('Hard predecessor review is incomplete: none recorded; confirm that none is required.');
    }

    const currentStep = task.display_order == null ? null : Number(task.display_order);
    if (currentStep != null) {
      for (const dependency of task.dependencies || []) {
        const predecessor = taskById(dependency.prerequisite_setup_task_id);
        if (!predecessor || !sameScope(task, predecessor) || predecessor.display_order == null) continue;
        if (Number(predecessor.display_order) >= currentStep) {
          items.push(`Step order review: required predecessor Step ${predecessor.display_order} is not before Step ${currentStep}.`);
        }
      }
    }

    const material = task.display_material || {};
    if (material.requires_display_material) {
      if (!material.display_count) items.push('Material step has no resolved Displays.');
      if (material.ownership_status && material.ownership_status !== 'COMPLETE') {
        items.push(`Material ownership/resolution needs review (${material.ownership_status}).`);
      }
    }
    if (hasUnverifiedPickListFacts(task)) {
      items.push('Extra Material / T-Post quantity or source data still needs verification for Pick List use.');
    }
    return items;
  }

  function schedulerStrip(task) {
    const crew = crewText(task);
    const duration = durationText(task);
    const effort = task.effort_level || 'Not reviewed';
    return `
      <div class="scheduler-strip">
        <span><strong>Crew:</strong> <span class="${crew ? '' : 'missing-value'}">${escapeHtml(crew || 'MISSING')}</span></span>
        <span><strong>Estimated setup:</strong> <span class="${duration ? '' : 'missing-value'}">${escapeHtml(duration || 'MISSING')}</span></span>
        <span><strong>Effort:</strong> ${escapeHtml(effort)}</span>
      </div>
    `;
  }

  function taskCard(task) {
    const extra = (task.extra_materials || []).filter((row) => row.material_name !== 'T-Post');
    const tposts = task.tpost_requirements || [];
    const review = indicatorText(task.review_indicators || []);
    const schedulerReview = schedulerReviewItems(task);
    const step = task.display_order ?? 'MISSING';
    const isMaterialStep = Boolean(task.display_material?.requires_display_material);

    return `
      <article class="task-card${isMaterialStep ? ' material-task' : ''}">
        <div class="task-header">
          <div class="task-title-wrap">
            <h3 class="task-title">${escapeHtml(task.task_name)}</h3>
            ${isMaterialStep ? '<span class="material-badge">MATERIAL STEP</span>' : ''}
          </div>
          <div class="task-order">Step ${escapeHtml(step)}</div>
        </div>
        ${schedulerStrip(task)}
        ${schedulerReview.length ? `<div class="scheduler-review"><strong>SCHEDULER / PICK-LIST REVIEW:</strong> ${escapeHtml(schedulerReview.join(' '))}</div>` : '<div class="scheduler-ready">Scheduler basics recorded — review sequence and field practicality.</div>'}
        <div class="compact-line"><strong>Hard predecessor(s) — REQUIRED:</strong> ${predecessorHtml(task)}</div>
        ${task.readiness_note ? optionalLine('Readiness condition / note', task.readiness_note) : '<div class="compact-line"><strong>Readiness condition / note:</strong> <span class="review-value">No readiness note recorded</span></div>'}
        ${optionalLine('Complete when', task.completion_point)}
        ${optionalLine('Weather', task.weather_note)}
        ${optionalLine('Equipment / Resources', resourceText(task.resources))}
        ${isMaterialStep ? optionalLine('Display material / current Containers', displayMaterialText(task.display_material)) : ''}
        ${optionalLine('Kit / Support Containers', supportContainerText(task.support_containers))}
        ${optionalLine('Extra Materials', extraMaterialText(extra))}
        ${optionalLine('T-Post', extraMaterialText(tposts))}
        ${review ? `<div class="review-box"><strong>DATA / PICK-LIST REVIEW:</strong> ${escapeHtml(review)}</div>` : ''}
        ${optionalLine('Procedure', procedureHtml(task), { html: true })}
        ${optionalLine('Reusable notes', task.reusable_notes)}
        <div class="correction-space" aria-label="Hand correction space"></div>
      </article>
    `;
  }

  function groupKey(task) {
    if (task.stage_id == null) return '0|SITE_WIDE';
    const stage = `${task.stage_key || ''} — ${task.stage_name || ''}`.trim();
    if (task.lor_scene_id == null) return `1|${stage}|0|GENERAL`;
    return `1|${stage}|1|${task.scene_name || ''}`;
  }

  function groupLabel(task) {
    if (task.stage_id == null) return 'Site-wide / Park Infrastructure';
    const stage = `${task.stage_key || ''} — ${task.stage_name || ''}`.replace(/\s+—\s+$/, '');
    if (task.lor_scene_id == null) return `${stage} — Stage / General`;
    return `${stage} — ${task.scene_name}`;
  }

  function taskStepSort(left, right) {
    const leftStep = left.display_order == null ? Number.MAX_SAFE_INTEGER : Number(left.display_order);
    const rightStep = right.display_order == null ? Number.MAX_SAFE_INTEGER : Number(right.display_order);
    if (leftStep !== rightStep) return leftStep - rightStep;
    return Number(left.setup_task_id || 0) - Number(right.setup_task_id || 0);
  }

  function renderSummary(summary) {
    state.summary = summary;
    qs('summary-root').hidden = false;
    qs('summary-scope').textContent = summary.scope_label || summary.scope;
    qs('summary-count').textContent = String(summary.task_count ?? 0);
    qs('summary-printed-at').textContent = new Date().toLocaleString();
    qs('verification-boundary').textContent = summary.verification_boundary || '';

    let warning = qs('disposable-warning');
    if (!warning) {
      warning = document.createElement('div');
      warning.id = 'disposable-warning';
      warning.className = 'disposable-warning';
      warning.textContent = 'DISPOSABLE PLANNING MARKUP — NOT AUTHORITATIVE — ENTER DURABLE CORRECTIONS BACK INTO SETUP';
      qs('verification-boundary').before(warning);
    }

    const grouped = new Map();
    for (const task of summary.tasks || []) {
      const key = groupKey(task);
      if (!grouped.has(key)) grouped.set(key, { label: groupLabel(task), tasks: [] });
      grouped.get(key).tasks.push(task);
    }
    for (const group of grouped.values()) group.tasks.sort(taskStepSort);

    const html = [...grouped.values()].map((group) => `
      <section class="scope-group">
        <div class="scope-heading">
          <h2>${escapeHtml(group.label)}</h2>
          <span>${group.tasks.length} task${group.tasks.length === 1 ? '' : 's'} · printed in Catalog Step order</span>
        </div>
        <div class="task-grid">${group.tasks.map(taskCard).join('')}</div>
      </section>
    `).join('');

    qs('summary-groups').innerHTML = html || '<p class="empty">No active reusable Setup tasks matched this scope.</p>';
    qs('print-summary').disabled = !(summary.tasks || []).length;
    setStatus(`Loaded ${summary.task_count || 0} active reusable task(s) in Catalog Step order.`);
  }

  async function loadSummary() {
    try {
      qs('print-summary').disabled = true;
      setStatus('Loading current reusable Setup planning data…');
      const scope = qs('scope-select').value;
      const params = new URLSearchParams({ scope });
      if (scope !== 'all') {
        const stageId = qs('stage-select').value;
        if (!stageId) throw new Error('Choose a Stage.');
        params.set('stage_id', stageId);
      }
      if (scope === 'scene') {
        const sceneId = qs('scene-select').value;
        if (!sceneId) throw new Error('Choose a real Scene for this Stage.');
        params.set('lor_scene_id', sceneId);
      }
      const payload = await api(`../api/setup/planning-summary?${params.toString()}`);
      renderSummary(payload.planning_summary || {});
    } catch (error) {
      qs('summary-root').hidden = true;
      setStatus(error.message || String(error), true);
    }
  }

  function applyRequestedScope() {
    const params = new URLSearchParams(window.location.search);
    const scope = params.get('scope');
    if (!['stage', 'scene', 'all'].includes(scope)) return false;

    qs('scope-select').value = scope;
    if (scope !== 'all') {
      const stageId = params.get('stage_id');
      if (!stageId || ![...qs('stage-select').options].some((item) => item.value === stageId)) return false;
      qs('stage-select').value = stageId;
    }
    refreshScopeControls();

    if (scope === 'scene') {
      const sceneId = params.get('lor_scene_id');
      if (!sceneId || ![...qs('scene-select').options].some((item) => item.value === sceneId)) return false;
      qs('scene-select').value = sceneId;
    }
    return true;
  }

  async function initialize() {
    try {
      setStatus('Loading Setup planning scopes…');
      const [accessPayload, stagesPayload, organizationPayload] = await Promise.all([
        api('../api/setup/access'),
        api('../api/setup/stages'),
        api('../api/setup/organization'),
      ]);
      state.access = accessPayload.access || {};
      state.stages = stagesPayload.stages || [];
      state.scenes = organizationPayload.organization?.scenes || [];
      qs('access-label').textContent = state.access.display_name
        ? `Signed in: ${state.access.display_name}`
        : 'Setup reader';
      refreshStageOptions();
      refreshScopeControls();
      if (applyRequestedScope()) {
        await loadSummary();
      } else {
        setStatus('Choose a planning scope and load the current reusable Catalog summary.');
      }
    } catch (error) {
      setStatus(error.message || String(error), true);
    }
  }

  qs('scope-select').addEventListener('change', refreshScopeControls);
  qs('stage-select').addEventListener('change', refreshSceneOptions);
  qs('load-summary').addEventListener('click', loadSummary);
  qs('print-summary').addEventListener('click', () => {
    qs('summary-printed-at').textContent = new Date().toLocaleString();
    window.print();
  });

  initialize();
})();