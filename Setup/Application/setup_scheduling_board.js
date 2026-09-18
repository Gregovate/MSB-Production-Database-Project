/* Setup #205 rolling Scheduling Board.
   This upgrades the legacy V0.3 Plan / Schedule surface without changing the
   Reusable Task Catalog or the #132 Report Work implementation. */

const setupBoard205State = {
  board: { session: null, work_days: [], crews: [], captain_candidates: [], tasks: [], assignments: [], dependencies: [] },
  dragged: null,
  editSeasonTaskId: null,
  editPlanningTaskId: null,
  scheduleTarget: null
};

const SETUP_BOARD205_TYPICAL_AM_MINUTES = 180;

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

function board205CrewRow(crewId) {
  return (setupBoard205State.board.crews || []).find(
    (crew) => Number(crew.setup_work_day_crew_id) === Number(crewId)
  );
}

function board205CaptainCandidate(personId) {
  return (setupBoard205State.board.captain_candidates || []).find(
    (person) => Number(person.person_id) === Number(personId)
  );
}

function board205CaptainOptions(selectedPersonId = null) {
  const selected = selectedPersonId == null ? '' : String(selectedPersonId);
  return '<option value="">TBD</option>' + (setupBoard205State.board.captain_candidates || []).map((person) => (
    `<option value="${person.person_id}" ${String(person.person_id) === selected ? 'selected' : ''}>${board205Esc(person.display_name)}</option>`
  )).join('');
}

function board205TaskHasReusableCaptain(task, personId) {
  return (task?.reusable_captain_person_ids || []).some(
    (value) => Number(value) === Number(personId)
  );
}

function board205PlacementWarnings(task, crewId, shift) {
  const warnings = [];
  if (!task) return warnings;

  if (task.readiness_state === 'NOT_READY') {
    warnings.push(`Readiness is NOT READY${task.readiness_note ? `: ${task.readiness_note}` : ''}.`);
  }
  if (task.prerequisites_complete === false) {
    warnings.push('One or more hard predecessors are incomplete.');
  }

  const crew = board205CrewRow(crewId);
  const planned = board205PlannedCrewForShift(crew, shift);
  const minCrew = task.normal_crew_min == null ? null : Number(task.normal_crew_min);
  if (planned != null && minCrew != null && planned < minCrew) {
    const period = shift === 'MORNING' ? 'AM' : shift === 'AFTERNOON' ? 'PM' : 'selected';
    warnings.push(`SHORT CREW: planned ${period} crew ${planned} / task minimum ${minCrew} — short by ${minCrew - planned}.`);
  }

  return warnings;
}

function board205ConfirmPlacement(task, crewId, shift) {
  const warnings = board205PlacementWarnings(task, crewId, shift);
  if (!warnings.length) return true;
  return window.confirm(`${warnings.join('\n\n')}\n\nSchedule this task anyway?`);
}

async function board205MaybeLearnCaptainForTask(task, crewId, captainPersonId = null) {
  if (!task || task.task_origin !== 'REUSABLE') return;
  const crew = board205CrewRow(crewId);
  const personId = captainPersonId ?? crew?.captain_person_id;
  if (personId == null || board205TaskHasReusableCaptain(task, personId)) return;

  const person = board205CaptainCandidate(personId);
  const name = person?.display_name || crew?.captain_display_name || `Person ${personId}`;
  const crewCode = crew?.crew_code || '';
  const confirmed = window.confirm(
    `${name} is Captain of Crew ${crewCode || 'this crew'} but is not currently a reusable Captain for "${task.task_name}".\n\nOK = Add/promote ${name} as a reusable task Captain.\nCancel = Keep the schedule only.\n\nExisting Captains will remain.`
  );
  if (!confirmed) return;

  await api(
    `api/setup/scheduling-board/season-tasks/${task.setup_session_task_id}/crew-captain/${crewId}/promote`,
    commandOptions('POST', {})
  );
}

async function board205MaybeLearnCaptainForCrewAssignments(crewId, captainPersonId) {
  if (captainPersonId == null) return;
  const crew = board205CrewRow(crewId);
  const person = board205CaptainCandidate(captainPersonId);
  const name = person?.display_name || `Person ${captainPersonId}`;
  const taskMap = new Map();

  for (const item of board205CrewSequence(crewId)) {
    const task = board205Task(item.setup_session_task_id);
    if (!task || task.task_origin !== 'REUSABLE' || board205TaskHasReusableCaptain(task, captainPersonId)) continue;
    taskMap.set(Number(task.setup_session_task_id), task);
  }

  const tasks = [...taskMap.values()];
  if (!tasks.length) return;

  const confirmed = window.confirm(
    `${name} is now Captain of Crew ${crew?.crew_code || ''}.\n\nOK = Add/promote ${name} as a reusable Captain for ${tasks.length} reusable task${tasks.length === 1 ? '' : 's'} already assigned to this crew.\nCancel = Keep the Crew Captain assignment only.\n\nExisting Captains will remain.`
  );
  if (!confirmed) return;

  for (const task of tasks) {
    await api(
      `api/setup/scheduling-board/season-tasks/${task.setup_session_task_id}/crew-captain/${crewId}/promote`,
      commandOptions('POST', {})
    );
  }
}


