/* Source-backed network discovery. GPX descriptions never assign network identity. */
(async () => {
  const status = document.getElementById('network-status');
  const details = document.getElementById('network-details');
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
    layers.NET.eachLayer(marker => {
      const id = marker._searchFeature?.properties.id;
      if (!id) return;
      if (!routes.has(id)) routes.set(id, []);
      routes.get(id).push(marker);
    });
    const networks = new Map();
    for (const cable of source.cables) {
      if (!networks.has(cable.network)) networks.set(cable.network, []);
      networks.get(cable.network).push(cable);
    }
    const routeNames = new Map(source.mapped_routes.map(r => [r.route_id, r.source_name]));
    function show(network, cables, routeIds) {
      details.replaceChildren();
      details.parentElement.open = true;
      row(details, `${network} — ${cables.length} draw.io cable records · ${routeIds.size} GPX routes`);
      row(details, 'Endpoint matches need review. Shared network names do not prove physical continuity.');
      row(details, `${source.source_name} · SHA256 ${source.source_sha256.slice(0, 16)}`);
      for (const cable of cables) {
        const item = document.createElement('details');
        const title = document.createElement('summary');
        title.textContent = `${cable.attributes.Cable_ID} · ${cable.route_ids.length ? 'route match: review required' : cable.status === 'ENDPOINT_CONFLICT' ? 'endpoint conflict' : 'route unresolved'}`;
        item.appendChild(title);
        row(item, `Endpoints: ${cable.attributes.Waypoint_1} → ${cable.attributes.Waypoint_2}`);
        row(item, `Source network: ${cable.attributes.Network}`);
        row(item, `Source length: ${cable.attributes.Feet || 'not recorded'} ft · Source Speed field: ${cable.attributes.Speed || 'not recorded'} (not measured throughput)`);
        row(item, `Source object: ${cable.source_id}`);
        for (const id of cable.route_ids) row(item, routeNames.get(id) || id);
        // These buttons reuse the original route selection and never draw a connecting line.
        if (cable.route_ids.length) {
          const button = document.createElement('button');
          button.textContent = 'Show cable route';
          button.addEventListener('click', () => mapSearch.select({name: cable.attributes.Cable_ID,
            kind: 'Cable route', layer: 'NET', markers: cable.route_ids.flatMap(id => routes.get(id) || []),
            association: 'Endpoint match — review required'}));
          item.appendChild(button);
        }
        details.appendChild(item);
      }
    }
    for (const [network, cables] of networks) {
      const routeIds = new Set(cables.flatMap(c => c.route_ids));
      const markers = [...routeIds].flatMap(id => routes.get(id) || []);
      const unresolved = cables.filter(c => !c.route_ids.length).length;
      const terms = [network, ...cables.flatMap(c => [c.attributes.Network, c.attributes.Cable_ID,
        c.attributes.Waypoint_1, c.attributes.Waypoint_2])].join(' ');
      mapSearch.addReference({name: network, kind: 'Network (draw.io)', layer: 'NET',
        markers, terms, resultNote: `${routeIds.size} routes · ${unresolved} unresolved cables`,
        association: `${routeIds.size} endpoint-matched routes; ${unresolved} cables without matched routes — review required`,
        onSelect: () => show(network, cables, routeIds)});
    }
    status.textContent = `Network source loaded: ${source.mapped_routes.length} endpoint-matched routes; ${source.unresolved_routes.length} unresolved routes; ${source.legacy_edges.length} legacy edges need review.`;
  } catch (error) {
    status.textContent = `Network source unavailable: ${error.message}. GPX and asset search remain available.`;
  }
})();
