/* Source-backed network discovery. GPX descriptions never assign network identity. */
(async () => {
  const status = document.getElementById('network-status');
  const details = document.getElementById('network-details');
  const options = document.getElementById('network-options');
  const networkControls = new Map();
  const networkToggle = document.querySelector('[data-layer="NET"]');
  mapSearch.onSelection(entry => {
    // Search and checklist share one selection so checks never describe stale highlights.
    const selected = new Set(entry.selectedNetworks || (entry.networkSearchAliases ? [entry.name] : []));
    for (const [name, control] of networkControls) control.checked = selected.has(name);
    if (selected.size) { networkToggle.checked = true; layers.NET.addTo(map); }
    if (entry.networkSearchAliases || entry.preserveNetworkDetails) return;
    details.replaceChildren();
    details.parentElement.open = false;
  });
  function row(parent, text) {
    const line = document.createElement('div');
    line.textContent = text;
    parent.appendChild(line);
  }
  try {
    const response = await fetch('assets/setup_locate_networks.json', {cache: 'no-store'});
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const source = await response.json();
    if (source.format_version !== 1) throw new Error('Unsupported source format');
    const routes = new Map();
    for (const [layerName, group] of Object.entries(layers)) group.eachLayer(marker => {
      const id = marker._searchFeature?.properties.id;
      if (!id) return;
      if (!routes.has(id)) routes.set(id, []);
      marker._networkLayer = layerName;
      routes.get(id).push(marker);
    });
    const networks = new Map();
    for (const cable of source.cables) {
      if (!networks.has(cable.network)) networks.set(cable.network, []);
      networks.get(cable.network).push(cable);
    }
    const routeNames = new Map(source.mapped_routes.map(r => [r.route_id, r.source_name]));
    const alternativeMarkers = new Set();
    function show(network, cables, routeIds, expand = true) {
      details.replaceChildren();
      details.parentElement.open = expand;
      row(details, `${network} — ${cables.length} LinkIQ test records · ${routeIds.size} candidate GPX routes`);
      row(details, 'GPX geometry is preserved. Shared tracks can carry multiple cables. Route candidates need review; network names alone do not prove continuity.');
      row(details, `${source.source_name} · SHA256 ${source.source_sha256.slice(0, 16)}`);
      for (const cable of cables) {
        const item = document.createElement('details');
        const title = document.createElement('summary');
        title.textContent = `${cable.attributes.Cable_ID} · ${cable.route_ids.length ? 'route candidate: review required' : cable.status === 'ENDPOINT_CONFLICT' ? 'endpoint conflict' : cable.status === 'NETWORK_CONFLICT' ? 'network label conflict' : 'route unresolved'}`;
        item.appendChild(title);
        row(item, `Endpoints: ${cable.attributes.Waypoint_1} → ${cable.attributes.Waypoint_2}`);
        row(item, `Source network: ${cable.attributes.Network}`);
        row(item, `Tester length: ${cable.attributes.Feet ?? 'not recorded'} ft · Name qualifier: ${cable.attributes.Qualifier || 'none'}`);
        row(item, `Test UUID: ${cable.source_id}`);
        if (cable.test) {
          row(item, `Notes: ${cable.test.Notes || 'none'} · Faceplate: ${cable.test.Faceplate || 'none'} · Outlet: ${cable.test.OutletId || 'none'}`);
          row(item, `Raw test time: ${cable.test.TimeSpan} · Raw result code: ${cable.test.TestStatus}`);
        }
        for (const comparison of cable.drawio_matches || []) {
          row(item, `draw.io ${comparison.source_id}: ${comparison.attributes.Waypoint_1} → ${comparison.attributes.Waypoint_2} · ${comparison.status}`);
        }
        // Endpoint navigation remains useful even when no route is reconciled.
        for (const endpoint of cable.endpoints) {
          const point = source.waypoint_lookup[endpoint];
          if (!point || !routes.has(point.id)) continue;
          const button = document.createElement('button');
          button.textContent = `Show ${endpoint}`;
          button.addEventListener('click', () => mapSearch.select({name: endpoint,
            layer: routes.get(point.id)[0]._networkLayer, markers: routes.get(point.id), preserveNetworkDetails: true}));
          item.appendChild(button);
        }
        for (const id of cable.route_ids) {
          const route = source.mapped_routes.find(r => r.route_id === id);
          row(item, `${routeNames.get(id) || id} · whole GPX track ${route.geometry_length_ft} ft (may span multiple cables)`);
          row(item, `GPX installation/source description: ${route.source_properties?.desc || 'not recorded'} · ${route.source_properties?.cmt || ''}`);
        }
        // These buttons reuse the original route selection and never draw a connecting line.
        if (cable.route_ids.length) {
          const button = document.createElement('button');
          button.textContent = 'Show cable route';
          button.addEventListener('click', () => mapSearch.select({name: cable.attributes.Cable_ID,
            kind: 'Cable route', layer: 'NET', markers: cable.route_ids.flatMap(id => routes.get(id) || []),
            association: 'Route candidate — review required', alternativeMarkers, preserveNetworkDetails: true}));
          item.appendChild(button);
        }
        details.appendChild(item);
      }
    }
    options.replaceChildren();
    function highlightChecked() {
      const selected = [...networkControls].filter(([, control]) => control.checked).map(([name]) => name);
      if (!selected.length) { mapSearch.clearSelection(); return; }
      const cables = selected.flatMap(name => networks.get(name));
      const routeIds = new Set(cables.flatMap(c => c.route_ids));
      // Union source markers once; shared trenches must not lose their highlight
      // when one of several checked networks is removed.
      const markers = [...new Set([...routeIds].flatMap(id => routes.get(id) || []))];
      mapSearch.select({name: selected.join(', '), selectedNetworks: selected,
        layer: 'NET', markers, preserveNetworkDetails: true,
        association: `${routeIds.size} candidate routes — review required`,
        // Keep the checklist in place while choosing several networks.
        onSelect: () => show(selected.join(', '), cables, routeIds, false)});
    }
    document.getElementById('network-clear').addEventListener('click', () => mapSearch.clearSelection());
    networkToggle.addEventListener('change', () => {
      // Turning NET off also restores highlights on shared HV source tracks.
      if (!networkToggle.checked && [...networkControls.values()].some(control => control.checked))
        mapSearch.clearSelection();
    });
    for (const [network, cables] of [...networks].sort(([a], [b]) => a.localeCompare(b, undefined, {numeric: true}))) {
      const routeIds = new Set(cables.flatMap(c => c.route_ids));
      const markers = [...routeIds].flatMap(id => routes.get(id) || []);
      const unresolved = cables.filter(c => !c.route_ids.length).length;
      const label = document.createElement('label');
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.value = network;
      checkbox.addEventListener('change', highlightChecked);
      const caption = document.createElement('span');
      caption.textContent = `${network} · ${routeIds.size} candidate routes · ${unresolved} unmatched test records`;
      label.appendChild(checkbox); label.appendChild(caption); options.appendChild(label);
      networkControls.set(network, checkbox);
      const terms = [network, ...cables.flatMap(c => [c.attributes.Network, c.attributes.Cable_ID,
        c.attributes.Waypoint_1, c.attributes.Waypoint_2])].join(' ');
      mapSearch.addReference({name: network, kind: 'Network (LinkIQ)', layer: 'NET',
        markers, terms, alternativeMarkers,
        networkSearchAliases: [network, ...(network === 'AUX-I' ? ['Aux I'] : []), ...new Set(cables.map(c => c.attributes.Network))],
        resultNote: `${routeIds.size} candidate routes · ${unresolved} unresolved cables`,
        association: `${routeIds.size} candidate routes; ${unresolved} cables without matched routes — review required`,
        onSelect: () => show(network, cables, routeIds)});
    }
    if (source.lor_inventory) {
      const inventory = source.lor_inventory;
      mapSearch.addReference({name: 'LOR expected networks / recorded controller programming',
        kind: 'Database snapshot', layer: 'NET', markers: [], terms: 'LOR expected networks controllers UID universe programmed',
        association: 'Assignments do not establish physical cable attachments', preserveNetworkDetails: true,
        onSelect: () => {
          details.replaceChildren(); details.parentElement.open = true;
          row(details, `${inventory.source_name} · validated LOR snapshot import ${inventory.import_run_id} · ${inventory.run_ts}`);
          row(details, 'Expected show assignments; no physical cable attachment inferred. DMX network fields retain their source meaning.');
          for (const [network, value] of Object.entries(inventory.expected_networks)) {
            row(details, `${network}: ${value.props} props, ${value.sub_props} sub-props, ${value.dmx_channels} DMX channel rows · UIDs ${value.uids.join(', ')} · universes ${value.universes.join(', ')}`);
          }
          row(details, 'Recorded controller programming (separate from expected show assignments):');
          for (const controller of inventory.recorded_controllers) {
            row(details, `Controller ${controller.controller_id}: ${controller.lor_network || 'network not recorded'} · UID ${controller.lor_uid_start || 'not recorded'} · count ${controller.lor_uid_count ?? 'not recorded'} · ${controller.programmed_config_verification_state}`);
          }
        }});
    }
    // Schematic devices navigate to GPX anchors only; diagram X/Y never becomes GPS.
    for (const device of source.devices || []) {
      const attrs = device.attributes;
      const markers = routes.get(device.waypoint_id) || [];
      mapSearch.addReference({name: `${attrs.node_id || 'Unlocated'} ${attrs.node_type || 'Infrastructure'}`,
        kind: 'Schematic infrastructure', layer: markers[0]?._networkLayer || 'refs', markers,
        terms: Object.values(attrs).join(' '), preserveNetworkDetails: true,
        association: markers.length ? 'Schematic identity at GPX waypoint; placement needs review' : 'No matched GPX waypoint',
        onSelect: () => {
          details.replaceChildren(); details.parentElement.open = true;
          for (const [key, value] of Object.entries(attrs)) row(details, `${key}: ${value}`);
          row(details, `Schematic connections: ${device.connections.join(', ') || 'none recorded'}`);
        }});
    }
    // Source problems stay inspectable, including records without a network suffix.
    mapSearch.addReference({name: 'LinkIQ reconciliation review', kind: 'Source review', layer: 'NET',
      markers: [], terms: 'LinkIQ unresolved deleted review', association: 'Source records retained',
      preserveNetworkDetails: true, onSelect: () => {
        details.replaceChildren(); details.parentElement.open = true;
        for (const record of source.review_records || []) row(details, `${record.attributes.CableId} · ${record.reason} · ${record.attributes.UUID}`);
        for (const cable of source.drawio_cables || []) {
          if (['ENDPOINT_CONFLICT', 'NETWORK_CONFLICT'].includes(cable.status))
            row(details, `draw.io ${cable.source_id} · ${cable.attributes.Cable_ID} · ${cable.attributes.Waypoint_1} → ${cable.attributes.Waypoint_2} · ${cable.status}`);
        }
      }});
    status.textContent = `Network source loaded: ${source.mapped_routes.length} candidate routes; ${source.unresolved_routes.length} unresolved routes; ${source.legacy_edges.length} legacy schematic edges; ${(source.review_records || []).length} tester records need review or are deleted.`;
  } catch (error) {
    options.textContent = 'Network choices unavailable; refresh the page to retry.';
    status.textContent = `Network source unavailable: ${error.message}. GPX and asset search remain available.`;
  }
})();