function board205CrewsForDay(dayId) {
  return (setupBoard205State.board.crews || [])
    .filter((crew) => Number(crew.setup_work_day_id) === Number(dayId))
    .sort((a, b) => Number(a.crew_number) - Number(b.crew_number));
}

function board205PlannedCrewForShift(crew, shift) {
  if (!crew) return null;
  const raw = shift === 'MORNING'
    ? crew.am_planned_crew_count
    : shift === 'AFTERNOON'
      ? crew.pm_planned_crew_count
      : null;
  return raw == null ? null : Number(raw);
}

function board205Effort(task) {
  return task?.effort_level ? String(task.effort_level).toUpperCase() : 'EFFORT TBD';
}

function board205CrewSequence(crewId) {
  const rank = { MORNING: 1, AFTERNOON: 2, ALL_DAY: 3 };
  return (setupBoard205State.board.assignments || [])
    .filter((item) => Number(item.setup_work_day_crew_id) === Number(crewId))
    .sort((a, b) => (
      (rank[a.shift_code] || 9) - (rank[b.shift_code] || 9)
      || Number(a.sort_order) - Number(b.sort_order)
      || Number(a.setup_work_day_task_id) - Number(b.setup_work_day_task_id)
    ));
}

function board205AmCarryoverMinutes(crewId) {
  const items = board205CrewSequence(crewId).filter((item) => item.shift_code === 'MORNING');
  if (!items.length) return 0;
  let total = 0;
  for (const item of items) {
    const task = board205Task(item.setup_session_task_id) || item;
    const minutes = Number(task.expected_duration_minutes || 0);
    if (minutes <= 0) return null;
    total += minutes;
  }
  return Math.max(total - SETUP_BOARD205_TYPICAL_AM_MINUTES, 0);
}

function board205AssignmentSortKey(item) {
  const day = (setupBoard205State.board.work_days || []).find(
    (row) => Number(row.setup_work_day_id) === Number(item.setup_work_day_id)
  );
  const shiftRank = { MORNING: 1, AFTERNOON: 2, ALL_DAY: 3 };
  return [
    day?.work_date || item.work_date || '9999-12-31',
    shiftRank[item.shift_code] || 9,
    Number(item.sort_order) || 0,
    Number(item.setup_work_day_task_id) || 0
  ];
}

function board205CompareAssignmentOrder(a, b) {
  const ak = board205AssignmentSortKey(a);
  const bk = board205AssignmentSortKey(b);
  return ak[0].localeCompare(bk[0]) || ak[1] - bk[1] || ak[2] - bk[2] || ak[3] - bk[3];
}

function board205HeavyWarning(item) {
  const task = board205Task(item?.setup_session_task_id) || item;
  if (String(task?.effort_level || '').toUpperCase() !== 'HEAVY') return null;

  const crew = board205CrewRow(item.setup_work_day_crew_id);
  const captainId = crew?.captain_person_id == null ? null : Number(crew.captain_person_id);
  let sequence;

  if (captainId != null) {
    sequence = (setupBoard205State.board.assignments || [])
      .filter((row) => Number(board205CrewRow(row.setup_work_day_crew_id)?.captain_person_id) === captainId)
      .sort(board205CompareAssignmentOrder);
  } else {
    sequence = board205CrewSequence(item.setup_work_day_crew_id);
  }

  const index = sequence.findIndex(
    (row) => Number(row.setup_work_day_task_id) === Number(item.setup_work_day_task_id)
  );
  if (index <= 0) return null;

  const previous = sequence[index - 1];
  if (Number(previous.setup_session_task_id) === Number(item.setup_session_task_id)) return null;
  const previousTask = board205Task(previous.setup_session_task_id) || previous;
  if (String(previousTask?.effort_level || '').toUpperCase() !== 'HEAVY') return null;

  if (captainId != null) {
    return `HEAVY work follows HEAVY work for Captain ${crew?.captain_display_name || 'this Captain'}.`;
  }
  return 'HEAVY work follows HEAVY work for this crew.';
}

