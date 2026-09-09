(function () {
  'use strict';

  const commandHeaders = {
    'Content-Type': 'application/json',
    'X-MSB-People-Command': '1'
  };

  const state = {
    selectedPersonId: null,
    person: null,
    duplicateCandidates: [],
    emailCandidates: [],
    alternateEmailNeedsAck: false,
    duplicateFingerprint: null
  };

  const el = (id) => document.getElementById(id);

  function analytics(eventName, parameters) {
    if (typeof window.msbPeopleAnalyticsEvent === 'function') {
      window.msbPeopleAnalyticsEvent(eventName, parameters || {});
    }
  }

  async function api(url, options) {
    const response = await fetch(url, options);
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data.error || `Request failed (${response.status})`);
    }
    return data;
  }

  function fullName(person) {
    const first = (person.preferred_name || person.first_name || '').trim();
    const last = (person.last_name || '').trim();
    return `${first} ${last}`.trim() || `Person ${person.person_id}`;
  }

  function yesNo(value) {
    return value ? 'Yes' : 'No';
  }

  function clearWarnings() {
    state.duplicateCandidates = [];
    state.duplicateFingerprint = null;
    el('duplicatePanel').classList.add('hidden');
    el('duplicateReviewAck').checked = false;
    state.alternateEmailNeedsAck = false;
    el('emailCollisionPanel').classList.add('hidden');
    el('emailExceptionAck').checked = false;
  }

  async function loadAccess() {
    const data = await api('api/access');
    const access = data.access || {};
    if (!access.can_manage_people) {
      el('accessStatus').textContent = 'No People Manager access';
      throw new Error('This account is not authorized for People Manager.');
    }
    el('accessStatus').textContent = access.display_name || 'People Manager';
  }

  async function loadPeople() {
    const q = el('searchInput').value.trim();
    const includeInactive = el('includeInactive').checked;
    el('searchMessage').textContent = 'Loading…';
    el('searchMessage').className = 'message muted';
    const params = new URLSearchParams();
    if (q) params.set('q', q);
    if (includeInactive) params.set('include_inactive', '1');
    const data = await api(`api/people?${params.toString()}`);
    renderPeople(data.people || []);
    el('searchMessage').textContent = `${(data.people || []).length} record${(data.people || []).length === 1 ? '' : 's'}`;
    analytics('people_search_used', { include_inactive: includeInactive });
  }

  function renderPeople(people) {
    const list = el('peopleList');
    list.replaceChildren();
    for (const person of people) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'person-row';
      if (!person.active_flag) button.classList.add('inactive-row');
      if (person.person_id === state.selectedPersonId) button.classList.add('selected');

      const name = document.createElement('strong');
      name.textContent = fullName(person);
      const line1 = document.createElement('small');
      line1.textContent = `Person ${person.person_id} · ${person.active_flag ? 'Active' : 'Inactive'}`;
      const line2 = document.createElement('small');
      line2.textContent = person.email || person.personal_email || person.cell_phone || 'No contact value';
      button.append(name, line1, line2);
      button.addEventListener('click', () => selectPerson(person.person_id));
      list.appendChild(button);
    }
  }

  function showForm() {
    el('emptyState').classList.add('hidden');
    el('personForm').classList.remove('hidden');
  }

  function renderIdentity(person) {
    const facts = [
      ['Directus linked', yesNo(person.directus_linked)],
      ['PostgreSQL login linked', yesNo(person.postgres_login_linked)],
      ['Legacy Manager flag', yesNo(person.is_manager)],
      ['Legacy Team flag', yesNo(person.is_team)],
      ['Available for Work Orders', yesNo(person.available_for_work_orders)]
    ];
    const box = el('identityFacts');
    box.replaceChildren();
    for (const [label, value] of facts) {
      const item = document.createElement('div');
      item.className = 'fact';
      const small = document.createElement('span');
      small.textContent = label;
      const strong = document.createElement('strong');
      strong.textContent = value;
      item.append(small, strong);
      box.appendChild(item);
    }
  }

  async function selectPerson(personId) {
    state.selectedPersonId = personId;
    clearWarnings();
    const [detail, deps] = await Promise.all([
      api(`api/people/${personId}`),
      api(`api/people/${personId}/dependencies`)
    ]);
    state.person = detail.person;
    populatePerson(detail.person);
    renderDependencies(deps.dependencies || []);
    await loadPeople();
    analytics('people_record_opened');
  }

  function populatePerson(person) {
    showForm();
    el('recordMode').textContent = `Person ${person.person_id}`;
    el('personHeading').textContent = fullName(person);
    el('personId').value = person.person_id;
    el('expectedUpdatedAt').value = person.updated_at || '';
    el('firstName').value = person.first_name || '';
    el('lastName').value = person.last_name || '';
    el('preferredName').value = person.preferred_name || '';
    el('cellPhone').value = person.cell_phone || '';
    el('personalEmail').value = person.personal_email || '';
    el('msbEmail').value = person.email || '';
    el('activeFlag').checked = Boolean(person.active_flag);
    el('personStateBadge').textContent = person.active_flag ? 'Active' : 'Inactive';
    el('msbEmail').disabled = Boolean(person.directus_linked);
    el('suggestEmailButton').disabled = Boolean(person.directus_linked);
    el('emailHelp').textContent = person.directus_linked
      ? 'Directus-linked MSB email is protected from ordinary contact editing.'
      : 'Reserved system identity. Reserving it does not create the Google Workspace account.';
    renderIdentity(person);
    el('identityPanel').classList.remove('hidden');
    el('formMessage').textContent = '';
  }

  function newPerson() {
    state.selectedPersonId = null;
    state.person = null;
    clearWarnings();
    showForm();
    el('recordMode').textContent = 'New casual volunteer';
    el('personHeading').textContent = 'Add person';
    el('personId').value = '';
    el('expectedUpdatedAt').value = '';
    for (const id of ['firstName', 'lastName', 'preferredName', 'cellPhone', 'personalEmail', 'msbEmail']) {
      el(id).value = '';
    }
    el('activeFlag').checked = true;
    el('personStateBadge').textContent = 'New';
    el('msbEmail').disabled = false;
    el('suggestEmailButton').disabled = false;
    el('emailHelp').textContent = 'A standard first-initial + last-name @sheboyganlights.org address will be reserved. This does not create a Google account.';
    el('identityPanel').classList.add('hidden');
    el('dependenciesPanel').classList.add('hidden');
    el('formMessage').textContent = '';
    el('firstName').focus();
    analytics('people_create_opened');
  }

  function formPayload() {
    return {
      first_name: el('firstName').value.trim(),
      last_name: el('lastName').value.trim(),
      preferred_name: el('preferredName').value.trim() || null,
      email: el('msbEmail').value.trim().toLowerCase() || null,
      personal_email: el('personalEmail').value.trim().toLowerCase() || null,
      cell_phone: el('cellPhone').value.trim() || null,
      active_flag: el('activeFlag').checked,
      duplicate_review_ack: el('duplicateReviewAck').checked,
      email_exception_ack: el('emailExceptionAck').checked
    };
  }

  async function buildEmailCandidates() {
    const first = el('firstName').value.trim();
    const last = el('lastName').value.trim();
    if (!first || !last) {
      throw new Error('Enter first and last name before building the MSB email.');
    }
    const payload = {
      first_name: first,
      last_name: last,
      exclude_person_id: state.selectedPersonId
    };
    const data = await api('api/people/email-candidates', {
      method: 'POST',
      headers: commandHeaders,
      body: JSON.stringify(payload)
    });
    state.emailCandidates = data.candidates || [];
    renderEmailCandidates();
  }

  function renderEmailCandidates() {
    const candidates = state.emailCandidates;
    if (!candidates.length) {
      el('emailCollisionPanel').classList.add('hidden');
      return;
    }
    const standard = candidates.find((candidate) => candidate.is_standard);
    const firstAvailable = candidates.find((candidate) => candidate.is_available);
    const list = el('emailCandidateList');
    list.replaceChildren();

    if (standard && standard.is_available) {
      el('msbEmail').value = standard.candidate_email;
      state.alternateEmailNeedsAck = false;
      el('emailCollisionPanel').classList.add('hidden');
      el('emailExceptionAck').checked = false;
      return;
    }

    state.alternateEmailNeedsAck = true;
    el('emailCollisionPanel').classList.remove('hidden');
    el('emailCollisionMessage').textContent = 'The standard first-initial + last-name address is already reserved or linked. Choose and explicitly approve an available alternate.';

    for (const candidate of candidates) {
      const item = document.createElement('div');
      item.className = 'candidate-item';
      const label = document.createElement('span');
      label.textContent = `${candidate.candidate_email} — ${candidate.is_available ? 'available in current PostgreSQL/Directus evidence' : 'already in use'}`;
      item.appendChild(label);
      if (candidate.is_available) {
        const use = document.createElement('button');
        use.type = 'button';
        use.className = 'secondary';
        use.textContent = 'Use this';
        use.addEventListener('click', () => {
          el('msbEmail').value = candidate.candidate_email;
          el('emailExceptionAck').checked = false;
        });
        item.appendChild(use);
      }
      list.appendChild(item);
    }

    if (firstAvailable && !el('msbEmail').value) {
      el('msbEmail').value = firstAvailable.candidate_email;
    }
    analytics('people_email_collision_shown');
  }

  function duplicatePayload() {
    return {
      first_name: el('firstName').value.trim(),
      last_name: el('lastName').value.trim(),
      email: el('msbEmail').value.trim().toLowerCase() || null,
      personal_email: el('personalEmail').value.trim().toLowerCase() || null,
      cell_phone: el('cellPhone').value.trim() || null,
      exclude_person_id: state.selectedPersonId
    };
  }

  async function checkDuplicates() {
    const payload = duplicatePayload();
    const fingerprint = JSON.stringify(payload);
    const preserveAck = state.duplicateFingerprint === fingerprint && el('duplicateReviewAck').checked;
    const data = await api('api/people/duplicates', {
      method: 'POST',
      headers: commandHeaders,
      body: JSON.stringify(payload)
    });
    state.duplicateCandidates = data.candidates || [];
    state.duplicateFingerprint = fingerprint;
    renderDuplicates(preserveAck);
    return state.duplicateCandidates;
  }

  function renderDuplicates(preserveAck) {
    const panel = el('duplicatePanel');
    const list = el('duplicateList');
    list.replaceChildren();
    el('duplicateReviewAck').checked = Boolean(preserveAck);
    if (!state.duplicateCandidates.length) {
      panel.classList.add('hidden');
      return;
    }
    panel.classList.remove('hidden');
    for (const candidate of state.duplicateCandidates) {
      const item = document.createElement('div');
      item.className = 'duplicate-item';
      const strong = document.createElement('strong');
      strong.textContent = `${candidate.display_name} · Person ${candidate.person_id} · ${candidate.match_level}`;
      const reasons = [];
      if (candidate.match_name) reasons.push('same name');
      if (candidate.match_msb_email) reasons.push('same MSB email');
      if (candidate.match_personal_email) reasons.push('same personal email');
      if (candidate.match_phone) reasons.push('same phone');
      const small = document.createElement('small');
      small.textContent = `${candidate.active_flag ? 'Active' : 'Inactive'} · ${reasons.join(', ')}`;
      item.append(strong, small);
      list.appendChild(item);
    }
    analytics('people_duplicate_review_shown', { candidate_count_bucket: state.duplicateCandidates.length > 3 ? '4_plus' : String(state.duplicateCandidates.length) });
  }

  function renderDependencies(dependencies) {
    const panel = el('dependenciesPanel');
    const list = el('dependencyList');
    list.replaceChildren();
    panel.classList.remove('hidden');
    if (!dependencies.length) {
      const p = document.createElement('p');
      p.className = 'field-help';
      p.textContent = 'No current foreign-key relationships were found.';
      list.appendChild(p);
      return;
    }
    for (const dep of dependencies) {
      const item = document.createElement('div');
      item.className = 'dependency-item';
      const strong = document.createElement('strong');
      strong.textContent = `${dep.schema_name}.${dep.table_name}.${dep.column_name}: ${dep.reference_count}`;
      const small = document.createElement('small');
      small.textContent = dep.constraint_name;
      item.append(strong, small);
      list.appendChild(item);
    }
  }

  async function savePerson(event) {
    event.preventDefault();
    el('formMessage').textContent = '';
    const payload = formPayload();
    if (!payload.first_name || !payload.last_name) {
      el('formMessage').textContent = 'First and last name are required.';
      return;
    }

    try {
      if (!payload.email && !state.person?.directus_linked) {
        await buildEmailCandidates();
        payload.email = el('msbEmail').value.trim().toLowerCase() || null;
      }

      const duplicates = await checkDuplicates();
      if (duplicates.length && !el('duplicateReviewAck').checked) {
        el('formMessage').textContent = 'Review the potential duplicate records and check the acknowledgement before saving.';
        return;
      }
      payload.duplicate_review_ack = el('duplicateReviewAck').checked;
      payload.email_exception_ack = el('emailExceptionAck').checked;

      if (state.alternateEmailNeedsAck && !payload.email_exception_ack) {
        el('formMessage').textContent = 'Review and approve the non-standard MSB email before saving.';
        return;
      }

      let result;
      if (state.selectedPersonId === null) {
        result = await api('api/people', {
          method: 'POST',
          headers: commandHeaders,
          body: JSON.stringify(payload)
        });
        state.selectedPersonId = result.person.person_id;
        analytics('people_person_created');
      } else {
        payload.expected_updated_at = el('expectedUpdatedAt').value;
        const wasActive = Boolean(state.person && state.person.active_flag);
        result = await api(`api/people/${state.selectedPersonId}`, {
          method: 'PATCH',
          headers: commandHeaders,
          body: JSON.stringify(payload)
        });
        analytics('people_person_updated', { active_state_changed: wasActive !== payload.active_flag });
      }

      el('formMessage').textContent = 'Saved.';
      el('formMessage').className = 'message success';
      await selectPerson(state.selectedPersonId);
    } catch (error) {
      el('formMessage').textContent = error.message;
      el('formMessage').className = 'message';
    }
  }

  let searchTimer = null;
  function scheduleSearch() {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(() => loadPeople().catch(showGlobalError), 180);
  }

  function showGlobalError(error) {
    el('searchMessage').textContent = error.message;
    el('searchMessage').className = 'message';
  }

  async function start() {
    el('newPersonButton').addEventListener('click', newPerson);
    el('searchInput').addEventListener('input', scheduleSearch);
    el('includeInactive').addEventListener('change', () => loadPeople().catch(showGlobalError));
    el('personForm').addEventListener('submit', savePerson);
    el('suggestEmailButton').addEventListener('click', () => buildEmailCandidates().catch((error) => {
      el('formMessage').textContent = error.message;
    }));
    el('checkDuplicatesButton').addEventListener('click', () => checkDuplicates().catch((error) => {
      el('formMessage').textContent = error.message;
    }));

    for (const id of ['firstName', 'lastName', 'personalEmail', 'cellPhone']) {
      el(id).addEventListener('input', () => {
        state.duplicateFingerprint = null;
        el('duplicateReviewAck').checked = false;
      });
    }
    el('msbEmail').addEventListener('input', () => {
      state.duplicateFingerprint = null;
      el('duplicateReviewAck').checked = false;
      el('emailExceptionAck').checked = false;
    });

    await loadAccess();
    await loadPeople();
  }

  start().catch(showGlobalError);
})();
