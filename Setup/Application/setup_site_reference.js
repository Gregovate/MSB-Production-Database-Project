/* #171/#230: read-only maintained PostGIS consumer for EXISTING Setup /setup/locate/ map.
 * Reference maintenance belongs in the separate #230 application, never this map.
 * Reference redraw does not touch #88 Container/Display/Drop observation layers.
 * Incomplete/absent DB = visibly dated snapshot, never a silent "live" claim.
 */
(() => {
  'use strict';
  const status = document.createElement('div');
  status.id = 'site-reference-status';
  status.setAttribute('role', 'status');
  status.style.cssText = 'padding:6px 0;font-weight:600;color:#923b15';
  const control = document.getElementById('map-controls');
  const search = document.getElementById('map-search');
  control.insertBefore(status, search.parentNode === control ? search : control.children[1]);
  const inspection = document.createElement('details');
  inspection.id = 'site-reference-inspection';
  inspection.className = 'control-group';
  const summary = document.createElement('summary');
  summary.textContent = 'Selected infrastructure / maintenance';
  inspection.appendChild(summary);
  const body = document.createElement('div');
  body.id = 'site-reference-body';
  inspection.appendChild(body);
  document.getElementById('network-picker').after(inspection);

  // Reuse existing icon *objects*. The parallel SVG/PNG workstream owns URL and
  // rectangular aspect sizing; never infer an icon from a waypoint label.
  const originalIcons = new Map();
  for (const name of ['stages','drops','refs']) layers[name].eachLayer(layer => {
    const p = layer._searchFeature?.properties;
    if (p?.name && layer.options?.icon) originalIcons.set(p.name, layer.options.icon);
  });
  const existingWaypointStyles = new Map(originalIcons);
  const names = new Map();
  let current = null;
  let selection = null;
  let selectedTrack = null;
  let lastEditMessage = '';

  const byId = (values, id, field = 'id') =>
    (values || []).find(value => Number(value[field]) === Number(id));
  const textValue = v => v === null || v === undefined || v === '' ? 'Not recorded / unreviewed' : String(v);
  const sourceYear = v => /^\d{4}/.test(v || '') ? String(v).slice(0,4) : 'not recorded';
  const append = (parent, element) => (parent.appendChild(element), element);
  const line = (parent, value) => {
    const el = document.createElement('div');
    el.style.margin = '5px 0';
    el.textContent = value;
    append(parent, el);
    return el;
  };
  const heading = (parent, value) => {
    const el = document.createElement('strong');
    el.textContent = value;
    append(parent, el);
    return el;
  };
  const lookupLabel = id => byId(current?.waypoints, id)?.label || 'Unknown waypoint #' + id;
  const matchingCircuits = id => (current?.destinations || [])
    .filter(d => Number(d.site_waypoint_id) === Number(id))
    .map(d => byId(current.circuits, d.site_power_circuit_id, 'site_power_circuit_id')).filter(Boolean);
  // Local receptacles are explicit panel-owned devices, never synthetic waypoints.
  const localOutlets = c => (current?.panel_outlets || []).filter(o =>
    Number(o.site_power_circuit_id) === Number(c.site_power_circuit_id));
  const destinationLabels = c => [
    ...current.destinations.filter(d => Number(d.site_power_circuit_id) === Number(c.site_power_circuit_id))
      .map(d => lookupLabel(d.site_waypoint_id)),
    ...localOutlets(c).map(o => 'At panel: ' + o.device_name)
  ];
  const inspectedCables = id => (current?.cables || []).filter(c =>
    Number(c.endpoint_a) === Number(id) || Number(c.endpoint_b) === Number(id));
  const networkNames = id => (current?.memberships || [])
    .filter(m => Number(m.site_waypoint_id) === Number(id))
    .map(m => byId(current.networks, m.site_network_id)?.network_code).filter(Boolean);

  function field(form, labelText, name, value = '', type = 'text') {
    const label = document.createElement('label');
    label.style.cssText = 'display:block;margin:8px 0';
    label.textContent = labelText + ' ';
    const input = document.createElement('input');
    input.name = name;
    input.type = type;
    input.value = value === null || value === undefined ? '' : String(value);
    input.style.cssText = 'box-sizing:border-box;width:100%;min-height:34px';
    label.appendChild(input);
    form.appendChild(label);
    return input;
  }
  function choice(form, labelText, name, values) {
    const label = document.createElement('label');
    label.textContent = labelText + ' ';
    const select = document.createElement('select');
    select.name = name;
    select.style.cssText = 'width:100%;min-height:36px';
    for (const [value, caption] of values) {
      const option = document.createElement('option');
      option.value = String(value);
      option.textContent = caption;
      select.appendChild(option);
    }
    label.appendChild(select);
    form.appendChild(label);
    return select;
  }
  function action(parent, title, command, setupFields) {
    const box = document.createElement('details');
    box.style.cssText = 'margin-top:9px;border-top:1px solid #ddd;padding-top:7px';
    const head = document.createElement('summary');
    head.textContent = title;
    box.appendChild(head);
    const form = document.createElement('form');
    const build = setupFields(form);
    const evidence = field(form, 'Reason / source evidence (required)', 'evidence_notes', '');
    evidence.required = true;
    const save = document.createElement('button');
    save.type = 'submit';
    save.textContent = 'Save reviewed change';
    form.appendChild(save);
    form.addEventListener('submit', async ev => {
      ev.preventDefault();
      save.disabled = true;
      try {
        const fields = build();
        fields.evidence_notes = evidence.value.trim();
        if (!fields.evidence_notes) throw new Error('Review evidence is required');
        const response = await fetch('../api/setup/locate/references/command', {
          method: 'POST', credentials: 'same-origin',
          headers: {'Content-Type':'application/json', 'X-MSB-Setup-Command':'1'},
          cache: 'no-store',
          body: JSON.stringify({command, expected_revision:current.revision, fields})
        });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Command rejected');
        lastEditMessage = 'Saved as revision ' + result.revision + '; audit entry recorded.';
        await refresh();
        if (selectedTrack !== null) showTrack(selectedTrack);
        else if (selection !== null) showWaypoint(selection);
      } catch (error) {
        lastEditMessage = 'NOT saved: ' + error.message + '. Refresh before retrying.';
        line(form, lastEditMessage);
      } finally {
        save.disabled = false;
      }
    });
    box.appendChild(form);
    parent.appendChild(box);
  }
  function waypointPopup(point) {
    const display = document.createElement('div');
    heading(display, point.label);
    line(display, point.type || 'Waypoint');
    line(display, 'Source year: ' + sourceYear(point.source_time));
    const p = byId(current?.panels, point.id, 'site_waypoint_id');
    const circuits = matchingCircuits(point.id);
    const net = networkNames(point.id);
    line(display, 'Supplying circuit(s): ' + (circuits.length ? circuits.map(c =>
      lookupLabel(c.panel_waypoint_id) + ' / ' + c.circuit_code).join('; ') : 'Not recorded / unreviewed'));
    line(display, 'Actual network(s): ' + (net.length ? net.join(', ') : 'Not recorded / unreviewed'));
    if (p || /panel/i.test(point.type || '')) {
      line(display, 'Panel owner: ' + (p?.owner_code || 'UNKNOWN') + ' · Meter ID: ' + textValue(p?.meter_identifier));
      const own = (current.circuits || []).filter(c => Number(c.panel_waypoint_id) === Number(point.id));
      line(display, 'Breaker / circuit numbers: ' + (own.length ? own.map(c => c.circuit_code +
        ' (' + c.owner_code + ')').join(', ') : 'Not recorded / unreviewed'));
      for (const c of own) {
        const destinations = destinationLabels(c);
        line(display, c.circuit_code + ' supplies ' + (destinations.length ?
          destinations.join(', ') : 'unknown destinations'));
        for (const i of current.instructions.filter(i => Number(i.site_power_circuit_id) === Number(c.site_power_circuit_id))) {
          line(display, i.season_year + ' planned ON: ' + textValue(i.turn_on_instruction)
            + '; planned OFF: ' + textValue(i.turn_off_instruction) + ' (not observed state)');
        }
      }
    }
    const linked = inspectedCables(point.id);
    line(display, 'Reviewed cable identities: ' + linked.length);
    for (const c of linked) {
      const latest = c.tests?.[0];
      line(display, 'Cable #' + c.id + ' · ' + (byId(current.networks, c.network_id, 'site_network_id')?.network_code ||
        c.spare || 'network unreviewed') + ' · LinkIQ raw result ' +
        textValue(latest?.test_status_code) + ' · ' + textValue(latest?.tested_at_local) +
        ' · measured speed not established');
    }
    const btn = document.createElement('button');
    btn.type = 'button'; btn.textContent = 'View circuits and tests';
    btn.addEventListener('click', () => showWaypoint(point.id));
    append(display, btn);
    return display;
  }
  function showWaypoint(id) {
    if (!current) return;
    const w = byId(current.waypoints, id);
    if (!w) return;
    selection = Number(id);
    selectedTrack = null;
    inspection.open = true;
    body.replaceChildren();
    heading(body, w.label + ' · ' + w.type);
    if (lastEditMessage) line(body, lastEditMessage);
    const panel = byId(current.panels, id, 'site_waypoint_id');
    const powerLink = append(body, document.createElement('a'));
    powerLink.href = '/fieldwiring/circuits?waypoint=' + encodeURIComponent(id);
    powerLink.textContent = 'View or maintain panel circuits in FieldWiring';

    const ownCircuits = (current.circuits || []).filter(c => Number(c.panel_waypoint_id) === Number(id));
    const supplies = matchingCircuits(id);
    line(body, 'Recorded panel owner: ' + (panel?.owner_code || 'UNKNOWN — unreviewed'));
    if (panel || /panel/i.test(w.type || '')) line(body, 'Meter ID: ' + textValue(panel?.meter_identifier));
    const aliases = (current.aliases || []).filter(a => Number(a.waypoint_id) === Number(id));
    line(body, 'Reviewed names / aliases: ' + (aliases.length ?
      aliases.map(a => a.label).join('; ') : 'No alternate names reviewed'));
    heading(body, 'Power and switching');
    if(panel) line(body,'Panel supply plan: show '+panel.show_desired_state+'; off-season '+panel.restoration_desired_state);
    line(body,'Recorded sources may be incomplete. Planned OFF does not prove absence of voltage. Open FieldWiring for upstream isolation and dated field/utility evidence.');

    if (ownCircuits.length) for (const c of ownCircuits) {
      const dests = destinationLabels(c);
      line(body, 'Circuit ' + c.circuit_code + (c.circuit_label ? ' (' + c.circuit_label + ')' : '')
        + ' · owner ' + c.owner_code + ' · breaker '
        + textValue(c.breaker_rating_amps) + ' A → '
        + (dests.length ? dests.join(', ') : 'Destinations unreviewed'));
      for (const i of current.instructions.filter(i => Number(i.site_power_circuit_id) === Number(c.site_power_circuit_id))) {
        line(body, i.season_year + ' planned ON: ' + textValue(i.turn_on_instruction)
          + ' | planned OFF: ' + textValue(i.turn_off_instruction) + ' (not observed state)');
      }
    }
    if (supplies.length) for (const c of supplies)
      line(body, 'Supplied by ' + lookupLabel(c.panel_waypoint_id)
        + ' / circuit ' + c.circuit_code + ' · ownership ' + c.owner_code);
    if (!ownCircuits.length && !supplies.length)
      line(body, 'Panel, breaker and supplying circuit: Not recorded / unreviewed');
    heading(body, 'Networks confirmed by reviewed physical routes');
    const net = networkNames(id);
    line(body, net.length ? net.join(', ') : 'Not recorded / unreviewed (GPX track name is not assignment)');
    heading(body, 'Physical cables and LinkIQ tests');
    const cables = inspectedCables(id);
    if (!cables.length) line(body, 'No reviewed physical cable identity associated with this waypoint');
    for (const c of cables) {
      const network = byId(current.networks, c.network_id, 'site_network_id');
      line(body, 'Cable #' + c.id + ': ' + lookupLabel(c.endpoint_a) + ' → '
        + lookupLabel(c.endpoint_b) + ' · ' + (network?.network_code || c.spare || 'network not assigned')
        + ' · status ' + c.lifecycle);
      if (!c.tests.length) line(body, 'LinkIQ test: Not associated / unreviewed');
      for (const test of c.tests) {
        line(body, 'Test ' + test.uuid + ' · ' + textValue(test.tested_at_local)
          + ' · length ' + textValue(test.length_ft) + ' ft · raw result code '
          + textValue(test.test_status_code) + ' · standard ' + textValue(test.test_standard)
          + ' · measured speed NOT ESTABLISHED');
      }
    }
    const provenance = append(body, document.createElement('details'));
    const provSummary = append(provenance, document.createElement('summary'));
    provSummary.textContent = 'Original source metadata / provenance';
    line(provenance, 'GPX label: ' + textValue(w.source_label) + ' · source year: ' + sourceYear(w.source_time));
    line(provenance, 'Source time: ' + textValue(w.source_time)
      + ' · last reviewed: ' + textValue(w.verified_at));
    line(provenance, 'Description: ' + textValue(w.source_description));
    line(provenance, 'Comment: ' + textValue(w.source_comment));
    line(provenance, 'Accepted GPX SHA256: ' + (current.sources?.gpx?.sha256 || 'not accepted'));
    line(provenance, 'Latest staged GPX SHA256: ' + (current.sources?.gpx_latest_staged?.sha256 || 'not staged'));
    line(provenance, 'LinkIQ evidence SHA256: ' + (current.sources?.flw?.sha256 || 'not recorded'));
    line(provenance, 'Unreconciled LinkIQ test UUIDs: ' + current.unresolved_linkiq_tests);
    line(body, 'Reference DB revision ' + current.revision
      + ' · operational instructions are NOT proof of electrical state.');
    if (false && (current.permissions.identity || current.permissions.operations)) {
      // This map is a consumer. Never expose protected reference mutation here.
      // Keep the legacy forms uncalled until moved to #230's dedicated editor.
      const edits = append(body, document.createElement('div'));
      heading(edits, 'Authorized maintenance · server checked');
      if (current.permissions.identity) {
        action(edits, 'Manager: name, type and WGS84 position', 'manager_update_waypoint', form => {
          const label = field(form, 'ExpertGPS Label on Map', 'label', w.label);
          const kind = field(form, 'Source waypoint type', 'type', w.type);
          const latitude = field(form, 'Latitude', 'latitude', w.geometry.coordinates[1], 'number');
          latitude.step = 'any';
          const longitude = field(form, 'Longitude', 'longitude', w.geometry.coordinates[0], 'number');
          longitude.step = 'any';
          return () => ({waypoint_id:id,label:label.value,type:kind.value,
            latitude:latitude.value, longitude:longitude.value});
        });
        if (/panel/i.test(w.type || '')) action(edits, 'Manager: panel ownership (explicit)', 'manager_set_panel_owner', form => {
          const owner = choice(form, 'Owner', 'owner_code', [['UNKNOWN','Unconfirmed'],['MSB','MSB'],['CITY','City']]);
          owner.value = panel?.owner_code || 'UNKNOWN';
          return () => ({waypoint_id:id,owner_code:owner.value});
        });
        for (const c of ownCircuits) {
          action(edits, 'Manager: owner for circuit ' + c.circuit_code, 'manager_set_circuit_owner', form => {
            const owner = choice(form,'Circuit owner','owner_code',
              [['UNKNOWN','Unconfirmed'],['MSB','MSB'],['CITY','City']]);
            owner.value = c.owner_code;
            return () => ({circuit_id:c.site_power_circuit_id,owner_code:owner.value});
          });
        }
        action(edits, 'Manager: create maintained network designation', 'manager_add_network', form => {
          const code = field(form, 'Network designation (verified)', 'network_code');
          const kind = choice(form, 'Network kind', 'network_kind',
            [['LOR','LOR'],['IP','IP / Ethernet'],['OTHER','Other']]);
          return () => ({network_code:code.value,network_kind:kind.value});
        });
        action(edits, 'Manager: accept an alternate historical waypoint label', 'manager_add_alias', form => {
          line(form, 'An alias is for the SAME physical waypoint. Do not merge similarly named but different locations.');
          const alias = field(form, 'Verified historical alias (for LinkIQ/GPX name reconciliation)', 'alias_text');
          const source = field(form, 'Alias evidence source', 'alias_source', 'FIELD_REVIEW');
          return () => ({waypoint_id:id, alias_text:alias.value, alias_source:source.value});
        });
        for (const cable of cables.filter(c => !['REPLACED','DESTROYED','ABANDONED','RETIRED'].includes(c.lifecycle))) {
          action(edits, 'Manager: retire / replace cable #' + cable.id, 'manager_retire_cable', form => {
            const status = choice(form, 'Reviewed cable lifecycle', 'lifecycle_status',
              [['REPLACED','Replaced'],['DESTROYED','Destroyed'],['ABANDONED','Abandoned'],['RETIRED','Retired']]);
            const date = field(form, 'Verified date (blank = command date)', 'retired_at', '', 'date');
            return () => ({site_cable_id:cable.id,lifecycle_status:status.value,retired_at:date.value});
          });
        }
        // A physical cable is a separately reviewed asset, NOT each LinkIQ UUID
        // and NOT every GPX line. Parallel cables get distinct generated IDs.
        if (current.waypoints.length > 1) action(
          edits, 'Manager: create a reviewed physical cable from this waypoint',
          'manager_create_cable', form => {
            line(form, 'Confirm the physical endpoints from field evidence. No cable is inferred from proximity or test labels.');
            const destination = choice(form, 'Other existing endpoint', 'endpoint_b_waypoint_id',
              current.waypoints.filter(p => Number(p.id) !== Number(id))
                .map(p => [p.id, p.label]));
            const network = choice(form, 'Reviewed network (or SPARE designation below)',
              'network_id', [['','Unassigned / use SPARE'], ...current.networks.map(n =>
                [n.site_network_id,n.network_code])]);
            const spare = field(form, 'Explicit SPARE designation (otherwise blank)', 'spare_designation');
            const lifecycle = choice(form, 'Reviewed lifecycle', 'lifecycle_status',
              [['CURRENT','Current'],['FAILED','Failed'],['REPAIRED','Repaired']]);
            return () => ({
              endpoint_a_waypoint_id:id, endpoint_b_waypoint_id:Number(destination.value),
              network_id:network.value ? Number(network.value) : null,
              spare_designation:spare.value.trim() || null, lifecycle_status:lifecycle.value
            });
          }
        );
        // The user must choose BOTH an immutable UUID and a previously reviewed
        // physical cable. Reimport/retest never creates the latter automatically.
        const eligible = current.cables.filter(c =>
          Number(c.endpoint_a) === Number(id) || Number(c.endpoint_b) === Number(id));
        const reviewable = (current.linkiq_review || []).filter(t => t.source_sha256);
        if (eligible.length && reviewable.length) action(
          edits, 'Manager: review or correct a LinkIQ UUID/cable relationship',
          'manager_link_test', form => {
            line(form, 'Compare the original tester name, latest corrected LinkWare label, endpoints and saved test evidence. Selection is NOT automatic acceptance.');
            const test = choice(form, 'Unresolved LinkIQ test UUID', 'test_uuid',
              reviewable.map(t => [t.test_uuid,
                (t.preferred_display_name || 'No reviewed display label') +
                ' · tester: ' + (t.tester_original_name || 'unknown') +
                ' · ' + t.test_uuid +
                (t.identity_review_status === 'REVIEWED' ?
                  ' · reviewed #' + textValue(t.physical_site_cable_id) : ' · needs review')]));
            const cable = choice(form, 'Reviewed physical cable', 'site_cable_id',
              eligible.map(c => [c.id,
                '#' + c.id + ' ' + lookupLabel(c.endpoint_a) +
                ' → ' + lookupLabel(c.endpoint_b) +
                ' · ' + (byId(current.networks,c.network_id,'site_network_id')?.network_code ||
                  c.spare || 'designation unknown')]));
            const evidencePreview = line(form, '');
            const updateEvidence = () => {
              const t = reviewable.find(entry => entry.test_uuid === test.value);
              evidencePreview.textContent = t ?
                'Test ' + t.test_uuid + ' · ' + textValue(t.tested_at_local) +
                ' · length ' + textValue(t.length_ft) + ' ft · raw result ' +
                textValue(t.test_status_code) + ' · standard ' +
                textValue(t.test_standard) + ' (NOT measured speed)' +
                ' · prior cable binding ' +
                textValue(t.physical_site_cable_id) + ' · intake review: ' +
                textValue(t.intake_status) : 'Select one preserved UUID';
            };
            test.addEventListener('change', updateEvidence);
            updateEvidence();
            return () => {
              const selected = reviewable.find(entry => entry.test_uuid === test.value);
              if (!selected) throw new Error('Select a source-proven LinkIQ UUID');
              return {
                test_uuid:selected.test_uuid,
                source_sha256:selected.source_sha256,
                expected_cable_id:selected.physical_site_cable_id,
                site_cable_id:Number(cable.value)
              };
            };
          }
        );
      }
      if (current.permissions.operations) {
        if (/panel/i.test(w.type || '')) {
          action(edits, 'Production crew: meter identifier', 'crew_set_meter', form => {
            const meter = field(form, 'Verified meter ID (leave blank if unknown)', 'meter_identifier', panel?.meter_identifier);
            return () => ({waypoint_id:id,meter_identifier:meter.value});
          });
          action(edits, 'Production crew: create / revise circuit', 'crew_upsert_circuit', form => {
            const code = field(form, 'Breaker/circuit number', 'circuit_code');
            const label = field(form, 'Circuit description', 'circuit_label');
            const amps = field(form, 'Breaker rating amps (optional)', 'breaker_rating_amps', '', 'number');
            return () => ({panel_waypoint_id:id,circuit_code:code.value,
              circuit_label:label.value,breaker_rating_amps:amps.value});
          });
          for (const c of ownCircuits) {
            action(edits, 'Production crew: ' + c.circuit_code + ' season ON / OFF', 'crew_set_switching', form => {
              const year = field(form, 'Season year', 'season_year', new Date().getFullYear(), 'number');
              const on = field(form, 'Instructions to turn ON', 'turn_on_instruction');
              const off = field(form, 'Instructions to turn OFF', 'turn_off_instruction');
              return () => ({circuit_id:c.site_power_circuit_id,season_year:Number(year.value),
                turn_on_instruction:on.value,turn_off_instruction:off.value});
            });
          }
        } else if (current.circuits.length) {
          action(edits, 'Production crew: link waypoint to circuit', 'crew_link_destination', form => {
            const circuit = choice(form,'Existing panel / circuit','circuit_id',
              current.circuits.map(c=>[c.site_power_circuit_id,
                lookupLabel(c.panel_waypoint_id) + ' / ' + c.circuit_code]));
            return () => ({waypoint_id:id,circuit_id:Number(circuit.value)});
          });
        }
        for (const circuit of supplies) {
          action(edits, 'Production crew: unlink ' + w.label + ' from ' +
            lookupLabel(circuit.panel_waypoint_id) + ' / ' + circuit.circuit_code,
            'crew_unlink_destination', form => {
              line(form, 'Remove only this reviewed circuit-to-waypoint relationship. Equipment and source history remain.');
              return () => ({waypoint_id:id,circuit_id:circuit.site_power_circuit_id});
            });
        }
        for (const circuit of ownCircuits) {
          for (const instruction of current.instructions.filter(i =>
            Number(i.site_power_circuit_id) === Number(circuit.site_power_circuit_id))) {
            action(edits, 'Production crew: remove ' + instruction.season_year +
              ' switching plan for ' + circuit.circuit_code,
              'crew_clear_switching', form => {
                line(form, 'Removes the PLANNED instructions, not any observed energized state.');
                return () => ({circuit_id:circuit.site_power_circuit_id,
                  season_year:instruction.season_year});
              });
          }
        }

      }
    }
  }
  function showTrack(id) {
    // Tracks and permanent waypoints share the existing #230 inspection panel.
    // Historical GPX names are retained independently in ops source evidence.
    if (!current) return;
    const track = byId(current.tracks, id);
    if (!track) return;
    selectedTrack = Number(id);
    selection = null;
    inspection.open = true;
    body.replaceChildren();
    heading(body, track.label || 'Unnamed GPX track');
    if (lastEditMessage) line(body, lastEditMessage);
    line(body, 'GPX track · Type: ' + textValue(track.type)
      + ' · Lifecycle: ' + textValue(track.lifecycle));
    line(body, 'Source track ordinal: ' + textValue(track.source_ordinal)
      + ' · SHA256 ' + textValue(track.source_sha256));
    line(body, 'Original imported track name: ' + textValue(track.source_label));
    line(body, 'Last reviewed: ' + textValue(track.verified_at)
      + ' · by ' + textValue(track.verified_by));
    line(body, 'Original description (historical, NOT verified cable count): '
      + textValue(track.description));
    line(body, 'Name changes do NOT change track geometry, endpoint connections,'
      + ' cable inventory or source GPX. Those remain separately reviewed facts.');
    if (current.permissions?.identity) {
      action(body, 'Manager: correct this GPX track label', 'manager_update_track_label', form => {
        const label = field(form, 'Reviewed route name', 'track_label', track.label);
        return () => ({track_id:Number(track.id),
          expected_track_label:track.label,track_label:label.value});
      });
    }
  }

  function markerFeature(feature, layerName, marker) {
    marker._searchFeature = feature;
    marker._networkLayer = layerName;
    marker.addTo(layers[layerName]);
    return marker;
  }
  function renderDb(snapshot) {
    // Remove only GPX/reference features. #88 movements and latest assets stay.
    for (const [layerName, group] of Object.entries(layers)) {
      if (['containers','displays'].includes(layerName)) continue;
      const stale = [];
      group.eachLayer(marker => { if (marker._searchFeature || marker._gisCasing) stale.push(marker); });
      for (const marker of stale) group.removeLayer(marker);
    }
    names.clear();
    for (const w of snapshot.waypoints) {
      names.set(Number(w.id), w.label);
      const xy = [w.geometry.coordinates[1], w.geometry.coordinates[0]];
      const layerName = w.type === 'Stage' ? 'stages' :
                        w.type === 'Drop Point' ? 'drops' : 'refs';
      const icon = existingWaypointStyles.get(w.source_label) || existingWaypointStyles.get(w.label);
      const marker = window.msbReferenceSymbols?.has(w.type)
        ? window.msbReferenceSymbols.marker(xy, w.type)
        : icon ? L.marker(xy, {icon})
        : L.circleMarker(xy, {radius:5,color:'#444',weight:1,fillOpacity:.8});
      markerFeature({type:'Feature',geometry:w.geometry,
        properties:{id:'wp:'+w.id,name:w.label,type:w.type}},layerName,marker);
      marker.bindPopup(waypointPopup(w));
      marker.on('popupopen', () => showWaypoint(w.id));
    }
    for (const t of snapshot.tracks) {
      if (!t.geometry) continue; // Retain incomplete GPX trace in the DB, no invented line.
      const cls = /^(NET|HV|PRI)(?=\W|$)/i.exec(t.label || '')?.[1]?.toUpperCase() ||
        ({'High Voltage':'HV','Network':'NET','Primary':'PRI'}[t.type] || 'Other');
      // ExpertGPS styling is source presentation, not verified electrical topology.
      const source = t.style || {}, style = {...trackStyles[cls], opacity: 0.85};
      if (/^[0-9a-f]{6}$/i.test(source.color || '')) style.color = '#' + source.color;
      if (source.opacity !== '' && Number.isFinite(Number(source.opacity)) && Number(source.opacity) >= 0 && Number(source.opacity) <= 1)
        style.opacity = Number(source.opacity);
      if (Number.isFinite(Number(source.width)) && Number(source.width) > 0)
        style.weight = Math.min(40, Number(source.width) * 96 / 25.4);
      const patterns = {Solid:null, Dash:'8 5', Dot:'2 5', DashDot:'8 4 2 4'};
      if (Object.hasOwn(patterns, source.pattern)) style.dashArray = patterns[source.pattern];
      const segmentList = t.geometry.type === 'LineString' ? [t.geometry.coordinates] :
                          t.geometry.coordinates || [];
      const feature = {type:'Feature',geometry:t.geometry,
        properties:{id:'track:'+t.id,name:t.label,type:t.type,source_description:t.description}};
      for (const coords of segmentList) {
        if (!coords.length) continue;
        if (coords.length > 1 && source.cased === 'true') {
          const casing = L.polyline(coords.map(x=>[x[1],x[0]]),
            {...style,color:'#ffffff',weight:(style.weight || 3)+3,interactive:false});
          casing._gisCasing = true;
          casing.addTo(layers[cls]);
        }
        const marker = coords.length === 1 ?
          L.circleMarker([coords[0][1],coords[0][0]],{radius:4,color:style.color}) :
          L.polyline(coords.map(x=>[x[1],x[0]]),style);
        markerFeature(feature,cls,marker);
        const popup = document.createElement('div');
        heading(popup,t.label);
        // textContent keeps imported labels from being interpreted as HTML.
        const label = document.createElement('span'); label.textContent = t.label;
        marker.bindTooltip(label,{permanent:true,direction:'center',className:'gis-track-label'});
        line(popup, 'GPX source track · ' + t.type + ' · lifecycle ' + t.lifecycle);
        line(popup, 'Original GPS name: ' + textValue(t.source_label));
        line(popup, 'Source description (unverified): ' + textValue(t.description));
        line(popup, 'Network/circuit assignment requires separate reviewed records');
        const review = document.createElement('button');
        review.type = 'button';
        review.textContent = 'Inspect track';
        review.addEventListener('click', () => showTrack(t.id));
        popup.appendChild(review);
        marker.bindPopup(popup);
        marker.on('popupopen', () => showTrack(t.id));
      }
    }
    for (const route of snapshot.routes) {
      const coords = route.geometry?.coordinates || [];
      if (coords.length < 2) continue;
      const marker = L.polyline(coords.map(x=>[x[1],x[0]]),{
        color:'#23666b',weight:4,opacity:0.9,dashArray:'5 5'});
      const feature = {type:'Feature',geometry:route.geometry,
        properties:{id:'route:'+route.id,name:route.label,type:'Reviewed shared route'}};
      markerFeature(feature,'Other',marker);
      const p = document.createElement('div');
      heading(p,route.label);
      line(p, 'Reviewed shared route; not a one-cable assumption');
      line(p, lookupLabel(route.endpoint_a) + ' → ' + lookupLabel(route.endpoint_b));
      line(p, 'Physical cables on reviewed segment: ' + (route.cable_ids?.length || 0));
      for (const cableId of route.cable_ids || []) {
        const cable = byId(snapshot.cables, cableId);
        if (!cable) {line(p, 'Cable #' + cableId + ' pending physical review');continue;}
        line(p, 'Cable #' + cableId + ': ' + (byId(snapshot.networks,cable.network_id,'site_network_id')?.network_code || cable.spare || 'unknown network'));
        for (const test of cable.tests) line(p, 'LinkIQ ' + test.uuid + ' · raw result ' + textValue(test.test_status_code)
          + ' · length ' + textValue(test.length_ft) + ' ft · speed NOT established');
      }
      marker.bindPopup(p);
    }
    mapSearch.reindexMapReferences();
    document.getElementById('counts').textContent =
      snapshot.waypoints.length + ' maintained waypoints · ' + snapshot.tracks.length
      + ' GPX traces · ' + snapshot.routes.length + ' reviewed shared routes';
  }
  function renderNetworks(snapshot, offline = false) {
    const options = document.getElementById('network-options');
    const details = document.getElementById('network-details');
    const statusLine = document.getElementById('network-status');
    options.replaceChildren();
    details.replaceChildren();
    const selected = new Set();
    const entries = [];
    function show() {
      details.replaceChildren();
      const assigned = snapshot.memberships.filter(m => selected.has(Number(m.site_network_id)));
      const matchedCables = snapshot.cables.filter(c => selected.has(Number(c.network_id)));
      const markerList = [];
      for (const m of assigned) {
        const id = 'wp:' + m.site_waypoint_id;
        for (const layer of Object.values(layers)) layer.eachLayer(marker => {
          if (marker._searchFeature?.properties?.id === id) markerList.push(marker);
        });
      }
      if (markerList.length) mapSearch.select({name:'Maintained network(s)',
        kind:'Network',layer:'NET',markers:markerList,
        selectedNetworks:[...selected].map(id=>byId(snapshot.networks,id,'site_network_id')?.network_code).filter(Boolean),
        preserveNetworkDetails:true,association:'Explicit reviewed memberships'});
      line(details, assigned.length + ' reviewed waypoint memberships · '
        + matchedCables.length + ' reviewed physical cables');
      for (const c of matchedCables) {
        line(details, 'Cable #' + c.id + ': ' + lookupLabel(c.endpoint_a)
          + ' → ' + lookupLabel(c.endpoint_b) + ' · ' + c.tests.length + ' linked LinkIQ tests');
        for (const test of c.tests)
          line(details, 'Test ' + test.uuid + ' · raw result ' + textValue(test.test_status_code)
            + ' · ' + textValue(test.test_standard) + ' standard · '
            + textValue(test.length_ft) + ' ft · measured speed not established');
      }
      if (!matchedCables.length)
        line(details,'Physical cable/test mapping is not reviewed; no automatic GPX route inference');
      details.parentElement.open = true;
    }
    for (const n of snapshot.networks) {
      const label = document.createElement('label');
      label.style.display = 'block';
      const cb = document.createElement('input');
      cb.type='checkbox';cb.value=String(n.site_network_id);
      cb.addEventListener('change', () => {
        if(cb.checked) selected.add(n.site_network_id); else selected.delete(n.site_network_id);
        show();
      });
      label.appendChild(cb);
      const count = snapshot.memberships.filter(m=>Number(m.site_network_id)===Number(n.site_network_id)).length;
      label.appendChild(document.createTextNode(n.network_code + ' · ' + count + ' reviewed waypoint(s)'));
      options.appendChild(label);
      const ids = new Set(snapshot.memberships.filter(m=>Number(m.site_network_id)===Number(n.site_network_id))
        .map(m=>'wp:'+m.site_waypoint_id));
      const markers = [];
      for (const layer of Object.values(layers)) layer.eachLayer(marker => {
        if(ids.has(marker._searchFeature?.properties?.id)) markers.push(marker);
      });
      entries.push({sourceKind:'site',name:n.network_code,kind:'Maintained network',
        layer:'NET',markers,terms:n.network_code.toLowerCase(),preserveNetworkDetails:true,
        networkSearchAliases:[n.network_code],association:'Reviewed waypoints, not inferred tracks',
        onSelect:()=>{selected.clear();selected.add(n.site_network_id);
          options.querySelectorAll('input').forEach(c=>c.checked=c.value===String(n.site_network_id));show();}});
    }
    mapSearch.replaceSiteReferences(entries);
    statusLine.textContent = (offline ? 'OFFLINE SAVED PostgreSQL network assignments · ' : 'LIVE PostgreSQL network assignments · ') + snapshot.networks.length
      + ' designations · ' + snapshot.unresolved_linkiq_tests + ' unresolved LinkIQ test UUIDs';
    if (!snapshot.networks.length)
      options.textContent='No reviewed network designations yet. GPX NET names are historical geometry, not membership.';
  }
  async function refresh() {
    const response = await fetch('../api/setup/locate/references',{cache:'no-store',credentials:'same-origin'});
    if (!response.ok) throw new Error('HTTP '+response.status);
    const snapshot = await response.json();
    if (snapshot.format_version !== 1 || snapshot.data_mode !== 'postgres')
      throw new Error('Unknown maintained reference format');
    const required = window.MSBRequiredGpxSha;
    if (required && snapshot.sources?.gpx?.sha256 !== required)
      throw new Error("Required GPX " + required + " does not match database source " + snapshot.sources?.gpx?.sha256);
    current = snapshot;
    const accepted = snapshot.sources?.gpx?.sha256 || '';
    const staged = snapshot.sources?.gpx_latest_staged?.sha256 || '';
    const drift = !!staged && staged !== accepted;
    status.style.color = drift ? '#923b15' : '#145a38';
    status.textContent = 'LIVE PostgreSQL GIS · revision ' + snapshot.revision
      + ' · accepted GPX ' + (accepted || 'NOT ACCEPTED').slice(0,12)
      + ' · latest FLW evidence ' + (snapshot.sources?.flw?.sha256 || 'not loaded').slice(0,12)
      + (drift ? ' · NEW GPX STAGED / NOT ACCEPTED — reconcile before export' : '');
    renderDb(snapshot);
    renderNetworks(snapshot);
    const sourceIdentity = document.getElementById('gis-source-identity');
    if (sourceIdentity) sourceIdentity.textContent = 'Database GPX SHA256 ' + accepted
      + ' · ' + snapshot.waypoints.length + ' waypoints · ' + snapshot.tracks.length + ' tracks';
    return snapshot;
  }
  let initialWaypointFocus=false;
  function focusRequestedWaypoint() {
    if(initialWaypointFocus) return;
    initialWaypointFocus=true;
    const id=new URLSearchParams(window.location.search).get('waypoint_id');
    if(id && /^[1-9][0-9]*$/.test(id)) mapSearch.focusWaypoint(id);
  }
  window.siteReferenceReady = refresh().then(snapshot=>{focusRequestedWaypoint();return snapshot;}).catch(async error => {
    if (window.MSBRequiredGpxSha) {
      // Exact-source acceptance cannot fall back to older static/offline data.
      status.style.color = '#923b15';
      status.textContent = 'GIS REVIEW BLOCKED — required GPX ' + window.MSBRequiredGpxSha + ' · ' + error.message;
      document.getElementById('network-status').textContent = 'Current GIS unavailable; historical fallback disabled for this review.';
      return null;
    }
    // A successfully prepared, versioned offline package can show dated
    // reference relationships. Offline grants MUST NOT expose editing.
    let saved = null;
    try { saved = await window.MSBLocateOffline?.readReferences(); }
    catch (_) { saved = null; }
    if (saved && saved.format_version === 1 && saved.data_mode === 'postgres') {
      saved.permissions = {identity:false,operations:false};
      current = saved;
      status.style.color = '#923b15';
      status.textContent = 'OFFLINE SAVED PostgreSQL GIS · revision ' + saved.revision
        + ' · downloaded ' + new Date(saved._offlinePreparedAt).toLocaleString()
        + ' · NOT CURRENT · editing disabled · (' + error.message + ')';
      renderDb(saved);
      renderNetworks(saved, true);
      return saved;
    }
    status.style.color='#923b15';
    status.textContent = 'STATIC GPX SOURCE ONLY — maintained PostgreSQL references unavailable ('
      + error.message + '). Circuits/networks/tests not current; editing disabled.';
    return null;
  });
})();