function board205Scope(task) {
  if (!task) return 'Unknown scope';
  if (task.stage_id == null) return 'Site-wide / Infrastructure';
  const stageName = task.stage_name ? ` — ${task.stage_name}` : '';
  const detail = task.scene_name ? ` / ${task.scene_name}` : ' / Stage-level';
  return `Stage ${task.stage_key || '—'}${stageName}${detail}`;
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
        <span class="setup-board205-badge effort-${board205Esc(String(task.effort_level || 'unknown').toLowerCase())}">${board205Esc(board205Effort(task))}</span>
        ${board205WorkOrderBadge(task)}
      </div>
      <div class="setup-board205-meta">${board205Esc(board205Scope(task))}</div>
      <div class="setup-board205-meta"><strong>Min crew:</strong> ${board205Esc(task.normal_crew_min ?? 'TBD')} · <strong>Expected:</strong> ${board205Esc(board205Duration(task.expected_duration_minutes))}</div>
      ${task.resource_summary ? `<div class="setup-board205-meta"><strong>Resources:</strong> ${board205Esc(task.resource_summary)}</div>` : ''}
      <div class="setup-board205-meta"><strong>Hard predecessor(s):</strong> ${board205Esc(depText)}</div>
      ${task.readiness_note ? `<div class="setup-board205-readiness ${task.readiness_state === 'NOT_READY' ? 'not-ready' : 'ready'}"><strong>Readiness:</strong> ${board205Esc(task.readiness_note)} · <strong>${board205Esc(task.readiness_state || 'READY')}</strong></div>` : ''}
      <div class="setup-board205-card-actions">
        ${canSchedule ? '<button type="button" class="small setup-board205-schedule-task">Schedule…</button>' : ''}
        ${canManage && task.readiness_note ? `<button type="button" class="small secondary setup-board205-toggle-readiness">${task.readiness_state === 'NOT_READY' ? 'Mark Ready' : 'Mark Not Ready'}</button>` : ''}
        ${canManage && !task.progress_entries && !task.effective_complete ? '<button type="button" class="small secondary setup-board205-edit-planning-info">Edit Planning Info</button>' : ''}
        ${canManage && seasonOnly ? '<button type="button" class="small secondary setup-board205-edit-season-task">Edit season task</button>' : ''}
        ${canManage ? `
          <button type="button" class="small secondary setup-board205-plan-up">Plan ↑</button>
          <button type="button" class="small secondary setup-board205-plan-down">Plan ↓</button>` : ''}
      </div>
    </article>`;
}


function board205QueueTasks() {
  const mode = document.getElementById('setup-board205-view-mode')?.value || 'AVAILABLE';
  const search = (document.getElementById('setup-board205-task-search')?.value || '').trim().toLowerCase();
  const hoursValue = Number(document.getElementById('setup-board205-time-filter')?.value || 0);
  const minutesValue = hoursValue > 0 ? hoursValue * 60 : null;
  const timeOp = document.getElementById('setup-board205-time-op')?.value || 'LTE';
  const crewValue = Number(document.getElementById('setup-board205-crew-filter')?.value || 0);
  const crewOp = document.getElementById('setup-board205-crew-op')?.value || 'LTE';
  const effort = document.getElementById('setup-board205-effort-filter')?.value || '';

  const modes = {
    AVAILABLE: new Set(['READY_TO_SCHEDULE', 'NEEDS_SCHEDULING_AGAIN']),
    OUTSTANDING: new Set(['BLOCKED', 'WAITING_ON_WORK_ORDER']),
    SCHEDULED: new Set(['SCHEDULED']),
    COMPLETE: new Set(['COMPLETE']),
    ALL: null
  };
  const statuses = modes[mode] ?? modes.AVAILABLE;

  return [...(setupBoard205State.board.tasks || [])]
    .filter((task) => {
      if (statuses && !statuses.has(task.board_status)) return false;
      if (search) {
        const haystack = [
          task.task_name,
          task.stage_key,
          task.stage_name,
          task.scene_name,
          task.readiness_note,
          task.resource_summary,
          task.linked_work_order_id ? `WO ${task.linked_work_order_id}` : ''
        ].filter(Boolean).join(' ').toLowerCase();
        if (!haystack.includes(search)) return false;
      }
      if (minutesValue != null) {
        if (task.expected_duration_minutes == null) return false;
        const duration = Number(task.expected_duration_minutes);
        if (timeOp === 'GTE' ? duration < minutesValue : duration > minutesValue) return false;
      }
      if (crewValue > 0) {
        if (task.normal_crew_min == null) return false;
        const crewMin = Number(task.normal_crew_min);
        if (crewOp === 'GTE' ? crewMin < crewValue : crewMin > crewValue) return false;
      }
      if (effort && String(task.effort_level || '').toUpperCase() !== effort) return false;
      return true;
    })
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
    card.querySelector('.setup-board205-toggle-readiness')?.addEventListener('click', () => {
      board205SetReadiness(task);
    });
    card.querySelector('.setup-board205-edit-planning-info')?.addEventListener('click', () => {
      board205OpenPlanningInfoDialog(taskId);
    });
    card.querySelector('.setup-board205-edit-season-task')?.addEventListener('click', () => {
      board205OpenSeasonTaskDialog(taskId);
    });
    card.querySelector('.setup-board205-plan-up')?.addEventListener('click', () => board205MoveAnnualOrder(taskId, -1));
    card.querySelector('.setup-board205-plan-down')?.addEventListener('click', () => board205MoveAnnualOrder(taskId, 1));
  });
}


function board205AssignmentsFor(dayId, shift, crewId) {
  return (setupBoard205State.board.assignments || [])
    .filter((item) => (
      Number(item.setup_work_day_id) === Number(dayId)
      && item.shift_code === shift
      && Number(item.setup_work_day_crew_id) === Number(crewId)
    ))
    .sort((a, b) => (
      Number(a.sort_order) - Number(b.sort_order)
      || Number(a.setup_work_day_task_id) - Number(b.setup_work_day_task_id)
    ));
}



function board205AssignmentCard(item) {
  const task = board205Task(item.setup_session_task_id) || item;
  const crew = board205CrewRow(item.setup_work_day_crew_id);
  const canManage = Boolean(appState.access?.can_manage_setup);
  const locked = Boolean(item.historical_locked);
  const planned = board205PlannedCrewForShift(crew, item.shift_code);
  const minCrew = task.normal_crew_min == null ? null : Number(task.normal_crew_min);
  const understaffed = planned != null && minCrew != null && planned < minCrew;
  const shortBy = understaffed ? minCrew - planned : 0;
  const heavyWarning = board205HeavyWarning(item);
  return `
    <article class="setup-board205-assignment ${locked ? 'locked' : ''} ${understaffed ? 'short-crew' : ''}"
      data-assignment-id="${item.setup_work_day_task_id}"
      draggable="${canManage && !locked ? 'true' : 'false'}">
      <div class="setup-board205-task-title">
        <span>${board205Esc(item.task_name)}</span>
        ${task.task_origin === 'SEASON_ONLY' ? '<span class="setup-board205-badge season-only">THIS SEASON ONLY</span>' : ''}
        <span class="setup-board205-badge effort-${board205Esc(String(task.effort_level || 'unknown').toLowerCase())}">${board205Esc(board205Effort(task))}</span>
        ${understaffed ? '<span class="setup-board205-badge short-crew-badge">SHORT CREW</span>' : ''}
        ${board205WorkOrderBadge(task)}
      </div>
      <div class="setup-board205-meta">${board205Esc(board205Scope(item))}</div>
      <div class="setup-board205-meta">Min crew ${board205Esc(minCrew ?? 'TBD')} · ${board205Esc(board205Duration(task.expected_duration_minutes))}</div>
      <div class="setup-board205-meta"><strong>Crew Captain:</strong> ${board205Esc(crew?.captain_display_name || 'TBD')}</div>
      ${task.readiness_state === 'NOT_READY' ? `<div class="setup-board205-warning">⚠ Readiness not met: ${board205Esc(task.readiness_note || 'annual readiness condition')}</div>` : ''}
      ${understaffed ? `<div class="setup-board205-warning setup-board205-short-crew-warning"><strong>SHORT CREW</strong> · Planned ${board205Esc(item.shift_code === 'MORNING' ? 'AM' : 'PM')} ${board205Esc(planned)} / minimum ${board205Esc(minCrew)} · short by ${board205Esc(shortBy)}.</div>` : ''}
      ${heavyWarning ? `<div class="setup-board205-warning">⚠ ${board205Esc(heavyWarning)}</div>` : ''}
      ${locked ? '<div class="setup-board205-lock">Historical actual — locked</div>' : ''}
      ${canManage && !locked ? `
        <div class="setup-board205-card-actions">
          <button type="button" class="small secondary setup-board205-up">↑</button>
          <button type="button" class="small secondary setup-board205-down">↓</button>
          <button type="button" class="small secondary setup-board205-move">Move…</button>
          ${!task.progress_entries && !task.effective_complete ? '<button type="button" class="small secondary setup-board205-edit-planning-info">Edit Info</button>' : ''}
          <button type="button" class="small secondary setup-board205-remove">Remove</button>
        </div>` : ''}
    </article>`;
}

function board205Cell(day, shift, crew) {
  const items = board205AssignmentsFor(day.setup_work_day_id, shift, crew.setup_work_day_crew_id);
  const carryover = shift === 'AFTERNOON'
    ? board205AmCarryoverMinutes(crew.setup_work_day_crew_id)
    : 0;
  const carryoverNote = shift === 'AFTERNOON' && carryover > 0
    ? `<div class="setup-board205-carryover">≈ ${board205Esc(board205Duration(carryover))} of AM work carries past lunch into PM.</div>`
    : '';
  return `
    <div class="setup-board205-cell"
      data-day-id="${day.setup_work_day_id}" data-shift="${shift}" data-crew-id="${crew.setup_work_day_crew_id}">
      ${carryoverNote}
      ${items.length ? items.map(board205AssignmentCard).join('') : '<div class="setup-board205-cell-empty">Drop work here</div>'}
    </div>`;
}



function board205Day(day) {
  const dayClass = Number(day.iso_day_of_week) === 6 ? 'saturday' : Number(day.iso_day_of_week) === 7 ? 'sunday' : '';
  const dayNote = [day.volunteer_note, day.weather_note, day.notes].filter(Boolean).join(' · ');
  const crews = board205CrewsForDay(day.setup_work_day_id);
  const canManage = Boolean(appState.access?.can_manage_setup);
  const crewRows = crews.map((crew) => {
    const legacy = board205AssignmentsFor(day.setup_work_day_id, 'ALL_DAY', crew.setup_work_day_crew_id);
    return `
      <div class="setup-board205-crew-label" data-crew-id="${crew.setup_work_day_crew_id}">
        <strong>Crew ${board205Esc(crew.crew_code)}</strong>
        <label class="setup-board205-crew-captain">Captain
          <select class="setup-board205-crew-captain-select">${board205CaptainOptions(crew.captain_person_id)}</select>
        </label>
        <div class="setup-board205-crew-counts">
          <label>AM <input class="setup-board205-crew-am" type="number" min="0" value="${board205Esc(crew.am_planned_crew_count ?? '')}" placeholder="—"></label>
          <label>PM <input class="setup-board205-crew-pm" type="number" min="0" value="${board205Esc(crew.pm_planned_crew_count ?? '')}" placeholder="—"></label>
        </div>
        ${canManage ? `<div class="setup-board205-crew-actions"><button type="button" class="small secondary setup-board205-save-crew">Save</button>${Number(crew.crew_number) > 1 ? '<button type="button" class="small secondary setup-board205-remove-crew">Remove</button>' : ''}</div>` : ''}
      </div>
      ${board205Cell(day, 'MORNING', crew)}
      ${board205Cell(day, 'AFTERNOON', crew)}
      ${legacy.length ? `
        <div class="setup-board205-crew-label setup-board205-legacy-label">Crew ${board205Esc(crew.crew_code)} · Legacy All Day</div>
        <div class="setup-board205-legacy-all-day">${legacy.map(board205AssignmentCard).join('')}</div>` : ''}
    `;
  }).join('');

  return `
    <section class="setup-board205-day ${dayClass}" data-day-id="${day.setup_work_day_id}">
      <div class="setup-board205-day-header">
        <div>
          <strong>Day ${board205Esc(day.setup_day_number)} · ${board205Esc(day.day_of_week)} · ${board205Esc(day.work_date)}</strong>
          ${Number(day.iso_day_of_week) === 6 ? '<div class="setup-board205-day-note">Saturday · typically stronger volunteer turnout</div>' : ''}
          ${Number(day.iso_day_of_week) === 7 ? '<div class="setup-board205-sunday-warning">Sunday · avoid scheduling unless deliberately needed</div>' : ''}
          ${dayNote ? `<div class="setup-board205-day-note">${board205Esc(dayNote)}</div>` : ''}
        </div>
        <div class="setup-board205-day-actions">
          <span class="setup-board205-badge">${board205Esc(day.day_status)}</span>
          ${canManage ? '<button type="button" class="small setup-board205-add-crew">+ Add Crew</button>' : ''}
        </div>
      </div>
      <div class="setup-board205-table-wrap">
        <div class="setup-board205-grid">
          <div class="setup-board205-grid-head">Crew / Captain / planned availability</div>
          <div class="setup-board205-grid-head">AM <span class="setup-board205-shift-hint">≈ 9–12</span></div>
          <div class="setup-board205-grid-head">PM <span class="setup-board205-shift-hint">after lunch ≈ 1 PM</span></div>
          ${crewRows}
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
        Number(cell.dataset.crewId),
        null
      );
    });
  });

  target.querySelectorAll('.setup-board205-day').forEach((dayNode) => {
    const dayId = Number(dayNode.dataset.dayId);
    dayNode.querySelector('.setup-board205-add-crew')?.addEventListener('click', () => board205AddCrew(dayId));
    dayNode.querySelectorAll('.setup-board205-crew-label[data-crew-id]').forEach((crewNode) => {
      const crewId = Number(crewNode.dataset.crewId);
      crewNode.querySelector('.setup-board205-save-crew')?.addEventListener('click', () => board205SaveCrew(crewId, crewNode));
      crewNode.querySelector('.setup-board205-remove-crew')?.addEventListener('click', () => board205RemoveCrew(crewId));
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
        item.shift_code === 'ALL_DAY' ? 'MORNING' : item.shift_code,
        Number(item.setup_work_day_crew_id),
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
    card.querySelector('.setup-board205-edit-planning-info')?.addEventListener('click', () => {
      board205OpenPlanningInfoDialog(item.setup_session_task_id);
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
    setupBoard205State.board = payload.board || { session: null, work_days: [], crews: [], captain_candidates: [], tasks: [], assignments: [], dependencies: [] };
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


async function board205SetReadiness(task) {
  if (!task || !appState.access?.can_manage_setup) return;
  const ready = task.readiness_state === 'NOT_READY';
  try {
    setBusy(true);
    await api(`api/setup/scheduling-board/season-tasks/${task.setup_session_task_id}/readiness`, commandOptions('PATCH', {
      ready
    }));
    await board205Load();
    setAlert(ready ? 'Annual readiness marked Ready.' : 'Annual readiness marked Not Ready.', 'ok');
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function board205AddCrew(dayId) {
  try {
    setBusy(true);
    await api(`api/setup/scheduling-board/work-days/${dayId}/crews`, commandOptions('POST', {}));
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function board205SaveCrew(crewId, crewNode) {
  const captainPersonId = nullableInteger(
    crewNode.querySelector('.setup-board205-crew-captain-select')?.value
  );
  try {
    setBusy(true);
    await api(`api/setup/scheduling-board/crews/${crewId}`, commandOptions('PATCH', {
      am_planned_crew_count: nullableInteger(crewNode.querySelector('.setup-board205-crew-am')?.value),
      pm_planned_crew_count: nullableInteger(crewNode.querySelector('.setup-board205-crew-pm')?.value),
      captain_person_id: captainPersonId
    }));
    await board205MaybeLearnCaptainForCrewAssignments(crewId, captainPersonId);
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function board205RemoveCrew(crewId) {
  const crew = board205CrewRow(crewId);
  if (!crew) return;
  if (!window.confirm(`Remove Crew ${crew.crew_code} from this work day? Only empty crews can be removed.`)) return;
  try {
    setBusy(true);
    await api(`api/setup/scheduling-board/crews/${crewId}`, commandOptions('DELETE'));
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}


function board205EndSort(dayId, shift, crewId) {
  const items = board205AssignmentsFor(dayId, shift, crewId);
  return items.length ? Math.max(...items.map((item) => Number(item.sort_order) || 0)) + 10 : 10;
}

async function board205DropToCell(dragged, dayId, shift, crewId, requestedSort) {
  if (!dragged || !appState.access?.can_manage_setup) return;
  const sortOrder = requestedSort == null ? board205EndSort(dayId, shift, crewId) : requestedSort;
  try {
    setBusy(true);
    let task = null;
    if (dragged.kind === 'task') {
      task = board205Task(dragged.id);
      if (!task || task.effective_complete || task.task_action_type === 'GATE') return;
      if (!board205ConfirmPlacement(task, crewId, shift)) return;
      await api('api/setup/scheduling-board/assignments', commandOptions('POST', {
        setup_work_day_id: dayId,
        setup_session_task_id: task.setup_session_task_id,
        shift_code: shift,
        setup_work_day_crew_id: crewId,
        sort_order: sortOrder
      }));
    } else if (dragged.kind === 'assignment') {
      const item = board205Assignment(dragged.id);
      if (!item || item.historical_locked) return;
      task = board205Task(item.setup_session_task_id);
      const changedPlacement = (
        Number(item.setup_work_day_id) !== Number(dayId)
        || String(item.shift_code === 'ALL_DAY' ? 'MORNING' : item.shift_code) !== String(shift)
        || Number(item.setup_work_day_crew_id) !== Number(crewId)
      );
      if (changedPlacement && !board205ConfirmPlacement(task, crewId, shift)) return;
      await api(`api/setup/scheduling-board/assignments/${item.setup_work_day_task_id}`, commandOptions('PATCH', {
        setup_work_day_id: dayId,
        shift_code: shift,
        setup_work_day_crew_id: crewId,
        sort_order: sortOrder
      }));
    }
    if (task) await board205MaybeLearnCaptainForTask(task, crewId);
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
  const peers = board205AssignmentsFor(item.setup_work_day_id, item.shift_code, item.setup_work_day_crew_id);
  const index = peers.findIndex((row) => Number(row.setup_work_day_task_id) === Number(item.setup_work_day_task_id));
  const neighbor = peers[index + direction];
  if (!neighbor) return;
  const newSort = direction < 0
    ? Number(neighbor.sort_order) - 1
    : Number(neighbor.sort_order) + 1;
  try {
    await api(`api/setup/scheduling-board/assignments/${item.setup_work_day_task_id}`, commandOptions('PATCH', {
      setup_work_day_id: item.setup_work_day_id,
      shift_code: item.shift_code === 'ALL_DAY' ? 'MORNING' : item.shift_code,
      setup_work_day_crew_id: item.setup_work_day_crew_id,
      sort_order: newSort
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
    board205PopulateCrewSelect(Number(daySelect.value || 0));
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

function board205PopulateCrewSelect(dayId, selectedCrewId = null) {
  const crewSelect = document.getElementById('setup-board205-schedule-crew');
  if (!crewSelect) return;
  const crews = board205CrewsForDay(dayId);
  crewSelect.innerHTML = crews.map((crew) => (
    `<option value="${crew.setup_work_day_crew_id}">Crew ${board205Esc(crew.crew_code)}</option>`
  )).join('');
  if (selectedCrewId != null) crewSelect.value = String(selectedCrewId);
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

  const daySelect = document.getElementById('setup-board205-schedule-day');
  if (target.kind === 'assignment') {
    const item = board205Assignment(target.id);
    if (!item || item.historical_locked) return;
    daySelect.value = String(item.setup_work_day_id);
    board205PopulateCrewSelect(item.setup_work_day_id, item.setup_work_day_crew_id);
    document.getElementById('setup-board205-schedule-shift').value = item.shift_code === 'ALL_DAY' ? 'MORNING' : item.shift_code;
  } else {
    board205PopulateCrewSelect(Number(daySelect.value || 0));
  }
  dialog.showModal();
}

async function board205SubmitScheduleDialog(event) {
  event.preventDefault();
  const target = setupBoard205State.scheduleTarget;
  if (!target) return;
  const dayId = Number(document.getElementById('setup-board205-schedule-day').value || 0);
  const shift = document.getElementById('setup-board205-schedule-shift').value;
  const crewId = Number(document.getElementById('setup-board205-schedule-crew').value || 0);
  if (!dayId || !crewId) return;

  const item = target.kind === 'assignment' ? board205Assignment(target.id) : null;
  const task = target.kind === 'task'
    ? board205Task(target.id)
    : board205Task(item?.setup_session_task_id);
  const changedPlacement = target.kind === 'task' || (
    item
    && (
      Number(item.setup_work_day_id) !== Number(dayId)
      || String(item.shift_code === 'ALL_DAY' ? 'MORNING' : item.shift_code) !== String(shift)
      || Number(item.setup_work_day_crew_id) !== Number(crewId)
    )
  );
  if (changedPlacement && !board205ConfirmPlacement(task, crewId, shift)) return;

  try {
    setBusy(true);
    const sortOrder = board205EndSort(dayId, shift, crewId);
    if (target.kind === 'task') {
      await api('api/setup/scheduling-board/assignments', commandOptions('POST', {
        setup_work_day_id: dayId,
        setup_session_task_id: target.id,
        shift_code: shift,
        setup_work_day_crew_id: crewId,
        sort_order: sortOrder
      }));
    } else {
      await api(`api/setup/scheduling-board/assignments/${target.id}`, commandOptions('PATCH', {
        setup_work_day_id: dayId,
        shift_code: shift,
        setup_work_day_crew_id: crewId,
        sort_order: sortOrder
      }));
    }
    if (task) await board205MaybeLearnCaptainForTask(task, crewId);
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
  const form = event.currentTarget;
  const date = document.getElementById('setup-board205-work-date').value;
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
      setup_day_number: null,
      day_status: 'PLANNED',
      volunteer_note: volunteerNote
    }));
    form.reset();
    await board205Load();
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}


function board205OpenPlanningInfoDialog(sessionTaskId) {
  const task = board205Task(sessionTaskId);
  const dialog = document.getElementById('setup-board205-planning-dialog');
  const form = document.getElementById('setup-board205-planning-form');
  if (!task || !dialog || !form) return;

  setupBoard205State.editPlanningTaskId = sessionTaskId;
  form.reset();
  document.getElementById('setup-board205-planning-heading').textContent = `Edit Planning Info — ${task.task_name}`;
  document.getElementById('setup-board205-planning-origin').textContent = task.task_origin === 'REUSABLE'
    ? 'Updates reusable task knowledge and refreshes this annual snapshot.'
    : 'Updates this season-only annual task only.';
  document.getElementById('setup-board205-planning-crew-min').value = task.normal_crew_min ?? '';
  document.getElementById('setup-board205-planning-crew-max').value = task.normal_crew_max ?? '';
  const total = Number(task.expected_duration_minutes || 0);
  document.getElementById('setup-board205-planning-hours').value = total ? Math.floor(total / 60) : '';
  document.getElementById('setup-board205-planning-minutes').value = total ? total % 60 : '';
  document.getElementById('setup-board205-planning-effort').value = task.effort_level || '';
  document.getElementById('setup-board205-planning-readiness').value = task.readiness_note || '';
  document.getElementById('setup-board205-planning-weather').value = task.weather_note || '';
  document.getElementById('setup-board205-planning-completion').value = task.completion_point || '';
  dialog.showModal();
}

function board205PlanningMinutes() {
  const hours = nullableInteger(document.getElementById('setup-board205-planning-hours').value) || 0;
  const minutes = nullableInteger(document.getElementById('setup-board205-planning-minutes').value) || 0;
  const total = hours * 60 + minutes;
  return total > 0 ? total : null;
}

async function board205SubmitPlanningInfo(event) {
  event.preventDefault();
  const sessionTaskId = setupBoard205State.editPlanningTaskId;
  if (!sessionTaskId) return;

  try {
    setBusy(true);
    await api(`api/setup/scheduling-board/season-tasks/${sessionTaskId}/planning-info`, commandOptions('PATCH', {
      normal_crew_min: nullableInteger(document.getElementById('setup-board205-planning-crew-min').value),
      normal_crew_max: nullableInteger(document.getElementById('setup-board205-planning-crew-max').value),
      expected_duration_minutes: board205PlanningMinutes(),
      effort_level: document.getElementById('setup-board205-planning-effort').value || null,
      readiness_note: document.getElementById('setup-board205-planning-readiness').value.trim() || null,
      weather_note: document.getElementById('setup-board205-planning-weather').value.trim() || null,
      completion_point: document.getElementById('setup-board205-planning-completion').value.trim() || null
    }));
    document.getElementById('setup-board205-planning-dialog').close();
    await board205Load();
    setAlert('Scheduling planning information updated.', 'ok');
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
    document.getElementById('setup-board205-season-effort').value = task.effort_level || '';
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
      effort_level: document.getElementById('setup-board205-season-effort').value || null,
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
          <div class="setup-board205-auto-day-note">Setup Day # is assigned automatically in chronological order.</div>
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
          <div id="setup-board205-filters" class="setup-board205-filters setup-board205-finder">
            <label>View<select id="setup-board205-view-mode">
              <option value="AVAILABLE">Available Now / Needs Continuation</option>
              <option value="OUTSTANDING">Outstanding / Blocked</option>
              <option value="SCHEDULED">Scheduled</option>
              <option value="COMPLETE">Complete</option>
              <option value="ALL">All annual work</option>
            </select></label>
            <label class="setup-board205-search">Task<input id="setup-board205-task-search" type="search" placeholder="Name, Stage, Scene, readiness, resource, WO"></label>
            <label class="setup-board205-numeric-filter">Time
              <span><select id="setup-board205-time-op" aria-label="Time comparator"><option value="LTE">≤</option><option value="GTE">≥</option></select><input id="setup-board205-time-filter" type="number" min="0" step="0.25" placeholder="Any" aria-label="Time hours"></span>
            </label>
            <label class="setup-board205-numeric-filter">Min crew
              <span><select id="setup-board205-crew-op" aria-label="Crew comparator"><option value="LTE">≤</option><option value="GTE">≥</option></select><input id="setup-board205-crew-filter" type="number" min="1" step="1" placeholder="Any" aria-label="Minimum crew"></span>
            </label>
            <label>Effort<select id="setup-board205-effort-filter">
              <option value="">Any</option>
              <option value="LIGHT">Light</option>
              <option value="MODERATE">Moderate</option>
              <option value="HEAVY">Heavy</option>
            </select></label>
          </div>
          <div id="setup-board205-queue" class="setup-board205-queue"></div>
        </section>

        <section class="card setup-board205-board">
          <div class="eyebrow">Setup Day Number · DOW · Date</div>
          <h3>Rolling Work Days</h3>
          <p class="muted">Each work day starts with Crew A. Add crews only when needed. Schedule in AM/PM shifts; planned headcount is optional by crew and shift. Historical actual assignments are locked.</p>
          <div id="setup-board205-days" class="setup-board205-days"></div>
        </section>
      </div>
    </div>

    <dialog id="setup-board205-schedule-dialog" class="setup-board205-dialog">
      <form id="setup-board205-schedule-dialog-form">
        <h3>Schedule Annual Task</h3>
        <div class="setup-board205-form-grid">
          <label>Setup Day<select id="setup-board205-schedule-day" required></select></label>
          <label>Work period<select id="setup-board205-schedule-shift"><option value="MORNING">Morning</option><option value="AFTERNOON">Afternoon</option></select></label>
          <label>Crew<select id="setup-board205-schedule-crew" required></select></label>
        </div>
        <menu><button type="button" class="secondary setup-board205-dialog-cancel">Cancel</button><button type="submit">Save Assignment</button></menu>
      </form>
    </dialog>

    <dialog id="setup-board205-planning-dialog" class="setup-board205-dialog">
      <form id="setup-board205-planning-form">
        <h3 id="setup-board205-planning-heading">Edit Planning Info</h3>
        <p id="setup-board205-planning-origin" class="muted"></p>
        <div class="setup-board205-form-grid">
          <label>Crew min<input id="setup-board205-planning-crew-min" type="number" min="0"></label>
          <label>Crew max<input id="setup-board205-planning-crew-max" type="number" min="0"></label>
          <label>Expected hours<input id="setup-board205-planning-hours" type="number" min="0" step="1"></label>
          <label>Expected minutes<input id="setup-board205-planning-minutes" type="number" min="0" max="59" step="1"></label>
          <label>Effort<select id="setup-board205-planning-effort"><option value="">Not reviewed</option><option value="LIGHT">Light</option><option value="MODERATE">Moderate</option><option value="HEAVY">Heavy</option></select></label>
        </div>
        <label>Readiness condition<textarea id="setup-board205-planning-readiness" rows="2"></textarea></label>
        <label>Weather note<textarea id="setup-board205-planning-weather" rows="2"></textarea></label>
        <label>Complete when<textarea id="setup-board205-planning-completion" rows="2"></textarea></label>
        <menu><button type="button" class="secondary setup-board205-dialog-cancel">Cancel</button><button type="submit">Save Planning Info</button></menu>
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
          <label>Effort<select id="setup-board205-season-effort"><option value="">Not reviewed</option><option value="LIGHT">Light</option><option value="MODERATE">Moderate</option><option value="HEAVY">Heavy</option></select></label>
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

  document.querySelectorAll('#setup-board205-filters input, #setup-board205-filters select').forEach((control) => {
    control.addEventListener(control.type === 'search' ? 'input' : 'change', board205RenderQueue);
    if (control.type === 'number') control.addEventListener('input', board205RenderQueue);
  });
  document.getElementById('setup-board205-day-form').addEventListener('submit', board205AddWorkDay);
  document.getElementById('setup-board205-add-season-task').addEventListener('click', () => board205OpenSeasonTaskDialog());
  document.getElementById('setup-board205-schedule-dialog-form').addEventListener('submit', board205SubmitScheduleDialog);
  document.getElementById('setup-board205-schedule-day').addEventListener('change', (event) => {
    board205PopulateCrewSelect(Number(event.currentTarget.value || 0));
  });
  document.getElementById('setup-board205-planning-form').addEventListener('submit', board205SubmitPlanningInfo);
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
