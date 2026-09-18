/* Setup #205 rolling Scheduling Board.
   This upgrades the legacy V0.3 Plan / Schedule surface without changing the
   Reusable Task Catalog or the #132 Report Work implementation. */

const setupBoard205State = {
  board: { session: null, work_days: [], tasks: [], assignments: [], dependencies: [] },
  dragged: null,
  editSeasonTaskId: null,
  scheduleTarget: null
};

function board205Esc(value) {
  return escapeHtml(value == null ? '' : String(value));
}

function board205Task(sessionTaskId) {
  return (setupBoard205State.board.tasks || []).find(
    (task) => Number(task.setup_session_task_id) === Number(sessionTaskId)
  );
}

function board205Assignment(assignmentId) {
  return (setupBoard205State.board.assignments || []).find(
    (item) => Number(item.setup_work_day_task_id) === Number(assignmentId)
  );
}

function board205Scope(task) {
  if (!task) return 'Unknown scope';
  if (task.stage_id == null) return 'Site-wide / Infrastructure';
  return `Stage ${task.stage_key || '—'}${task.scene_name ? ` / ${task.scene_name}` : ' / Stage-level'}`;
}

function board205Duration(minutes) {
  if (minutes == null || Number(minutes) <= 0) return 'Time not reviewed';
  return typeof formatMinutes === 'function'
    ? formatMinutes(Number(minutes))
    : `${minutes} min`;
}

function board205Crew(task) {
  if (task.normal_crew_min == null && task.normal_crew_max == null) return 'Crew not reviewed';
  if (task.normal_crew_min != null && task.normal_crew_max != null) {
    return Number(task.normal_crew_min) === Number(task.normal_crew_max)
      ? `Crew ${task.normal_crew_min}`
      : `Crew ${task.normal_crew_min}–${task.normal_crew_max}`;
  }
  return `Crew ${task.normal_crew_min ?? task.normal_crew_max}`;
}

function board205StatusLabel(status) {
  return String(status || '').replaceAll('_', ' ').replace(/\b\w/g, (char) => char.toUpperCase());
}

function board205TaskDependencies(taskId) {
  return (setupBoard205State.board.dependencies || []).filter(
    (dep) => Number(dep.setup_session_task_id) === Number(taskId)
  );
}

function board205WorkOrderBadge(task) {
  if (!task?.linked_work_order_id) return '';
  const complete = Boolean(task.linked_work_order_completed_at);
  return `<span class="setup-board205-badge ${complete ? '' : 'waiting'}">WO ${board205Esc(task.linked_work_order_id)} · ${complete ? 'complete' : 'open'}</span>`;
}

function board205TaskCard(task) {
  const deps = board205TaskDependencies(task.setup_session_task_id);
  const isGate = task.task_action_type === 'GATE';
  const canManage = Boolean(appState.access?.can_manage_setup);
  const canSchedule = canManage && !task.effective_complete && !isGate && task.board_status !== 'DEFERRED';
  const blocked = task.board_status === 'BLOCKED';
  const seasonOnly = task.task_origin === 'SEASON_ONLY';
  const depText = deps.length
    ? deps.map((dep) => `${dep.prerequisite_complete ? '✓' : '○'} ${dep.prerequisite_task_name}`).join('; ')
    : 'No annual prerequisite';

  return `
    <article class="setup-board205-task-card"
      data-session-task-id="${task.setup_session_task_id}"
      draggable="${canSchedule ? 'true' : 'false'}">
      <div class="setup-board205-task-title">
        <span>${board205Esc(task.planned_order ?? '—')} · ${board205Esc(task.task_name)}</span>
        ${seasonOnly ? '<span class="setup-board205-badge season-only">THIS SEASON ONLY</span>' : ''}
        ${isGate ? '<span class="setup-board205-badge">GATE</span>' : ''}
        <span class="setup-board205-badge ${blocked ? 'blocked' : task.board_status === 'WAITING_ON_WORK_ORDER' ? 'waiting' : ''}">${board205Esc(board205StatusLabel(task.board_status))}</span>
        ${board205WorkOrderBadge(task)}
      </div>
      <div class="setup-board205-meta">${board205Esc(board205Scope(task))}</div>
      <div class="setup-board205-meta">${board205Esc(board205Crew(task))} · ${board205Esc(board205Duration(task.expected_duration_minutes))}</div>
      <div class="setup-board205-meta">${board205Esc(depText)}</div>
      ${task.readiness_note ? `<div class="setup-board205-meta"><strong>Readiness:</strong> ${board205Esc(task.readiness_note)}</div>` : ''}
      <div class="setup-board205-card-actions">
        ${canSchedule ? `<button type="button" class="small setup-board205-schedule-task">Schedule…</button>` : ''}
        ${canManage && seasonOnly ? `<button type="button" class="small secondary setup-board205-edit-season-task">Edit season task</button>` : ''}
        ${canManage ? `
          <button type="button" class="small secondary setup-board205-plan-up">Plan ↑</button>
          <button type="button" class="small secondary setup-board205-plan-down">Plan ↓</button>` : ''}
      </div>
    </article>`;
}

