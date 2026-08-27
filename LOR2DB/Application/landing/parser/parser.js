/* MSB parser and ingest workflow - 2026-08-27 V0.6.2 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  let model;
  let parserActivity;
  let ingestActivity;
  let pollTimer;
  let reviewedDigest;
  let reviewedParserActivityId;
  const pendingRequestIds = {};

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

  function operationRequestId(kind) {
    const key = `lor2db-${kind}-request-id`;

    if (pendingRequestIds[kind]) {
      return pendingRequestIds[kind];
    }

    try {
      const stored = sessionStorage.getItem(key);
      if (stored) {
        pendingRequestIds[kind] = stored;
        return stored;
      }
    } catch (_error) {
      // In-memory idempotency still protects repeated clicks in this page.
    }

    const suffix = globalThis.crypto?.randomUUID
      ? globalThis.crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(16).slice(2)}-${Math.random().toString(16).slice(2)}`;

    const value = `${kind}:${suffix}`;
    pendingRequestIds[kind] = value;

    try {
      sessionStorage.setItem(key, value);
    } catch (_error) {
      // In-memory fallback is sufficient for the current page lifetime.
    }

    return value;
  }

  function clearOperationRequestId(kind, acceptedRequestId) {
    if (!acceptedRequestId) return;

    if (pendingRequestIds[kind] === acceptedRequestId) {
      delete pendingRequestIds[kind];
    }

    try {
      const key = `lor2db-${kind}-request-id`;
      if (sessionStorage.getItem(key) === acceptedRequestId) {
        sessionStorage.removeItem(key);
      }
    } catch (_error) {
      // Nothing else is required if browser storage is unavailable.
    }
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

  function validatedParserEvidence(runner, consoleActivity) {
    const run = runner?.production_parser_run;
    const activity = runner?.parser_activity;
    const digest = String(run?.sqlite_sha256 || "").toLowerCase();
    const activityId = String(activity?.activity_id || "");

    if (
      run?.status !== "COMPLETE"
      || run?.validation_status !== "PASSED"
      || !/^[0-9a-f]{64}$/.test(digest)
      || !activityId
      || String(run?.parser_activity_id || "") !== activityId
    ) return null;

    if (
      activity?.target !== "current"
      || activity?.status !== "PASSED"
      || String(activity?.result?.sqlite_sha256 || "").toLowerCase() !== digest
    ) return null;

    if (
      consoleActivity?.activity_id !== activityId
      || consoleActivity?.status !== "PASSED"
      || consoleActivity?.console_available !== true
      || String(consoleActivity?.result?.sqlite_sha256 || "").toLowerCase() !== digest
    ) return null;

    return {
      digest,
      activityId
    };
  }

  function validatedIngestEvidence(
    runner,
    parserEvidence,
    consoleActivity
  ) {
    const digest = parserEvidence?.digest;
    const parserActivityId = parserEvidence?.activityId;
    const ingested = runner?.production_ingest_run;
    const stateActivity = runner?.ingest_activity;
    const ingestActivityId = String(
      ingested?.ingest_activity_id || ""
    );

    if (
      !digest
      || !parserActivityId
      || ingested?.status !== "COMPLETE"
      || String(ingested?.sqlite_sha256 || "").toLowerCase()
        !== digest
      || ingested?.parser_activity_id !== parserActivityId
      || !ingestActivityId
    ) return null;

    if (
      stateActivity?.activity_id !== ingestActivityId
      || stateActivity?.status !== "PASSED"
      || stateActivity?.parser_activity_id !== parserActivityId
      || stateActivity?.result?.ingest_activity_id
        !== ingestActivityId
      || stateActivity?.result?.parser_activity_id
        !== parserActivityId
      || stateActivity?.result?.import_run_id
        !== ingested?.import_run_id
    ) return null;

    if (
      consoleActivity?.activity_id !== ingestActivityId
      || consoleActivity?.status !== "PASSED"
      || consoleActivity?.console_available !== true
      || consoleActivity?.parser_activity_id !== parserActivityId
      || consoleActivity?.result?.ingest_activity_id
        !== ingestActivityId
      || consoleActivity?.result?.parser_activity_id
        !== parserActivityId
      || consoleActivity?.result?.import_run_id
        !== ingested?.import_run_id
    ) return null;

    return {
      ...parserEvidence,
      ingestActivityId,
      importRunId: ingested.import_run_id
    };
  }

  function ingestWorkflow(runner, evidence, workflow) {
    const digest = evidence?.digest;
    const parserActivityId = evidence?.activityId;

    if (!digest || !parserActivityId) return "";

    const ingest = ingestActivity?.activity;
    const ingested = runner.production_ingest_run;
    const completeEvidence = validatedIngestEvidence(
      runner,
      evidence,
      ingest
    );
    const sameDigestComplete = Boolean(completeEvidence);
    const running = ingest?.status === "RUNNING";
    const failed = ingest?.status === "FAILED" || ingest?.status === "INTERRUPTED";
    const reviewed =
      reviewedDigest === digest
      && reviewedParserActivityId === parserActivityId;
    let status = reviewed ? "READY FOR INGEST" : "REVIEW REQUIRED";
    let detail = reviewed
      ? "You marked this exact parser output as correct. Ingest is now available for this SQLite SHA-256 only."
      : "Review the parser console, counts, reports, and SQLite output above. If anything is wrong, make corrections and run the parser again. Continue only when this exact output looks correct.";
    let controls = reviewed
      ? `<div class="page-actions">
          <button id="run-ingest" class="primary" type="button">Ingest to PostgreSQL</button>
          <button id="rerun-parser" type="button">Make corrections and run parser again</button>
        </div>`
      : `<div class="page-actions">
          <button id="mark-ready-ingest" class="primary" type="button">Parser output looks correct — ready for ingest</button>
          <button id="rerun-parser" type="button">Make corrections and run parser again</button>
        </div>`;

    if (!runner.ingest_configured) {
      status = "SETUP REQUIRED";
      detail = "The Office PC does not yet have its protected PostgreSQL ingest credential. Configure it once before using web ingest.";
      controls = '<p class="error">Web ingest is unavailable until the protected credential is configured.</p>';
    } else if (running) {
      status = "INGEST RUNNING";
      detail = "PostgreSQL ingest is running. Its read-only console output updates below.";
      controls = '<div class="page-actions"><button class="primary" type="button" disabled>Ingest is running...</button></div>';
    } else if (sameDigestComplete) {
      status = "INGEST COMPLETE";
      detail = `PostgreSQL snapshot ${esc(ingested.import_run_id)} was created successfully. Review the ingest console below before starting reconciliation.`;
      controls = "";
    } else if (failed) {
      status = "INGEST FAILED";
      detail = "Review the ingest console error below. Reconciliation has not started. Correct the problem and retry this same validated snapshot.";
      controls = reviewed
        ? '<div class="page-actions"><button id="run-ingest" class="primary" type="button">Retry PostgreSQL ingest</button><button id="rerun-parser" type="button">Make corrections and run parser again</button></div>'
        : '<div class="page-actions"><button id="mark-ready-ingest" class="primary" type="button">Parser output still looks correct — retry ingest</button><button id="rerun-parser" type="button">Make corrections and run parser again</button></div>';
    }

    return `<section id="ingest-step" class="card next-step-card">
      <div class="card-title"><div><p class="eyebrow">2. Operator approval and ingest</p><h2>PostgreSQL snapshot ingest</h2></div><span class="pill">${esc(status)}</span></div>
      <p>${detail}</p>
      <dl class="facts">
        <div><dt>Parser activity ID</dt><dd class="digest">${esc(parserActivityId)}</dd></div>
        <div><dt>Validated SQLite SHA-256</dt><dd class="digest">${esc(digest)}</dd></div>
        <div><dt>PostgreSQL import run</dt><dd>${esc(ingested?.import_run_id || "Not yet created")}</dd></div>
      </dl>
      ${controls}
    </section>`;
  }

  function reconciliationWorkflow(runner, evidence, workflow) {
    const ingested = runner?.production_ingest_run;
    const completeEvidence = validatedIngestEvidence(
      runner,
      evidence,
      ingestActivity?.activity
    );
    if (!completeEvidence) return "";
    const controls = workflow?.can_start
      ? '<button id="start-reconciliation" class="primary" type="button">Start reconciliation</button>'
      : '<button id="refresh-reconciliation" type="button">Refresh reconciliation status</button>';
    return `<section class="card next-step-card">
      <div class="card-title"><div><p class="eyebrow">3. Reconcile the new snapshot</p><h2>Start reconciliation</h2></div><span class="pill">INGEST ${esc(ingested.import_run_id)} READY</span></div>
      <p>The PostgreSQL ingest completed. After reviewing its console output, start reconciliation for this newly committed snapshot.</p>
      <div class="page-actions">${controls}<a class="secondary" href="../">Return to dashboard</a></div>
    </section>`;
  }

  function consoleCard(
    id,
    title,
    activity,
    emptyMessage,
    expectedActivityId
  ) {
    const record = activity?.activity;

    const mismatched = Boolean(
      expectedActivityId
      && record?.activity_id
      && record.activity_id !== expectedActivityId
    );

    const evidenceUnavailable = Boolean(
      !mismatched
      && record?.status === "PASSED"
      && record?.console_available !== true
    );

    const status = mismatched
      ? "REFRESHING"
      : (record?.status || "NOT RUN");

    const output = mismatched
      ? "Current console evidence is still refreshing. Approval is blocked until the activity ID matches."
      : evidenceUnavailable
        ? "Current console evidence is unavailable. Approval and reconciliation are blocked."
        : (
          record?.console_output
          || (
            status === "RUNNING"
              ? "Operation is running..."
              : emptyMessage
          )
        );

    return `<section id="${esc(id)}" class="card">
      <div class="card-title"><h2>${esc(title)}</h2><span class="pill state-${esc(status.toLowerCase())}">${esc(status)}</span></div>
      ${record?.activity_id ? `<dl class="facts"><div><dt>Activity ID</dt><dd class="digest">${esc(record.activity_id)}</dd></div>${record?.parser_activity_id ? `<div><dt>Parser activity ID</dt><dd class="digest">${esc(record.parser_activity_id)}</dd></div>` : ""}</dl>` : ""}
      ${evidenceUnavailable ? '<p class="error">Current console evidence is unavailable. Approval and reconciliation are blocked.</p>' : ""}
      ${record?.console_truncated && !mismatched ? '<p class="warning">Only the most recent 500,000 characters are displayed. The complete log remains on the runner host.</p>' : ""}
      ${record?.error && !mismatched ? `<p class="error">${esc(record.error)}</p>` : ""}
      <pre class="console">${esc(output)}</pre>
    </section>`;
  }

  function render() {
    const runner = model?.parser_runner;
    if (!runner) {
      app.innerHTML = `<section class="card"><h2>Runner unavailable</h2><p class="error">${esc(model?.parser_runner_error || "The Windows/G-drive runner is offline.")}</p></section>`;
      return;
    }
    const latest = parserActivity?.activity;
    const parserRunning = latest?.status === "RUNNING";
    const ingestRunning = ingestActivity?.activity?.status === "RUNNING";
    const run = latest?.result || runner.production_parser_run;
    const status = latest?.status || "NOT RUN FROM THIS PAGE";

    if (latest?.request_id) {
      clearOperationRequestId("parser", latest.request_id);
    }

    if (ingestActivity?.activity?.request_id) {
      clearOperationRequestId(
        "ingest",
        ingestActivity.activity.request_id
      );
    }

    const evidence = validatedParserEvidence(runner, latest);
    const digest = evidence?.digest;
    const parserActivityId = evidence?.activityId;

    if (
      reviewedDigest
      && (
        reviewedDigest !== digest
        || reviewedParserActivityId !== parserActivityId
      )
    ) {
      reviewedDigest = undefined;
      reviewedParserActivityId = undefined;
    }
    const targetNote = latest && latest.target !== "current"
      ? `<p class="warning">The latest parser activity belongs to the ${esc(latest.target)} version-check workflow, not the production parser.</p>`
      : "";

    app.innerHTML = `<section class="card">
      <div class="card-title"><h2>1. Build and review production SQLite</h2><span class="pill">Runner ${esc(runner.runner_version)}</span></div>
      <p>Run the parser, inspect its output, and make any needed corrections. You may run this step again as many times as necessary. Each run rebuilds and replaces the SQLite output; PostgreSQL remains unchanged until you explicitly approve ingest.</p>
      <dl class="facts">
        <div><dt>Approved LOR version</dt><dd>${esc(runner.current_lor_version)}</dd></div>
        <div><dt>Parser status</dt><dd>${esc(status)}</dd></div>
        <div><dt>Parser activity ID</dt><dd class="digest">${esc(latest?.activity_id || "Not recorded")}</dd></div>
        <div><dt>Preview source folder</dt><dd class="path-value">${esc(runner.current_preview_folder)}</dd></div>
        <div><dt>Started</dt><dd>${esc(displayDate(latest?.started_at))}</dd></div>
        <div><dt>Production SQLite</dt><dd class="path-value">${esc(run?.sqlite_path || "Not recorded")}</dd></div>
        <div><dt>Completed</dt><dd>${esc(displayDate(latest?.completed_at || run?.completed_at))}</dd></div>
        <div><dt>SQLite SHA-256</dt><dd class="digest">${esc(run?.sqlite_sha256 || "Not recorded")}</dd></div>
        <div><dt>Validation</dt><dd>${esc(run?.validation_status || "Not recorded")}</dd></div>
      </dl>
      ${targetNote}${counts(run)}
      <div class="page-actions">
        <button id="run-parser" class="primary" type="button" ${parserRunning || ingestRunning ? "disabled" : ""}>${parserRunning ? "Parser is running..." : "Run parser"}</button>
        ${digest && !parserRunning && !ingestRunning
          ? '<a class="secondary" href="#parser-console">Review parser output</a>'
          : ""}
        <button id="refresh-output" type="button">Refresh output</button>
        <a class="secondary" href="../">Return to dashboard</a>
      </div>
    </section>
    ${consoleCard(
      "parser-console",
      "Parser console output",
      parserActivity,
      "No parser console output has been recorded yet.",
      runner.parser_activity?.activity_id
    )}
    ${ingestWorkflow(runner, evidence, model.workflow)}
    ${consoleCard(
      "ingest-console",
      "PostgreSQL ingest console output",
      ingestActivity,
      "No PostgreSQL ingest has been run for this parser output.",
      runner.ingest_activity?.activity_id
    )}
    ${reconciliationWorkflow(runner, evidence, model.workflow)}`;

    document.querySelector("#run-parser")?.addEventListener("click", runParser);
    document.querySelector("#rerun-parser")?.addEventListener("click", runParser);
    document.querySelector("#mark-ready-ingest")?.addEventListener("click", () => {
      reviewedDigest = digest;
      reviewedParserActivityId = parserActivityId;
      render();
      document.querySelector("#ingest-step")?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    document.querySelector("#run-ingest")?.addEventListener("click", runIngest);
    document.querySelector("#start-reconciliation")?.addEventListener("click", startReconciliation);
    document.querySelector("#refresh-output")?.addEventListener("click", refresh);
    document.querySelector("#refresh-reconciliation")?.addEventListener("click", refresh);
    document.querySelectorAll(".console").forEach((element) => {
      element.scrollTop = element.scrollHeight;
    });
    const running = parserRunning || ingestRunning;
    if (running && !pollTimer) pollTimer = window.setInterval(refresh, 2000);
    if (!running && pollTimer) {
      window.clearInterval(pollTimer);
      pollTimer = undefined;
    }
  }

  async function loadCurrentState() {
    return Promise.all([
      request("dashboard"),
      request("parser/activity"),
      request("ingest/activity")
    ]);
  }

  function requiresSettlementRefresh() {
    const runner = model?.parser_runner;
    const parser = parserActivity?.activity;
    const ingest = ingestActivity?.activity;

    const parserNeedsSettlement = Boolean(
      parser
      && parser.status !== "RUNNING"
      && (
        runner?.parser_activity?.activity_id
          !== parser.activity_id
        || runner?.parser_activity?.status
          !== parser.status
        || (
          parser.status === "PASSED"
          && runner?.production_parser_run?.parser_activity_id
            !== parser.activity_id
        )
      )
    );

    const ingestNeedsSettlement = Boolean(
      ingest
      && ingest.status !== "RUNNING"
      && (
        runner?.ingest_activity?.activity_id
          !== ingest.activity_id
        || runner?.ingest_activity?.status
          !== ingest.status
        || (
          ingest.status === "PASSED"
          && runner?.production_ingest_run?.ingest_activity_id
            !== ingest.activity_id
        )
      )
    );

    return parserNeedsSettlement || ingestNeedsSettlement;
  }

  async function refresh() {
    [model, parserActivity, ingestActivity] =
      await loadCurrentState();

    if (requiresSettlementRefresh()) {
      [model, parserActivity, ingestActivity] =
        await loadCurrentState();
    }

    render();
  }

  async function runParser(event) {
    reviewedDigest = undefined;
    reviewedParserActivityId = undefined;

    const requestId = operationRequestId("parser");

    event.currentTarget.disabled = true;
    event.currentTarget.textContent = "Starting parser...";

    if (!pollTimer) {
      pollTimer = window.setInterval(refresh, 2000);
    }

    try {
      parserActivity = await request(
        "parser/start",
        {
          method: "POST",
          body: JSON.stringify({
            target: "current",
            request_id: requestId
          })
        }
      );

      clearOperationRequestId("parser", requestId);
      render();
    } catch (error) {
      window.alert(error.message);
    }

    await refresh();
  }

  async function runIngest(event) {
    const evidence = validatedParserEvidence(
      model?.parser_runner,
      parserActivity?.activity
    );

    const digest = evidence?.digest;
    const parserActivityId = evidence?.activityId;

    if (
      !digest
      || !parserActivityId
      || reviewedDigest !== digest
      || reviewedParserActivityId !== parserActivityId
    ) {
      window.alert(
        "Review and approve this exact parser activity and SQLite output before ingest."
      );
      return;
    }

    const requestId = operationRequestId("ingest");

    event.currentTarget.disabled = true;
    event.currentTarget.textContent = "Starting ingest...";

    if (!pollTimer) {
      pollTimer = window.setInterval(refresh, 2000);
    }

    try {
      ingestActivity = await request(
        "ingest/start",
        {
          method: "POST",
          body: JSON.stringify({
            expected_sqlite_sha256: digest,
            parser_activity_id: parserActivityId,
            request_id: requestId
          })
        }
      );

      clearOperationRequestId("ingest", requestId);
      render();
    } catch (error) {
      window.alert(error.message);
    }

    await refresh();
  }

  async function startReconciliation(event) {
    if (!window.confirm("Start reconciliation for the newly ingested PostgreSQL snapshot?")) return;
    event.currentTarget.disabled = true;
    event.currentTarget.textContent = "Starting reconciliation...";
    try {
      const result = await request("runs/start", { method: "POST", body: "{}" });
      location.href = `../${result.review_url}`;
    } catch (error) {
      window.alert(error.message);
      event.currentTarget.disabled = false;
      event.currentTarget.textContent = "Start reconciliation";
    }
  }

  refresh().catch((error) => {
    app.innerHTML = `<section class="card"><h2>Parser workflow unavailable</h2><p class="error">${esc(error.message)}</p></section>`;
  });
}());
