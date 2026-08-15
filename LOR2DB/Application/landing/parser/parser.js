/* MSB read-only parser console - 2026-08-15 V0.5.0 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  let model;
  let activity;
  let pollTimer;

  const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char]);

  function displayDate(value) {
    if (!value) return "Not recorded";
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium", timeStyle: "medium"
    }).format(new Date(value));
  }

  async function request(path, options) {
    const response = await fetch(`../preflight/api/${path}`, {
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      ...options
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
    return payload;
  }

  function counts(result) {
    const values = result?.counts;
    if (!values) return "";
    return `<div class="counts">
      <span><strong>${esc(values.previews ?? "-")}</strong> previews</span>
      <span><strong>${esc(values.scenes ?? "-")}</strong> raw LOR Scene rows</span>
      <span><strong>${esc(values.props ?? "-")}</strong> props</span>
      <span><strong>${esc(values.subProps ?? "-")}</strong> subprops</span>
      <span><strong>${esc(values.dmxChannels ?? "-")}</strong> DMX</span>
      <span><strong>${esc(values.scene_lor_props ?? "-")}</strong> scene/prop</span>
    </div>`;
  }

  function render() {
    const runner = model?.parser_runner;
    if (!runner) {
      app.innerHTML = `<section class="card"><h2>Runner unavailable</h2><p class="error">${esc(model?.parser_runner_error || "The Windows/G-drive runner is offline.")}</p></section>`;
      return;
    }
    const latest = activity?.activity;
    const running = latest?.status === "RUNNING";
    const run = latest?.result || runner.production_parser_run;
    const status = latest?.status || "NOT RUN FROM THIS PAGE";
    const consoleText = latest?.console_output || (running
      ? "Parser process is running. Complete console output will appear when the process finishes."
      : "No parser console output has been recorded yet.");
    const error = latest?.error ? `<p class="error">${esc(latest.error)}</p>` : "";
    const targetNote = latest && latest.target !== "current"
      ? `<p class="warning">The latest recorded parser activity belongs to the ${esc(latest.target)} version-check workflow, not a production parser run.</p>`
      : "";
    app.innerHTML = `<section class="card">
      <div class="card-title"><h2>Production SQLite parser</h2><span class="pill">Runner ${esc(runner.runner_version)}</span></div>
      <p>This reads the approved preview folder and atomically rebuilds the production SQLite file. It does not ingest PostgreSQL or start reconciliation.</p>
      <dl class="facts">
        <div><dt>Approved LOR version</dt><dd>${esc(runner.current_lor_version)}</dd></div>
        <div><dt>Parser status</dt><dd>${esc(status)}</dd></div>
        <div><dt>Preview source folder</dt><dd class="path-value">${esc(runner.current_preview_folder)}</dd></div>
        <div><dt>Started</dt><dd>${esc(displayDate(latest?.started_at))}</dd></div>
        <div><dt>Production SQLite</dt><dd class="path-value">${esc(run?.sqlite_path || "Not recorded")}</dd></div>
        <div><dt>Completed</dt><dd>${esc(displayDate(latest?.completed_at || run?.completed_at))}</dd></div>
        <div><dt>SQLite SHA-256</dt><dd class="digest">${esc(run?.sqlite_sha256 || "Not recorded")}</dd></div>
        <div><dt>Validation</dt><dd>${esc(run?.validation_status || "Not recorded")}</dd></div>
      </dl>
      ${targetNote}${error}${counts(run)}
      <div class="page-actions">
        <button id="run-parser" class="primary" type="button" ${running ? "disabled" : ""}>${running ? "Parser is running..." : "Run parser"}</button>
        <button id="refresh-output" type="button">Refresh output</button>
        <a class="secondary" href="../">Return to dashboard</a>
      </div>
    </section>
    <section class="card">
      <div class="card-title"><h2>Read-only console output</h2><span class="pill state-${esc(status.toLowerCase())}">${esc(status)}</span></div>
      ${latest?.console_truncated ? '<p class="warning">The display is limited to the most recent 500,000 characters. The complete log remains on the runner host.</p>' : ""}
      <pre id="console-output" class="console">${esc(consoleText)}</pre>
    </section>`;

    document.querySelector("#refresh-output")?.addEventListener("click", refresh);
    document.querySelector("#run-parser")?.addEventListener("click", runParser);
    const consoleElement = document.querySelector("#console-output");
    if (consoleElement) consoleElement.scrollTop = consoleElement.scrollHeight;
    if (running && !pollTimer) pollTimer = window.setInterval(refreshActivity, 2000);
    if (!running && pollTimer) {
      window.clearInterval(pollTimer);
      pollTimer = undefined;
    }
  }

  async function refreshActivity() {
    try {
      activity = await request("parser/activity");
      render();
    } catch (error) {
      window.clearInterval(pollTimer);
      pollTimer = undefined;
      app.insertAdjacentHTML("afterbegin", `<p class="error">${esc(error.message)}</p>`);
    }
  }

  async function refresh() {
    [model, activity] = await Promise.all([
      request("dashboard"), request("parser/activity")
    ]);
    render();
  }

  async function runParser(event) {
    if (!window.confirm("Run the parser for the approved LOR version now? This rebuilds SQLite only; PostgreSQL remains unchanged.")) return;
    event.currentTarget.disabled = true;
    event.currentTarget.textContent = "Starting parser...";
    pollTimer = window.setInterval(refreshActivity, 2000);
    try {
      await request("parser/run", {
        method: "POST", body: JSON.stringify({ target: "current" })
      });
    } catch (error) {
      window.alert(error.message);
    } finally {
      await refresh();
    }
  }

  refresh().catch((error) => {
    app.innerHTML = `<section class="card"><h2>Parser status unavailable</h2><p class="error">${esc(error.message)}</p></section>`;
  });
}());
