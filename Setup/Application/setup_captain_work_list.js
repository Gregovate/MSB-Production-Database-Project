/* Setup #175 Captain Work List — connected/read-only sample over the accepted #205 schedule. */
const state = {
  seasons: [],
  year: null,
  board: null,
  catalog: [],
  enrichment: new Map(),
  generatedAt: new Date()
};

const byId = (id) => document.getElementById(id);
const params = new URLSearchParams(window.location.search);

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

async function api(path) {
  const response = await fetch('../' + String(path).replace(/^\/+/, ''), {
    credentials: 'same-origin',
    headers: { Accept: 'application/json' }
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || 'Setup API returned HTTP ' + response.status);
  return payload;
}

function setStatus(message, kind = '') {
  const target = byId('status');
  target.textContent = message;
  target.className = 'status' + (kind ? ' ' + kind : '');
}

function formatDate(dateText) {
  if (!dateText) return '';
  const parsed = new Date(dateText + 'T12:00:00');
  return Number.isNaN(parsed.valueOf())
    ? dateText
    : parsed.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' });
}

function formatDuration(minutes) {
  if (minutes == null || Number(minutes) <= 0) return 'Time not reviewed';
  const total = Number(minutes);
  const hours = Math.floor(total / 60);
  const mins = total % 60;
  if (!hours) return mins + ' min';
  if (!mins) return hours + (hours === 1 ? ' hr' : ' hrs');
  return hours + (hours === 1 ? ' hr ' : ' hrs ') + mins + ' min';
}

function expectedCrew(task) {
  const min = task.normal_crew_min;
  const max = task.normal_crew_max;
  if (min == null && max == null) return 'Crew not reviewed';
  if (min != null && max != null && Number(min) !== Number(max)) return min + '–' + max + ' people';
  return String(min ?? max) + ' people';
}

function taskScope(task) {
  if (task.stage_id == null) return 'Site-wide / Infrastructure';
  const stage = 'Stage ' + (task.stage_key || '—') + (task.stage_name ? ' — ' + task.stage_name : '');
  return task.scene_name ? stage + ' / ' + task.scene_name : stage + ' / Stage-level';
}

function cleanImportantNotes(value) {
  const text = String(value || '').trim();
  if (!text) return '';
  return text
    .split(/\r?\n/)
    .filter((line) => !/^\s*\[Copied from reusable task \d+; verify destination-specific details\.\]\s*$/i.test(line))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function catalogTask(setupTaskId) {
  return state.catalog.find((item) => Number(item.setup_task_id) === Number(setupTaskId)) || null;
}

function selectedDay() {
  const id = Number(byId('work-day-select').value || 0);
  return (state.board?.work_days || []).find((day) => Number(day.setup_work_day_id) === id) || null;
}

function selectedCrewId() {
  const raw = byId('crew-select').value;
  return raw === 'ALL' ? null : Number(raw);
}

function captainForCrew(crew) {
  if (!crew?.captain_person_id) return null;
  return (state.board?.captain_candidates || []).find(
    (person) => Number(person.person_id) === Number(crew.captain_person_id)
  ) || null;
}

function plannedCrewForAssignment(assignment, crew) {
  if (assignment.planned_crew_count != null) return Number(assignment.planned_crew_count);
  if (!crew) return null;
  if (assignment.shift_code === 'MORNING') return crew.am_planned_crew_count;
  if (assignment.shift_code === 'AFTERNOON') return crew.pm_planned_crew_count;
  return null;
}

function currentVisibleAssignments() {
  const day = selectedDay();
  if (!day) return [];
  const crewId = selectedCrewId();
  return (state.board?.assignments || []).filter((item) => (
    Number(item.setup_work_day_id) === Number(day.setup_work_day_id)
    && (crewId == null || Number(item.setup_work_day_crew_id) === crewId)
  ));
}

async function enrichTask(task) {
  const key = Number(task.setup_session_task_id);
  if (state.enrichment.has(key)) return state.enrichment.get(key);

  const result = { procedure: null, context: null };
  if (task.setup_task_id != null) {
    const [procedureResult, contextResult] = await Promise.allSettled([
      api('api/setup/tasks/' + task.setup_task_id + '/procedure'),
      api('api/setup/tasks/' + task.setup_task_id + '/field-context?season_year=' + encodeURIComponent(state.year))
    ]);
    if (procedureResult.status === 'fulfilled') result.procedure = procedureResult.value.instructions || {};
    if (contextResult.status === 'fulfilled') result.context = contextResult.value.context || {};
  }
  state.enrichment.set(key, result);
  return result;
}

function materialText(task, enrichment) {
  const parts = [];
  const context = enrichment?.context || {};
  const displays = context.displays || [];
  const displayContainers = new Map();
  displays.forEach((display) => {
    if (display.container_id == null) return;
    const label = 'C' + String(display.container_id).padStart(3, '0')
      + (display.container_description ? ' · ' + display.container_description : '');
    displayContainers.set(Number(display.container_id), label);
  });
  if (displayContainers.size) {
    parts.push('Display material: ' + [...displayContainers.values()].join(', '));
  } else if (task.requires_display_material) {
    parts.push('Display material required; current Container summary is not available.');
  }
  if (task.support_container_summary) parts.push('Kit / support: ' + task.support_container_summary);
  if (task.extra_material_summary) parts.push('Extra materials: ' + task.extra_material_summary);
  if (!parts.length) return 'No structured material requirement recorded.';
  return parts.join('\n');
}

function procedureMarkup(task, enrichment) {
  if (task.setup_task_id == null) {
    return '<span class="missing">Season-only task — no reusable Procedure scope is linked.</span>';
  }
  const instructions = enrichment?.procedure || {};
  const docs = instructions.current_documents || instructions.documents || [];
  if (!docs.length) return '<span class="missing">No current published Setup Procedure resolved.</span>';
  return '<ul class="procedure-list">' + docs.map((doc) => {
    const name = doc.name || 'Open current Procedure';
    const href = '../api/setup/tasks/' + task.setup_task_id
      + '/procedure/current?name=' + encodeURIComponent(name);
    return '<li><a target="_blank" rel="noopener" href="' + href + '">' + escapeHtml(name) + '</a></li>';
  }).join('') + '</ul>';
}

function prerequisitesMarkup(task) {
  const deps = (state.board?.dependencies || []).filter(
    (dep) => Number(dep.setup_session_task_id) === Number(task.setup_session_task_id)
  );
  if (!deps.length) return '<span class="missing">No hard prerequisite.</span>';
  return '<ul class="prereq-list">' + deps.map((dep) => (
    '<li class="' + (dep.prerequisite_complete ? 'prereq-done' : 'prereq-open') + '">'
      + (dep.prerequisite_complete ? '✓ ' : '○ ')
      + escapeHtml(dep.prerequisite_task_name)
      + (dep.dependency_note ? ' — ' + escapeHtml(dep.dependency_note) : '')
      + '</li>'
  )).join('') + '</ul>';
}

function valueBlock(label, value, full = false) {
  return '<div class="info' + (full ? ' full' : '') + '"><span class="info-label">'
    + escapeHtml(label) + '</span><div class="info-value">'
    + (value ? escapeHtml(value) : '<span class="missing">Not recorded</span>')
    + '</div></div>';
}

function taskCard(assignment, task, enrichment, crew) {
  const catalog = catalogTask(task.setup_task_id);
  const importantNotes = cleanImportantNotes(
    task.setup_task_id != null ? catalog?.reusable_notes : task.annual_notes
  );
  const planned = plannedCrewForAssignment(assignment, crew);
  const readiness = task.readiness_note || 'No special readiness condition recorded.';
  const weather = task.weather_note || 'No special weather limit recorded.';
  const done = task.completion_point || 'Completion point not yet documented.';
  const resourceText = task.resource_summary || 'No structured Equipment / Resource requirement recorded.';
  const reportHref = '../?season_year=' + encodeURIComponent(state.year)
    + '&view=perform&setup_session_task_id=' + encodeURIComponent(task.setup_session_task_id)
    + '&setup_work_day_id=' + encodeURIComponent(assignment.setup_work_day_id)
    + '&setup_work_day_task_id=' + encodeURIComponent(assignment.setup_work_day_task_id)
    + '&shift_code=' + encodeURIComponent(assignment.shift_code || 'ALL_DAY')
    + '&crew_id=' + encodeURIComponent(assignment.setup_work_day_crew_id || '')
    + '&crew_code=' + encodeURIComponent(assignment.crew_lane || crew?.crew_code || '')
    + '&work_date=' + encodeURIComponent(assignment.work_date || '');
  const blocked = String(task.readiness_state || '').toUpperCase() === 'NOT_READY'
    || !task.prerequisites_complete;
  const complete = Boolean(task.effective_complete);
  const material = materialText(task, enrichment);
  const materialReview = Number(task.extra_material_review_count || 0) > 0
    ? '<div class="review-warning">Some Extra Material information still needs review.</div>'
    : '';

  return '<article class="task-card' + (blocked ? ' not-ready' : '') + (complete ? ' complete' : '') + '">'
    + '<div class="task-heading"><div><h3>' + escapeHtml(task.task_name) + '</h3>'
    + '<div class="scope">' + escapeHtml(taskScope(task)) + '</div></div>'
    + '<div class="badges">'
    + '<span class="badge">' + escapeHtml(String(assignment.shift_code || '').replaceAll('_', ' ')) + '</span>'
    + (blocked ? '<span class="badge blocked">CHECK BEFORE STARTING</span>' : '')
    + (complete ? '<span class="badge">COMPLETE</span>' : '')
    + '</div></div>'
    + '<div class="info-grid">'
    + valueBlock('Can start when', readiness)
    + valueBlock('Weather limits', weather)
    + valueBlock('Done when', done)
    + valueBlock('Expected / planned crew', expectedCrew(task)
        + (planned == null ? '' : ' · Planned ' + planned))
    + valueBlock('Expected duration', formatDuration(task.expected_duration_minutes))
    + '<div class="info"><span class="info-label">Hard prerequisites</span><div class="info-value">'
        + prerequisitesMarkup(task) + '</div></div>'
    + valueBlock('Equipment / Resources', resourceText, true)
    + valueBlock('Important setup notes', importantNotes || 'No additional important setup note recorded.', true)
    + '<div class="info full"><span class="info-label">Material summary</span><div class="info-value">'
        + escapeHtml(material).replaceAll('\n', '<br>') + materialReview + '</div></div>'
    + '<div class="info full"><span class="info-label">Procedure</span><div class="info-value">'
        + procedureMarkup(task, enrichment) + '</div></div>'
    + '</div>'
    + '<div class="task-actions no-print"><a class="primary" href="' + reportHref + '">Report Work</a>'
    + (task.setup_task_id != null
      ? '<a class="secondary-link" href="../?season_year=' + encodeURIComponent(state.year)
          + '&view=review&setup_task_id=' + encodeURIComponent(task.setup_task_id) + '">Open Setup Task</a>'
      : '')
    + '</div></article>';
}

function groupAssignments(assignments) {
  const groups = [];
  assignments.forEach((assignment) => {
    const key = String(assignment.setup_work_day_crew_id || assignment.crew_lane || 'UNASSIGNED')
      + '|' + String(assignment.shift_code || 'ALL_DAY');
    let group = groups.find((item) => item.key === key);
    if (!group) {
      group = { key, crewId: assignment.setup_work_day_crew_id, shift: assignment.shift_code, assignments: [] };
      groups.push(group);
    }
    group.assignments.push(assignment);
  });
  return groups;
}

async function renderWorkList() {
  const day = selectedDay();
  const assignments = currentVisibleAssignments();
  const taskMap = new Map((state.board?.tasks || []).map((task) => [Number(task.setup_session_task_id), task]));
  const visibleTasks = assignments.map((assignment) => taskMap.get(Number(assignment.setup_session_task_id))).filter(Boolean);

  setStatus('Loading current Procedure and material context…');
  await Promise.all(visibleTasks.map((task) => enrichTask(task)));

  if (!day) {
    byId('work-list').innerHTML = '';
    setStatus('No scheduled Setup work day is available for this season.', 'error');
    return;
  }

  byId('scope-title').textContent = state.year + ' Setup · ' + formatDate(day.work_date);
  byId('generated-at').textContent = 'Generated: ' + state.generatedAt.toLocaleString();

  const context = byId('day-context');
  const dayNotes = [
    day.weather_note ? '<p><strong>Day weather / condition note:</strong> ' + escapeHtml(day.weather_note) + '</p>' : '',
    day.volunteer_note ? '<p><strong>Volunteer / crew note:</strong> ' + escapeHtml(day.volunteer_note) + '</p>' : '',
    day.notes ? '<p><strong>Day note:</strong> ' + escapeHtml(day.notes) + '</p>' : ''
  ].filter(Boolean).join('');
  context.innerHTML = '<h2>Setup Day ' + escapeHtml(day.setup_day_number ?? '—') + ' · '
    + escapeHtml(formatDate(day.work_date)) + '</h2>' + dayNotes;
  context.hidden = false;

  if (!assignments.length) {
    byId('work-list').innerHTML = '';
    setStatus('No tasks are scheduled for the selected work day / crew.', 'error');
    updateEmailLink();
    return;
  }

  const crewMap = new Map((state.board?.crews || []).map((crew) => [Number(crew.setup_work_day_crew_id), crew]));
  const groups = groupAssignments(assignments);
  byId('work-list').innerHTML = groups.map((group) => {
    const crew = crewMap.get(Number(group.crewId));
    const captainName = crew?.captain_display_name || 'Captain not assigned';
    const crewName = crew?.crew_code ? 'Crew ' + crew.crew_code : 'Crew';
    return '<section class="work-group"><div class="work-group-heading"><h2>'
      + escapeHtml(crewName + ' · ' + String(group.shift || 'ALL_DAY').replaceAll('_', ' '))
      + '</h2><span class="captain-name">' + escapeHtml(captainName) + '</span></div>'
      + group.assignments.map((assignment) => {
        const task = taskMap.get(Number(assignment.setup_session_task_id));
        return task ? taskCard(assignment, task, state.enrichment.get(Number(task.setup_session_task_id)), crew) : '';
      }).join('')
      + '</section>';
  }).join('');

  setStatus('', 'ok');
  updateEmailLink();
}

function availableDays() {
  const assignmentDayIds = new Set((state.board?.assignments || []).map((item) => Number(item.setup_work_day_id)));
  return (state.board?.work_days || []).filter((day) => (
    assignmentDayIds.has(Number(day.setup_work_day_id))
    && String(day.day_status || '').toUpperCase() !== 'CANCELLED'
  ));
}

function chooseDay(days) {
  const requested = params.get('work_date');
  if (requested) {
    const match = days.find((day) => String(day.work_date) === requested);
    if (match) return match;
  }
  const today = new Date().toISOString().slice(0, 10);
  return days.find((day) => String(day.work_date) >= today) || days[days.length - 1] || null;
}

function populateDays() {
  const days = availableDays();
  byId('work-day-select').innerHTML = days.map((day) => (
    '<option value="' + day.setup_work_day_id + '">' + escapeHtml(formatDate(day.work_date))
      + ' · Day ' + escapeHtml(day.setup_day_number ?? '—') + '</option>'
  )).join('');
  const selected = chooseDay(days);
  if (selected) byId('work-day-select').value = String(selected.setup_work_day_id);
  populateCrews();
}

function populateCrews() {
  const day = selectedDay();
  const assignmentCrewIds = new Set((state.board?.assignments || [])
    .filter((item) => Number(item.setup_work_day_id) === Number(day?.setup_work_day_id))
    .map((item) => Number(item.setup_work_day_crew_id)));
  const crews = (state.board?.crews || []).filter(
    (crew) => Number(crew.setup_work_day_id) === Number(day?.setup_work_day_id)
      && assignmentCrewIds.has(Number(crew.setup_work_day_crew_id))
  );
  const requestedCrew = Number(params.get('crew_id') || 0);
  byId('crew-select').innerHTML = '<option value="ALL">All crews</option>' + crews.map((crew) => (
    '<option value="' + crew.setup_work_day_crew_id + '">'
      + escapeHtml('Crew ' + (crew.crew_code || crew.crew_number)
        + (crew.captain_display_name ? ' — ' + crew.captain_display_name : ' — Captain not assigned'))
      + '</option>'
  )).join('');
  if (requestedCrew && crews.some((crew) => Number(crew.setup_work_day_crew_id) === requestedCrew)) {
    byId('crew-select').value = String(requestedCrew);
  }
  updateEmailLink();
}

function updateEmailLink() {
  const link = byId('email-captain');
  const crewId = selectedCrewId();
  const day = selectedDay();
  if (!crewId || !day) {
    link.hidden = true;
    link.removeAttribute('href');
    return;
  }
  const crew = (state.board?.crews || []).find((item) => Number(item.setup_work_day_crew_id) === crewId);
  const captain = captainForCrew(crew);
  if (!captain?.email) {
    link.hidden = true;
    link.removeAttribute('href');
    return;
  }

  const workUrl = new URL(window.location.href);
  workUrl.searchParams.set('season_year', String(state.year));
  workUrl.searchParams.set('work_date', String(day.work_date));
  workUrl.searchParams.set('crew_id', String(crewId));
  const subject = 'MSB Setup work — ' + formatDate(day.work_date) + ' — Crew ' + (crew.crew_code || crew.crew_number);
  const body = 'Your current Captain work list:\n\n' + workUrl.toString()
    + '\n\nThis is a connected live list. Refresh it if the Setup schedule changes.';
  link.href = 'mailto:' + encodeURIComponent(captain.email)
    + '?subject=' + encodeURIComponent(subject)
    + '&body=' + encodeURIComponent(body);
  link.textContent = 'Email ' + (captain.display_name || crew.captain_display_name || 'Captain');
  link.hidden = false;
}

function chooseSeason() {
  const requested = Number(params.get('season_year') || 0);
  if (requested && state.seasons.some((season) => Number(season.season_year) === requested)) return requested;
  const withSession = state.seasons
    .filter((season) => season.setup_session_id)
    .sort((a, b) => Number(b.season_year) - Number(a.season_year));
  return withSession.length ? Number(withSession[0].season_year) : null;
}

async function loadSeason(year) {
  state.year = Number(year);
  state.enrichment.clear();
  state.generatedAt = new Date();
  byId('season-select').value = String(state.year);
  setStatus('Loading scheduled work…');

  const [boardPayload, tasksPayload] = await Promise.all([
    api('api/setup/scheduling-board?season_year=' + encodeURIComponent(state.year)),
    api('api/setup/tasks?season_year=' + encodeURIComponent(state.year))
  ]);
  state.board = boardPayload.board || null;
  state.catalog = tasksPayload.tasks || [];

  if (!state.board?.session) {
    byId('work-day-select').innerHTML = '';
    byId('crew-select').innerHTML = '<option>All crews</option>';
    byId('work-list').innerHTML = '';
    byId('day-context').hidden = true;
    byId('scope-title').textContent = state.year + ' Setup';
    byId('generated-at').textContent = 'Generated: ' + state.generatedAt.toLocaleString();
    setStatus(state.year + ' does not have a Setup Session yet. No Captain schedule can be published from it.', 'error');
    return;
  }

  populateDays();
  await renderWorkList();
}

async function initialize() {
  try {
    const [accessPayload, seasonsPayload] = await Promise.all([
      api('api/setup/access'),
      api('api/setup/seasons')
    ]);
    if (!accessPayload.access?.can_read_setup) throw new Error('Your account is not authorized to read Setup.');
    state.seasons = seasonsPayload.seasons || [];
    state.year = chooseSeason();
    byId('season-select').innerHTML = state.seasons.map((season) => (
      '<option value="' + season.season_year + '">' + escapeHtml(String(season.season_year)
        + (season.setup_session_id ? ' — ' + String(season.session_status || 'Setup Session').replaceAll('_', ' ') : ' — no Setup Session'))
        + '</option>'
    )).join('');
    if (state.year == null) throw new Error('No Setup season is available.');
    await loadSeason(state.year);
  } catch (error) {
    setStatus(error.message || error, 'error');
  }
}

byId('print-list').addEventListener('click', () => window.print());
byId('back-setup').addEventListener('click', () => {
  window.location.href = '../?season_year=' + encodeURIComponent(state.year || '');
});
byId('season-select').addEventListener('change', () => loadSeason(byId('season-select').value));
byId('work-day-select').addEventListener('change', async () => {
  populateCrews();
  await renderWorkList();
});
byId('crew-select').addEventListener('change', renderWorkList);

initialize();
