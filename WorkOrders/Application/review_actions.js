/* #419 V0.2 operator workflow rehearsal.
 * Save POSTs commit ONLY to an authorization-marked isolated clone.
 * No outgoing email or live Directus behavior is invoked.
 */
(() => {
  "use strict";
  const byId = (id) => document.getElementById(id);
  const model = { actor: null, ticket: null, options: null, selected: new Set(), csrf: "", runtime: "disposable", pendingSignature: null, pendingKey: null };
  const isLive = () => model.runtime === "production";
  const actions = {
    create: "Create · New Internal Work Order",
    link_setup: "Manager · Add this Work Order to seasonal Setup",
    assign: "Assign / Reassign · Multiple volunteers",
    edit: "Manager · Edit existing Work Order",
    cancel: "Manager · Cancel / No Action",
    progress: "Record Work Note · Keep open",
    complete: "Complete · Required verified work notes",
    promote: "Public Intake · Promote & Assign",
    // Public Intake also supports non-destructive clarification/disposition.
    correction_owner: "Task Feedback · Choose correction owner",
    clarify: "Task Feedback · Request clarification",
    resolve: "Task Feedback · Verified disposition",
    reply: "Task Feedback · Respond to clarification",
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
    if (!ticket) {
      if (actor.can_manage) result.push("create");
      return result;
    }
    // The accepted V1 native command contract does not yet include the
    // optional seasonal Setup link. Do not render a button that would 409.
    // Preserve the existing clone-only link test until the governed native
    // cross-subsystem command is implemented and accepted.
    if (model.runtime === "disposable" &&
        actor.can_manage && ticket.type === "WORK_ORDER" &&
        (ticket.detail?.stage_id || ticket.setup_context?.stage_id)) {
      result.push("link_setup");
    }
    if (ticket.type === "WORK_ORDER" && !ticket.done_at && ticket.active) {
      if (actor.can_manage) result.push("assign", "edit", "cancel");
      if (actor.can_manage ||
          (ticket.assignee_ids || []).some((id) => Number(id) === Number(actor.person_id))) {
        result.push("progress", "complete");
      }
    } else if (ticket.type === "INTAKE_REQUEST") {
      if (actor.can_manage) {
        result.push("promote", "resolve");
        result.push("clarify");
      }
      if (Number(ticket.reporter_id) === Number(actor.person_id))
        result.push("reply");
    } else if (ticket.type === "TASK_FEEDBACK") {
      if (actor.can_manage) result.push("correction_owner", "clarify", "resolve", "promote");
      if (Number(ticket.reporter_id) === Number(actor.person_id)) result.push("reply");
    }
    return result;
  }

  function drawActions() {
    const picker = byId("review-action");
    const previous = picker.value;
    const available = permitted();
    picker.replaceChildren();
    option(picker, "", "Choose an action");
    available.forEach((kind) => option(picker, kind, actions[kind]));
    picker.disabled = !model.actor || !available.length;
    // A late reviewer-options/actor refresh must not silently close a Create
    // form that the operator explicitly opened. The selector is hidden from
    // view, so losing its selected value otherwise looks like a dead button.
    const creating = !model.ticket && model.actor?.can_create &&
      byId("detail-content").classList.contains("create-mode");
    if (available.includes(previous)) picker.value = previous;
    else if (creating && available.includes("create")) picker.value = "create";

    const ticket = model.ticket;
    const title = byId("review-panel-title");
    const buttons = byId("review-action-buttons");
    const guidance = byId("review-action-guidance");
    buttons.replaceChildren();
    const managerMaintenance = byId("detail-manager-maintenance");
    managerMaintenance.hidden = !ticket || !model.actor?.can_manage ||
      ticket.type !== "WORK_ORDER" || Boolean(ticket.done_at);
    title.textContent = !ticket ? "New internal Work Order" :
      ticket.type === "WORK_ORDER" ? "Work on this Work Order" :
      ticket.type === "TASK_FEEDBACK" ? "Review Task Feedback" : "Review Public Intake";

    const labels = {
      progress: "Add Work Note",
      complete: "Complete Work Order",
      assign: "Assign / Reassign",
      edit: "Edit Work Order",
      cancel: "Cancel / No Action",
      link_setup: "Link to seasonal Setup",
      promote: "Promote & Assign",
      correction_owner: "Assign correction owner",
      clarify: "Ask reporter for details",
      reply: "Reply to clarification",
      resolve: "Record disposition / No Work Order",
    };
    // Assignment is a distinct Manager maintenance action in the
    // Work Order heading, not mixed with crew work/complete buttons.
    const visible = available.filter((kind) =>
      kind !== "create" && kind !== "assign");
    visible.forEach((kind) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "review-action-button" +
        (kind === "complete" || kind === "promote" ? " primary-action" : "") +
        (["assign", "edit", "cancel", "link_setup", "correction_owner", "clarify", "resolve"].includes(kind)
          ? " manager-action" : "");
      button.dataset.action = kind;
      button.textContent = labels[kind] || actions[kind];
      button.setAttribute("aria-pressed", String(picker.value === kind));
      button.addEventListener("click", () => {
        if (!permitted().includes(kind)) return;
        picker.value = kind;
        actionChanged();
        buttons.querySelectorAll("button").forEach((item) =>
          item.setAttribute("aria-pressed", String(item.dataset.action === kind)));
        const input = kind === "complete" ? byId("review-completion-notes") :
          kind === "progress" ? byId("review-progress-note") : null;
        if (input) input.focus();
      });
      buttons.appendChild(button);
    });
    guidance.textContent = !ticket
      ? (isLive() ? "Manager Create saves an approved native Work Order." :
          "Complete the new Work Order fields and save to the disposable database.") :
      ticket.type === "WORK_ORDER" && ticket.done_at
        ? "This Work Order has a recorded completion date. Work notes and completion are locked."
        : ticket.type === "WORK_ORDER" && !visible.length
          ? "Only the Manager or an active assignee can update this Work Order."
          : ticket.type === "WORK_ORDER"
            ? "Record what was done, or mark the work complete with required notes."
            : ticket.type === "INTAKE_REQUEST"
              ? "This is a submitted request, not an assigned Work Order. Managers triage it here."
              : "Manager correction review and original-reporter follow-up.";
    byId("review-context").textContent = ticket
      ? "Selected: " + ticket.ticket + " · " +
        (ticket.title || "Untitled") : "Create this Work Order directly; no Intake is generated.";
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

  function uniqueCatalogMatch(selectId, raw, expected) {
    const needle = String(raw || "").trim().toLowerCase();
    if (!needle) return "";
    const entries = Array.from(byId(selectId).options).filter((item) => item.value);
    let matches = entries.filter((item) => item.textContent.trim().toLowerCase() === needle);
    if (expected === "stage" && !matches.length) {
      // Stage key prefix is a stable identity, unlike a free-form Stage name.
      const prefix = /^([0-9]{1,3})[-\\s]/.exec(needle);
      if (prefix) {
        matches = entries.filter((item) =>
          item.textContent.toLowerCase().startsWith("stage " + prefix[1] + " "));
      }
    }
    return matches.length === 1 ? matches[0].value : "";
  }

  function updateIntakeComparison() {
    const d = model.ticket?.detail || {};
    const intake = model.ticket?.type === "INTAKE_REQUEST";
    if (!intake) return;
    const values = {
      "intake-original-urgency": d.priority_raw || d.urgency_id || "Not submitted",
      "intake-original-type": d.task_type_raw || "Not submitted",
      "intake-original-location": d.stage_raw || d.work_area_raw || "Not submitted",
      "intake-mapped-urgency": byId("review-urgency").selectedOptions[0]?.textContent || "Select urgency",
      "intake-mapped-type": byId("review-task-type").selectedOptions[0]?.textContent || "Choose Task Type",
      "intake-mapped-location": byId("review-location-type").value === "stage"
        ? byId("review-stage").selectedOptions[0]?.textContent
        : byId("review-location-type").value === "area"
          ? byId("review-area").selectedOptions[0]?.textContent : "Choose Stage or Work Area",
    };
    Object.entries(values).forEach(([id, value]) => { byId(id).textContent = String(value || "Not selected"); });
    const missing = [];
    if (!byId("review-task-type").value) missing.push("Task Type");
    if (!byId("review-location-type").value ||
        !(byId("review-location-type").value === "stage"
          ? byId("review-stage").value : byId("review-area").value))
      missing.push("Stage / Work Area");
    byId("intake-mapping-status").textContent = missing.length
      ? "Manager confirmation required: " + missing.join(", ") + "."
      : "Catalog selections populated. Review and correct before promoting.";
  }

  function setSelectionFromTicket() {
    model.selected = new Set((model.ticket?.assignee_ids || []).map(Number));
    drawPeople();
    byId("review-problem").value =
      model.ticket?.detail?.problem_raw || model.ticket?.detail?.problem ||
      model.ticket?.title || "";
    byId("review-target-year").value = model.ticket?.urgency == 5 ? (model.ticket?.yr || "") : "";
    byId("review-urgency").value = String(model.ticket?.urgency || 3);
    planningChanged();
    const detail = model.ticket?.detail || {};
    const kind = detail.stage_id ? "stage" : detail.work_area_id ? "area" : "";
    byId("review-location-type").value = kind;
    byId("review-stage").value = detail.stage_id || "";
    byId("review-area").value = detail.work_area_id || "";
    if (model.ticket?.type === "WORK_ORDER") {
      byId("review-task-type").value = detail.task_type_id || "";
      byId("review-urgency").value = detail.urgency_id || "";
      byId("review-target-year").value = detail.target_year || "";
    }
    // Public-form values may be plain text; resolve only unique catalog hits.
    if (model.ticket?.type === "INTAKE_REQUEST") {
      const submittedPriority = String(detail.priority_raw || detail.urgency_id || model.ticket?.urgency || "");
      if (/^[1-5]$/.test(submittedPriority)) byId("review-urgency").value = submittedPriority;
      const existingType = String(detail.task_type_id || "");
      if (existingType && Array.from(byId("review-task-type").options).some(o => o.value === existingType))
        byId("review-task-type").value = existingType;
      else byId("review-task-type").value = uniqueCatalogMatch("review-task-type", detail.task_type_raw);
      if (!kind && detail.stage_raw) {
        const matched = uniqueCatalogMatch("review-stage", detail.stage_raw, "stage");
        if (matched) {
          byId("review-location-type").value = "stage";
          byId("review-stage").value = matched;
        }
      } else if (!kind && detail.work_area_raw) {
        const matched = uniqueCatalogMatch("review-area", detail.work_area_raw);
        if (matched) {
          byId("review-location-type").value = "area";
          byId("review-area").value = matched;
        }
      }
    }
    locationChanged();
    planningChanged();
    updateIntakeComparison();
  }

  function planningChanged() {
    const planning = byId("review-urgency").value === "5";
    byId("review-year-wrap").hidden = !planning;
    byId("review-target-year").required = planning;
    if (!planning) byId("review-target-year").value = "";
  }

  function locationChanged() {
    byId("review-stage-wrap").hidden = byId("review-location-type").value !== "stage";
    byId("review-area-wrap").hidden = byId("review-location-type").value !== "area";
    setupModeChanged();
    updateIntakeComparison();
  }

  function setupModeChanged() {
    const mode = byId("review-setup-mode").value;
    const isManager = Boolean(model.actor?.can_manage);
    const create = mode === "create" && isManager;
    byId("review-setup-fields").hidden = !create;
    // Only Stage-based park repair can create a linked Setup gate.
    if (create && byId("review-location-type").value !== "stage") {
      byId("review-setup-mode").value = "request";
      byId("review-setup-fields").hidden = true;
    }
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
                          "review-stage", "review-area", "review-urgency",
                          "review-setup-season", "review-setup-name")) {
        byId(name).value = "";
      }
      byId("review-urgency").value = "3";
      byId("review-setup-mode").value = "none";
    } else {
      setSelectionFromTicket();
      // A previous seasonal request can never leak into an assignment,
      // progress/completion, or unrelated triage decision.
      byId("review-setup-mode").value = "none";
    }
    byId("review-progress-note").value = "";
    byId("review-completion-notes").value = "";
    byId("review-response").value = "";
    byId("review-edit-reason").value = "";
    byId("review-cancel-reason").value = "";
    byId("review-disposition").value = "";
    planningChanged();
    showForm();
  }

  function showForm() {
    const kind = byId("review-action").value;
    const form = byId("review-action-form");
    form.hidden = !kind;
    byId("review-create-fields").hidden = !["create", "promote", "edit"].includes(kind);
    byId("review-edit-reason-fields").hidden = kind !== "edit";
    byId("review-setup-choice").hidden = !["create", "promote"].includes(kind);
    byId("review-cancel-fields").hidden = kind !== "cancel";
    byId("review-intake-comparison").hidden = !(kind === "promote" && model.ticket?.type === "INTAKE_REQUEST");
    byId("review-link-setup-fields").hidden = kind !== "link_setup";
    byId("review-person-fields").hidden =
      !model.actor?.can_manage ||
      !["create", "assign", "promote", "correction_owner"].includes(kind);
    byId("review-progress-fields").hidden = kind !== "progress";
    byId("review-complete-fields").hidden = kind !== "complete";
    byId("review-feedback-fields").hidden = !["clarify", "resolve", "reply"].includes(kind);
    byId("review-disposition").disabled = kind !== "resolve";
    byId("review-result").textContent = "";
    byId("review-cancel-create").hidden = kind !== "create";
    // A selected Edit is a separate workspace, not another browsing column.
    document.dispatchEvent(new CustomEvent("wo419:edit-mode", {
      detail: {editing: kind === "edit"}
    }));
    const submit = byId("review-submit");
    const submitNames = {
      create: "Create Work Order",
      edit: "Save Work Order Corrections",
      cancel: "Cancel Work Order · Do Not Mark Complete",
      assign: "Save assignments",
      progress: "Save Work Note · Keep open",
      complete: "Confirm and Save Completion",
      link_setup: "Link Work Order to Setup",
      promote: "Promote & Assign",
      correction_owner: "Save correction owner",
      clarify: "Save clarification request · No email sent",
      reply: "Save reporter reply",
      resolve: "Save feedback resolution · No email sent",
    };
    submit.textContent = submitNames[kind] ||
      (isLive() ? "Save authoritative Work Order" : "Save to disposable database");
    if (kind && ["create", "promote", "edit"].includes(kind)) {
      locationChanged();
      planningChanged();
    } else {
      byId("review-year-wrap").hidden = true;
      byId("review-target-year").required = false;
      byId("review-setup-fields").hidden = true;
    }
  }

  function validate() {
    const kind = byId("review-action").value;
    if (!permitted().includes(kind)) throw new Error("This action is not available to your identity.");
    const source = model.ticket?.ticket || "NEW INTERNAL WORK ORDER";
    const note = byId("review-response").value.trim();
    if (["create", "promote", "edit"].includes(kind)) {
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
      if (byId("review-urgency").value === "5") {
        if (!/^\d{4}$/.test(year) || +year < 2020 || +year > 2100)
          throw new Error("Planning Work Orders require a valid target year.");
      } else if (year) {
        throw new Error("Target year is only used for Planning work.");
      }
      const setupMode = byId("review-setup-mode").value;
      if (setupMode === "create") {
        if (!model.actor?.can_manage) throw new Error("Only a Manager can add seasonal Setup work.");
        if (locationKind !== "stage") throw new Error("Choose the park Stage for seasonal Setup.");
        if (!byId("review-setup-season").value)
          throw new Error("Choose an existing open seasonal Setup session.");
      }
    }
    if (kind === "edit" && byId("review-edit-reason").value.trim().length < 10)
      throw new Error("An accountable correction reason (at least 10 characters) is required.");
    if (kind === "cancel" && byId("review-cancel-reason").value.trim().length < 10)
      throw new Error("Cancel / No Action requires an explanation (at least 10 characters).");
    if (kind === "link_setup") {
      if (!model.actor?.can_manage) throw new Error("Only a Manager may link Setup work.");
      if (!model.ticket?.detail?.stage_id)
        throw new Error("This Work Order has no Park Stage to link to Setup.");
      if (!byId("review-link-setup-season").value)
        throw new Error("Choose an existing open seasonal Setup session.");
    }
    if (["assign", "promote", "correction_owner"].includes(kind) && !model.selected.size)
      throw new Error("Select at least one exact existing Person.");
    if (kind === "progress" && byId("review-progress-note").value.trim().length < 10)
      throw new Error("Record a substantive work note before saving (at least 10 characters).");
    if (kind === "complete" && byId("review-completion-notes").value.trim().length < 10)
      throw new Error("Completion requires substantive notes explaining actual work.");
    if (kind === "reply" && note.length < 10)
      throw new Error("Respond with a substantive detail (at least 10 characters).");
    if (kind === "clarify" && note.length < 10)
      throw new Error("Ask a specific clarification question (at least 10 characters).");
    // The Manager may record a question when contact cannot be verified,
    // but it remains flagged for manual contact; no message is claimed sent.
    if (kind === "resolve" && (!byId("review-disposition").value || note.length < 10))
      throw new Error("Choose a disposition and provide a substantive explanation.");
    const names = (model.options?.people || [])
      .filter((person) => model.selected.has(Number(person.person_id)))
      .map((person) => person.display_name);
    const label = actions[kind];
    return label + " · " + source +
      (kind === "clarify" && !model.ticket?.reporter_id
        ? " · Reporter is not linked: contact will be flagged, NOT sent." : "") +
      (names.length && ["create","assign","promote","correction_owner"].includes(kind)
        ? " · " + names.join(", ") : "") +
      ".";
  }

  async function saveAction() {
    const kind = byId("review-action").value;
    if (!model.csrf || !model.actor) throw new Error("Approved disposable login is missing.");
    const summary = validate();
    if (!window.confirm(
      summary + (isLive()
        ? "\n\nSave this change to the PRODUCTION Work Orders database?\n" +
          "This change is permanent. Notifications are held pending release; not sent."
        : "\n\nSave this change in the TEMPORARY disposable database?\n" +
          "It will be discarded when the browser review ends. No emails will be sent.")
    )) return null;
    const location = byId("review-location-type").value;
    const body = {
      action: kind,
      ticket: kind === "create" ? null : model.ticket?.ticket,
      person_ids: [...model.selected],
      problem: byId("review-problem").value.trim(),
      task_type_id: byId("review-task-type").value,
      urgency: byId("review-urgency").value,
      target_year: ["create", "promote", "edit"].includes(kind) &&
        byId("review-urgency").value === "5"
        ? byId("review-target-year").value : null,
      setup_mode: kind === "link_setup" ? "create" : byId("review-setup-mode").value,
      setup_season_year: kind === "link_setup"
        ? byId("review-link-setup-season").value : byId("review-setup-season").value,
      setup_task_name: kind === "link_setup"
        ? byId("review-link-setup-name").value.trim() : byId("review-setup-name").value.trim(),
      stage_id: location === "stage" ? byId("review-stage").value : null,
      work_area_id: location === "area" ? byId("review-area").value : null,
      progress_note: byId("review-progress-note").value.trim(),
      completion_notes: byId("review-completion-notes").value.trim(),
      response: byId("review-response").value.trim(),
      edit_reason: byId("review-edit-reason").value.trim(),
      cancel_reason: byId("review-cancel-reason").value.trim(),
      disposition: byId("review-disposition").value,
    };
    const signature = JSON.stringify(body);
    if (signature !== model.pendingSignature) {
      model.pendingSignature = signature;
      model.pendingKey = crypto.randomUUID();
    }
    body.request_key = model.pendingKey;
    const response = await fetch("/api/work-orders/commands", {
      method: "POST", credentials: "same-origin", cache: "no-store",
      headers: { "Content-Type": "application/json", "Accept": "application/json",
                 "X-WO419-CSRF": model.csrf,
                 "X-MSB-Work-Order-Command": "1" },
      body: JSON.stringify(body),
    });
    const payload = await response.json();
    if (!response.ok || !payload.result?.saved) {
      throw new Error(payload.error || "Work Order save failed; no success was recorded.");
    }
    model.pendingSignature = null;
    model.pendingKey = null;
    document.dispatchEvent(new CustomEvent("wo419:saved", {
      detail: { ...payload.result, action: kind },
    }));
    return payload.result;
  }

  function openCreate() {
    if (!model.actor?.can_manage) return;
    model.ticket = null;
    const detail = byId("detail-content");
    byId("detail-empty").hidden = true;
    detail.hidden = false;
    detail.classList.add("create-mode");
    drawActions();
    byId("review-action").value = "create";
    actionChanged();
    // Explicitly expose the form: a disabled/hidden action picker cannot be
    // the only UI state proof for direct Create. If a later asynchronous
    // redraw runs, drawActions() above preserves create-mode.
    const form = byId("review-action-form");
    form.hidden = false;
    byId("review-create-fields").hidden = false;
    byId("create-work-order").setAttribute("aria-expanded", "true");
    byId("review-workbench").scrollIntoView({ behavior: "smooth", block: "start" });
    byId("review-problem").focus();
    document.dispatchEvent(new CustomEvent("wo419:open-create"));
  }

  function openManagerAssignment() {
    if (!model.actor?.can_manage || !model.ticket ||
        model.ticket.type !== "WORK_ORDER" || model.ticket.done_at) return;
    byId("review-action").value = "assign";
    actionChanged();
    byId("review-workbench").scrollIntoView({ behavior: "smooth", block: "nearest" });
    byId("review-person-filter").focus();
  }

  async function initializeReviewerOptions() {
    if (!model.actor?.can_create) return;
    try {
      const result = await fetch("/api/work-orders/reviewer-options", {
        credentials: "same-origin", cache: "no-store",
        headers: { "Accept": "application/json" },
      });
      if (!result.ok) throw new Error("Manager catalog read failed.");
      const payload = await result.json();
      if (payload.read_only ||
          !(payload.disposable_only ||
            (isLive() && payload.runtime_mode === "production")))
        throw new Error("Approved Work Order catalog permission unavailable.");
      model.options = payload.options;
      document.querySelectorAll("#review-setup-mode option[data-manager-only]")
        .forEach((option) => {
          option.hidden = !model.actor?.can_manage;
          option.disabled = !model.actor?.can_manage;
        });
      catalog("review-setup-season", model.options.setup_seasons || []);
      catalog("review-link-setup-season", model.options.setup_seasons || []);
      catalog("review-task-type", model.options.task_types || []);
      catalog("review-stage", model.options.stages || []);
      catalog("review-area", model.options.work_areas || []);
      setSelectionFromTicket();
      drawActions();
    } catch (_) {
      byId("review-context").textContent =
        "Catalog verification unavailable. Hold internal creation; do not enter invented IDs.";
      byId("review-action").disabled = true;
    }
  }

  document.addEventListener("wo419:actor", (event) => {
    model.actor = event.detail;
    model.csrf = event.detail.csrf_token || "";
    model.runtime = event.detail.runtime_mode || "disposable";
    byId("create-work-order").hidden = !model.actor.can_manage;
    byId("create-work-order").setAttribute("aria-expanded", "false");
    byId("create-work-order").title = "Managers create approved Work Orders; others submit Intake requests.";
    byId("review-action").disabled = !model.actor.can_manage;
    byId("review-context").textContent = "New requests enter Intake for Manager triage.";
    drawActions();
    initializeReviewerOptions();
  });
  document.addEventListener("wo419:ticket", (event) => {
    model.ticket = event.detail;
    byId("detail-content").classList.remove("create-mode");
    byId("create-work-order").setAttribute("aria-expanded", "false");
    byId("review-action").value = "";
    setSelectionFromTicket();
    drawActions();
  });
  byId("review-action").addEventListener("change", actionChanged);
  byId("create-work-order").addEventListener("click", openCreate);
  byId("manager-assign-button").addEventListener("click", openManagerAssignment);
  byId("review-cancel-create").addEventListener("click", () => {
    if (!byId("detail-content").classList.contains("create-mode")) return;
    const entered = byId("review-problem").value.trim();
    if (entered && !window.confirm("Discard this unsaved Work Order? No record will be created.")) return;
    model.pendingSignature = null;
    model.pendingKey = null;
    model.selected.clear();
    document.dispatchEvent(new CustomEvent("wo419:cancel-create"));
  });
  document.addEventListener("wo419:history-create", openCreate);
  byId("review-location-type").addEventListener("change", locationChanged);
  byId("review-task-type").addEventListener("change", updateIntakeComparison);
  byId("review-stage").addEventListener("change", updateIntakeComparison);
  byId("review-area").addEventListener("change", updateIntakeComparison);
  byId("review-urgency").addEventListener("change", () => { planningChanged(); updateIntakeComparison(); });
  byId("review-setup-mode").addEventListener("change", setupModeChanged);
  byId("review-person-filter").addEventListener("input", drawPeople);
  byId("review-action-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const box = byId("review-result");
    const submit = event.submitter;
    if (submit) submit.disabled = true;
    try {
      const saved = await saveAction();
      if (saved) {
        if (kind === "edit") {
          byId("review-action").value = "";
          drawActions();
        }
        box.textContent = (isLive() ? "SAVED to Work Orders: " :
          "SAVED on disposable clone: ") + saved.ticket +
          (saved.linked_setup_session_task_id
            ? " · linked Setup season-only task #" + saved.linked_setup_session_task_id
            : "") +
          (saved.notifications === "MISSING_RECIPIENT"
            ? ". REPORTER CONTACT MISSING — Manager follow-up required. No email sent."
            : isLive() ? ". Notifications: PENDING CUTOVER; no send yet."
            : ". Notification: NO SEND. This change disappears at cleanup.");
        box.dataset.valid = "true";
      }
    } catch (error) {
      box.textContent = error.message || "Save failed; no success recorded.";
      box.dataset.valid = "false";
    } finally {
      if (submit) submit.disabled = false;
    }
  });
})();