function board205QueueTasks() {
  const checked = new Set(
    [...document.querySelectorAll('#setup-board205-filters input:checked')].map((input) => input.value)
  );
  return [...(setupBoard205State.board.tasks || [])]
    .filter((task) => checked.has(task.board_status))
    .sort((a, b) => {
      const ao = a.planned_order == null ? 999999 : Number(a.planned_order);
      const bo = b.planned_order == null ? 999999 : Number(b.planned_order);
      if (ao !== bo) return ao - bo;
      return Number(a.setup_session_task_id) - Number(b.setup_session_task_id);
    });
}

function board205RenderQueue() {
  const target = document.getElementById('setup-board205-queue');
  if (!target) return;
  const tasks = board205QueueTasks();
  target.innerHTML = tasks.length
    ? tasks.map(board205TaskCard).join('')
    : '<div class="setup-board205-empty">No annual tasks match the selected filters.</div>';

  target.querySelectorAll('.setup-board205-task-card').forEach((card) => {
    const taskId = Number(card.dataset.sessionTaskId);
    const task = board205Task(taskId);
    card.addEventListener('dragstart', (event) => {
      if (!task || task.task_action_type === 'GATE') return;
      setupBoard205State.dragged = { kind: 'task', id: taskId };
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', JSON.stringify(setupBoard205State.dragged));
      card.classList.add('dragging');
    });
    card.addEventListener('dragend', () => {
      setupBoard205State.dragged = null;
      document.querySelectorAll('.dragging,.drop-target').forEach((item) => item.classList.remove('dragging', 'drop-target'));
    });
    card.querySelector('.setup-board205-schedule-task')?.addEventListener('click', () => {
      board205OpenScheduleDialog({ kind: 'task', id: taskId });
    });
    card.querySelector('.setup-board205-edit-season-task')?.addEventListener('click', () => {
      board205OpenSeasonTaskDialog(taskId);
    });
    card.querySelector('.setup-board205-plan-up')?.addEventListener('click', () => board205MoveAnnualOrder(taskId, -1));
    card.querySelector('.setup-board205-plan-down')?.addEventListener('click', () => board205MoveAnnualOrder(taskId, 1));
  });
}

function board205AssignmentsFor(dayId, shift, lane) {
  return (setupBoard205State.board.assignments || [])
    .filter((item) => (
      Number(item.setup_work_day_id) === Number(dayId)
      && item.shift_code === shift
      && String(item.crew_lane) === lane
    ))
    .sort((a, b) => (
      Number(a.sort_order) - Number(b.sort_order)
      || Number(a.setup_work_day_task_id) - Number(b.setup_work_day_task_id)
    ));
}

function board205AssignmentCard(item) {
  const task = board205Task(item.setup_session_task_id) || item;
  const canManage = Boolean(appState.access?.can_manage_setup);
  const locked = Boolean(item.historical_locked);
  return `
    <article class="setup-board205-assignment ${locked ? 'locked' : ''}"
      data-assignment-id="${item.setup_work_day_task_id}"
      draggable="${canManage && !locked ? 'true' : 'false'}">
      <div class="setup-board205-task-title">
        <span>${board205Esc(item.task_name)}</span>
        ${task.task_origin === 'SEASON_ONLY' ? '<span class="setup-board205-badge season-only">THIS SEASON ONLY</span>' : ''}
        ${board205WorkOrderBadge(task)}
      </div>
      <div class="setup-board205-meta">${board205Esc(board205Scope(item))} · Planned crew ${board205Esc(item.planned_crew_count ?? 'TBD')}</div>
      ${locked ? '<div class="setup-board205-lock">Historical actual — locked</div>' : ''}
      ${canManage && !locked ? `
        <div class="setup-board205-card-actions">
          <button type="button" class="small secondary setup-board205-up">↑</button>
          <button type="button" class="small secondary setup-board205-down">↓</button>
          <button type="button" class="small secondary setup-board205-move">Move…</button>
          <button type="button" class="small secondary setup-board205-remove">Remove</button>
        </div>` : ''}
    </article>`;
}

function board205Cell(day, shift, lane) {
  const items = board205AssignmentsFor(day.setup_work_day_id, shift, lane);
  return `
    <div class="setup-board205-cell"
      data-day-id="${day.setup_work_day_id}" data-shift="${shift}" data-lane="${lane}">
      ${items.length ? items.map(board205AssignmentCard).join('') : '<div class="setup-board205-cell-empty">Drop work here</div>'}
    </div>`;
}

