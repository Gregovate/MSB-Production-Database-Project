(() => {
  'use strict';

  const startButton = document.getElementById('start-pick-mode');
  const stopButton = document.getElementById('stop-pick-mode');
  const panel = document.getElementById('pick-mode-panel');
  const feedback = document.getElementById('pick-mode-feedback');
  const networkState = document.getElementById('pick-mode-network');
  const queueState = document.getElementById('pick-mode-queue');
  const gpsState = document.getElementById('pick-mode-gps');
  const title = document.getElementById('pick-mode-title');
  const help = document.getElementById('pick-mode-help');
  const actionButtons = Array.from(document.querySelectorAll('[data-movement-action]'));
  const seasonSelect = document.getElementById('season-select');

  const DB_NAME = 'msb-setup-movement';
  const DB_VERSION = 1;
  const STORE_NAME = 'movement-queue';
  const DEVICE_KEY = 'msb.setup.movement.device-id';
  const SCAN_RESET_MS = 5000;
  const ACTION_LABELS = Object.freeze({
    PICKED: 'PICK',
    LOADED: 'LOAD',
    IN_TRANSIT: 'DEPART / IN TRANSIT',
    UNLOADED: 'UNLOAD',
    STAGED: 'STAGE',
    PLACED: 'PLACE',
    RELOCATED: 'RELOCATE',
    RETURNED: 'RETURN EMPTY'
  });
  const GPS_REQUIRED_ACTIONS = new Set([
    'UNLOADED', 'STAGED', 'PLACED', 'RELOCATED'
  ]);

  let active = false;
  let currentAction = 'PICKED';
  let scanBuffer = '';
  let scanResetTimer = null;
  let latestPosition = null;
  let watchId = null;
  let queuedActionKeys = new Set();
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
      networkState.textContent = navigator.onLine ? 'ONLINE' : 'OFFLINE — scans will queue';
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

  function actionKey(assetType, assetId, action) {
    return `${assetKey(assetType, assetId)}:${action}`;
  }

  async function refreshQueueState() {
    try {
      const rows = await queueRows();
      queuedActionKeys = new Set(rows.map((row) => actionKey(
        row.asset_type,
        row.asset_id,
        row.movement_action
      )));
      if (queueState) queueState.textContent = `Offline queue: ${rows.length}`;
      return rows;
    } catch (error) {
      if (queueState) queueState.textContent = 'Offline queue unavailable';
      return [];
    }
  }

  function findDemand(assetType, assetId) {
    const readiness = bridge()?.readiness?.();
    return (readiness?.physical_items || []).find((item) => (
      item.physical_type === assetType && Number(item.physical_id) === Number(assetId)
    )) || null;
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
    if (queuedActionKeys.has(actionKey(identity.asset_type, identity.asset_id, 'PICKED'))) {
      return {ok: false, kind: 'offline', message: `${identity.identity} — PICK ALREADY QUEUED OFFLINE`};
    }
    return {ok: true, item};
  }

  function gpsEvidence() {
    if (!latestPosition) return {};
    return {
      gps_latitude: latestPosition.coords.latitude,
      gps_longitude: latestPosition.coords.longitude,
      gps_accuracy_m: latestPosition.coords.accuracy
    };
  }

  function gpsText() {
    if (!latestPosition) return 'GPS unavailable';
    const accuracy = Math.round(Number(latestPosition.coords.accuracy) || 0);
    return `GPS ±${accuracy} m`;
  }

  function selectAction(action) {
    if (!Object.hasOwn(ACTION_LABELS, action)) return;
    currentAction = action;
    actionButtons.forEach((button) => {
      button.classList.toggle('active', button.dataset.movementAction === action);
    });
    if (title) title.textContent = `SCAN MODE — ${ACTION_LABELS[action]}`;
    if (help) {
      help.textContent = action === 'RETURNED'
        ? 'Scan an empty Container or Display. The accepted Home Location will be shown after the return event is recorded.'
        : `${ACTION_LABELS[action]} is armed. Scan CONT:<id> or DISP:<id> + Enter.`;
    }
    if (active) setFeedback('ready', `READY — ${ACTION_LABELS[action]} next scan`);
  }

  function movementPayload(identity) {
    return {
      season_year: Number(seasonSelect?.value || 2026),
      client_event_id: uuid(),
      asset_type: identity.asset_type,
      asset_id: identity.asset_id,
      movement_action: currentAction,
      occurred_at: new Date().toISOString(),
      device_id: deviceId(),
      captured_operator_email: String(
        bridge()?.access?.()?.authenticated_email || ''
      ).trim().toLowerCase(),
      capture_method: 'HID_SCAN',
      offline_captured: !navigator.onLine,
      ...gpsEvidence()
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
    const queued = {...payload, offline_captured: true, queue_status: 'QUEUED'};
    await putQueue(queued);
    queuedActionKeys.add(actionKey(
      payload.asset_type,
      payload.asset_id,
      payload.movement_action
    ));
    await refreshQueueState();
    return queued;
  }

  async function recordMovement(identity) {
    if (currentAction === 'PICKED') {
      const validation = cachedPickValidation(identity);
      if (!validation.ok) {
        setFeedback(validation.kind, validation.message);
        return;
      }
    } else if (queuedActionKeys.has(actionKey(
      identity.asset_type,
      identity.asset_id,
      currentAction
    ))) {
      setFeedback(
        'offline',
        `${identity.identity} — ${ACTION_LABELS[currentAction]} ALREADY QUEUED OFFLINE`
      );
      return;
    }

    if (GPS_REQUIRED_ACTIONS.has(currentAction) && !latestPosition) {
      setFeedback(
        'blocked',
        `${ACTION_LABELS[currentAction]} REQUIRES LOCATION — wait for GPS before scanning`
      );
      return;
    }

    const payload = movementPayload(identity);
    const action = payload.movement_action;

    if (!navigator.onLine) {
      try {
        await queueMovement(payload);
        setFeedback('offline', `${identity.identity} — ${ACTION_LABELS[action]} QUEUED OFFLINE`);
      } catch (error) {
        setFeedback('blocked', `OFFLINE QUEUE FAILED — ${error.message || error}`);
      }
      return;
    }

    setFeedback('ready', `${identity.identity} — recording ${ACTION_LABELS[action]}…`);
    try {
      const movement = await postMovement(payload);
      let message = `${identity.identity} — ${movement.duplicate_event ? 'ALREADY RECORDED' : ACTION_LABELS[action]}`;
      if (action === 'RETURNED') {
        message += movement.home_location_code
          ? ` — HOME ${movement.home_location_code}`
          : ' — HOME LOCATION MISSING — MANAGER EXCEPTION';
      } else if (latestPosition) {
        message += ` · ${gpsText()}`;
      }
      setFeedback('success', message);
      await bridge()?.reload?.();
    } catch (error) {
      if (!navigator.onLine || !error.httpStatus || error.httpStatus >= 500) {
        try {
          await queueMovement(payload);
          setFeedback('offline', `${identity.identity} — ${ACTION_LABELS[action]} QUEUED OFFLINE`);
          return;
        } catch (queueError) {
          setFeedback('blocked', `PICK FAILED — ${queueError.message || queueError}`);
          return;
        }
      }
      const message = String(error.message || error);
      const kind = /DELAYED|DO NOT PICK/i.test(message) ? 'blocked' : 'warning';
      setFeedback(kind, `${identity.identity} — ${message}`);
      await bridge()?.reload?.().catch(() => {});
    }
  }

  async function handleScan(raw) {
    const identity = parseIdentity(raw);
    if (!identity) {
      setFeedback('blocked', `INVALID SCAN — expected CONT:<id> or DISP:<id>`);
      return;
    }
    await recordMovement(identity);
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

  function captureKeydown(event) {
    if (!active || event.defaultPrevented || event.isComposing) return;
    if (event.ctrlKey || event.metaKey || event.altKey) return;

    if (event.key === 'Enter') {
      event.preventDefault();
      event.stopImmediatePropagation();
      clearScanTimer();
      const value = scanBuffer;
      scanBuffer = '';
      if (value.trim()) void handleScan(value);
      return;
    }

    if (event.key && event.key.length === 1) {
      event.preventDefault();
      event.stopImmediatePropagation();
      scanBuffer += event.key;
      scheduleScanReset();
    }
  }

  function startGps() {
    if (!navigator.geolocation) {
      if (gpsState) gpsState.textContent = 'GPS unavailable';
      return;
    }
    if (watchId !== null) return;
    if (gpsState) gpsState.textContent = 'GPS: acquiring…';
    watchId = navigator.geolocation.watchPosition(
      (position) => {
        latestPosition = position;
        if (gpsState) gpsState.textContent = gpsText();
      },
      () => {
        if (gpsState) gpsState.textContent = 'GPS unavailable';
      },
      {enableHighAccuracy: true, maximumAge: 30000, timeout: 10000}
    );
  }

  function stopGps() {
    if (watchId !== null && navigator.geolocation) {
      navigator.geolocation.clearWatch(watchId);
    }
    watchId = null;
  }

  function startMode() {
    const access = bridge()?.access?.() || {};
    if (!access.can_move_setup_assets) {
      setFeedback('blocked', 'This signed-in account is not authorized for Setup movement.');
      if (panel) panel.hidden = false;
      return;
    }
    active = true;
    scanBuffer = '';
    selectAction('PICKED');
    document.body.classList.add('pick-mode-active');
    if (panel) panel.hidden = false;
    document.activeElement?.blur?.();
    setFeedback('ready', 'READY — scan the next item');
    startGps();
    void refreshQueueState();
  }

  function stopMode() {
    active = false;
    scanBuffer = '';
    clearScanTimer();
    stopGps();
    document.body.classList.remove('pick-mode-active');
    if (panel) panel.hidden = true;
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
          queuedActionKeys.delete(actionKey(
            row.asset_type,
            row.asset_id,
            row.movement_action
          ));
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

      // The first page load may finish its API reads before the newly installed
      // worker controls the client. Re-read the launch-critical GET surfaces
      // after activation so a later offline cold start has authoritative cached
      // Pick List/access data from the most recent connected checkpoint.
      const year = encodeURIComponent(seasonSelect?.value || '2026');
      const urls = [
        `../api/setup/material-readiness?season_year=${year}`,
        '../api/setup/access',
        '../api/setup/stages'
      ];
      if (bridge()?.access?.()?.can_manage_setup) {
        urls.push('../api/setup/containers/source-options');
      }
      await Promise.allSettled(
        urls.map((url) => fetch(url, {cache: 'no-store'}))
      );
    } catch (_error) {
      // Queueing still works when the browser lacks install permission, but the
      // offline-cold-start acceptance gate will expose a failed shell cache.
    }
  }

  document.addEventListener('keydown', captureKeydown, true);
  startButton?.addEventListener('click', startMode);
  stopButton?.addEventListener('click', stopMode);
  actionButtons.forEach((button) => {
    button.addEventListener('click', () => {
      selectAction(String(button.dataset.movementAction || '').toUpperCase());
    });
  });
  window.addEventListener('online', () => {
    updateNetwork();
    void syncQueue();
  });
  window.addEventListener('offline', updateNetwork);

  // Fail safe: mutating mode is never restored after reload/new session.
  stopMode();
  updateNetwork();
  void refreshQueueState();
  void registerServiceWorker();
  if (navigator.onLine) void syncQueue();
})();
