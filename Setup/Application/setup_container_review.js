/* #88 desk review: selections are explicit; GET never changes movement records. */
(() => {
  'use strict';
  const el = id => document.getElementById(id);
  const year = Number(new URLSearchParams(location.search).get('season_year')) || new Date().getFullYear();
  let data = null,
    current = null,
    selected = new Set(),
    saving = false,
    pending = null;
  const actions = {
    NEEDS_FIELD_CHECK: 'Needs field check — keep open',
    CONFIRM: 'Confirm selected records are correct',
    LOCATION: 'Correct selected Display locations',
    PRIOR_PARK: 'Empty return — leave selected Displays at prior park stop',
    ATTACH: 'Restore selected erroneous detachments to this Container'
  };
  const text = (tag, value, cls) => {
    const n = document.createElement(tag);
    n.textContent = value;
    if (cls) n.className = cls;
    return n;
  };
  const cid = c => `C${String(c.container_id).padStart(3,'0')}`;
  const when = v => v ? new Date(v).toLocaleString() : 'Not recorded';
  const destination = e => [e?.stage_key, e?.stage_name, e?.destination_location_note].filter(Boolean).join(
    ' · ') || 'Stage / name not recorded';
  const localNow = () => {
    const d = new Date();
    return new Date(d - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  };
  const displays = c => [...c.attached, ...c.detached].sort((a, b) => a.display_name.localeCompare(b
    .display_name));

  function evidence(parent, e) {
    parent.append(text('p',
      `Recorded destination: ${destination(e)} · ${e?.observed||when(e?.occurred_at)}`));
    parent.append(text('p', e?.gps || 'No GPS recorded', 'muted'));
    if (e?.nearest_reference) parent.append(text('p',
      `Calculated nearest reference: ${e.nearest_reference.name} · ${Math.round(e.nearest_reference.distance_ft)} ft (GPS estimate)`,
      'muted'));
  }
  async function json(url, opts = {}) {
    const r = await fetch(url, {
      cache: 'no-store',
      ...opts
    });
    const p = await r.json();
    if (!r.ok) throw new Error(p.error || `Request failed (${r.status})`);
    return p;
  }

  function error(e) {
    el('status').textContent = e.message;
    el('status').className = 'error';
  }
  async function load() {
    data = await json(`../api/setup/container-exceptions?season_year=${year}`);
    el('status').className = '';
    el('status').textContent =
      `As of ${data.generated} · through event ${data.through_event_id} · V0.3.85-container-review`;
    el('counts').replaceChildren(...[
      ['Outstanding Containers', data.counts.open],
      ['Needs field check', data.counts.field_check],
      ['Resolved reviews', data.counts.resolved]
    ].map(([label, n]) => {
      const box = text('div', label);
      box.prepend(text('strong', n));
      return box;
    }));
    render();
  }

  function render() {
    const q = el('search').value.trim().toLowerCase(),
      f = el('filter').value;
    const rows = data.cases.filter(c => (f === 'ALL' || (f === 'OPEN' ? c.status !== 'RESOLVED' : c
      .status === f || c.reasons.some(r => r.code === f))) && (!q ||
      `${cid(c)} ${c.container_id} ${c.container_name} ${displays(c).map(d=>d.display_name).join(' ')}`
      .toLowerCase().includes(q)));
    el('cases').replaceChildren(...rows.map(c => {
      const box = text('article', '', `case ${c.status==='RESOLVED'?'resolved':''}`);
      const top = text('div', '', 'case-top');
      const title = text('div', '');
      title.append(text('h2', `${cid(c)} — ${c.container_name}`), text('span', c.status.replaceAll(
        '_', ' '), 'tag'));
      const btn = text('button', 'Review case');
      btn.addEventListener('click', () => openCase(c));
      top.append(title, btn);
      box.append(top);
      c.reasons.forEach(r => box.append(text('p', r.label, 'reason'), text('p', r.next_action)));
      box.append(text('p',
        `${c.location_group} · ${c.attached.length} recorded attached / ${c.detached.length} detached`
        ), text('p',
        `${c.age_days} days since oldest open flag / current movement · Last activity ${c.last_activity}`,
        'muted'));
      const names = displays(c).filter(d => c.reasons.some(r => r.code === 'RETURNED_ATTACHED') ? d
        .position_mode === 'WITH_CONTAINER' : c.reasons.some(r => r.code === 'PROTECTED_DETACHED') ?
        d.position_mode === 'DETACHED' : true);
      box.append(text('p', names.slice(0, 5).map(d => d.display_name).join(' · ') + (names.length >
        5 ? ` · +${names.length-5} more` : ''), 'muted'));
      return box;
    }));
    if (!rows.length) el('cases').append(text('p', 'No cases match this view.'));
  }

  function checkbox(label, value) {
    const row = text('label', ''),
      input = document.createElement('input');
    input.type = 'checkbox';
    input.value = value;
    row.append(input, text('span', label));
    return {
      row,
      input
    };
  }

  function selection() {
    el('selected-count').textContent =
      `${selected.size} of ${displays(current).length} Display Names selected`;
    el('review-summary').textContent = `${selected.size} selected · ${actions[el('action').value]}`;
  }

  function renderNames() {
    const q = el('display-search').value.toLowerCase();
    el('displays').replaceChildren(...displays(current).filter(d => d.display_name.toLowerCase().includes(
      q)).map(d => {
      const {
        row,
        input
      } = checkbox(d.display_name, d.display_id);
      input.checked = selected.has(d.display_id);
      input.addEventListener('change', () => {
        input.checked ? selected.add(d.display_id) : selected.delete(d.display_id);
        selection();
      });
      row.lastChild.append(text('small',
        `${d.position_mode==='WITH_CONTAINER'?'With Container':'Independent'} · ${d.current_location_note||d.stage_name||'location: see movement evidence'} · event ${d.last_movement_event_id||'not recorded'}`
        ));
      return row;
    }));
    selection();
  }

  function openCase(c) {
    current = c;
    selected = new Set();
    pending = null;
    el('case-title').textContent = `${cid(c)} — ${c.container_name}`;
    el('save-status').textContent = '';
    el('evidence').value = '';
    el('observed-at').value = localNow();
    el('location-note').value = '';
    el('display-search').value = '';
    el('whole-case').checked = false;
    el('case-evidence').replaceChildren(text('p',
      `${c.container_type_name} · Home ${c.home_location_code||'not recorded'} · ${c.movement_status||'No Container movement logged'}`));
    evidence(el('case-evidence'), c.latest);
    if (c.prior_park) {
      el('case-evidence').append(text('h3',
        `Prior park anchor · event ${c.prior_park.setup_movement_event_id}`));
      evidence(el('case-evidence'), c.prior_park);
    }
    const a = document.createElement('a');
    a.textContent = 'Open this Container in the full movement trail';
    a.href = `../api/setup/material-status/report?season_year=${year}#container-${c.container_id}`;
    a.target = '_blank';
    a.rel = 'noopener';
    el('case-evidence').append(a);
    el('flags').replaceChildren(...c.open_flags.map(f => {
      const box = text('div', '', 'flag');
      box.append(text('p',
          `Event ${f.setup_movement_event_id} · ${f.observed} · ${f.captured_operator_email||'recorder not recorded'}`
          ), text('p', f.captured_displays ?
          `Captured scope: ${f.captured_displays.map(d=>d.display_name).join(' · ')||'No Display Names captured'}` :
          'Original Display scope not captured; current assignments are not a historical snapshot.'
          ));
      return box;
    }));
    el('resolve-flags').replaceChildren(...c.open_flags.map(f => {
      const {
        row,
        input
      } = checkbox(
        `Resolve original flag ${f.setup_movement_event_id} after accounting for its complete scope`,
        f.setup_movement_event_id);
      input.dataset.resolveFlag = '1';
      return row;
    }));
    el('whole-case-label').hidden = !c.open_flags.some(f => f.captured_displays === null) && displays(c)
      .length > 0;
    el('action').replaceChildren(...Object.entries(actions).filter(([key]) => !(c.protected && ['LOCATION',
      'PRIOR_PARK'
    ].includes(key)) && !(key === 'PRIOR_PARK' && !c.prior_park) && !(key === 'ATTACH' && (c
      .movement_status === 'RETURNED' || !c.detached.length))).map(([key, label]) => {
      const opt = text('option', label);
      opt.value = key;
      return opt;
    }));
    el('review-history').replaceChildren(...c.reviews.map(r => text('p',
      `${when(r.recorded_at)} · ${r.reviewer_email} · ${actions[r.action]} · ${r.evidence} · flags resolved: ${r.resolved_flag_ids.join(', ')||'none'}`,
      'review-row')));
    if (!c.reviews.length) el('review-history').append(text('p', 'No review decisions recorded.'));
    actionChanged();
    renderNames();
    el('case-dialog').showModal();
  }

  function actionChanged() {
    el('location-fields').hidden = el('action').value !== 'LOCATION';
    selection();
  }

  function freeze(value) {
    saving = value;
    el('save').disabled = value;
    el('confirm-save').disabled = value;
    el('close').disabled = value;
    el('cancel-save').disabled = value;
  }
  el('review-form').addEventListener('submit', e => {
    e.preventDefault();
    if (saving) return;
    const action = el('action').value;
    if (action !== 'NEEDS_FIELD_CHECK' && !selected.size && !(action === 'CONFIRM' && !displays(current)
        .length && el('whole-case').checked)) {
      el('save-status').textContent = 'Select the Display Names reviewed.';
      return;
    }
    if (action === 'LOCATION' && !el('location-note').value.trim()) {
      el('save-status').textContent = 'Enter the verified Stage / location.';
      return;
    }
    const command = {
      action,
      display_ids: [...selected],
      flag_ids: current.open_flags.map(f => f.setup_movement_event_id),
      resolve_flag_ids: [...el('resolve-flags').querySelectorAll('input:checked')].map(n => Number(n
        .value)),
      whole_case_confirmed: el('whole-case').checked,
      evidence: el('evidence').value.trim(),
      observed_at: new Date(el('observed-at').value).toISOString(),
      location_note: el('location-note').value.trim() || null
    };
    pending = {
      season_year: year,
      client_event_id: crypto.randomUUID(),
      snapshot: current.snapshot,
      command
    };
    el('confirmation').replaceChildren(text('p', `${cid(current)} · ${actions[action]}`), text('p',
        action === 'PRIOR_PARK' ?
        `Inferred location from prior event ${current.prior_park.setup_movement_event_id}: ${destination(current.prior_park)}. Container stays Home.` :
        action === 'LOCATION' ? `Verified destination: ${command.location_note}` : action ===
        'ATTACH' ?
        'Selected independent locations will be superseded by the assigned Container location. Verify every selected Display.' :
        'Only selected Display Names are affected.'), text('p', `Evidence: ${command.evidence}`),
      text('p', `Resolve flags: ${command.resolve_flag_ids.join(', ')||'none; keep open'}`));
    const ul = text('ul', '');
    displays(current).filter(d => selected.has(d.display_id)).forEach(d => ul.append(text('li',
      `${d.display_name} · ${d.position_mode} · ${d.current_location_note||d.stage_name||'no independent named location'} · current event ${d.last_movement_event_id||'not recorded'}`
      )));
    el('confirmation').append(ul);
    el('confirm-dialog').showModal();
  });
  el('confirm-save').addEventListener('click', async () => {
    if (saving || !pending) return;
    freeze(true);
    try {
      await json(`../api/setup/container-exceptions/${current.container_id}/review`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-MSB-Setup-Command': '1'
        },
        body: JSON.stringify(pending)
      });
      el('confirm-dialog').close();
      el('case-dialog').close();
      pending = null;
      await load();
      el('status').textContent += ' · Review recorded.';
    } catch (e) {
      el('confirm-dialog').close();
      el('save-status').textContent =
        `${e.message} No successful review is confirmed. Refresh the case before changing the selection.`;
      el('save-status').className = 'error';
    } finally {
      freeze(false);
    }
  });
  el('cancel-save').addEventListener('click', () => el('confirm-dialog').close());
  el('close').addEventListener('click', () => el('case-dialog').close());
  el('case-dialog').addEventListener('cancel', e => {
    if (saving) e.preventDefault();
  });
  el('confirm-dialog').addEventListener('cancel', e => {
    if (saving) e.preventDefault();
  });
  el('select-all').addEventListener('click', () => {
    selected = new Set(displays(current).map(d => d.display_id));
    renderNames();
  });
  el('select-none').addEventListener('click', () => {
    selected.clear();
    renderNames();
  });
  el('display-search').addEventListener('input', renderNames);
  el('action').addEventListener('change', actionChanged);
  el('search').addEventListener('input', render);
  el('filter').addEventListener('change', render);
  // Desk entry for known concerns that cannot be detected from recorded state.
  el('open-container').addEventListener('click', async () => {
    const id = Number(el('open-container-id').value);
    if (!Number.isInteger(id) || id < 1) { error(new Error('Enter a Container number.')); return; }
    try {
      const result = await json(`../api/setup/container-exceptions?season_year=${year}&container_id=${id}`);
      const item = result.cases.find(c => c.container_id === id);
      if (!item) throw new Error('Container not found');
      openCase(item);
    } catch (e) { error(e); }
  });
  el('refresh').addEventListener('click', () => load().catch(error));
  el('print').addEventListener('click', () => window.print());
  el('back').href += `?season_year=${year}`;
  el('trail').href = `../api/setup/material-status/report?season_year=${year}`;
  load().catch(error);
})();
