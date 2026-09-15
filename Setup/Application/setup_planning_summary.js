(() => {
  'use strict';

  const state = {
    access: null,
    stages: [],
    scenes: [],
    summary: null,
  };

  const qs = (id) => document.getElementById(id);

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

  function compactMeta(task) {
    const bits = [];
    bits.push(`Type ${task.task_action_type || 'WORK'}`);
    const crewMin = task.normal_crew_min;
    const crewMax = task.normal_crew_max;
    if (crewMin != null || crewMax != null) {
      if (crewMin != null && crewMax != null) bits.push(`Crew ${crewMin}–${crewMax}`);
      else bits.push(`Crew ${crewMin ?? crewMax}`);
    }
    if (task.expected_duration_minutes != null) bits.push(`${task.expected_duration_minutes} min`);
    if (task.effort_level) bits.push(`Effort ${task.effort_level}`);
    return bits.join(' · ');
  }

  function dependencyText(rows) {
    return (rows || []).map((row) => {
      const note = row.dependency_note ? ` — ${row.dependency_note}` : '';
      return `${row.task_name}${note}`;
    }).join('; ');
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
    if (!material?.requires_display_material) return 'No';
    const bits = [`Yes — ${material.display_count || 0} Display(s)`];
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

  function taskCard(task) {
    const extra = (task.extra_materials || []).filter((row) => row.material_name !== 'T-Post');
    const tposts = task.tpost_requirements || [];
    const review = indicatorText(task.review_indicators || []);
    const baseline = task.baseline_plan_order ?? '—';
    const displayOrder = task.display_order ?? '—';

    return `
      <article class="task-card">
        <div class="task-header">
          <h3 class="task-title">${escapeHtml(task.task_name)}</h3>
          <div class="task-order">Plan ${escapeHtml(baseline)} · Display ${escapeHtml(displayOrder)}</div>
        </div>
        <p class="task-meta">${escapeHtml(compactMeta(task))}</p>
        ${review ? `<div class="review-box">${escapeHtml(review)}</div>` : ''}
        ${optionalLine('Prereq', dependencyText(task.dependencies))}
        ${optionalLine('Complete when', task.completion_point)}
        ${optionalLine('Ready when', task.readiness_note)}
        ${optionalLine('Weather', task.weather_note)}
        ${optionalLine('Resources', resourceText(task.resources))}
        ${optionalLine('Display / Container', displayMaterialText(task.display_material))}
        ${optionalLine('Kit / Support', supportContainerText(task.support_containers))}
        ${optionalLine('Extra', extraMaterialText(extra))}
        ${optionalLine('T-Post', extraMaterialText(tposts))}
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

    const html = [...grouped.values()].map((group) => `
      <section class="scope-group">
        <div class="scope-heading">
          <h2>${escapeHtml(group.label)}</h2>
          <span>${group.tasks.length} task${group.tasks.length === 1 ? '' : 's'}</span>
        </div>
        <div class="task-grid">${group.tasks.map(taskCard).join('')}</div>
      </section>
    `).join('');

    qs('summary-groups').innerHTML = html || '<p class="empty">No active reusable Setup tasks matched this scope.</p>';
    qs('print-summary').disabled = !(summary.tasks || []).length;
    setStatus(`Loaded ${summary.task_count || 0} active reusable task(s).`);
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
      setStatus('Choose a planning scope and load the current reusable Catalog summary.');
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
