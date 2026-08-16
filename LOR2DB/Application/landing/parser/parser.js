/* MSB parser and ingest workflow - 2026-08-15 V0.6.0 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  let model;
  let parserActivity;
  let ingestActivity;
  let pollTimer;
  let reviewedDigest;

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

  function validatedDigest(runner) {
    const run = runner?.production_parser_run;
    const activity = runner?.parser_activity;
    const digest = String(run?.sqlite_sha256 || "").toLowerCase();
    if (run?.validation_status !== "PASSED" || !/^[0-9a-f]{64}$/.test(digest)) return null;
    if (
      activity?.target !== "current"
      || activity?.status !== "PASSED"
      || String(activity?.result?.sqlite_sha256 || "").toLowerCase() !== digest
    ) return null;
    return digest;
  }

  function ingestWorkflow(runner, digest, workflow) {
    if (!digest) return "";
    const ingest = ingestActivity?.activity;
    const ingested = runner.production_ingest_run;
    const sameDigestComplete = ingested?.status === "COMPLETE" && ingested.sqlite_sha256 === digest;
    const running = ingest?.status === "RUNNING";
    const failed = ingest?.status === "FAILED" || ingest?.status === "INTERRUPTED";
    const reviewed = reviewedDigest === digest;
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
        <div><dt>Validated SQLite SHA-256</dt><dd class="digest">${esc(digest)}</dd></div>
        <div><dt>PostgreSQL import run</dt><dd>${esc(ingested?.import_run_id || "Not yet created")}</dd></div>
      </dl>
      ${controls}
    </section>`;
  }

  function reconciliationWorkflow(runner, digest, workflow) {
    const ingested = runner?.production_ingest_run;
    const sameDigestComplete = digest
      && ingested?.status === "COMPLETE"
      && ingested.sqlite_sha256 === digest;
    if (!sameDigestComplete) return "";
    const controls = workflow?.can_start
      ? '<button id="start-reconciliation" class="primary" type="button">Start reconciliation</button>'
      : '<button id="refresh-reconciliation" type="button">Refresh reconciliation status</button>';
    return `<section class="card next-step-card">
      <div class="card-title"><div><p class="eyebrow">3. Reconcile the new snapshot</p><h2>Start reconciliation</h2></div><span class="pill">INGEST ${esc(ingested.import_run_id)} READY</span></div>
      <p>The PostgreSQL ingest completed. After reviewing its console output, start reconciliation for this newly committed snapshot.</p>
      <div class="page-actions">${controls}<a class="secondary" href="../">Return to dashboard</a></div>
    </section>`;
  }

  function consoleCard(id, title, activity, emptyMessage) {
    const record = activity?.activity;
    const status = record?.status || "NOT RUN";
    const output = record?.console_output || (status === "RUNNING" ? "Operation is running..." : emptyMessage);
    return `<section id="${esc(id)}" class="card">
      <div class="card-title"><h2>${esc(title)}</h2><span class="pill state-${esc(status.toLowerCase())}">${esc(status)}</span></div>
      ${record?.console_truncated ? '<p class="warning">Only the most recent 500,000 characters are displayed. The complete log remains on the Office PC.</p>' : ""}
      ${record?.error ? `<p class="error">${esc(record.error)}</p>` : ""}
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
    const digest = validatedDigest(runner);
    if (reviewedDigest && reviewedDigest !== digest) reviewedDigest = undefined;
    const targetNote = latest && latest.target !== "current"
      ? `<p class="warning">The latest parser activity belongs to the ${esc(latest.target)} version-check workflow, not the production parser.</p>`
      : "";

    app.innerHTML = `<section class="card">
      <div class="card-title"><h2>1. Build and review production SQLite</h2><span class="pill">Runner ${esc(runner.runner_version)}</span></div>
      <p>Run the parser, inspect its output, and make any needed corrections. You may run this step again as many times as necessary. Each run rebuilds and replaces the SQLite output; PostgreSQL remains unchanged until you explicitly approve ingest.</p>
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
      ${targetNote}${counts(run)}
      <div class="page-actions">
        ${digest && !parserRunning && !ingestRunning
          ? '<a class="primary" href="#parser-console">Review parser output</a>'
          : `<button id="run-parser" class="primary" type="button" ${parserRunning || ingestRunning ? "disabled" : ""}>${parserRunning ? "Parser is running..." : "Run parser"}</button>`}
        <button id="refresh-output" type="button">Refresh output</button>
        <a class="secondary" href="../">Return to dashboard</a>
      </div>
    </section>
    ${consoleCard("parser-console", "Parser console output", parserActivity, "No parser console output has been recorded yet.")}
    ${ingestWorkflow(runner, digest, model.workflow)}
    ${consoleCard("ingest-console", "PostgreSQL ingest console output", ingestActivity, "No PostgreSQL ingest has been run for this parser output.")}
    ${reconciliationWorkflow(runner, digest, model.workflow)}`;

    document.querySelector("#run-parser")?.addEventListener("click", runParser);
    document.querySelector("#rerun-parser")?.addEventListener("click", runParser);
    document.querySelector("#mark-ready-ingest")?.addEventListener("click", () => {
      reviewedDigest = digest;
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

  async function refresh() {
    [model, parserActivity, ingestActivity] = await Promise.all([
      request("dashboard"), request("parser/activity"), request("ingest/activity")
    ]);
    render();
  }

  async function runParser(event) {
    if (!window.confirm("Run the parser now? You can inspect the output and run it again before ingest.")) return;
    reviewedDigest = undefined;
    event.currentTarget.disabled = true;
    event.currentTarget.textContent = "Starting parser...";
    if (!pollTimer) pollTimer = window.setInterval(refresh, 2000);
    try {
      await request("parser/run", { method: "POST", body: JSON.stringify({ target: "current" }) });
    } catch (error) {
      window.alert(error.message);
    } finally {
      await refresh();
    }
  }

  async function runIngest(event) {
    const digest = validatedDigest(model?.parser_runner);
    if (!digest || reviewedDigest !== digest) {
      window.alert("Review and approve this exact parser output before ingest.");
      return;
    }
    if (!window.confirm("Ingest this reviewed SQLite snapshot into PostgreSQL now? Reconciliation will not start automatically.")) return;
    event.currentTarget.disabled = true;
    event.currentTarget.textContent = "Starting ingest...";
    if (!pollTimer) pollTimer = window.setInterval(refresh, 2000);
    try {
      await request("ingest/run", {
        method: "POST",
        body: JSON.stringify({ expected_sqlite_sha256: digest })
      });
    } catch (error) {
      window.alert(error.message);
    } finally {
      await refresh();
    }
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
