// Browser-native Controller Add/Edit and Display assignment management — V0.4.0.
(function () {
  'use strict';

  const detailId = document.getElementById('detail-id');
  const filters = document.querySelector('.filters');
  if (!detailId || !filters) return;

  const COMMAND_HEADERS = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-MSB-Controller-Command': '1',
  };

  let access = null;
  let options = null;
  let managementInstalled = false;
  let activeControllerDialog = null;
  let activeControllerFormDirty = false;

  function esc(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&#39;');
  }

  async function responseJson(response) {
    const text = await response.text();
    try {
      return text ? JSON.parse(text) : {};
    } catch (_) {
      throw new Error(`Controller server returned an unexpected response (${response.status}).`);
    }
  }

  async function api(url, init = {}) {
    const response = await fetch(url, init);
    const payload = await responseJson(response);
    if (!response.ok) {
      throw new Error(payload.error || payload.engineering_error || `Controller request failed (${response.status}).`);
    }
    return payload;
  }

  function controllerIdFromHeading() {
    const match = String(detailId.textContent || '').match(/CTRL\s+(\d+)/i);
    return match ? Number(match[1]) : null;
  }

  function hexUid(value) {
    if (value === null || value === undefined || value === '') return '';
    const n = Number(value);
    return Number.isInteger(n) ? n.toString(16).toUpperCase().padStart(2, '0') : '';
  }

  function parseHexUid(value) {
    const text = String(value || '').trim();
    if (!text) return null;
    if (!/^[0-9a-f]{1,2}$/i.test(text)) throw new Error('First UID must be hexadecimal 01 through F0.');
    const n = Number.parseInt(text, 16);
    if (n < 1 || n > 240) throw new Error('First UID must be hexadecimal 01 through F0.');
    return n;
  }

  function selectedOption(select, value, fallback = '') {
    const raw = value === null || value === undefined ? '' : String(value);
    return [...select.options].find(o => o.value === raw) || fallback;
  }

  async function loadAccess() {
    const payload = await api('api/controller-access', {headers:{Accept:'application/json'}});
    access = payload.access || null;
    return access;
  }

  async function loadOptions() {
    if (options) return options;
    const payload = await api('api/controller-management/options', {headers:{Accept:'application/json'}});
    options = payload.options || {};
    return options;
  }

  function modelById(modelId) {
    return (options?.models || []).find(m => Number(m.controller_model_id) === Number(modelId)) || null;
  }

  function statusByName(name) {
    return (options?.statuses || []).find(s => s.controller_status_name === name) || null;
  }

  function firmwareForModel(modelId) {
    return (options?.firmware_versions || [])
      .filter(f => Number(f.controller_model_id) === Number(modelId));
  }

  function modelOptions(selectedId) {
    return (options?.models || []).map(m => `
      <option value="${m.controller_model_id}" ${Number(selectedId) === Number(m.controller_model_id) ? 'selected' : ''}>
        ${esc(m.model_code)} — ${esc(m.manufacturer)} ${esc(m.model_name)}
      </option>`).join('');
  }

  function statusOptions(selectedId) {
    return (options?.statuses || []).map(s => `
      <option value="${s.controller_status_id}" ${Number(selectedId) === Number(s.controller_status_id) ? 'selected' : ''}>
        ${esc(s.controller_status_name)}
      </option>`).join('');
  }

  function locationOptions(selectedCode) {
    const rows = (options?.locations || []).map(l => `
      <option value="${esc(l.location_code)}" ${String(selectedCode || '') === String(l.location_code) ? 'selected' : ''}>
        ${esc(l.location_code)}
      </option>`).join('');
    return `<option value="">Unknown / not recorded</option>${rows}`;
  }

  function firmwareOptions(modelId, selectedId, selectedText) {
    const rows = firmwareForModel(modelId);
    let html = '<option value="">Unknown / not recorded</option>';
    html += rows.map(f => `
      <option value="${f.controller_firmware_version_id}" ${Number(selectedId) === Number(f.controller_firmware_version_id) ? 'selected' : ''}>
        ${esc(f.firmware_version)}${f.is_current_recommended ? ' — recommended' : ''}
      </option>`).join('');
    if (!selectedId && selectedText) {
      const match = rows.find(f => String(f.firmware_version) === String(selectedText));
      if (match) {
        html = html.replace(`value="${match.controller_firmware_version_id}"`, `value="${match.controller_firmware_version_id}" selected`);
      }
    }
    return html;
  }

  function stateOptions(values, selected) {
    return values.map(value => `
      <option value="${value}" ${value === selected ? 'selected' : ''}>${value.replaceAll('_', ' ')}</option>`).join('');
  }

  function attachDialogClose(dialog, form) {
    dialog.addEventListener('cancel', event => {
      if (form && activeControllerFormDirty && !window.confirm('Discard unsaved Controller changes?')) {
        event.preventDefault();
      }
    });
  }

  function closeDialog(dialog, form = null) {
    const controllerFormIsDirty = activeControllerFormDirty && (form || dialog === activeControllerDialog);
    if (controllerFormIsDirty && !window.confirm('Discard unsaved Controller changes?')) return;
    activeControllerFormDirty = false;
    dialog.close();
    dialog.remove();
    if (activeControllerDialog === dialog) activeControllerDialog = null;
  }

  function createDialog(id, title, subtitle) {
    const old = document.getElementById(id);
    if (old) old.remove();
    const dialog = document.createElement('dialog');
    dialog.id = id;
    dialog.className = 'management-dialog';
    dialog.innerHTML = `
      <div class="management-dialog-shell">
        <div class="management-dialog-header">
          <div><h2>${esc(title)}</h2><div class="muted">${esc(subtitle || '')}</div></div>
          <button type="button" class="small dialog-x" aria-label="Close">Close</button>
        </div>
        <div class="management-dialog-body"></div>
      </div>`;
    document.body.appendChild(dialog);
    dialog.querySelector('.dialog-x').addEventListener('click', () => closeDialog(dialog));
    return dialog;
  }

  function syncModelRules(form, controller = {}) {
    const modelSelect = form.elements.controller_model_id;
    const firmwareSelect = form.elements.installed_firmware_version_id;
    const countInput = form.elements.lor_uid_count;
    const model = modelById(modelSelect.value);
    const currentlySelectedFirmware = firmwareSelect.value;
    firmwareSelect.innerHTML = firmwareOptions(
      modelSelect.value,
      currentlySelectedFirmware || controller.installed_firmware_version_id,
      controller.installed_firmware,
    );

    const capacity = model?.lor_uid_capacity ?? null;
    const fixed = Boolean(model?.lor_uid_requires_full_capacity);
    const hint = form.querySelector('#model-capacity-hint');
    hint.textContent = capacity
      ? `${model.model_code}: ${capacity} LOR UID${Number(capacity) === 1 ? '' : 's'} maximum${fixed ? ' and required when LOR UID programming is used' : ''}.`
      : `${model?.model_code || 'Selected model'}: no LOR UID capacity is recorded; use management IP/configuration as applicable.`;

    countInput.readOnly = fixed;
    if (fixed && capacity && form.elements.lor_uid_start.value.trim()) {
      countInput.value = capacity;
    }
    syncUidRange(form);
    syncFirmwareState(form);
  }

  function syncUidRange(form) {
    const range = form.querySelector('#uid-range-preview');
    try {
      const start = parseHexUid(form.elements.lor_uid_start.value);
      const count = form.elements.lor_uid_count.value ? Number(form.elements.lor_uid_count.value) : null;
      if (!start || !count || !Number.isInteger(count) || count < 1) {
        range.textContent = '—';
        return;
      }
      const end = start + count - 1;
      range.textContent = end <= 240 ? `${hexUid(start)}-${hexUid(end)}` : 'Exceeds F0';
    } catch (_) {
      range.textContent = 'Invalid UID';
    }
  }

  function syncFirmwareState(form) {
    const firmware = form.elements.installed_firmware_version_id.value;
    const state = form.elements.firmware_verification_state;
    if (!firmware) {
      state.value = 'UNKNOWN';
    } else if (state.value === 'UNKNOWN') {
      state.value = 'RECORDED_UNVERIFIED';
    }
  }

  function controllerFormPayload(form) {
    const lorNetwork = form.elements.lor_network.value.trim();
    const uidText = form.elements.lor_uid_start.value.trim();
    const countText = form.elements.lor_uid_count.value.trim();
    const lorAny = Boolean(lorNetwork || uidText || countText);
    if (lorAny && !(lorNetwork && uidText && countText)) {
      throw new Error('LOR Network, First UID, and UID Count must be entered together.');
    }
    const uidStart = uidText ? parseHexUid(uidText) : null;
    const uidCount = countText ? Number(countText) : null;
    if (uidCount !== null && (!Number.isInteger(uidCount) || uidCount < 1)) {
      throw new Error('UID Count must be a positive whole number.');
    }
    if (uidStart && uidCount && uidStart + uidCount - 1 > 240) {
      throw new Error('The programmed UID range cannot extend beyond F0.');
    }

    const firmwareId = form.elements.installed_firmware_version_id.value;
    return {
      controller_model_id: Number(form.elements.controller_model_id.value),
      controller_status_id: Number(form.elements.controller_status_id.value),
      hardware_revision: form.elements.hardware_revision.value.trim() || null,
      installed_firmware_version_id: firmwareId ? Number(firmwareId) : null,
      firmware_verification_state: form.elements.firmware_verification_state.value,
      firmware_verification_note: form.elements.firmware_verification_note.value.trim() || null,
      serial_number: form.elements.serial_number.value.trim() || null,
      year_deployed: form.elements.year_deployed.value ? Number(form.elements.year_deployed.value) : null,
      current_location_code: form.elements.current_location_code.value || null,
      is_display_attached: form.elements.is_display_attached.value === ''
        ? null : form.elements.is_display_attached.value === 'true',
      verification_state: form.elements.verification_state.value,
      notes: form.elements.notes.value.trim() || null,
      label_required: form.elements.label_required.checked,
      lor_network: lorNetwork || null,
      lor_uid_start: uidStart,
      lor_uid_count: uidCount,
      management_ip: form.elements.management_ip.value.trim() || null,
      programmed_config_verification_state: form.elements.programmed_config_verification_state.value,
      programmed_config_source_note: form.elements.programmed_config_source_note.value.trim() || null,
    };
  }

  async function openControllerForm(mode, controllerId = null) {
    await loadOptions();
    const detailPayload = controllerId ? await api(`api/controllers/${controllerId}`) : null;
    const c = detailPayload?.controller || {};
    const isAdd = mode === 'add';
    const available = statusByName('AVAILABLE');
    const initialModel = c.controller_model_id || options.models?.[0]?.controller_model_id || '';
    const initialStatus = c.controller_status_id || available?.controller_status_id || options.statuses?.[0]?.controller_status_id || '';

    const dialog = createDialog(
      'controller-edit-dialog',
      isAdd ? 'Add Controller' : `Edit CTRL ${controllerId}`,
      isAdd
        ? 'Create one permanent physical Controller asset. The Controller ID is assigned by PostgreSQL.'
        : 'Maintain current physical Controller facts. Display assignments are managed separately.',
    );
    activeControllerDialog = dialog;
    const body = dialog.querySelector('.management-dialog-body');
    body.innerHTML = `
      <form id="controller-maintenance-form">
        <section class="management-section">
          <h3>Identification and Operational State</h3>
          <div class="management-form-grid">
            <label>Model<select name="controller_model_id" required>${modelOptions(initialModel)}</select><div id="model-capacity-hint" class="management-capacity"></div></label>
            <label>Status<select name="controller_status_id" required>${statusOptions(initialStatus)}</select></label>
            <label>Physical Verification<select name="verification_state">${stateOptions(['ENGINEERING_ACCEPTED','FIELD_VERIFICATION_REQUIRED','PHYSICALLY_VERIFIED'], c.verification_state || 'FIELD_VERIFICATION_REQUIRED')}</select></label>
            <label>Hardware Revision<input name="hardware_revision" value="${esc(c.hardware_revision || '')}"></label>
            <label>Serial Number<input name="serial_number" value="${esc(c.serial_number || '')}"></label>
            <label>Year Deployed<input name="year_deployed" type="number" min="1980" max="2100" value="${esc(c.year_deployed || '')}"></label>
            <label>Current Location<select name="current_location_code">${locationOptions(c.current_location_code)}</select></label>
            <label>Display Attached<select name="is_display_attached"><option value="" ${c.is_display_attached == null ? 'selected' : ''}>Unknown</option><option value="true" ${c.is_display_attached === true ? 'selected' : ''}>Yes</option><option value="false" ${c.is_display_attached === false ? 'selected' : ''}>No</option></select></label>
            <label class="management-inline"><input name="label_required" type="checkbox" ${c.label_required !== false ? 'checked' : ''}> Label required</label>
            <label class="wide">Notes<textarea name="notes">${esc(c.notes || '')}</textarea></label>
          </div>
        </section>

        <section class="management-section">
          <h3>Current Programmed Configuration</h3>
          <div class="management-form-grid">
            <label>LOR Network<input name="lor_network" value="${esc(c.lor_network || '')}" placeholder="Regular, Aux A, Aux N…"></label>
            <label>First UID (hex)<input name="lor_uid_start" value="${esc(hexUid(c.lor_uid_start))}" maxlength="2" placeholder="01"></label>
            <label>UID Count<input name="lor_uid_count" type="number" min="1" max="240" value="${esc(c.lor_uid_count || '')}"></label>
            <label>Calculated UID Range<div id="uid-range-preview" class="readonly-value">—</div></label>
            <label>Management IP<input name="management_ip" value="${esc(c.management_ip || '')}" placeholder="10.10.5.10"></label>
            <label>Configuration Verification<select name="programmed_config_verification_state">${stateOptions(['UNKNOWN','RECORDED_UNVERIFIED','VERIFIED'], c.programmed_config_verification_state || 'UNKNOWN')}</select></label>
            <label class="wide">Configuration Source / Verification Note<textarea name="programmed_config_source_note">${esc(c.programmed_config_source_note || '')}</textarea></label>
          </div>
          <div class="management-capacity">This records what the physical controller is programmed as now. LOR/V7 remains authority for what the show requires.</div>
        </section>

        <section class="management-section">
          <h3>Firmware</h3>
          <div class="management-form-grid">
            <label>Installed Firmware<select name="installed_firmware_version_id"></select></label>
            <label>Firmware Verification<select name="firmware_verification_state">${stateOptions(['UNKNOWN','RECORDED_UNVERIFIED','VERIFIED'], c.firmware_verification_state || 'UNKNOWN')}</select></label>
            <label class="span-2">Firmware Verification Note<input name="firmware_verification_note" value="${esc(c.firmware_verification_note || '')}"></label>
          </div>
          <div class="management-capacity">When firmware is changed or newly verified, PostgreSQL records a firmware-history event.</div>
        </section>

        <div id="controller-form-message"></div>
        <div class="management-dialog-actions">
          <button type="button" class="cancel-controller-form">Cancel</button>
          <button type="submit" class="primary">${isAdd ? 'Add Controller' : 'Save Controller'}</button>
        </div>
      </form>`;

    const form = body.querySelector('#controller-maintenance-form');
    const firmwareRows = firmwareForModel(initialModel);
    const selectedFirmware = c.installed_firmware_version_id
      || firmwareRows.find(f => String(f.firmware_version) === String(c.installed_firmware || ''))?.controller_firmware_version_id
      || null;
    form.elements.installed_firmware_version_id.innerHTML = firmwareOptions(initialModel, selectedFirmware, c.installed_firmware);
    syncModelRules(form, {...c, installed_firmware_version_id:selectedFirmware});

    form.elements.controller_model_id.addEventListener('change', () => syncModelRules(form));
    form.elements.lor_uid_start.addEventListener('input', () => {
      const model = modelById(form.elements.controller_model_id.value);
      if (model?.lor_uid_requires_full_capacity && model.lor_uid_capacity && form.elements.lor_uid_start.value.trim()) {
        form.elements.lor_uid_count.value = model.lor_uid_capacity;
      }
      syncUidRange(form);
    });
    form.elements.lor_uid_count.addEventListener('input', () => syncUidRange(form));
    form.elements.installed_firmware_version_id.addEventListener('change', () => syncFirmwareState(form));
    form.addEventListener('input', () => { activeControllerFormDirty = true; });
    form.addEventListener('change', () => { activeControllerFormDirty = true; });
    form.querySelector('.cancel-controller-form').addEventListener('click', () => closeDialog(dialog, form));
    attachDialogClose(dialog, form);

    form.addEventListener('submit', async event => {
      event.preventDefault();
      const message = form.querySelector('#controller-form-message');
      const submit = form.querySelector('button[type="submit"]');
      submit.disabled = true;
      message.className = 'muted';
      message.textContent = isAdd ? 'Adding Controller…' : 'Saving Controller…';
      try {
        const payload = controllerFormPayload(form);
        const result = await api(
          isAdd ? 'api/controllers' : `api/controllers/${controllerId}`,
          {
            method: isAdd ? 'POST' : 'PATCH',
            headers: COMMAND_HEADERS,
            body: JSON.stringify(payload),
          },
        );
        activeControllerFormDirty = false;
        const savedId = Number(result.controller?.controller_id || controllerId);
        const actor = result.controller?.operator_display_name || access?.display_name || 'authorized operator';
        message.className = 'management-success';
        message.textContent = `CTRL ${savedId} saved by ${actor}.`;
        if (typeof loadControllers === 'function') await loadControllers();
        if (typeof loadControllerDetail === 'function') await loadControllerDetail(savedId);
        window.setTimeout(() => {
          if (dialog.open) closeDialog(dialog);
        }, 350);
      } catch (error) {
        message.className = 'management-error';
        message.textContent = error.message;
        submit.disabled = false;
      }
    });

    dialog.showModal();
  }

  function stageLabel(item) {
    return item.stage_key ? `${item.stage_key} · ${item.stage_name || ''}` : 'No Stage';
  }

  async function searchDisplays(query, target, onChoose, buttonLabel = 'Select') {
    target.innerHTML = '<div class="muted" style="padding:10px">Searching Displays…</div>';
    try {
      const payload = await api(`api/controller-management/displays?q=${encodeURIComponent(query)}`);
      const rows = payload.displays || [];
      if (!rows.length) {
        target.innerHTML = '<div class="muted" style="padding:10px">No active Displays match.</div>';
        return;
      }
      target.innerHTML = rows.map((d, index) => `
        <div class="assignment-result">
          <div>
            <strong>${esc(d.display_name)}</strong>
            <div class="meta">Display ${d.display_id} · ${esc(stageLabel(d))} · ${d.has_current_wiring ? 'Current LOR wiring' : 'No current LOR wiring'}</div>
            ${Number(d.controller_count) > 0 ? `<div class="coverage">Already assigned controller(s): ${esc(d.controller_ids)}</div>` : ''}
          </div>
          <button type="button" class="small choose-display" data-index="${index}">${esc(buttonLabel)}</button>
        </div>`).join('');
      for (const button of target.querySelectorAll('.choose-display')) {
        button.addEventListener('click', () => onChoose(rows[Number(button.dataset.index)]));
      }
    } catch (error) {
      target.innerHTML = `<div class="management-error" style="padding:10px">${esc(error.message)}</div>`;
    }
  }

  async function chooseWiringSource(container, selectedId = null, selectedName = '') {
    return new Promise(resolve => {
      container.innerHTML = `
        <div class="management-inline">
          <input class="wiring-source-toggle" type="checkbox" ${selectedId ? 'checked' : ''}>
          <strong>Use another Display as the LOR wiring source</strong>
        </div>
        <div class="wiring-source-picker" ${selectedId ? '' : 'hidden'}>
          <div class="assignment-search">
            <input class="wiring-source-query" placeholder="Search Display name or ID">
            <button type="button" class="wiring-source-search">Search</button>
          </div>
          <div class="wiring-source-selected">${selectedId ? `Selected: ${esc(selectedName || `Display ${selectedId}`)}` : 'No wiring source selected.'}</div>
          <div class="assignment-results wiring-source-results" hidden></div>
        </div>`;
      const toggle = container.querySelector('.wiring-source-toggle');
      const picker = container.querySelector('.wiring-source-picker');
      const query = container.querySelector('.wiring-source-query');
      const results = container.querySelector('.wiring-source-results');
      const selected = container.querySelector('.wiring-source-selected');
      let source = selectedId ? {display_id:selectedId, display_name:selectedName || `Display ${selectedId}`} : null;

      toggle.addEventListener('change', () => {
        picker.hidden = !toggle.checked;
        if (!toggle.checked) {
          source = null;
          selected.textContent = 'No wiring source selected.';
        }
      });
      const doSearch = async () => {
        if (!query.value.trim()) return;
        results.hidden = false;
        await searchDisplays(query.value, results, item => {
          source = item;
          selected.textContent = `Selected: ${item.display_name} (Display ${item.display_id})`;
          results.hidden = true;
        }, 'Use');
      };
      container.querySelector('.wiring-source-search').addEventListener('click', doSearch);
      query.addEventListener('keydown', event => {
        if (event.key === 'Enter') { event.preventDefault(); doSearch(); }
      });
      resolve(() => toggle.checked && source ? Number(source.display_id) : null);
    });
  }

  async function openRelationshipEditor(controller, mode, display, existing = null, oldDisplayId = null) {
    const title = mode === 'add'
      ? `Assign CTRL ${controller.controller_id}`
      : mode === 'replace'
        ? `Reassign CTRL ${controller.controller_id}`
        : `Edit Assignment — CTRL ${controller.controller_id}`;
    const dialog = createDialog('controller-assignment-edit-dialog', title, `${display.display_name} · Display ${display.display_id} · ${stageLabel(display)}`);
    const body = dialog.querySelector('.management-dialog-body');
    body.innerHTML = `
      <form id="assignment-edit-form">
        <section class="management-section">
          <div class="management-form-grid">
            <label class="span-2">Display<div class="readonly-value">${esc(display.display_name)} · Display ${display.display_id} · ${esc(stageLabel(display))}</div></label>
            <label>Placement Note<input name="placement_note" value="${esc(existing?.placement_note || '')}"></label>
            <label class="wide">Relationship Notes<textarea name="notes">${esc(existing?.notes || '')}</textarea></label>
          </div>
          <div id="wiring-source-control" class="wiring-source-picker"></div>
          ${mode === 'add' && controller.controller_status_name === 'AVAILABLE' ? `<label class="management-inline" style="margin-top:10px"><input name="mark_deployed" type="checkbox" checked> Change status from AVAILABLE to DEPLOYED when assigned</label>` : ''}
        </section>
        <div class="management-capacity">Network/UID/IP are not used as Controller identity. Intentional duplicate addresses remain valid.</div>
        <div id="assignment-edit-message"></div>
        <div class="management-dialog-actions"><button type="button" class="cancel-assignment">Cancel</button><button type="submit" class="primary">Save Assignment</button></div>
      </form>`;
    const form = body.querySelector('#assignment-edit-form');
    const sourceGetter = await chooseWiringSource(
      form.querySelector('#wiring-source-control'),
      existing?.wiring_source_display_id || null,
      existing?.wiring_source_display || '',
    );
    form.querySelector('.cancel-assignment').addEventListener('click', () => closeDialog(dialog));
    form.addEventListener('submit', async event => {
      event.preventDefault();
      const message = form.querySelector('#assignment-edit-message');
      const submit = form.querySelector('button[type="submit"]');
      submit.disabled = true;
      try {
        const payload = {
          display_id: Number(display.display_id),
          wiring_source_display_id: sourceGetter(),
          placement_note: form.elements.placement_note.value.trim() || null,
          notes: form.elements.notes.value.trim() || null,
        };
        let url;
        let method;
        if (mode === 'edit') {
          url = `api/controllers/${controller.controller_id}/assignments/${display.display_id}`;
          method = 'PATCH';
        } else if (mode === 'replace') {
          url = `api/controllers/${controller.controller_id}/assignments/${oldDisplayId}/reassign`;
          method = 'POST';
        } else {
          url = `api/controllers/${controller.controller_id}/assignments`;
          method = 'POST';
          payload.mark_deployed = form.elements.mark_deployed ? form.elements.mark_deployed.checked : false;
        }
        await api(url, {method, headers:COMMAND_HEADERS, body:JSON.stringify(payload)});
        message.className = 'management-success';
        message.textContent = 'Assignment saved.';
        if (typeof loadControllers === 'function') await loadControllers();
        if (typeof loadControllerDetail === 'function') await loadControllerDetail(controller.controller_id);
        closeDialog(dialog);
        const manager = document.getElementById('controller-assignments-dialog');
        if (manager?.open) {
          manager.close();
          manager.remove();
          await openAssignments(controller.controller_id);
        }
      } catch (error) {
        message.className = 'management-error';
        message.textContent = error.message;
        submit.disabled = false;
      }
    });
    dialog.showModal();
  }

  async function unassign(controller, assignment, assignmentCount) {
    let returnAvailable = false;
    if (assignmentCount === 1 && controller.controller_status_name === 'DEPLOYED') {
      returnAvailable = window.confirm(
        `This is CTRL ${controller.controller_id}'s final Display assignment.\n\nOK: return the Controller to AVAILABLE after unassigning.\nCancel: keep its current DEPLOYED status.`,
      );
    }
    if (!window.confirm(`Unassign CTRL ${controller.controller_id} from ${assignment.display_name}?\n\nThe Controller asset itself will NOT be deleted.`)) return;
    await api(
      `api/controllers/${controller.controller_id}/assignments/${assignment.display_id}`,
      {method:'DELETE', headers:COMMAND_HEADERS, body:JSON.stringify({return_available:returnAvailable})},
    );
    if (typeof loadControllers === 'function') await loadControllers();
    if (typeof loadControllerDetail === 'function') await loadControllerDetail(controller.controller_id);
    const manager = document.getElementById('controller-assignments-dialog');
    if (manager?.open) {
      manager.close();
      manager.remove();
      await openAssignments(controller.controller_id);
    }
  }

  async function openAssignments(controllerId) {
    const payload = await api(`api/controllers/${controllerId}`);
    const controller = payload.controller;
    const assignments = payload.assignments || [];
    const dialog = createDialog(
      'controller-assignments-dialog',
      `Manage Display Assignments — CTRL ${controllerId}`,
      'Current-snapshot many-to-many relationships. Unassigning never deletes the Controller asset.',
    );
    const body = dialog.querySelector('.management-dialog-body');
    body.innerHTML = `
      <section class="management-section">
        <h3>Current Assignments</h3>
        <div class="assignment-manager-list">${assignments.length ? assignments.map((a, i) => `
          <div class="assignment-manager-row" data-index="${i}">
            <div><strong>${esc(a.display_name)}</strong><div class="muted">Display ${a.display_id} · ${esc(stageLabel(a))}</div><div class="muted">Wiring source: ${esc(a.wiring_source_display_id ? `${a.wiring_source_display} (Display ${a.wiring_source_display_id})` : 'This Display')}</div></div>
            <div class="actions"><button type="button" class="small edit-assignment">Edit</button><button type="button" class="small replace-assignment">Replace</button><button type="button" class="small danger unassign-assignment">Unassign</button></div>
          </div>`).join('') : '<div class="muted">No current Display assignments. This is valid for shelf stock.</div>'}</div>
      </section>
      <section class="management-section">
        <h3 id="assignment-search-title">Assign Another Display</h3>
        <div id="replace-context" class="management-warning" hidden></div>
        <div class="assignment-search"><input id="assignment-display-query" placeholder="Display name or ID"><button id="assignment-display-search" type="button">Search</button></div>
        <div id="assignment-display-results" class="assignment-results" hidden></div>
      </section>
      <div id="assignment-manager-message"></div>
      <div class="management-dialog-actions"><button type="button" class="close-assignment-manager">Done</button></div>`;

    let replaceOld = null;
    const results = body.querySelector('#assignment-display-results');
    const query = body.querySelector('#assignment-display-query');
    const title = body.querySelector('#assignment-search-title');
    const replaceContext = body.querySelector('#replace-context');

    const doSearch = async () => {
      if (!query.value.trim()) return;
      results.hidden = false;
      await searchDisplays(query.value, results, async display => {
        await openRelationshipEditor(
          controller,
          replaceOld ? 'replace' : 'add',
          display,
          replaceOld,
          replaceOld?.display_id || null,
        );
      }, replaceOld ? 'Replace With' : 'Assign');
    };
    body.querySelector('#assignment-display-search').addEventListener('click', doSearch);
    query.addEventListener('keydown', event => {
      if (event.key === 'Enter') { event.preventDefault(); doSearch(); }
    });
    body.querySelector('.close-assignment-manager').addEventListener('click', () => closeDialog(dialog));

    for (const row of body.querySelectorAll('.assignment-manager-row')) {
      const assignment = assignments[Number(row.dataset.index)];
      row.querySelector('.edit-assignment').addEventListener('click', () => openRelationshipEditor(controller, 'edit', assignment, assignment));
      row.querySelector('.replace-assignment').addEventListener('click', () => {
        replaceOld = assignment;
        title.textContent = `Replace ${assignment.display_name}`;
        replaceContext.hidden = false;
        replaceContext.textContent = `Choose the new Display. The replacement is one atomic database command; other Controller assignments are preserved.`;
        query.focus();
      });
      row.querySelector('.unassign-assignment').addEventListener('click', async () => {
        const msg = body.querySelector('#assignment-manager-message');
        try {
          await unassign(controller, assignment, assignments.length);
        } catch (error) {
          msg.className = 'management-error';
          msg.textContent = error.message;
        }
      });
    }

    dialog.showModal();
  }

  function installManagementControls() {
    if (managementInstalled || !access?.can_manage_controllers) return;
    managementInstalled = true;

    const add = document.createElement('button');
    add.type = 'button';
    add.id = 'add-controller-button';
    add.className = 'primary add-controller-button';
    add.textContent = 'Add Controller';
    add.addEventListener('click', () => openControllerForm('add'));
    filters.appendChild(add);

    const syncDetailActions = () => {
      const id = controllerIdFromHeading();
      const detailHeading = document.querySelector('#detail .detail-heading');
      if (!detailHeading) return;
      let actions = document.getElementById('controller-management-actions');
      if (!id) {
        if (actions) actions.remove();
        return;
      }
      if (!actions) {
        actions = document.createElement('div');
        actions.id = 'controller-management-actions';
        actions.className = 'management-actions';
        const status = document.getElementById('detail-status');
        if (status) detailHeading.insertBefore(actions, status);
        else detailHeading.appendChild(actions);
      }
      actions.innerHTML = `<button type="button" class="edit-controller-button">Edit Controller</button><button type="button" class="manage-assignments-button">Manage Assignments</button>`;
      actions.querySelector('.edit-controller-button').addEventListener('click', () => openControllerForm('edit', id));
      actions.querySelector('.manage-assignments-button').addEventListener('click', () => openAssignments(id));
    };

    new MutationObserver(syncDetailActions).observe(detailId, {childList:true, subtree:true, characterData:true});
    syncDetailActions();
  }

  window.addEventListener('beforeunload', event => {
    if (activeControllerDialog?.open && activeControllerFormDirty) {
      event.preventDefault();
      event.returnValue = '';
    }
  });

  loadAccess()
    .then(() => installManagementControls())
    .catch(() => {
      // The existing read-only Controller browser remains usable if management
      // capability resolution is unavailable.
    });
})();
