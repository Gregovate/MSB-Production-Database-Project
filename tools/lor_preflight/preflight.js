/*
 * MSB Database - reusable LOR reconciliation preflight interface
 * Initial release: 2026-08-04 V0.1.0
 * Current version: 2026-08-05 V0.4.1
 *
 * The browser never writes PostgreSQL directly. All durable decisions and
 * lifecycle changes go through the same-origin secured API described in
 * README.md. The API remains responsible for database authorization and for
 * invoking only the approved ops functions.
 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  const dialog = document.querySelector("#dialog");
  const dialogTitle = document.querySelector("#dialog-title");
  const dialogBody = document.querySelector("#dialog-body");
  const dialogReasonWrap = document.querySelector("#dialog-reason-wrap");
  const dialogReason = document.querySelector("#dialog-reason");
  const dialogConfirm = document.querySelector("#dialog-confirm");
  const params = new URLSearchParams(location.search);
  const runId = params.get("run");
  let model;

  const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char]);

  async function request(url, options) {
    const response = await fetch(url, {
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", ...(options?.headers || {}) },
      ...options
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
    return payload;
  }

  function proposedAction(candidate) {
    if (candidate.proposed_action) return candidate.proposed_action;
    const nonFallback = candidate.allowed_actions.filter((action) =>
      !["DEFER", "CORRECT_SOURCE_REQUIRED", "RESTORE_TO_LOR_REQUIRED"].includes(action));
    return nonFallback.length === 1 ? nonFallback[0] : null;
  }

  function actionLabel(action) {
    return action.toLowerCase().split("_").map((part) => part[0].toUpperCase() + part.slice(1)).join(" ");
  }

  function decisionLabel(action, proposed, candidate) {
    const current = candidate.current_display_name || candidate.entity_key;
    const next = candidate.proposed_display_name || candidate.entity_key;
    const labels = {
      ADD_NEW_DISPLAY: `Add ${next} as a new ACTIVE display`,
      RENAME_DISPLAY: `Approve name change from ${current} to ${next}`,
      SET_RECYCLED: `Mark ${current} as RECYCLED`,
      SET_RETIRED: `Mark ${current} as RETIRED`,
      RESTORE_TO_LOR_REQUIRED: "LOR source needs correction — leave production unchanged",
      CORRECT_SOURCE_REQUIRED: "Source information is incorrect — leave production unchanged",
      DEFER: "Defer — leave production unchanged for this run"
    };
    if (labels[action]) return labels[action];
    return `${action === proposed ? "Accept" : "Choose"} — ${actionLabel(action)}`;
  }

  function displayName(candidate) {
    return candidate.current_display_name || candidate.proposed_display_name || candidate.entity_key;
  }

  function renderCandidate(candidate) {
    const proposed = proposedAction(candidate);
    const orderedActions = [
      ...(proposed ? [proposed] : []),
      ...candidate.allowed_actions.filter((action) => action !== proposed && action !== "DEFER"),
      ...candidate.allowed_actions.filter((action) => action === "DEFER")
    ];
    const facts = (candidate.facts || []).map((fact) =>
      `<span><span class="fact-label">${esc(fact.label)}:</span> ${esc(fact.value)}</span>`).join("");
    return `<section class="candidate" data-group-id="${candidate.group_id}">
      <div class="evidence">
        <label class="row-selector"><input class="row-select" type="checkbox"><span>Select for<br>group action</span></label>
        <div>
          <div class="title"><h3>${esc(displayName(candidate))}</h3><span class="badge">${esc(candidate.classification_label)}</span></div>
          <div>${esc(candidate.operator_message)}</div>
          <div class="facts">${facts}</div>
        </div>
      </div>
      <div class="decision-panel">
        <label>Decision
          <select class="decision">
            <option value="">Choose a decision…</option>
            ${orderedActions.map((action) => `<option value="${esc(action)}" ${action === candidate.effective_action_type ? "selected" : ""}>${esc(decisionLabel(action, proposed, candidate))}</option>`).join("")}
          </select>
        </label>
        <label>Operator comment (optional)<textarea class="reason" rows="2" placeholder="Add context if it will help the audit record">${esc(candidate.effective_reason || "")}</textarea></label>
        <div><button class="save" type="button">Save decision</button> <span class="save-state ${candidate.effective_action_type ? "is-saved" : ""}">${candidate.effective_action_type ? "Saved" : "Not saved"}</span></div>
      </div>
    </section>`;
  }

  function renderReview() {
    const complete = model.candidates.filter((candidate) => candidate.effective_action_type).length;
    const remaining = model.candidates.length - complete;
    const bulkActions = [...new Set(model.candidates.flatMap((candidate) => candidate.allowed_actions))]
      .filter((action) => action !== "REASSOCIATE_DISPLAY");
    app.innerHTML = `<div class="card">
      <header class="header">
        <div><h1>Preflight review</h1><div class="meta"><span>Reconciliation run ${model.run_id}</span><span>Captured ingest ${model.import_run_id}</span><span class="badge">${model.candidates.length} decisions required</span></div></div>
        <div class="status"><strong>${complete} of ${model.candidates.length} complete</strong><div class="muted">Production remains unchanged</div></div>
      </header>
      <section class="group-tools">
        <div><strong>Bulk decisions</strong><div class="muted">Use only when the same decision and reason apply to several related checks.</div></div>
        <button id="toggle-bulk" type="button" aria-expanded="false">Enable bulk decision mode</button>
        <div class="group-controls" hidden><label>Group action<select id="bulk-action"><option value="">Choose…</option>${bulkActions.map((action) => `<option value="${esc(action)}">${esc(actionLabel(action))}</option>`).join("")}</select></label><button id="apply-bulk">Apply and save</button></div>
      </section>
      <div class="column-head"><span>Preflight check and evidence</span><span>Operator decision — choose, optionally comment, then save</span></div>
      <div id="candidates">${model.candidates.map(renderCandidate).join("")}</div>
      <p id="error" class="error" role="alert"></p>
      <footer class="footer"><button id="cancel-run">Cancel reconciliation</button><div class="footer-actions"><span class="muted">${remaining ? `${remaining} decision${remaining === 1 ? "" : "s"} remain.` : "All decisions are recorded."}</span><button id="continue" class="primary" ${remaining || model.status !== "READY_TO_FINISH" ? "disabled" : ""}>Continue to final review</button></div></footer>
    </div>`;
    bindReview();
  }

  function selectedAction(section) {
    return section.querySelector(".decision").value || null;
  }

  async function saveCandidate(section, candidate) {
    const action = selectedAction(section);
    const reason = section.querySelector(".reason").value.trim();
    if (!action) throw new Error("Select a decision before saving.");
    const result = await request(`api/runs/${model.run_id}/groups/${candidate.group_id}/decisions`, {
      method: "POST", body: JSON.stringify({ action_type: action, reason, expected_action_id: candidate.effective_action_id || null })
    });
    model = result.run;
    renderReview();
  }

  function bindReview() {
    const error = document.querySelector("#error");
    const continueButton = document.querySelector("#continue");
    const markUnsaved = (section) => {
      const state = section.querySelector(".save-state");
      state.textContent = "Unsaved changes";
      state.classList.remove("is-saved");
      state.classList.add("is-unsaved");
      continueButton.disabled = true;
    };
    document.querySelectorAll(".candidate").forEach((section) => {
      const candidate = model.candidates.find((item) => item.group_id === Number(section.dataset.groupId));
      section.querySelector(".decision").addEventListener("change", () => markUnsaved(section));
      section.querySelector(".reason").addEventListener("input", () => markUnsaved(section));
      section.querySelector(".save").addEventListener("click", async () => {
        error.textContent = "";
        try { await saveCandidate(section, candidate); } catch (failure) { error.textContent = failure.message; }
      });
    });
    document.querySelector("#toggle-bulk").addEventListener("click", (event) => {
      const enabled = event.currentTarget.getAttribute("aria-expanded") === "true";
      event.currentTarget.setAttribute("aria-expanded", String(!enabled));
      event.currentTarget.textContent = enabled ? "Enable bulk decision mode" : "Disable bulk decision mode";
      document.querySelector(".group-controls").hidden = enabled;
      document.querySelector("#candidates").classList.toggle("bulk-enabled", !enabled);
    });
    document.querySelector("#apply-bulk").addEventListener("click", async () => {
      error.textContent = "";
      const groupIds = [...document.querySelectorAll(".candidate:has(.row-select:checked)")].map((section) => Number(section.dataset.groupId));
      const action = document.querySelector("#bulk-action").value;
      if (!groupIds.length || !action) { error.textContent = "Select at least one line and a group action."; return; }
      const reason = prompt("Enter the specific reason for this group action:", "");
      if (!reason?.trim()) return;
      try {
        const result = await request(`api/runs/${model.run_id}/decisions/bulk`, { method: "POST", body: JSON.stringify({ group_ids: groupIds, action_type: action, reason: reason.trim() }) });
        model = result.run; renderReview();
      } catch (failure) { error.textContent = failure.message; }
    });
    document.querySelector("#cancel-run").addEventListener("click", () => confirmCancel());
    document.querySelector("#continue").addEventListener("click", renderFinalReview);
  }

  function confirmCancel() {
    dialogTitle.textContent = "Cancel entire reconciliation?";
    dialogBody.textContent = "No production changes will be applied. The captured snapshot will be rejected and a new reconciliation run will be required.";
    dialogReasonWrap.hidden = false; dialogReason.value = "";
    dialogConfirm.textContent = "Cancel reconciliation"; dialogConfirm.className = "danger";
    dialogConfirm.onclick = async (event) => {
      event.preventDefault();
      if (!dialogReason.value.trim()) return;
      try { await request(`api/runs/${model.run_id}/cancel`, { method: "POST", body: JSON.stringify({ reason: dialogReason.value.trim() }) }); location.reload(); }
      catch (failure) { dialogBody.textContent = failure.message; }
    };
    dialog.showModal();
  }

  function renderFinalReview() {
    const applied = model.candidates.filter((candidate) => candidate.effective_action_type && candidate.effective_action_type !== "DEFER");
    app.innerHTML = `<div class="card"><h1>Final application review</h1><p>Only the following recorded actions will be applied to production. Deferred items are excluded.</p><ul class="final-list">${applied.map((candidate) => `<li><strong>${esc(displayName(candidate))}</strong><br>${esc(actionLabel(candidate.effective_action_type))}<br><span class="muted">${esc(candidate.effective_reason)}</span></li>`).join("")}</ul><p class="error">Proceed is the production-write boundary. It invokes Finish for reconciliation run ${model.run_id}.</p><div class="footer-actions"><button id="back">Back to review</button><button id="proceed" class="danger">Proceed</button></div></div>`;
    document.querySelector("#back").addEventListener("click", renderReview);
    document.querySelector("#proceed").addEventListener("click", confirmProceed);
  }

  function confirmProceed() {
    dialogTitle.textContent = "Apply these changes to production?";
    dialogBody.textContent = `This will invoke Finish for reconciliation run ${model.run_id}. This action cannot be undone from this screen.`;
    dialogReasonWrap.hidden = true;
    dialogConfirm.textContent = "Proceed with production update"; dialogConfirm.className = "danger";
    dialogConfirm.onclick = async (event) => {
      event.preventDefault();
      try {
        await request(`api/runs/${model.run_id}/finish`, {
          method: "POST",
          body: JSON.stringify({ expected_decision_version: model.decision_version })
        });
        location.href = "../reports/";
      }
      catch (failure) { dialogBody.textContent = failure.message; }
    };
    dialog.showModal();
  }

  async function load() {
    if (!runId || !/^\d+$/.test(runId)) throw new Error("Open the page with a numeric reconciliation run, for example ?run=4.");
    model = await request(`api/runs/${runId}`);
    renderReview();
  }

  load().catch((failure) => { app.innerHTML = `<div class="card"><h1>Preflight unavailable</h1><p class="error">${esc(failure.message)}</p></div>`; });
}());
