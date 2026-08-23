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

            <div class="hint">Examples: DISP:141, CONT:238, LOC:RA-01-A-03, or a full scan URL</div>

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

        function setStatus(message) {
          scanStatus.textContent = message || '';
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
            return;
          }

          if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            setStatus('Browser does not support camera access.');
            return;
          }

          if (scannerRunning) {
            setStatus('Scanner already running');
            return;
          }

          reader.style.display = 'block';
          stopBtn.style.display = 'block';

          html5QrCode = new Html5Qrcode('reader');

          try {
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
            setStatus('Camera ready');
          } catch (err) {
            console.error('Camera start failed:', err);
            setStatus('Camera start failed: ' + (err && err.message ? err.message : err));
            reader.style.display = 'none';
            stopBtn.style.display = 'none';
          }
        }

        // setStatus('Before button binding');

        scanBtn.addEventListener('click', function () {
          // alert('Scan button clicked');
          // setStatus('Scan button event fired');
          startCameraScan();
        });

        stopBtn.addEventListener('click', function () {
          // setStatus('Stop button event fired');
          stopCameraScan();
        });

        // setStatus('Button binding complete');

        input.focus();
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
              <a class="btn secondary" href="/fieldwiring/wiring.html?display_id=${encodeURIComponent(display.display_id)}">Field Wiring</a>
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