function board205Day(day) {
  const dayClass = Number(day.iso_day_of_week) === 6 ? 'saturday' : Number(day.iso_day_of_week) === 7 ? 'sunday' : '';
  const dayNote = [day.volunteer_note, day.weather_note, day.notes].filter(Boolean).join(' · ');
  return `
    <section class="setup-board205-day ${dayClass}" data-day-id="${day.setup_work_day_id}">
      <div class="setup-board205-day-header">
        <div>
          <strong>Day ${board205Esc(day.setup_day_number)} · ${board205Esc(day.day_of_week)} · ${board205Esc(day.work_date)}</strong>
          ${Number(day.iso_day_of_week) === 6 ? '<div class="setup-board205-day-note">Saturday · typically stronger volunteer turnout</div>' : ''}
          ${Number(day.iso_day_of_week) === 7 ? '<div class="setup-board205-sunday-warning">Sunday · avoid scheduling unless deliberately needed</div>' : ''}
          ${dayNote ? `<div class="setup-board205-day-note">${board205Esc(dayNote)}</div>` : ''}
        </div>
        <span class="setup-board205-badge">${board205Esc(day.day_status)}</span>
      </div>
      <div class="setup-board205-table-wrap">
        <div class="setup-board205-grid">
          <div class="setup-board205-grid-head">Crew</div>
          <div class="setup-board205-grid-head">AM</div>
          <div class="setup-board205-grid-head">PM</div>
          <div class="setup-board205-grid-head">All Day</div>
          ${['A','B','C','D'].map((lane) => `
            <div class="setup-board205-crew-label">Crew ${lane}</div>
            ${board205Cell(day, 'MORNING', lane)}
            ${board205Cell(day, 'AFTERNOON', lane)}
            ${board205Cell(day, 'ALL_DAY', lane)}
          `).join('')}
        </div>
      </div>
    </section>`;
}

function board205RenderBoard() {
  const target = document.getElementById('setup-board205-days');
  if (!target) return;
  const days = setupBoard205State.board.work_days || [];
  target.innerHTML = days.length
    ? days.map(board205Day).join('')
    : '<div class="setup-board205-empty">No Setup work days yet. Add the first actual planned work day; early-access locating/layout work may legitimately be Day 1.</div>';

  target.querySelectorAll('.setup-board205-cell').forEach((cell) => {
    cell.addEventListener('dragover', (event) => {
      if (!setupBoard205State.dragged) return;
      event.preventDefault();
      cell.classList.add('drop-target');
    });
    cell.addEventListener('dragleave', () => cell.classList.remove('drop-target'));
    cell.addEventListener('drop', async (event) => {
      event.preventDefault();
      event.stopPropagation();
      cell.classList.remove('drop-target');
      await board205DropToCell(
        setupBoard205State.dragged,
        Number(cell.dataset.dayId),
        cell.dataset.shift,
        cell.dataset.lane,
        null
      );
    });
  });

  target.querySelectorAll('.setup-board205-assignment').forEach((card) => {
    const assignmentId = Number(card.dataset.assignmentId);
    const item = board205Assignment(assignmentId);
    card.addEventListener('dragstart', (event) => {
      if (!item || item.historical_locked) return;
      setupBoard205State.dragged = { kind: 'assignment', id: assignmentId };
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', JSON.stringify(setupBoard205State.dragged));
      card.classList.add('dragging');
    });
    card.addEventListener('dragover', (event) => {
      if (!setupBoard205State.dragged || item?.historical_locked) return;
      event.preventDefault();
      event.stopPropagation();
      card.classList.add('drop-target');
    });
    card.addEventListener('dragleave', () => card.classList.remove('drop-target'));
    card.addEventListener('drop', async (event) => {
      event.preventDefault();
      event.stopPropagation();
      card.classList.remove('drop-target');
      if (!item) return;
      await board205DropToCell(
        setupBoard205State.dragged,
        Number(item.setup_work_day_id),
        item.shift_code,
        item.crew_lane,
        Number(item.sort_order) - 1
      );
    });
    card.addEventListener('dragend', () => {
      setupBoard205State.dragged = null;
      document.querySelectorAll('.dragging,.drop-target').forEach((node) => node.classList.remove('dragging', 'drop-target'));
    });
    card.querySelector('.setup-board205-up')?.addEventListener('click', () => board205NudgeAssignment(item, -1));
    card.querySelector('.setup-board205-down')?.addEventListener('click', () => board205NudgeAssignment(item, 1));
    card.querySelector('.setup-board205-move')?.addEventListener('click', () => {
      board205OpenScheduleDialog({ kind: 'assignment', id: assignmentId });
    });
    card.querySelector('.setup-board205-remove')?.addEventListener('click', () => board205RemoveAssignment(item));
  });
}

