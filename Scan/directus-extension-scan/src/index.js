/* =====================================================================
   MSB Directus Scan Extension
   ---------------------------------------------------------------------
   Provides a mobile-friendly scan interface for QR codes, barcodes,
   and manual entry used in the Making Spirits Bright production system.

   Routes handled by this extension:

     /scan
       → Scan hub (camera scan, manual entry, URL handling)

     /scan/DISP/:key
       → Display scan landing page

     /scan/CONT/:key
       → Container scan landing page

     /scan/CTRL/:key
       → Controller Inventory exact-controller search/detail

     /scan/DISP/:key/test
       → Opens display test record in Directus

     /scan/DISP/:key/container
       → Opens assigned container record

     /scan/DISP/:key/work-orders
       → Opens active work orders for the display

   Notes:

   • Designed for rugged tablets and phones used by volunteers
   • Supports QR codes and 1-D barcodes via html5-qrcode library
   • No authentication handled here — relies on Directus session
   • Camera access requires HTTPS
   • Uses client-side routing to call server endpoints

   Created: 2026-03-17
   Project: Making Spirits Bright Production Database
   Maintainer: Greg Liebig / MSB Technical Team

   ===================================================================== */
export default {
  id: 'scan',

  handler: (router, { database }) => {
    // ============================================================
    // SCAN EXTENSION ROUTES
    // All routes are registered here at the top level.
    // Order does not matter, but nesting is NOT allowed.
    // ============================================================
    router.get('/', async (req, res) => {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');

          res.setHeader(
            'Content-Security-Policy',
            [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com",
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data: blob:",
              "media-src 'self' blob:",
              "connect-src 'self' https://unpkg.com",
              "frame-src 'self'",
              "object-src 'none'"
            ].join('; ')
          );

      res.send(`
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>MSB Scan</title>

          <script src="https://unpkg.com/html5-qrcode" type="text/javascript"></script>

          <style>
            body {
              font-family: Arial, sans-serif;
              background: #0b1220;
              color: #fff;
              margin: 0;
              padding: 20px;
            }

            .card {
              max-width: 700px;
              margin: 0 auto;
              background: #111a2b;
              border-radius: 12px;
              padding: 20px;
            }

            h1 {
              margin-top: 0;
            }

            input {
              width: 100%;
              padding: 14px;
              font-size: 18px;
              border-radius: 8px;
              border: 1px solid #444;
              box-sizing: border-box;
              margin-bottom: 12px;
            }

            .hint {
              margin-top: 10px;
              color: #bbb;
            }

            .btn,
            .btn:visited,
            .btn:focus {
              display: block;
              width: 100%;
              background: #1f6feb;
              color: #fff;
              text-decoration: none;
              padding: 14px 16px;
              border-radius: 8px;
              margin-bottom: 12px;
              text-align: center;
              font-weight: bold;
              outline: none;
              border: 0;
              box-sizing: border-box;
              cursor: pointer;
              font-size: 16px;
            }

            .btn:active {
              transform: scale(0.98);
            }

            .secondary,
            .secondary:visited,
            .secondary:focus {
              background: #39435a;
              color: #fff;
            }

            .secondary:active {
              transform: scale(0.98);
            }

            .disabled {
              background: #3a3a3a;
              color: #888;
              opacity: 0.55;
              pointer-events: none;
              filter: grayscale(60%);
            }

            .meta {
              color: #bbb;
              margin-bottom: 20px;
            }

            #reader {
              display: none;
              margin-top: 16px;
              background: #000;
              border-radius: 12px;
              overflow: hidden;
            }

            #scanStatus {
              margin-top: 10px;
              color: #bbb;
            }

            * {
              -webkit-tap-highlight-color: transparent;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>MSB Scan</h1>

            <form id="scanForm">
              <input id="scanInput" name="scan" autofocus placeholder="Scan code or paste URL" />
              <button type="submit" class="btn">Go</button>
            </form>

            <button id="scanBtn" type="button" class="btn secondary">Scan with Camera</button>
            <button id="stopBtn" type="button" class="btn secondary" style="display:none;">Stop Camera</button>

            <div class="hint">Examples: DISP:141, CONT:238, LOC:RA-01-A-03, CTRL:1014, or a full scan URL</div>

            <div id="reader"></div>
            <div id="scanStatus"></div>
          </div>

      <script>
        const form = document.getElementById('scanForm');
        const input = document.getElementById('scanInput');
        const scanBtn = document.getElementById('scanBtn');
        const stopBtn = document.getElementById('stopBtn');
        const reader = document.getElementById('reader');
        const scanStatus = document.getElementById('scanStatus');

        let html5QrCode = null;
        let scannerRunning = false;
        let cameraStarting = false;

        function setStatus(message) {
          scanStatus.textContent = message || '';
        }

        // Mobile browsers do not consistently honor HTML autofocus. Retry the
        // focus after page activation so a Zebra HID scan can start without an
        // operator first tapping the field.
        function focusScanInput() {
          if (scannerRunning || cameraStarting) return;

          try {
            input.focus({ preventScroll: true });
          } catch (err) {
            input.focus();
          }
        }

        function scheduleScanInputFocus() {
          window.setTimeout(focusScanInput, 0);
          window.setTimeout(focusScanInput, 250);
        }

        function isUnfocusedPageSurface(target) {
          return !target || target === document.body || target === document.documentElement;
        }

        // Show any top-level JS errors on screen.
        window.onerror = function (message, source, lineno, colno) {
          setStatus('JS error: ' + message + ' @ line ' + lineno);
        };

        // setStatus('Script started');

        function handleScanValue(rawValue) {
          let value = (rawValue || '').trim();
          if (!value) return;

          input.value = value;

          if (value.startsWith('http://') || value.startsWith('https://')) {
            try {
              const u = new URL(value);
              window.location.href = u.pathname;
              return;
            } catch (err) {}
          }

          const m = value.match(/^([A-Z]+):(.*)$/i);
          if (m) {
            const type = m[1].toUpperCase();
            const key = encodeURIComponent(m[2]);
            window.location.href = '/scan/' + type + '/' + key;
            return;
          }

          alert('Unrecognized scan format.');
        }

        form.addEventListener('submit', function (e) {
          e.preventDefault();
         // setStatus('Form submit fired');
          handleScanValue(input.value);
        });

        async function stopCameraScan() {
          // setStatus('stopCameraScan called');

          if (!html5QrCode || !scannerRunning) {
            reader.style.display = 'none';
            stopBtn.style.display = 'none';
            return;
          }

          try {
            await html5QrCode.stop();
          } catch (err) {
            console.error('Scanner stop error:', err);
          }

          try {
            await html5QrCode.clear();
          } catch (err) {
            console.error('Scanner clear error:', err);
          }

          html5QrCode = null;
          scannerRunning = false;
          reader.style.display = 'none';
          stopBtn.style.display = 'none';
          setStatus('Camera stopped');
        }

        async function startCameraScan() {
          //setStatus('startCameraScan called');

          if (typeof Html5Qrcode === 'undefined') {
          //  setStatus('Scanner library failed to load.');
            scheduleScanInputFocus();
            return;
          }

          if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            setStatus('Browser does not support camera access.');
            scheduleScanInputFocus();
            return;
          }

          if (scannerRunning) {
            setStatus('Scanner already running');
            return;
          }

          reader.style.display = 'block';
          stopBtn.style.display = 'block';
          cameraStarting = true;

          try {
            html5QrCode = new Html5Qrcode('reader');
            await html5QrCode.start(
              { facingMode: 'environment' },
              { fps: 10 },
              async function(decodedText) {
                input.value = decodedText;
                setStatus('Scan detected: ' + decodedText);
                await stopCameraScan();
                handleScanValue(decodedText);
              },
              function() {
                // ignore decode misses
              }
            );

            scannerRunning = true;
            cameraStarting = false;
            setStatus('Camera ready');
          } catch (err) {
            cameraStarting = false;
            console.error('Camera start failed:', err);
            setStatus('Camera start failed: ' + (err && err.message ? err.message : err));
            reader.style.display = 'none';
            stopBtn.style.display = 'none';
            scheduleScanInputFocus();
          }
        }

        // setStatus('Before button binding');

        scanBtn.addEventListener('click', function () {
          // alert('Scan button clicked');
          // setStatus('Scan button event fired');
          startCameraScan();
        });

        stopBtn.addEventListener('click', async function () {
          // setStatus('Stop button event fired');
          await stopCameraScan();
          scheduleScanInputFocus();
        });

        // Restore focus when the browser returns to this page or the page
        // becomes active again. The delayed retry handles mobile page restore.
        window.addEventListener('pageshow', scheduleScanInputFocus);
        window.addEventListener('focus', scheduleScanInputFocus);
        document.addEventListener('visibilitychange', function () {
          if (document.visibilityState === 'visible') {
            scheduleScanInputFocus();
          }
        });

        // If a mobile browser still refuses initial focus, capture the first
        // HID character from the otherwise-unfocused page. Once the input has
        // focus, normal input/form behavior handles the rest of the scan.
        document.addEventListener('keydown', function (event) {
          if (
            scannerRunning ||
            event.defaultPrevented ||
            event.isComposing ||
            event.ctrlKey ||
            event.metaKey ||
            event.altKey ||
            !isUnfocusedPageSurface(event.target)
          ) {
            return;
          }

          if (event.key === 'Enter') {
            if (input.value.trim()) {
              event.preventDefault();
              handleScanValue(input.value);
            }
            return;
          }

          if (event.key && event.key.length === 1) {
            event.preventDefault();
            input.value += event.key;
            focusScanInput();
          }
        }, true);

        // setStatus('Button binding complete');
        scheduleScanInputFocus();
      </script>
        </body>
        </html>
      `);
    });


    // ============================================================
    // SCAN + GPS FIELD ACCEPTANCE HARNESS
    // /scan/field-test
    //
    // Read-only engineering page used to collect evidence from the
    // real tablet + Zebra + browser geolocation path. It does not
    // query or write Production Database workflow state.
    // ============================================================
    router.get('/field-test', async (req, res) => {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.setHeader('Cache-Control', 'no-store');
      res.setHeader(
        'Content-Security-Policy',
        [
          "default-src 'self'",
          "script-src 'self' 'unsafe-inline'",
          "style-src 'self' 'unsafe-inline'",
          "img-src 'self' data:",
          "connect-src 'self'",
          "object-src 'none'"
        ].join('; ')
      );

      res.send(`
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>MSB Scan + GPS Field Acceptance</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              background: #0b1220;
              color: #fff;
              margin: 0;
              padding: 16px;
            }
            .card {
              max-width: 900px;
              margin: 0 auto 16px;
              background: #111a2b;
              border-radius: 12px;
              padding: 18px;
            }
            h1, h2 { margin-top: 0; }
            .warning {
              background: #4b3210;
              border: 1px solid #8c6420;
              border-radius: 8px;
              padding: 12px;
              margin-bottom: 16px;
            }
            .good { color: #8fe29a; }
            .bad { color: #ff9b9b; }
            .muted { color: #bbb; }
            .grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
              gap: 12px;
            }
            label {
              display: block;
              font-weight: bold;
              margin-bottom: 6px;
            }
            input, select, textarea, button {
              width: 100%;
              box-sizing: border-box;
              padding: 12px;
              font-size: 16px;
              border-radius: 8px;
              border: 1px solid #4a5568;
              margin-bottom: 10px;
            }
            input, select, textarea {
              background: #fff;
              color: #111;
            }
            .source-badge {
              display: inline-block;
              padding: 2px 6px;
              margin-right: 4px;
              border-radius: 999px;
              font-size: 11px;
              font-weight: bold;
              background: #39435a;
              color: #fff;
            }
            .source-badge.field { background: #285d3b; }
            .source-badge.preview { background: #6b4d16; }
            button, .btn {
              display: block;
              background: #1f6feb;
              color: #fff;
              text-decoration: none;
              text-align: center;
              font-weight: bold;
              cursor: pointer;
            }
            button.secondary, .btn.secondary { background: #39435a; }
            button.danger { background: #7c2d2d; }
            button:disabled, .btn.disabled {
              opacity: .5;
              pointer-events: none;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              font-size: 14px;
            }
            th, td {
              text-align: left;
              padding: 8px;
              border-bottom: 1px solid #39435a;
              vertical-align: top;
            }
            code {
              color: #c9d7ff;
              overflow-wrap: anywhere;
            }
            .value {
              font-size: 18px;
              font-weight: bold;
            }
            .small { font-size: 13px; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>MSB Scan + GPS Field Acceptance</h1>
            <div class="warning">
              <strong>READ-ONLY ENGINEERING TEST.</strong>
              This page does not change Setup movement state or write test observations to PostgreSQL.
              Test evidence stays in this browser until exported.
            </div>
            <div class="muted small">
              Reference source: <code>2026_msb.gpx</code> · ExpertGPS 9.34 / Garmin GPSMAP 66sr ·
              GPX modified 2026-09-15T20:51:16.014Z · 31 current GPX waypoints exported with type Stage.
              Names are used exactly as GPX reference labels; this page does not infer Production Stage/Scene hierarchy.
            </div>
          </div>

          <div class="card">
            <h2>1. Known field reference</h2>
            <label for="expectedReference">Where are you intentionally testing?</label>
            <select id="expectedReference">
              <option value="">Select expected GPX reference (optional)</option>
            </select>
            <div class="muted small">
              Select the place you believe you are standing at. The harness will still rank all nearby references independently.
              No automatic PASS/FAIL distance threshold is applied.
            </div>

            <label for="operatorLocationComment" style="margin-top:14px;">Operator location comment</label>
            <textarea
              id="operatorLocationComment"
              rows="3"
              placeholder="Record where you believe this scan should resolve, or any field context you want preserved with the observation."
              style="width:100%; box-sizing:border-box; padding:12px; font-size:16px; border-radius:8px; border:1px solid #4a5568; margin-bottom:10px;"
            ></textarea>
            <div class="muted small">
              This is your field judgment. It is saved separately from the selected GPX reference and from the GPS-derived nearest-location ranking.
            </div>
          </div>

          <div class="card">
            <h2>2. Tablet GPS</h2>
            <div class="grid">
              <button id="startGps" type="button">Start high-accuracy GPS</button>
              <button id="captureGps" type="button" class="secondary" disabled>Capture GPS-only sample</button>
            </div>
            <div id="gpsError" class="bad"></div>
            <div class="grid">
              <div><div class="muted">Latitude / Longitude</div><div id="gpsLatLon" class="value">No fix</div></div>
              <div><div class="muted">Reported accuracy</div><div id="gpsAccuracy" class="value">—</div></div>
              <div><div class="muted">Fix age</div><div id="gpsAge" class="value">—</div></div>
              <div><div class="muted">Nearest reference</div><div id="gpsNearest" class="value">—</div></div>
              <div><div class="muted">Connectivity</div><div id="connectivityState" class="value">Checking…</div></div>
            </div>
            <div id="gpsCandidates" class="small muted"></div>
          </div>

          <div class="card">
            <h2>3. Provisional field-reference observations</h2>
            <div class="warning">
              <strong>DISPOSABLE REFERENCE EVIDENCE.</strong>
              These observations are raw field evidence only. They do not update the GPX file, Production GIS, Stage/Scene identity, or PostgreSQL.
              Multiple observations with the same provisional name remain separate raw points; this page does not average them.
            </div>
            <div class="grid">
              <div>
                <label for="fieldReferenceName">Provisional reference name</label>
                <input id="fieldReferenceName" autocomplete="off" placeholder="Example: Elf Choir east-side stake" />
              </div>
              <div>
                <label for="fieldReferenceArea">Stage / area context (optional)</label>
                <input id="fieldReferenceArea" autocomplete="off" placeholder="Example: 08-Elf Choir-EC" />
              </div>
              <div>
                <label for="fieldReferenceEnvironment">Environment</label>
                <select id="fieldReferenceEnvironment">
                  <option value="">Not recorded</option>
                  <option value="OPEN_SKY">Open sky</option>
                  <option value="TREE_COVER">Tree cover</option>
                  <option value="STRUCTURE_ADJACENT">Structure-adjacent</option>
                  <option value="OTHER">Other</option>
                </select>
              </div>
            </div>
            <label for="fieldReferenceComment">Field-reference comment</label>
            <textarea id="fieldReferenceComment" rows="2" placeholder="Describe the physical point or why this reference may be useful."></textarea>
            <label for="fieldReferenceEnvironmentNote">Environment note (optional)</label>
            <textarea id="fieldReferenceEnvironmentNote" rows="2" placeholder="Trees, trailer, structure, open area, or other conditions affecting GPS."></textarea>
            <div class="grid">
              <button id="captureFieldReference" type="button" disabled>Capture current GPS as field reference</button>
              <button id="loadPreviewFix" type="button" class="secondary">Load controlled preview fix</button>
            </div>
            <div id="fieldReferenceStatus" class="muted small"></div>
            <div class="muted small">
              “Load controlled preview fix” is for pre-field UI acceptance only. Preview fixes are exported with
              <code>fix_source=CONTROLLED_PREVIEW</code> and must not be treated as physical GPS evidence.
            </div>
          </div>

          <div class="card">
            <h2>4. Scan while standing at the test point</h2>
            <div class="grid">
              <div>
                <label for="inputMethod">Input method</label>
                <select id="inputMethod">
                  <option value="ZEBRA_HID">Zebra HID</option>
                  <option value="MANUAL">Manual entry</option>
                  <option value="CAMERA">Camera (record only)</option>
                </select>
              </div>
              <div>
                <label for="scanInput">Asset identity</label>
                <form id="scanForm">
                  <input id="scanInput" autocomplete="off" autofocus placeholder="Scan DISP:, CONT:, CTRL:, LOC: or full scan URL" />
                </form>
              </div>
            </div>
            <div id="scanStatus" class="muted"></div>
            <a id="normalRoute" class="btn secondary disabled" target="_blank" rel="noopener">Verify normal Scan route</a>
            <div class="muted small">
              In this harness Enter records the scan instead of redirecting. Use “Verify normal Scan route” afterward when you want to confirm normal routing separately.
            </div>
          </div>

          <div class="card">
            <h2>5. Session evidence</h2>
            <div id="sessionSummary" class="muted">No observations yet.</div>
            <div id="fieldReferenceSummary" class="muted small" style="margin-top:8px;">No field-reference observations yet.</div>
            <div style="overflow-x:auto; margin-top:12px;">
              <table>
                <thead>
                  <tr>
                    <th>Field reference</th>
                    <th>Source</th>
                    <th>Area</th>
                    <th>Environment</th>
                    <th>GPS</th>
                    <th>Accuracy</th>
                    <th>Time</th>
                  </tr>
                </thead>
                <tbody id="fieldReferenceRows"></tbody>
              </table>
            </div>
            <div style="overflow-x:auto; margin-top:18px;">
              <table>
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Scan</th>
                    <th>Expected</th>
                    <th>Operator comment</th>
                    <th>Nearest</th>
                    <th>Expected rank</th>
                    <th>GPS accuracy</th>
                  </tr>
                </thead>
                <tbody id="observationRows"></tbody>
              </table>
            </div>
            <div class="grid" style="margin-top:12px;">
              <button id="exportJson" type="button" class="secondary">Export JSON</button>
              <button id="exportCsv" type="button" class="secondary">Export CSV</button>
              <button id="clearSession" type="button" class="danger">Clear local test data</button>
            </div>
          </div>

          <script>
            const referencePoints = [{"name":"04-Food Collection-FC","lat":43.7777955,"lon":-87.74358339},{"name":"01-Front Entrance-FE","lat":43.77752968,"lon":-87.74151575},{"name":"00-HWY 42-HW","lat":43.77792811,"lon":-87.74186506},{"name":"05-Festive Trees-FT","lat":43.77833036,"lon":-87.74354104},{"name":"05a-Mega Star-MS","lat":43.7785483,"lon":-87.74319754},{"name":"06-Post Office-PO","lat":43.77874564,"lon":-87.74423908},{"name":"07a-Who Forest-WF","lat":43.77948868,"lon":-87.74573914},{"name":"08-Elf Choir-EC","lat":43.77942108,"lon":-87.74623869},{"name":"09-Global Warming-GW","lat":43.77977361,"lon":-87.74652366},{"name":"10-Stars-ST","lat":43.78026391,"lon":-87.74678012},{"name":"11-Sledders-SL","lat":43.78038637,"lon":-87.74757818},{"name":"13-Winter Wonderland-WW","lat":43.77984397,"lon":-87.74782959},{"name":"14-Icicle Tunnel-IT","lat":43.7789102,"lon":-87.74828739},{"name":"15-Church-Bells-CH","lat":43.77852769,"lon":-87.74910923},{"name":"16-Northern Lights-NL","lat":43.77721337,"lon":-87.74888248},{"name":"17-Candyland-CL","lat":43.77680829,"lon":-87.74697976},{"name":"18-Dancing Forest-DF","lat":43.77649806,"lon":-87.74559202},{"name":"19-Santa's Workshop-SW","lat":43.77683742,"lon":-87.74577019},{"name":"20-Snow Storm-SS","lat":43.77625492,"lon":-87.74475721},{"name":"21-Polar Bear Playground-PB","lat":43.77604286,"lon":-87.74487442},{"name":"22-Glistening Grove-GG","lat":43.77573908,"lon":-87.74390953},{"name":"23-Peanuts-PN","lat":43.77577894,"lon":-87.74294278},{"name":"24-Traditional Christmas-TC","lat":43.77591889,"lon":-87.74289151},{"name":"25-Racing Arches-RA","lat":43.77636681,"lon":-87.74226992},{"name":"26-Magic Igloo-MI","lat":43.77714554,"lon":-87.74166344},{"name":"02-Triangle-TR","lat":43.77709198,"lon":-87.74208111},{"name":"03-Welcome Area-WA","lat":43.77741945,"lon":-87.7426539},{"name":"03a-Mega Cube-MC","lat":43.77756775,"lon":-87.7426221},{"name":"30-Santa's Station-QV","lat":43.78175546,"lon":-87.74664227},{"name":"30-Santa's Station Entrance","lat":43.78063504,"lon":-87.74542583},{"name":"07-Whoville-WV","lat":43.77955255,"lon":-87.74491109}];
            const STORAGE_KEY = 'msb_scan_gps_field_acceptance_v1';
            const SOURCE = {
              file: '2026_msb.gpx',
              creator: 'ExpertGPS 9.34 using Garmin GPSMAP 66sr',
              modified_at: '2026-09-15T20:51:16.014Z',
              sha256: 'eff23e666e0c288b52741621c1450b5a95150b36394de38bfe50b307c311de74',
              source_waypoint_count: 519,
              selection_rule: 'type=Stage',
              selected_waypoint_count: referencePoints.length,
              reference_count: referencePoints.length
            };

            const expectedReference = document.getElementById('expectedReference');
            const operatorLocationComment = document.getElementById('operatorLocationComment');
            const startGps = document.getElementById('startGps');
            const captureGps = document.getElementById('captureGps');
            const gpsError = document.getElementById('gpsError');
            const gpsLatLon = document.getElementById('gpsLatLon');
            const gpsAccuracy = document.getElementById('gpsAccuracy');
            const gpsAge = document.getElementById('gpsAge');
            const gpsNearest = document.getElementById('gpsNearest');
            const gpsCandidates = document.getElementById('gpsCandidates');
            const connectivityState = document.getElementById('connectivityState');
            const fieldReferenceName = document.getElementById('fieldReferenceName');
            const fieldReferenceArea = document.getElementById('fieldReferenceArea');
            const fieldReferenceEnvironment = document.getElementById('fieldReferenceEnvironment');
            const fieldReferenceComment = document.getElementById('fieldReferenceComment');
            const fieldReferenceEnvironmentNote = document.getElementById('fieldReferenceEnvironmentNote');
            const captureFieldReference = document.getElementById('captureFieldReference');
            const loadPreviewFix = document.getElementById('loadPreviewFix');
            const fieldReferenceStatus = document.getElementById('fieldReferenceStatus');
            const fieldReferenceSummary = document.getElementById('fieldReferenceSummary');
            const fieldReferenceRows = document.getElementById('fieldReferenceRows');
            const inputMethod = document.getElementById('inputMethod');
            const scanForm = document.getElementById('scanForm');
            const scanInput = document.getElementById('scanInput');
            const scanStatus = document.getElementById('scanStatus');
            const normalRoute = document.getElementById('normalRoute');
            const sessionSummary = document.getElementById('sessionSummary');
            const observationRows = document.getElementById('observationRows');
            const exportJson = document.getElementById('exportJson');
            const exportCsv = document.getElementById('exportCsv');
            const clearSession = document.getElementById('clearSession');

            let watchId = null;
            let latestPosition = null;
            let gpsStartedAt = null;

            function newId() {
              if (window.crypto && typeof window.crypto.randomUUID === 'function') {
                return window.crypto.randomUUID();
              }
              return 'obs-' + Date.now() + '-' + Math.random().toString(16).slice(2);
            }

            function newSession() {
              return {
                schema_version: 2,
                session_id: newId(),
                started_at: new Date().toISOString(),
                reference_source: SOURCE,
                reference_points: referencePoints.map(function(point) {
                  return { name: point.name, lat: point.lat, lon: point.lon };
                }),
                user_agent: navigator.userAgent,
                field_reference_observations: [],
                observations: []
              };
            }

            function loadSession() {
              try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return newSession();
                const parsed = JSON.parse(raw);
                if (!parsed || !Array.isArray(parsed.observations)) return newSession();
                if (!Array.isArray(parsed.field_reference_observations)) {
                  parsed.field_reference_observations = [];
                }
                parsed.schema_version = 2;
                return parsed;
              } catch (err) {
                return newSession();
              }
            }

            let session = loadSession();

            function referenceCandidates() {
              const seeds = referencePoints.map(function(point) {
                return {
                  reference_id: 'GPX:' + point.name,
                  source_type: 'GPX_SEED',
                  name: point.name,
                  lat: point.lat,
                  lon: point.lon,
                  area_context: null,
                  observation_recorded_at: null
                };
              });
              const field = session.field_reference_observations.map(function(obs) {
                return {
                  reference_id: 'FIELD:' + obs.field_reference_observation_id,
                  source_type: 'FIELD_OBSERVATION',
                  name: obs.provisional_name,
                  lat: obs.gps.latitude,
                  lon: obs.gps.longitude,
                  area_context: obs.area_context,
                  observation_recorded_at: obs.recorded_at
                };
              });
              return seeds.concat(field);
            }

            function renderExpectedReferenceOptions() {
              const selected = expectedReference.value;
              expectedReference.innerHTML = '<option value="">Select expected reference (optional)</option>';
              referenceCandidates()
                .slice()
                .sort(function(a, b) {
                  if (a.source_type !== b.source_type) return a.source_type === 'GPX_SEED' ? -1 : 1;
                  return a.name.localeCompare(b.name);
                })
                .forEach(function(point) {
                  const option = document.createElement('option');
                  option.value = point.reference_id;
                  option.textContent =
                    (point.source_type === 'GPX_SEED' ? '[GPX] ' : '[FIELD] ') +
                    point.name +
                    (point.area_context ? ' · ' + point.area_context : '');
                  expectedReference.appendChild(option);
                });
              if (Array.from(expectedReference.options).some(function(option) { return option.value === selected; })) {
                expectedReference.value = selected;
              }
            }

            renderExpectedReferenceOptions();

            function toRadians(value) {
              return value * Math.PI / 180;
            }

            function distanceFeet(lat1, lon1, lat2, lon2) {
              const earthFeet = 20902231;
              const dLat = toRadians(lat2 - lat1);
              const dLon = toRadians(lon2 - lon1);
              const a =
                Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2);
              const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
              return earthFeet * c;
            }

            function rankedReferences(lat, lon) {
              return referenceCandidates()
                .map(function(point) {
                  return {
                    reference_id: point.reference_id,
                    source_type: point.source_type,
                    name: point.name,
                    latitude: point.lat,
                    longitude: point.lon,
                    area_context: point.area_context,
                    observation_recorded_at: point.observation_recorded_at,
                    distance_ft: distanceFeet(lat, lon, point.lat, point.lon)
                  };
                })
                .sort(function(a, b) { return a.distance_ft - b.distance_ft; });
            }

            function referenceLabel(item) {
              if (!item) return '—';
              return (item.source_type === 'FIELD_OBSERVATION' ? '[FIELD] ' : '[GPX] ') + item.name;
            }

            function connectivitySnapshot() {
              const connection =
                navigator.connection ||
                navigator.mozConnection ||
                navigator.webkitConnection ||
                null;

              return {
                browser_online: navigator.onLine === true,
                effective_type: connection && connection.effectiveType ? connection.effectiveType : null,
                downlink_mbps: connection && typeof connection.downlink === 'number' ? connection.downlink : null,
                rtt_ms: connection && typeof connection.rtt === 'number' ? connection.rtt : null,
                save_data: connection && typeof connection.saveData === 'boolean' ? connection.saveData : null
              };
            }

            function renderConnectivity() {
              const state = connectivitySnapshot();
              connectivityState.textContent = state.browser_online ? 'ONLINE' : 'OFFLINE';
              connectivityState.className = 'value ' + (state.browser_online ? 'good' : 'bad');
            }

            function positionSnapshot(position) {
              if (!position || !position.coords) return null;
              return {
                latitude: position.coords.latitude,
                longitude: position.coords.longitude,
                accuracy_m: position.coords.accuracy,
                accuracy_ft: position.coords.accuracy == null ? null : position.coords.accuracy * 3.280839895,
                altitude_m: position.coords.altitude,
                altitude_accuracy_m: position.coords.altitudeAccuracy,
                heading_deg: position.coords.heading,
                speed_mps: position.coords.speed,
                fix_timestamp: new Date(position.timestamp).toISOString(),
                fix_age_ms: Math.max(0, Date.now() - Number(position.timestamp)),
                fix_source: position._msbSource || 'BROWSER_GEOLOCATION'
              };
            }

            function renderGps() {
              if (!latestPosition) return;
              const gps = positionSnapshot(latestPosition);
              const ranked = rankedReferences(gps.latitude, gps.longitude);
              gpsLatLon.textContent = gps.latitude.toFixed(7) + ', ' + gps.longitude.toFixed(7);
              gpsAccuracy.textContent = gps.accuracy_ft == null ? 'Unknown' : gps.accuracy_ft.toFixed(1) + ' ft';
              gpsAge.textContent = (gps.fix_age_ms / 1000).toFixed(1) + ' sec';
              gpsNearest.textContent = referenceLabel(ranked[0]) + ' · ' + ranked[0].distance_ft.toFixed(1) + ' ft';
              gpsCandidates.textContent = 'Nearest 5: ' + ranked.slice(0, 5).map(function(item, index) {
                return (index + 1) + '. ' + referenceLabel(item) + ' (' + item.distance_ft.toFixed(1) + ' ft)';
              }).join(' · ');
              captureGps.disabled = false;
              captureFieldReference.disabled = false;
            }

            function startGpsWatch() {
              gpsError.textContent = '';
              if (!navigator.geolocation) {
                gpsError.textContent = 'This browser does not expose geolocation.';
                return;
              }
              if (watchId != null) {
                gpsError.textContent = 'GPS watch is already running.';
                return;
              }
              gpsStartedAt = Date.now();
              startGps.disabled = true;
              startGps.textContent = 'GPS running…';
              watchId = navigator.geolocation.watchPosition(
                function(position) {
                  latestPosition = position;
                  renderGps();
                },
                function(error) {
                  gpsError.textContent = 'GPS error ' + error.code + ': ' + error.message;
                  startGps.disabled = false;
                  startGps.textContent = 'Retry high-accuracy GPS';
                  if (watchId != null) {
                    navigator.geolocation.clearWatch(watchId);
                    watchId = null;
                  }
                },
                {
                  enableHighAccuracy: true,
                  maximumAge: 0,
                  timeout: 15000
                }
              );
            }

            function persistSession() {
              localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
            }

            function loadControlledPreviewFix() {
              const selected = referenceCandidates().find(function(item) {
                return item.reference_id === expectedReference.value;
              }) || referenceCandidates().find(function(item) {
                return item.source_type === 'GPX_SEED';
              });
              if (!selected) return;
              latestPosition = {
                coords: {
                  latitude: selected.lat,
                  longitude: selected.lon,
                  accuracy: 3,
                  altitude: null,
                  altitudeAccuracy: null,
                  heading: null,
                  speed: null
                },
                timestamp: Date.now(),
                _msbSource: 'CONTROLLED_PREVIEW'
              };
              gpsStartedAt = Date.now();
              renderGps();
              fieldReferenceStatus.textContent =
                'Controlled preview fix loaded from ' + referenceLabel(selected) +
                '. This is UI test data, not physical GPS evidence.';
            }

            function captureFieldReferenceObservation() {
              const gps = positionSnapshot(latestPosition);
              const provisionalName = fieldReferenceName.value.trim();
              if (!gps) {
                fieldReferenceStatus.textContent = 'Start GPS or load a controlled preview fix first.';
                return;
              }
              if (!provisionalName) {
                fieldReferenceStatus.textContent = 'Enter a provisional field-reference name first.';
                fieldReferenceName.focus();
                return;
              }

              const observation = {
                field_reference_observation_id: newId(),
                provisional_name: provisionalName,
                area_context: fieldReferenceArea.value.trim() || null,
                operator_comment: fieldReferenceComment.value.trim() || null,
                environment_context: fieldReferenceEnvironment.value || null,
                environment_note: fieldReferenceEnvironmentNote.value.trim() || null,
                recorded_at: new Date().toISOString(),
                gps: gps,
                gps_acquisition_elapsed_ms:
                  gpsStartedAt == null ? null : Number(latestPosition.timestamp) - gpsStartedAt,
                connectivity: connectivitySnapshot()
              };

              session.field_reference_observations.push(observation);
              persistSession();
              renderExpectedReferenceOptions();
              renderFieldReferences();
              renderGps();
              renderSession();
              fieldReferenceStatus.textContent =
                'Recorded raw field-reference observation “' + provisionalName + '” (' +
                gps.fix_source + '). Multiple observations with this name remain separate raw points.';
              scheduleScanInputFocus();
            }

            function canonicalScan(raw) {
              const value = String(raw || '').trim();
              if (!value) return null;

              if (value.startsWith('http://') || value.startsWith('https://')) {
                try {
                  const url = new URL(value);
                  const match = url.pathname.match(/\/scan\/([A-Za-z]+)\/([^/?#]+)/);
                  if (match) {
                    return {
                      type: match[1].toUpperCase(),
                      key: decodeURIComponent(match[2]),
                      canonical: match[1].toUpperCase() + ':' + decodeURIComponent(match[2])
                    };
                  }
                } catch (err) {}
              }

              const compact = value.match(/^([A-Za-z]+):(.*)$/);
              if (!compact || !compact[2]) return null;
              return {
                type: compact[1].toUpperCase(),
                key: compact[2],
                canonical: compact[1].toUpperCase() + ':' + compact[2]
              };
            }

            function expectedResult(ranked) {
              const referenceId = expectedReference.value || null;
              if (!referenceId) {
                return {
                  reference_id: null,
                  source_type: null,
                  name: null,
                  latitude: null,
                  longitude: null,
                  rank: null,
                  distance_ft: null
                };
              }

              const point = referenceCandidates().find(function(item) {
                return item.reference_id === referenceId;
              }) || null;
              const index = ranked.findIndex(function(item) {
                return item.reference_id === referenceId;
              });
              return {
                reference_id: point ? point.reference_id : referenceId,
                source_type: point ? point.source_type : null,
                name: point ? point.name : null,
                latitude: point ? point.lat : null,
                longitude: point ? point.lon : null,
                rank: index < 0 ? null : index + 1,
                distance_ft: index < 0 ? null : ranked[index].distance_ft
              };
            }

            function recordObservation(kind, rawScan) {
              const gps = positionSnapshot(latestPosition);
              const ranked = gps ? rankedReferences(gps.latitude, gps.longitude) : [];
              const expected = expectedResult(ranked);
              const parsed = rawScan ? canonicalScan(rawScan) : null;

              const observation = {
                observation_id: newId(),
                kind: kind,
                recorded_at: new Date().toISOString(),
                input_method: kind === 'SCAN' ? inputMethod.value : null,
                scan_raw: rawScan || null,
                scan_canonical: parsed ? parsed.canonical : null,
                scan_type: parsed ? parsed.type : null,
                scan_key: parsed ? parsed.key : null,
                expected_reference_id: expected.reference_id,
                expected_reference_source_type: expected.source_type,
                expected_reference: expected.name,
                expected_reference_latitude: expected.latitude,
                expected_reference_longitude: expected.longitude,
                operator_location_comment: operatorLocationComment.value.trim() || null,
                expected_rank: expected.rank,
                expected_distance_ft: expected.distance_ft,
                gps: gps,
                connectivity: connectivitySnapshot(),
                gps_acquisition_elapsed_ms: gpsStartedAt == null || !gps ? null : Number(latestPosition.timestamp) - gpsStartedAt,
                nearest_references: ranked.slice(0, 5)
              };

              session.observations.push(observation);
              persistSession();
              renderSession();

              if (kind === 'SCAN') {
                if (parsed) {
                  scanStatus.textContent = 'Recorded ' + parsed.canonical + (gps ? ' with GPS evidence.' : ' without a GPS fix.');
                  normalRoute.href = '/scan/' + encodeURIComponent(parsed.type) + '/' + encodeURIComponent(parsed.key);
                  normalRoute.classList.remove('disabled');
                } else {
                  scanStatus.textContent = 'Recorded raw scan, but it did not match a recognized TYPE:key or /scan/TYPE/key value.';
                  normalRoute.removeAttribute('href');
                  normalRoute.classList.add('disabled');
                }
                scanInput.value = '';
                scheduleScanInputFocus();
              }
            }

            function escapeHtml(value) {
              return String(value == null ? '' : value)
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;');
            }

            function renderFieldReferences() {
              fieldReferenceRows.innerHTML = '';
              session.field_reference_observations.slice().reverse().forEach(function(obs) {
                const tr = document.createElement('tr');
                const gps = obs.gps || {};
                const sourceClass = gps.fix_source === 'CONTROLLED_PREVIEW' ? 'preview' : 'field';
                tr.innerHTML =
                  '<td>' + escapeHtml(obs.provisional_name) + '</td>' +
                  '<td><span class="source-badge ' + sourceClass + '">' +
                    escapeHtml(gps.fix_source || 'BROWSER_GEOLOCATION') + '</span></td>' +
                  '<td>' + escapeHtml(obs.area_context || '—') + '</td>' +
                  '<td>' + escapeHtml(
                    (obs.environment_context || '—') +
                    (obs.environment_note ? ' · ' + obs.environment_note : '')
                  ) + '</td>' +
                  '<td>' + escapeHtml(
                    gps.latitude == null ? '—' :
                    Number(gps.latitude).toFixed(7) + ', ' + Number(gps.longitude).toFixed(7)
                  ) + '</td>' +
                  '<td>' + escapeHtml(
                    gps.accuracy_ft == null ? '—' : Number(gps.accuracy_ft).toFixed(1) + ' ft'
                  ) + '</td>' +
                  '<td>' + escapeHtml(new Date(obs.recorded_at).toLocaleTimeString()) + '</td>';
                fieldReferenceRows.appendChild(tr);
              });
              const physicalCount = session.field_reference_observations.filter(function(obs) {
                return obs.gps && obs.gps.fix_source !== 'CONTROLLED_PREVIEW';
              }).length;
              const previewCount = session.field_reference_observations.length - physicalCount;
              fieldReferenceSummary.textContent =
                session.field_reference_observations.length + ' raw field-reference observations · ' +
                physicalCount + ' browser-GPS · ' + previewCount + ' controlled preview · no averaging/promotion';
            }

            function renderSession() {
              observationRows.innerHTML = '';
              session.observations.slice().reverse().forEach(function(obs) {
                const nearest = obs.nearest_references && obs.nearest_references[0];
                const tr = document.createElement('tr');
                tr.innerHTML =
                  '<td>' + escapeHtml(new Date(obs.recorded_at).toLocaleTimeString()) + '</td>' +
                  '<td>' + escapeHtml(obs.scan_canonical || (obs.kind === 'GPS_SAMPLE' ? 'GPS sample' : obs.scan_raw || '—')) + '</td>' +
                  '<td>' + escapeHtml(obs.expected_reference || '—') + '</td>' +
                  '<td>' + escapeHtml(obs.operator_location_comment || '—') + '</td>' +
                  '<td>' + escapeHtml(nearest ? referenceLabel(nearest) + ' · ' + nearest.distance_ft.toFixed(1) + ' ft' : 'No GPS') + '</td>' +
                  '<td>' + escapeHtml(obs.expected_rank == null ? '—' : String(obs.expected_rank)) + '</td>' +
                  '<td>' + escapeHtml(obs.gps && obs.gps.accuracy_ft != null ? obs.gps.accuracy_ft.toFixed(1) + ' ft' : '—') + '</td>';
                observationRows.appendChild(tr);
              });

              const gpsCount = session.observations.filter(function(obs) { return !!obs.gps; }).length;
              const offlineCount = session.observations.filter(function(obs) {
                return obs.connectivity && obs.connectivity.browser_online === false;
              }).length;
              const rankedCount = session.observations.filter(function(obs) { return obs.expected_rank != null; }).length;
              const nearestExpected = session.observations.filter(function(obs) { return obs.expected_rank === 1; }).length;
              sessionSummary.textContent =
                session.observations.length + ' observations · ' +
                session.field_reference_observations.length + ' raw field references · ' +
                gpsCount + ' with GPS · ' +
                offlineCount + ' captured offline · ' +
                (rankedCount ? nearestExpected + '/' + rankedCount + ' expected locations ranked #1' : 'no expected-location comparisons yet') +
                ' · local session ' + session.session_id;
            }

            function csvCell(value) {
              const text = value == null ? '' : String(value);
              return '"' + text.replace(/"/g, '""') + '"';
            }

            function exportFile(filename, mime, text) {
              const blob = new Blob([text], { type: mime });
              const url = URL.createObjectURL(blob);
              const anchor = document.createElement('a');
              anchor.href = url;
              anchor.download = filename;
              document.body.appendChild(anchor);
              anchor.click();
              anchor.remove();
              window.setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
            }

            function exportSessionJson() {
              exportFile(
                'msb-scan-gps-field-test-' + session.session_id + '.json',
                'application/json',
                JSON.stringify(session, null, 2)
              );
            }

            function exportSessionCsv() {
              const header = [
                'record_type','observation_id','field_reference_observation_id','recorded_at','kind','input_method',
                'scan_raw','scan_canonical','scan_type','scan_key',
                'reference_source_sha256','reference_source_modified_at','reference_selection_rule',
                'source_waypoint_count','selected_waypoint_count',
                'expected_reference_id','expected_reference_source_type','expected_reference',
                'expected_reference_latitude','expected_reference_longitude',
                'field_reference_name','field_reference_area_context','field_reference_operator_comment',
                'field_reference_environment_context','field_reference_environment_note','gps_fix_source',
                'operator_location_comment','expected_rank','expected_distance_ft',
                'latitude','longitude','accuracy_ft','fix_timestamp','fix_age_ms','gps_acquisition_elapsed_ms',
                'browser_online','effective_type','downlink_mbps','rtt_ms','save_data',
                'nearest_1_source','nearest_1','nearest_1_distance_ft',
                'nearest_2_source','nearest_2','nearest_2_distance_ft',
                'nearest_3_source','nearest_3','nearest_3_distance_ft',
                'nearest_4_source','nearest_4','nearest_4_distance_ft',
                'nearest_5_source','nearest_5','nearest_5_distance_ft'
              ];
              const rows = [header.map(csvCell).join(',')];
              session.observations.forEach(function(obs) {
                const ranked = obs.nearest_references || [];
                const gps = obs.gps || {};
                const connectivity = obs.connectivity || {};
                rows.push([
                  'OBSERVATION', obs.observation_id, null, obs.recorded_at, obs.kind, obs.input_method,
                  obs.scan_raw, obs.scan_canonical, obs.scan_type, obs.scan_key,
                  session.reference_source && session.reference_source.sha256,
                  session.reference_source && session.reference_source.modified_at,
                  session.reference_source && session.reference_source.selection_rule,
                  session.reference_source && session.reference_source.source_waypoint_count,
                  session.reference_source && session.reference_source.selected_waypoint_count,
                  obs.expected_reference_id, obs.expected_reference_source_type, obs.expected_reference,
                  obs.expected_reference_latitude, obs.expected_reference_longitude,
                  null, null, null, null, null, gps.fix_source,
                  obs.operator_location_comment, obs.expected_rank, obs.expected_distance_ft,
                  gps.latitude, gps.longitude, gps.accuracy_ft, gps.fix_timestamp, gps.fix_age_ms,
                  obs.gps_acquisition_elapsed_ms,
                  connectivity.browser_online, connectivity.effective_type, connectivity.downlink_mbps,
                  connectivity.rtt_ms, connectivity.save_data,
                  ranked[0] && ranked[0].source_type, ranked[0] && ranked[0].name, ranked[0] && ranked[0].distance_ft,
                  ranked[1] && ranked[1].source_type, ranked[1] && ranked[1].name, ranked[1] && ranked[1].distance_ft,
                  ranked[2] && ranked[2].source_type, ranked[2] && ranked[2].name, ranked[2] && ranked[2].distance_ft,
                  ranked[3] && ranked[3].source_type, ranked[3] && ranked[3].name, ranked[3] && ranked[3].distance_ft,
                  ranked[4] && ranked[4].source_type, ranked[4] && ranked[4].name, ranked[4] && ranked[4].distance_ft
                ].map(csvCell).join(','));
              });
              session.field_reference_observations.forEach(function(obs) {
                const gps = obs.gps || {};
                const connectivity = obs.connectivity || {};
                rows.push([
                  'FIELD_REFERENCE_OBSERVATION', null, obs.field_reference_observation_id, obs.recorded_at,
                  'FIELD_REFERENCE', null, null, null, null, null,
                  session.reference_source && session.reference_source.sha256,
                  session.reference_source && session.reference_source.modified_at,
                  session.reference_source && session.reference_source.selection_rule,
                  session.reference_source && session.reference_source.source_waypoint_count,
                  session.reference_source && session.reference_source.selected_waypoint_count,
                  null, null, null, null, null,
                  obs.provisional_name, obs.area_context, obs.operator_comment,
                  obs.environment_context, obs.environment_note, gps.fix_source,
                  null, null, null,
                  gps.latitude, gps.longitude, gps.accuracy_ft, gps.fix_timestamp, gps.fix_age_ms,
                  obs.gps_acquisition_elapsed_ms,
                  connectivity.browser_online, connectivity.effective_type, connectivity.downlink_mbps,
                  connectivity.rtt_ms, connectivity.save_data,
                  null, null, null, null, null, null, null, null, null, null, null, null, null, null, null
                ].map(csvCell).join(','));
              });
              exportFile(
                'msb-scan-gps-field-test-' + session.session_id + '.csv',
                'text/csv',
                rows.join('\n')
              );
            }

            function focusScanInput() {
              try {
                scanInput.focus({ preventScroll: true });
              } catch (err) {
                scanInput.focus();
              }
            }

            function scheduleScanInputFocus() {
              window.setTimeout(focusScanInput, 0);
              window.setTimeout(focusScanInput, 250);
            }

            function isUnfocusedPageSurface(target) {
              return !target || target === document.body || target === document.documentElement;
            }

            startGps.addEventListener('click', function() {
              startGpsWatch();
              scheduleScanInputFocus();
            });
            captureGps.addEventListener('click', function() {
              recordObservation('GPS_SAMPLE', null);
              scheduleScanInputFocus();
            });
            captureFieldReference.addEventListener('click', captureFieldReferenceObservation);
            loadPreviewFix.addEventListener('click', function() {
              loadControlledPreviewFix();
              scheduleScanInputFocus();
            });
            expectedReference.addEventListener('change', function() {
              if (latestPosition && latestPosition._msbSource === 'CONTROLLED_PREVIEW') {
                loadControlledPreviewFix();
              }
              scheduleScanInputFocus();
            });
            inputMethod.addEventListener('change', scheduleScanInputFocus);
            operatorLocationComment.addEventListener('blur', scheduleScanInputFocus);
            fieldReferenceName.addEventListener('blur', scheduleScanInputFocus);
            fieldReferenceArea.addEventListener('blur', scheduleScanInputFocus);
            fieldReferenceComment.addEventListener('blur', scheduleScanInputFocus);
            fieldReferenceEnvironmentNote.addEventListener('blur', scheduleScanInputFocus);
            scanForm.addEventListener('submit', function(event) {
              event.preventDefault();
              const raw = scanInput.value.trim();
              if (raw) recordObservation('SCAN', raw);
            });

            exportJson.addEventListener('click', exportSessionJson);
            exportCsv.addEventListener('click', exportSessionCsv);
            clearSession.addEventListener('click', function() {
              if (!window.confirm('Clear all locally stored field-test observations on this browser?')) return;
              localStorage.removeItem(STORAGE_KEY);
              session = newSession();
              fieldReferenceStatus.textContent = '';
              renderExpectedReferenceOptions();
              renderFieldReferences();
              renderGps();
              renderSession();
            });

            document.addEventListener('keydown', function(event) {
              if (
                event.defaultPrevented ||
                event.isComposing ||
                event.ctrlKey ||
                event.metaKey ||
                event.altKey ||
                !isUnfocusedPageSurface(event.target)
              ) {
                return;
              }

              if (event.key === 'Enter') {
                if (scanInput.value.trim()) {
                  event.preventDefault();
                  recordObservation('SCAN', scanInput.value);
                }
                return;
              }

              if (event.key && event.key.length === 1) {
                event.preventDefault();
                scanInput.value += event.key;
                focusScanInput();
              }
            }, true);

            window.setInterval(renderGps, 1000);
            window.addEventListener('online', renderConnectivity);
            window.addEventListener('offline', renderConnectivity);
            window.addEventListener('pageshow', function() {
              renderConnectivity();
              scheduleScanInputFocus();
            });
            window.addEventListener('focus', scheduleScanInputFocus);
            document.addEventListener('visibilitychange', function() {
              if (document.visibilityState === 'visible') scheduleScanInputFocus();
            });

            renderConnectivity();
            renderExpectedReferenceOptions();
            renderFieldReferences();
            renderSession();
            scheduleScanInputFocus();
          </script>
        </body>
        </html>
      `);
    });

    // ============================================================
    // DISPLAY HUB
    // /scan/DISP/:key
    // Main landing page when a display is scanned
    // ============================================================
    router.get('/DISP/:key', async (req, res) => {
      const key = req.params.key;

      try {
        const display = await database('ref.display')
          .select('display_id', 'display_name', 'container_id', 'display_status_id')
          .where('display_id', key)
          .first();

        // ---- Check display exists FIRST ----  
        if (!display) {
          res.status(404).send(`
            <h1>Display Not Found</h1>
            <p>No display found for DISP:${escapeHtml(key)}</p>
          `);
          return;
        }

        // ---- Get open work order count ----
        let woCount = 0;

        try {
          const result = await database('ops.work_order')
            .count('* as count')
            .where('display_id', display.display_id)
            .andWhere('is_active', true);

          woCount = Number(result?.[0]?.count ?? 0);
        } catch (err) {
          woCount = 0;
        }

        // ---- Get current season ----
        let currentSeasonYear = null;

        try {
          const season = await database('ref.season')
            .select('season_year')
            .where('active_flag', true)
            .first();

          currentSeasonYear = season?.season_year ?? null;
        } catch (err) {
          currentSeasonYear = null;
        }

        // ---- Test session state for this display ----
        let testButtonHtml = `<div class="btn secondary disabled">Testing Status Unknown</div>`;

        if (!display.container_id) {
          testButtonHtml = `<div class="btn secondary disabled">No Container Assigned</div>`;
        } else if (!currentSeasonYear) {
          testButtonHtml = `<div class="btn secondary disabled">No Current Season</div>`;
        } else {
          let testSession = null;

          try {
            testSession = await database('ops.test_session')
              .select('test_session_id', 'container_id', 'season_year', 'container_test_status_id')
              .where('container_id', display.container_id)
              .where('season_year', currentSeasonYear)
              .first();
          } catch (err) {
            testSession = null;
          }

          if (!testSession) {
            testButtonHtml = `<div class="btn secondary disabled">No Container Test Session</div>`;
          } else {
            const containerTestStatus = Number(testSession.container_test_status_id);

            if (containerTestStatus === 1) {
              testButtonHtml = `<div class="btn secondary disabled">Container Not Started</div>`;
            } else if (containerTestStatus === 2) {
              let displayTestSession = null;

              try {
                displayTestSession = await database('ops.display_test_session')
                  .select('display_test_session_id', 'test_session_id', 'display_id', 'test_status')
                  .where('test_session_id', testSession.test_session_id)
                  .where('display_id', display.display_id)
                  .first();
              } catch (err) {
                displayTestSession = null;
              }

              if (!displayTestSession) {
                testButtonHtml = `<div class="btn secondary disabled">Display Not In Active Test Session</div>`;
              } else if (displayTestSession.test_status == null) {
                testButtonHtml = `<a class="btn secondary" href="/scan/DISP/${encodeURIComponent(display.display_id)}/test">Open Current Test Record</a>`;
              } else {
                testButtonHtml = `<a class="btn secondary" href="/scan/DISP/${encodeURIComponent(display.display_id)}/test">View Test Record</a>`;
              }
            } else if (containerTestStatus === 3) {
              testButtonHtml = `<div class="btn secondary disabled">Container Testing Complete</div>`;
            } else if (containerTestStatus === 4) {
              testButtonHtml = `<div class="btn secondary disabled">Testing Not Required</div>`;
            } else if (containerTestStatus === 5) {
              testButtonHtml = `<div class="btn secondary disabled">Testing Deferred</div>`;
            } else {
              testButtonHtml = `<div class="btn secondary disabled">Unknown Test Status</div>`;
            }
          }
        }


        
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.send(`
          <!doctype html>
          <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>Display ${escapeHtml(display.display_id)}</title>
            <style>
              body {
                font-family: Arial, sans-serif;
                background: #0b1220;
                color: #fff;
                margin: 0;
                padding: 20px;
              }
              .card {
                max-width: 700px;
                margin: 0 auto;
                background: #111a2b;
                border-radius: 12px;
                padding: 20px;
              }
              .meta {
                color: #bbb;
                margin-bottom: 20px;
              }
              .btn,
              .btn:visited,
              .btn:focus {
                display: block;
                background: #1f6feb;
                color: #fff;
                text-decoration: none;
                padding: 14px 16px;
                border-radius: 8px;
                margin-bottom: 12px;
                text-align: center;
                font-weight: bold;
                outline: none;
              }

              /* Press effect (tap) */
              .btn:active {
                transform: scale(0.98);
              }
              .secondary,
              .secondary:visited,
              .secondary:focus {
                background: #39435a;
                color: #fff;
              }

              .secondary:active {
                transform: scale(0.98);
              }
              .disabled {
                background: #3a3a3a;
                color: #888;
                opacity: 0.55;
                pointer-events: none;
                filter: grayscale(60%);
              }
              * {
                -webkit-tap-highlight-color: transparent;
              }
            </style>
          </head>
          <body>
            <div class="card">
              <h1>${escapeHtml(display.display_name ?? 'Unnamed Display')}</h1>
              <div class="meta">
                DISP:${escapeHtml(display.display_id)}<br>
                Container: ${escapeHtml(display.container_id ?? 'None')}<br>
                Status: ${escapeHtml(display.display_status_id ?? 'Unknown')}
              </div>

              <a class="btn" href="https://db.sheboyganlights.org/admin/content/display/${encodeURIComponent(display.display_id)}">Open Display Record</a>
              ${testButtonHtml}
              <a class="btn secondary" href="https://my.sheboyganlights.org/fieldwiring/wiring.html?display_id=${encodeURIComponent(display.display_id)}">Field Wiring</a>
              <a class="btn secondary" href="https://my.sheboyganlights.org/procedures/?display_id=${encodeURIComponent(display.display_id)}">Procedures</a>
              <a class="btn secondary" href="/scan/DISP/${encodeURIComponent(display.display_id)}/container">Open Container</a>
                ${woCount > 0
            ? `<a class="btn secondary" href="/scan/DISP/${encodeURIComponent(display.display_id)}/work-orders">
                    Open Work Orders (${woCount})
                    </a>`
            : `<div class="btn secondary disabled">
                    Open Work Orders (0)
                    </div>`
          }
            </div>
          </body>
          </html>
        `);
      } catch (err) {
        res.status(500).send(`
          <h1>Scan Error</h1>
          <pre>${escapeHtml(err.message)}</pre>
        `);
      }
    });

    // ============================================================
    // CONTAINER HUB
    // /scan/CONT/:key
    // Landing page when a container barcode is scanned
    // ============================================================
    router.get('/CONT/:key', async (req, res) => {
      const key = req.params.key;

      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.send(`
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>Container ${key}</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              background: #0b1220;
              color: #fff;
              padding: 20px;
            }
            .card {
              max-width: 700px;
              margin: auto;
              background: #111a2b;
              border-radius: 12px;
              padding: 20px;
            }
            a.btn {
              display: block;
              background: #1f6feb;
              color: #fff;
              text-decoration: none;
              padding: 16px;
              border-radius: 8px;
              margin-top: 12px;
              text-align: center;
              font-weight: bold;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Container ${key}</h1>

            <a class="btn" href="https://db.sheboyganlights.org/admin/content/container/${key}">
              Open Container Record
            </a>

            <a class="btn" href="/scan">
              Back to Scan
            </a>
          </div>
        </body>
        </html>
      `);
    });

    // ============================================================
    // CONTROLLER INVENTORY HANDOFF
    // /scan/CTRL/:key
    // Opens the production Controller Inventory with the permanent
    // controller_id selected in both Search and the detail panel.
    // ============================================================
    router.get('/CTRL/:key', async (req, res) => {
      const key = String(req.params.key ?? '').trim();
      const controllerId = Number(key);

      if (!/^\d+$/.test(key) || !Number.isSafeInteger(controllerId) || controllerId <= 0) {
        res.status(400).send(`
          <h1>Invalid Controller</h1>
          <p>Expected CTRL:&lt;controller_id&gt;; received CTRL:${escapeHtml(key)}</p>
        `);
        return;
      }

      res.redirect(
        `https://my.sheboyganlights.org/fieldwiring/controllers?controller_id=${encodeURIComponent(controllerId)}`
      );
    });

    // ============================================================
    // DISPLAY TEST RECORD
    // /scan/DISP/:key/test
    // Opens the active display_test_session record
    // ============================================================
    router.get('/DISP/:key/test', async (req, res) => {
      const key = req.params.key;

      try {
        // Get display info (need container_id)
        const display = await database('ref.display')
          .select('display_id', 'display_name', 'container_id')
          .where('display_id', key)
          .first();

        if (!display) {
          res.status(404).send('<h1>Display Not Found</h1>');
          return;
        }

        // Get current season
        const season = await database('ref.season')
          .select('season_year')
          .where('active_flag', true)
          .first();

        const currentSeasonYear = season?.season_year ?? null;

        if (!currentSeasonYear) {
          res.status(404).send('<h1>No Current Season</h1>');
          return;
        }

        // Get container test session for this season
        const testSession = await database('ops.test_session')
          .select('test_session_id', 'container_id', 'season_year', 'container_test_status_id')
          .where('container_id', display.container_id)
          .where('season_year', currentSeasonYear)
          .first();

        if (!testSession) {
          res.status(404).send('<h1>No Container Test Session</h1>');
          return;
        }

        // Get display's test record within that session
        const displayTestSession = await database('ops.display_test_session')
          .select('display_test_session_id', 'test_session_id', 'display_id', 'test_status')
          .where('test_session_id', testSession.test_session_id)
          .where('display_id', display.display_id)
          .first();

        if (!displayTestSession) {
          res.status(404).send('<h1>Display Not In Active Test Session</h1>');
          return;
        }

        // Redirect to Directus admin editor
        res.redirect(
          `https://db.sheboyganlights.org/admin/content/display_test_session/${encodeURIComponent(
            displayTestSession.display_test_session_id
          )}`
        );

      } catch (err) {
        res.status(500).send(`
          <h1>Test Record Error</h1>
          <pre>${escapeHtml(err.message)}</pre>
        `);
      }
    });

    // ============================================================
    // DISPLAY → CONTAINER REDIRECT
    // /scan/DISP/:key/container
    // Opens the container assigned to this display
    // ============================================================
    router.get('/DISP/:key/container', async (req, res) => {
      const key = req.params.key;

      try {
        const display = await database('ref.display')
          .select('display_id', 'display_name', 'container_id')
          .where('display_id', key)
          .first();

        if (!display) {
          res.status(404).send('<h1>Display Not Found</h1>');
          return;
        }

        if (!display.container_id) {
          res.send(`
            <h1>${escapeHtml(display.display_name ?? 'Unnamed Display')}</h1>
            <p>No container assigned.</p>
          `);
          return;
        }

        res.redirect(`https://db.sheboyganlights.org/admin/content/container/${encodeURIComponent(display.container_id)}`);
      } catch (err) {
        res.status(500).send(`<pre>${escapeHtml(err.message)}</pre>`);
      }
    });

    // ============================================================
    // DISPLAY WORK ORDERS
    // /scan/DISP/:key/work-orders
    // Opens active work orders for this display
    // ============================================================
    router.get('/DISP/:key/work-orders', async (req, res) => {
      const key = req.params.key;

      try {
        const display = await database('ref.display')
          .select('display_id', 'display_name')
          .where('display_id', key)
          .first();

        if (!display) {
          res.status(404).send('<h1>Display Not Found</h1>');
          return;
        }

        // Get ACTIVE work orders for this display
        const workOrders = await database('ops.work_order')
          .select('work_order_id')
          .where('display_id', display.display_id)
          .andWhere('is_active', true)
          .orderBy('work_order_id', 'desc');

        // None exist
        if (!workOrders || workOrders.length === 0) {
          res.send(`<h1>No Open Work Orders for DISP:${escapeHtml(display.display_id)}</h1>`);
          return;
        }

        // Exactly ONE → open directly
        if (workOrders.length === 1) {
          res.redirect(`https://db.sheboyganlights.org/admin/content/work_order/${encodeURIComponent(workOrders[0].work_order_id)}`);
          return;
        }

        // Multiple → show selection page
        const linksHtml = workOrders.map(wo => `
          <a href="https://db.sheboyganlights.org/admin/content/work_order/${encodeURIComponent(wo.work_order_id)}">
            Work Order #${escapeHtml(wo.work_order_id)}
          </a><br>
        `).join('');

        res.send(`
          <h1>Open Work Orders for DISP:${escapeHtml(display.display_id)}</h1>
          ${linksHtml}
        `);

      } catch (err) {
        res.status(500).send(`
          <h1>Work Order Error</h1>
          <pre>${escapeHtml(err.message)}</pre>
        `);
      }
    });

    // ============================================================
    // HELPER FUNCTIONS
    // ============================================================
    function escapeHtml(value) {
      return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }
  }
};
