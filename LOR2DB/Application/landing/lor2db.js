/* MSB LOR landing page — 2026-08-06 V0.1.0 */
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

  function snapshotCard(snapshot) {
    if (!snapshot) return `<section class="card"><h2>Current LOR snapshot</h2><p>No committed snapshot is available.</p></section>`;
    return `<section class="card">
      <div class="card-title"><h2>Current LOR snapshot</h2><span class="pill">Ingest ${esc(snapshot.import_run_id)}</span></div>
      <dl class="facts">
        <div><dt>Parsed</dt><dd>${esc(displayDate(snapshot.parser_completed_at))}</dd></div>
        <div><dt>Parser</dt><dd>${esc(snapshot.parser_version || "Not recorded")}</dd></div>
        <div><dt>Ingested</dt><dd>${esc(displayDate(snapshot.ingest_completed_at || snapshot.run_ts))}</dd></div>
        <div><dt>Ingest script</dt><dd>${esc(snapshot.ingest_script_version || "Not recorded")}</dd></div>
      </dl>
      <div class="counts">
        <span><strong>${esc(snapshot.preview_count ?? "—")}</strong> previews</span>
        <span><strong>${esc(snapshot.scene_count ?? "—")}</strong> scenes</span>
        <span><strong>${esc(snapshot.prop_count ?? "—")}</strong> props</span>
        <span><strong>${esc(snapshot.sub_prop_count ?? "—")}</strong> subprops</span>
        <span><strong>${esc(snapshot.dmx_channel_count ?? "—")}</strong> DMX</span>
        <span><strong>${esc(snapshot.scene_lor_prop_count ?? "—")}</strong> scene/prop</span>
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
        <div><dt>Exceptions</dt><dd>${esc(run.blocked_count)} blocked · ${esc(run.deferred_count)} deferred · ${esc(run.unresolved_count)} unresolved</dd></div>
      </dl>
      ${report}
    </section>`;
  }

  function workflowCard(workflow, snapshot) {
    let action = "";
    if (workflow.action?.kind === "review") {
      action = `<a class="primary" href="${esc(workflow.action.url)}">${esc(workflow.action.label)}</a>`;
    } else if (workflow.can_start) {
      action = `<button id="start-run" class="primary" type="button">Start reconciliation</button>`;
    }
    return `<section class="card workflow">
      <div><p class="eyebrow">Current state</p><h2>${esc(workflow.state.replaceAll("_", " "))}</h2><p>${esc(workflow.message)}</p></div>
      <div class="workflow-action">${action}</div>
      <div class="manual-note"><strong>Parser and ingest are manual for now.</strong> Run the approved V7 parser and PostgreSQL ingest first. This page will detect the newly committed snapshot; no ingest number is entered here.</div>
    </section>`;
  }

  function render() {
    app.innerHTML = `${workflowCard(model.workflow, model.snapshot)}<div class="grid">${snapshotCard(model.snapshot)}${runCard(model.latest_run)}</div>`;
    document.querySelector("#start-run")?.addEventListener("click", () => {
      dialogError.textContent = "";
      startMessage.textContent = `Snapshot ${model.snapshot.import_run_id} will be captured for a new reconciliation run.`;
      dialog.showModal();
    });
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

  request("dashboard").then((result) => {
    model = result;
    render();
  }).catch((error) => {
    app.innerHTML = `<section class="card"><h2>LOR status unavailable</h2><p class="error">${esc(error.message)}</p></section>`;
  });
}());
