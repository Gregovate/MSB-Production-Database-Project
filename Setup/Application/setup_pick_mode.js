(() => {
  'use strict';

  const startPickButton = document.getElementById('start-pick-mode');
  const startParkButton = document.getElementById('start-park-mode');
  const stopButton = document.getElementById('stop-pick-mode');
  const panel = document.getElementById('pick-mode-panel');
  const feedback = document.getElementById('pick-mode-feedback');
  const networkState = document.getElementById('pick-mode-network');
  const queueState = document.getElementById('pick-mode-queue');
  const gpsState = document.getElementById('pick-mode-gps');
  const title = document.getElementById('pick-mode-title');
  const help = document.getElementById('pick-mode-help');
  const seasonSelect = document.getElementById('season-select');
  const parkTools = document.getElementById('park-location-tools');
  const gpsToggle = document.getElementById('movement-gps-toggle');
  const gpsCandidates = document.getElementById('movement-gps-candidates');
  const gpsCandidateButtons = document.getElementById('movement-gps-candidate-buttons');
  const knownReference = document.getElementById('movement-known-reference');
  const locationNote = document.getElementById('movement-location-note');
  const gpsQuality = document.getElementById('movement-gps-quality');
  const gpsQualityNote = document.getElementById('movement-gps-quality-note');
  const manualInput = document.getElementById('movement-manual-input');
  const manualGo = document.getElementById('movement-manual-go');
  const pendingPanel = document.getElementById('movement-pending');
  const pendingTitle = document.getElementById('movement-pending-title');
  const pendingState = document.getElementById('movement-pending-state');
  const unloadGroups = document.getElementById('movement-unload-groups');
  const recordHere = document.getElementById('movement-record-here');
  const returnHome = document.getElementById('movement-return-home');
  const clearPendingButton = document.getElementById('movement-clear-pending');

  const DB_NAME = 'msb-setup-movement';
  const DB_VERSION = 1;
  const STORE_NAME = 'movement-queue';
  const DEVICE_KEY = 'msb.setup.movement.device-id';
  const SCAN_RESET_MS = 5000;
  const GPS_CURRENT_MS = 15000;
  const MODE_PICK = 'PICK';
  const MODE_PARK = 'PARK';

  // Same frozen 2026_msb.gpx type=Stage reference set used by #219 field acceptance.
  // These are good operator reference anchors; raw GPS remains independent evidence.
  const REFERENCE_POINTS = [
    ["04-Food Collection-FC",43.7777955,-87.74358339],
    ["01-Front Entrance-FE",43.77752968,-87.74151575],
    ["00-HWY 42-HW",43.77792811,-87.74186506],
    ["05-Festive Trees-FT",43.77833036,-87.74354104],
    ["05a-Mega Star-MS",43.7785483,-87.74319754],
    ["06-Post Office-PO",43.77874564,-87.74423908],
    ["07a-Who Forest-WF",43.77948868,-87.74573914],
    ["08-Elf Choir-EC",43.77942108,-87.74623869],
    ["09-Global Warming-GW",43.77977361,-87.74652366],
    ["10-Stars-ST",43.78026391,-87.74678012],
    ["11-Sledders-SL",43.78038637,-87.74757818],
    ["13-Winter Wonderland-WW",43.77984397,-87.74782959],
    ["14-Icicle Tunnel-IT",43.7789102,-87.74828739],
    ["15-Church-Bells-CH",43.77852769,-87.74910923],
    ["16-Northern Lights-NL",43.77721337,-87.74888248],
    ["17-Candyland-CL",43.77680829,-87.74697976],
    ["18-Dancing Forest-DF",43.77649806,-87.74559202],
    ["19-Santa's Workshop-SW",43.77683742,-87.74577019],
    ["20-Snow Storm-SS",43.77625492,-87.74475721],
    ["21-Polar Bear Playground-PB",43.77604286,-87.74487442],
    ["22-Glistening Grove-GG",43.77573908,-87.74390953],
    ["23-Peanuts-PN",43.77577894,-87.74294278],
    ["24-Traditional Christmas-TC",43.77591889,-87.74289151],
    ["25-Racing Arches-RA",43.77636681,-87.74226992],
    ["26-Magic Igloo-MI",43.77714554,-87.74166344],
    ["02-Triangle-TR",43.77709198,-87.74208111],
    ["03-Welcome Area-WA",43.77741945,-87.7426539],
    ["03a-Mega Cube-MC",43.77756775,-87.7426221],
    ["30-Santa's Station-QV",43.78175546,-87.74664227],
    ["30-Santa's Station Entrance",43.78063504,-87.74542583],
    ["07-Whoville-WV",43.77955255,-87.74491109]
  ].map(([name, lat, lon]) => ({name, lat, lon}));

  let active = false;
  let mode = null;
  let scanBuffer = '';
  let scanResetTimer = null;
  let latestPosition = null;
  let watchId = null;
  let pendingIdentity = null;
  let pendingCaptureMethod = 'HID_SCAN';
  let pendingContents = null;
  let pendingStateRow = null;
  let queuedPickKeys = new Set();
  let syncing = false;

  function bridge() {
    return window.MSBSetupPickList || null;
  }

  function uuid() {
    if (window.crypto?.randomUUID) return window.crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = Math.random() * 16 | 0;
      return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
  }

  function deviceId() {
    let value = localStorage.getItem(DEVICE_KEY);
    if (!value) {
      value = uuid();
      localStorage.setItem(DEVICE_KEY, value);
    }
    return value;
  }

  function setFeedback(kind, message) {
    if (!feedback) return;
    feedback.className = `pick-mode-feedback ${kind}`;
    feedback.textContent = message;
  }

  function updateNetwork() {
    if (networkState) {
      networkState.textContent = navigator.onLine ? 'ONLINE' : 'OFFLINE — observations will queue';
    }
  }

  function openQueueDb() {
    return new Promise((resolve, reject) => {
      if (!('indexedDB' in window)) {
        reject(new Error('Durable offline storage is not available in this browser.'));
        return;
      }
      const request = indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          const store = db.createObjectStore(STORE_NAME, {keyPath: 'client_event_id'});
          store.createIndex('occurred_at', 'occurred_at', {unique: false});
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error || new Error('Offline queue could not be opened.'));
    });
  }

  async function queueRows() {
    const db = await openQueueDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const request = tx.objectStore(STORE_NAME).getAll();
      request.onsuccess = () => {
        const rows = Array.isArray(request.result) ? request.result : [];
        rows.sort((a, b) => String(a.occurred_at).localeCompare(String(b.occurred_at)));
        resolve(rows);
      };
      request.onerror = () => reject(request.error);
      tx.oncomplete = () => db.close();
    });
  }

  async function putQueue(row) {
    const db = await openQueueDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put(row);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
    db.close();
  }

  async function deleteQueue(clientEventId) {
    const db = await openQueueDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).delete(clientEventId);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
    db.close();
  }

  function assetKey(assetType, assetId) {
    return `${assetType}:${assetId}`;
  }

  async function refreshQueueState() {
    try {
      const rows = await queueRows();
      queuedPickKeys = new Set(
        rows
          .filter((row) => row.movement_action === 'PICKED')
          .map((row) => assetKey(row.asset_type, row.asset_id))
      );
      if (queueState) queueState.textContent = `Offline queue: ${rows.length}`;
      return rows;
    } catch (_error) {
      if (queueState) queueState.textContent = 'Offline queue unavailable';
      return [];
    }
  }

  function parseIdentity(raw) {
    const text = String(raw || '').trim().toUpperCase();
    const match = /^(CONT|DISP):(\d+)$/.exec(text);
    if (!match) return null;
    const id = Number(match[2]);
    if (!Number.isSafeInteger(id) || id <= 0) return null;
    return {
      asset_type: match[1] === 'CONT' ? 'CONTAINER' : 'DISPLAY',
      asset_id: id,
      identity: `${match[1]}:${id}`
    };
  }

  function findDemand(assetType, assetId) {
    const readiness = bridge()?.readiness?.();
    return (readiness?.physical_items || []).find((item) => (
      item.physical_type === assetType && Number(item.physical_id) === Number(assetId)
    )) || null;
  }

  function cachedPickValidation(identity) {
    const item = findDemand(identity.asset_type, identity.asset_id);
    if (!item) {
      return {ok: false, kind: 'warning', message: `${identity.identity} — NOT ON CURRENT PICK LIST`};
    }
    if (bridge()?.itemDelayed?.(item)) {
      return {ok: false, kind: 'blocked', message: `${identity.identity} — DELAYED — DO NOT PICK YET`};
    }
    if (bridge()?.itemMoved?.(item)) {
      const status = String(item?.current_observation?.movement_status || 'MOVED');
      return {ok: false, kind: 'warning', message: `${identity.identity} — ALREADY ${status}`};
    }
    if (queuedPickKeys.has(assetKey(identity.asset_type, identity.asset_id))) {
      return {ok: false, kind: 'offline', message: `${identity.identity} — PICK ALREADY QUEUED OFFLINE`};
    }
    return {ok: true, item};
  }

  function toRad(value) {
    return value * Math.PI / 180;
  }

  function distanceFeet(lat1, lon1, lat2, lon2) {
    const radiusFt = 20902260.958;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a = Math.sin(dLat / 2) ** 2
      + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return radiusFt * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  function currentGpsSnapshot() {
    if (watchId === null || !latestPosition) return null;
    const fixAt = Number(latestPosition.timestamp);
    const ageMs = Math.max(0, Date.now() - fixAt);
    if (ageMs > GPS_CURRENT_MS) return null;
    return {
      latitude: latestPosition.coords.latitude,
      longitude: latestPosition.coords.longitude,
      accuracy_m: latestPosition.coords.accuracy,
      fix_at: new Date(fixAt).toISOString(),
      fix_age_ms: Math.round(ageMs)
    };
  }

  function rankedReferences(snapshot) {
    if (!snapshot) return [];
    return REFERENCE_POINTS
      .map((point) => ({
        ...point,
        distance_ft: distanceFeet(
          snapshot.latitude,
          snapshot.longitude,
          point.lat,
          point.lon
        )
      }))
      .sort((a, b) => a.distance_ft - b.distance_ft);
  }

  function renderGps() {
    if (watchId === null) {
      if (gpsState) gpsState.textContent = 'GPS OFF';
      if (gpsToggle) gpsToggle.textContent = 'Start GPS';
      if (gpsCandidates) gpsCandidates.textContent = 'GPS is off. Start GPS when location evidence is needed.';
      if (gpsCandidateButtons) gpsCandidateButtons.innerHTML = '';
      return;
    }

    if (gpsToggle) gpsToggle.textContent = 'Stop GPS';
    const snapshot = currentGpsSnapshot();
    if (!snapshot) {
      if (gpsState) gpsState.textContent = latestPosition ? 'GPS STALE — waiting for current fix' : 'GPS acquiring…';
      if (gpsCandidates) gpsCandidates.textContent = 'Waiting for a current GPS fix…';
      if (gpsCandidateButtons) gpsCandidateButtons.innerHTML = '';
      return;
    }

    const accuracyFt = Number(snapshot.accuracy_m || 0) * 3.280839895;
    const ranked = rankedReferences(snapshot).slice(0, 3);
    if (gpsState) gpsState.textContent = `GPS ±${accuracyFt.toFixed(0)} ft · fix ${(snapshot.fix_age_ms / 1000).toFixed(1)} sec old`;
    if (gpsCandidates) {
      gpsCandidates.textContent = ranked.length
        ? `Nearest: ${ranked.map((item) => `${item.name} ${item.distance_ft.toFixed(0)} ft`).join(' · ')}`
        : 'No park reference candidates available.';
    }
    if (gpsCandidateButtons) {
      gpsCandidateButtons.innerHTML = ranked.map((item) => (
        `<button type="button" data-reference="${escapeHtml(item.name)}">${escapeHtml(item.name)} · ${item.distance_ft.toFixed(0)} ft</button>`
      )).join('');
      gpsCandidateButtons.querySelectorAll('[data-reference]').forEach((button) => {
        button.addEventListener('click', () => {
          knownReference.value = button.dataset.reference || '';
          setFeedback('ready', `LOCATION CONFIRMED — ${button.dataset.reference}`);
        });
      });
    }
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
  }

  function populateReferenceSelect() {
    if (!knownReference) return;
    knownReference.innerHTML = '<option value="">No named location confirmed</option>' +
      REFERENCE_POINTS.map((point) => (
        `<option value="${escapeHtml(point.name)}">${escapeHtml(point.name)}</option>`
      )).join('');
  }

  function startGps() {
    if (!navigator.geolocation) {
      if (gpsState) gpsState.textContent = 'GPS unavailable';
      return;
    }
    if (watchId !== null) return;
    latestPosition = null;
    if (gpsState) gpsState.textContent = 'GPS acquiring…';
    watchId = navigator.geolocation.watchPosition(
      (position) => {
        latestPosition = position;
        renderGps();
      },
      (error) => {
        if (gpsState) gpsState.textContent = `GPS error ${error.code}`;
        renderGps();
      },
      {enableHighAccuracy: true, maximumAge: 5000, timeout: 10000}
    );
    renderGps();
  }

  function stopGps() {
    if (watchId !== null && navigator.geolocation) {
      navigator.geolocation.clearWatch(watchId);
    }
    watchId = null;
    latestPosition = null;
    renderGps();
  }

  function destinationNote() {
    return String(locationNote?.value || '').trim()
      || String(knownReference?.value || '').trim()
      || null;
  }

  function gpsPayload() {
    const snapshot = currentGpsSnapshot();
    if (!snapshot) return {};
    return {
      gps_latitude: snapshot.latitude,
      gps_longitude: snapshot.longitude,
      gps_accuracy_m: snapshot.accuracy_m,
      gps_fix_at: snapshot.fix_at,
      gps_fix_age_ms: snapshot.fix_age_ms,
      gps_quality: String(gpsQuality?.value || 'UNASSESSED').toUpperCase(),
      gps_quality_note: String(gpsQualityNote?.value || '').trim() || null
    };
  }

  function movementPayload(identity, action, captureMethod, unloadedDisplayIds = []) {
    return {
      season_year: Number(seasonSelect?.value || 2026),
      client_event_id: uuid(),
      asset_type: identity.asset_type,
      asset_id: identity.asset_id,
      movement_action: action,
      occurred_at: new Date().toISOString(),
      device_id: deviceId(),
      captured_operator_email: String(
        bridge()?.access?.()?.authenticated_email || ''
      ).trim().toLowerCase(),
      capture_method: captureMethod,
      offline_captured: !navigator.onLine,
      destination_location_note: action === 'RETURNED' ? null : destinationNote(),
      unloaded_display_ids: unloadedDisplayIds,
      gps_quality: String(gpsQuality?.value || 'UNASSESSED').toUpperCase(),
      gps_quality_note: String(gpsQualityNote?.value || '').trim() || null,
      ...gpsPayload()
    };
  }

  async function postMovement(payload) {
    const response = await fetch('../api/setup/movements', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-MSB-Setup-Command': '1'
      },
      body: JSON.stringify(payload)
    });
    let data = {};
    try {
      data = await response.json();
    } catch (_error) {}
    if (!response.ok) {
      const error = new Error(data.error || `HTTP ${response.status}`);
      error.httpStatus = response.status;
      throw error;
    }
    return data.movement || {};
  }

  async function queueMovement(payload) {
    await putQueue({...payload, offline_captured: true, queue_status: 'QUEUED'});
    if (payload.movement_action === 'PICKED') {
      queuedPickKeys.add(assetKey(payload.asset_type, payload.asset_id));
    }
    await refreshQueueState();
  }

  async function sendOrQueue(payload) {
    if (!navigator.onLine) {
      await queueMovement(payload);
      return {queued: true};
    }
    try {
      return {movement: await postMovement(payload), queued: false};
    } catch (error) {
      if (!error.httpStatus || error.httpStatus >= 500) {
        await queueMovement(payload);
        return {queued: true};
      }
      throw error;
    }
  }

  async function recordPick(identity, captureMethod) {
    const validation = cachedPickValidation(identity);
    if (!validation.ok) {
      setFeedback(validation.kind, validation.message);
      return;
    }

    const payload = movementPayload(identity, 'PICKED', captureMethod);
    try {
      const result = await sendOrQueue(payload);
      if (result.queued) {
        setFeedback('offline', `${identity.identity} — PICK QUEUED OFFLINE`);
      } else {
        setFeedback('success', `${identity.identity} — PICKED FOR PARK TRANSPORT`);
        await bridge()?.reload?.();
      }
    } catch (error) {
      const message = String(error.message || error);
      const kind = /DELAYED|DO NOT PICK/i.test(message) ? 'blocked' : 'warning';
      setFeedback(kind, `${identity.identity} — ${message}`);
      await bridge()?.reload?.().catch(() => {});
    }
  }

  async function fetchState(identity) {
    const url = '../api/setup/movements/state'
      + `?season_year=${encodeURIComponent(seasonSelect?.value || 2026)}`
      + `&asset_type=${encodeURIComponent(identity.asset_type)}`
      + `&asset_id=${encodeURIComponent(identity.asset_id)}`;
    const response = await fetch(url, {cache: 'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    return data.state || null;
  }

  async function fetchContainerContents(containerId) {
    const url = '../api/setup/movements/container-contents'
      + `?season_year=${encodeURIComponent(seasonSelect?.value || 2026)}`
      + `&container_id=${encodeURIComponent(containerId)}`;
    const response = await fetch(url, {cache: 'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    return data.container || null;
  }

  function clearPending() {
    pendingIdentity = null;
    pendingCaptureMethod = 'HID_SCAN';
    pendingContents = null;
    pendingStateRow = null;
    if (pendingPanel) pendingPanel.hidden = true;
    if (pendingTitle) pendingTitle.textContent = '';
    if (pendingState) pendingState.textContent = '';
    if (unloadGroups) unloadGroups.innerHTML = '';
    if (returnHome) returnHome.hidden = true;
  }

  function selectedUnloadedDisplayIds() {
    if (!unloadGroups) return [];
    const result = [];
    unloadGroups.querySelectorAll('input[data-display-ids]:checked').forEach((input) => {
      const ids = String(input.dataset.displayIds || '')
        .split(',')
        .map((value) => Number(value))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
      result.push(...ids);
    });
    return [...new Set(result)];
  }

  function setAllUnloadGroups(checked) {
    unloadGroups?.querySelectorAll('input[data-display-ids]:not(:disabled)')
      .forEach((input) => { input.checked = checked; });
  }

  function renderPending() {
    if (!pendingIdentity || !pendingPanel) return;
    pendingPanel.hidden = false;
    const label = pendingContents?.label || pendingStateRow?.label || pendingIdentity.identity;
    pendingTitle.textContent = `${pendingIdentity.identity} — ${label}`;
    const status = pendingContents?.movement_status || pendingStateRow?.movement_status || 'No prior movement state';
    pendingState.textContent = `Current Setup state: ${String(status).replaceAll('_', ' ')}`;
    returnHome.hidden = pendingIdentity.asset_type !== 'CONTAINER';

    if (pendingIdentity.asset_type !== 'CONTAINER') {
      unloadGroups.innerHTML = '<p class="movement-group-note">Recording this Display here detaches only this Display from its Container. Later Container moves will not move it.</p>';
      return;
    }

    const groups = Array.isArray(pendingContents?.groups) ? pendingContents.groups : [];
    if (!groups.length) {
      unloadGroups.innerHTML = '<p class="movement-group-note">No active Displays remain with this Container. Record the Container location only.</p>';
      return;
    }

    const selectable = groups.filter((group) => group.bulk_selectable);
    const reviewOnly = groups.filter((group) => !group.bulk_selectable);
    const groupHtml = selectable.map((group) => {
      const ids = (group.display_ids || []).join(',');
      return `
        <label class="movement-unload-group">
          <input type="checkbox" data-display-ids="${escapeHtml(ids)}">
          <span><strong>${escapeHtml(group.label)}</strong><br>
          ${group.display_count} Display${group.display_count === 1 ? '' : 's'} came off here</span>
        </label>`;
    }).join('');

    const reviewHtml = reviewOnly.map((group) => (
      `<div class="movement-group-warning"><strong>${escapeHtml(group.label)}</strong> · ${group.display_count} Display${group.display_count === 1 ? '' : 's'}</div>`
    )).join('');

    unloadGroups.innerHTML = `
      <div class="movement-group-heading">
        <strong>What came off here?</strong>
        <span>Anything not selected stays WITH_CONTAINER and follows the next Container scan.</span>
      </div>
      ${groupHtml || '<p class="movement-group-note">No Stage-grouped Displays are available for bulk unload.</p>'}
      ${selectable.length ? '<div class="movement-group-actions"><button type="button" id="movement-unload-all">All remaining groups</button><button type="button" id="movement-unload-none" class="secondary">None came off</button></div>' : ''}
      ${reviewHtml}
    `;

    document.getElementById('movement-unload-all')?.addEventListener('click', () => setAllUnloadGroups(true));
    document.getElementById('movement-unload-none')?.addEventListener('click', () => setAllUnloadGroups(false));
  }

  async function selectForPark(identity, captureMethod) {
    pendingIdentity = identity;
    pendingCaptureMethod = captureMethod;
    pendingContents = null;
    pendingStateRow = null;
    setFeedback('ready', `${identity.identity} — loading current movement context…`);
    try {
      if (identity.asset_type === 'CONTAINER') {
        pendingContents = await fetchContainerContents(identity.asset_id);
        pendingStateRow = pendingContents;
      } else {
        pendingStateRow = await fetchState(identity);
      }
    } catch (error) {
      if (navigator.onLine) {
        clearPending();
        setFeedback('warning', `${identity.identity} — ${error.message || error}`);
        return;
      }
      // Offline use may not have a cached context yet. Preserve the observation
      // path but do not invent unload membership.
      pendingStateRow = {label: identity.identity, movement_status: 'OFFLINE CONTEXT UNAVAILABLE'};
    }
    renderPending();
    setFeedback('ready', `${identity.identity} — review location, then RECORD HERE`);
  }

  async function recordPending(returningHome = false) {
    if (!pendingIdentity) return;
    const identity = pendingIdentity;
    const action = returningHome
      ? 'RETURNED'
      : (identity.asset_type === 'CONTAINER' ? 'CONTAINER_MOVE' : 'DISPLAY_MOVE');

    if (!returningHome && !currentGpsSnapshot() && !destinationNote()) {
      setFeedback('blocked', 'LOCATION NEEDED — start GPS, confirm a park reference, or enter a location note.');
      return;
    }

    const unloaded = action === 'CONTAINER_MOVE' ? selectedUnloadedDisplayIds() : [];
    const payload = movementPayload(identity, action, pendingCaptureMethod, unloaded);
    setFeedback('ready', `${identity.identity} — recording physical observation…`);

    try {
      const result = await sendOrQueue(payload);
      if (result.queued) {
        setFeedback('offline', `${identity.identity} — OBSERVATION QUEUED OFFLINE`);
      } else {
        const movement = result.movement || {};
        if (returningHome) {
          setFeedback(
            'success',
            `${identity.identity} — RETURNED HOME ${movement.home_location_code || ''}`.trim()
          );
        } else {
          const unloadText = Number(movement.unloaded_display_count || 0)
            ? ` · ${movement.unloaded_display_count} Display${Number(movement.unloaded_display_count) === 1 ? '' : 's'} left here`
            : '';
          const snapshot = currentGpsSnapshot();
          const gpsText = snapshot
            ? ` · GPS ±${Math.round(Number(snapshot.accuracy_m || 0) * 3.280839895)} ft`
            : '';
          setFeedback('success', `${identity.identity} — RECORDED HERE${unloadText}${gpsText}`);
        }
        await bridge()?.reload?.().catch(() => {});
      }
      clearPending();
      if (knownReference) knownReference.value = '';
      if (locationNote) locationNote.value = '';
      if (gpsQuality) gpsQuality.value = 'UNASSESSED';
      if (gpsQualityNote) gpsQualityNote.value = '';
    } catch (error) {
      setFeedback('warning', `${identity.identity} — ${error.message || error}`);
    }
  }

  async function handleIdentity(raw, captureMethod) {
    const identity = parseIdentity(raw);
    if (!identity) {
      setFeedback('blocked', 'INVALID IDENTITY — expected CONT:<id> or DISP:<id>');
      return;
    }
    if (mode === MODE_PICK) {
      await recordPick(identity, captureMethod);
      return;
    }
    if (mode === MODE_PARK) {
      await selectForPark(identity, captureMethod);
    }
  }

  function clearScanTimer() {
    if (scanResetTimer) window.clearTimeout(scanResetTimer);
    scanResetTimer = null;
  }

  function scheduleScanReset() {
    clearScanTimer();
    scanResetTimer = window.setTimeout(() => {
      scanBuffer = '';
      scanResetTimer = null;
    }, SCAN_RESET_MS);
  }

  function isEditableTarget(target) {
    return target instanceof HTMLInputElement
      || target instanceof HTMLTextAreaElement
      || target instanceof HTMLSelectElement
      || target?.isContentEditable;
  }

  function captureKeydown(event) {
    if (!active || event.defaultPrevented || event.isComposing) return;
    if (event.ctrlKey || event.metaKey || event.altKey) return;
    if (isEditableTarget(event.target)) return;

    if (event.key === 'Enter') {
      event.preventDefault();
      event.stopImmediatePropagation();
      clearScanTimer();
      const value = scanBuffer;
      scanBuffer = '';
      if (value.trim()) void handleIdentity(value, 'HID_SCAN');
      return;
    }

    if (event.key && event.key.length === 1) {
      event.preventDefault();
      event.stopImmediatePropagation();
      scanBuffer += event.key;
      scheduleScanReset();
    }
  }

  function updateModeUrl(nextMode) {
    const url = new URL(location.href);
    if (nextMode === MODE_PARK) url.searchParams.set('mode', 'park');
    else if (nextMode === MODE_PICK) url.searchParams.set('mode', 'pick');
    else url.searchParams.delete('mode');
    history.replaceState({}, '', url);
  }

  function startMode(nextMode) {
    const access = bridge()?.access?.() || {};
    if (!access.can_move_setup_assets) {
      if (panel) panel.hidden = false;
      setFeedback('blocked', 'This signed-in account is not authorized for Setup movement.');
      return;
    }

    active = true;
    mode = nextMode;
    scanBuffer = '';
    clearPending();
    document.body.classList.add('pick-mode-active');
    if (panel) panel.hidden = false;
    if (parkTools) parkTools.hidden = nextMode !== MODE_PARK;
    document.activeElement?.blur?.();

    if (nextMode === MODE_PICK) {
      stopGps();
      title.textContent = 'WORKSHOP PICK — ARMED';
      help.textContent = 'Scan or choose a Container / Display. One Pick records that it is going onto transport for the park.';
      setFeedback('ready', 'READY — scan the next Pick List item');
    } else {
      title.textContent = 'PARK SCAN — RECORD WHERE IT IS';
      help.textContent = 'Scan or choose a Container / Display, review location evidence, then Record Here.';
      startGps();
      setFeedback('ready', 'READY — scan or choose an item');
    }

    updateModeUrl(nextMode);
    void refreshQueueState();
  }

  function stopMode() {
    active = false;
    mode = null;
    scanBuffer = '';
    clearScanTimer();
    clearPending();
    stopGps();
    document.body.classList.remove('pick-mode-active');
    if (panel) panel.hidden = true;
    updateModeUrl(null);
  }

  async function syncQueue() {
    if (syncing || !navigator.onLine) return;
    syncing = true;
    try {
      const rows = await queueRows();
      for (const row of rows) {
        try {
          await postMovement({...row, offline_captured: true});
          await deleteQueue(row.client_event_id);
        } catch (error) {
          if (!error.httpStatus || error.httpStatus >= 500) break;
          await putQueue({
            ...row,
            queue_status: 'FAILED',
            last_error: String(error.message || error)
          });
          setFeedback(
            'blocked',
            `OFFLINE SYNC NEEDS REVIEW — ${row.asset_type}:${row.asset_id} — ${error.message || error}`
          );
          break;
        }
      }
      await refreshQueueState();
      await bridge()?.reload?.().catch(() => {});
    } finally {
      syncing = false;
    }
  }

  async function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) return;
    try {
      await navigator.serviceWorker.register('service-worker.js', {scope: './'});
      await navigator.serviceWorker.ready;
      const year = encodeURIComponent(seasonSelect?.value || '2026');
      const urls = [
        `../api/setup/material-readiness?season_year=${year}`,
        '../api/setup/access',
        '../api/setup/stages'
      ];
      if (bridge()?.access?.()?.can_manage_setup) {
        urls.push('../api/setup/containers/source-options');
      }
      await Promise.allSettled(urls.map((url) => fetch(url, {cache: 'no-store'})));
    } catch (_error) {
      // Offline-cold-start acceptance exposes any shell/cache failure.
    }
  }

  manualGo?.addEventListener('click', () => {
    const value = manualInput?.value || '';
    if (value.trim()) void handleIdentity(value, 'MANUAL_ENTRY');
  });
  manualInput?.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    const value = manualInput.value;
    if (value.trim()) void handleIdentity(value, 'MANUAL_ENTRY');
  });

  document.addEventListener('keydown', captureKeydown, true);
  document.addEventListener('msb-movement-select', (event) => {
    const identity = event.detail?.identity;
    if (active && identity) void handleIdentity(identity, 'TOUCH_SELECT');
  });
  document.addEventListener('msb-pick-list-ready', () => {
    const requested = new URLSearchParams(location.search).get('mode');
    if (requested === 'park') startMode(MODE_PARK);
    else if (requested === 'pick') startMode(MODE_PICK);
  });

  startPickButton?.addEventListener('click', () => startMode(MODE_PICK));
  startParkButton?.addEventListener('click', () => startMode(MODE_PARK));
  stopButton?.addEventListener('click', stopMode);
  gpsToggle?.addEventListener('click', () => {
    if (watchId === null) startGps();
    else stopGps();
  });
  knownReference?.addEventListener('change', () => {
    if (knownReference.value) {
      setFeedback('ready', `LOCATION CONFIRMED — ${knownReference.value}`);
    }
  });
  recordHere?.addEventListener('click', () => { void recordPending(false); });
  returnHome?.addEventListener('click', () => { void recordPending(true); });
  clearPendingButton?.addEventListener('click', () => {
    clearPending();
    setFeedback('ready', 'READY — scan or choose an item');
  });

  window.addEventListener('online', () => {
    updateNetwork();
    void syncQueue();
  });
  window.addEventListener('offline', updateNetwork);
  window.setInterval(() => {
    if (mode === MODE_PARK) renderGps();
  }, 1000);

  populateReferenceSelect();
  stopGps();
  updateNetwork();
  void refreshQueueState();
  void registerServiceWorker();
  if (navigator.onLine) void syncQueue();
})();
