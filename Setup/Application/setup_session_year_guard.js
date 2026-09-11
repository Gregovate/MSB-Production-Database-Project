/* Setup Session year guard for shared Production-backed review/planning. */

function setupYearGuardSeason() {
  const year = Number(appState?.seasonYear);
  return Number.isInteger(year) && year >= 2000 && year <= 2100 ? year : null;
}

function setupYearGuardBounds(year) {
  return {
    dateMin: `${year}-01-01`,
    dateMax: `${year}-12-31`,
    dateTimeMin: `${year}-01-01T00:00`,
    dateTimeMax: `${year}-12-31T23:59`
  };
}

function setupYearGuardCurrentSession() {
  if (typeof currentSeasonRecord !== 'function') return null;
  return currentSeasonRecord();
}

function setupYearGuardValidateInput(input, year) {
  if (!input?.value) {
    input?.setCustomValidity('');
    return;
  }
  const valueYear = Number(String(input.value).slice(0, 4));
  if (valueYear !== year) {
    input.setCustomValidity(`This Setup Session only accepts operational dates in ${year}.`);
  } else {
    input.setCustomValidity('');
  }
}

function setupYearGuardApplyDateInputs() {
  const year = setupYearGuardSeason();
  if (!year) return;
  const bounds = setupYearGuardBounds(year);

  document.querySelectorAll('input[type="date"]').forEach((input) => {
    input.min = bounds.dateMin;
    input.max = bounds.dateMax;
    input.dataset.setupSessionYear = String(year);
    setupYearGuardValidateInput(input, year);
    if (!input.dataset.setupYearGuardBound) {
      input.dataset.setupYearGuardBound = '1';
      input.addEventListener('input', () => setupYearGuardValidateInput(input, setupYearGuardSeason()));
      input.addEventListener('change', () => setupYearGuardValidateInput(input, setupYearGuardSeason()));
    }
  });

  document.querySelectorAll('input[type="datetime-local"]').forEach((input) => {
    input.min = bounds.dateTimeMin;
    input.max = bounds.dateTimeMax;
    input.dataset.setupSessionYear = String(year);
    setupYearGuardValidateInput(input, year);
    if (!input.dataset.setupYearGuardBound) {
      input.dataset.setupYearGuardBound = '1';
      input.addEventListener('input', () => setupYearGuardValidateInput(input, setupYearGuardSeason()));
      input.addEventListener('change', () => setupYearGuardValidateInput(input, setupYearGuardSeason()));
    }
  });
}

function setupYearGuardApplyAdminControls() {
  const canAdmin = Boolean(appState?.access?.can_admin_setup);
  const promote = document.getElementById('next-promote-baseline');
  if (promote) {
    promote.hidden = !canAdmin;
    promote.disabled = !canAdmin;
    promote.classList.remove('manager-only');
    promote.classList.add('admin-only');
    promote.title = canAdmin
      ? 'Administrator only: carry this season order into the reusable future baseline.'
      : 'Only a Setup Administrator can carry an annual order into the future baseline.';
  }
}

function setupYearGuardRenderBanner() {
  const year = setupYearGuardSeason();
  if (!year) return;
  const session = setupYearGuardCurrentSession();
  let banner = document.getElementById('setup-session-year-guard');
  if (!banner) {
    banner = document.createElement('section');
    banner.id = 'setup-session-year-guard';
    banner.className = 'setup-session-year-guard';
    const alert = document.getElementById('app-alert');
    alert?.insertAdjacentElement('afterend', banner);
  }
  if (!banner) return;

  const historical = session?.session_status === 'HISTORICAL_VERIFICATION';
  banner.innerHTML = historical
    ? `<strong>${year} Historical Review / Training</strong><span>Saved changes are permanent ${year} Setup records. Operational dates are limited to ${year}. This session does not create or schedule a future season. Future-baseline promotion is Administrator-only.</span>`
    : `<strong>${year} Setup Session</strong><span>Operational dates are limited to ${year}. Future-baseline promotion is Administrator-only.</span>`;
}

function applySetupSessionYearGuard() {
  setupYearGuardApplyDateInputs();
  setupYearGuardApplyAdminControls();
  setupYearGuardRenderBanner();
}

/* Reapply after season and schedule loads because those operations create or
   refresh the date-bearing controls. */
if (typeof loadNextSchedule === 'function') {
  const priorSetupYearGuardLoadNextSchedule = loadNextSchedule;
  loadNextSchedule = async function loadNextScheduleWithYearGuard(...args) {
    const result = await priorSetupYearGuardLoadNextSchedule(...args);
    applySetupSessionYearGuard();
    return result;
  };
}

if (typeof loadSeason === 'function') {
  const priorSetupYearGuardLoadSeason = loadSeason;
  loadSeason = async function loadSeasonWithYearGuard(...args) {
    const result = await priorSetupYearGuardLoadSeason(...args);
    applySetupSessionYearGuard();
    return result;
  };
}

if (typeof applyAccess === 'function') {
  const priorSetupYearGuardApplyAccess = applyAccess;
  applyAccess = function applyAccessWithYearGuard(...args) {
    const result = priorSetupYearGuardApplyAccess(...args);
    setupYearGuardApplyAdminControls();
    return result;
  };
}

document.addEventListener('DOMContentLoaded', () => {
  applySetupSessionYearGuard();
  setTimeout(applySetupSessionYearGuard, 250);
  setTimeout(applySetupSessionYearGuard, 1000);
});
