(() => {
  'use strict';

  const startButton = document.getElementById('start-pick-mode');
  const stopButton = document.getElementById('stop-pick-mode');
  const panel = document.getElementById('pick-mode-panel');
  const feedback = document.getElementById('pick-mode-feedback');
  const networkState = document.getElementById('pick-mode-network');
  const queueState = document.getElementById('pick-mode-queue');
  const manualInput = document.getElementById('movement-manual-input');
  const manualGo = document.getElementById('movement-manual-go');
  const seasonSelect = document.getElementById('season-select');
  const trainingEntry = document.getElementById('pick-training-entry');
  const trainingSummary = document.getElementById('pick-training-summary');
  const trainingEnter = document.getElementById('enter-pick-training');
  const trainingExit = document.getElementById('exit-pick-training');
  const pickModeTitle = document.getElementById('pick-mode-title');
  const containersPicked = document.getElementById('pick-mode-containers-picked');
  const trainingCount = document.getElementById('pick-mode-training-count');

  const pageParams = new URLSearchParams(location.search);
  const trainingMode = pageParams.get('training') === '1';

  const DB_NAME = 'msb-setup-movement';
  const DB_VERSION = 1;
  const STORE_NAME = 'movement-queue';
  const DEVICE_KEY = 'msb.setup.movement.device-id';
  const SCAN_RESET_MS = 5000;

  let active = false;
  let scanBuffer = '';
  let scanResetTimer = null;
  let queuedPickKeys = new Set();
  let syncing = false;
  let trainingPickCount = 0;

  function bridge() {
    return window.MSBSetupPickList || null;
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

  function setFeedback(kind, message) {
    feedback.className = 'pick-mode-feedback ' + kind;
    feedback.textContent = message;
  }

  function refreshPanelCounts() {
    const current = bridge() && bridge().containersPickedCount
      ? bridge().containersPickedCount()
      : 0;
    if (containersPicked) containersPicked.textContent = String(current);
    if (trainingCount) {
      trainingCount.hidden = !trainingMode;
      const strong = trainingCount.querySelector('strong');
      if (strong) strong.textContent = String(trainingPickCount);
    }
  }

  function updateNetwork() {
    if (trainingMode) {
      networkState.textContent = navigator.onLine ? 'ONLINE' : 'OFFLINE';
      return;
    }
    networkState.textContent = navigator.onLine
      ? 'ONLINE'
      : 'OFFLINE — valid picks will queue locally';
  }

  function applyTrainingMode() {
    document.body.classList.toggle('pick-training-mode', trainingMode);
    if (trainingEntry) trainingEntry.hidden = false;
    if (trainingSummary) trainingSummary.textContent = trainingMode
      ? 'Training active — no recording'
      : 'Training / device test';
    if (trainingEnter) trainingEnter.hidden = trainingMode;
    if (trainingExit) trainingExit.hidden = !trainingMode;
    if (startButton) startButton.textContent = trainingMode ? 'Start Training Pick' : 'Start Picking';
    if (stopButton) stopButton.textContent = trainingMode ? 'Exit Training' : 'Stop Scanner';
    if (pickModeTitle) pickModeTitle.textContent = trainingMode
      ? 'WORKSHOP PICK — TRAINING'
      : 'WORKSHOP PICK — READY';
    refreshPanelCounts();
  }

  function enterTrainingMode() {
    const confirmed = window.confirm(
      'Enter Pick List Training Mode?\n\n'
      + 'Nothing will be recorded or queued. The real Pick List and scanner validation will still be used.'
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

  function assetKey(assetType, assetId) {
    return assetType + ':' + assetId;
  }

  function findDemand(assetType, assetId) {
    const readiness = bridge() && bridge().readiness ? bridge().readiness() : null;
    return (readiness && readiness.physical_items || []).find(function (item) {
      return item.physical_type === assetType && Number(item.physical_id) === Number(assetId);
    }) || null;
  }

  function cachedPickValidation(identity) {
    const item = findDemand(identity.asset_type, identity.asset_id);
    if (!item) {
      return {ok: false, kind: 'warning', message: identity.identity + ' — NOT ON CURRENT PICK LIST'};
    }
    if (bridge().itemDelayed(item)) {
      return {ok: false, kind: 'blocked', message: identity.identity + ' — DELAYED — DO NOT PICK YET'};
    }
    if (bridge().itemMoved(item)) {
      const status = String((item.current_observation && item.current_observation.movement_status) || 'MOVED');
      return {ok: false, kind: 'warning', message: identity.identity + ' — ALREADY ' + status};
    }
    if (queuedPickKeys.has(assetKey(identity.asset_type, identity.asset_id))) {
      return {ok: false, kind: 'offline', message: identity.identity + ' — PICK ALREADY QUEUED OFFLINE'};
    }
    return {ok: true, item: item};
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
    try {
      const rows = await queueRows();
      queuedPickKeys = new Set(rows.filter(function (row) {
        return row.movement_action === 'PICKED';
      }).map(function (row) {
        return assetKey(row.asset_type, row.asset_id);
      }));
      queueState.textContent = trainingMode
        ? 'Queue disabled' + (rows.length ? ' · real pending: ' + rows.length : '')
        : 'Offline queue: ' + rows.length;
      refreshPanelCounts();
      return rows;
    } catch (_error) {
      queueState.textContent = 'Offline queue unavailable';
      return [];
    }
  }

  function movementPayload(identity, captureMethod) {
    const access = bridge() && bridge().access ? bridge().access() : {};
    return {
      season_year: Number(seasonSelect && seasonSelect.value || 2026),
      client_event_id: uuid(),
      asset_type: identity.asset_type,
      asset_id: identity.asset_id,
      movement_action: 'PICKED',
      occurred_at: new Date().toISOString(),
      device_id: deviceId(),
      captured_operator_email: String(access.authenticated_email || '').trim().toLowerCase(),
      capture_method: captureMethod,
      offline_captured: !navigator.onLine
    };
  }

  async function postMovement(payload) {
    if (trainingMode) {
      throw new Error('Training Mode blocks Setup movement writes.');
    }
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
      const error = new Error(data.error || ('HTTP ' + response.status));
      error.httpStatus = response.status;
      throw error;
    }
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
    queuedPickKeys.add(assetKey(payload.asset_type, payload.asset_id));
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

    if (trainingMode) {
      trainingPickCount += 1;
      refreshPanelCounts();
      setFeedback('success', 'WOULD PICK ' + identity.identity + ' FOR PARK TRANSPORT · NOT RECORDED');
      return;
    }

    try {
      const result = await sendOrQueue(movementPayload(identity, captureMethod));
      if (result.queued) {
        setFeedback('offline', identity.identity + ' — PICK QUEUED OFFLINE');
      } else {
        const movement = result.movement || {};
        if (bridge() && bridge().settlePicked) {
          bridge().settlePicked(identity, movement);
        }
        setFeedback('success', identity.identity + ' — PICKED FOR PARK TRANSPORT');
        if (bridge() && bridge().reload) {
          void bridge().reload().catch(function () {
            setFeedback(
              'warning',
              identity.identity + ' — PICKED, but Pick List refresh is delayed. Continue scanning; authoritative refresh will retry on the next load.'
            );
          });
        }
      }
    } catch (error) {
      const message = String(error.message || error);
      const kind = /DELAYED|DO NOT PICK/i.test(message) ? 'blocked' : 'warning';
      setFeedback(kind, identity.identity + ' — ' + message);
      try { await bridge().reload(); } catch (_error) {}
    }
  }

  function resetScanEntry() {
    clearScanTimer();
    scanBuffer = '';
    if (manualInput) manualInput.value = '';
  }

  async function handleIdentity(raw, captureMethod) {
    const submitted = String(raw || '').trim();
    resetScanEntry();

    const identity = parseIdentity(submitted);
    if (!identity) {
      setFeedback('blocked', 'INVALID IDENTITY — expected CONT:<id>, DISP:<id>, or a permanent scan URL.');
      return;
    }
    await recordPick(identity, captureMethod);
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

  function startPicking() {
    const access = bridge() && bridge().access ? bridge().access() : {};
    if (!access.can_move_setup_assets) {
      panel.hidden = false;
      setFeedback('blocked', 'This signed-in account is not authorized for Setup movement.');
      return;
    }

    active = true;
    scanBuffer = '';
    document.body.classList.add('pick-mode-active');
    panel.hidden = false;
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    setFeedback(
      'ready',
      'READY — scan the next Pick List item'
    );
    refreshPanelCounts();
    void refreshQueueState();
  }

  function stopPicking() {
    active = false;
    scanBuffer = '';
    clearScanTimer();
    document.body.classList.remove('pick-mode-active');
    panel.hidden = true;
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
      try { await bridge().reload(); } catch (_error) {}
    } finally {
      syncing = false;
    }
  }

  async function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) return;
    try {
      await navigator.serviceWorker.register('service-worker.js', {scope: './'});
      await navigator.serviceWorker.ready;
      const year = encodeURIComponent(seasonSelect && seasonSelect.value || '2026');
      await Promise.allSettled([
        fetch('../api/setup/material-readiness?season_year=' + year, {cache: 'no-store'}),
        fetch('../api/setup/access', {cache: 'no-store'})
      ]);
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

  document.addEventListener('keydown', captureKeydown, true);
  document.addEventListener('msb-movement-select', function (event) {
    const identity = event.detail && event.detail.identity;
    if (active && identity) void handleIdentity(identity, 'TOUCH_SELECT');
  });
  startButton.addEventListener('click', startPicking);
  stopButton.addEventListener('click', function () {
    if (trainingMode) {
      exitTrainingMode();
      return;
    }
    stopPicking();
  });
  trainingEnter?.addEventListener('click', enterTrainingMode);
  trainingExit?.addEventListener('click', exitTrainingMode);
  document.addEventListener('msb-pick-list-rendered', refreshPanelCounts);
  window.addEventListener('online', function () {
    updateNetwork();
    void syncQueue();
  });
  window.addEventListener('offline', updateNetwork);

  applyTrainingMode();
  updateNetwork();
  void refreshQueueState();
  void registerServiceWorker();
  if (navigator.onLine && !trainingMode) void syncQueue();
})();
