(() => {
  'use strict';

  const el = (id) => document.getElementById(id);
  const manualInput = el('movement-manual-input');
  const manualGo = el('movement-manual-go');
  const searchInput = el('movement-search-input');
  const searchGo = el('movement-search-go');
  const searchResults = el('movement-search-results');
  const scannerToggle = el('movement-scanner-toggle');
  const scannerStatus = el('movement-scanner-status');
  const identityTitle = el('movement-identity-title');
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
  const referenceStatus = el('movement-reference-status');
  const pendingPanel = el('movement-pending');
  const pendingTitle = el('movement-pending-title');
  const pendingState = el('movement-pending-state');
  const homeLocationReview = el('movement-home-location');
  const reviewLocation = el('movement-review-location');
  const unloadGroups = el('movement-unload-groups');
  const selectionSummary = el('movement-selection-summary');
  const reviewDialog = el('movement-review-dialog');
  const reviewBody = el('movement-review-body');
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
  const locationPanel = document.querySelector('.location-panel');

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
  let contentsDecision = null;
  let identifyRemaining = false;
  let unloadedHereDisplayIds = new Set();
  let contentsView = 'UNLOAD';
  let remainingDisplayIds = null;
  let remainingSearch = '';
  let reviewing = false;
  let displayPlacement = null;
  let placementStageId = null;
  let recording = false;
  let selectionGeneration = 0;
  let scanBuffer = '';
  let scanResetTimer = null;
  let scannerActive = false;
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

  function renderScannerLayoutState() {
    document.body.classList.toggle('record-location-scanner-active', scannerActive);
    document.body.classList.toggle('record-location-dock-visible', Boolean(pendingIdentity));
    document.body.classList.toggle(
      'record-location-asset-pending',
      Boolean(scannerActive && pendingIdentity)
    );

    if (!identityTitle) return;
    if (scannerActive && pendingIdentity) {
      identityTitle.textContent = pendingIdentity.identity + ' — location pending';
    } else if (scannerActive) {
      identityTitle.textContent = 'RECORD LOCATION — SCANNER';
    } else {
      identityTitle.textContent = 'Container / Display';
    }
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
    renderRecordReadiness();
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
      renderRecordReadiness();
      return;
    }

    gpsToggle.textContent = 'Stop GPS';
    const snapshot = currentGpsSnapshot();
    if (!snapshot) {
      gpsState.textContent = latestPosition ? 'GPS STALE — waiting for current fix' : 'GPS acquiring…';
      gpsCandidates.textContent = 'Waiting for a current GPS fix…';
      gpsCandidateButtons.innerHTML = '';
      renderRecordReadiness();
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
        const stage = placementStages().find(row => String(row.stage_key) === item.name.split('-')[0]);
        if (needsDisplayPlacement() && displayPlacement === 'YES' && stage) {
          confirmPlacementStage(stage.stage_id);
          renderDisplayPlacement();
        }
        renderRecordReadiness();
        restoreScannerCapture();
      });
      gpsCandidateButtons.appendChild(button);
    });
    renderRecordReadiness();
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

  function currentLocationEvidence() {
    const reference = String(knownReference.value || '').trim();
    const note = String(locationNote.value || '').trim();
    const gps = currentGpsSnapshot();

    const stage = needsDisplayPlacement() && displayPlacement === 'YES'
      && placementStages().find(row => Number(row.stage_id) === placementStageId);
    if (stage) {
      return {
        ready: true,
        label: stage.stage_key + ' · ' + stage.stage_name,
        detail: 'Actual Stage confirmed' + (gps ? ' · GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft' : '')
      };
    }

    if (note) {
      const context = [];
      if (reference) context.push('named reference ' + reference + ' confirmed');
      if (gps) context.push('GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft');
      return {
        ready: true,
        label: note,
        detail: context.length ? 'Location note · ' + context.join(' · ') : 'Location note'
      };
    }
    if (reference) {
      return {
        ready: true,
        label: reference,
        detail: gps
          ? 'Named reference confirmed · GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft'
          : 'Named reference confirmed'
      };
    }
    if (gps) {
      return {
        ready: true,
        label: 'current GPS',
        detail: 'Current GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft'
      };
    }
    return {
      ready: false,
      label: null,
      detail: 'Location needed — start GPS, confirm a named reference, or enter a location note.'
    };
  }

  function renderRecordReadiness() {
    if (!recordHere || !reviewLocation) return;
    if (!pendingIdentity) {
      recordHere.disabled = true;
      recordHere.textContent = trainingMode ? 'Choose a location first' : 'Choose a location first';
      reviewLocation.className = 'review-location blocked';
      reviewLocation.textContent = 'Location needed — scan or choose an asset first.';
      return;
    }

    const evidence = currentLocationEvidence();
    const decisionReady = pendingIdentity.asset_type !== 'CONTAINER'
      || selectedUnloadedDisplayIds().length > 0 || Boolean(contentsDecision);
    renderSelectionSummary();
    recordHere.disabled = recording || reviewing || !evidence.ready || !decisionReady
      || (needsDisplayPlacement() && (displayPlacement !== 'YES' || !placementStageId))
      || (pendingIdentity.asset_type === 'DISPLAY' && pendingStateRow && pendingStateRow.can_detach === false);
    if (pendingIdentity.asset_type === 'CONTAINER') {
      returnHome.disabled = recording || reviewing || contentsDecision !== 'EMPTY' || !pendingContents
        || !pendingContents.reconciliation_allowed || !pendingContents.home_location_code;
    }
    reviewLocation.className = 'review-location ' + (evidence.ready ? 'ready' : 'blocked');

    if (evidence.ready) {
      reviewLocation.innerHTML = '<strong>Location confirmed:</strong> '
        + escapeHtml(evidence.label)
        + '<div class="muted">' + escapeHtml(evidence.detail) + '</div>';
      recordHere.textContent = (trainingMode ? 'Review test' : 'Review and record')
        + ' · ' + pendingIdentity.identity;
    } else {
      reviewLocation.textContent = evidence.detail;
      recordHere.textContent = 'Choose a location first';
    }
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
      gps_quality: 'UNASSESSED',
      gps_quality_note: null
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
      gps_quality: 'UNASSESSED',
      gps_quality_note: null
    };
    return action === 'RETURNED' ? payload : Object.assign(payload, gpsPayload());
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
    if (!navigator.onLine || (await queueRows()).length) {
      await queueMovement(payload);
      if (navigator.onLine) void syncQueue();
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
    const key = 'msb.setup.display-context.' + seasonYear() + '.' + identity.asset_id;
    let state;
    try {
      const data = await apiJson(url, {cache: 'no-store'});
      state = data.state || null;
      localStorage.setItem(key, JSON.stringify(state));
    } catch (error) {
      if (navigator.onLine) throw error;
      state = JSON.parse(localStorage.getItem(key) || 'null');
      if (!state) throw error;
    }
    const rows = await queueRows().catch(() => []);
    if (state && rows.some(row => row.asset_type === 'DISPLAY' && Number(row.asset_id) === identity.asset_id
        && Number(row.season_year) === seasonYear() && row.movement_action === 'DISPLAY_MOVE'
        && row.queue_status !== 'FAILED')) state.position_mode = 'DETACHED';
    return state;
  }

  function applyQueuedContainerContext(contents, rows, containerId) {
    if (!contents) return null;
    const context = JSON.parse(JSON.stringify(contents));
    // Direct Display scans drain before later Container commands in the same queue.
    const detached = rows.filter(row => row.asset_type === 'DISPLAY' && row.movement_action === 'DISPLAY_MOVE'
      && row.queue_status !== 'FAILED' && Number(row.season_year) === seasonYear()).map(row => Number(row.asset_id));
    context.displays = (context.displays || []).filter(display => !detached.includes(Number(display.display_id)));
    const queued = rows.filter(row => row.asset_type === 'CONTAINER'
      && Number(row.asset_id) === Number(containerId) && Number(row.season_year) === seasonYear())
      .sort((a, b) => String(a.occurred_at).localeCompare(String(b.occurred_at)));
    for (const row of queued) {
      if (row.queue_status === 'FAILED') {
        context.reconciliation_allowed = false;
        context.queue_conflict = true;
        break;
      }
      if (context.last_movement_at && Date.parse(row.occurred_at) <= Date.parse(context.last_movement_at)) continue;
      const decision = row.reconciliation;
      if (decision && (decision.decision === 'EMPTY' || decision.identify_remaining)) {
        const remaining = decision.remaining_display_ids || [];
        context.displays = (context.displays || []).filter(display => remaining.includes(Number(display.display_id)));
      } else if ((row.unloaded_display_ids || []).length) {
        context.displays = (context.displays || []).filter(display => !row.unloaded_display_ids.includes(Number(display.display_id)));
      }
      const previous = context.prior_location;
      context.prior_location = {
        event_type: row.movement_action, occurred_at: row.occurred_at,
        destination_location_note: row.destination_location_note,
        named_context: row.movement_action === 'RETURNED' ? null :
          (row.destination_location_note || (previous && previous.named_context)),
        gps_latitude: row.gps_latitude, gps_longitude: row.gps_longitude, gps_accuracy_m: row.gps_accuracy_m
      };
      context.last_movement_event_id = null;
      context.prior_client_event_id = row.client_event_id;
      context.movement_status = row.movement_action + ' · queued offline';
      context.last_movement_at = row.occurred_at;
    }
    // The original Stage groups must reflect locally queued detachments too.
    const remainingIds = new Set((context.displays || []).map(display => Number(display.display_id)));
    context.groups = (context.groups || []).map(group => {
      const displays = (group.displays || []).filter(display => remainingIds.has(Number(display.display_id)));
      return Object.assign({}, group, {displays, display_ids: displays.map(display => Number(display.display_id)), display_count: displays.length});
    }).filter(group => group.display_count > 0);
    return context;
  }

  async function fetchContainerContents(containerId) {
    const url = '../api/setup/movements/container-contents?season_year=' + encodeURIComponent(seasonYear())
      + '&container_id=' + encodeURIComponent(containerId);
    const key = 'msb.setup.container-context.' + seasonYear() + '.' + containerId;
    try {
      const data = await apiJson(url, {cache: 'no-store'});
      localStorage.setItem(key, JSON.stringify(data.container));
      return applyQueuedContainerContext(data.container || null, await queueRows().catch(() => []), containerId);
    } catch (error) {
      if (navigator.onLine) throw error;
      const cached = localStorage.getItem(key);
      if (!cached) throw error;
      return applyQueuedContainerContext(JSON.parse(cached), await queueRows(), containerId);
    }
  }

  function clearPending() {
    selectionGeneration += 1;
    contentsDecision = null;
    identifyRemaining = false;
    unloadedHereDisplayIds = new Set();
    contentsView = 'UNLOAD';
    remainingDisplayIds = null;
    remainingSearch = '';
    displayPlacement = null;
    placementStageId = null;
    pendingIdentity = null;
    pendingCaptureMethod = 'HID_SCAN';
    pendingContents = null;
    pendingStateRow = null;
    pendingPanel.hidden = true;
    pendingTitle.textContent = '';
    pendingState.textContent = '';
    if (homeLocationReview) {
      homeLocationReview.hidden = true;
      homeLocationReview.textContent = '';
    }
    unloadGroups.innerHTML = '';
    returnHome.hidden = true;
    returnHome.disabled = false;
    returnHome.textContent = trainingMode ? 'Test Return Home' : 'Returned to Home Location';
    renderScannerLayoutState();
    renderRecordReadiness();
  }

  function currentDisplays() {
    return pendingContents && Array.isArray(pendingContents.displays) ? pendingContents.displays : [];
  }

  function selectableUnloadGroups() {
    if (!pendingContents || !pendingContents.reconciliation_allowed) return [];
    const attached = new Set(currentDisplays().map(display => Number(display.display_id)));
    return (pendingContents.groups || []).filter(group => group.bulk_selectable).map(group => {
      const ids = (group.display_ids || []).map(Number).filter(id => attached.has(id));
      return Object.assign({}, group, {display_ids: ids,
        displays: (group.displays || []).filter(display => ids.includes(Number(display.display_id)))});
    }).filter(group => group.display_ids.length > 0);
  }

  function selectedUnloadedDisplayIds() {
    const allowed = new Set(selectableUnloadGroups().flatMap(group => group.display_ids));
    return Array.from(unloadedHereDisplayIds).filter(id => allowed.has(id));
  }

  function selectUnloadHere(ids, checked) {
    ids.forEach(id => checked ? unloadedHereDisplayIds.add(Number(id)) : unloadedHereDisplayIds.delete(Number(id)));
    // Direct observation and prior-location inference are mutually exclusive.
    contentsDecision = selectedUnloadedDisplayIds().length ? null : 'NOT_EMPTY';
    identifyRemaining = false;
    remainingDisplayIds = null;
    // Do not rebuild rows on a checkbox change: expanded names and focus stay put.
    unloadGroups.querySelectorAll('input[data-display-ids]').forEach(input => {
      input.checked = String(input.dataset.displayIds).split(',').map(Number)
        .every(id => unloadedHereDisplayIds.has(id));
    });
    renderRecordReadiness();
  }

  function setAllUnloadGroups(checked) {
    unloadedHereDisplayIds = new Set();
    selectUnloadHere(selectableUnloadGroups().flatMap(group => group.display_ids), checked);
  }

  function appendNames(parent, title, rows) {
    const details = document.createElement('details');
    details.className = 'display-names';
    const summary = document.createElement('summary');
    summary.textContent = title + ' · ' + rows.length + ' Displays';
    const names = document.createElement('ul');
    rows.forEach(row => {
      const item = document.createElement('li');
      item.textContent = row.display_name;
      names.appendChild(item);
    });
    details.appendChild(summary);
    details.appendChild(names);
    parent.appendChild(details);
  }

  function switchContentsView(view) {
    contentsView = view;
    unloadedHereDisplayIds = new Set();
    contentsDecision = null;
    identifyRemaining = false;
    remainingDisplayIds = null;
    remainingSearch = '';
    renderContentsDecision();
    renderRecordReadiness();
  }

  function renderUnloadHere() {
    const heading = document.createElement('h3');
    heading.textContent = 'What came off here?';
    unloadGroups.appendChild(heading);
    const prompt = document.createElement('p');
    prompt.textContent = 'Select Stage groups unloaded here. Other Displays stay on this Container.';
    unloadGroups.appendChild(prompt);
    const actions = document.createElement('div');
    actions.className = 'group-actions';
    [['All remaining groups', true], ['None came off', false]].forEach(([text, checked]) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = text;
      button.addEventListener('click', () => setAllUnloadGroups(checked));
      actions.appendChild(button);
    });
    unloadGroups.appendChild(actions);
    selectableUnloadGroups().forEach(group => {
      const card = document.createElement('div');
      card.className = 'unload-card';
      const label = document.createElement('label');
      label.className = 'unload-group';
      const input = document.createElement('input');
      input.type = 'checkbox';
      input.dataset.displayIds = group.display_ids.join(',');
      input.checked = group.display_ids.every(id => unloadedHereDisplayIds.has(id));
      input.addEventListener('change', () => selectUnloadHere(group.display_ids, input.checked));
      const span = document.createElement('span');
      span.innerHTML = '<strong>' + escapeHtml(group.label) + '</strong><br>'
        + group.display_ids.length + ' Display' + (group.display_ids.length === 1 ? '' : 's');
      label.appendChild(input);
      label.appendChild(span);
      card.appendChild(label);
      // Names stay available without making a whole Stage's contents a checkbox target.
      appendNames(card, 'Show Displays', group.displays);
      unloadGroups.appendChild(card);
    });
    (pendingContents.groups || []).filter(group => !group.bulk_selectable).forEach(group => {
      const warning = document.createElement('div');
      warning.className = 'group-warning';
      const text = document.createElement('p');
      text.textContent = group.label + ' — scan these Displays individually';
      warning.appendChild(text);
      appendNames(warning, 'Show Displays', group.displays || []);
      unloadGroups.appendChild(warning);
    });
  }

  function selectedRemainingDisplayIds() {
    // Selection belongs to the asset, not to the filtered/visible DOM rows.
    const selected = remainingDisplayIds || new Set(currentDisplays().map(row => Number(row.display_id)));
    return currentDisplays().map(row => Number(row.display_id)).filter(id => selected.has(id));
  }

  function renderSelectionSummary() {
    if (!selectionSummary || !pendingIdentity) return;
    selectionSummary.innerHTML = '';
    const text = document.createElement('strong');
    const count = currentDisplays().length;
    const unloaded = selectedUnloadedDisplayIds();
    if (pendingIdentity.asset_type !== 'CONTAINER') {
      text.textContent = pendingIdentity.identity + ' · ' + (pendingStateRow && pendingStateRow.label || 'Display');
    } else if (unloaded.length) {
      text.textContent = unloaded.length + ' unloading HERE · ' + (count - unloaded.length) + ' staying';
    } else if (identifyRemaining) {
      const remaining = selectedRemainingDisplayIds().length;
      text.textContent = remaining + ' staying · ' + (count - remaining) + ' unloading at PRIOR location';
    } else if (contentsDecision === 'EMPTY') {
      text.textContent = count + ' unloading at PRIOR location · Container empty';
    } else if (contentsDecision) {
      text.textContent = 'Location only · ' + count + ' Displays stay attached';
    } else {
      text.textContent = 'No unload selected · ' + count + ' Displays on Container';
    }
    selectionSummary.appendChild(text);
    const location = document.createElement('div');
    location.className = 'selection-location';
    location.textContent = unloaded.length ? 'HERE: ' + (currentLocationEvidence().label || 'Choose a location')
      : (contentsDecision === 'EMPTY' || identifyRemaining) ? 'PRIOR: ' + priorLocationText()
      : currentLocationEvidence().label || 'Choose a location';
    selectionSummary.appendChild(location);
    if (unloaded.length) {
      const selected = document.createElement('div');
      selected.className = 'selected-stage-strip';
      selectableUnloadGroups().filter(group => group.display_ids.every(id => unloadedHereDisplayIds.has(id))).forEach(group => {
        const chip = document.createElement('span');
        chip.textContent = group.label;
        selected.appendChild(chip);
      });
      selectionSummary.appendChild(selected);
    }
  }

  function renderRemainingList(list) {
    list.innerHTML = '';
    const matching = currentDisplays().filter(row => row.display_name.toLowerCase().includes(remainingSearch.toLowerCase()));
    matching.forEach(row => {
      const label = document.createElement('label');
      label.className = 'unload-group';
      const input = document.createElement('input');
      input.type = 'checkbox';
      input.dataset.displayId = row.display_id;
      input.checked = selectedRemainingDisplayIds().includes(Number(row.display_id));
      input.addEventListener('change', () => {
        const id = Number(row.display_id);
        input.checked ? remainingDisplayIds.add(id) : remainingDisplayIds.delete(id);
        renderRecordReadiness();
      });
      const name = document.createElement('span');
      name.textContent = row.display_name;
      label.appendChild(input);
      label.appendChild(name);
      list.appendChild(label);
    });
    if (!matching.length) {
      const empty = document.createElement('p');
      empty.textContent = 'No matching Display Names. Selections are preserved.';
      list.appendChild(empty);
    }
  }

  function reconciliationPayload() {
    if (selectedUnloadedDisplayIds().length) throw new Error('Review the selected unload at the current location, or clear it before reconciling earlier unloads.');
    if (!contentsDecision) throw new Error('Choose Empty, Not Empty, or Not Sure first.');
    const result = {decision: contentsDecision, identify_remaining: identifyRemaining};
    if (contentsDecision === 'EMPTY' || identifyRemaining) {
      if (!pendingContents || !pendingContents.reconciliation_allowed) {
        throw new Error('Contents cannot be reconciled for this item. Choose Not Sure to record location only.');
      }
      result.prior_event_id = pendingContents.last_movement_event_id || null;
      if (pendingContents.prior_client_event_id) result.prior_client_event_id = pendingContents.prior_client_event_id;
      result.expected_display_ids = currentDisplays().map(row => Number(row.display_id));
      result.remaining_display_ids = identifyRemaining
        ? selectedRemainingDisplayIds()
        : [];
      if (identifyRemaining && !result.remaining_display_ids.length) {
        throw new Error('Not Empty requires at least one Display Name still present. Otherwise choose Empty.');
      }
    }
    return result;
  }

  function priorLocationText() {
    const prior = pendingContents && pendingContents.prior_location;
    if (!prior || prior.event_type === 'RETURNED'
        || prior.named_context === pendingContents.home_location_code) return 'Unload location unresolved';
    let text = prior.named_context || prior.destination_location_note ||
      (prior.destination_stage_id ? 'previous recorded Stage' : 'previous GPS observation');
    if (prior.gps_accuracy_m != null) text += ' · ±' + Math.round(Number(prior.gps_accuracy_m) / 0.3048) + ' ft';
    return text + ' · observed ' + prior.occurred_at;
  }

  function renderContentsDecision() {
    unloadGroups.innerHTML = '';
    if (!pendingIdentity || pendingIdentity.asset_type !== 'CONTAINER') return;
    const hasGroups = pendingContents && pendingContents.reconciliation_allowed && selectableUnloadGroups().length > 0;
    if (hasGroups) {
      const switcher = document.createElement('button');
      switcher.type = 'button';
      switcher.textContent = contentsView === 'UNLOAD' ? 'Check contents / missed earlier unload' : 'Back to unload here';
      switcher.addEventListener('click', () => switchContentsView(contentsView === 'UNLOAD' ? 'CONTENTS' : 'UNLOAD'));
      unloadGroups.appendChild(switcher);
      if (contentsView === 'UNLOAD') {
        renderUnloadHere();
        return;
      }
    }
    const earlier = document.createElement('h3');
    earlier.textContent = 'Missed an earlier unload? Review contents';
    unloadGroups.appendChild(earlier);
    const intro = document.createElement('p');
    intro.textContent = 'Prior last-known location: ' + priorLocationText();
    unloadGroups.appendChild(intro);
    const heading = document.createElement('h3');
    heading.textContent = 'Is this Container empty?';
    unloadGroups.appendChild(heading);
    const choices = document.createElement('div');
    choices.className = 'group-actions';
    [['EMPTY', 'Empty'], ['NOT_EMPTY', 'Not Empty'], ['NOT_SURE', 'Not Sure']].forEach(([value, label]) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = label;
      button.setAttribute('aria-pressed', String(contentsDecision === value));
      button.disabled = value === 'EMPTY' && (!pendingContents || !pendingContents.reconciliation_allowed);
      button.addEventListener('click', () => {
        unloadedHereDisplayIds = new Set();
        contentsDecision = value;
        identifyRemaining = false;
        remainingDisplayIds = null;
        remainingSearch = '';
        renderContentsDecision();
        renderRecordReadiness();
      });
      choices.appendChild(button);
    });
    unloadGroups.appendChild(choices);
    const explanation = document.createElement('p');
    if (!pendingContents) explanation.textContent = 'Contents context unavailable. Record location only; reconnect and rescan for reconciliation or Return Empty.';
    else if (pendingContents.queue_conflict) explanation.textContent = 'An earlier offline reconciliation failed. Reconnect and review it before changing contents or returning this Container.';
    else if (!pendingContents.reconciliation_allowed) explanation.textContent = 'This Standalone / singular Display-Pallet is one physical object. Its Display stays with it. Record the Container location only.';
    else if (selectedUnloadedDisplayIds().length) explanation.textContent = 'Selected Stage groups will unload at the current location. Choosing a contents answer switches to reconciliation at the prior location.';
    else if (contentsDecision === 'EMPTY') explanation.textContent = currentDisplays().length + ' Displays will stop following this Container. Their unload location is inferred from the prior observation, never this new scan or Workshop Home.';
    else if (contentsDecision === 'NOT_SURE') explanation.textContent = 'Location only. Displays keep following this Container; contents need later review.';
    else explanation.textContent = 'No Displays change until you identify what remains and review the result.';
    unloadGroups.appendChild(explanation);
    if (contentsDecision !== 'NOT_EMPTY' || !pendingContents || !pendingContents.reconciliation_allowed) return;
    const identify = document.createElement('button');
    identify.type = 'button';
    identify.textContent = identifyRemaining ? 'I cannot identify what remains — location only' : 'I can identify what remains';
    identify.addEventListener('click', () => {
      identifyRemaining = !identifyRemaining;
      remainingDisplayIds = identifyRemaining ? new Set(currentDisplays().map(row => Number(row.display_id))) : null;
      remainingSearch = '';
      renderContentsDecision();
      renderRecordReadiness();
    });
    unloadGroups.appendChild(identify);
    if (!identifyRemaining) return;
    const prompt = document.createElement('p');
    prompt.textContent = 'Which Display Names are STILL on this Container? Checked names stay with it. Unchecked names came off at the prior last-known location.';
    unloadGroups.appendChild(prompt);
    if (!remainingDisplayIds) remainingDisplayIds = new Set(currentDisplays().map(row => Number(row.display_id)));
    const searchLabel = document.createElement('label');
    searchLabel.className = 'remaining-search';
    searchLabel.textContent = 'Find a Display Name';
    const search = document.createElement('input');
    search.type = 'search';
    search.placeholder = 'Search names — selections stay checked';
    search.value = remainingSearch;
    const list = document.createElement('div');
    search.addEventListener('focus', () => pauseScannerForTyping('searching Display Names'));
    search.addEventListener('input', () => {
      remainingSearch = search.value;
      renderRemainingList(list);
    });
    search.addEventListener('blur', restoreScannerCapture);
    searchLabel.appendChild(search);
    unloadGroups.appendChild(searchLabel);
    unloadGroups.appendChild(list);
    renderRemainingList(list);
  }

  async function confirmContainerMovement(payload, returningHome) {
    reviewBody.innerHTML = '';
    el('movement-review-title').textContent = (trainingMode ? 'Review test · ' : 'Review · ') + pendingIdentity.identity;
    el('movement-review-confirm').textContent = trainingMode ? 'Confirm test — no writes' : 'Confirm and record';
    const reconciliation = payload.reconciliation;
    const ids = payload.unloaded_display_ids.length ? payload.unloaded_display_ids
      : reconciliation.identify_remaining ? currentDisplays().map(row => Number(row.display_id))
        .filter(id => !reconciliation.remaining_display_ids.includes(id))
      : reconciliation.decision === 'EMPTY' ? currentDisplays().map(row => Number(row.display_id)) : [];
    const removed = currentDisplays().filter(row => ids.includes(Number(row.display_id)));
    const remaining = currentDisplays().filter(row => !ids.includes(Number(row.display_id)));
    const destination = document.createElement('p');
    destination.className = 'review-location ready';
    destination.textContent = returningHome ? 'Return Empty to ' + pendingContents.home_location_code + ' · no GPS needed'
      : 'Container NOW: ' + currentLocationEvidence().label;
    reviewBody.appendChild(destination);
    const basis = document.createElement('p');
    basis.textContent = removed.length ? removed.length + ' unloading · '
      + (payload.unloaded_display_ids.length ? 'observed HERE: ' + currentLocationEvidence().label : 'inferred PRIOR: ' + priorLocationText())
      : 'Location only — no Display attachment changes.';
    reviewBody.appendChild(basis);
    if (payload.unloaded_display_ids.length) {
      selectableUnloadGroups().filter(group => group.display_ids.every(id => ids.includes(id)))
        .forEach(group => appendNames(reviewBody, group.label, group.displays));
    } else if (removed.length) {
      appendNames(reviewBody, 'Displays unloading', removed);
    }
    appendNames(reviewBody, 'Staying on Container', remaining);
    if (reconciliation && (reconciliation.decision === 'NOT_SURE'
        || reconciliation.decision === 'NOT_EMPTY' && !reconciliation.identify_remaining)) {
      const warning = document.createElement('p');
      warning.textContent = 'Contents flagged for later review.';
      reviewBody.appendChild(warning);
    }
    reviewing = true;
    renderRecordReadiness();
    try {
      return await new Promise(resolve => {
        reviewDialog.addEventListener('close', () => resolve(reviewDialog.returnValue === 'record'), {once: true});
        reviewDialog.returnValue = 'cancel';
        reviewDialog.showModal();
      });
    } finally {
      reviewing = false;
      renderRecordReadiness();
    }
  }

  function needsDisplayPlacement() {
    return Boolean(pendingIdentity && pendingIdentity.asset_type === 'DISPLAY'
      && (!pendingStateRow || !Array.isArray(pendingStateRow.placement_stages) || pendingStateRow.container_id)
      && (!pendingStateRow || pendingStateRow.position_mode !== 'DETACHED'));
  }

  function placementStages() {
    return (pendingStateRow && pendingStateRow.placement_stages) || [];
  }

  function confirmPlacementStage(id) {
    const stage = placementStages().find(row => Number(row.stage_id) === Number(id));
    if (!stage) return;
    placementStageId = Number(stage.stage_id);
    // A previously selected Container reference/note is not this Display's placement.
    knownReference.value = '';
    locationNote.value = stage.stage_key + ' · ' + stage.stage_name;
    renderRecordReadiness();
  }

  function renderDisplayPlacement() {
    unloadGroups.innerHTML = '';
    const message = document.createElement('p');
    unloadGroups.appendChild(message);
    if (pendingStateRow && pendingStateRow.can_detach === false) {
      message.textContent = 'This Display is one object with its Standalone / singular Display-Pallet. Scan the Container to record its location.';
      return;
    }
    if (!needsDisplayPlacement()) {
      message.textContent = 'This Display is independent. Recording its current location moves only this Display.';
      return;
    }
    message.textContent = 'Is this Display at its setup location now? Confirm what you see here, not where it is going.';
    const choices = document.createElement('div');
    choices.className = 'group-actions';
    [['YES', 'Yes'], ['NO', 'No'], ['NOT_SURE', 'Not Sure']].forEach(([value, label]) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = label;
      button.setAttribute('aria-pressed', String(displayPlacement === value));
      button.addEventListener('click', () => {
        displayPlacement = value;
        placementStageId = null;
        renderDisplayPlacement();
        renderRecordReadiness();
      });
      choices.appendChild(button);
    });
    unloadGroups.appendChild(choices);
    const explanation = document.createElement('p');
    explanation.textContent = displayPlacement === 'YES'
      ? 'Confirm the actual Stage below or choose its nearest GPS Stage above. Only this Display will stop following its Container; other Displays stay attached.'
      : 'No / Not Sure leaves this Display attached and records nothing. Scan the Container to record its location.';
    unloadGroups.appendChild(explanation);
    if (displayPlacement !== 'YES') return;
    const stages = placementStages();
    if (!stages.length) {
      explanation.textContent = 'Stage context unavailable. Reconnect and rescan before detaching this Display.';
      return;
    }
    const label = document.createElement('label');
    label.className = 'placement-stage';
    label.textContent = 'Actual Stage now (confirm even when assigned)';
    const select = document.createElement('select');
    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = 'Confirm actual Stage…';
    select.appendChild(placeholder);
    stages.forEach(stage => {
      const option = document.createElement('option');
      option.value = stage.stage_id;
      option.textContent = stage.stage_key + ' · ' + stage.stage_name + (stage.assigned ? ' (assigned)' : '');
      select.appendChild(option);
    });
    select.value = placementStageId || '';
    select.addEventListener('change', () => {placementStageId = null; confirmPlacementStage(select.value); renderRecordReadiness();});
    label.appendChild(select);
    unloadGroups.appendChild(label);
    const candidates = document.createElement('div');
    candidates.className = 'group-actions';
    const ranked = rankedReferences(currentGpsSnapshot());
    const suggestions = [...stages.filter(stage => stage.assigned), ...ranked.map(point =>
      stages.find(stage => String(stage.stage_key) === point.name.split('-')[0])).filter(Boolean).slice(0, 3)];
    const seen = new Set();
    suggestions.forEach(stage => {
      if (seen.has(stage.stage_id)) return;
      seen.add(stage.stage_id);
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = 'Confirm ' + stage.stage_key + ' · ' + stage.stage_name + (stage.assigned ? ' (assigned)' : ' (near GPS)');
      button.addEventListener('click', () => {confirmPlacementStage(stage.stage_id); select.value = stage.stage_id;});
      candidates.appendChild(button);
    });
    unloadGroups.appendChild(candidates);
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

    if (pendingIdentity.asset_type === 'CONTAINER') {
      const home = String(
        (pendingContents && pendingContents.home_location_code)
        || (pendingStateRow && pendingStateRow.home_location_code)
        || ''
      ).trim();

      returnHome.hidden = false;
      if (home) {
        returnHome.disabled = false;
        returnHome.textContent = (trainingMode ? 'Test Return Empty ' : 'Return Empty ')
          + pendingIdentity.identity + ' to ' + home;
        if (homeLocationReview) {
          homeLocationReview.hidden = false;
          homeLocationReview.innerHTML = '<strong>Home Location:</strong> ' + escapeHtml(home);
        }
      } else {
        returnHome.disabled = true;
        returnHome.textContent = 'Home Location missing — Manager correction required';
        if (homeLocationReview) {
          homeLocationReview.hidden = false;
          homeLocationReview.innerHTML = '<strong>Home Location missing.</strong> Manager correction required before return.';
        }
      }
    } else {
      returnHome.hidden = true;
    }

    renderRecordReadiness();

    if (pendingIdentity.asset_type !== 'CONTAINER') {
      renderDisplayPlacement();
      return;
    }
    renderContentsDecision();
    renderRecordReadiness();
  }

  async function selectIdentity(identity, captureMethod) {
    if (!access || !access.can_move_setup_assets) {
      setFeedback('blocked', 'Movement authorization is not available.');
      return;
    }

    if (recording || reviewing) return;
    const generation = ++selectionGeneration;
    contentsDecision = null;
    identifyRemaining = false;
    unloadedHereDisplayIds = new Set();
    contentsView = 'UNLOAD';
    remainingDisplayIds = null;
    remainingSearch = '';
    displayPlacement = null;
    placementStageId = null;
    pendingIdentity = identity;
    pendingCaptureMethod = captureMethod;
    renderScannerLayoutState();
    pendingContents = null;
    pendingStateRow = null;
    setFeedback('ready', identity.identity + ' — loading current movement context…');

    try {
      if (identity.asset_type === 'CONTAINER') {
        const contents = await fetchContainerContents(identity.asset_id);
        if (generation !== selectionGeneration) return;
        pendingContents = contents;
        pendingStateRow = pendingContents;
      } else {
        const state = await fetchState(identity);
        if (generation !== selectionGeneration) return;
        pendingStateRow = state;
      }
    } catch (error) {
      if (generation !== selectionGeneration) return;
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
    renderRecordReadiness();
    setFeedback('ready', identity.identity + (needsDisplayPlacement()
      ? ' — answer the setup location question, then confirm the actual Stage'
      : ' — now confirm location evidence, then review and record'));
    if (window.matchMedia && window.matchMedia('(max-width: 900px)').matches && locationPanel) {
      locationPanel.scrollIntoView({behavior: 'smooth', block: 'start'});
    }
  }

  async function recordPending(returningHome) {
    if (recording || reviewing) return;
    if (!pendingIdentity) {
      setFeedback('blocked', 'Select a Container or Display first.');
      return;
    }

    const identity = pendingIdentity;
    if (needsDisplayPlacement() && (displayPlacement !== 'YES' || !placementStageId)) {
      setFeedback('blocked', 'Confirm Yes and the actual Stage before detaching this Display. No / Not Sure records nothing.');
      return;
    }
    if (identity.asset_type === 'DISPLAY' && pendingStateRow && pendingStateRow.can_detach === false) {
      setFeedback('blocked', 'Scan the Container for this Standalone / singular Display-Pallet.');
      return;
    }
    const action = returningHome
      ? 'RETURNED'
      : (identity.asset_type === 'CONTAINER' ? 'CONTAINER_MOVE' : 'DISPLAY_MOVE');

    if (!returningHome && !currentGpsSnapshot() && !destinationNote() && !placementStageId) {
      setFeedback('blocked', 'LOCATION NEEDED — start GPS, confirm a named reference, or enter a location note.');
      return;
    }

    const unloaded = identity.asset_type === 'CONTAINER' ? selectedUnloadedDisplayIds() : [];
    if (returningHome && unloaded.length) {
      setFeedback('blocked', 'Record the observed unload here first, then confirm Empty for Return Empty.');
      return;
    }
    const payload = movementPayload(identity, action, pendingCaptureMethod, unloaded);
    if (needsDisplayPlacement()) {
      const stage = placementStages().find(row => Number(row.stage_id) === placementStageId);
      payload.display_placement = 'YES';
      payload.destination_stage_id = placementStageId;
      payload.destination_location_note = stage.stage_key + ' · ' + stage.stage_name;
      payload.notes = 'display_setup_location_confirmed=true; direct_display_observation=true';
      if (!window.confirm('Confirm ' + pendingStateRow.label + ' is at its setup location NOW:\n'
          + payload.destination_location_note + '\n\nDetach only this Display from its Container and record here?')) return;
    }
    if (identity.asset_type === 'CONTAINER') {
      if (unloaded.length) {
        payload.notes = [payload.notes, 'direct_container_unload=true'].filter(Boolean).join('; ');
      } else {
        try {
          payload.reconciliation = reconciliationPayload();
          if (returningHome && payload.reconciliation.decision !== 'EMPTY') throw new Error('Confirm Empty before Return Empty.');
        } catch (error) {
          setFeedback('blocked', error.message);
          return;
        }
      }
    }

    if (identity.asset_type === 'CONTAINER' && !await confirmContainerMovement(payload, returningHome)) return;

    if (trainingMode) {
      const gps = currentGpsSnapshot();
      const evidence = currentLocationEvidence();
      let message = 'TRAINING — WOULD RECORD ' + identity.identity;
      if (returningHome) {
        message += ' RETURNED HOME';
      } else {
        message += ' HERE';
        if (evidence.ready && evidence.label) message += ' · ' + evidence.label;
        if (gps) message += ' · GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft';
        if (unloaded.length) message += ' · would leave ' + unloaded.length + ' Display' + (unloaded.length === 1 ? '' : 's') + ' here';
      }
      if (payload.reconciliation && (payload.reconciliation.decision === 'EMPTY' || payload.reconciliation.identify_remaining)) {
        const count = currentDisplays().length - (payload.reconciliation.remaining_display_ids || []).length;
        if (count) message += ' · would reconcile ' + count + ' Displays at prior location';
      }
      if (payload.display_placement) message += ' · would detach only this Display at confirmed Stage';
      resetAssetEntryForNextScan();
      setFeedback(
        'success',
        message + ' · NOTHING RECORDED'
          + (scannerActive ? ' · SCANNER READY — scan next asset' : '')
      );
      return;
    }

    recording = true;
    renderRecordReadiness();
    setFeedback('ready', identity.identity + ' — recording physical observation…');

    try {
      const result = await sendOrQueue(payload);
      if (result.queued) {
        setFeedback('offline', identity.identity + ' — OBSERVATION QUEUED OFFLINE');
      } else if (returningHome) {
        setFeedback('success', identity.identity + ' — RETURNED HOME '
          + String((result.movement && result.movement.home_location_code) || '')
          + (result.movement && result.movement.unloaded_display_count
            ? ' · ' + result.movement.unloaded_display_count + ' Displays reconciled at prior location' : ''));
      } else {
        const movement = result.movement || {};
        const unloadCount = Number(movement.unloaded_display_count || 0);
        const gps = currentGpsSnapshot();
        let message = identity.identity + ' — LOCATION RECORDED';
        if (payload.display_placement) message += ' · ONLY THIS DISPLAY DETACHED';
        if (unloadCount) message += ' · ' + unloadCount + ' Display' + (unloadCount === 1 ? '' : 's')
          + (payload.reconciliation ? ' reconciled at prior location' : ' unloaded here');
        if (gps) message += ' · GPS ±' + Math.round(Number(gps.accuracy_m || 0) * 3.280839895) + ' ft';
        setFeedback('success', message);
      }

      resetAssetEntryForNextScan();
      if (scannerActive) {
        feedback.textContent += ' · SCANNER READY — scan next asset';
      }
    } catch (error) {
      setFeedback('warning', identity.identity + ' — ' + (error.message || error));
    } finally {
      recording = false;
      renderRecordReadiness();
    }
  }

  async function handleIdentity(raw, captureMethod) {
    const identity = parseIdentity(raw);
    if (!identity) {
      setFeedback('blocked', 'INVALID IDENTITY — expected CONT:<id>, DISP:<id>, or a permanent scan URL.');
      restoreScannerCapture();
      return;
    }
    manualInput.value = identity.identity;
    await selectIdentity(identity, captureMethod);
    restoreScannerCapture();
  }

  function pauseScannerForTyping(label) {
    if (!scannerActive) return;
    clearScanTimer();
    scanBuffer = '';
    scannerStatus.textContent = 'Scanner paused — ' + label;
  }

  function restoreScannerCapture() {
    if (!scannerActive) return;
    clearScanTimer();
    scanBuffer = '';
    const active = document.activeElement;
    if (active && active.blur) active.blur();
    if (pendingIdentity) {
      scannerStatus.textContent = 'Scanner paused — record or clear ' + pendingIdentity.identity;
      return;
    }
    scannerStatus.textContent = 'Scanner ready — no field focus needed';
  }

  function finishScannerTypingOnEnter(event) {
    if (!scannerActive || event.key !== 'Enter') return;
    event.preventDefault();
    event.currentTarget.blur();
  }

  function resetAssetEntryForNextScan() {
    clearPending();
    manualInput.value = '';
    knownReference.value = '';
    locationNote.value = '';
    restoreScannerCapture();
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
    if (!scannerActive || pendingIdentity || event.defaultPrevented || event.isComposing) return;
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

  function stopScanner() {
    scannerActive = false;
    clearScanTimer();
    scanBuffer = '';
    scannerToggle.textContent = 'Start Scanner';
    scannerStatus.textContent = 'Scanner off';
    renderScannerLayoutState();
    cameraToggle.disabled = false;
    cameraStatus.textContent = 'Camera off';
  }

  async function toggleScanner() {
    if (scannerActive) {
      stopScanner();
      setFeedback('ready', 'Scanner off — use manual entry, Find, camera, or start the scanner again.');
      return;
    }
    if (!access || !access.can_move_setup_assets) {
      setFeedback('blocked', 'Movement authorization is not available.');
      return;
    }

    await stopCamera();
    scannerActive = true;
    clearScanTimer();
    scanBuffer = '';
    scannerToggle.textContent = 'Stop Scanner';
    renderScannerLayoutState();
    cameraToggle.disabled = true;
    cameraStatus.textContent = 'Camera disabled while scanner is on';
    restoreScannerCapture();
    setFeedback(
      'ready',
      pendingIdentity
        ? 'SCANNER PAUSED — record or clear ' + pendingIdentity.identity
        : 'SCANNER READY — scan a Container or Display'
    );
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
          await handleIdentity(raw, 'CAMERA_SCAN');
          return;
        }
      }
    } catch (_error) {}
    if (cameraStream) cameraFrame = requestAnimationFrame(scanCameraFrame);
  }

  async function startCamera() {
    if (scannerActive) {
      setFeedback('warning', 'Stop Scanner before using the camera.');
      return;
    }
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
  manualInput.addEventListener('focus', function () {
    pauseScannerForTyping('manual identity entry');
  });
  manualInput.addEventListener('blur', restoreScannerCapture);
  manualInput.addEventListener('keydown', function (event) {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    if (manualInput.value.trim()) void handleIdentity(manualInput.value, 'MANUAL_ENTRY');
  });
  searchGo.addEventListener('click', function () {
    void searchAssets().finally(restoreScannerCapture);
  });
  searchInput.addEventListener('focus', function () {
    pauseScannerForTyping('Find field active');
  });
  searchInput.addEventListener('blur', restoreScannerCapture);
  searchInput.addEventListener('keydown', function (event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      void searchAssets().finally(restoreScannerCapture);
    }
  });
  scannerToggle.addEventListener('click', function () { void toggleScanner(); });
  cameraToggle.addEventListener('click', function () { void startCamera(); });
  gpsToggle.addEventListener('click', function () {
    if (watchId === null) startGps();
    else stopGps();
  });
  recordHere.addEventListener('click', function () { void recordPending(false); });
  returnHome.addEventListener('click', function () { void recordPending(true); });
  clearPendingButton.addEventListener('click', function () {
    if (recording || reviewing) return;
    resetAssetEntryForNextScan();
    setFeedback(
      'ready',
      scannerActive
        ? 'SCANNER READY — scan a Container or Display'
        : 'READY — scan, search, or choose an asset'
    );
  });
  el('movement-review-cancel').addEventListener('click', () => reviewDialog.close('cancel'));
  el('movement-review-confirm').addEventListener('click', () => reviewDialog.close('record'));
  knownReference.addEventListener('focus', function () {
    pauseScannerForTyping('choosing a park reference');
  });
  knownReference.addEventListener('change', function () {
    renderRecordReadiness();
    restoreScannerCapture();
  });
  knownReference.addEventListener('blur', restoreScannerCapture);
  locationNote.addEventListener('focus', function () {
    pauseScannerForTyping('typing location note');
  });
  locationNote.addEventListener('input', renderRecordReadiness);
  locationNote.addEventListener('keydown', finishScannerTypingOnEnter);
  locationNote.addEventListener('blur', restoreScannerCapture);
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
  window.addEventListener('pagehide', function () {
    stopScanner();
    void stopCamera();
  });
  window.setInterval(function () { renderGps(); }, 1000);

  async function initialize() {
    applyTrainingMode();
    renderScannerLayoutState();
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
        await handleIdentity(requested, 'TOUCH_SELECT');
      } else {
        setFeedback('warning', 'The supplied Record Location asset was not a valid CONT:/DISP: identity.');
      }
    }
  }

  void initialize();
})();