function board205Render() {
  const session = setupBoard205State.board.session;
  const noSession = document.getElementById('setup-board205-no-session');
  const workspace = document.getElementById('setup-board205-workspace');
  const addSeason = document.getElementById('setup-board205-add-season-task');
  const dayForm = document.getElementById('setup-board205-day-form');
  if (addSeason) addSeason.disabled = !session;
  if (dayForm) {
    dayForm.querySelectorAll('input,button,select').forEach((control) => {
      control.disabled = !session;
    });
  }
  if (!session) {
    if (noSession) noSession.hidden = false;
    if (workspace) workspace.hidden = true;
    return;
  }
  if (noSession) noSession.hidden = true;
  if (workspace) workspace.hidden = false;
  board205RenderQueue();
  board205RenderBoard();
  board205PopulateDialogSelects();
}

async function board205Load() {
  try {
    const payload = await api(`api/setup/scheduling-board?season_year=${encodeURIComponent(appState.seasonYear)}`);
    setupBoard205State.board = payload.board || { session: null, work_days: [], tasks: [], assignments: [], dependencies: [] };
    board205Render();
  } catch (error) {
    setAlert(error.message || error, 'error');
    const target = document.getElementById('setup-board205-days');
    if (target) target.innerHTML = `<div class="setup-board205-empty">${board205Esc(error.message || error)}</div>`;
  }
}

/* Replace the legacy Plan/Schedule reload target. Existing tab listeners call
   the global function at click time, so this keeps the accepted tab shell. */
loadNextSchedule = board205Load;

function board205EndSort(dayId, shift, lane) {
  const items = board205AssignmentsFor(dayId, shift, lane);
  return items.length ? Math.max(...items.map((item) => Number(item.sort_order) || 0)) + 10 : 10;
}

async function board205DropToCell(dragged, dayId, shift, lane, requestedSort) {
  if (!dragged || !appState.access?.can_manage_setup) return;
  const sortOrder = requestedSort == null ? board205EndSort(dayId, shift, lane) : requestedSort;
  try {
    setBusy(true);
    if (dragged.kind === 'task') {
      const task = board205Task(dragged.id);
      if (!task || task.effective_complete || task.task_action_type === 'GATE') return;
      if (task.board_status === 'BLOCKED' && !window.confirm('This task has an incomplete annual prerequisite. Schedule it anyway?')) return;
      await api('api/setup/scheduling-board/assignments', commandOptions('POST', {
        setup_work_day_id: dayId,
        setup_session_task_id: task.setup_session_task_id,
        shift_code: shift,
        crew_lane: lane,
        sort_order: sortOrder,
        planned_crew_count: task.normal_crew_min ?? null
      }));
    } else if (dragged.kind === 'assignment') {
      const item = board205Assignment(dragged.id);
      if (!item || item.historical_locked) return;
      await api(`api/setup/scheduling-board/assignments/${item.setup_work_day_task_id}`, commandOptions('PATCH', {
        setup_work_day_id: dayId,
        shift_code: shift,
        crew_lane: lane,
        sort_order: sortOrder,
        planned_crew_count: item.planned_crew_count
      }));
    }
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setupBoard205State.dragged = null;
    setBusy(false);
  }
}

async function board205NudgeAssignment(item, direction) {
  if (!item || item.historical_locked) return;
  const peers = board205AssignmentsFor(item.setup_work_day_id, item.shift_code, item.crew_lane);
  const index = peers.findIndex((row) => Number(row.setup_work_day_task_id) === Number(item.setup_work_day_task_id));
  const neighbor = peers[index + direction];
  if (!neighbor) return;
  const newSort = direction < 0
    ? Number(neighbor.sort_order) - 1
    : Number(neighbor.sort_order) + 1;
  try {
    await api(`api/setup/scheduling-board/assignments/${item.setup_work_day_task_id}`, commandOptions('PATCH', {
      setup_work_day_id: item.setup_work_day_id,
      shift_code: item.shift_code,
      crew_lane: item.crew_lane,
      sort_order: newSort,
      planned_crew_count: item.planned_crew_count
    }));
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  }
}

async function board205RemoveAssignment(item) {
  if (!item || item.historical_locked) return;
  if (!window.confirm(`Remove "${item.task_name}" from this future work period and return it to Needs Scheduling?`)) return;
  try {
    await api(`api/setup/scheduling-board/assignments/${item.setup_work_day_task_id}`, commandOptions('DELETE'));
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  }
}

