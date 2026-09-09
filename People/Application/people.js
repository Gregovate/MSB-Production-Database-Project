(function () {
  'use strict';

  const commandHeaders = {
    'Content-Type': 'application/json',
    'X-MSB-People-Command': '1'
  };

  const setupRoleLabels = {
    SETUP_VOLUNTEER: 'Setup volunteer',
    TAKEDOWN_VOLUNTEER: 'Takedown volunteer',
    CAPTAIN_CANDIDATE: 'Captain candidate',
    ADVISOR_CANDIDATE: 'Advisor candidate'
  };

  const state = {
    selectedPersonId: null,
    person: null,
    duplicateCandidates: [],
    emailCandidates: [],
    alternateEmailNeedsAck: false,
    duplicateFingerprint: null,
    capabilityCatalog: [],
    qualificationCatalog: [],
    capabilities: [],
    qualifications: [],
    setupRoles: [],
    leadership: []
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

  function setMessage(id, text, success) {
    const node = el(id);
    node.textContent = text || '';
    node.className = `message${success ? ' success' : ''}`;
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

  async function loadCatalogs() {
    const [capabilityData, qualificationData] = await Promise.all([
      api('api/catalogs/capabilities?include_inactive=1'),
      api('api/catalogs/qualifications?include_inactive=1')
    ]);
    state.capabilityCatalog = capabilityData.capabilities || [];
    state.qualificationCatalog = qualificationData.qualifications || [];
    renderCatalogSelects();
  }

  function renderCatalogSelects() {
    const capabilitySelect = el('capabilitySelect');
    capabilitySelect.replaceChildren();
    const capabilityBlank = document.createElement('option');
    capabilityBlank.value = '';
    capabilityBlank.textContent = state.capabilityCatalog.some((item) => item.active_flag)
      ? 'Select capability'
      : 'No active capability types';
    capabilitySelect.appendChild(capabilityBlank);
    for (const item of state.capabilityCatalog.filter((entry) => entry.active_flag)) {
      const option = document.createElement('option');
      option.value = String(item.person_capability_type_id);
      option.textContent = `${item.capability_name} · ${item.capability_category}`;
      capabilitySelect.appendChild(option);
    }

    const qualificationSelect = el('qualificationSelect');
    const currentValue = qualificationSelect.value;
    qualificationSelect.replaceChildren();
    const qualificationBlank = document.createElement('option');
    qualificationBlank.value = '';
    qualificationBlank.textContent = state.qualificationCatalog.some((item) => item.active_flag)
      ? 'Select qualification'
      : 'No active qualification types';
    qualificationSelect.appendChild(qualificationBlank);
    for (const item of state.qualificationCatalog.filter((entry) => entry.active_flag)) {
      const option = document.createElement('option');
      option.value = String(item.person_qualification_type_id);
      option.textContent = item.qualification_name;
      qualificationSelect.appendChild(option);
    }
    if ([...qualificationSelect.options].some((option) => option.value === currentValue)) {
      qualificationSelect.value = currentValue;
    }
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

  function showMetadataSections(show) {
    el('metadataWaitPanel').classList.toggle('hidden', show);
    for (const id of ['capabilityPanel', 'qualificationPanel', 'setupRolePanel', 'leadershipPanel']) {
      el(id).classList.toggle('hidden', !show);
    }
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
    const [detail, deps, capabilities, qualifications, roles, leadership] = await Promise.all([
      api(`api/people/${personId}`),
      api(`api/people/${personId}/dependencies`),
      api(`api/people/${personId}/capabilities`),
      api(`api/people/${personId}/qualifications`),
      api(`api/people/${personId}/setup-roles`),
      api(`api/people/${personId}/leadership`)
    ]);
    state.person = detail.person;
    state.capabilities = capabilities.capabilities || [];
    state.qualifications = qualifications.qualifications || [];
    state.setupRoles = roles.roles || [];
    state.leadership = leadership.leadership || [];

    populatePerson(detail.person);
    renderCapabilities();
    renderQualifications();
    renderSetupRoles();
    renderLeadership();
    renderDependencies(deps.dependencies || []);
    showMetadataSections(true);
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
    el('dependenciesPanel').classList.remove('hidden');
    setMessage('formMessage', '');
  }

  function newPerson() {
    state.selectedPersonId = null;
    state.person = null;
    state.capabilities = [];
    state.qualifications = [];
    state.setupRoles = [];
    state.leadership = [];
    clearWarnings();
    showForm();
    el('recordMode').textContent = 'New volunteer / contact';
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
    showMetadataSections(false);
    setMessage('formMessage', '');
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
    const list = el('dependencyList');
    list.replaceChildren();
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
    setMessage('formMessage', '');
    const payload = formPayload();
    if (!payload.first_name || !payload.last_name) {
      setMessage('formMessage', 'First and last name are required.');
      return;
    }

    try {
      if (!payload.email && !state.person?.directus_linked) {
        await buildEmailCandidates();
        payload.email = el('msbEmail').value.trim().toLowerCase() || null;
      }

      const duplicates = await checkDuplicates();
      if (duplicates.length && !el('duplicateReviewAck').checked) {
        setMessage('formMessage', 'Review the potential duplicate records and check the acknowledgement before saving.');
        return;
      }
      payload.duplicate_review_ack = el('duplicateReviewAck').checked;
      payload.email_exception_ack = el('emailExceptionAck').checked;

      if (state.alternateEmailNeedsAck && !payload.email_exception_ack) {
        setMessage('formMessage', 'Review and approve the non-standard MSB email before saving.');
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

      setMessage('formMessage', 'Saved.', true);
      await selectPerson(state.selectedPersonId);
    } catch (error) {
      setMessage('formMessage', error.message);
    }
  }

  function renderCapabilities() {
    const list = el('capabilityList');
    list.replaceChildren();
    if (!state.capabilities.length) {
      const p = document.createElement('p');
      p.className = 'field-help';
      p.textContent = 'No capabilities recorded.';
      list.appendChild(p);
      return;
    }

    for (const capability of state.capabilities) {
      const item = document.createElement('div');
      item.className = `metadata-item${capability.active_flag ? '' : ' inactive-metadata'}`;
      const text = document.createElement('div');
      const strong = document.createElement('strong');
      strong.textContent = capability.capability_name;
      const small = document.createElement('small');
      small.textContent = `${capability.capability_category} · ${capability.active_flag ? 'Active' : 'Inactive'}${capability.notes ? ` · ${capability.notes}` : ''}`;
      text.append(strong, small);

      const toggle = document.createElement('button');
      toggle.type = 'button';
      toggle.className = 'secondary';
      toggle.textContent = capability.active_flag ? 'Deactivate' : 'Reactivate';
      toggle.addEventListener('click', () => setPersonCapability(
        capability.person_capability_type_id,
        !capability.active_flag,
        capability.notes || ''
      ));

      item.append(text, toggle);
      list.appendChild(item);
    }
  }

  async function setPersonCapability(typeId, activeFlag, notes) {
    if (!state.selectedPersonId) return;
    try {
      await api(`api/people/${state.selectedPersonId}/capabilities/${typeId}`, {
        method: 'PUT',
        headers: commandHeaders,
        body: JSON.stringify({ active_flag: activeFlag, notes: notes || null })
      });
      const data = await api(`api/people/${state.selectedPersonId}/capabilities`);
      state.capabilities = data.capabilities || [];
      renderCapabilities();
      setMessage('capabilityMessage', activeFlag ? 'Capability saved.' : 'Capability deactivated.', true);
    } catch (error) {
      setMessage('capabilityMessage', error.message);
    }
  }

  async function assignCapability() {
    const typeId = Number(el('capabilitySelect').value);
    if (!typeId) {
      setMessage('capabilityMessage', 'Select a capability first.');
      return;
    }
    await setPersonCapability(typeId, true, el('capabilityNotes').value.trim());
    el('capabilityNotes').value = '';
  }

  async function createCapabilityType() {
    const name = el('newCapabilityName').value.trim();
    if (!name) {
      setMessage('capabilityMessage', 'Capability name is required.');
      return;
    }
    try {
      await api('api/catalogs/capabilities', {
        method: 'POST',
        headers: commandHeaders,
        body: JSON.stringify({
          capability_name: name,
          capability_category: el('newCapabilityCategory').value,
          notes: el('newCapabilityCatalogNotes').value.trim() || null,
          active_flag: true,
          sort_order: 100
        })
      });
      el('newCapabilityName').value = '';
      el('newCapabilityCatalogNotes').value = '';
      await loadCatalogs();
      setMessage('capabilityMessage', 'Capability type added to catalog.', true);
    } catch (error) {
      setMessage('capabilityMessage', error.message);
    }
  }

  function qualificationSummary(record) {
    const bits = [record.active_flag ? 'Active' : 'Inactive'];
    if (record.completed_on) bits.push(`completed ${record.completed_on}`);
    if (record.valid_from) bits.push(`valid ${record.valid_from}`);
    if (record.expires_on) bits.push(`expires ${record.expires_on}`);
    if (record.qualification_role) bits.push(record.qualification_role);
    if (record.certificate_number) bits.push(`cert ${record.certificate_number}`);
    return bits.join(' · ');
  }

  function renderQualifications() {
    const list = el('qualificationList');
    list.replaceChildren();
    if (!state.qualifications.length) {
      const p = document.createElement('p');
      p.className = 'field-help';
      p.textContent = 'No qualifications recorded.';
      list.appendChild(p);
      return;
    }

    for (const record of state.qualifications) {
      const item = document.createElement('div');
      item.className = `metadata-item${record.active_flag ? '' : ' inactive-metadata'}`;
      const text = document.createElement('div');
      const strong = document.createElement('strong');
      strong.textContent = record.qualification_name;
      const small = document.createElement('small');
      small.textContent = qualificationSummary(record);
      text.append(strong, small);
      if (record.evidence_reference || record.notes) {
        const extra = document.createElement('small');
        extra.textContent = [record.evidence_reference, record.notes].filter(Boolean).join(' · ');
        text.appendChild(extra);
      }

      const actions = document.createElement('div');
      actions.className = 'row-actions';
      const edit = document.createElement('button');
      edit.type = 'button';
      edit.className = 'secondary';
      edit.textContent = 'Edit';
      edit.addEventListener('click', () => editQualification(record));
      const toggle = document.createElement('button');
      toggle.type = 'button';
      toggle.className = 'secondary';
      toggle.textContent = record.active_flag ? 'Deactivate' : 'Reactivate';
      toggle.addEventListener('click', () => persistQualification({
        ...record,
        active_flag: !record.active_flag
      }));
      actions.append(edit, toggle);
      item.append(text, actions);
      list.appendChild(item);
    }
  }

  function clearQualificationEditor() {
    el('editingQualificationId').value = '';
    el('qualificationSelect').value = '';
    for (const id of [
      'qualificationRole',
      'qualificationCompletedOn',
      'qualificationValidFrom',
      'qualificationExpiresOn',
      'qualificationCertificateNumber',
      'qualificationEvidenceReference',
      'qualificationNotes'
    ]) {
      el(id).value = '';
    }
    el('qualificationActiveFlag').checked = true;
    el('saveQualificationButton').textContent = 'Add qualification';
    el('cancelQualificationEditButton').classList.add('hidden');
  }

  function editQualification(record) {
    el('editingQualificationId').value = String(record.person_qualification_id);
    el('qualificationSelect').value = String(record.person_qualification_type_id);
    el('qualificationRole').value = record.qualification_role || '';
    el('qualificationCompletedOn').value = record.completed_on || '';
    el('qualificationValidFrom').value = record.valid_from || '';
    el('qualificationExpiresOn').value = record.expires_on || '';
    el('qualificationCertificateNumber').value = record.certificate_number || '';
    el('qualificationEvidenceReference').value = record.evidence_reference || '';
    el('qualificationNotes').value = record.notes || '';
    el('qualificationActiveFlag').checked = Boolean(record.active_flag);
    el('saveQualificationButton').textContent = 'Save qualification';
    el('cancelQualificationEditButton').classList.remove('hidden');
    el('qualificationSelect').focus();
  }

  function qualificationEditorPayload() {
    return {
      person_qualification_type_id: Number(el('qualificationSelect').value) || null,
      completed_on: el('qualificationCompletedOn').value || null,
      valid_from: el('qualificationValidFrom').value || null,
      expires_on: el('qualificationExpiresOn').value || null,
      qualification_role: el('qualificationRole').value.trim() || null,
      certificate_number: el('qualificationCertificateNumber').value.trim() || null,
      evidence_reference: el('qualificationEvidenceReference').value.trim() || null,
      active_flag: el('qualificationActiveFlag').checked,
      notes: el('qualificationNotes').value.trim() || null
    };
  }

  async function persistQualification(record) {
    if (!state.selectedPersonId) return;
    const qualificationId = record.person_qualification_id || Number(el('editingQualificationId').value) || null;
    const payload = record.person_qualification_type_id ? {
      person_qualification_type_id: record.person_qualification_type_id,
      completed_on: record.completed_on || null,
      valid_from: record.valid_from || null,
      expires_on: record.expires_on || null,
      qualification_role: record.qualification_role || null,
      certificate_number: record.certificate_number || null,
      evidence_reference: record.evidence_reference || null,
      active_flag: Boolean(record.active_flag),
      notes: record.notes || null
    } : qualificationEditorPayload();

    if (!payload.person_qualification_type_id) {
      setMessage('qualificationMessage', 'Select a qualification type.');
      return;
    }

    try {
      const url = qualificationId
        ? `api/people/${state.selectedPersonId}/qualifications/${qualificationId}`
        : `api/people/${state.selectedPersonId}/qualifications`;
      await api(url, {
        method: qualificationId ? 'PATCH' : 'POST',
        headers: commandHeaders,
        body: JSON.stringify(payload)
      });
      const data = await api(`api/people/${state.selectedPersonId}/qualifications`);
      state.qualifications = data.qualifications || [];
      renderQualifications();
      clearQualificationEditor();
      setMessage('qualificationMessage', 'Qualification saved.', true);
    } catch (error) {
      setMessage('qualificationMessage', error.message);
    }
  }

  async function createQualificationType() {
    const name = el('newQualificationName').value.trim();
    if (!name) {
      setMessage('qualificationMessage', 'Qualification name is required.');
      return;
    }
    try {
      await api('api/catalogs/qualifications', {
        method: 'POST',
        headers: commandHeaders,
        body: JSON.stringify({
          qualification_name: name,
          notes: el('newQualificationCatalogNotes').value.trim() || null,
          active_flag: true,
          sort_order: 100
        })
      });
      el('newQualificationName').value = '';
      el('newQualificationCatalogNotes').value = '';
      await loadCatalogs();
      setMessage('qualificationMessage', 'Qualification type added to catalog.', true);
    } catch (error) {
      setMessage('qualificationMessage', error.message);
    }
  }

  function renderSetupRoles() {
    const list = el('setupRoleList');
    list.replaceChildren();
    for (const role of state.setupRoles) {
      const row = document.createElement('div');
      row.className = 'role-row';

      const checkLabel = document.createElement('label');
      checkLabel.className = 'check-label';
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.checked = Boolean(role.active_flag);
      checkbox.dataset.roleCode = role.setup_role;
      checkbox.className = 'setup-role-check';
      const span = document.createElement('span');
      span.textContent = setupRoleLabels[role.setup_role] || role.setup_role;
      checkLabel.append(checkbox, span);

      const notes = document.createElement('input');
      notes.placeholder = 'Optional notes';
      notes.value = role.notes || '';
      notes.dataset.roleCode = role.setup_role;
      notes.className = 'setup-role-notes';

      row.append(checkLabel, notes);
      list.appendChild(row);
    }
  }

  async function saveSetupRoles() {
    if (!state.selectedPersonId) return;
    const checks = [...document.querySelectorAll('.setup-role-check')];
    try {
      for (const checkbox of checks) {
        const roleCode = checkbox.dataset.roleCode;
        const notes = document.querySelector(`.setup-role-notes[data-role-code="${roleCode}"]`);
        await api(`api/people/${state.selectedPersonId}/setup-roles/${roleCode}`, {
          method: 'PUT',
          headers: commandHeaders,
          body: JSON.stringify({
            active_flag: checkbox.checked,
            notes: notes && notes.value.trim() ? notes.value.trim() : null
          })
        });
      }
      const data = await api(`api/people/${state.selectedPersonId}/setup-roles`);
      state.setupRoles = data.roles || [];
      renderSetupRoles();
      setMessage('setupRoleMessage', 'Setup / Takedown roles saved.', true);
    } catch (error) {
      setMessage('setupRoleMessage', error.message);
    }
  }

  function renderLeadership() {
    const list = el('leadershipList');
    list.replaceChildren();
    if (!state.leadership.length) {
      const p = document.createElement('p');
      p.className = 'field-help';
      p.textContent = 'No current reusable-task Captain / Alternate / Advisor assignments.';
      list.appendChild(p);
      return;
    }
    for (const item of state.leadership) {
      const row = document.createElement('div');
      row.className = 'metadata-item';
      const text = document.createElement('div');
      const strong = document.createElement('strong');
      strong.textContent = item.task_name;
      const small = document.createElement('small');
      const stage = item.stage_id == null ? 'No Stage' : `Stage ID ${item.stage_id}`;
      small.textContent = `${item.captain_role} · ${stage}${item.notes ? ` · ${item.notes}` : ''}`;
      text.append(strong, small);
      row.appendChild(text);
      list.appendChild(row);
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
    el('suggestEmailButton').addEventListener('click', () => buildEmailCandidates().catch((error) => setMessage('formMessage', error.message)));
    el('checkDuplicatesButton').addEventListener('click', () => checkDuplicates().catch((error) => setMessage('formMessage', error.message)));

    el('assignCapabilityButton').addEventListener('click', assignCapability);
    el('createCapabilityTypeButton').addEventListener('click', createCapabilityType);
    el('saveQualificationButton').addEventListener('click', () => persistQualification(qualificationEditorPayload()));
    el('cancelQualificationEditButton').addEventListener('click', clearQualificationEditor);
    el('createQualificationTypeButton').addEventListener('click', createQualificationType);
    el('saveSetupRolesButton').addEventListener('click', saveSetupRoles);

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
    await Promise.all([loadCatalogs(), loadPeople()]);
  }

  start().catch(showGlobalError);
})();
