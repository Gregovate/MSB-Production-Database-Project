/* Shared read-only discovery for reference geometry and recorded assets. */
const mapSearch = (() => {
  const input = document.getElementById('map-search');
  const results = document.getElementById('map-search-results');
  const status = document.getElementById('map-search-status');
  const references = [];
  let assets = [];
  for (const [layer, group] of Object.entries(layers)) {
    const features = new Map();
    group.eachLayer(marker => {
      const feature = marker._searchFeature;
      if (!feature) return;
      const key = feature.properties.id;
      if (!features.has(key)) {
        const entry = {name: feature.properties.name, kind: feature.properties.type,
          layer, markers: [], terms: feature.properties.name};
        features.set(key, entry); references.push(entry);
      }
      features.get(key).markers.push(marker);
    });
  }
  function select(entry) {
    if (!entry.markers.length) {
      status.textContent = `${entry.name}: ${entry.expectedLocation ? entry.expectedLocation + " — expected before picking; waypoint not recorded." : "Location not recorded."}`;
      return;
    }
    // Selecting reveals only the required layer; other layer choices persist.
    layers[entry.layer].addTo(map);
    const toggle = document.querySelector(`[data-layer="${entry.layer}"]`);
    if (toggle) toggle.checked = true;
    const bounds = L.latLngBounds([]);
    for (const marker of entry.markers) {
      if (marker.getBounds) bounds.extend(marker.getBounds());
      else bounds.extend(marker.getLatLng());
    }
    map.fitBounds(bounds, {padding: [40,40], maxZoom: 21});
    entry.markers[0].openPopup();
    status.textContent = `${entry.name}${entry.association ? ' · ' + entry.association : ''}`;
  }
  function update() {
    results.replaceChildren();
    const query = input.value.trim().toLowerCase();
    if (!query) { status.textContent = ''; return; }
    const matches = [...references, ...assets].filter(entry =>
      entry.terms.toLowerCase().includes(query) || entry.numericId === query);
    status.textContent = `${matches.length} results`;
    for (const entry of matches) {
      const button = document.createElement('button');
      button.style.display = 'block';
      button.style.width = '100%';
      button.style.textAlign = 'left';
      button.textContent = `${entry.name} · ${entry.kind}${entry.markers.length ? '' : entry.expectedLocation ? ' · Workshop (not picked)' : ' · Location not recorded'}`;
      button.addEventListener('click', () => select(entry));
      results.appendChild(button);
    }
  }
  input.addEventListener('input', update);
  return {
    clearAssets() { assets = []; update(); },
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