async function board205MoveAnnualOrder(taskId, direction) {
  const task = board205Task(taskId);
  if (!task) return;
  const tasks = [...(setupBoard205State.board.tasks || [])]
    .sort((a, b) => Number(a.planned_order ?? 999999) - Number(b.planned_order ?? 999999));
  const index = tasks.findIndex((row) => Number(row.setup_session_task_id) === Number(taskId));
  const neighbor = tasks[index + direction];
  if (!neighbor) return;
  const desired = direction < 0
    ? Number(neighbor.planned_order ?? 0) - 1
    : Number(neighbor.planned_order ?? 0) + 1;
  try {
    await api(`api/setup/session-tasks/${taskId}/planned-order`, commandOptions('PATCH', {
      planned_order: Math.max(0, desired),
      plan_change_reason: 'Annual Scheduling Board reorder'
    }));
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  }
}

function board205PopulateDialogSelects() {
  const daySelect = document.getElementById('setup-board205-schedule-day');
  if (daySelect) {
    daySelect.innerHTML = (setupBoard205State.board.work_days || []).map((day) => (
      `<option value="${day.setup_work_day_id}">Day ${board205Esc(day.setup_day_number)} · ${board205Esc(day.day_of_week)} · ${board205Esc(day.work_date)}</option>`
    )).join('');
  }

  const stageSelect = document.getElementById('setup-board205-season-stage');
  if (stageSelect) {
    stageSelect.innerHTML = '<option value="">Site-wide / Infrastructure</option>' + (appState.stages || []).map((stage) => (
      `<option value="${stage.stage_id}">${board205Esc(stage.stage_key)} — ${board205Esc(stage.stage_name)}</option>`
    )).join('');
  }

  const taskOptions = '<option value="">— none —</option>' + (setupBoard205State.board.tasks || []).map((task) => (
    `<option value="${task.setup_session_task_id}">${board205Esc(task.planned_order ?? '—')} — ${board205Esc(task.task_name)}</option>`
  )).join('');
  const prior = document.getElementById('setup-board205-season-prereq');
  const downstream = document.getElementById('setup-board205-season-downstream');
  if (prior) prior.innerHTML = taskOptions;
  if (downstream) downstream.innerHTML = taskOptions;
  board205PopulateScenes();
}

function board205PopulateScenes() {
  const stageId = Number(document.getElementById('setup-board205-season-stage')?.value || 0);
  const scene = document.getElementById('setup-board205-season-scene');
  if (!scene) return;
  const scenes = (setupNextState?.scenes || []).filter((item) => Number(item.stage_id) === stageId);
  scene.innerHTML = '<option value="">Stage-level / General</option>' + scenes.map((item) => (
    `<option value="${item.lor_scene_id}">${board205Esc(item.scene_name)}</option>`
  )).join('');
  scene.disabled = !stageId;
}

function board205OpenScheduleDialog(target) {
  const dialog = document.getElementById('setup-board205-schedule-dialog');
  if (!dialog) return;
  setupBoard205State.scheduleTarget = target;
  board205PopulateDialogSelects();

  if (target.kind === 'assignment') {
    const item = board205Assignment(target.id);
    if (!item || item.historical_locked) return;
    document.getElementById('setup-board205-schedule-day').value = String(item.setup_work_day_id);
    document.getElementById('setup-board205-schedule-shift').value = item.shift_code;
    document.getElementById('setup-board205-schedule-lane').value = item.crew_lane;
    document.getElementById('setup-board205-schedule-crew').value = item.planned_crew_count ?? '';
  } else {
    const task = board205Task(target.id);
    document.getElementById('setup-board205-schedule-crew').value = task?.normal_crew_min ?? '';
  }
  dialog.showModal();
}

