/* #171/#230: maintained PostGIS source for the EXISTING /setup/locate/ map.
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
    .map(d => byId(current.circuits, d.site_power_circuit_id)).filter(Boolean);
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
      const fields = build();
      fields.evidence_notes = evidence.value.trim();
      if (!fields.evidence_notes) return;
      save.disabled = true;
      try {
        const response = await fetch('..' + '/api/setup/locate/references/command', {
          method: 'POST', credentials: 'same-origin',
          headers: {'Content-Type':'application/json', 'X-MSB-Setup-Command':'1'},
          cache: 'no-store',
          body: JSON.stringify({command, expected_revision:current.revision, fields})
        });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Command rejected');
        lastEditMessage = 'Saved as revision ' + result.revision + '; audit entry recorded.';
        await refresh();
        if (selection !== null) showWaypoint(selection);
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
    if (p) line(display, 'Panel owner: ' + p.owner_code + ' · Meter ID: ' + textValue(p.meter_identifier));
    line(display, 'Reviewed cable identities: ' + inspectedCables(point.id).length);
    const btn = document.createElement('button');
    btn.type = 'button'; btn.textContent = 'View circuits, tests / edit';
    btn.addEventListener('click', () => showWaypoint(point.id));
    append(display, btn);
    return display;
  }
  function showWaypoint(id) {
    if (!current) return;
    const w = byId(current.waypoints, id);
    if (!w) return;
    selection = Number(id);
    inspection.open = true;
    body.replaceChildren();
    heading(body, w.label + ' · ' + w.type);
    if (lastEditMessage) line(body, lastEditMessage);
    const panel = byId(current.panels, id, 'site_waypoint_id');
    const ownCircuits = (current.circuits || []).filter(c => Number(c.panel_waypoint_id) === Number(id));
    const supplies = matchingCircuits(id);
    line(body, 'Verified panel owner: ' + (panel?.owner_code || 'UNKNOWN — unreviewed'));
    if (panel || /panel/i.test(w.type || '')) line(body, 'Meter ID: ' + textValue(panel?.meter_identifier));
    heading(body, 'Power and switching');
    if (ownCircuits.length) for (const c of ownCircuits) {
      const dests = current.destinations.filter(d => Number(d.site_power_circuit_id) === Number(c.site_power_circuit_id));
      line(body, 'Circuit ' + c.circuit_code + (c.circuit_label ? ' (' + c.circuit_label + ')' : '')
        + ' · owner ' + c.owner_code + ' · breaker '
        + textValue(c.breaker_rating_amps) + ' A → '
        + (dests.length ? dests.map(d => lookupLabel(d.site_waypoint_id)).join(', ') : 'Destinations unreviewed'));
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
    heading(body, 'Actual reviewed network assignments');
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
    line(provenance, 'GPX SHA256: ' + (current.sources?.gpx?.sha256 || 'not recorded'));
    line(provenance, 'FLW SHA256: ' + (current.sources?.flw?.sha256 || 'not recorded'));
    line(provenance, 'Unreconciled LinkIQ test UUIDs: ' + current.unresolved_linkiq_tests);
    line(body, 'Online DB revision ' + current.revision
      + ' · operational instructions are NOT proof of electrical state.');
    if (current.permissions.identity || current.permissions.operations) {
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
            if (current.permissions.identity)
              action(edits, 'Manager: owner for circuit ' + c.circuit_code, 'manager_set_circuit_owner', form => {
                const owner = choice(form,'Circuit owner','owner_code',
                  [['UNKNOWN','Unconfirmed'],['MSB','MSB'],['CITY','City']]);
                owner.value = c.owner_code;
                return () => ({circuit_id:c.site_power_circuit_id,owner_code:owner.value});
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
        if (current.networks.length) action(edits, 'Production crew: assign maintained network', 'crew_assign_network', form => {
          const net = choice(form, 'Known network', 'network_id',
            current.networks.map(n=>[n.site_network_id,n.network_code]));
          return () => ({waypoint_id:id,network_id:Number(net.value)});
        });
      }
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
      group.eachLayer(marker => { if (marker._searchFeature) stale.push(marker); });
      for (const marker of stale) group.removeLayer(marker);
    }
    names.clear();
    for (const w of snapshot.waypoints) {
      names.set(Number(w.id), w.label);
      const xy = [w.geometry.coordinates[1], w.geometry.coordinates[0]];
      const layerName = w.type === 'Stage' ? 'stages' :
                        w.type === 'Drop Point' ? 'drops' : 'refs';
      const icon = existingWaypointStyles.get(w.source_label) || existingWaypointStyles.get(w.label);
      const marker = icon ? L.marker(xy, {icon}) :
        L.circleMarker(xy, {radius:5,color:'#444',weight:1,fillOpacity:.8});
      markerFeature({type:'Feature',geometry:w.geometry,
        properties:{id:'wp:'+w.id,name:w.label,type:w.type}},layerName,marker);
      marker.bindPopup(waypointPopup(w));
      marker.on('popupopen', () => showWaypoint(w.id));
    }
    for (const t of snapshot.tracks) {
      if (!t.geometry) continue; // Retain incomplete GPX trace in the DB, no invented line.
      const cls = /^(NET|HV|PRI)(?=\W|$)/i.exec(t.label || '')?.[1]?.toUpperCase() || 'Other';
      const segmentList = t.geometry.type === 'LineString' ? [t.geometry.coordinates] :
                          t.geometry.coordinates || [];
      const feature = {type:'Feature',geometry:t.geometry,
        properties:{id:'track:'+t.id,name:t.label,type:t.type,source_description:t.description}};
      for (const coords of segmentList) {
        if (!coords.length) continue;
        const marker = coords.length === 1 ?
          L.circleMarker([coords[0][1],coords[0][0]],{radius:4,color:trackStyles[cls].color}) :
          L.polyline(coords.map(x=>[x[1],x[0]]),{...trackStyles[cls],opacity:0.85});
        markerFeature(feature,cls,marker);
        const popup = document.createElement('div');
        heading(popup,t.label);
        line(popup, 'GPX source track · ' + t.type + ' · lifecycle ' + t.lifecycle);
        line(popup, 'Historical note: ' + textValue(t.description));
        line(popup, 'Network/circuit assignment requires separate reviewed records');
        marker.bindPopup(popup);
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
      marker.bindPopup(p);
    }
    mapSearch.reindexMapReferences();
    document.getElementById('counts').textContent =
      snapshot.waypoints.length + ' maintained waypoints · ' + snapshot.tracks.length
      + ' GPX traces · ' + snapshot.routes.length + ' reviewed shared routes';
  }
  function renderNetworks(snapshot) {
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
    statusLine.textContent = 'LIVE PostgreSQL network assignments · ' + snapshot.networks.length
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
    current = snapshot;
    status.style.color = '#145a38';
    status.textContent = 'LIVE PostgreSQL GIS · revision ' + snapshot.revision
      + ' · GPX ' + (snapshot.sources?.gpx?.sha256 || 'not loaded').slice(0,12)
      + ' · FLW ' + (snapshot.sources?.flw?.sha256 || 'not loaded').slice(0,12);
    renderDb(snapshot);
    renderNetworks(snapshot);
    return snapshot;
  }
  window.siteReferenceReady = refresh().catch(error => {
    status.style.color='#923b15';
    status.textContent = 'STATIC SOURCE SNAPSHOT ONLY — maintained PostgreSQL references unavailable ('
      + error.message + '). Do not treat circuits, networks or tests as current. Editing disabled.';
    return null;
  });
})();
