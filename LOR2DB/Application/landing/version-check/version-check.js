/* MSB guided LOR version check - 2026-08-15 V0.5.0 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  let model;
  let working = false;

  const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char]);

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

  function status(value, fallback) {
    return esc(value || fallback);
  }

  function findings(title, items) {
    if (!items?.length) return "";
    return `<div class="blocking"><strong>${esc(title)}</strong><ul>${items.map((item) => `<li><strong>${esc(item.severity)} - ${esc(item.area)}:</strong> ${esc(item.message)}</li>`).join("")}</ul></div>`;
  }

  function render() {
    const runner = model?.parser_runner;
    if (!runner) {
      app.innerHTML = `<section class="card"><h2>Version checker unavailable</h2><p class="error">${esc(model?.parser_runner_error || "The Windows/G-drive runner is offline.")}</p><a class="secondary" href="../">Return to dashboard</a></section>`;
      return;
    }
    const candidate = runner.new_lor_version;
    const check = runner.candidate_check;
    const baseline = runner.baseline_parser_run;
    const candidateRun = runner.candidate_parser_run;
    const comparison = runner.candidate_output_comparison;
    const resolution = runner.candidate_resolution;
    const baselinePassed = baseline?.status === "COMPLETE" && baseline?.validation_status === "PASSED";
    const candidatePassed = candidateRun?.status === "COMPLETE" && candidateRun?.validation_status === "PASSED";
    const checkAccepted = check?.status === "PASSED" || resolution?.status === "RESOLVED";
    const comparisonAccepted = comparison?.status === "PASSED" || resolution?.status === "RESOLVED";
    const mayResolve = candidate && check && comparison && baselinePassed && candidatePassed &&
      (check.status !== "PASSED" || comparison.status !== "PASSED");
    const mayApprove = candidate && checkAccepted && comparisonAccepted && baselinePassed && candidatePassed;
    const blockingCheck = (check?.blocking_count || 0) > 0;

    app.innerHTML = `<section class="card">
      <div class="card-title"><h2>Before you begin</h2><span class="pill">Runner ${esc(runner.runner_version)}</span></div>
      <p>Use this workflow only after installing a different LOR software version and exporting its complete preview set. Routine preview edits under LOR ${esc(runner.current_lor_version)} use the normal parser page.</p>
      <div class="notice"><strong>This workflow is isolated.</strong> It does not replace production SQLite, ingest PostgreSQL, or start reconciliation.</div>
      <dl class="facts">
        <div><dt>Current approved LOR version</dt><dd>${esc(runner.current_lor_version)}</dd></div>
        <div><dt>Current approved preview folder</dt><dd class="path-value">${esc(runner.current_preview_folder)}</dd></div>
      </dl>
      <ol class="step-list">
        <li>Enter the new LOR version. The runner resolves only <code>Database Previews V&lt;version&gt;</code>.</li>
        <li>Confirm the detected candidate folder.</li>
        <li>Run the complete XML, baseline, candidate-parser, and SQLite-output checks.</li>
        <li>Review and resolve any findings.</li>
        <li>Approve the new version explicitly. Approval returns to the dashboard and marks production SQLite for rebuild.</li>
      </ol>
    </section>

    <section class="card">
      <h2>1. Select candidate version</h2>
      <label for="candidate-version">New LOR version</label>
      <input id="candidate-version" value="${esc(candidate || "")}" placeholder="6.6.11" autocomplete="off" ${working ? "disabled" : ""}>
      <div class="page-actions">
        <button id="set-candidate" type="button" ${working ? "disabled" : ""}>Detect candidate folder</button>
      </div>
      <dl class="stacked-facts">
        <div><dt>Selected candidate version</dt><dd>${esc(candidate || "Not selected")}</dd></div>
        <div><dt>Detected candidate preview folder</dt><dd class="path-value">${esc(runner.new_preview_folder || "Not detected")}</dd></div>
      </dl>
    </section>

    <section class="card">
      <h2>2. Run version check</h2>
      <p>One button runs the required checks in order. The approved baseline and candidate databases remain isolated under the LOR Version Reviews folder.</p>
      <div class="page-actions">
        <button id="run-version-check" class="primary" type="button" ${!candidate || working ? "disabled" : ""}>${working ? "Version check is running..." : "Run version check"}</button>
      </div>
      ${blockingCheck ? '<p class="error">Blocking XML changes were found. Parser comparison was not run.</p>' : ""}
      <dl class="facts">
        <div><dt>XML compatibility</dt><dd>${status(check?.status, "Not run")}</dd></div>
        <div><dt>Approved-version baseline</dt><dd>${status(baseline?.validation_status, "Not built")}</dd></div>
        <div><dt>Candidate parser</dt><dd>${status(candidateRun?.validation_status, "Not run")}</dd></div>
        <div><dt>SQLite output comparison</dt><dd>${status(comparison?.status, "Not run")}</dd></div>
      </dl>
      ${findings("XML compatibility findings", check?.findings)}
      ${findings("SQLite output findings", comparison?.findings)}
      ${check?.parser_modifications_required?.length ? `<div class="blocking"><strong>Parser modifications required</strong><ul>${check.parser_modifications_required.map((item) => `<li>${esc(item)}</li>`).join("")}</ul></div>` : ""}
      <details>
        <summary>Show technical details</summary>
        <dl class="stacked-facts">
          <div><dt>Baseline SQLite SHA-256</dt><dd class="digest">${esc(baseline?.sqlite_sha256 || "Not available")}</dd></div>
          <div><dt>Candidate SQLite SHA-256</dt><dd class="digest">${esc(candidateRun?.sqlite_sha256 || "Not available")}</dd></div>
          <div><dt>Compatibility report</dt><dd class="path-value">${esc(check?.report_markdown || "Not available")}</dd></div>
          <div><dt>Output comparison report</dt><dd class="path-value">${esc(comparison?.report_markdown || "Not available")}</dd></div>
        </dl>
      </details>
    </section>

    <section class="card">
      <h2>3. Resolve and approve</h2>
      <p>Approval changes only the approved LOR version, preview path, and compatibility authority. It does not run the production parser.</p>
      ${mayResolve ? `<label for="resolution-notes">Engineering resolution for every finding</label><textarea id="resolution-notes" rows="5" placeholder="Explain intentional changes, parser modifications, and why the candidate is acceptable."></textarea><div class="page-actions"><button id="resolve-findings" type="button">Record findings resolved</button></div>` : ""}
      <dl class="stacked-facts">
        <div><dt>Finding resolution</dt><dd>${status(resolution?.status, check && comparison && check.status === "PASSED" && comparison.status === "PASSED" ? "Not required" : "Not recorded")}</dd></div>
        <div><dt>Approval readiness</dt><dd>${mayApprove ? "Ready for explicit approval" : "Required checks or resolutions are incomplete"}</dd></div>
      </dl>
      <div class="page-actions">
        <button id="approve-version" class="primary" type="button" ${!mayApprove || working ? "disabled" : ""}>Approve new version</button>
        <a class="secondary" href="../">Return without approval</a>
      </div>
    </section>`;

    document.querySelector("#set-candidate")?.addEventListener("click", selectCandidate);
    document.querySelector("#run-version-check")?.addEventListener("click", runVersionCheck);
    document.querySelector("#resolve-findings")?.addEventListener("click", resolveFindings);
    document.querySelector("#approve-version")?.addEventListener("click", approveVersion);
  }

  async function refresh() {
    model = await request("dashboard");
    render();
  }

  async function withWorking(action) {
    working = true;
    render();
    try {
      await action();
    } catch (error) {
      window.alert(error.message);
    } finally {
      working = false;
      await refresh();
    }
  }

  function selectCandidate() {
    const input = document.querySelector("#candidate-version");
    const version = input?.value.trim();
    if (!version) {
      window.alert("Enter the new LOR version first.");
      return;
    }
    withWorking(() => request("parser/candidate", {
      method: "POST", body: JSON.stringify({ new_lor_version: version })
    }));
  }

  function runVersionCheck() {
    withWorking(async () => {
      const check = await request("parser/check", { method: "POST", body: "{}" });
      if (check.status === "BLOCKED" || (check.blocking_count || 0) > 0) return;
      await request("parser/run", {
        method: "POST", body: JSON.stringify({ target: "baseline" })
      });
      await request("parser/run", {
        method: "POST", body: JSON.stringify({ target: "candidate" })
      });
    });
  }

  function resolveFindings() {
    const notes = document.querySelector("#resolution-notes")?.value.trim();
    if (!notes) {
      window.alert("Enter an engineering resolution for every finding.");
      return;
    }
    withWorking(() => request("parser/resolve", {
      method: "POST", body: JSON.stringify({ notes })
    }));
  }

  async function approveVersion() {
    const version = model.parser_runner?.new_lor_version;
    const confirmation = window.prompt(`Type ${version} to approve this LOR version:`);
    if (confirmation !== version) {
      if (confirmation !== null) window.alert("The entered version did not match. Nothing was approved.");
      return;
    }
    working = true;
    render();
    try {
      await request("parser/approve", {
        method: "POST", body: JSON.stringify({ confirm_lor_version: confirmation })
      });
      location.href = "../";
    } catch (error) {
      working = false;
      window.alert(error.message);
      await refresh();
    }
  }

  refresh().catch((error) => {
    app.innerHTML = `<section class="card"><h2>Version-check status unavailable</h2><p class="error">${esc(error.message)}</p></section>`;
  });
}());
