/* #171 consumes #88 observations. Rendering never records movement. */
(() => {
  const icons = {
    UNKNOWN: 'assets/container-unknown.svg',
    LOADED: 'assets/container-loaded.svg',
    PARTIAL: 'assets/container-partial.svg',
    EMPTY: 'assets/container-empty.svg',
    DISPLAY: 'https://webassets.sheboyganlights.org/images/symbols/msb/T-Post.png'
  };
  const year = document.getElementById('asset-year');
  year.value = new Date().getFullYear();
  const status = document.getElementById('asset-status');
  const unlocated = document.getElementById('asset-unlocated');
  const refresh = document.getElementById('asset-refresh');
  let sequence = 0;
  function evidence(o) {
    let text = `Observation: ${esc(o.occurred_at ? new Date(o.occurred_at).toLocaleString('en-US', {timeZone: 'America/Chicago'}) + ' (Chicago)' : 'not recorded')}`;
    if (o.gps_latitude != null && o.gps_longitude != null) text += `<br>Recorded GPS: ${esc(o.gps_latitude)}, ${esc(o.gps_longitude)}`;
    if (o.gps_accuracy_m != null && Number(o.gps_accuracy_m) >= 0) text += `<br>Accuracy: ±${Math.round(Number(o.gps_accuracy_m) / 0.3048)} ft`;
    text += `<br>Event: ${esc(o.setup_movement_event_id ?? 'none')} · ${esc(o.event_type ?? '')}`;
    text += `<br>Source: ${esc(o.capture_method ?? 'not recorded')}${o.offline_captured ? ' · offline capture' : ''}`;
    if (o.destination_location_note) text += `<br>Recorded destination: ${esc(o.destination_location_note)}`;
    if (o.stage_name) text += `<br>Recorded Stage: ${esc(o.stage_key)} ${esc(o.stage_name)}`;
    if (o.gps_quality) text += `<br>GPS quality: ${esc(o.gps_quality)}`;
    if (Number(o.gps_fix_age_ms) > 15000) text += '<br>Fix was stale at capture';
    return text;
  }
  function popup(a, container) {
    let text = `<b>${container ? 'C' + String(a.container_id).padStart(3, '0') + ' — ' : ''}${esc(a.name)}</b><br>${evidence(a.observation)}`;
    if (container) {
      text += `<br>Recorded movement: ${esc(a.movement_status)}<br>Physical load: Unknown<br>${esc(a.uncertainty)}`;
      if (a.review_event_ids.length) text += `<br>Contents review recorded in events ${esc(a.review_event_ids.join(', '))}; resolution not established here.`;
      text += '<br><b>Current recorded Display associations</b><ul>';
      for (const d of a.contents) text += `<li>${esc(d.display_name)} · ${esc(d.position_mode)}</li>`;
      text += '</ul>';
      if (!a.contents.length) text += 'No active assigned Displays; this does not prove Empty.';
    } else text += `<br>Recorded position mode: ${esc(a.position_mode)}`;
    return text;
  }
  function render(items, container) {
    const group = layers[container ? 'containers' : 'displays'];
    // One marker per exact coordinate, with all colocated assets in its popup.
    // Recorded coordinates remain unchanged; no artificial marker displacement.
    const positions = new Map();
    for (const a of items) {
      if (!a.position) {
        const el = document.createElement('details');
        el.innerHTML = `<summary>${container ? 'C' + String(a.container_id).padStart(3, '0') + ' — ' : ''}${esc(a.name)}</summary>${popup(a, container)}<p>No geographic position in current state.</p>`;
        unlocated.appendChild(el);
        continue;
      }
      const key = a.position.join(',');
      if (!positions.has(key)) positions.set(key, []);
      positions.get(key).push(a);
    }
    for (const values of positions.values()) {
      const a = values[0];
      const marker = L.marker(a.position, {icon: L.icon({iconUrl: container ? icons[a.load_state] || icons.UNKNOWN : icons.DISPLAY, iconSize: [32,32], iconAnchor: [16,16]})});
      const title = values.map(v => container ? 'C' + String(v.container_id).padStart(3, '0') : v.name).join(' · ');
      marker.bindTooltip(esc(title));
      marker.bindPopup(values.map(v => popup(v, container)).join('<hr>'), {maxHeight: 360});
      marker.addTo(group);
    }
  }
  async function load() {
    const current = ++sequence;
    refresh.disabled = true;
    status.textContent = 'Loading recorded asset locations…';
    layers.containers.clearLayers(); layers.displays.clearLayers();
    unlocated.replaceChildren();
    try {
      const response = await fetch(`../api/setup/locate/assets?season_year=${encodeURIComponent(year.value)}`, {cache: 'no-store', headers: {Accept: 'application/json'}});
      if (!response.ok) throw new Error(`Asset data unavailable (${response.status})`);
      const data = await response.json();
      if (current !== sequence) return;
      render(data.containers, true); render(data.displays, false);
      status.textContent = `${data.containers.length} Containers · ${data.displays.length} independent Displays · ${unlocated.children.length} unlocated · through event ${data.through_event_id}. Physical loads unconfirmed.`;
    } catch (error) {
      if (current === sequence) status.textContent = `${error.message}. Refresh to retry.`;
    } finally { if (current === sequence) refresh.disabled = false; }
  }
  refresh.addEventListener('click', load);
  load();
})();
