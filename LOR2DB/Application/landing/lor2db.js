/* MSB LOR landing page - 2026-08-15 V0.5.0 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  const dialog = document.querySelector("#start-dialog");
  const startMessage = document.querySelector("#start-message");
  const dialogError = document.querySelector("#dialog-error");
  const confirmStart = document.querySelector("#confirm-start");
  let model;

  const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char]);

  function displayDate(value) {
    if (!value) return "Not recorded";
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium", timeStyle: "short"
    }).format(new Date(value));
  }

  async function request(path, options) {
    const response = await fetch(`preflight/api/${path}`, {
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      ...options
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
    return payload;
  }

  function parserWorkflowCard(runner, runnerError) {
    if (!runner) {
      return `<section class="card task-card">
        <div class="card-title"><h2>Run LOR parser</h2><span class="pill state-error">Runner offline</span></div>
        <p>The Windows/G-drive runner is unavailable. No parser can be started from this page.</p>
        ${runnerError ? `<p class="error">${esc(runnerError)}</p>` : ""}
      </section>`;
    }
    const run = runner.production_parser_run;
    const parserStatus = run?.validation_status || "Rebuild required";
    return `<section class="card task-card">
      <div class="card-title"><h2>Run LOR parser</h2><span class="pill">Runner ${esc(runner.runner_version)}</span></div>
      <p>Build the production SQLite database from the currently approved preview folder. You may run this repeatedly before the separate PostgreSQL ingest.</p>
      <dl class="stacked-facts">
        <div><dt>Approved LOR version</dt><dd>${esc(runner.current_lor_version)}</dd></div>
        <div><dt>Preview source folder</dt><dd class="path-value">${esc(runner.current_preview_folder)}</dd></div>
        <div><dt>Last production parser result</dt><dd>${esc(parserStatus)}</dd></div>
        <div><dt>Last completed</dt><dd>${esc(displayDate(run?.completed_at))}</dd></div>
        <div><dt>Production SQLite</dt><dd class="path-value">${esc(run?.sqlite_path || "Not built in the current approved-version state")}</dd></div>
        <div><dt>SQLite SHA-256</dt><dd class="digest">${esc(run?.sqlite_sha256 || "Not available until a validated parser run completes")}</dd></div>
      </dl>
      <a class="primary" href="parser/">Run parser or view output</a>
    </section>`;
  }

  function versionWorkflowCard(runner, runnerError) {
    if (!runner) {
      return `<section class="card task-card">
        <div class="card-title"><h2>LOR version approval</h2><span class="pill state-error">Unavailable</span></div>
        <p>The version checker is unavailable until the Windows runner reconnects.</p>
        ${runnerError ? `<p class="error">${esc(runnerError)}</p>` : ""}
      </section>`;
    }
    return `<section class="card task-card">
      <div class="card-title"><h2>LOR version approval</h2><span class="pill">Infrequent workflow</span></div>
      <p>Use this only when evaluating a different LOR software version. Routine preview edits use the parser workflow.</p>
      <dl class="stacked-facts">
        <div><dt>Current approved LOR version</dt><dd>${esc(runner.current_lor_version)}</dd></div>
        <div><dt>Approved preview folder</dt><dd class="path-value">${esc(runner.current_preview_folder)}</dd></div>
        <div><dt>Last approval</dt><dd>${esc(displayDate(runner.last_approval?.approved_at))}</dd></div>
      </dl>
      <a class="secondary" href="version-check/">Check new version</a>
    </section>`;
  }

  function snapshotCard(snapshot) {
    if (!snapshot) return `<section class="card"><h2>Current reconciled PostgreSQL snapshot</h2><p>No production snapshot is available.</p></section>`;
    return `<section class="card">
      <div class="card-title"><h2>Current reconciled PostgreSQL snapshot</h2><span class="pill">Ingest ${esc(snapshot.import_run_id)}</span></div>
      <dl class="facts">
        <div><dt>Parsed</dt><dd>${esc(displayDate(snapshot.parser_completed_at))}</dd></div>
        <div><dt>Parser</dt><dd>${esc(snapshot.parser_version || "Not recorded")}</dd></div>
        <div><dt>LOR version</dt><dd>${esc(snapshot.source_lor_version || "Legacy snapshot - not recorded")}</dd></div>
        <div><dt>Parser validation</dt><dd>${esc(snapshot.parser_validation_status || "Legacy snapshot - not recorded")}</dd></div>
        <div><dt>Ingested</dt><dd>${esc(displayDate(snapshot.ingest_completed_at || snapshot.run_ts))}</dd></div>
        <div><dt>Ingest script</dt><dd>${esc(snapshot.ingest_script_version || "Not recorded")}</dd></div>
        <div><dt>Reviewed SQLite SHA-256</dt><dd class="digest">${esc(snapshot.source_sqlite_sha256 || "Legacy snapshot - not recorded")}</dd></div>
        <div><dt>XML compatibility manifest</dt><dd class="digest">${esc(snapshot.compatibility_manifest_sha256 || "Legacy snapshot - not recorded")}</dd></div>
      </dl>
      <div class="counts">
        <span><strong>${esc(snapshot.preview_count ?? "-")}</strong> previews</span>
        <span><strong>${esc(snapshot.scene_count ?? "-")}</strong> raw LOR Scene rows</span>
        <span><strong>${esc(snapshot.prop_count ?? "-")}</strong> props</span>
        <span><strong>${esc(snapshot.sub_prop_count ?? "-")}</strong> subprops</span>
        <span><strong>${esc(snapshot.dmx_channel_count ?? "-")}</strong> DMX</span>
        <span><strong>${esc(snapshot.scene_lor_prop_count ?? "-")}</strong> scene/prop</span>
      </div>
    </section>`;
  }

  function runCard(run) {
    if (!run) return `<section class="card"><h2>Reconciliation</h2><p>No reconciliation run has been created.</p></section>`;
    const report = run.report_url
      ? `<a class="primary" href="${esc(run.report_url)}">Open Run ${esc(run.lor_reconciliation_run_id)} report</a>`
      : "";
    return `<section class="card">
      <div class="card-title"><h2>Reconciliation</h2><span class="pill state-${esc(run.status.toLowerCase())}">${esc(run.status.replaceAll("_", " "))}</span></div>
      <dl class="facts">
        <div><dt>Run</dt><dd>${esc(run.lor_reconciliation_run_id)}</dd></div>
        <div><dt>Captured ingest</dt><dd>${esc(run.import_run_id)}</dd></div>
        <div><dt>Started</dt><dd>${esc(displayDate(run.started_at))}</dd></div>
        <div><dt>Completed</dt><dd>${esc(displayDate(run.completed_at))}</dd></div>
        <div><dt>Validation</dt><dd>${esc(run.validation_state)}</dd></div>
        <div><dt>Exceptions</dt><dd>${esc(run.blocked_count)} blocked / ${esc(run.deferred_count)} deferred / ${esc(run.unresolved_count)} unresolved</dd></div>
      </dl>
      ${report}
    </section>`;
  }

  function workflowCard(workflow) {
    const headings = {
      SNAPSHOT_CONSUMED: "NO NEW SNAPSHOT TO RECONCILE",
      READY_TO_START: "NEW SNAPSHOT READY FOR REVIEW",
      IN_PROGRESS: "RECONCILIATION IN PROGRESS",
      NO_SNAPSHOT: "NO PRODUCTION SNAPSHOT"
    };
    let action = "";
    if (workflow.action?.kind === "review") {
      action = `<a class="primary" href="${esc(workflow.action.url)}">${esc(workflow.action.label)}</a>`;
    } else if (workflow.can_start) {
      action = `<button id="start-run" class="primary" type="button">Start reconciliation</button>`;
    }
    return `<section class="card workflow">
      <div><p class="eyebrow">PostgreSQL reconciliation status</p><h2>${esc(headings[workflow.state] || workflow.state.replaceAll("_", " "))}</h2><p>${esc(workflow.message)}</p></div>
      <div class="workflow-action">${action}</div>
      <div class="manual-note"><strong>PostgreSQL ingest remains separate.</strong> Run and inspect the approved parser output first, then perform the digest-locked ingest. This page never starts an ingest.</div>
    </section>`;
  }

  function render() {
    app.innerHTML = `<div class="task-grid">${parserWorkflowCard(model.parser_runner, model.parser_runner_error)}${versionWorkflowCard(model.parser_runner, model.parser_runner_error)}</div>${workflowCard(model.workflow)}<div class="grid">${snapshotCard(model.snapshot)}${runCard(model.latest_run)}</div>`;
    document.querySelector("#start-run")?.addEventListener("click", () => {
      dialogError.textContent = "";
      startMessage.textContent = `Snapshot ${model.snapshot.import_run_id} will be captured for a new reconciliation run.`;
      dialog.showModal();
    });
  }

  async function refresh() {
    model = await request("dashboard");
    render();
  }

  confirmStart.addEventListener("click", async (event) => {
    event.preventDefault();
    confirmStart.disabled = true;
    dialogError.textContent = "";
    try {
      const result = await request("runs/start", { method: "POST", body: "{}" });
      location.href = result.review_url;
    } catch (error) {
      dialogError.textContent = error.message;
      confirmStart.disabled = false;
    }
  });

  refresh().catch((error) => {
    app.innerHTML = `<section class="card"><h2>LOR status unavailable</h2><p class="error">${esc(error.message)}</p></section>`;
  });
}());
