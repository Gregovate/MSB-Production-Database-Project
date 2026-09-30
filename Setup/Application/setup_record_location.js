(() => {
  'use strict';

  const el = (id) => document.getElementById(id);
  const manualInput = el('movement-manual-input');
  const manualGo = el('movement-manual-go');
  const searchInput = el('movement-search-input');
  const searchGo = el('movement-search-go');
  const searchResults = el('movement-search-results');
  const cameraToggle = el('movement-camera-toggle');
  const cameraStatus = el('movement-camera-status');
  const cameraPanel = el('movement-camera-panel');
  const cameraVideo = el('movement-camera-video');
  const gpsToggle = el('movement-gps-toggle');
  const gpsState = el('movement-gps');
  const gpsCandidates = el('movement-gps-candidates');
  const gpsCandidateButtons = el('movement-gps-candidate-buttons');
  const knownReference = el('movement-known-reference');
  const locationNote = el('movement-location-note');
  const gpsQuality = el('movement-gps-quality');
  const gpsQualityNote = el('movement-gps-quality-note');
  const referenceStatus = el('movement-reference-status');
  const pendingPanel = el('movement-pending');
  const pendingTitle = el('movement-pending-title');
  const pendingState = el('movement-pending-state');
  const unloadGroups = el('movement-unload-groups');
  const recordHere = el('movement-record-here');
  const returnHome = el('movement-return-home');
  const clearPendingButton = el('movement-clear-pending');
  const feedback = el('movement-feedback');
  const networkState = el('movement-network');
  const queueState = el('movement-queue');
  const operatorBadge = el('operator-badge');
  const trainingEnter = el('training-enter');
  const trainingExit = el('training-exit');
  const trainingEntry = el('training-entry');
  const trainingBanner = el('training-banner');

  const pageParams = new URLSearchParams(location.search);
  const trainingMode = pageParams.get('training') === '1';

  const DB_NAME = 'msb-setup-movement';
  const DB_VERSION = 1;
  const STORE_NAME = 'movement-queue';
  const DEVICE_KEY = 'msb.setup.movement.device-id';
  const ACCESS_CACHE_KEY = 'msb.setup.movement.access';
  const REFERENCE_CACHE_KEY = 'msb.setup.record-location.references';
  const GPS_CURRENT_MS = 15000;
  const SCAN_RESET_MS = 5000;

  let access = null;
  let referenceSet = null;
  let latestPosition = null;
  let watchId = null;
  let pendingIdentity = null;
  let pendingCaptureMethod = 'HID_SCAN';
  let pendingContents = null;
  let pendingStateRow = null;
  let scanBuffer = '';
  let scanResetTimer = null;
  let syncing = false;
  let cameraStream = null;
  let cameraFrame = null;
  let barcodeDetector = null;

  function seasonYear() {
    const raw = Number(new URLSearchParams(location.search).get('season_year'));
    return Number.isInteger(raw) && raw > 2000 ? raw : new Date().getFullYear();
  }

  function uuid() {
    if (window.crypto && window.crypto.randomUUID) return window.crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
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

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  function setFeedback(kind, message) {
    feedback.className = 'feedback ' + kind;
    feedback.textContent = message;
  }

  function updateNetwork() {
    if (trainingMode) {
      networkState.textContent = navigator.onLine
        ? 'ONLINE · TRAINING READ-ONLY'
        : 'OFFLINE · TRAINING READ-ONLY';
      return;
    }
    networkState.textContent = navigator.onLine
      ? 'ONLINE'
      : 'OFFLINE — observations will queue locally';
  }

  function applyTrainingMode() {
    document.body.classList.toggle('training-mode', trainingMode);
    if (trainingBanner) trainingBanner.hidden = !trainingMode;
    if (trainingExit) trainingExit.hidden = !trainingMode;
    if (trainingEntry) trainingEntry.hidden = trainingMode;
    if (recordHere) recordHere.textContent = trainingMode ? 'Test Record Here' : 'Record Here';
    if (returnHome) returnHome.textContent = trainingMode ? 'Test Return Home' : 'Returned to Home Location';
    if (trainingMode && queueState) queueState.textContent = 'Training — movement queue disabled';
  }

  function enterTrainingMode() {
    const confirmed = window.confirm(
      'Enter Record Location Training Mode?\n\n'
      + 'Nothing will be recorded or queued. Use this only for deliberate device/operator practice.'
    );
    if (!confirmed) return;
    const url = new URL(location.href);
    url.searchParams.set('training', '1');
    location.href = url.toString();
  }

  function exitTrainingMode() {
    const url = new URL(location.href);
    url.searchParams.delete('training');
    location.href = url.toString();
  }

  function parseIdentity(raw) {
    const text = String(raw || '').trim();
    const compact = /^(CONT|DISP):(\d+)$/i.exec(text);
    if (compact) {
      const id = Number(compact[2]);
      if (!Number.isSafeInteger(id) || id <= 0) return null;
      return {
        asset_type: compact[1].toUpperCase() === 'CONT' ? 'CONTAINER' : 'DISPLAY',
        asset_id: id,
        identity: compact[1].toUpperCase() + ':' + id
      };
    }

    try {
      const url = new URL(text);
      const match = /\/scan\/(CONT|DISP)\/(\d+)(?:\/|$)/i.exec(url.pathname);
      if (!match) return null;
      const id = Number(match[2]);
      if (!Number.isSafeInteger(id) || id <= 0) return null;
      return {
        asset_type: match[1].toUpperCase() === 'CONT' ? 'CONTAINER' : 'DISPLAY',
        asset_id: id,
        identity: match[1].toUpperCase() + ':' + id
      };
    } catch (_error) {
      return null;
    }
  }

  function openQueueDb() {
    return new Promise(function (resolve, reject) {
      if (!('indexedDB' in window)) {
        reject(new Error('Durable offline storage is not available in this browser.'));
        return;
      }
      const request = indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = function () {
        const db = request.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          const store = db.createObjectStore(STORE_NAME, {keyPath: 'client_event_id'});
          store.createIndex('occurred_at', 'occurred_at', {unique: false});
        }
      };
      request.onsuccess = function () { resolve(request.result); };
      request.onerror = function () { reject(request.error || new Error('Offline queue could not be opened.')); };
    });
  }

  async function queueRows() {
    const db = await openQueueDb();
    return new Promise(function (resolve, reject) {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const request = tx.objectStore(STORE_NAME).getAll();
      request.onsuccess = function () {
        const rows = Array.isArray(request.result) ? request.result : [];
        rows.sort(function (a, b) { return String(a.occurred_at).localeCompare(String(b.occurred_at)); });
        resolve(rows);
      };
      request.onerror = function () { reject(request.error); };
      tx.oncomplete = function () { db.close(); };
    });
  }

  async function putQueue(row) {
    const db = await openQueueDb();
    await new Promise(function (resolve, reject) {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put(row);
      tx.oncomplete = resolve;
      tx.onerror = function () { reject(tx.error); };
      tx.onabort = function () { reject(tx.error); };
    });
    db.close();
  }

  async function deleteQueue(clientEventId) {
    const db = await openQueueDb();
    await new Promise(function (resolve, reject) {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).delete(clientEventId);
      tx.oncomplete = resolve;
      tx.onerror = function () { reject(tx.error); };
      tx.onabort = function () { reject(tx.error); };
    });
    db.close();
  }

  async function refreshQueueState() {
    if (trainingMode) {
      queueState.textContent = 'Training — movement queue disabled';
      return [];
    }
    try {
      const rows = await queueRows();
      queueState.textContent = 'Offline queue: ' + rows.length;
      return rows;
    } catch (_error) {
      queueState.textContent = 'Offline queue unavailable';
      return [];
    }
  }

  async function apiJson(url, options) {
    const response = await fetch(url, options || {cache: 'no-store'});
    let data = {};
    try {
      data = await response.json();
    } catch (_error) {}
    if (!response.ok) {
      const error = new Error(data.error || ('HTTP ' + response.status));
      error.httpStatus = response.status;
      throw error;
    }
    return data;
  }

  async function loadAccess() {
    try {
      const data = await apiJson('../api/setup/access', {cache: 'no-store'});
      access = data.access || {};
      localStorage.setItem(ACCESS_CACHE_KEY, JSON.stringify(access));
    } catch (error) {
      const cached = localStorage.getItem(ACCESS_CACHE_KEY);
      if (!cached) throw error;
      access = JSON.parse(cached);
    }

    operatorBadge.textContent = (access.display_name || access.authenticated_email || 'Signed in')
      + ' · ' + (access.role_name || 'Setup');
    if (!access.can_move_setup_assets) {
      setFeedback('blocked', 'This signed-in account is not authorized to record Setup locations.');
      throw new Error('Setup asset movement is not authorized for this account.');
    }
  }

  async function loadReferenceSet() {
    let source = 'network';
    try {
      const response = await fetch('location-references.json', {cache: 'no-store'});
      if (!response.ok) throw new Error('Reference HTTP ' + response.status);
      referenceSet = await response.json();
      localStorage.setItem(REFERENCE_CACHE_KEY, JSON.stringify({
        saved_at: new Date().toISOString(),
        data: referenceSet
      }));
    } catch (_error) {
      source = 'offline cache';
      const cached = localStorage.getItem(REFERENCE_CACHE_KEY);
      if (cached) {
        const parsed = JSON.parse(cached);
        referenceSet = parsed.data || null;
      }
    }

    populateReferenceSelect();
    if (!referenceSet) {
      referenceStatus.textContent = 'No named reference set is available. Raw GPS and a manual location note can still be recorded.';
      return;
    }
    referenceStatus.textContent = 'Reference set ' + referenceSet.version
      + ' · source ' + referenceSet.source
      + ' · loaded from ' + source
      + '. Reference points may be refreshed without changing historical raw GPS.';
  }

  function referencePoints() {
    return Array.isArray(referenceSet && referenceSet.points) ? referenceSet.points : [];
  }

  function populateReferenceSelect() {
    knownReference.innerHTML = '<option value="">No named location confirmed</option>';
    referencePoints().forEach(function (point) {
      const option = document.createElement('option');
      option.value = point.name;
      option.textContent = point.name;
      knownReference.appendChild(option);
    });
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
    return referencePoints().map(function (point) {
      return {
        name: point.name,
        distance_ft: distanceFeet(snapshot.latitude, snapshot.longitude, point.latitude, point.longitude)
      };
    }).sort(function (a, b) { return a.distance_ft - b.distance_ft; });
  }

  function renderGps() {
    if (watchId === null) {
      gpsState.textContent = 'GPS OFF';
      gpsToggle.textContent = 'Start GPS';
      gpsCandidates.textContent = 'GPS is off. Start it when location evidence is needed.';
      gpsCandidateButtons.innerHTML = '';
      return;
    }

    gpsToggle.textContent = 'Stop GPS';
    const snapshot = currentGpsSnapshot();
    if (!snapshot) {
      gpsState.textContent = latestPosition ? 'GPS STALE — waiting for current fix' : 'GPS acquiring…';
      gpsCandidates.textContent = 'Waiting for a current GPS fix…';
      gpsCandidateButtons.innerHTML = '';
      return;
    }

    const accuracyFt = Number(snapshot.accuracy_m || 0) * 3.280839895;
    gpsState.textContent = 'GPS ±' + accuracyFt.toFixed(0) + ' ft · fix '
      + (snapshot.fix_age_ms / 1000).toFixed(1) + ' sec old';

    const ranked = rankedReferences(snapshot).slice(0, 3);
    gpsCandidates.textContent = ranked.length
      ? 'Nearest: ' + ranked.map(function (item) {
          return item.name + ' ' + item.distance_ft.toFixed(0) + ' ft';
        }).join(' · ')
      : 'Raw GPS fix available; no named reference set is loaded.';

    gpsCandidateButtons.innerHTML = '';
    ranked.forEach(function (item) {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = item.name + ' · ' + item.distance_ft.toFixed(0) + ' ft';
      button.addEventListener('click', function () {
        knownReference.value = item.name;
        setFeedback('ready', 'LOCATION CONFIRMED — ' + item.name);
      });
      gpsCandidateButtons.appendChild(button);
    });
  }

  function startGps() {
    if (watchId !== null) return;
    if (!navigator.geolocation) {
      setFeedback('warning', 'GPS is not available in this browser.');
      return;
    }
    latestPosition = null;
    watchId = navigator.geolocation.watchPosition(
      function (position) {
        latestPosition = position;
        renderGps();
      },
      function (error) {
        setFeedback('warning', 'GPS unavailable — ' + (error.message || error));
        stopGps();
      },
      {enableHighAccuracy: true, maximumAge: 0, timeout: 15000}
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
    return String(locationNote.value || '').trim()
      || String(knownReference.value || '').trim()
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
      gps_quality: String(gpsQuality.value || 'UNASSESSED').toUpperCase(),
      gps_quality_note: String(gpsQualityNote.value || '').trim() || null
    };
  }

  function referenceProvenanceNote() {
    const version = referenceSet && referenceSet.version ? referenceSet.version : null;
    const reference = String(knownReference.value || '').trim() || null;
    if (!version && !reference) return null;
    const parts = [];
    if (version) parts.push('location_reference_set=' + version);
    if (reference) parts.push('location_reference=' + reference);
    return parts.join('; ');
  }

  function movementPayload(identity, action, captureMethod, unloadedDisplayIds) {
    const payload = {
      season_year: seasonYear(),
      client_event_id: uuid(),
      asset_type: identity.asset_type,
      asset_id: identity.asset_id,
      movement_action: action,
      occurred_at: new Date().toISOString(),
      device_id: deviceId(),
      captured_operator_email: String((access && access.authenticated_email) || '').trim().toLowerCase(),
      capture_method: captureMethod,
      offline_captured: !navigator.onLine,
      destination_location_note: action === 'RETURNED' ? null : destinationNote(),
      notes: action === 'RETURNED' ? null : referenceProvenanceNote(),
      unloaded_display_ids: unloadedDisplayIds || [],
      gps_quality: String(gpsQuality.value || 'UNASSESSED').toUpperCase(),
      gps_quality_note: String(gpsQualityNote.value || '').trim() || null
    };
    return Object.assign(payload, gpsPayload());
  }

  async function postMovement(payload) {
    if (trainingMode) {
      throw new Error('Training Mode blocks Setup movement writes.');
    }
    const data = await apiJson('../api/setup/movements', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-MSB-Setup-Command': '1'
      },
      body: JSON.stringify(payload)
    });
    return data.movement || {};
  }

  async function queueMovement(payload) {
    if (trainingMode) {
      throw new Error('Training Mode blocks the offline movement queue.');
    }
    await putQueue(Object.assign({}, payload, {
      offline_captured: true,
      queue_status: 'QUEUED'
    }));
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

  async function fetchState(identity) {
    const url = '../api/setup/movements/state?season_year=' + encodeURIComponent(seasonYear())
      + '&asset_type=' + encodeURIComponent(identity.asset_type)
      + '&asset_id=' + encodeURIComponent(identity.asset_id);
    const data = await apiJson(url, {cache: 'no-store'});
    return data.state || null;
  }

  async function fetchContainerContents(containerId) {
    const url = '../api/setup/movements/container-contents?season_year=' + encodeURIComponent(seasonYear())
      + '&container_id=' + encodeURIComponent(containerId);
    const data = await apiJson(url, {cache: 'no-store'});
    return data.container || null;
  }

  function clearPending() {
    pendingIdentity = null;
    pendingCaptureMethod = 'HID_SCAN';
    pendingContents = null;
    pendingStateRow = null;
    pendingPanel.hidden = true;
    pendingTitle.textContent = '';
    pendingState.textContent = '';
    unloadGroups.innerHTML = '';
    returnHome.hidden = true;
  }

  function selectedUnloadedDisplayIds() {
    const result = [];
    unloadGroups.querySelectorAll('input[data-display-ids]:checked').forEach(function (input) {
      String(input.dataset.displayIds || '').split(',').map(Number).forEach(function (id) {
        if (Number.isSafeInteger(id) && id > 0) result.push(id);
      });
    });
    return Array.from(new Set(result));
  }

  function setAllUnloadGroups(checked) {
    unloadGroups.querySelectorAll('input[data-display-ids]:not(:disabled)').forEach(function (input) {
      input.checked = checked;
    });
  }

  function renderPending() {
    if (!pendingIdentity) return;
    pendingPanel.hidden = false;
    const label = (pendingContents && pendingContents.label)
      || (pendingStateRow && pendingStateRow.label)
      || pendingIdentity.identity;
    pendingTitle.textContent = pendingIdentity.identity + ' — ' + label;
    const status = (pendingContents && pendingContents.movement_status)
      || (pendingStateRow && pendingStateRow.movement_status)
      || 'No prior movement state';
    pendingState.textContent = 'Current Setup state: ' + String(status).replaceAll('_', ' ');
    returnHome.hidden = pendingIdentity.asset_type !== 'CONTAINER';

    if (pendingIdentity.asset_type !== 'CONTAINER') {
      unloadGroups.innerHTML = '<p>Recording this Display here detaches only this Display from its Container. Later Container moves will not move it.</p>';
      return;
    }

    if (!pendingContents) {
      unloadGroups.innerHTML = '<div class="group-warning"><strong>Container contents unavailable.</strong> You may record the Container location, but Display unload groups are disabled so offline/stale data cannot detach the wrong Displays.</div>';
      return;
    }

    const groups = Array.isArray(pendingContents.groups) ? pendingContents.groups : [];
    if (!groups.length) {
      unloadGroups.innerHTML = '<p>No active Displays remain with this Container. Record the Container location only.</p>';
      return;
    }

    const selectable = groups.filter(function (group) { return group.bulk_selectable; });
    const reviewOnly = groups.filter(function (group) { return !group.bulk_selectable; });
    unloadGroups.innerHTML = '<div class="group-heading"><strong>What came off here?</strong><span>Anything not selected stays WITH_CONTAINER and follows the next Container location.</span></div>';

    selectable.forEach(function (group) {
      const label = document.createElement('label');
      label.className = 'unload-group';
      const input = document.createElement('input');
      input.type = 'checkbox';
      input.dataset.displayIds = (group.display_ids || []).join(',');
      const span = document.createElement('span');
      span.innerHTML = '<strong>' + escapeHtml(group.label) + '</strong><br>'
        + Number(group.display_count || 0) + ' Display'
        + (Number(group.display_count || 0) === 1 ? '' : 's') + ' came off here';
      label.appendChild(input);
      label.appendChild(span);
      unloadGroups.appendChild(label);
    });

    if (selectable.length) {
      const actions = document.createElement('div');
      actions.className = 'group-actions';
      const all = document.createElement('button');
      all.type = 'button';
      all.textContent = 'All remaining groups';
      all.addEventListener('click', function () { setAllUnloadGroups(true); });
      const none = document.createElement('button');
      none.type = 'button';
      none.textContent = 'None came off';
      none.addEventListener('click', function () { setAllUnloadGroups(false); });
      actions.appendChild(all);
      actions.appendChild(none);
      unloadGroups.appendChild(actions);
    }

    reviewOnly.forEach(function (group) {
      const warning = document.createElement('div');
      warning.className = 'group-warning';
      warning.innerHTML = '<strong>' + escapeHtml(group.label) + '</strong> · '
        + Number(group.display_count || 0) + ' Display'
        + (Number(group.display_count || 0) === 1 ? '' : 's');
      unloadGroups.appendChild(warning);
    });
  }

  async function selectIdentity(identity, captureMethod) {
    if (!access || !access.can_move_setup_assets) {
      setFeedback('blocked', 'Movement authorization is not available.');
      return;
    }

    pendingIdentity = identity;
    pendingCaptureMethod = captureMethod;
    pendingContents = null;
    pendingStateRow = null;
    setFeedback('ready', identity.identity + ' — loading current movement context…');

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
        setFeedback('warning', identity.identity + ' — ' + (error.message || error));
        return;
      }
      pendingStateRow = {
        label: identity.identity,
        movement_status: 'OFFLINE — CURRENT CONTEXT UNAVAILABLE'
      };
    }

    renderPending();
    setFeedback('ready', identity.identity + ' — review location evidence, then RECORD HERE');
  }

  async function recordPending(returningHome) {
    if (!pendingIdentity) {
      setFeedback('blocked', 'Select a Container or Display first.');
      return;
    }

    const identity = pendingIdentity;
    const action = returningHome
      ? 'RETURNED'
      : (identity.asset_type === 'CONTAINER' ? 'CONTAINER_MOVE' : 'DISPLAY_MOVE');

    if (!returningHome && !currentGpsSnapshot() && !destinationNote()) {
      setFeedback('blocked', 'LOCATION NEEDED — start GPS, confirm a named reference, or enter a location note.');
      return;
    }

    const unloaded = action === 'CONTAINER_MOVE' ? selectedUnloadedDisplayIds() : [];
    const payload = movementPayload(identity, action, pendingCaptureMethod, unloaded);

    if (trainingMode) {
      const gps = currentGpsSnapshot();
      const reference = String(knownReference.value || '').trim();
      const note = destinationNote();
      let message = 'TRAINING — WOULD RECORD ' + identity.identity;
      if (returningHome) {
        message += ' RETURNED HOME';
      } else {
        message += ' HERE';
        if (reference) message += ' · ' + reference;
        else if (note) message += ' · ' + note;
        if (gps) message += ' · GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft';
        if (unloaded.length) message += ' · would leave ' + unloaded.length + ' Display' + (unloaded.length === 1 ? '' : 's') + ' here';
      }
      setFeedback('success', message + ' · NOTHING RECORDED');
      clearPending();
      knownReference.value = '';
      locationNote.value = '';
      gpsQuality.value = 'UNASSESSED';
      gpsQualityNote.value = '';
      return;
    }

    setFeedback('ready', identity.identity + ' — recording physical observation…');

    try {
      const result = await sendOrQueue(payload);
      if (result.queued) {
        setFeedback('offline', identity.identity + ' — OBSERVATION QUEUED OFFLINE');
      } else if (returningHome) {
        setFeedback('success', identity.identity + ' — RETURNED HOME '
          + String((result.movement && result.movement.home_location_code) || ''));
      } else {
        const movement = result.movement || {};
        const unloadCount = Number(movement.unloaded_display_count || 0);
        const gps = currentGpsSnapshot();
        let message = identity.identity + ' — LOCATION RECORDED';
        if (unloadCount) message += ' · ' + unloadCount + ' Display' + (unloadCount === 1 ? '' : 's') + ' left here';
        if (gps) message += ' · GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft';
        setFeedback('success', message);
      }

      clearPending();
      knownReference.value = '';
      locationNote.value = '';
      gpsQuality.value = 'UNASSESSED';
      gpsQualityNote.value = '';
    } catch (error) {
      setFeedback('warning', identity.identity + ' — ' + (error.message || error));
    }
  }

  async function handleIdentity(raw, captureMethod) {
    const identity = parseIdentity(raw);
    if (!identity) {
      setFeedback('blocked', 'INVALID IDENTITY — expected CONT:<id>, DISP:<id>, or a permanent scan URL.');
      return;
    }
    await selectIdentity(identity, captureMethod);
  }

  function clearScanTimer() {
    if (scanResetTimer) window.clearTimeout(scanResetTimer);
    scanResetTimer = null;
  }

  function scheduleScanReset() {
    clearScanTimer();
    scanResetTimer = window.setTimeout(function () {
      scanBuffer = '';
      scanResetTimer = null;
    }, SCAN_RESET_MS);
  }

  function isEditableTarget(target) {
    return target instanceof HTMLInputElement
      || target instanceof HTMLTextAreaElement
      || target instanceof HTMLSelectElement
      || (target && target.isContentEditable);
  }

  function captureKeydown(event) {
    if (event.defaultPrevented || event.isComposing) return;
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

  async function searchAssets() {
    const q = String(searchInput.value || '').trim();
    if (!q) return;
    searchResults.textContent = 'Searching…';
    try {
      const data = await apiJson('../api/setup/movements/search?q=' + encodeURIComponent(q), {cache: 'no-store'});
      const rows = Array.isArray(data.assets) ? data.assets : [];
      searchResults.innerHTML = '';
      if (!rows.length) {
        searchResults.textContent = 'No matching Container or Display.';
        return;
      }
      rows.forEach(function (row) {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = row.identity + ' — ' + (row.label || '');
        button.addEventListener('click', function () {
          void handleIdentity(row.identity, 'TOUCH_SELECT');
        });
        searchResults.appendChild(button);
      });
    } catch (error) {
      searchResults.textContent = 'Search unavailable — ' + (error.message || error);
    }
  }

  async function stopCamera() {
    if (cameraFrame) cancelAnimationFrame(cameraFrame);
    cameraFrame = null;
    if (cameraStream) cameraStream.getTracks().forEach(function (track) { track.stop(); });
    cameraStream = null;
    cameraVideo.srcObject = null;
    cameraPanel.hidden = true;
    cameraToggle.textContent = 'Scan with Camera';
    cameraStatus.textContent = 'Camera off';
  }

  async function scanCameraFrame() {
    if (!cameraStream || !barcodeDetector) return;
    try {
      const codes = await barcodeDetector.detect(cameraVideo);
      if (codes && codes.length) {
        const raw = String(codes[0].rawValue || '');
        const identity = parseIdentity(raw);
        if (identity) {
          await stopCamera();
          await selectIdentity(identity, 'CAMERA_SCAN');
          return;
        }
      }
    } catch (_error) {}
    if (cameraStream) cameraFrame = requestAnimationFrame(scanCameraFrame);
  }

  async function startCamera() {
    if (cameraStream) {
      await stopCamera();
      return;
    }
    if (!('BarcodeDetector' in window)) {
      setFeedback('warning', 'This browser does not support direct camera barcode detection. Use the normal MSB Scan app, Zebra, Find, or manual entry.');
      return;
    }
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      setFeedback('warning', 'Camera access is unavailable in this browser.');
      return;
    }

    try {
      const supported = await window.BarcodeDetector.getSupportedFormats();
      const formats = supported.indexOf('qr_code') >= 0 ? ['qr_code'] : supported;
      barcodeDetector = new window.BarcodeDetector({formats: formats});
      cameraStream = await navigator.mediaDevices.getUserMedia({
        video: {facingMode: {ideal: 'environment'}},
        audio: false
      });
      cameraVideo.srcObject = cameraStream;
      await cameraVideo.play();
      cameraPanel.hidden = false;
      cameraToggle.textContent = 'Stop Camera';
      cameraStatus.textContent = 'Camera scanning';
      cameraFrame = requestAnimationFrame(scanCameraFrame);
    } catch (error) {
      await stopCamera();
      setFeedback('warning', 'Camera start failed — ' + (error.message || error));
    }
  }

  async function syncQueue() {
    if (trainingMode || syncing || !navigator.onLine) return;
    syncing = true;
    try {
      const rows = await queueRows();
      for (const row of rows) {
        try {
          await postMovement(Object.assign({}, row, {offline_captured: true}));
          await deleteQueue(row.client_event_id);
        } catch (error) {
          if (!error.httpStatus || error.httpStatus >= 500) break;
          await putQueue(Object.assign({}, row, {
            queue_status: 'FAILED',
            last_error: String(error.message || error)
          }));
          setFeedback('blocked', 'OFFLINE SYNC NEEDS REVIEW — '
            + row.asset_type + ':' + row.asset_id + ' — ' + (error.message || error));
          break;
        }
      }
      await refreshQueueState();
    } finally {
      syncing = false;
    }
  }

  async function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) return;
    try {
      await navigator.serviceWorker.register('service-worker.js', {scope: './'});
      await navigator.serviceWorker.ready;
    } catch (_error) {}
  }

  manualGo.addEventListener('click', function () {
    if (manualInput.value.trim()) void handleIdentity(manualInput.value, 'MANUAL_ENTRY');
  });
  manualInput.addEventListener('keydown', function (event) {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    if (manualInput.value.trim()) void handleIdentity(manualInput.value, 'MANUAL_ENTRY');
  });
  searchGo.addEventListener('click', function () { void searchAssets(); });
  searchInput.addEventListener('keydown', function (event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      void searchAssets();
    }
  });
  cameraToggle.addEventListener('click', function () { void startCamera(); });
  gpsToggle.addEventListener('click', function () {
    if (watchId === null) startGps();
    else stopGps();
  });
  recordHere.addEventListener('click', function () { void recordPending(false); });
  returnHome.addEventListener('click', function () { void recordPending(true); });
  clearPendingButton.addEventListener('click', function () {
    clearPending();
    setFeedback('ready', 'READY — scan, search, or choose an asset');
  });
  knownReference.addEventListener('change', function () {
    if (knownReference.value) setFeedback('ready', 'LOCATION CONFIRMED — ' + knownReference.value);
  });
  trainingEnter.addEventListener('click', enterTrainingMode);
  trainingExit.addEventListener('click', exitTrainingMode);
  el('back-setup').addEventListener('click', function () {
    location.href = '../';
  });
  document.addEventListener('keydown', captureKeydown, true);
  window.addEventListener('online', function () {
    updateNetwork();
    void syncQueue();
    void loadReferenceSet();
  });
  window.addEventListener('offline', updateNetwork);
  window.addEventListener('pagehide', function () { void stopCamera(); });
  window.setInterval(function () { renderGps(); }, 1000);

  async function initialize() {
    applyTrainingMode();
    stopGps();
    updateNetwork();
    await refreshQueueState();
    void registerServiceWorker();
    try {
      await loadAccess();
    } catch (error) {
      setFeedback('blocked', error.message || error);
      return;
    }
    await loadReferenceSet();
    if (navigator.onLine && !trainingMode) void syncQueue();

    const requested = pageParams.get('asset');
    if (requested) {
      const identity = parseIdentity(requested);
      if (identity) {
        await selectIdentity(identity, 'TOUCH_SELECT');
      } else {
        setFeedback('warning', 'The supplied Record Location asset was not a valid CONT:/DISP: identity.');
      }
    }
  }

  void initialize();
})();
