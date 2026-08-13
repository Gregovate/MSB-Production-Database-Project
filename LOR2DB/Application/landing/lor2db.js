/* MSB LOR landing page — 2026-08-13 V0.3.0 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  const dialog = document.querySelector("#start-dialog");
  const startMessage = document.querySelector("#start-message");
  const dialogError = document.querySelector("#dialog-error");
  const confirmStart = document.querySelector("#confirm-start");
  const versionDialog = document.querySelector("#version-dialog");
  const versionInput = document.querySelector("#new-lor-version");
  const versionError = document.querySelector("#version-error");
  const confirmVersion = document.querySelector("#confirm-version");
  const approveDialog = document.querySelector("#approve-dialog");
  const approveInput = document.querySelector("#approve-lor-version");
  const approveError = document.querySelector("#approve-error");
  const confirmApproval = document.querySelector("#confirm-approval");
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
        <div><dt>LOR version</dt><dd>${esc(snapshot.source_lor_version || "Legacy snapshot — not recorded")}</dd></div>
        <div><dt>Parser validation</dt><dd>${esc(snapshot.parser_validation_status || "Legacy snapshot — not recorded")}</dd></div>
        <div><dt>Ingested</dt><dd>${esc(displayDate(snapshot.ingest_completed_at || snapshot.run_ts))}</dd></div>
        <div><dt>Ingest script</dt><dd>${esc(snapshot.ingest_script_version || "Not recorded")}</dd></div>
        <div><dt>Reviewed SQLite SHA-256</dt><dd class="digest">${esc(snapshot.source_sqlite_sha256 || "Legacy snapshot — not recorded")}</dd></div>
        <div><dt>XML compatibility manifest</dt><dd class="digest">${esc(snapshot.compatibility_manifest_sha256 || "Legacy snapshot — not recorded")}</dd></div>
      </dl>
      <div class="counts">
        <span><strong>${esc(snapshot.preview_count ?? "—")}</strong> previews</span>
        <span><strong>${esc(snapshot.scene_count ?? "—")}</strong> raw LOR Scene rows</span>
        <span><strong>${esc(snapshot.prop_count ?? "—")}</strong> props</span>
        <span><strong>${esc(snapshot.sub_prop_count ?? "—")}</strong> subprops</span>
        <span><strong>${esc(snapshot.dmx_channel_count ?? "—")}</strong> DMX</span>
        <span><strong>${esc(snapshot.scene_lor_prop_count ?? "—")}</strong> scene/prop</span>
      </div>
    </section>`;
  }

  function parserCard(runner, runnerError) {
    if (!runner) {
      return `<section class="card parser-card">
        <div class="card-title"><h2>LOR version and parser</h2><span class="pill">Runner offline</span></div>
        <p>The Windows/G-drive runner is not available. Parser and version approval controls are disabled.</p>
        ${runnerError ? `<p class="error">${esc(runnerError)}</p>` : ""}
      </section>`;
    }
    const check = runner.candidate_check;
    const baselineRun = runner.baseline_parser_run;
    const candidateRun = runner.candidate_parser_run;
    const comparison = runner.candidate_output_comparison;
    const resolution = runner.candidate_resolution;
    const productionRun = runner.production_parser_run;
    const candidate = runner.new_lor_version;
    const checkStatus = check?.status || "Not run";
    const xmlFindings = check?.findings || [];
    const modifications = check?.parser_modifications_required || [];
    const findingsAccepted = checkStatus === "PASSED" || resolution?.status === "RESOLVED";
    const comparisonStatus = comparison?.status || "Not run";
    const comparisonAccepted = comparisonStatus === "PASSED" || resolution?.status === "RESOLVED";
    const baselinePassed = baselineRun?.status === "COMPLETE" && baselineRun?.validation_status === "PASSED";
    const candidatePassed = candidateRun?.status === "COMPLETE" && candidateRun?.validation_status === "PASSED";
    const mayResolve = candidate && check && comparison &&
      (checkStatus !== "PASSED" || comparisonStatus !== "PASSED") && baselinePassed && candidatePassed;
    const mayApprove = candidate && findingsAccepted && comparisonAccepted && baselinePassed &&
      candidateRun?.status === "COMPLETE" && candidateRun?.validation_status === "PASSED";
    return `<section class="card parser-card">
      <div class="card-title"><h2>LOR version and parser</h2><span class="pill">Runner ${esc(runner.runner_version)}</span></div>
      <dl class="facts">
        <div><dt>Current LOR version</dt><dd>${esc(runner.current_lor_version)}</dd></div>
        <div><dt>New LOR version</dt><dd>${esc(candidate || "Not selected")}</dd></div>
        <div><dt>Compatibility check</dt><dd>${esc(checkStatus)}</dd></div>
        <div><dt>Approved-version baseline</dt><dd>${esc(baselineRun?.validation_status || "Not built")}</dd></div>
        <div><dt>Candidate parser</dt><dd>${esc(candidateRun?.validation_status || "Not run")}</dd></div>
        <div><dt>SQLite output comparison</dt><dd>${esc(comparisonStatus)}</dd></div>
        <div><dt>Finding resolution</dt><dd>${esc(resolution?.status || "Not required/recorded")}</dd></div>
        <div><dt>Current parser</dt><dd>${esc(productionRun?.validation_status || "Not run")}</dd></div>
        <div><dt>Current SQLite SHA-256</dt><dd class="digest">${esc(productionRun?.sqlite_sha256 || "Not built in this runner state")}</dd></div>
      </dl>
      ${xmlFindings.length ? `<div class="blocking"><strong>XML compatibility findings</strong><ul>${xmlFindings.map((item) => `<li><strong>${esc(item.severity)} — ${esc(item.area)}:</strong> ${esc(item.message)}</li>`).join("")}</ul></div>` : ""}
      ${comparison?.findings?.length ? `<div class="blocking"><strong>SQLite output findings</strong><ul>${comparison.findings.map((item) => `<li><strong>${esc(item.severity)} — ${esc(item.area)}:</strong> ${esc(item.message)}</li>`).join("")}</ul></div>` : ""}
      ${modifications.length ? `<div class="blocking"><strong>Parser modifications required</strong><ul>${modifications.map((item) => `<li>${esc(item)}</li>`).join("")}</ul></div>` : ""}
      <div class="operator-actions">
        <button id="set-candidate" type="button">Set new LOR version</button>
        <button id="check-candidate" type="button" ${candidate ? "" : "disabled"}>Check XML compatibility</button>
        <button id="run-baseline-parser" type="button">Build approved-version baseline</button>
        <button id="run-candidate-parser" type="button" ${check && baselinePassed ? "" : "disabled"}>Run and compare candidate parser</button>
        <button id="resolve-candidate" type="button" ${mayResolve ? "" : "disabled"}>Record findings resolved</button>
        <button id="approve-candidate" class="primary" type="button" ${mayApprove ? "" : "disabled"}>Approve new version</button>
        <button id="run-current-parser" class="primary" type="button">Run current parser</button>
      </div>
      <p class="manual-note"><strong>Ingest remains separate.</strong> Review the generated SQLite and record its SHA-256 before running the manual PostgreSQL ingest.</p>
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
      <div class="manual-note"><strong>PostgreSQL ingest remains separate.</strong> Run and inspect the approved V7 parser output first, then perform the digest-locked ingest. This page detects the newly committed snapshot; no ingest number is entered here.</div>
    </section>`;
  }

  function render() {
    app.innerHTML = `${parserCard(model.parser_runner, model.parser_runner_error)}${workflowCard(model.workflow, model.snapshot)}<div class="grid">${snapshotCard(model.snapshot)}${runCard(model.latest_run)}</div>`;
    document.querySelector("#start-run")?.addEventListener("click", () => {
      dialogError.textContent = "";
      startMessage.textContent = `Snapshot ${model.snapshot.import_run_id} will be captured for a new reconciliation run.`;
      dialog.showModal();
    });
    document.querySelector("#set-candidate")?.addEventListener("click", () => {
      versionError.textContent = "";
      versionInput.value = model.parser_runner?.new_lor_version || "";
      versionDialog.showModal();
      versionInput.focus();
    });
    document.querySelector("#check-candidate")?.addEventListener("click", (event) => runParserAction(event.currentTarget, "parser/check", {}));
    document.querySelector("#run-baseline-parser")?.addEventListener("click", (event) => runParserAction(event.currentTarget, "parser/run", { target: "baseline" }));
    document.querySelector("#run-candidate-parser")?.addEventListener("click", (event) => runParserAction(event.currentTarget, "parser/run", { target: "candidate" }));
    document.querySelector("#run-current-parser")?.addEventListener("click", (event) => runParserAction(event.currentTarget, "parser/run", { target: "current" }));
    document.querySelector("#resolve-candidate")?.addEventListener("click", async (event) => {
      const notes = window.prompt("Explain every XML and SQLite output finding, including intentional metadata changes and any parser modifications:");
      if (notes?.trim()) await runParserAction(event.currentTarget, "parser/resolve", { notes: notes.trim() });
    });
    document.querySelector("#approve-candidate")?.addEventListener("click", () => {
      approveError.textContent = "";
      approveInput.value = "";
      approveDialog.showModal();
      approveInput.focus();
    });
  }

  async function refresh() {
    model = await request("dashboard");
    render();
  }

  async function runParserAction(button, path, payload) {
    const original = button.textContent;
    button.disabled = true;
    button.textContent = "Working…";
    try {
      await request(path, { method: "POST", body: JSON.stringify(payload) });
      await refresh();
    } catch (error) {
      button.disabled = false;
      button.textContent = original;
      window.alert(error.message);
    }
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

  confirmVersion.addEventListener("click", async (event) => {
    event.preventDefault();
    confirmVersion.disabled = true;
    versionError.textContent = "";
    try {
      await request("parser/candidate", {
        method: "POST", body: JSON.stringify({ new_lor_version: versionInput.value.trim() })
      });
      versionDialog.close();
      await refresh();
    } catch (error) {
      versionError.textContent = error.message;
    } finally {
      confirmVersion.disabled = false;
    }
  });

  confirmApproval.addEventListener("click", async (event) => {
    event.preventDefault();
    confirmApproval.disabled = true;
    approveError.textContent = "";
    try {
      await request("parser/approve", {
        method: "POST", body: JSON.stringify({ confirm_lor_version: approveInput.value.trim() })
      });
      approveDialog.close();
      await refresh();
    } catch (error) {
      approveError.textContent = error.message;
    } finally {
      confirmApproval.disabled = false;
    }
  });

  refresh().catch((error) => {
    app.innerHTML = `<section class="card"><h2>LOR status unavailable</h2><p class="error">${esc(error.message)}</p></section>`;
  });
}());
