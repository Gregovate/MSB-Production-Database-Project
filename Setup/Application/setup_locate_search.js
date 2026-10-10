/* Shared read-only discovery for reference geometry and recorded assets. */
const mapSearch = (() => {
  const input = document.getElementById('map-search');
  const results = document.getElementById('map-search-results');
  const status = document.getElementById('map-search-status');
  const references = [];
  let assets = [];
  let highlighted = [];
  const selectionListeners = [];
  function clearHighlight() {
    for (const item of highlighted) item.marker.setStyle(item.style);
    highlighted = [];
  }
  for (const [layer, group] of Object.entries(layers)) {
    const features = new Map();
    group.eachLayer(marker => {
      const feature = marker._searchFeature;
      if (!feature) return;
      const key = feature.properties.id;
      if (!features.has(key)) {
        const entry = {name: feature.properties.name, kind: layer === 'NET' ? 'GPX route (source name)' : feature.properties.type,
          layer, markers: [], terms: feature.properties.name};
        features.set(key, entry); references.push(entry);
      }
      features.get(key).markers.push(marker);
    });
  }
  function select(entry) {
    clearHighlight();
    if (map.closePopup) map.closePopup();
    for (const listener of selectionListeners) listener(entry);
    if (entry.onSelect) entry.onSelect();
    if (!entry.markers.length && entry.expectedLocation === "Workshop") {
      const workshop = references.find(ref => ref.name === "Workshop");
      if (workshop) entry = {...entry, layer: workshop.layer, markers: workshop.markers,
        association: "Expected at Workshop before picking; temporary reference"};
    }
    if (!entry.markers.length && entry.onSelect) {
      status.textContent = `${entry.name}: ${entry.association}. No matched map route.`;
      return;
    }
    if (!entry.markers.length) {
      status.textContent = `${entry.name}: ${entry.expectedLocation ? entry.expectedLocation + " — expected before picking; waypoint not recorded." : "Location not recorded."}`;
      return;
    }
    // Selecting reveals only the required layer; other layer choices persist.
    // A network may follow source tracks from multiple geographic layers.
    for (const layer of new Set([entry.layer, ...entry.markers.map(m => m._networkLayer).filter(Boolean)])) {
      layers[layer].addTo(map);
      const control = document.querySelector(`[data-layer="${layer}"]`);
      if (control) control.checked = true;
    }
    const toggle = document.querySelector(`[data-layer="${entry.layer}"]`);
    if (toggle) toggle.checked = true;
    const bounds = L.latLngBounds([]);
    for (const marker of entry.markers) {
      if (marker.getBounds) bounds.extend(marker.getBounds());
      else bounds.extend(marker.getLatLng());
    }
    // Highlight all source segments together, preserving their original styles.
    for (const marker of entry.markers) {
      if (!marker.setStyle) continue;
      highlighted.push({marker, style: {color: marker.options.color,
        weight: marker.options.weight, opacity: marker.options.opacity,
        dashArray: marker.options.dashArray || null}});
      marker.setStyle({color: "#ff00d4", weight: 7, opacity: 1,
        dashArray: entry.alternativeMarkers?.has(marker) ? "8 6" : null});
      if (marker.bringToFront) marker.bringToFront();
    }
    map.fitBounds(bounds, {padding: [40,40], maxZoom: 21});
    if (!entry.networkSearchAliases) entry.markers[0].openPopup();
    status.textContent = `${entry.name}${entry.association ? ' · ' + entry.association : ''}`;
  }
  function update() {
    results.replaceChildren();
    const query = input.value.trim().toLowerCase();
    if (!query) { status.textContent = ''; return; }
    // Exact network names resolve to one logical group. Historical GPX labels
    // remain discoverable by route name without competing with that network.
    const exactNetworks = references.filter(entry => entry.networkSearchAliases?.some(
      alias => alias.toLowerCase() === query));
    const matches = exactNetworks.length ? exactNetworks : [...references, ...assets].filter(entry =>
      entry.terms.toLowerCase().includes(query) || entry.numericId === query);
    status.textContent = `${matches.length} results`;
    for (const entry of matches) {
      const button = document.createElement('button');
      button.style.display = 'block';
      button.style.width = '100%';
      button.style.textAlign = 'left';
      button.textContent = `${entry.name} · ${entry.kind}${entry.resultNote ? ' · ' + entry.resultNote : ''}${entry.markers.length || entry.onSelect ? '' : entry.expectedLocation ? ' · Workshop (not picked)' : ' · Location not recorded'}`;
      button.addEventListener('click', () => select(entry));
      results.appendChild(button);
    }
  }
  input.addEventListener('input', update);
  return {
    select,
    focusContainer(id) {
      const entry = assets.find(a => a.kind === 'Container' && a.numericId === String(id));
      if (entry) select(entry);
      else status.textContent = `Container ${id} is not in this season's asset snapshot.`;
    },
    onSelection(listener) { selectionListeners.push(listener); },
    addReference(entry) { references.push(entry); update(); },
    clearAssets() { clearHighlight(); for (const listener of selectionListeners) listener({}); assets = []; update(); },
    addAsset(asset, container, marker) {
      const code = container ? 'C' + String(asset.container_id).padStart(3, '0') : '';
      const entry = {name: container ? `${code} — ${asset.name}` : asset.name,
        kind: container ? 'Container' : 'Display', layer: container ? 'containers' : 'displays',
        markers: marker ? [marker] : [], terms: `${code} ${asset.name}`,
        expectedLocation: asset.expected_location,
        numericId: container ? String(asset.container_id) : null};
      assets.push(entry);
      if (container) {
        for (const display of asset.contents.filter(d => d.position_mode === 'WITH_CONTAINER')) {
          assets.push({name: display.display_name, terms: display.display_name, kind: 'Display',
            layer: 'containers', markers: entry.markers, expectedLocation: asset.expected_location, association: `With ${code}`});
        }
      }
      update();
    }
  };
})();