async function board205SubmitScheduleDialog(event) {
  event.preventDefault();
  const target = setupBoard205State.scheduleTarget;
  if (!target) return;
  const dayId = Number(document.getElementById('setup-board205-schedule-day').value || 0);
  const shift = document.getElementById('setup-board205-schedule-shift').value;
  const lane = document.getElementById('setup-board205-schedule-lane').value;
  const plannedCrew = nullableInteger(document.getElementById('setup-board205-schedule-crew').value);
  if (!dayId) return;

  const task = target.kind === 'task'
    ? board205Task(target.id)
    : board205Task(board205Assignment(target.id)?.setup_session_task_id);
  if (task?.board_status === 'BLOCKED' && !window.confirm('This task has an incomplete annual prerequisite. Schedule it anyway?')) return;

  try {
    setBusy(true);
    const sortOrder = board205EndSort(dayId, shift, lane);
    if (target.kind === 'task') {
      await api('api/setup/scheduling-board/assignments', commandOptions('POST', {
        setup_work_day_id: dayId,
        setup_session_task_id: target.id,
        shift_code: shift,
        crew_lane: lane,
        sort_order: sortOrder,
        planned_crew_count: plannedCrew
      }));
    } else {
      await api(`api/setup/scheduling-board/assignments/${target.id}`, commandOptions('PATCH', {
        setup_work_day_id: dayId,
        shift_code: shift,
        crew_lane: lane,
        sort_order: sortOrder,
        planned_crew_count: plannedCrew
      }));
    }
    document.getElementById('setup-board205-schedule-dialog').close();
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function board205AddWorkDay(event) {
  event.preventDefault();
  const date = document.getElementById('setup-board205-work-date').value;
  const dayNumber = nullableInteger(document.getElementById('setup-board205-day-number').value);
  const volunteerNote = document.getElementById('setup-board205-volunteer-note').value.trim() || null;
  if (!date) return;

  const parts = date.split('-').map(Number);
  const dow = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2])).getUTCDay();
  if (dow === 0 && !window.confirm('This is a Sunday. MSB normally avoids Sunday Setup work. Add it deliberately anyway?')) return;

  try {
    setBusy(true);
    await api('api/setup/scheduling-board/work-days', commandOptions('POST', {
      season_year: Number(appState.seasonYear),
      work_date: date,
      setup_day_number: dayNumber,
      day_status: 'PLANNED',
      volunteer_note: volunteerNote
    }));
    event.currentTarget.reset();
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function board205OpenSeasonTaskDialog(sessionTaskId = null) {
  const dialog = document.getElementById('setup-board205-season-dialog');
  const form = document.getElementById('setup-board205-season-form');
  if (!dialog || !form) return;
  form.reset();
  setupBoard205State.editSeasonTaskId = sessionTaskId;
  board205PopulateDialogSelects();

  const heading = document.getElementById('setup-board205-season-heading');
  const chain = document.getElementById('setup-board205-season-chain');
  if (sessionTaskId == null) {
    heading.textContent = `Add ${appState.seasonYear} Season Task`;
    chain.hidden = false;
  } else {
    const task = board205Task(sessionTaskId);
    if (!task || task.task_origin !== 'SEASON_ONLY') return;
    heading.textContent = `Edit ${appState.seasonYear} Season Task`;
    chain.hidden = true;
    document.getElementById('setup-board205-season-name').value = task.task_name || '';
    document.getElementById('setup-board205-season-stage').value = task.stage_id ?? '';
    board205PopulateScenes();
    document.getElementById('setup-board205-season-scene').value = task.lor_scene_id ?? '';
    document.getElementById('setup-board205-season-type').value = task.task_action_type || 'WORK';
    document.getElementById('setup-board205-season-work-order').value = task.linked_work_order_id ?? '';
    document.getElementById('setup-board205-season-gate').checked = Boolean(task.linked_work_order_gate);
    document.getElementById('setup-board205-season-crew-min').value = task.normal_crew_min ?? '';
    document.getElementById('setup-board205-season-crew-max').value = task.normal_crew_max ?? '';
    const total = Number(task.expected_duration_minutes || 0);
    document.getElementById('setup-board205-season-hours').value = total ? Math.floor(total / 60) : '';
    document.getElementById('setup-board205-season-minutes').value = total ? total % 60 : '';
    document.getElementById('setup-board205-season-completion').value = task.completion_point || '';
    document.getElementById('setup-board205-season-readiness').value = task.readiness_note || '';
    document.getElementById('setup-board205-season-notes').value = task.annual_notes || '';
  }
  dialog.showModal();
}

function board205SeasonMinutes() {
  const hours = Number(document.getElementById('setup-board205-season-hours').value || 0);
  const minutes = Number(document.getElementById('setup-board205-season-minutes').value || 0);
  if (hours < 0 || minutes < 0 || minutes > 59) {
    throw new Error('Expected Minutes must be between 0 and 59.');
  }
  const total = (hours * 60) + minutes;
  return total > 0 ? total : null;
}

async function board205SubmitSeasonTask(event) {
  event.preventDefault();
  const sessionTaskId = setupBoard205State.editSeasonTaskId;
  const taskName = document.getElementById('setup-board205-season-name').value.trim();
  const stageId = nullableInteger(document.getElementById('setup-board205-season-stage').value);
  const sceneId = nullableInteger(document.getElementById('setup-board205-season-scene').value);
  const workOrderId = nullableInteger(document.getElementById('setup-board205-season-work-order').value);
  const actionType = document.getElementById('setup-board205-season-type').value;
  const prior = nullableInteger(document.getElementById('setup-board205-season-prereq').value);
  const downstream = nullableInteger(document.getElementById('setup-board205-season-downstream').value);

  try {
    const duration = board205SeasonMinutes();
    let plannedOrder = null;
    if (prior) {
      const priorTask = board205Task(prior);
      const priorOrder = Number(priorTask?.planned_order ?? 0);
      if (downstream) {
        const downstreamTask = board205Task(downstream);
        const downstreamOrder = Number(downstreamTask?.planned_order ?? 0);
        plannedOrder = downstreamOrder > priorOrder + 1
          ? Math.floor((priorOrder + downstreamOrder) / 2)
          : priorOrder + 1;
      } else {
        plannedOrder = priorOrder + 1;
      }
    }

    const payload = {
      season_year: Number(appState.seasonYear),
      task_name: taskName,
      stage_id: stageId,
      lor_scene_id: sceneId,
      task_action_type: actionType,
      planned_order: plannedOrder,
      normal_crew_min: nullableInteger(document.getElementById('setup-board205-season-crew-min').value),
      normal_crew_max: nullableInteger(document.getElementById('setup-board205-season-crew-max').value),
      expected_duration_minutes: duration,
      completion_point: document.getElementById('setup-board205-season-completion').value.trim() || null,
      readiness_note: document.getElementById('setup-board205-season-readiness').value.trim() || null,
      linked_work_order_id: workOrderId,
      linked_work_order_gate: document.getElementById('setup-board205-season-gate').checked,
      annual_notes: document.getElementById('setup-board205-season-notes').value.trim() || null
    };

    setBusy(true);
    let targetId = sessionTaskId;
    if (sessionTaskId == null) {
      const result = await api('api/setup/scheduling-board/season-tasks', commandOptions('POST', payload));
      targetId = Number(result.season_task?.setup_session_task_id || 0);
      if (targetId && prior) {
        await api(`api/setup/scheduling-board/season-tasks/${targetId}/dependencies/${prior}`, commandOptions('PATCH', { active: true }));
      }
      if (targetId && downstream) {
        await api(`api/setup/scheduling-board/season-tasks/${downstream}/dependencies/${targetId}`, commandOptions('PATCH', { active: true }));
      }
    } else {
      await api(`api/setup/scheduling-board/season-tasks/${sessionTaskId}`, commandOptions('PATCH', payload));
    }
    document.getElementById('setup-board205-season-dialog').close();
    await board205Load();
    setAlert(sessionTaskId == null ? 'Season-only Setup task added.' : 'Season-only Setup task updated.', 'ok');
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function board205InstallView() {
  const view = document.getElementById('schedule-view');
  if (!view || document.getElementById('setup-board205-root')) return;

  view.innerHTML = `
    <div id="setup-board205-root" class="setup-board205-shell">
      <div class="card">
        <div class="setup-board205-toolbar">
          <div>
            <div class="eyebrow">Rolling annual dispatch · historical learning</div>
            <h2>Setup Scheduling Board</h2>
            <p class="muted">Plan only the next practical work days. Annual execution may teach the reusable Catalog later, but this board never changes reusable knowledge automatically.</p>
          </div>
          <button id="setup-board205-add-season-task" type="button" class="manager-only">Add Season Task</button>
        </div>
        <form id="setup-board205-day-form" class="setup-board205-day-form manager-only">
          <label>Date<input id="setup-board205-work-date" type="date" required></label>
          <label>Setup Day # <input id="setup-board205-day-number" type="number" min="1" placeholder="Auto"></label>
          <label class="setup-board205-volunteer-note">Volunteer / capacity note<input id="setup-board205-volunteer-note" type="text" placeholder="Optional, e.g. strong Saturday turnout expected"></label>
          <button type="submit">Add Work Day</button>
        </form>
      </div>

      <div id="setup-board205-no-session" class="card" hidden>
        <strong>No annual Setup Session exists for this season.</strong>
        <p class="muted">That is expected until the annual-session gate is accepted. The Reusable Catalog remains separate.</p>
      </div>

      <div id="setup-board205-workspace" class="setup-board205-main">
        <section class="card setup-board205-backlog">
          <div class="eyebrow">Annual work set</div>
          <h3>Needs Scheduling</h3>
          <div id="setup-board205-filters" class="setup-board205-filters">
            <label><input type="checkbox" value="READY_TO_SCHEDULE" checked> Ready</label>
            <label><input type="checkbox" value="NEEDS_SCHEDULING_AGAIN" checked> Needs Again</label>
            <label><input type="checkbox" value="BLOCKED" checked> Blocked</label>
            <label><input type="checkbox" value="WAITING_ON_WORK_ORDER" checked> WO Gate</label>
            <label><input type="checkbox" value="SCHEDULED"> Scheduled</label>
            <label><input type="checkbox" value="COMPLETE"> Complete</label>
            <label><input type="checkbox" value="DEFERRED"> Deferred</label>
          </div>
          <div id="setup-board205-queue" class="setup-board205-queue"></div>
        </section>

        <section class="card setup-board205-board">
          <div class="eyebrow">Setup Day Number · DOW · Date</div>
          <h3>Rolling Work Days</h3>
          <p class="muted">Drag work onto Crew A–D or use Schedule/Move controls. Stacked cards are the intended order within that crew/period. Historical actual assignments are locked.</p>
          <div id="setup-board205-days" class="setup-board205-days"></div>
        </section>
      </div>
    </div>

    <dialog id="setup-board205-schedule-dialog" class="setup-board205-dialog">
      <form id="setup-board205-schedule-dialog-form">
        <h3>Schedule Annual Task</h3>
        <div class="setup-board205-form-grid">
          <label>Setup Day<select id="setup-board205-schedule-day" required></select></label>
          <label>Work period<select id="setup-board205-schedule-shift"><option value="MORNING">Morning</option><option value="AFTERNOON">Afternoon</option><option value="ALL_DAY">All Day</option></select></label>
          <label>Crew lane<select id="setup-board205-schedule-lane"><option value="A">Crew A</option><option value="B">Crew B</option><option value="C">Crew C</option><option value="D">Crew D</option></select></label>
          <label>Planned crew<input id="setup-board205-schedule-crew" type="number" min="0"></label>
        </div>
        <menu><button type="button" class="secondary setup-board205-dialog-cancel">Cancel</button><button type="submit">Save Assignment</button></menu>
      </form>
    </dialog>

    <dialog id="setup-board205-season-dialog" class="setup-board205-dialog">
      <form id="setup-board205-season-form">
        <h3 id="setup-board205-season-heading">Add Season Task</h3>
        <p class="muted">Season-only work belongs to this annual Setup Session. It does not enter the Reusable Task Catalog unless explicitly reconciled and confirmed later.</p>
        <label>Task name<input id="setup-board205-season-name" type="text" required></label>
        <div class="setup-board205-form-grid">
          <label>Stage<select id="setup-board205-season-stage"></select></label>
          <label>Scene<select id="setup-board205-season-scene"></select></label>
          <label>Type<select id="setup-board205-season-type"><option value="WORK">Work</option><option value="GATE">Stop / Gate</option><option value="SUPPORT">Support</option><option value="UNLOAD_CONTAINER">Unload Container</option></select></label>
          <label>Existing Work Order ID<input id="setup-board205-season-work-order" type="number" min="1"></label>
          <label class="checkbox-label"><input id="setup-board205-season-gate" type="checkbox"> Work Order completion satisfies this gate</label>
          <span></span>
          <label>Crew min<input id="setup-board205-season-crew-min" type="number" min="0"></label>
          <label>Crew max<input id="setup-board205-season-crew-max" type="number" min="0"></label>
          <label>Expected hours<input id="setup-board205-season-hours" type="number" min="0"></label>
          <label>Expected minutes<input id="setup-board205-season-minutes" type="number" min="0" max="59"></label>
        </div>
        <label>Completion point<textarea id="setup-board205-season-completion" rows="2"></textarea></label>
        <label>Readiness / hold note<textarea id="setup-board205-season-readiness" rows="2"></textarea></label>
        <label>Annual notes<textarea id="setup-board205-season-notes" rows="3"></textarea></label>
        <div id="setup-board205-season-chain" class="setup-board205-form-grid">
          <label>Insert after / prerequisite<select id="setup-board205-season-prereq"></select></label>
          <label>Block downstream task<select id="setup-board205-season-downstream"></select></label>
        </div>
        <menu><button type="button" class="secondary setup-board205-dialog-cancel">Cancel</button><button type="submit">Save Season Task</button></menu>
      </form>
    </dialog>
  `;

  document.getElementById('setup-board205-filters').querySelectorAll('input').forEach((input) => input.addEventListener('change', board205RenderQueue));
  document.getElementById('setup-board205-day-form').addEventListener('submit', board205AddWorkDay);
  document.getElementById('setup-board205-add-season-task').addEventListener('click', () => board205OpenSeasonTaskDialog());
  document.getElementById('setup-board205-schedule-dialog-form').addEventListener('submit', board205SubmitScheduleDialog);
  document.getElementById('setup-board205-season-form').addEventListener('submit', board205SubmitSeasonTask);
  document.getElementById('setup-board205-season-stage').addEventListener('change', board205PopulateScenes);
  view.querySelectorAll('.setup-board205-dialog-cancel').forEach((button) => {
    button.addEventListener('click', () => button.closest('dialog')?.close());
  });
}

const board205PriorLoadSeason = loadSeason;
loadSeason = async function loadSeasonWithSchedulingBoard(year) {
  await board205PriorLoadSeason(year);
  if (document.getElementById('schedule-view')?.classList.contains('active-view')) {
    await board205Load();
  }
};

board205InstallView();
