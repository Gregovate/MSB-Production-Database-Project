/* #419 V0.2 operator workflow rehearsal.
 * No POST, mutation, notification transport, or new ticket identity.
 * Real clone catalog choices + client-side validation only.
 * This is a UX acceptance slice, NOT operational P0 write acceptance.
 */
(() => {
  "use strict";
  const byId = (id) => document.getElementById(id);
  const model = { actor: null, ticket: null, options: null, selected: new Set() };
  const actions = {
    create: "Manager Create · Internal Work Order",
    assign: "Assign / Reassign · Multiple volunteers",
    complete: "Complete · Required verified work notes",
    promote: "Public Intake · Promote & Assign",
    correction_owner: "Task Feedback · Choose correction owner",
    clarify: "Task Feedback · Request clarification",
    resolve: "Task Feedback · Verified disposition",
  };

  function option(select, value, name) {
    const item = document.createElement("option");
    item.value = String(value);
    item.textContent = String(name);
    select.appendChild(item);
  }

  function catalog(selectId, rows) {
    const select = byId(selectId);
    select.replaceChildren();
    option(select, "", "Choose an existing item");
    rows.forEach((row) => option(select, row.id, row.name));
  }

  function permitted() {
    const ticket = model.ticket;
    const actor = model.actor;
    const result = [];
    if (!actor) return result;
    if (actor.can_manage) result.push("create");
    if (!ticket) return result;
    if (ticket.type === "WORK_ORDER" && !ticket.done_at) {
      if (actor.can_manage) result.push("assign");
      if (actor.can_manage ||
          (ticket.assignee_ids || []).some((id) => Number(id) === Number(actor.person_id))) {
        result.push("complete");
      }
    } else if (actor.can_manage && ticket.type === "INTAKE_REQUEST") {
      result.push("promote");
    } else if (actor.can_manage && ticket.type === "TASK_FEEDBACK") {
      result.push("correction_owner", "clarify", "resolve", "promote");
    }
    return result;
  }

  function drawActions() {
    const select = byId("review-action");
    const previous = select.value;
    select.replaceChildren();
    option(select, "", "Select proposed action");
    for (const kind of permitted()) option(select, kind, actions[kind]);
    select.disabled = !model.actor || !permitted().length;
    if (permitted().includes(previous)) select.value = previous;
    byId("review-context").textContent = model.ticket
      ? "Current source: " + model.ticket.ticket + " · " +
        (model.ticket.title || "Untitled") + " · " +
        (model.ticket.reported_by || "Reporter not recorded")
      : "No selected ticket. Managers may still rehearse direct internal creation.";
    showForm();
  }

  function drawPeople() {
    const people = model.options?.people || [];
    const query = byId("review-person-filter").value.trim().toLowerCase();
    const container = byId("review-people");
    container.replaceChildren();
    const matching = people.filter((person) =>
      person.display_name.toLowerCase().includes(query) ||
      String(person.person_id).includes(query)
    );
    matching.slice(0, 70).forEach((person) => {
      const label = document.createElement("label");
      const input = document.createElement("input");
      input.type = "checkbox";
      input.value = String(person.person_id);
      input.checked = model.selected.has(Number(person.person_id));
      input.addEventListener("change", () => {
        if (input.checked) model.selected.add(Number(person.person_id));
        else model.selected.delete(Number(person.person_id));
      });
      label.append(input, document.createTextNode(" " + person.display_name));
      container.appendChild(label);
    });
    if (matching.length > 70) {
      const hint = document.createElement("p");
      hint.textContent = "Showing 70 matches; refine the name filter for more.";
      container.appendChild(hint);
    }
    if (!matching.length) container.textContent = "No matching active linked People.";
  }

  function setSelectionFromTicket() {
    model.selected = new Set((model.ticket?.assignee_ids || []).map(Number));
    drawPeople();
    byId("review-problem").value =
      model.ticket?.detail?.problem_raw || model.ticket?.detail?.problem ||
      model.ticket?.title || "";
    byId("review-target-year").value = model.ticket?.yr || "";
    byId("review-urgency").value = model.ticket?.urgency || "";
    const detail = model.ticket?.detail || {};
    const kind = detail.stage_id ? "stage" : detail.work_area_id ? "area" : "";
    byId("review-location-type").value = kind;
    byId("review-stage").value = detail.stage_id || "";
    byId("review-area").value = detail.work_area_id || "";
    locationChanged();
  }

  function locationChanged() {
    byId("review-stage-wrap").hidden = byId("review-location-type").value !== "stage";
    byId("review-area-wrap").hidden = byId("review-location-type").value !== "area";
  }

  function actionChanged() {
    // Direct Create must never reuse a previously selected ticket's report,
    // assignees, urgency or location as if it were a new instruction.
    const kind = byId("review-action").value;
    if (kind === "create") {
      model.selected.clear();
      byId("review-person-filter").value = "";
      drawPeople();
      for (const name of ("review-problem", "review-target-year",
                          "review-task-type", "review-location-type",
                          "review-stage", "review-area", "review-urgency")) {
        byId(name).value = "";
      }
    } else {
      setSelectionFromTicket();
    }
    byId("review-completion-notes").value = "";
    byId("review-response").value = "";
    byId("review-disposition").value = "";
    showForm();
  }

  function showForm() {
    const kind = byId("review-action").value;
    const form = byId("review-action-form");
    form.hidden = !kind;
    byId("review-create-fields").hidden = !["create", "promote"].includes(kind);
    byId("review-person-fields").hidden = !["create", "assign", "promote", "correction_owner"].includes(kind);
    byId("review-complete-fields").hidden = kind !== "complete";
    byId("review-feedback-fields").hidden = !["clarify", "resolve"].includes(kind);
    byId("review-disposition").disabled = kind !== "resolve";
    byId("review-result").textContent = "";
    if (kind && ["create", "promote"].includes(kind)) locationChanged();
  }

  function validate() {
    const kind = byId("review-action").value;
    if (!permitted().includes(kind)) throw new Error("This action is not available to your identity.");
    const source = model.ticket?.ticket || "NEW INTERNAL WORK ORDER";
    const note = byId("review-response").value.trim();
    if (["create", "promote"].includes(kind)) {
      const problem = byId("review-problem").value.trim();
      if (problem.length < 10) throw new Error("Describe the actual job (at least 10 characters).");
      if (!byId("review-task-type").value)
        throw new Error("Choose a real Task Type, not a fabricated default.");
      if (!byId("review-urgency").value)
        throw new Error("Choose an urgency from the existing five-level catalog.");
      const locationKind = byId("review-location-type").value;
      const locationId = locationKind === "stage"
        ? byId("review-stage").value : byId("review-area").value;
      if (!["stage", "area"].includes(locationKind) || !locationId)
        throw new Error("Choose exactly one valid Stage OR Work Area.");
      const year = byId("review-target-year").value;
      if (year && (!/^\d{4}$/.test(year) || +year < 2020 || +year > 2100))
        throw new Error("Choose a valid target year.");
    }
    if (["assign", "promote", "correction_owner"].includes(kind) && !model.selected.size)
      throw new Error("Select at least one exact existing Person.");
    if (kind === "complete" && byId("review-completion-notes").value.trim().length < 10)
      throw new Error("Completion requires substantive notes explaining actual work.");
    if (kind === "clarify" && note.length < 10)
      throw new Error("Ask a specific clarification question (at least 10 characters).");
    if (kind === "clarify" && !model.ticket?.reporter_id)
      throw new Error("Original reporter identity is not verified; no notification may be targeted.");
    if (kind === "resolve" && (!byId("review-disposition").value || note.length < 10))
      throw new Error("Choose a disposition and provide a substantive explanation.");
    const names = (model.options?.people || [])
      .filter((person) => model.selected.has(Number(person.person_id)))
      .map((person) => person.display_name);
    const label = actions[kind];
    return label + " · " + source +
      (names.length && ["create","assign","promote","correction_owner"].includes(kind)
        ? " · " + names.join(", ") : "") +
      ". VALIDATION ONLY: Nothing was saved or sent.";
  }

  async function initializeReviewerOptions() {
    if (!model.actor?.can_manage) return;
    try {
      const result = await fetch("/api/work-orders/reviewer-options", {
        credentials: "same-origin", cache: "no-store",
        headers: { "Accept": "application/json" },
      });
      if (!result.ok) throw new Error("Manager catalog read failed.");
      const payload = await result.json();
      if (!payload.read_only || !payload.rehearsal_only)
        throw new Error("Invalid no-save acceptance mode.");
      model.options = payload.options;
      catalog("review-task-type", model.options.task_types || []);
      catalog("review-stage", model.options.stages || []);
      catalog("review-area", model.options.work_areas || []);
      setSelectionFromTicket();
      drawActions();
    } catch (_) {
      byId("review-context").textContent =
        "Catalog verification unavailable. Hold Manager rehearsal; do not enter invented IDs.";
      byId("review-action").disabled = true;
    }
  }

  document.addEventListener("wo419:actor", (event) => {
    model.actor = event.detail;
    drawActions();
    initializeReviewerOptions();
  });
  document.addEventListener("wo419:ticket", (event) => {
    model.ticket = event.detail;
    byId("review-action").value = "";
    setSelectionFromTicket();
    drawActions();
  });
  byId("review-action").addEventListener("change", actionChanged);
  byId("review-location-type").addEventListener("change", locationChanged);
  byId("review-person-filter").addEventListener("input", drawPeople);
  byId("review-action-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const result = byId("review-result");
    try {
      result.textContent = validate();
      result.dataset.valid = "true";
    } catch (error) {
      result.textContent = error.message;
      result.dataset.valid = "false";
    }
  });
})();