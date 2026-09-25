/* Setup #205 rolling Scheduling Board.
   This upgrades the legacy V0.3 Plan / Schedule surface without changing the
   Reusable Task Catalog or the #132 Report Work implementation. */

const setupBoard205State = {
  board: { session: null, work_days: [], crews: [], captain_candidates: [], work_orders: [], tasks: [], assignments: [], dependencies: [] },
  dragged: null,
  editSeasonTaskId: null,
  editPlanningTaskId: null,
  editPlanningReusableTaskId: null,
  scheduleTarget: null,
  finderCompact: null,
  workDaySelection: new Set(),
  workDayCalendarMonth: null,
  workDayPickerExpanded: false
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
  const planned = board205PlacementCrewCount(crewId, shift);
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

function board205PlacementCrewCount(crewId, shift) {
  const crewNode = document.querySelector(
    `.setup-board205-crew-label[data-crew-id="${Number(crewId)}"]`
  );
  const selector = shift === 'MORNING'
    ? '.setup-board205-crew-am'
    : shift === 'AFTERNOON'
      ? '.setup-board205-crew-pm'
      : null;
  if (crewNode && selector) {
    const value = crewNode.querySelector(selector)?.value;
    if (value !== '' && value != null) return Number(value);
  }
  return board205PlannedCrewForShift(board205CrewRow(crewId), shift);
}

function board205CrewCapacityWarnings(crewId, amCount, pmCount) {
  const warnings = [];
  for (const item of board205CrewSequence(crewId)) {
    const task = board205Task(item.setup_session_task_id);
    if (!task || task.normal_crew_min == null) continue;
    const minCrew = Number(task.normal_crew_min);
    const planned = item.shift_code === 'MORNING'
      ? amCount
      : item.shift_code === 'AFTERNOON'
        ? pmCount
        : null;
    if (planned == null || planned >= minCrew) continue;
    const period = item.shift_code === 'MORNING' ? 'AM' : 'PM';
    warnings.push(
      `${task.task_name}: planned ${period} crew ${planned} / task minimum ${minCrew} — short by ${minCrew - planned}.`
    );
  }
  return warnings;
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

function board205TodayKey() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function board205DayAssignments(day) {
  if (!day) return [];
  return (setupBoard205State.board.assignments || []).filter(
    (item) => Number(item.setup_work_day_id) === Number(day.setup_work_day_id)
  );
}

function board205ExistingWorkDayDates() {
  return new Set(
    (setupBoard205State.board.work_days || [])
      .map((day) => String(day.work_date || '').slice(0, 10))
      .filter(Boolean)
  );
}

function board205CalendarMonthStart() {
  if (setupBoard205State.workDayCalendarMonth) {
    return new Date(setupBoard205State.workDayCalendarMonth + '-01T00:00:00Z');
  }
  const today = new Date();
  const seasonYear = Number(appState.seasonYear);
  const existing = (setupBoard205State.board.work_days || [])
    .map((day) => String(day.work_date || '').slice(0, 7))
    .filter((value) => value.startsWith(String(seasonYear) + '-'))
    .sort();
  const month = existing.at(-1)
    || (today.getUTCFullYear() === seasonYear
      ? String(seasonYear) + '-' + String(today.getUTCMonth() + 1).padStart(2, '0')
      : String(seasonYear) + '-01');
  setupBoard205State.workDayCalendarMonth = month;
  return new Date(month + '-01T00:00:00Z');
}

function board205ApplyWorkDayPickerExpanded() {
  const form = document.getElementById('setup-board205-day-form');
  const body = document.getElementById('setup-board205-work-day-picker-body');
  const toggle = document.getElementById('setup-board205-toggle-work-days');
  if (!form || !body || !toggle) return;
  const expanded = Boolean(setupBoard205State.workDayPickerExpanded);
  form.classList.toggle('expanded', expanded);
  body.hidden = !expanded;
  toggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
  toggle.textContent = expanded ? 'Hide Work Day Calendar' : '+ Add Work Days';
}

function board205RenderWorkDayCalendar() {
  board205ApplyWorkDayPickerExpanded();
  const target = document.getElementById('setup-board205-work-day-calendar');
  const summary = document.getElementById('setup-board205-work-day-selection');
  const submit = document.getElementById('setup-board205-add-work-days');
  if (!target || !summary || !submit) return;

  const existing = board205ExistingWorkDayDates();
  for (const date of [...setupBoard205State.workDaySelection]) {
    if (existing.has(date)) setupBoard205State.workDaySelection.delete(date);
  }

  const monthStart = board205CalendarMonthStart();
  const year = monthStart.getUTCFullYear();
  const month = monthStart.getUTCMonth();
  const firstDow = monthStart.getUTCDay();
  const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const monthLabel = monthStart.toLocaleDateString(undefined, {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC'
  });

  const cells = [];
  for (let blank = 0; blank < firstDow; blank += 1) {
    cells.push('<span class="setup-board205-calendar-blank" aria-hidden="true"></span>');
  }
  for (let day = 1; day <= daysInMonth; day += 1) {
    const date = String(year) + '-' + String(month + 1).padStart(2, '0') + '-' + String(day).padStart(2, '0');
    const alreadyExists = existing.has(date);
    const selected = setupBoard205State.workDaySelection.has(date);
    const weekday = new Date(date + 'T00:00:00Z').toLocaleDateString(undefined, {
      weekday: 'long',
      timeZone: 'UTC'
    });
    cells.push(
      '<button type="button" class="setup-board205-calendar-day' + (selected ? ' selected' : '') + (alreadyExists ? ' existing' : '') + '" data-work-date="' + date + '" aria-pressed="' + (selected ? 'true' : 'false') + '" ' + (alreadyExists ? 'disabled aria-disabled="true"' : '') + ' title="' + (alreadyExists ? 'Work Day already exists' : 'Select ' + weekday + ', ' + date) + '"><span>' + day + '</span>' + (alreadyExists ? '<small>Work Day</small>' : '') + '</button>'
    );
  }

  target.innerHTML =
    '<div class="setup-board205-calendar-head">' +
      '<button id="setup-board205-calendar-prev" type="button" class="small secondary" aria-label="Previous month">‹</button>' +
      '<strong>' + board205Esc(monthLabel) + '</strong>' +
      '<button id="setup-board205-calendar-next" type="button" class="small secondary" aria-label="Next month">›</button>' +
    '</div>' +
    '<div class="setup-board205-calendar-weekdays" aria-hidden="true">' +
      '<span>Sun</span><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span>' +
    '</div>' +
    '<div class="setup-board205-calendar-grid">' + cells.join('') + '</div>';

  const selectedDates = [...setupBoard205State.workDaySelection].sort();
  summary.textContent = selectedDates.length
    ? String(selectedDates.length) + ' date' + (selectedDates.length === 1 ? '' : 's') + ' selected: ' + selectedDates.join(', ')
    : 'Select one or more dates. Tap a selected date again to remove it.';
  submit.disabled = !selectedDates.length;

  target.querySelector('#setup-board205-calendar-prev')?.addEventListener('click', () => {
    const prior = new Date(Date.UTC(year, month - 1, 1));
    setupBoard205State.workDayCalendarMonth = String(prior.getUTCFullYear()) + '-' + String(prior.getUTCMonth() + 1).padStart(2, '0');
    board205RenderWorkDayCalendar();
  });
  target.querySelector('#setup-board205-calendar-next')?.addEventListener('click', () => {
    const next = new Date(Date.UTC(year, month + 1, 1));
    setupBoard205State.workDayCalendarMonth = String(next.getUTCFullYear()) + '-' + String(next.getUTCMonth() + 1).padStart(2, '0');
    board205RenderWorkDayCalendar();
  });
  target.querySelectorAll('.setup-board205-calendar-day:not(:disabled)').forEach((button) => {
    button.addEventListener('click', () => {
      const date = button.dataset.workDate;
      if (!date || board205ExistingWorkDayDates().has(date)) return;
      if (setupBoard205State.workDaySelection.has(date)) {
        setupBoard205State.workDaySelection.delete(date);
      } else {
        setupBoard205State.workDaySelection.add(date);
      }
      board205RenderWorkDayCalendar();
    });
  });
}

function board205DayViewState(day) {
  const status = String(day.day_status || '').toUpperCase();
  if (status === 'COMPLETE' || status === 'CANCELLED') return 'COMPLETED';

  const assignments = board205DayAssignments(day);
  if (!assignments.length) return 'EMPTY';

  const hasUnfinished = assignments.some((item) => {
    const task = board205Task(item.setup_session_task_id);
    return !task || !task.effective_complete;
  });
  return hasUnfinished ? 'UNFINISHED' : 'COMPLETED';
}

function board205VisibleDays() {
  const showUnfinished = document.getElementById('setup-board205-show-unfinished-days')?.checked !== false;
  const showCompleted = Boolean(document.getElementById('setup-board205-show-completed-days')?.checked);
  const showEmpty = Boolean(document.getElementById('setup-board205-show-empty-days')?.checked);

  return (setupBoard205State.board.work_days || []).filter((day) => {
    const state = board205DayViewState(day);
    if (state === 'UNFINISHED') return showUnfinished;
    if (state === 'COMPLETED') return showCompleted;
    return showEmpty;
  });
}

function board205AutoScrollPane(pane, event) {
  if (!pane || !setupBoard205State.dragged) return;
  const rect = pane.getBoundingClientRect();
  const edge = Math.min(110, Math.max(70, rect.height * 0.14));
  const step = 34;
  if (event.clientY <= rect.top + edge) {
    pane.scrollTop = Math.max(0, pane.scrollTop - step);
  } else if (event.clientY >= rect.bottom - edge) {
    pane.scrollTop += step;
  }
}

function board205AmCapacity(crewId) {
  const items = board205CrewSequence(crewId).filter((item) => item.shift_code === 'MORNING');
  if (!items.length) {
    return { total: 0, remaining: SETUP_BOARD205_TYPICAL_AM_MINUTES, carryover: 0, known: true };
  }

  let total = 0;
  for (const item of items) {
    const task = board205Task(item.setup_session_task_id) || item;
    const minutes = Number(task.expected_duration_minutes || 0);
    if (minutes <= 0) {
      return { total: null, remaining: null, carryover: null, known: false };
    }
    total += minutes;
  }

  return {
    total,
    remaining: Math.max(SETUP_BOARD205_TYPICAL_AM_MINUTES - total, 0),
    carryover: Math.max(total - SETUP_BOARD205_TYPICAL_AM_MINUTES, 0),
    known: true
  };
}

function board205AmCapacityNote(crewId) {
  const capacity = board205AmCapacity(crewId);
  const hasMorningWork = board205CrewSequence(crewId).some((item) => item.shift_code === 'MORNING');
  if (!hasMorningWork) return '';
  if (!capacity.known) {
    return '<div class="setup-board205-capacity-note">AM remaining time unknown — one or more tasks have no reviewed duration.</div>';
  }
  if (capacity.carryover > 0) {
    return `<div class="setup-board205-capacity-note">≈ ${board205Esc(board205Duration(capacity.carryover))} over the typical AM window.</div>`;
  }
  if (capacity.remaining > 0) {
    return `<div class="setup-board205-capacity-note">≈ ${board205Esc(board205Duration(capacity.remaining))} remains in AM.</div>`;
  }
  return '<div class="setup-board205-capacity-note">AM work fills the typical ≈ 9–12 window.</div>';
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

function board205AuditWhen(value) {
  if (!value) return 'unknown time';
  if (typeof formatTimestamp === 'function') return formatTimestamp(value);
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? String(value) : parsed.toLocaleString();
}

function board205AuditLine(task) {
  if (!task || task.task_origin !== 'REUSABLE') return '';
  const createdBy = task.reusable_created_by_display || task.reusable_created_by || 'unknown actor';
  const updatedBy = task.reusable_updated_by_display || task.reusable_updated_by || 'unknown actor';
  return `Created ${board205AuditWhen(task.reusable_created_at)} by ${createdBy} · Last updated ${board205AuditWhen(task.reusable_updated_at)} by ${updatedBy}`;
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
  const problem = String(task.linked_work_order_problem || '').trim();
  return `<span class="setup-board205-badge ${complete ? '' : 'waiting'}" title="${board205Esc(problem)}">WO ${board205Esc(task.linked_work_order_id)} · ${complete ? 'complete' : 'open'}${problem ? ` · ${board205Esc(problem)}` : ''}</span>`;
}

function board205HistoricalReviewMode() {
  return String(setupBoard205State.board.session?.session_status || '').toUpperCase() === 'HISTORICAL_VERIFICATION';
}

function board205BlockingEnabled() {
  const toggle = document.getElementById('setup-board205-blocking-toggle');
  return toggle ? Boolean(toggle.checked) : true;
}

function board205ReadyOnlyEnabled() {
  return Boolean(document.getElementById('setup-board205-ready-only')?.checked);
}

function board205CaptureFinderState() {
  const value = (id) => document.getElementById(id)?.value ?? '';
  const checked = (id) => Boolean(document.getElementById(id)?.checked);

  return {
    stage: value('setup-board205-stage-filter'),
    scene: value('setup-board205-scene-filter'),
    sort: value('setup-board205-sort'),
    search: value('setup-board205-task-search'),
    blocking: checked('setup-board205-blocking-toggle'),
    readyOnly: checked('setup-board205-ready-only'),
    statusReady: checked('setup-board205-status-ready'),
    statusScheduled: checked('setup-board205-status-scheduled'),
    statusComplete: checked('setup-board205-status-complete'),
    timeOp: value('setup-board205-time-op'),
    time: value('setup-board205-time-filter'),
    crewOp: value('setup-board205-crew-op'),
    crew: value('setup-board205-crew-filter'),
    effort: value('setup-board205-effort-filter'),
    compact: Boolean(setupBoard205State.finderCompact),
    scrollY: Math.max(0, Number(window.scrollY || 0))
  };
}

function board205RestoreFinderState(state) {
  if (!state || typeof state !== 'object') return;

  const setValue = (id, value) => {
    const control = document.getElementById(id);
    if (control == null || value == null) return;
    const text = String(value);
    if (control.tagName === 'SELECT') {
      if ([...control.options].some((option) => option.value === text)) control.value = text;
    } else {
      control.value = text;
    }
  };
  const setChecked = (id, value) => {
    const control = document.getElementById(id);
    if (control && value != null) control.checked = Boolean(value);
  };

  setValue('setup-board205-stage-filter', state.stage);
  board205SyncFinderSceneOptions();
  setValue('setup-board205-scene-filter', state.scene);
  setValue('setup-board205-sort', state.sort);
  setValue('setup-board205-task-search', state.search);
  setChecked('setup-board205-blocking-toggle', state.blocking);
  setChecked('setup-board205-ready-only', state.readyOnly);
  setChecked('setup-board205-status-ready', state.statusReady);
  setChecked('setup-board205-status-scheduled', state.statusScheduled);
  setChecked('setup-board205-status-complete', state.statusComplete);
  setValue('setup-board205-time-op', state.timeOp);
  setValue('setup-board205-time-filter', state.time);
  setValue('setup-board205-crew-op', state.crewOp);
  setValue('setup-board205-crew-filter', state.crew);
  setValue('setup-board205-effort-filter', state.effort);

  setupBoard205State.finderCompact = Boolean(state.compact);
  board205ApplyFinderCompact();

  const blockingLabel = document.getElementById('setup-board205-blocking-toggle')?.closest('label');
  if (blockingLabel) {
    blockingLabel.lastChild.textContent = board205BlockingEnabled() ? ' Blocking ON' : ' Blocking OFF';
  }

  board205RenderQueue();

  const top = Math.max(0, Number(state.scrollY || 0));
  window.requestAnimationFrame(() => window.scrollTo({ top, left: 0, behavior: 'auto' }));
}

function board205ApplyFinderCompact() {
  const filters = document.getElementById('setup-board205-filters');
  const button = document.getElementById('setup-board205-filter-density');
  if (!filters || !button) return;

  const compact = Boolean(setupBoard205State.finderCompact);
  filters.classList.toggle('compact', compact);
  button.textContent = compact ? 'More filters' : 'Compact filters';
  button.setAttribute('aria-expanded', compact ? 'false' : 'true');
}

function board205FinderStatusFamily(task) {
  const status = String(task?.board_status || '').toUpperCase();

  // Readiness is a soft blocker: keep the task in the ordinary candidate
  // population so an operator can decide whether the condition is satisfied.
  if (
    status === 'BLOCKED'
    && task?.readiness_state === 'NOT_READY'
    && task?.prerequisites_complete !== false
  ) {
    return 'READY';
  }

  if (status === 'CATALOG_ONLY') return 'READY';
  if (status === 'READY_TO_SCHEDULE' || status === 'NEEDS_SCHEDULING_AGAIN') return 'READY';
  if (status === 'BLOCKED') return 'BLOCKED';
  if (status === 'WAITING_ON_WORK_ORDER' && task?.linked_work_order_gate) return 'READY';
  if (status === 'WAITING_ON_WORK_ORDER') return 'WAITING';
  if (status === 'SCHEDULED') return 'SCHEDULED';
  if (status === 'COMPLETE') return 'COMPLETE';
  if (status === 'DEFERRED') return 'DEFERRED';
  return 'OTHER';
}

function board205HasHardBlock(task) {
  if (!task) return false;

  // A hard block belongs on the subsequent task whose prerequisite is not
  // complete. The Work Order gate task itself remains visible so the operator
  // can see what is waiting and why.
  return task.prerequisites_complete === false;
}

function board205ReadinessOnly(task) {
  return Boolean(
    task?.readiness_state === 'NOT_READY'
    && !board205HasHardBlock(task)
  );
}

function board205FinderStageRows() {
  const rows = new Map();
  for (const task of setupBoard205State.board.tasks || []) {
    if (task.stage_id == null) continue;
    const id = Number(task.stage_id);
    if (!rows.has(id)) {
      rows.set(id, {
        stage_id: id,
        stage_key: task.stage_key || '',
        stage_name: task.stage_name || `Stage ${id}`
      });
    }
  }
  return [...rows.values()].sort((a, b) => (
    String(a.stage_key || '').localeCompare(
      String(b.stage_key || ''),
      undefined,
      { numeric: true, sensitivity: 'base' }
    )
    || String(a.stage_name || '').localeCompare(
      String(b.stage_name || ''),
      undefined,
      { sensitivity: 'base' }
    )
    || Number(a.stage_id) - Number(b.stage_id)
  ));
}

function board205SyncFinderSceneOptions() {
  const stage = document.getElementById('setup-board205-stage-filter');
  const scene = document.getElementById('setup-board205-scene-filter');
  const sceneLabel = document.getElementById('setup-board205-scene-label');
  if (!stage || !scene) return;

  const previous = scene.value;
  const stageValue = stage.value;
  if (!stageValue || stageValue === 'SITE_WIDE') {
    scene.innerHTML = '<option value="">All scope details</option>';
    scene.value = '';
    scene.disabled = true;
    if (sceneLabel) sceneLabel.hidden = true;
    return;
  }

  const stageId = Number(stageValue);
  const sceneRows = new Map();
  let hasStageLevel = false;

  for (const task of setupBoard205State.board.tasks || []) {
    if (Number(task.stage_id) !== stageId) continue;
    if (task.lor_scene_id == null) {
      hasStageLevel = true;
      continue;
    }
    const id = Number(task.lor_scene_id);
    if (!sceneRows.has(id)) {
      sceneRows.set(id, {
        lor_scene_id: id,
        scene_name: task.scene_name || `Scene ${id}`
      });
    }
  }

  const options = ['<option value="">All scope details</option>'];
  if (hasStageLevel) {
    options.push('<option value="STAGE_ONLY">Stage / Sub-stage level only</option>');
  }
  for (const row of [...sceneRows.values()].sort((a, b) => (
    String(a.scene_name || '').localeCompare(
      String(b.scene_name || ''),
      undefined,
      { numeric: true, sensitivity: 'base' }
    )
    || Number(a.lor_scene_id) - Number(b.lor_scene_id)
  ))) {
    options.push(`<option value="${row.lor_scene_id}">${board205Esc(row.scene_name)}</option>`);
  }

  scene.innerHTML = options.join('');
  const hasUsefulScopeChoice = options.length > 1;
  scene.disabled = !hasUsefulScopeChoice;
  if (sceneLabel) sceneLabel.hidden = !hasUsefulScopeChoice;
  scene.value = [...scene.options].some((option) => option.value === previous) ? previous : '';
}

function board205SyncFinderOptions() {
  const stage = document.getElementById('setup-board205-stage-filter');
  if (!stage) return;

  const previous = stage.value;
  const hasSiteWide = (setupBoard205State.board.tasks || []).some((task) => task.stage_id == null);
  const options = ['<option value="">All Stages / areas</option>'];

  if (hasSiteWide) {
    options.push('<option value="SITE_WIDE">Site-wide / Infrastructure</option>');
  }
  for (const row of board205FinderStageRows()) {
    const name = row.stage_name ? ` — ${row.stage_name}` : '';
    options.push(
      `<option value="${row.stage_id}">Stage ${board205Esc(row.stage_key || '—')}${board205Esc(name)}</option>`
    );
  }

  stage.innerHTML = options.join('');
  stage.value = [...stage.options].some((option) => option.value === previous) ? previous : '';
  board205SyncFinderSceneOptions();
}

function board205FinderSelectedStatuses() {
  const ids = {
    READY: 'setup-board205-status-ready',
    SCHEDULED: 'setup-board205-status-scheduled',
    COMPLETE: 'setup-board205-status-complete'
  };
  return new Set(
    Object.entries(ids)
      .filter(([, id]) => document.getElementById(id)?.checked)
      .map(([status]) => status)
  );
}

function board205FinderCompare(a, b, mode) {
  const reusablePlanning = board205HistoricalReviewMode() && Boolean(setupBoard205State.board.catalog_overlay);
  const stageFilter = document.getElementById('setup-board205-stage-filter')?.value || '';
  const taskIdentity = (task) => Number(task.setup_task_id ?? task.setup_session_task_id ?? 0);
  const baselineOrder = (task) => {
    const value = reusablePlanning
      ? task.baseline_plan_order
      : (task.planned_order ?? task.baseline_plan_order);
    return value == null ? 999999 : Number(value);
  };
  const stepOrder = (task) => {
    const useReusableStepOrder = Boolean(stageFilter) && task.task_origin === 'REUSABLE';
    const value = useReusableStepOrder
      ? (task.display_order ?? task.baseline_plan_order ?? task.planned_order)
      : (task.planned_order ?? task.baseline_plan_order ?? task.display_order);
    return value == null ? 999999 : Number(value);
  };
  const textCompare = (left, right) => String(left || '').localeCompare(
    String(right || ''),
    undefined,
    { numeric: true, sensitivity: 'base' }
  );
  const scopeCompare = (left, right) => {
    const leftScene = left.lor_scene_id == null ? 0 : 1;
    const rightScene = right.lor_scene_id == null ? 0 : 1;
    return leftScene - rightScene
      || textCompare(left.scene_name, right.scene_name);
  };

  if (mode === 'STAGE') {
    // Real Stage work sorts first in Stage-number order. Site-wide /
    // Infrastructure has no Stage key and belongs after the numbered Stages,
    // not before Stage 00.
    const aSiteWide = a.stage_id == null ? 1 : 0;
    const bSiteWide = b.stage_id == null ? 1 : 0;
    if (aSiteWide !== bSiteWide) return aSiteWide - bSiteWide;

    const aSceneLevel = a.lor_scene_id == null ? 0 : 1;
    const bSceneLevel = b.lor_scene_id == null ? 0 : 1;

    return textCompare(a.stage_key, b.stage_key)
      || textCompare(a.stage_name, b.stage_name)
      || aSceneLevel - bSceneLevel
      || textCompare(a.scene_name, b.scene_name)
      || baselineOrder(a) - baselineOrder(b)
      || taskIdentity(a) - taskIdentity(b);
  }
  if (mode === 'NAME') {
    return textCompare(a.task_name, b.task_name)
      || textCompare(a.stage_key, b.stage_key)
      || taskIdentity(a) - taskIdentity(b);
  }
  if (mode === 'STATUS') {
    const rank = { READY: 1, BLOCKED: 2, WAITING: 3, SCHEDULED: 4, DEFERRED: 5, COMPLETE: 6, OTHER: 9 };
    return (rank[board205FinderStatusFamily(a)] || 9) - (rank[board205FinderStatusFamily(b)] || 9)
      || textCompare(a.stage_key, b.stage_key)
      || baselineOrder(a) - baselineOrder(b)
      || taskIdentity(a) - taskIdentity(b);
  }
  if (mode === 'DURATION') {
    const ad = a.expected_duration_minutes == null ? 999999 : Number(a.expected_duration_minutes);
    const bd = b.expected_duration_minutes == null ? 999999 : Number(b.expected_duration_minutes);
    return ad - bd
      || baselineOrder(a) - baselineOrder(b)
      || taskIdentity(a) - taskIdentity(b);
  }
  if (mode === 'CREW') {
    const ac = a.normal_crew_min == null ? 999999 : Number(a.normal_crew_min);
    const bc = b.normal_crew_min == null ? 999999 : Number(b.normal_crew_min);
    return ac - bc
      || baselineOrder(a) - baselineOrder(b)
      || taskIdentity(a) - taskIdentity(b);
  }

  if (stageFilter) {
    return scopeCompare(a, b)
      || stepOrder(a) - stepOrder(b)
      || baselineOrder(a) - baselineOrder(b)
      || taskIdentity(a) - taskIdentity(b);
  }

  return stepOrder(a) - stepOrder(b)
    || baselineOrder(a) - baselineOrder(b)
    || textCompare(a.stage_key, b.stage_key)
    || taskIdentity(a) - taskIdentity(b);
}

function board205BlockerDetails(task, deps) {
  const details = [];
  const incomplete = (deps || []).filter((dep) => !dep.prerequisite_complete);

  if (incomplete.length) {
    details.push({
      label: 'Hard predecessor',
      text: `Complete first: ${incomplete.map((dep) => dep.prerequisite_task_name).join('; ')}`
    });
  }
  if (task?.readiness_state === 'NOT_READY') {
    details.push({
      label: 'Readiness condition · soft',
      text: `${task.readiness_note || 'Marked Not Ready'} · keep visible for operator judgement; mark Ready when the condition is actually met.`
    });
  }
  if (
    task?.linked_work_order_gate
    && task.linked_work_order_id
    && !task.linked_work_order_completed_at
  ) {
    details.push({
      label: 'Work Order gate',
      text: `WO ${task.linked_work_order_id} is open · clear when that Work Order is completed.`
    });
  }
  return details;
}

function board205CurrentReusableScope(task) {
  if (!task) return { stage_id: null, lor_scene_id: null, scene_name: null };
  const scope = (typeof setupNextState !== 'undefined' && setupNextState.taskScopes)
    ? setupNextState.taskScopes.get(Number(task.setup_task_id))
    : null;
  return {
    stage_id: scope?.stage_id ?? task.stage_id ?? null,
    lor_scene_id: scope?.lor_scene_id ?? task.lor_scene_id ?? null,
    scene_name: scope?.scene_name ?? task.scene_name ?? null
  };
}

function board205DefaultReadinessState(readinessNote) {
  return String(readinessNote || '').trim() ? 'NOT_READY' : 'READY';
}

function board205CatalogDependencyRows(task) {
  return (task?.dependencies || []).map((dep, index) => ({
    setup_session_task_id: null,
    prerequisite_setup_session_task_id: null,
    dependency_origin: 'REUSABLE_CURRENT',
    dependency_note: dep.dependency_note || null,
    sort_order: Number(dep.sort_order ?? ((index + 1) * 10)),
    prerequisite_task_name: dep.task_name || `Task ${dep.setup_task_id}`,
    prerequisite_task_origin: 'REUSABLE',
    prerequisite_execution_status: null,
    prerequisite_work_order_id: null,
    prerequisite_work_order_completed_at: null,
    // Before an annual Session exists there is no completed annual predecessor.
    // Reusable prerequisites therefore begin as hard blockers.
    prerequisite_complete: false,
    prerequisite_setup_task_id: dep.setup_task_id
  }));
}

function board205ApplyHistoricalCatalogOverlay() {
  const board = setupBoard205State.board || {};
  if (String(board.session?.session_status || '').toUpperCase() !== 'HISTORICAL_VERIFICATION') return;

  const annualByReusableId = new Map(
    (board.tasks || [])
      .filter((task) => task.setup_task_id != null && task.task_origin === 'REUSABLE')
      .map((task) => [Number(task.setup_task_id), task])
  );
  const currentTasks = (appState.tasks || []).filter((task) => Boolean(task.active_flag));
  const merged = [];
  const mergedDependencies = [];

  for (const current of currentTasks) {
    const reusableId = Number(current.setup_task_id);
    const annual = annualByReusableId.get(reusableId) || null;
    const scope = board205CurrentReusableScope(current);
    const stage = (appState.stages || []).find((row) => Number(row.stage_id) === Number(scope.stage_id));
    const annualName = annual?.task_name || null;
    const currentDependencies = board205CatalogDependencyRows(current);
    const hasHardPrerequisite = currentDependencies.length > 0;

    const row = {
      ...(annual || {}),
      setup_session_task_id: annual?.setup_session_task_id ?? null,
      setup_task_id: reusableId,
      task_origin: 'REUSABLE',
      catalog_only: !annual,
      annual_present: Boolean(annual),
      annual_snapshot_task_name: annualName,
      task_name: current.task_name,
      task_action_type: current.task_action_type || annual?.task_action_type || 'WORK',
      display_order: current.display_order ?? annual?.display_order ?? null,
      baseline_plan_order: current.baseline_plan_order ?? annual?.baseline_plan_order ?? null,
      stage_id: scope.stage_id,
      stage_key: stage?.stage_key ?? current.stage_key ?? annual?.stage_key ?? null,
      stage_name: stage?.stage_name ?? current.stage_name ?? annual?.stage_name ?? null,
      lor_scene_id: scope.lor_scene_id,
      scene_name: scope.scene_name,
      normal_crew_min: current.normal_crew_min,
      normal_crew_max: current.normal_crew_max,
      expected_duration_minutes: current.expected_duration_minutes,
      effort_level: current.effort_level ?? annual?.effort_level ?? null,
      completion_point: current.completion_point,
      readiness_note: current.readiness_note,
      readiness_state: board205DefaultReadinessState(current.readiness_note),
      weather_note: current.weather_note,
      reusable_notes: current.reusable_notes,
      reusable_active_flag: true,
      // The Scheduling Board query joins the current reusable Catalog row and
      // therefore carries authoritative audit fields from this request.
      // Historical Catalog overlay data in appState.tasks can be older than a
      // just-completed governed write, so never replace fresh board audit data
      // with that page-level cache.
      reusable_created_at: annual?.reusable_created_at ?? current.reusable_created_at,
      reusable_created_by: annual?.reusable_created_by ?? current.reusable_created_by,
      reusable_created_by_person_id: annual?.reusable_created_by_person_id ?? current.reusable_created_by_person_id,
      reusable_created_by_display: annual?.reusable_created_by_display ?? current.reusable_created_by_display,
      reusable_updated_at: annual?.reusable_updated_at ?? current.reusable_updated_at,
      reusable_updated_by: annual?.reusable_updated_by ?? current.reusable_updated_by,
      reusable_updated_by_person_id: annual?.reusable_updated_by_person_id ?? current.reusable_updated_by_person_id,
      reusable_updated_by_display: annual?.reusable_updated_by_display ?? current.reusable_updated_by_display,
      catalog_dependencies: currentDependencies,
      prerequisites_complete: !hasHardPrerequisite,
      // Historical Verification is being used as a safe shell to review the
      // current reusable Catalog before 2026 exists. Start from a fresh-season
      // baseline: 2025 completion does not satisfy future prerequisites.
      board_status: hasHardPrerequisite ? 'BLOCKED' : 'CATALOG_ONLY',
      effective_complete: annual?.effective_complete || false,
      progress_entries: annual?.progress_entries || 0
    };
    merged.push(row);
  }

  board.historical_annual_task_count = (board.tasks || []).length;
  board.tasks = merged;
  board.dependencies = [];
  board.catalog_overlay = true;
}

function board205TaskCard(task) {
  const historicalReview = board205HistoricalReviewMode();
  const catalogReview = historicalReview
    && Boolean(setupBoard205State.board.catalog_overlay)
    && task.task_origin === 'REUSABLE';
  const deps = catalogReview
    ? (task.catalog_dependencies || [])
    : board205TaskDependencies(task.setup_session_task_id);
  const isGate = task.task_action_type === 'GATE';
  const canManage = Boolean(appState.access?.can_manage_setup);
  const canSchedule = canManage
    && !historicalReview
    && !task.effective_complete
    && !isGate
    && task.board_status !== 'DEFERRED';
  const hardBlocked = board205HasHardBlock(task);
  const readinessOnly = board205ReadinessOnly(task);
  const seasonOnly = task.task_origin === 'SEASON_ONLY';
  const depText = deps.length
    ? deps.map((dep) => catalogReview
      ? dep.prerequisite_task_name
      : `${dep.prerequisite_complete ? '✓' : '○'} ${dep.prerequisite_task_name}`
    ).join('; ')
    : (catalogReview ? 'No reusable prerequisite' : 'No annual prerequisite');
  const blockerDetails = board205BlockerDetails(task, deps);

  return `
    <article class="setup-board205-task-card ${task.requires_display_material ? 'setup-material-task' : ''}"
      data-session-task-id="${task.setup_session_task_id ?? ''}"
      data-reusable-task-id="${task.setup_task_id ?? ''}"
      draggable="${canSchedule ? 'true' : 'false'}">
      <div class="setup-board205-task-title">
        <span>Task ${board205Esc(task.setup_task_id ?? 'annual-only')} · ${board205Esc(task.task_name)}</span>
        ${!catalogReview && seasonOnly ? '<span class="setup-board205-badge season-only">THIS SEASON ONLY</span>' : ''}
        ${isGate ? '<span class="setup-board205-badge">GATE</span>' : ''}
        <span class="setup-board205-badge ${hardBlocked ? 'blocked' : readinessOnly ? 'waiting' : ''}">${board205Esc(
          catalogReview
            ? hardBlocked
              ? 'HARD BLOCKED'
              : readinessOnly
                ? 'NOT READY'
                : 'CURRENT CATALOG'
            : board205StatusLabel(task.board_status)
        )}</span>
        <span class="setup-board205-badge effort-${board205Esc(String(task.effort_level || 'unknown').toLowerCase())}">${board205Esc(board205Effort(task))}</span>
        ${board205WorkOrderBadge(task)}
      </div>
      <div class="setup-board205-meta">${board205Esc(board205Scope(task))}</div>
      <div class="setup-board205-meta"><strong>Min crew:</strong> ${board205Esc(task.normal_crew_min ?? 'TBD')} · <strong>Expected:</strong> ${board205Esc(board205Duration(task.expected_duration_minutes))}</div>
      ${task.resource_summary ? `<div class="setup-board205-meta"><strong>Resources:</strong> ${board205Esc(task.resource_summary)}</div>` : ''}
      ${task.reusable_notes ? `<div class="setup-board205-meta setup-board205-reusable-notes"><strong>Reusable notes:</strong> ${board205Esc(task.reusable_notes)}</div>` : ''}
      ${canManage && task.task_origin === 'REUSABLE' ? `<div class="setup-board205-meta setup-board205-audit"><strong>Audit:</strong> ${board205Esc(board205AuditLine(task))}</div>` : ''}
      <div class="setup-board205-meta"><strong>Hard predecessor(s):</strong> ${board205Esc(depText)}</div>
      ${task.readiness_note ? `<div class="setup-board205-readiness ${task.readiness_state === 'NOT_READY' ? 'not-ready' : 'ready'}"><strong>Readiness:</strong> ${board205Esc(task.readiness_note)} · <strong>${board205Esc(task.readiness_state || 'READY')}</strong></div>` : ''}
      ${blockerDetails.map((detail) => `<div class="setup-board205-warning setup-board205-blocker-detail"><strong>${board205Esc(detail.label)}:</strong> ${board205Esc(detail.text)}</div>`).join('')}
      <div class="setup-board205-card-actions">
        ${canSchedule ? '<button type="button" class="small setup-board205-schedule-task">Schedule…</button>' : ''}
        ${canManage && !historicalReview && !task.catalog_only && task.readiness_note ? `<button type="button" class="small secondary setup-board205-toggle-readiness">${task.readiness_state === 'NOT_READY' ? 'Mark Ready' : 'Mark Not Ready'}</button>` : ''}
        ${canManage && historicalReview && task.task_origin === 'REUSABLE' ? '<button type="button" class="small setup-board205-edit-planning-info">Edit Planning Info</button>' : ''}
        ${canManage && !historicalReview && !task.catalog_only && !task.progress_entries && !task.effective_complete ? '<button type="button" class="small secondary setup-board205-edit-planning-info">Edit Planning Info</button>' : ''}
        ${canManage && !historicalReview && seasonOnly ? '<button type="button" class="small secondary setup-board205-edit-season-task">Edit season task</button>' : ''}
      </div>
    </article>`;
}


function board205QueueTasks() {
  const search = (document.getElementById('setup-board205-task-search')?.value || '').trim().toLowerCase();
  const stageValue = document.getElementById('setup-board205-stage-filter')?.value || '';
  const sceneValue = document.getElementById('setup-board205-scene-filter')?.value || '';
  const sortMode = document.getElementById('setup-board205-sort')?.value || 'PLAN';
  const hoursValue = Number(document.getElementById('setup-board205-time-filter')?.value || 0);
  const minutesValue = hoursValue > 0 ? hoursValue * 60 : null;
  const timeOp = document.getElementById('setup-board205-time-op')?.value || 'LTE';
  const crewValue = Number(document.getElementById('setup-board205-crew-filter')?.value || 0);
  const crewOp = document.getElementById('setup-board205-crew-op')?.value || 'LTE';
  const effort = document.getElementById('setup-board205-effort-filter')?.value || '';
  const readyOnly = board205ReadyOnlyEnabled();
  const statuses = board205FinderSelectedStatuses();

  return [...(setupBoard205State.board.tasks || [])]
    .filter((task) => {
      const family = board205FinderStatusFamily(task);
      const hardBlocked = board205HasHardBlock(task);

      // Blocking ON hides only tasks whose hard prerequisite is incomplete.
      // A Work Order gate task itself remains visible; downstream tasks are
      // blocked through their prerequisite edge. Readiness remains soft/visible.
      if (board205BlockingEnabled() && hardBlocked) return false;

      // Readiness remains a soft blocker. Ready only changes finder visibility
      // only; it does not rewrite readiness state or make readiness a hard gate.
      if (readyOnly && task.readiness_state === 'NOT_READY') return false;

      // Task-name search narrows the current finder population; it does not
      // resurrect tasks that moved into a different status such as SCHEDULED.
      // With Blocking OFF, hard-blocked work is still included automatically.
      if (!hardBlocked && !statuses.has(family)) return false;

      if (stageValue === 'SITE_WIDE') {
        if (task.stage_id != null) return false;
      } else if (stageValue && Number(task.stage_id) !== Number(stageValue)) {
        return false;
      }

      if (sceneValue === 'STAGE_ONLY') {
        if (task.lor_scene_id != null) return false;
      } else if (sceneValue && Number(task.lor_scene_id) !== Number(sceneValue)) {
        return false;
      }

      if (search) {
        // "Task" means task name. Keep this finder literal and predictable:
        // typing "locate" returns annual tasks whose task_name contains locate,
        // regardless of blocker/status. Stage/Scene/etc. have their own filters.
        const taskName = String(task.task_name || '').toLowerCase();
        if (!taskName.includes(search)) return false;
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
    .sort((a, b) => board205FinderCompare(a, b, sortMode));
}

function board205RenderQueue() {
  const target = document.getElementById('setup-board205-queue');
  if (!target) return;
  const tasks = board205QueueTasks();
  const summary = document.getElementById('setup-board205-finder-summary');
  const search = (document.getElementById('setup-board205-task-search')?.value || '').trim();
  if (summary) {
    const noun = board205HistoricalReviewMode() ? 'current reusable tasks' : 'annual tasks';
    summary.textContent = `${tasks.length} of ${(setupBoard205State.board.tasks || []).length} ${noun}`
      + ` · Blocking ${board205BlockingEnabled() ? 'ON' : 'OFF'}`
      + (board205ReadyOnlyEnabled() ? ' · Ready only' : ' · soft readiness shown')
      + (search ? ' · task-name search keeps status filters' : '')
      + (!board205BlockingEnabled()
        ? ' · hard-blocked work included'
        : ' · hard blockers hidden');
  }
  target.innerHTML = tasks.length
    ? tasks.map(board205TaskCard).join('')
    : `<div class="setup-board205-empty">No ${board205HistoricalReviewMode() ? 'current reusable' : 'annual'} tasks match the selected filters.</div>`;

  target.querySelectorAll('.setup-board205-task-card').forEach((card) => {
    const sessionTaskId = Number(card.dataset.sessionTaskId || 0);
    const reusableTaskId = Number(card.dataset.reusableTaskId || 0);
    const task = sessionTaskId
      ? board205Task(sessionTaskId)
      : (setupBoard205State.board.tasks || []).find(
          (row) => Number(row.setup_task_id) === reusableTaskId && row.catalog_only
        );
    const taskId = sessionTaskId;
    card.addEventListener('dragstart', (event) => {
      if (!task || !taskId || task.task_action_type === 'GATE') return;
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
      board205OpenPlanningInfoDialog(taskId || null, reusableTaskId || null);
    });
    card.querySelector('.setup-board205-edit-season-task')?.addEventListener('click', () => {
      board205OpenSeasonTaskDialog(taskId);
    });
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
    <article class="setup-board205-assignment ${task.requires_display_material ? 'setup-material-task' : ''} ${locked ? 'locked' : ''} ${understaffed ? 'short-crew' : ''}"
      data-assignment-id="${item.setup_work_day_task_id}"
      draggable="${canManage && !locked ? 'true' : 'false'}">
      <div class="setup-board205-task-title">
        <span>${board205Esc(task.task_name || item.task_name)}</span>
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
  const amCapacity = board205AmCapacity(crew.setup_work_day_crew_id);
  const capacityNote = shift === 'MORNING'
    ? board205AmCapacityNote(crew.setup_work_day_crew_id)
    : '';
  const carryoverNote = shift === 'AFTERNOON' && amCapacity.known && amCapacity.carryover > 0
    ? `<div class="setup-board205-carryover">≈ ${board205Esc(board205Duration(amCapacity.carryover))} of AM work carries past lunch into PM.</div>`
    : '';
  return `
    <div class="setup-board205-cell"
      data-day-id="${day.setup_work_day_id}" data-shift="${shift}" data-crew-id="${crew.setup_work_day_crew_id}">
      ${capacityNote}
      ${carryoverNote}
      ${items.length ? items.map(board205AssignmentCard).join('') : '<div class="setup-board205-cell-empty">Drop work here</div>'}
    </div>`;
}



function board205Day(day) {
  const dayClass = [
    Number(day.iso_day_of_week) === 6 ? 'saturday' : '',
    Number(day.iso_day_of_week) === 7 ? 'sunday' : '',
    Number(day.setup_day_number) % 2 === 0 ? 'day-band-even' : 'day-band-odd',
    board205DayViewState(day) === 'COMPLETED' ? 'completed-day' : '',
    String(day.day_status || '').toUpperCase() === 'CANCELLED' ? 'cancelled-day' : ''
  ].filter(Boolean).join(' ');
  const dayNote = [day.volunteer_note, day.weather_note, day.notes].filter(Boolean).join(' · ');
  const crews = board205CrewsForDay(day.setup_work_day_id);
  const canManage = Boolean(appState.access?.can_manage_setup);
  const crewRows = crews.map((crew) => {
    const legacy = board205AssignmentsFor(day.setup_work_day_id, 'ALL_DAY', crew.setup_work_day_crew_id);
    return `
      <div class="setup-board205-crew-label" data-crew-id="${crew.setup_work_day_crew_id}">
        <div class="setup-board205-crew-title-row">
          <strong>Crew ${board205Esc(crew.crew_code)}</strong>
          ${canManage ? `<div class="setup-board205-crew-actions"><button type="button" class="small setup-board205-save-crew">Save</button>${Number(crew.crew_number) > 1 ? '<button type="button" class="small secondary setup-board205-remove-crew">Remove</button>' : ''}</div>` : ''}
        </div>
        <label class="setup-board205-crew-captain">Captain
          <select class="setup-board205-crew-captain-select">${board205CaptainOptions(crew.captain_person_id)}</select>
        </label>
        <div class="setup-board205-crew-counts">
          <label>AM Crew <input class="setup-board205-crew-am" type="number" min="0" value="${board205Esc(crew.am_planned_crew_count ?? '')}" placeholder="—"></label>
          <label>PM Crew <input class="setup-board205-crew-pm" type="number" min="0" value="${board205Esc(crew.pm_planned_crew_count ?? '')}" placeholder="—"></label>
        </div>
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
          <div class="setup-board205-grid-head">Crew / Captain / Volunteers</div>
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
  const days = board205VisibleDays();
  target.innerHTML = days.length
    ? days.map(board205Day).join('')
    : '<div class="setup-board205-empty">No work days match the selected Day view filters.</div>';

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

function board205RenderKpis() {
  const target = document.getElementById('setup-board205-kpis');
  if (!target) return;
  const tasks = setupBoard205State.board.tasks || [];
  const total = tasks.length;
  const scheduled = tasks.filter((task) => Number(task.unworked_assignment_count || 0) > 0).length;
  const complete = tasks.filter((task) => Boolean(task.effective_complete)).length;
  const inProgress = tasks.filter((task) => task.execution_status === 'IN_PROGRESS').length;
  const pct = (count) => total ? Math.round((count / total) * 100) : 0;

  target.innerHTML = [
    `<span><strong>${total}</strong> tasks</span>`,
    `<span><strong>${scheduled}</strong> scheduled · ${pct(scheduled)}%</span>`,
    inProgress ? `<span><strong>${inProgress}</strong> in progress · ${pct(inProgress)}%</span>` : '',
    `<span><strong>${complete}</strong> complete · ${pct(complete)}%</span>`
  ].filter(Boolean).join('<span class="setup-board205-kpi-sep">·</span>');
}

function board205Render() {
  const session = setupBoard205State.board.session;
  const noSession = document.getElementById('setup-board205-no-session');
  const workspace = document.getElementById('setup-board205-workspace');
  const addSeason = document.getElementById('setup-board205-add-season-task');
  const createSession = document.getElementById('setup-board205-create-session');
  const dayForm = document.getElementById('setup-board205-day-form');
  const boardPane = document.getElementById('setup-board205-board-pane');
  const historicalNote = document.getElementById('setup-board205-historical-note');
  const finderTitle = document.getElementById('setup-board205-finder-title');
  const historicalReview = Boolean(session) && board205HistoricalReviewMode();
  const canManage = Boolean(appState.access?.can_manage_setup);
  const canAdmin = Boolean(appState.access?.can_admin_setup);

  if (addSeason) {
    addSeason.hidden = !session || historicalReview || !canManage;
    addSeason.disabled = !session || historicalReview || !canManage;
  }
  if (createSession) {
    createSession.textContent = `Create ${appState.seasonYear} Setup Session`;
    createSession.hidden = Boolean(session) || !canAdmin;
    createSession.disabled = Boolean(session) || !canAdmin;
  }
  if (dayForm) {
    const canScheduleDays = Boolean(session) && canManage && !historicalReview;
    dayForm.hidden = !canScheduleDays;
    dayForm.querySelectorAll('input,button,select').forEach((control) => {
      control.disabled = !canScheduleDays;
    });
  }
  if (boardPane) boardPane.hidden = historicalReview;
  if (historicalNote) historicalNote.hidden = !historicalReview;
  if (finderTitle) finderTitle.textContent = historicalReview
    ? 'Current Reusable Task Finder — Pre-2026 Planning'
    : 'Needs Scheduling';
  if (workspace) workspace.classList.toggle('finder-only', historicalReview);
  if (setupBoard205State.finderCompact == null) {
    setupBoard205State.finderCompact = true;
  }
  board205ApplyFinderCompact();
  board205RenderKpis();
  if (!session) {
    if (noSession) noSession.hidden = false;
    if (workspace) workspace.hidden = true;
    return;
  }
  if (noSession) noSession.hidden = true;
  if (workspace) workspace.hidden = false;
  board205SyncFinderOptions();
  board205RenderQueue();
  if (!historicalReview) {
    board205RenderWorkDayCalendar();
    board205RenderBoard();
    board205PopulateDialogSelects();
  }
}

async function board205Load() {
  try {
    const payload = await api(`api/setup/scheduling-board?season_year=${encodeURIComponent(appState.seasonYear)}`);
    setupBoard205State.board = payload.board || { session: null, work_days: [], crews: [], captain_candidates: [], work_orders: [], tasks: [], assignments: [], dependencies: [] };
    board205ApplyHistoricalCatalogOverlay();
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
  if (!task || !task.setup_session_task_id || !appState.access?.can_manage_setup) return;
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
  const amCount = nullableInteger(crewNode.querySelector('.setup-board205-crew-am')?.value);
  const pmCount = nullableInteger(crewNode.querySelector('.setup-board205-crew-pm')?.value);
  const capacityWarnings = board205CrewCapacityWarnings(crewId, amCount, pmCount);
  if (
    capacityWarnings.length
    && !window.confirm(
      `SHORT CREW:\n\n${capacityWarnings.join('\n')}\n\nSave this crew size anyway?`
    )
  ) {
    return;
  }

  try {
    setBusy(true);
    await api(`api/setup/scheduling-board/crews/${crewId}`, commandOptions('PATCH', {
      am_planned_crew_count: amCount,
      pm_planned_crew_count: pmCount,
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

  board205PopulateScenes();
  board205PopulateSeasonPlacementOptions();
  board205PopulateWorkOrderOptions();
}

function board205PopulateSeasonPlacementOptions() {
  const stageValue = document.getElementById('setup-board205-season-stage')?.value || '';
  const stageId = stageValue ? Number(stageValue) : null;
  const tasks = (setupBoard205State.board.tasks || []).filter((task) => (
    stageId == null ? task.stage_id == null : Number(task.stage_id) === stageId
  ));
  const options = '<option value="">— none —</option>' + tasks.map((task) => (
    `<option value="${task.setup_session_task_id}">${board205Esc(task.planned_order ?? '—')} — ${board205Esc(task.task_name)}</option>`
  )).join('');
  const prior = document.getElementById('setup-board205-season-prereq');
  const downstream = document.getElementById('setup-board205-season-downstream');
  if (prior) prior.innerHTML = options;
  if (downstream) downstream.innerHTML = options;
}

function board205PopulateWorkOrderOptions(selectedId = null) {
  const select = document.getElementById('setup-board205-season-work-order');
  if (!select) return;

  const search = String(
    document.getElementById('setup-board205-season-work-order-search')?.value || ''
  ).trim().toLowerCase();
  const selected = selectedId == null ? String(select.value || '') : String(selectedId || '');

  const rows = (setupBoard205State.board.work_orders || []).filter((wo) => {
    if (!search) return true;
    const haystack = [
      wo.work_order_id,
      `wo ${wo.work_order_id}`,
      wo.problem || ''
    ].join(' ').toLowerCase();
    return haystack.includes(search);
  });

  select.innerHTML = '<option value="">No Work Order</option>' + rows.map((wo) => {
    const problem = String(wo.problem || '').trim();
    const label = `WO ${wo.work_order_id}${problem ? ` · ${problem}` : ''}`;
    return `<option value="${wo.work_order_id}">${board205Esc(label)}</option>`;
  }).join('');

  if (selected && [...select.options].some((option) => option.value === selected)) {
    select.value = selected;
  }
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
  const volunteerNote = document.getElementById('setup-board205-volunteer-note').value.trim() || null;
  const existing = board205ExistingWorkDayDates();
  const dates = [...setupBoard205State.workDaySelection]
    .filter((date) => !existing.has(date))
    .sort();
  if (!dates.length) return;

  const sundays = dates.filter((date) => new Date(date + 'T00:00:00Z').getUTCDay() === 0);
  if (
    sundays.length
    && !window.confirm(
      sundays.join(', ') + (sundays.length === 1 ? ' is a Sunday' : ' are Sundays') +
      '. MSB normally avoids Sunday Setup work. Add ' +
      (sundays.length === 1 ? 'it' : 'them') + ' deliberately anyway?'
    )
  ) return;

  let created = 0;
  try {
    setBusy(true);
    for (const date of dates) {
      if (board205ExistingWorkDayDates().has(date)) continue;
      await api('api/setup/scheduling-board/work-days', commandOptions('POST', {
        season_year: Number(appState.seasonYear),
        work_date: date,
        setup_day_number: null,
        day_status: 'PLANNED',
        volunteer_note: volunteerNote
      }));
      created += 1;
    }
    setupBoard205State.workDaySelection.clear();
    form.reset();
    setupBoard205State.workDayPickerExpanded = false;
    const showEmptyDays = document.getElementById('setup-board205-show-empty-days');
    if (showEmptyDays) showEmptyDays.checked = true;
    await board205Load();
    setAlert(String(created) + ' Work Day' + (created === 1 ? '' : 's') + ' added.', 'ok');
  } catch (error) {
    setupBoard205State.workDaySelection.clear();
    await board205Load();
    setAlert(
      created
        ? String(created) + ' Work Day' + (created === 1 ? '' : 's') + ' added before the next date failed: ' + (error.message || error)
        : (error.message || error),
      'error'
    );
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}


function board205OpenPlanningInfoDialog(sessionTaskId = null, reusableTaskId = null) {
  const reusableId = Number(reusableTaskId || 0) || null;
  const task = sessionTaskId
    ? board205Task(sessionTaskId)
    : (setupBoard205State.board.tasks || []).find(
        (row) => Number(row.setup_task_id) === Number(reusableId)
      );
  const dialog = document.getElementById('setup-board205-planning-dialog');
  const form = document.getElementById('setup-board205-planning-form');
  if (!task || !dialog || !form) return;

  setupBoard205State.editPlanningTaskId = sessionTaskId || null;
  setupBoard205State.editPlanningReusableTaskId = Number(task.setup_task_id || reusableId || 0) || null;

  form.reset();
  document.getElementById('setup-board205-planning-heading').textContent = `Edit Planning Info — ${task.task_name}`;

  const reusablePlanning = board205HistoricalReviewMode() && task.task_origin === 'REUSABLE';
  document.getElementById('setup-board205-planning-origin').textContent = reusablePlanning
    ? 'Updates current reusable planning knowledge. Historical 2025 facts are not changed.'
    : task.task_origin === 'REUSABLE'
      ? 'Updates reusable task knowledge and the current annual planning snapshot.'
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

  const reusableNotesRow = document.getElementById('setup-board205-planning-reusable-notes-row');
  const reusableNotes = document.getElementById('setup-board205-planning-reusable-notes');
  if (reusableNotesRow && reusableNotes) {
    reusableNotesRow.hidden = task.task_origin !== 'REUSABLE';
    reusableNotes.value = task.reusable_notes || '';
  }

  const fullTask = document.getElementById('setup-board205-open-full-reusable');
  if (fullTask) {
    fullTask.hidden = task.task_origin !== 'REUSABLE' || !setupBoard205State.editPlanningReusableTaskId;
  }

  dialog.showModal();
}

function board205PlanningMinutes() {
  const hours = nullableInteger(document.getElementById('setup-board205-planning-hours').value) || 0;
  const minutes = nullableInteger(document.getElementById('setup-board205-planning-minutes').value) || 0;
  const total = hours * 60 + minutes;
  return total > 0 ? total : null;
}

function board205PlanningDraft() {
  return {
    normal_crew_min: nullableInteger(document.getElementById('setup-board205-planning-crew-min').value),
    normal_crew_max: nullableInteger(document.getElementById('setup-board205-planning-crew-max').value),
    expected_duration_minutes: board205PlanningMinutes(),
    effort_level: document.getElementById('setup-board205-planning-effort').value || null,
    readiness_note: document.getElementById('setup-board205-planning-readiness').value.trim() || null,
    weather_note: document.getElementById('setup-board205-planning-weather').value.trim() || null,
    completion_point: document.getElementById('setup-board205-planning-completion').value.trim() || null,
    reusable_notes: document.getElementById('setup-board205-planning-reusable-notes')?.value.trim() || null
  };
}

function board205PlanningTaskState(task) {
  return {
    normal_crew_min: task?.normal_crew_min == null ? null : Number(task.normal_crew_min),
    normal_crew_max: task?.normal_crew_max == null ? null : Number(task.normal_crew_max),
    expected_duration_minutes: task?.expected_duration_minutes == null ? null : Number(task.expected_duration_minutes),
    effort_level: task?.effort_level || null,
    readiness_note: String(task?.readiness_note || '').trim() || null,
    weather_note: String(task?.weather_note || '').trim() || null,
    completion_point: String(task?.completion_point || '').trim() || null,
    reusable_notes: String(task?.reusable_notes || '').trim() || null
  };
}

function board205PlanningInfoDirty() {
  const sessionTaskId = setupBoard205State.editPlanningTaskId;
  const reusableTaskId = setupBoard205State.editPlanningReusableTaskId;
  const task = sessionTaskId
    ? board205Task(sessionTaskId)
    : (setupBoard205State.board.tasks || []).find(
        (row) => Number(row.setup_task_id) === Number(reusableTaskId)
      );
  if (!task) return false;
  return JSON.stringify(board205PlanningDraft()) !== JSON.stringify(board205PlanningTaskState(task));
}

async function board205PersistPlanningInfo({ closeDialog = true, announce = true } = {}) {
  const sessionTaskId = setupBoard205State.editPlanningTaskId;
  const reusableTaskId = setupBoard205State.editPlanningReusableTaskId;
  if (!sessionTaskId && !reusableTaskId) return false;

  const draft = board205PlanningDraft();

  try {
    setBusy(true);

    const reusablePlanning = board205HistoricalReviewMode() && reusableTaskId;
    if (reusablePlanning) {
      const current = taskById(reusableTaskId);
      if (!current) throw new Error('Reusable task is not available in the current Catalog.');

      await api(`api/setup/tasks/${reusableTaskId}`, commandOptions('PATCH', {
        task_name: current.task_name,
        stage_id: current.stage_id,
        task_action_type: current.task_action_type || 'WORK',
        display_order: current.display_order ?? 100,
        active_flag: Boolean(current.active_flag),
        normal_crew_min: draft.normal_crew_min,
        normal_crew_max: draft.normal_crew_max,
        expected_duration_minutes: draft.expected_duration_minutes,
        completion_point: draft.completion_point,
        readiness_note: draft.readiness_note,
        weather_note: draft.weather_note,
        reusable_notes: draft.reusable_notes
      }));

      if ((current.effort_level || null) !== draft.effort_level) {
        await api(
          `api/setup/tasks/${reusableTaskId}/effort`,
          commandOptions('PATCH', { effort_level: draft.effort_level })
        );
      }

      // Refresh the shared task cache before any drill-down so full detail
      // opens with the just-saved values and authoritative audit attribution.
      await reloadTasks(reusableTaskId);
      await board205Load();
      if (announce) setAlert('Reusable planning information updated.', 'ok');
    } else {
      await api(`api/setup/scheduling-board/season-tasks/${sessionTaskId}/planning-info`, commandOptions('PATCH', {
        ...draft
      }));
      await board205Load();
      if (announce) setAlert('Scheduling planning information updated.', 'ok');
    }

    if (closeDialog) {
      document.getElementById('setup-board205-planning-dialog')?.close();
    }
    return true;
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
    return false;
  } finally {
    setBusy(false);
  }
}

async function board205SubmitPlanningInfo(event) {
  event.preventDefault();
  await board205PersistPlanningInfo();
}

async function board205CreateAnnualSession() {
  const year = Number(appState.seasonYear);
  if (!appState.access?.can_admin_setup || !Number.isInteger(year)) return;
  if (setupBoard205State.board.session) return;

  const activeCount = (appState.tasks || []).filter((task) => task.active_flag).length;
  const confirmed = window.confirm(
    `Create the real ${year} Setup Session now?\n\n`
    + `This seeds every active reusable Catalog task into ${year} exactly once`
    + (activeCount ? ` (currently ${activeCount} active reusable tasks).` : '.')
    + '\n\nAfter creation you can begin adding work days and scheduling. '
    + 'Normal planning remains editable; actual reported work becomes protected history.\n\n'
    + 'Create the annual Session?'
  );
  if (!confirmed) return;

  try {
    setBusy(true);
    const result = await api('api/setup/sessions', commandOptions('POST', {
      season_year: year,
      session_status: 'PLANNING'
    }));
    const seasonsPayload = await api('api/setup/seasons');
    appState.seasons = seasonsPayload.seasons || [];
    await loadSeason(year);
    await board205Load();
    const seeded = result.setup_session?.seeded_task_count;
    setAlert(
      `${year} Setup Session created${seeded == null ? '' : ` with ${seeded} reusable task(s)`}. You can start scheduling now.`,
      'ok'
    );
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function board205OpenAddTaskIntentDialog() {
  if (!setupBoard205State.board.session || !appState.access?.can_manage_setup) return;
  document.getElementById('setup-board205-add-intent-dialog')?.showModal();
}

async function board205ChooseReusableTask() {
  document.getElementById('setup-board205-add-intent-dialog')?.close();
  if (typeof navigateSetupView === 'function') {
    await navigateSetupView('library');
  } else {
    showView('library');
  }

  if (typeof acceptanceOpenAddTask === 'function') {
    acceptanceOpenAddTask(null, null);
  } else {
    document.getElementById('show-add-task')?.click();
  }
  setAlert(
    `Reusable task: this becomes permanent Catalog work and is automatically added to the open ${appState.seasonYear} Setup Session.`,
    'ok'
  );
}

function board205ChooseSeasonOnlyTask() {
  document.getElementById('setup-board205-add-intent-dialog')?.close();
  board205OpenSeasonTaskDialog();
}

async function board205DeleteSeasonTask() {
  const sessionTaskId = setupBoard205State.editSeasonTaskId;
  const task = board205Task(sessionTaskId);
  if (!task || task.task_origin !== 'SEASON_ONLY' || !appState.access?.can_manage_setup) return;

  const confirmed = window.confirm(
    `Delete "${task.task_name}" from ${appState.seasonYear}?\n\n`
    + 'This task is THIS SEASON ONLY. Planning-only day/crew assignments and prerequisite links will be removed with it.\n\n'
    + 'The database will refuse deletion if actual work/progress or execution evidence has been reported.\n\n'
    + 'Delete this season-only task?'
  );
  if (!confirmed) return;

  try {
    setBusy(true);
    await api(
      `api/setup/scheduling-board/season-tasks/${sessionTaskId}`,
      commandOptions('DELETE')
    );
    document.getElementById('setup-board205-season-dialog')?.close();
    setupBoard205State.editSeasonTaskId = null;
    await board205Load();
    setAlert('Unworked season-only Setup task deleted.', 'ok');
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
  const deleteButton = document.getElementById('setup-board205-delete-season-task');
  if (deleteButton) deleteButton.hidden = sessionTaskId == null;
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
    document.getElementById('setup-board205-season-work-order-search').value = '';
    board205PopulateWorkOrderOptions(task.linked_work_order_id ?? '');
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
      <div id="setup-board205-no-session" class="card" hidden>
        <strong>No annual Setup Session exists for this season.</strong>
        <p class="muted">The reusable Catalog is ready. A Setup Administrator can create the real annual Session here; creation seeds every active reusable task once and does not schedule any work by itself.</p>
        <div class="action-row">
          <button id="setup-board205-create-session" type="button" class="admin-only" hidden>Create Setup Session</button>
        </div>
      </div>

      <div id="setup-board205-workspace" class="setup-board205-main">
        <section class="card setup-board205-backlog">
          <div class="eyebrow">Current reusable Catalog</div>
          <h3 id="setup-board205-finder-title">Current Reusable Task Finder</h3>
          <div id="setup-board205-historical-note" class="notice" hidden>
            <strong>Pre-2026 planning — current reusable Catalog.</strong>
            Use the current reusable tasks to review crew guidance, expected time, readiness, notes, and plan order. The 2025 construction marker does not define this task list or current planning state. Work days, crews, and assignments remain disabled until the real annual Session is created.
          </div>
          <div id="setup-board205-filters" class="setup-board205-filters setup-board205-finder">
            <div class="setup-board205-primary-filters">
              <label>Stage / area<select id="setup-board205-stage-filter"><option value="">All Stages / areas</option></select></label>
              <label>Sort<select id="setup-board205-sort">
                <option value="PLAN">Plan order</option>
                <option value="STAGE">Stage / Scene</option>
                <option value="NAME">Task name</option>
                <option value="STATUS">Status</option>
                <option value="DURATION">Expected duration</option>
                <option value="CREW">Minimum crew</option>
              </select></label>
            </div>
            <label id="setup-board205-scene-label" hidden>Scene / scope<select id="setup-board205-scene-filter" disabled><option value="">All scope details</option></select></label>
            <label class="setup-board205-search">Task name<input id="setup-board205-task-search" type="search" placeholder="e.g. locate"></label>
            <label class="setup-board205-blocking-toggle"><input id="setup-board205-blocking-toggle" type="checkbox" checked> Blocking ON</label>
            <button id="setup-board205-filter-density" type="button" class="small secondary" aria-expanded="true">Compact filters</button>
            <div class="setup-board205-blocking-help">ON hides tasks whose hard predecessor is incomplete. A Work Order gate task itself stays visible; the task after it remains hard-blocked until the Work Order clears. Readiness stays a soft blocker; use Ready only when you want to temporarily hide NOT READY work.</div>
            <div class="setup-board205-secondary-filters">
            <fieldset class="setup-board205-status-filter">
              <legend>Status / readiness shown when Task name is blank</legend>
              <label><input id="setup-board205-status-ready" type="checkbox" checked> Ready / needs continuation</label>
              <label><input id="setup-board205-status-scheduled" type="checkbox"> Scheduled</label>
              <label><input id="setup-board205-ready-only" type="checkbox"> Ready only</label>
              <label><input id="setup-board205-status-complete" type="checkbox"> Complete</label>
            </fieldset>
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
          </div>
          <div id="setup-board205-finder-summary" class="muted"></div>
          <div id="setup-board205-queue" class="setup-board205-queue"></div>
        </section>

        <div class="setup-board205-right">
          <section class="card setup-board205-planning-header">
            <div class="setup-board205-toolbar">
              <div class="setup-board205-title">
                <div class="eyebrow">Rolling annual dispatch · historical learning</div>
                <h2>Setup Scheduling Board</h2>
              </div>
              <div id="setup-board205-kpis" class="setup-board205-kpis" aria-live="polite"></div>
              <div class="setup-board205-toolbar-actions">
                <button id="setup-board205-add-season-task" type="button" class="manager-only">Add Task</button>
              </div>
            </div>
            <form id="setup-board205-day-form" class="setup-board205-day-form" hidden>
              <div class="setup-board205-work-day-collapsed">
                <button id="setup-board205-toggle-work-days" type="button" class="small" aria-expanded="false">+ Add Work Days</button>
                <span class="setup-board205-auto-day-note">Open only when you need to add dates.</span>
              </div>
              <div id="setup-board205-work-day-picker-body" class="setup-board205-work-day-picker" hidden>
                <div class="setup-board205-work-day-picker-copy">
                  <strong>Add Work Days</strong>
                  <span class="setup-board205-auto-day-note">Tap dates to select or deselect them. Existing Work Days are disabled. Setup Day # is assigned automatically in chronological order.</span>
                </div>
                <div id="setup-board205-work-day-calendar" class="setup-board205-work-day-calendar" aria-label="Select Work Day dates"></div>
                <div id="setup-board205-work-day-selection" class="muted" aria-live="polite"></div>
                <label class="setup-board205-volunteer-note">Volunteer / capacity note<input id="setup-board205-volunteer-note" type="text" placeholder="Optional; applied to all selected dates"></label>
                <div class="setup-board205-work-day-actions">
                  <button id="setup-board205-add-work-days" type="submit" disabled>Add Selected Work Days</button>
                  <button id="setup-board205-cancel-work-days" type="button" class="secondary">Cancel</button>
                </div>
              </div>
            </form>
          </section>

          <section id="setup-board205-board-pane" class="card setup-board205-board">
            <div class="eyebrow">Setup Day Number · DOW · Date</div>
            <div class="setup-board205-board-heading">
              <div class="setup-board205-board-title-row">
                <h3>Rolling Work Days</h3>
                <button id="setup-board205-print" type="button" class="small">Print Schedule</button>
              </div>
              <p class="muted">Each work day starts with Crew A. Add crews only when needed. Schedule in AM/PM shifts; planned headcount is optional by crew and shift. Historical actual assignments are locked.</p>
              <div class="setup-board205-day-filters" aria-label="Day view">
                <strong>Day view</strong>
                <label><input id="setup-board205-show-unfinished-days" type="checkbox" checked> Scheduled / unfinished</label>
                <label><input id="setup-board205-show-completed-days" type="checkbox"> Completed / cancelled</label>
                <label><input id="setup-board205-show-empty-days" type="checkbox" checked> Empty days</label>
              </div>
            </div>
            <div id="setup-board205-days" class="setup-board205-days"></div>
          </section>
        </div>
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
        <label id="setup-board205-planning-reusable-notes-row">Reusable notes<textarea id="setup-board205-planning-reusable-notes" rows="4"></textarea></label>
        <menu><button id="setup-board205-open-full-reusable" type="button" class="secondary" hidden>Open Full Reusable Task</button><button type="button" class="secondary setup-board205-dialog-cancel">Cancel</button><button type="submit">Save Planning Info</button></menu>
      </form>
    </dialog>

    <dialog id="setup-board205-add-intent-dialog" class="setup-board205-dialog">
      <form method="dialog">
        <h3>What kind of task is this?</h3>
        <p class="muted">Choose deliberately. There is no default because these choices have different long-term meaning.</p>
        <div class="setup-board205-choice-stack">
          <button id="setup-board205-add-reusable" type="button">
            Reusable Setup Task — every year
          </button>
          <p class="muted">Creates permanent reusable Catalog work and automatically adds it to the open annual Session.</p>
          <button id="setup-board205-add-season-only" type="button" class="secondary">
            Season Task Only — this season
          </button>
          <p class="muted">Creates annual work only. It does not enter the Reusable Task Catalog.</p>
        </div>
        <menu><button type="button" class="secondary setup-board205-dialog-cancel">Cancel</button></menu>
      </form>
    </dialog>

    <dialog id="setup-board205-season-dialog" class="setup-board205-dialog">
      <form id="setup-board205-season-form">
        <h3 id="setup-board205-season-heading">Add Season Task</h3>
        <p class="muted"><strong>THIS SEASON ONLY.</strong> This work belongs only to the annual Setup Session and does not enter the Reusable Task Catalog.</p>
        <label>Task name<input id="setup-board205-season-name" type="text" required></label>
        <div class="setup-board205-form-grid">
          <label>Stage<select id="setup-board205-season-stage"></select></label>
          <label>Scene<select id="setup-board205-season-scene"></select></label>
          <label>Type<select id="setup-board205-season-type"><option value="WORK">Setup Work</option><option value="GATE">Wait / Gate</option><option value="SUPPORT">Support / Prep</option><option value="UNLOAD_CONTAINER">Unload Container</option></select></label>
          <div class="setup-board205-work-order-picker">
            <label>Find open Work Order<input id="setup-board205-season-work-order-search" type="search" placeholder="WO # or problem text" autocomplete="off"></label>
            <label>Matching Work Order<select id="setup-board205-season-work-order"><option value="">No Work Order</option></select></label>
          </div>
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
          <label>Place after / requires<select id="setup-board205-season-prereq"></select></label>
          <label>Optional downstream task to block<select id="setup-board205-season-downstream"></select></label>
        </div>
        <menu><button id="setup-board205-delete-season-task" type="button" class="danger" hidden>Delete Season Task</button><button type="button" class="secondary setup-board205-dialog-cancel">Cancel</button><button type="submit">Save Season Task</button></menu>
      </form>
    </dialog>
  `;

  document.getElementById('setup-board205-filter-density')?.addEventListener('click', () => {
    setupBoard205State.finderCompact = !Boolean(setupBoard205State.finderCompact);
    board205ApplyFinderCompact();
  });

  document.getElementById('setup-board205-season-work-order-search')?.addEventListener('input', () => {
    board205PopulateWorkOrderOptions();
  });

  const finderFilters = document.getElementById('setup-board205-filters');
  finderFilters?.addEventListener('change', (event) => {
    const control = event.target?.closest?.('input,select');
    if (!control || !finderFilters.contains(control)) return;
    if (control.id === 'setup-board205-stage-filter') board205SyncFinderSceneOptions();
    if (control.id === 'setup-board205-blocking-toggle') {
      const label = control.closest('label');
      if (label) {
        label.lastChild.textContent = control.checked ? ' Blocking ON' : ' Blocking OFF';
      }
    }
    board205RenderQueue();
  });
  finderFilters?.addEventListener('input', (event) => {
    const control = event.target?.closest?.('input');
    if (!control || !finderFilters.contains(control)) return;
    if (control.type === 'search' || control.type === 'number') board205RenderQueue();
  });
  document.getElementById('setup-board205-day-form').addEventListener('submit', board205AddWorkDay);
  document.getElementById('setup-board205-toggle-work-days')?.addEventListener('click', () => {
    setupBoard205State.workDayPickerExpanded = !setupBoard205State.workDayPickerExpanded;
    board205ApplyWorkDayPickerExpanded();
  });
  document.getElementById('setup-board205-cancel-work-days')?.addEventListener('click', () => {
    setupBoard205State.workDaySelection.clear();
    document.getElementById('setup-board205-day-form')?.reset();
    setupBoard205State.workDayPickerExpanded = false;
    board205RenderWorkDayCalendar();
  });
  document.querySelectorAll('.setup-board205-day-filters input').forEach((control) => {
    control.addEventListener('change', board205RenderBoard);
  });
  document.querySelectorAll('.setup-board205-backlog, .setup-board205-board').forEach((pane) => {
    pane.addEventListener('dragover', (event) => board205AutoScrollPane(pane, event), true);
  });
  document.getElementById('setup-board205-print')?.addEventListener('click', () => window.print());
  document.getElementById('setup-board205-add-season-task').addEventListener('click', board205OpenAddTaskIntentDialog);
  document.getElementById('setup-board205-create-session')?.addEventListener('click', board205CreateAnnualSession);
  document.getElementById('setup-board205-add-reusable')?.addEventListener('click', () => { void board205ChooseReusableTask(); });
  document.getElementById('setup-board205-add-season-only')?.addEventListener('click', board205ChooseSeasonOnlyTask);
  document.getElementById('setup-board205-delete-season-task')?.addEventListener('click', () => { void board205DeleteSeasonTask(); });
  document.getElementById('setup-board205-schedule-dialog-form').addEventListener('submit', board205SubmitScheduleDialog);
  document.getElementById('setup-board205-schedule-day').addEventListener('change', (event) => {
    board205PopulateCrewSelect(Number(event.currentTarget.value || 0));
  });
  document.getElementById('setup-board205-planning-form').addEventListener('submit', board205SubmitPlanningInfo);
  document.getElementById('setup-board205-open-full-reusable')?.addEventListener('click', () => {
    void (async () => {
      const reusableTaskId = setupBoard205State.editPlanningReusableTaskId;
      if (!reusableTaskId) return;

      if (board205PlanningInfoDirty()) {
        const saved = await board205PersistPlanningInfo({ closeDialog: false, announce: false });
        if (!saved) return;
        setAlert('Planning edits saved before opening the full reusable task.', 'ok');
      }

      document.getElementById('setup-board205-planning-dialog')?.close();
      if (typeof setupNavigateToReusableTaskFromFinder === 'function') {
        await setupNavigateToReusableTaskFromFinder(reusableTaskId);
      } else {
        showView('review');
        selectTask(reusableTaskId);
      }
    })();
  });
  document.getElementById('setup-board205-season-form').addEventListener('submit', board205SubmitSeasonTask);
  document.getElementById('setup-board205-season-stage').addEventListener('change', () => {
    board205PopulateScenes();
    board205PopulateSeasonPlacementOptions();
  });
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
if (document.getElementById('schedule-view')?.classList.contains('active-view')) {
  void board205Load();
}
