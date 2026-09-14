(() => {
  'use strict';

  const MARKER = '[DISPOSABLE_KIT_RECON_V1]';
  const state = {
    access: null,
    kits: [],
    tasks: [],
    selectedKitId: null,
    seasonYear: null,
  };

  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/kit-assignment-workbench';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }
  const APP_BASE = appBasePath();
  const appUrl = (path) => `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`;

  async function api(path, options = {}) {
    const response = await fetch(appUrl(path), {
      credentials: 'same-origin',
      headers: { Accept: 'application/json', ...(options.headers || {}) },
      ...options,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Setup API returned HTTP ${response.status}`);
    return payload;
  }

  function commandOptions(body) {
    return {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-MSB-Setup-Command': '1',
      },
      body: JSON.stringify(body),
    };
  }

  function esc(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&#039;');
  }

  function setNotice(message, stateName = 'ok') {
    const target = el('notice');
    target.textContent = message;
    target.dataset.state = stateName;
  }

  function isWorkbenchAssignment(assignment) {
    return String(assignment?.relationship_notes || '').startsWith(MARKER);
  }

  function kitById(containerId) {
    return state.kits.find((row) => Number(row.container_id) === Number(containerId));
  }

  function taskById(taskId) {
    return state.tasks.find((row) => Number(row.setup_task_id) === Number(taskId));
  }

  function assignmentExists(containerId, taskId) {
    const kit = kitById(containerId);
    return (kit?.assigned_tasks || []).some((row) => Number(row.setup_task_id) === Number(taskId));
  }

  function newAssignments() {
    const rows = [];
    state.kits.forEach((kit) => {
      (kit.assigned_tasks || []).forEach((assignment) => {
        if (!isWorkbenchAssignment(assignment)) return;
        rows.push({
          container_id: Number(kit.container_id),
          container_description: kit.container_description || '',
          setup_task_id: Number(assignment.setup_task_id),
          task_name: assignment.task_name || '',
          stage_key: assignment.stage_key || '',
          stage_name: assignment.stage_name || '',
        });
      });
    });
    return rows.sort((a, b) => a.setup_task_id - b.setup_task_id || a.container_id - b.container_id);
  }

  function renderSummary() {
    const assigned = state.kits.filter((kit) => Number(kit.assigned_task_count || 0) > 0).length;
    el('sum-kits').textContent = String(state.kits.length);
    el('sum-assigned').textContent = String(assigned);
    el('sum-unassigned').textContent = String(state.kits.length - assigned);
    el('sum-new').textContent = String(newAssignments().length);
  }

  function normalized(value) {
    return String(value || '').trim().toLocaleLowerCase();
  }

  async function selectKit(containerId) {
    state.selectedKitId = Number(containerId);
    const kit = kitById(state.selectedKitId);
    if (!kit) return;
    el('selected-kit').textContent = `Selected: #${kit.container_id} · ${kit.container_description || 'Unnamed Kit Box'}. Loading stored Displays…`;
    renderKits();
    try {
      const payload = await api(`api/setup/kit-inventory/kit-boxes/${kit.container_id}/displays`);
      const names = (payload.displays || []).map((row) => row.display_name).filter(Boolean);
      const displayText = names.length ? ` Stored Displays: ${names.join('; ')}.` : ' No current Displays are stored in this Kit.';
      el('selected-kit').textContent = `Selected: #${kit.container_id} · ${kit.container_description || 'Unnamed Kit Box'}.${displayText} Click a task on the right to assign it.`;
    } catch (error) {
      el('selected-kit').textContent = `Selected: #${kit.container_id} · ${kit.container_description || 'Unnamed Kit Box'}. Display lookup failed: ${error.message}`;
    }
  }

  function renderKits() {
    const query = normalized(el('kit-search').value);
    const unassignedOnly = el('kits-unassigned-only').checked;
    const rows = state.kits.filter((kit) => {
      if (unassignedOnly && Number(kit.assigned_task_count || 0) > 0) return false;
      if (!query) return true;
      const search = [
        kit.container_id,
        kit.container_description,
        kit.home_location_code,
        kit.assigned_task_names,
      ].join(' ').toLocaleLowerCase();
      return search.includes(query);
    });

    el('kit-list').innerHTML = rows.map((kit) => {
      const selected = Number(state.selectedKitId) === Number(kit.container_id);
      const assignments = (kit.assigned_tasks || []).map((assignment) => {
        const fresh = isWorkbenchAssignment(assignment);
        return `<span class="assignment-chip ${fresh ? 'new' : ''}">
          ${esc(assignment.stage_key || '—')} · ${esc(assignment.task_name || `Task ${assignment.setup_task_id}`)}
          ${fresh ? `<button type="button" class="remove-new" title="Undo this new disposable assignment" data-container-id="${kit.container_id}" data-task-id="${assignment.setup_task_id}">×</button>` : ''}
        </span>`;
      }).join('');
      return `<article class="kit-card ${selected ? 'selected' : ''}" draggable="true" data-container-id="${kit.container_id}">
        <div class="kit-title">#${kit.container_id} · ${esc(kit.container_description || 'Unnamed Kit Box')}</div>
        <div class="kit-meta">${esc(kit.home_location_code || 'No home location')} · ${Number(kit.display_rows || 0)} Displays · ${Number(kit.expected_item_rows || 0)} expected Extra Material rows</div>
        <div class="assignment-row">${assignments || '<span class="kit-meta">No reusable Setup task assignment recorded</span>'}</div>
      </article>`;
    }).join('') || '<div class="empty">No Kit Boxes match this filter.</div>';

    el('kit-list').querySelectorAll('.kit-card').forEach((card) => {
      card.addEventListener('click', (event) => {
        if (event.target.closest('.remove-new')) return;
        selectKit(Number(card.dataset.containerId));
      });
      card.addEventListener('dragstart', (event) => {
        const containerId = Number(card.dataset.containerId);
        state.selectedKitId = containerId;
        selectKit(containerId);
        event.dataTransfer.effectAllowed = 'copy';
        event.dataTransfer.setData('text/plain', String(containerId));
        card.classList.add('dragging');
      });
      card.addEventListener('dragend', () => card.classList.remove('dragging'));
    });

    el('kit-list').querySelectorAll('.remove-new').forEach((button) => {
      button.addEventListener('click', () => undoAssignment(Number(button.dataset.containerId), Number(button.dataset.taskId)));
    });
  }

  function taskAssignedKits(taskId) {
    return state.kits.filter((kit) => (kit.assigned_tasks || []).some((assignment) => Number(assignment.setup_task_id) === Number(taskId)));
  }

  function renderTasks() {
    const query = normalized(el('task-search').value);
    const tasks = state.tasks.filter((task) => {
      if (!task.active_flag || task.stage_id == null) return false;
      if (!query) return true;
      return [task.setup_task_id, task.stage_key, task.stage_name, task.task_name]
        .join(' ').toLocaleLowerCase().includes(query);
    });

    const groups = new Map();
    tasks.forEach((task) => {
      const key = `${task.stage_key || '—'}|${task.stage_name || 'General'}`;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(task);
    });

    el('task-list').innerHTML = [...groups.entries()].map(([key, stageTasks]) => {
      const [stageKey, stageName] = key.split('|');
      const ordered = [...stageTasks].sort((a, b) => Number(a.display_order || 0) - Number(b.display_order || 0) || Number(a.setup_task_id) - Number(b.setup_task_id));
      return `<section class="stage-group">
        <div class="stage-heading">Stage ${esc(stageKey)} — ${esc(stageName)}</div>
        ${ordered.map((task) => {
          const kits = taskAssignedKits(task.setup_task_id);
          const pills = kits.map((kit) => {
            const assignment = (kit.assigned_tasks || []).find((row) => Number(row.setup_task_id) === Number(task.setup_task_id));
            return `<span class="task-kit-pill ${isWorkbenchAssignment(assignment) ? 'new' : ''}">#${kit.container_id} ${esc(kit.container_description || '')}</span>`;
          }).join('');
          return `<article class="task-card" data-task-id="${task.setup_task_id}">
            <div class="task-title"><strong>${esc(task.task_name)}</strong><span class="task-meta">Task ${task.setup_task_id}</span></div>
            <div class="task-kits">${pills || '<span class="task-meta">No Kit assigned</span>'}</div>
          </article>`;
        }).join('')}
      </section>`;
    }).join('') || '<div class="empty">No reusable Setup tasks match this search.</div>';

    el('task-list').querySelectorAll('.task-card').forEach((card) => {
      const taskId = Number(card.dataset.taskId);
      card.addEventListener('dragover', (event) => {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
        card.classList.add('drag-over');
      });
      card.addEventListener('dragleave', () => card.classList.remove('drag-over'));
      card.addEventListener('drop', (event) => {
        event.preventDefault();
        card.classList.remove('drag-over');
        const containerId = Number(event.dataTransfer.getData('text/plain'));
        if (containerId) assignKit(containerId, taskId);
      });
      card.addEventListener('click', () => {
        if (state.selectedKitId) assignKit(state.selectedKitId, taskId);
      });
    });
  }

  function captureSql() {
    const rows = newAssignments();
    if (!rows.length) return '-- No new disposable Kit assignments have been made yet.\n';
    const values = rows.map((row) => {
      const comment = `${String(row.stage_key || '—')} ${row.task_name} <- Kit #${row.container_id} ${row.container_description}`
        .replaceAll('\n', ' ').replaceAll('\r', ' ').replaceAll('*/', '* /');
      return `    (${row.setup_task_id}, ${row.container_id}, 'KIT', 'Initial Kit assignment reviewed in disposable reconstruction workbench.') /* ${comment} */`;
    }).join(',\n');
    return `-- DISPOSABLE CAPTURE ARTIFACT ONLY. Review before any Production migration.\n-- Marker: ${MARKER}\n-- Candidate rows: ${rows.length}\nBEGIN;\nINSERT INTO ref.setup_task_container_support(\n    setup_task_id, container_id, relationship_type, notes\n) VALUES\n${values}\nON CONFLICT (setup_task_id, container_id) DO NOTHING;\nCOMMIT;\n`;
  }

  function renderCapture() {
    el('capture-output').value = captureSql();
  }

  async function reloadKits() {
    const payload = await api('api/setup/kit-inventory/kit-boxes');
    state.kits = payload.kit_boxes || [];
    renderSummary();
    renderKits();
    renderTasks();
    renderCapture();
  }

  async function assignKit(containerId, taskId) {
    if (!state.access?.can_manage_setup) return;
    const kit = kitById(containerId);
    const task = taskById(taskId);
    if (!kit || !task) return;
    if (assignmentExists(containerId, taskId)) {
      setNotice(`#${containerId} ${kit.container_description || ''} is already assigned to Task ${taskId} ${task.task_name}.`);
      return;
    }

    setNotice(`Assigning Kit #${containerId} to Task ${taskId}…`);
    try {
      await api(
        `api/setup/tasks/${taskId}/kit-boxes/${containerId}`,
        commandOptions({
          assigned: true,
          notes: `${MARKER} Reviewed bulk Kit assignment in disposable workbench.`,
        }),
      );
      await reloadKits();
      setNotice(`Assigned Kit #${containerId} · ${kit.container_description || ''} to Task ${taskId} · ${task.task_name}.`);
    } catch (error) {
      setNotice(error.message, 'error');
    }
  }

  async function undoAssignment(containerId, taskId) {
    const kit = kitById(containerId);
    const task = taskById(taskId);
    const assignment = (kit?.assigned_tasks || []).find((row) => Number(row.setup_task_id) === Number(taskId));
    if (!assignment || !isWorkbenchAssignment(assignment)) {
      setNotice('Existing/baseline Kit assignments cannot be removed from this disposable bulk workbench.', 'error');
      return;
    }
    if (!window.confirm(`Undo the new disposable assignment: Kit #${containerId} → Task ${taskId}?`)) return;
    try {
      await api(
        `api/setup/tasks/${taskId}/kit-boxes/${containerId}`,
        commandOptions({ assigned: false, notes: null }),
      );
      await reloadKits();
      setNotice(`Removed the new disposable Kit #${containerId} → Task ${taskId} assignment.`);
    } catch (error) {
      setNotice(error.message, 'error');
    }
  }

  async function initialize() {
    try {
      const [accessPayload, seasonsPayload, kitsPayload] = await Promise.all([
        api('api/setup/access'),
        api('api/setup/seasons'),
        api('api/setup/kit-inventory/kit-boxes'),
      ]);
      state.access = accessPayload.access || {};
      if (!state.access.can_manage_setup) throw new Error('This disposable assignment workbench requires Setup Manager authority.');
      el('access-badge').textContent = `${state.access.display_name || state.access.authenticated_email} · ${state.access.role_name || 'Manager'}`;

      const years = (seasonsPayload.seasons || []).map((row) => Number(row.season_year)).filter(Number.isFinite);
      state.seasonYear = years.length ? Math.max(...years) : 2025;
      const tasksPayload = await api(`api/setup/tasks?season_year=${state.seasonYear}`);
      state.tasks = tasksPayload.tasks || [];
      state.kits = kitsPayload.kit_boxes || [];

      renderSummary();
      renderKits();
      renderTasks();
      renderCapture();
      setNotice('Ready. Drag a Kit Box onto a reusable Setup task. Existing assignments are preserved; new assignments are disposable and exportable.');
    } catch (error) {
      setNotice(error.message, 'error');
    }
  }

  el('kit-search').addEventListener('input', renderKits);
  el('kits-unassigned-only').addEventListener('change', renderKits);
  el('task-search').addEventListener('input', renderTasks);
  el('capture-copy').addEventListener('click', async () => {
    const text = captureSql();
    try {
      await navigator.clipboard.writeText(text);
      setNotice(`Copied ${newAssignments().length} new Kit assignment rows.`);
    } catch (_error) {
      el('capture-output').focus();
      el('capture-output').select();
      setNotice('Clipboard access was unavailable. Capture text is selected for manual copy.', 'error');
    }
  });
  el('capture-download').addEventListener('click', () => {
    const blob = new Blob([captureSql()], { type: 'text/sql;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'Setup_Kit_Assignment_Disposable_Capture.sql';
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  });

  initialize();
})();
