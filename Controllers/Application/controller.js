const state = {
  candidates: [],
  selectedId: null,
  models: [],
};

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
  return data;
}

function esc(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function candidateEvidence(c) {
  const parts = [c.network_evidence, c.uid_evidence, c.model_evidence, c.year_deployed]
    .filter(v => v !== null && v !== undefined && String(v).trim() !== "");
  return parts.join(" · ");
}

async function loadHealth() {
  try {
    const h = await api("/api/health");
    document.getElementById("health").textContent =
      `API ${h.version} · stage=${h.stage_bootstrap ? "ready" : "missing"} · ref.controller=${h.ref_controller ? "present" : "missing"}`;
  } catch (err) {
    document.getElementById("health").textContent = err.message;
  }
}

async function loadModels() {
  const data = await api("/api/models");
  state.models = data.models;
}

async function loadCandidates() {
  const q = document.getElementById("search").value.trim();
  const filter = document.getElementById("stateFilter").value;
  const params = new URLSearchParams();
  if (q) params.set("q", q);
  if (filter) params.set("state", filter);
  const data = await api(`/api/bootstrap?${params}`);
  state.candidates = data.candidates;
  renderSummary(data.summary);
  renderCandidates();
}

function renderSummary(summary) {
  const el = document.getElementById("summary");
  el.innerHTML = [
    ["Total", summary.total],
    ["Review", summary.review_required],
    ["Ready", summary.ready],
    ["Skipped", summary.skipped],
    ["Ordered", summary.ordered],
  ].map(([label, value]) => `<span class="metric"><strong>${esc(value)}</strong> ${label}</span>`).join("");
}

function renderCandidates() {
  const list = document.getElementById("candidateList");
  document.getElementById("candidateCount").textContent = `${state.candidates.length} shown`;
  list.innerHTML = state.candidates.map(c => `
    <div class="candidate ${c.controller_bootstrap_id === state.selectedId ? "selected" : ""}"
         data-id="${c.controller_bootstrap_id}">
      <div class="section-title">
        <span class="title">${esc(c.display_name_evidence)}</span>
        <span class="pill">${esc(c.review_state)}</span>
      </div>
      <div class="evidence">Row ${esc(c.source_row_num)} · ${esc(candidateEvidence(c))}</div>
      ${c.for_what_evidence ? `<div class="evidence">${esc(c.for_what_evidence)}</div>` : ""}
      ${(c.blockers || []).length ? `<div class="evidence">Blockers: ${esc(c.blockers.join(", "))}</div>` : ""}
    </div>
  `).join("");

  list.querySelectorAll(".candidate").forEach(row => {
    row.addEventListener("click", () => selectCandidate(Number(row.dataset.id)));
  });
}

async function selectCandidate(id) {
  state.selectedId = id;
  renderCandidates();
  const data = await api(`/api/bootstrap/${id}`);
  renderDetail(data.candidate, data.relationships);
}

function renderDetail(c, relationships) {
  document.getElementById("emptyDetail").hidden = true;
  document.getElementById("detail").hidden = false;
  document.getElementById("detailTitle").textContent = c.display_name_evidence;
  document.getElementById("detailEvidence").textContent =
    `Workbook row ${c.source_row_num} · ${candidateEvidence(c)} · V7 ${c.v7_match_state || "unknown"}`;
  document.getElementById("detailState").textContent = c.review_state;

  const blockers = c.blockers || [];
  document.getElementById("blockers").innerHTML = blockers.length
    ? blockers.map(x => `<span class="blocker">${esc(x)}</span>`).join("")
    : `<span class="muted">No blocking fields.</span>`;

  const modelSelect = document.getElementById("modelSelect");
  modelSelect.innerHTML = `<option value="">-- unresolved --</option>` + state.models.map(m =>
    `<option value="${m.controller_model_id}" ${m.controller_model_id === c.controller_model_id ? "selected" : ""}>${esc(m.model_code)}</option>`
  ).join("");

  document.getElementById("yearDeployed").value = c.year_deployed ?? "";
  document.getElementById("reviewState").value = c.review_state;
  document.getElementById("reviewNotes").value = c.review_notes ?? "";

  renderRelationships(relationships);
  document.getElementById("displayResults").innerHTML = "";
  document.getElementById("displaySearch").value = "";
}

function renderRelationships(rows) {
  const el = document.getElementById("relationships");
  if (!rows.length) {
    el.innerHTML = `<div class="muted">No permanent Display relationship resolved yet.</div>`;
    return;
  }
  el.innerHTML = rows.map(r => `
    <div class="relationship">
      <span class="pill">${esc(r.relationship_type)}</span>
      <span>${esc(r.display_id)} · ${esc(r.display_name)}${r.year_built ? ` · ${esc(r.year_built)}` : ""}</span>
      <button class="danger remove-display" data-display-id="${r.display_id}" data-type="${esc(r.relationship_type)}">Remove</button>
    </div>
  `).join("");
  el.querySelectorAll(".remove-display").forEach(button => {
    button.addEventListener("click", async () => {
      if (!state.selectedId) return;
      await api(`/api/bootstrap/${state.selectedId}/displays/${button.dataset.displayId}?type=${encodeURIComponent(button.dataset.type)}`, { method: "DELETE" });
      await selectCandidate(state.selectedId);
      await loadCandidates();
    });
  });
}

async function saveCandidate() {
  if (!state.selectedId) return;
  const payload = {
    controller_model_id: document.getElementById("modelSelect").value || null,
    year_deployed: document.getElementById("yearDeployed").value || null,
    review_state: document.getElementById("reviewState").value,
    review_notes: document.getElementById("reviewNotes").value || null,
  };
  await api(`/api/bootstrap/${state.selectedId}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
  await selectCandidate(state.selectedId);
  await loadCandidates();
}

async function searchDisplays() {
  const q = document.getElementById("displaySearch").value.trim();
  if (q.length < 2) return;
  const data = await api(`/api/displays?q=${encodeURIComponent(q)}`);
  const el = document.getElementById("displayResults");
  el.innerHTML = data.displays.map(d => `
    <div class="display-result">
      <span>${esc(d.display_id)} · ${esc(d.display_name)}${d.year_built ? ` · ${esc(d.year_built)}` : ""}</span>
      <span>
        <button class="add-serves" data-id="${d.display_id}">Serves</button>
        <button class="add-source" data-id="${d.display_id}">Wiring source</button>
      </span>
    </div>
  `).join("");

  el.querySelectorAll(".add-serves").forEach(button => {
    button.addEventListener("click", () => addDisplay(Number(button.dataset.id), "SERVES"));
  });
  el.querySelectorAll(".add-source").forEach(button => {
    button.addEventListener("click", () => addDisplay(Number(button.dataset.id), "WIRING_SOURCE"));
  });
}

async function addDisplay(displayId, relationshipType) {
  if (!state.selectedId) return;
  await api(`/api/bootstrap/${state.selectedId}/displays`, {
    method: "POST",
    body: JSON.stringify({ display_id: displayId, relationship_type: relationshipType }),
  });
  await selectCandidate(state.selectedId);
  await loadCandidates();
}

async function prepareOrder() {
  const data = await api("/api/bootstrap/prepare-order", { method: "POST", body: "{}" });
  alert(`Prepared ${data.ordered} staged controllers: proposed ${data.first_proposed_id}-${data.last_proposed_id}. No permanent IDs were allocated.`);
  await loadCandidates();
  await loadOrder();
}

async function loadOrder() {
  const data = await api("/api/bootstrap/order");
  document.getElementById("orderBody").innerHTML = data.order.map(r => `
    <tr>
      <td>${esc(r.bootstrap_order)}</td>
      <td>${esc(r.proposed_controller_id)}</td>
      <td>${esc(r.year_deployed)}</td>
      <td>${esc(r.network_evidence)}</td>
      <td>${esc(r.uid_evidence)}</td>
      <td>${esc(r.display_name_evidence)}</td>
      <td>${esc(r.model_evidence)}</td>
      <td>${esc(r.firmware_state_evidence === "RECORDED" ? r.firmware_evidence : "VERIFY")}</td>
    </tr>
  `).join("");
}

function showError(err) {
  alert(err.message || String(err));
}

function bind() {
  document.getElementById("refreshButton").addEventListener("click", () => loadCandidates().catch(showError));
  document.getElementById("stateFilter").addEventListener("change", () => loadCandidates().catch(showError));
  document.getElementById("search").addEventListener("keydown", e => {
    if (e.key === "Enter") loadCandidates().catch(showError);
  });
  document.getElementById("saveCandidateButton").addEventListener("click", () => saveCandidate().catch(showError));
  document.getElementById("displaySearchButton").addEventListener("click", () => searchDisplays().catch(showError));
  document.getElementById("displaySearch").addEventListener("keydown", e => {
    if (e.key === "Enter") searchDisplays().catch(showError);
  });
  document.getElementById("prepareOrderButton").addEventListener("click", () => prepareOrder().catch(showError));
  document.getElementById("loadOrderButton").addEventListener("click", () => loadOrder().catch(showError));
}

async function start() {
  bind();
  await Promise.all([loadHealth(), loadModels()]);
  await loadCandidates();
  await loadOrder();
}

start().catch(showError);
