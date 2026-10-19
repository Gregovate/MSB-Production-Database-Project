/* #419 V0.3: read browser with approved disposable-only save commands. */
(() => {
  "use strict";
  const $ = (id) => document.getElementById(id);
  const state = {
    actor: null, tickets: [], assignees: [], selected: null,
    detail: null, relatedLoadedFor: null, fetchId: 0, listFetchId: 0,
    agingRows: [], agingFetchId: 0,
    navigationReady: false, restoringNavigation: false, createMode: false,
  };

  function escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  async function getJson(url) {
    const result = await fetch(url, {
      credentials: "same-origin",
      headers: { "Accept": "application/json" },
      cache: "no-store",
    });
    let payload;
    try { payload = await result.json(); }
    catch (_) { throw new Error("Server did not return an expected response."); }
    if (!result.ok) throw new Error(payload.error || "Work Management request failed.");
    return payload;
  }

  // Work Management is a single-screen application: browser Back/Forward
  // must restore internal views and selected tickets, not eject the operator.
  const knownScopes = new Set(["mine", "my-created", "my-feedback", "all",
    "tickets", "aging", "person", "critical", "unassigned", "repairs",
    "testing", "intake", "feedback"]);
  const knownSorts = new Set(["priority", "priority_desc", "number_asc",
    "number_desc", "created_asc", "created_desc"]);

  function navigationSnapshot() {
    return {
      scope: $("scope").value, person: $("assignee").value,
      sort: $("ticket-sort").value,
      include_planning: $("include-planning").checked ? "1" : "0",
      showCompleted: $("show-completed").checked,
      includePlanning: $("include-planning").checked,
      search: $("ticket-search").value,
      ticket: state.selected,
      mode: state.createMode ? "create" : "view",
      listScroll: $("ticket-list").scrollTop,
    };
  }

  function writeNavigation(mode = "push") {
    if (!state.navigationReady || state.restoringNavigation) return;
    const next = navigationSnapshot();
    const current = window.history.state?.wo419;
    if (mode === "push" && current &&
        JSON.stringify({...current, listScroll: 0}) ===
        JSON.stringify({...next, listScroll: 0})) return;
    const url = new URL(window.location.href);
    const values = {
      scope: next.scope, sort: next.sort,
      show_completed: next.showCompleted ? "1" : "0",
      include_planning: next.includePlanning ? "1" : "0",
      q: next.search, person_id: next.person,
      ticket: next.ticket || "", mode: next.mode === "create" ? "create" : "",
    };
    Object.entries(values).forEach(([key, value]) => {
      if (value) url.searchParams.set(key, value);
      else url.searchParams.delete(key);
    });
    window.history[mode === "replace" ? "replaceState" : "pushState"](
      {wo419: next}, "", url.pathname + url.search);
  }

  function restoreControls(snapshot) {
    const requested = knownScopes.has(snapshot.scope) ? snapshot.scope : "mine";
    const manager = Boolean(state.actor?.can_manage);
    $("scope").value = !manager &&
      !["mine","my-created","my-feedback"].includes(requested) ? "mine" : requested;
    $("ticket-sort").value = knownSorts.has(snapshot.sort) ? snapshot.sort : "priority";
    $("show-completed").checked = Boolean(snapshot.showCompleted);
    $("include-planning").checked = Boolean(snapshot.includePlanning);
    $("ticket-search").value = String(snapshot.search || "").slice(0, 120);
    $("assignee").value = snapshot.person || "";
    $("person-field").hidden = $("scope").value !== "person";
  }

  function resetDetail() {
    state.selected = null;
    state.detail = null;
    state.createMode = false;
    ++state.fetchId;
    $("detail-content").hidden = true;
    $("detail-empty").hidden = false;
    $("detail-content").classList.remove("create-mode");
    document.dispatchEvent(new CustomEvent("wo419:ticket", {detail: null}));
  }

  async function restoreNavigation(snapshot) {
    if (!snapshot) return;
    state.restoringNavigation = true;
    try {
      restoreControls(snapshot);
      resetDetail();
      await loadTickets();
      if (snapshot.mode === "create" && state.actor?.can_create) {
        state.createMode = true;
        document.dispatchEvent(new CustomEvent("wo419:history-create"));
      } else if (snapshot.ticket) {
        await selectTicket(snapshot.ticket, {noHistory: true});
      }
      $("ticket-list").scrollTop = Number(snapshot.listScroll) || 0;
    } finally {
      state.restoringNavigation = false;
    }
  }

  function initializeNavigation() {
    const qs = new URLSearchParams(window.location.search);
    restoreControls({
      scope: qs.get("scope") || "mine", sort: qs.get("sort") || "priority",
      person: qs.get("person_id") || "",
      showCompleted: qs.get("show_completed") === "1",
      includePlanning: qs.get("include_planning") === "1",
      search: qs.get("q") || "",
    });
    state.navigationReady = true;
    writeNavigation("replace");
    const ticket = qs.get("ticket");
    return {ticket: /^(WO|INTAKE)-[1-9]\\d{0,12}$/.test(ticket || "") ? ticket : null,
      create: qs.get("mode") === "create"};
  }

  function error(message) {
    const box = $("page-error");
    box.textContent = message || "";
    box.hidden = !message;
  }

  function scopeLabel() {
    const scope = $("scope").value;
    if (scope === "mine") return "My Assigned Work Orders";
    if (scope === "my-created") return "Work Orders I Created";
    if (scope === "all") return "All Work Orders";
    if (scope === "tickets") return "All Tickets · Search";
    if (scope === "aging") return "Open Work Order Aging Report";
    if (scope === "my-feedback") return "My Submitted Feedback";
    if (scope === "critical") return "Manager · Immediate / Critical Repairs";
    if (scope === "unassigned") return "Manager · Unassigned Work Orders";
    if (scope === "repairs") return "Manager · Park and routine repairs";
    if (scope === "testing") return "Manager · Testing repair assignment";
    if (scope === "intake") return "Manager · Public Intake triage";
    if (scope === "feedback") return "Manager · Task Feedback review";
    const name = state.assignees.find((p) =>
      String(p.person_id) === $("assignee").value);
    return name ? "Assigned to " + name.display_name : "Choose a volunteer";
  }

  function statusLabel(row) {
    if (row.done_at) return "Completed (date recorded)";
    if (row.type === "TASK_FEEDBACK") {
      const dispositions = {
        RESOLVED: "Resolved / Verified", DEFERRED: "Deferred",
        REJECTED: "Rejected / No Action", DUPLICATE: "Duplicate / Linked",
        WAITING_ON_REPORTER: "Waiting on reporter",
        PROMOTED_TO_WO: "Promoted to Work Order",
      };
      if (dispositions[row.state]) return dispositions[row.state];
    }
    if (row.type !== "WORK_ORDER") return row.state === "SUBMITTED"
      ? "Submitted — awaiting review" : "Intake review state: " + (row.state || "Not recorded");
    if (!row.active) return "Inactive — not recorded complete";
    return "Not recorded complete";
  }

  function categoryLabel(row) {
    if (row.type === "TASK_FEEDBACK") return "Correction / Task Feedback";
    if (row.type === "INTAKE_REQUEST") return "Intake Request";
    return row.test_id ? "Testing Repair / Work Order" : "Work Order";
  }

  function renderList() {
    const list = $("ticket-list");
    $("list-heading").textContent = scopeLabel();
    $("list-count").textContent =
      state.tickets.length + " item(s) shown · current source snapshot";
    if (!state.tickets.length) {
      list.innerHTML =
        '<div class="empty-list">No matching work recorded in this view.' +
        ($("scope").value === "mine" && state.actor?.can_manage
          ? '<button id="empty-view-all" type="button" class="quiet-button">View All Work Orders</button>'
          : "") +
        "</div>";
      $("empty-view-all")?.addEventListener("click", () => {
        $("scope").value = "all"; scopeChanged();
      });
      return;
    }
    list.innerHTML = state.tickets.map((row) => {
      const active = state.selected === row.ticket;
      const loc = row.location || "Location not recorded";
      return '<button type="button" role="listitem" class="ticket-card' +
        (active ? ' selected' : '') +
        '" data-ticket="' + escapeHtml(row.ticket) +
        '" aria-current="' + (active ? "true" : "false") + '">' +
        '<div class="card-top"><span class="ticket-type">' +
        escapeHtml(categoryLabel(row)) + '</span><span class="ticket-id">' +
        escapeHtml(row.ticket) + '</span></div>' +
        '<h4>' + escapeHtml(row.title || "Untitled item") + '</h4>' +
        '<p class="card-meta">' + escapeHtml(loc) +
        (row.urgency ? ' · <strong>Urgency ' + escapeHtml(row.urgency) +
          (row.urgency === 1 ? ' · CRITICAL' : '') + '</strong>' : ' · Urgency not recorded') +
        '</p>' +
        '<div class="card-footer"><span>' +
        escapeHtml(row.owners || "Unassigned") + '</span><span class="status' +
        (row.done_at ? " done" : "") + '">' +
        escapeHtml(statusLabel(row)) + '</span></div></button>';
    }).join("");
    list.querySelectorAll(".ticket-card").forEach((button) => {
      button.addEventListener("click", () => selectTicket(button.dataset.ticket));
    });
  }

  async function loadManagerInbox() {
    if (!state.actor?.can_manage) {
      $("manager-inbox-banner").hidden = true;
      return;
    }
    const banner = $("manager-inbox-banner");
    try {
      const result = await getJson("/api/work-orders/manager-inbox");
      const summary = result.inbox || {};
      const publicCount = Number(summary.public_intake || 0);
      const feedbackCount = Number(summary.task_feedback || 0);
      $("manager-inbox-message").textContent =
        publicCount + " Public Work Order Request" + (publicCount === 1 ? "" : "s") +
        " awaiting triage · " + feedbackCount + " Task Feedback finding" +
        (feedbackCount === 1 ? "" : "s") + " requiring review";
      $("go-intake").textContent = "Public Intake (" + publicCount + ")";
      $("go-feedback").textContent = "Task Feedback (" + feedbackCount + ")";
      banner.hidden = publicCount === 0 && feedbackCount === 0;
    } catch (exc) {
      banner.hidden = false;
      $("manager-inbox-message").textContent =
        "Unable to verify Intake status: " + exc.message;
      $("go-intake").textContent = "Open Public Intake";
      $("go-feedback").textContent = "Open Task Feedback";
    }
  }

  function goManagerQueue(scope) {
    if (!state.actor?.can_manage) return;
    $("scope").value = scope;
    scopeChanged();
  }

  function agingCsvCell(value) {
    // Prevent spreadsheet formula execution from free-form report text.
    let text = String(value ?? "");
    if (/^[\s]*[=+\-@]/.test(text)) text = "'" + text;
    return '"' + text.replaceAll('"', '""') + '"';
  }

  function exportAgingCsv() {
    if (!state.actor?.can_manage || !state.agingRows.length) return;
    const columns = [
      ["WO Number", "ticket"], ["Created", "opened_at"],
      ["Days Open", "days_open"], ["Priority", "urgency"],
      ["Description", "title"], ["Location", "location"],
      ["Assigned To", "owners"], ["Assignee Count", "assigned_n"],
      ["Active Record", "active"], ["Testing Repair ID", "test_id"],
      ["Review Flag", "review_flag"],
    ];
    const rows = [columns.map(([label]) => agingCsvCell(label)).join(",")];
    state.agingRows.forEach((row) => {
      rows.push(columns.map(([, field]) => agingCsvCell(row[field])).join(","));
    });
    const csv = "\ufeff" + rows.join("\r\n") + "\r\n";
    const url = URL.createObjectURL(new Blob([csv], {type:"text/csv;charset=utf-8"}));
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = "MSB_Open_Work_Order_Aging_Disposable.csv";
    document.body.append(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
  }

  function renderAgingReport(data) {
    const summary = $("aging-metrics");
    const buckets = data.buckets || {};
    const labels = [
      ["All open", data.count], ["0–7 days", buckets["0-7"]],
      ["8–30 days", buckets["8-30"]], ["31–60 days", buckets["31-60"]],
      ["61+ days", buckets["61+"]],
      ["Unassigned", data.unassigned_count],
      ["Inactive exceptions", data.inactive_count],
    ];
    summary.replaceChildren();
    for (const [label, value] of labels) {
      const item = document.createElement("div");
      const figure = document.createElement("strong");
      figure.textContent = String(value ?? 0);
      const name = document.createElement("span");
      name.textContent = label;
      item.append(figure, name);
      summary.appendChild(item);
    }
    summary.hidden = false;
    const table = $("aging-rows");
    table.replaceChildren();
    for (const row of state.agingRows) {
      const tr = document.createElement("tr");
      const cells = [
        null,
        row.opened_at ? new Date(row.opened_at).toLocaleDateString() : "Not recorded",
        row.days_open ?? "Unknown",
        row.urgency == null ? "Not set" : String(row.urgency),
        (row.title || "Untitled") + " · " + (row.location || "Location not recorded"),
        row.owners || "Unassigned",
        row.active ? "Open" : "Inactive / not completed",
      ];
      cells.forEach((value, index) => {
        const td = document.createElement("td");
        if (index === 0) {
          const button = document.createElement("button");
          button.type = "button";
          button.className = "aging-open-ticket";
          button.textContent = row.ticket || ("WO-" + row.wo_id);
          button.addEventListener("click", () => {
            $("scope").value = "all";
            scopeChanged();
            selectTicket(row.ticket);
          });
          td.appendChild(button);
        } else {
          td.textContent = String(value);
        }
        tr.appendChild(td);
      });
      table.appendChild(tr);
    }
    $("aging-export").disabled = !state.agingRows.length;
    $("aging-status").textContent =
      data.count + " recorded-open Work Orders · Created-date aging · " +
      "No row limit; all matching open records included" +
      ($("include-planning").checked ? " · Planning included" :
        " · Planning (priority 5) hidden") +
      (data.inactive_count ? " · Includes " + data.inactive_count +
        " inactive-but-undated exception(s)" : "");
  }

  async function loadAgingReport() {
    const serial = ++state.agingFetchId;
    if (!state.actor?.can_manage) {
      error("The Open Work Order Aging Report requires Manager permission.");
      return;
    }
    $("aging-status").textContent = "Loading all open Work Orders by creation date…";
    $("aging-export").disabled = true;
    const sort = $("ticket-sort").value;
    try {
      const response = await getJson("/api/work-orders/aging?sort=" +
        encodeURIComponent(sort) + "&include_planning=" +
        ($("include-planning").checked ? "1" : "0"));
      if (serial !== state.agingFetchId || $("scope").value !== "aging") return;
      state.agingRows = response.rows || [];
      renderAgingReport(response);
      error("");
    } catch (exc) {
      if (serial !== state.agingFetchId) return;
      state.agingRows = [];
      $("aging-rows").replaceChildren();
      $("aging-metrics").hidden = true;
      $("aging-export").disabled = true;
      $("aging-status").textContent = "Aging report unavailable.";
      error(exc.message);
    }
  }

  async function loadTickets() {
    const serial = ++state.listFetchId;
    const scope = $("scope").value;
    const aging = scope === "aging";
    $("aging-report").hidden = !aging;
    $("work-ticket-workspace").hidden = aging;
    $("show-completed").disabled = aging;
    $("ticket-search").disabled = aging;
    if (aging) {
      await loadAgingReport();
      return;
    }
    ++state.agingFetchId;
    const person = $("assignee").value;
    if (scope === "person" && !person) {
      state.tickets = [];
      renderList();
      return;
    }
    const params = new URLSearchParams({
      scope, q: $("ticket-search").value.trim(),
      show_completed: $("show-completed").checked ? "1" : "0",
      sort: $("ticket-sort").value,
    });
    if (scope === "person") params.set("person_id", person);
    try {
      error("");
      const response = await getJson("/api/work-orders/tickets?" + params);
      if (serial !== state.listFetchId) return;
      state.tickets = response.tickets || [];
      renderList();
    } catch (exc) {
      if (serial !== state.listFetchId) return;
      state.tickets = [];
      renderList();
      error(exc.message);
    }
  }

  function scopeChanged() {
    $("person-field").hidden = $("scope").value !== "person";
    if ($("scope").value === "aging") $("ticket-sort").value = "created_asc";
    resetDetail();
    writeNavigation("push");
    loadTickets();
  }

  function setText(id, value) {
    $(id).textContent = String(value ?? "");
  }

  function showDetail(row) {
    state.detail = row;
    $("detail-content").classList.remove("create-mode");
    const more = $("related-information");
    more.open = false;
    state.relatedLoadedFor = null;
    $("related-items").replaceChildren();
    setText("related-status", "Expand to load information related to the Stage.");
    $("detail-empty").hidden = true;
    $("detail-content").hidden = false;
    setText("detail-category", categoryLabel(row));
    setText("detail-ticket-id", row.ticket);
    setText("detail-title", row.title || "Untitled item");
    setText("detail-status", statusLabel(row));
    setText("detail-location", (row.location || "Location not recorded") +
      (row.urgency ? " · Urgency " + row.urgency : " · Urgency not recorded"));
    setText("detail-owner", row.owners || "Unassigned");
    setText("detail-reporter", row.reported_by || "Not recorded");
    setText("detail-source", row.source || "Not recorded");
    const detail = row.detail || {};
    setText("detail-description", detail.problem_raw || detail.problem || row.title);
    const extra = detail.notes_raw || detail.notes || "";
    $("detail-extra-note").hidden = !extra;
    setText("detail-extra-note", extra);
    document.dispatchEvent(new CustomEvent("wo419:ticket", { detail: row }));
  }

  async function loadActivity(key) {
    const list = $("ticket-activity-entries");
    const status = $("ticket-activity-status");
    list.replaceChildren();
    status.textContent = "Loading retained clone events…";
    try {
      const result = await getJson("/api/work-orders/tickets/" +
        encodeURIComponent(key) + "/activity");
      if (state.selected !== key) return;
      const events = result.activity || [];
      status.textContent = events.length ?
        events.length + " attributed event(s) · mail disabled / no send" :
        "No new clone action events recorded. Earlier Directus history is unchanged.";
      events.forEach((event) => {
        const box = document.createElement("div");
        box.className = "activity-entry";
        const top = document.createElement("strong");
        top.textContent = (event.event_kind || "Action").replaceAll("_", " ") +
          " · Person #" + (event.actor_person_id || "?");
        const date = document.createElement("small");
        date.textContent = event.created_at ? new Date(event.created_at).toLocaleString() : "";
        const note = document.createElement("p");
        note.textContent = event.note || "No additional notes";
        box.append(top, date, note);
        list.appendChild(box);
      });
    } catch (exc) {
      if (state.selected === key) status.textContent = exc.message;
    }
  }

  async function selectTicket(key) {
    if (!/^(WO|INTAKE)-[1-9]\d{0,12}$/.test(key || "")) return;
    state.selected = key;
    renderList();
    const serial = ++state.fetchId;
    try {
      error("");
      const data = await getJson("/api/work-orders/tickets/" + encodeURIComponent(key));
      if (serial !== state.fetchId || state.selected !== key) return;
      showDetail(data.ticket);
      if (!options.noHistory) writeNavigation("push");
      loadActivity(key);
    } catch (exc) {
      if (serial === state.fetchId) error(exc.message);
    }
  }

  function groupTitle(relation) {
    if (relation === "DIRECT_TASK") return "Directly linked to this task";
    if (relation === "SUBMITTED_CONTEXT") return "Captured with this report";
    if (relation === "STAGE_RELATED") return "Related to this Stage — not confirmed for this task";
    return "Other related information";
  }

  function safeLink(item) {
    // Only exact current MSB routes from known source identities may open.
    const match = String(item.url || "").match(
      /^\/(setup\/kit-inventory|scan\/DISP|scan\/CONT)\/([1-9]\d*)$/
    );
    if (!match) return "";
    const target = "https://my.sheboyganlights.org/" + match[1] + "/" + match[2];
    const label = match[1].startsWith("scan/") ? "Open asset ↗" : "Open Kit ↗";
    return '<a href="' + escapeHtml(target) +
      '" target="_blank" rel="noopener noreferrer" title="Opens existing protected MSB application in a new tab">' +
      label + '</a>';
  }

  function renderRelated(items) {
    const target = $("related-items");
    target.replaceChildren();
    const groups = new Map();
    items.forEach((item) => {
      const category = item.relation || "STAGE_RELATED";
      if (!groups.has(category)) groups.set(category, []);
      groups.get(category).push(item);
    });
    for (const [relation, all] of groups) {
      const panel = document.createElement("section");
      panel.className = "related-group";
      const heading = document.createElement("h5");
      heading.textContent = groupTitle(relation) + " · " + all.length;
      panel.appendChild(heading);
      const rows = document.createElement("div");
      panel.appendChild(rows);

      function display(showAll) {
        rows.innerHTML = all.slice(0, showAll ? all.length : 12).map((item) => (
          '<div class="related-row"><div>' +
          '<div class="name">' + escapeHtml(item.name) +
          ' <span class="ticket-id">' + escapeHtml(item.kind) + '</span></div>' +
          '<div class="source">' + escapeHtml(item.source || "") + '</div></div>' +
          safeLink(item) + '</div>'
        )).join("");
        if (!showAll && all.length > 12) {
          const button = document.createElement("button");
          button.className = "quiet-button";
          button.type = "button";
          button.textContent = "Show " + (all.length - 12) + " more";
          button.addEventListener("click", () => display(true));
          rows.appendChild(button);
        }
      }
      display(false);
      target.appendChild(panel);
    }
    if (items.length === 0) {
      target.textContent = "No current Stage resources were found in the clone. The original report is preserved.";
    }
  }

  async function loadRelated() {
    if (!$("related-information").open || !state.selected) return;
    const id = state.selected;
    if (state.relatedLoadedFor === id) return;
    setText("related-status", "Looking up current Stage resources…");
    try {
      const data = await getJson("/api/work-orders/tickets/" +
        encodeURIComponent(id) + "/related-information");
      if (state.selected !== id || !$("related-information").open) return;
      state.relatedLoadedFor = id;
      const related = data.related_information || {};
      renderRelated(related.groups || []);
      setText("related-status", related.stage_id
        ? "Stage " + related.stage_id + " · " + (related.notice || "Related references")
        : related.notice || "No Stage context recorded");
    } catch (exc) {
      if (state.selected === id) setText("related-status", exc.message);
    }
  }

  async function initialize() {
    try {
      const [access, people] = await Promise.all([
        getJson("/api/work-orders/access"),
        getJson("/api/work-orders/assignees"),
      ]);
      state.actor = access.access;
      $("home-heading").textContent = state.actor.can_manage
        ? "Work Management · Manager" : "My Work Orders";
      $("home-description").textContent = state.actor.can_manage
        ? "Manage repair assignments, urgent jobs, and pending Intake triage."
        : "Work and complete your assigned Work Orders, or create a new internal repair.";
      document.dispatchEvent(new CustomEvent("wo419:actor", {
        detail: { ...state.actor, csrf_token: access.csrf_token }
      }));
      document.querySelectorAll("#scope option[data-manager-only]").forEach((option) => {
        option.disabled = !state.actor.can_manage;
        option.hidden = !state.actor.can_manage;
      });
      state.assignees = people.assignees || [];
      setText("user-identity", state.actor.display_name || "Signed in");
      const picker = $("assignee");
      state.assignees.forEach((person) => {
        const option = document.createElement("option");
        option.value = String(person.person_id);
        option.textContent = person.display_name;
        picker.appendChild(option);
      });
      const initialView = initializeNavigation();
      await Promise.all([loadTickets(), loadManagerInbox()]);
      if (initialView.ticket) await selectTicket(initialView.ticket, {noHistory: true});
      else if (initialView.create && state.actor?.can_create) {
        state.restoringNavigation = true;
        try {
          state.createMode = true;
          document.dispatchEvent(new CustomEvent("wo419:history-create"));
        } finally {
          state.restoringNavigation = false;
        }
      }
    } catch (exc) {
      error(exc.message);
      setText("user-identity", "Access unavailable");
      setText("list-count", "Unable to load work");
    }
  }

  // Same MSB brand assets, local preference key and theme rule as Setup.
  const lightLogo = "https://webassets.sheboyganlights.org/images/branding/msb-blue-logo-600-plain.svg";
  const darkLogo = "https://webassets.sheboyganlights.org/images/branding/msb-white-logo-600-plain.svg";
  function applyTheme(value) {
    document.documentElement.dataset.theme = value;
    $("theme-toggle").textContent = value === "dark" ? "Light mode" : "Dark mode";
    $("screen-logo").src = value === "dark" ? darkLogo : lightLogo;
  }
  let savedTheme = null;
  try { savedTheme = localStorage.getItem("msb-theme"); } catch (_) { /* Storage optional. */ }
  applyTheme(savedTheme === "light" || savedTheme === "dark" ? savedTheme :
    (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"));
  $("theme-toggle").addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    applyTheme(next);
    try { localStorage.setItem("msb-theme", next); } catch (_) { /* Keep current theme. */ }
  });
  document.addEventListener("wo419:saved", async (event) => {
    const saved = event.detail || {};
    if (!saved.ticket) return;
    // Crew-created native WOs are intentionally unassigned. Show the
    // creator their new order without misrepresenting it as My Assigned Work.
    if (saved.action === "create" && !state.actor?.can_manage) {
      $("scope").value = "my-created";
      await loadTickets();
    } else if (state.actor?.can_manage && $("scope").value === "mine" &&
               !state.tickets.some(row => row.ticket === saved.ticket)) {
      $("scope").value = "all";
      scopeChanged();
    } else {
      await loadTickets();
    }
    await Promise.all([selectTicket(saved.ticket), loadManagerInbox()]);
  });
  document.addEventListener("wo419:open-create", () => {
    if (!state.actor?.can_create) return;
    writeNavigation("replace");
    state.selected = null;
    state.createMode = true;
    writeNavigation("push");
  });
  window.addEventListener("popstate", (event) => {
    if (event.state?.wo419) void restoreNavigation(event.state.wo419);
  });
  $("scope").addEventListener("change", scopeChanged);
  $("assignee").addEventListener("change", () => {
    writeNavigation("replace");
    loadTickets();
  });
  $("show-completed").addEventListener("change", () => {
    writeNavigation("replace");
    loadTickets();
  });
  $("include-planning").addEventListener("change", () => {
    writeNavigation("replace");
    loadTickets();
  });
  $("refresh").addEventListener("click", () =>
    Promise.all([loadTickets(), loadManagerInbox()]));
  $("ticket-sort").addEventListener("change", () => {
    writeNavigation("replace");
    loadTickets();
  });
  $("go-intake").addEventListener("click", () => goManagerQueue("intake"));
  $("go-feedback").addEventListener("click", () => goManagerQueue("feedback"));
  $("aging-export").addEventListener("click", exportAgingCsv);
  let searchTimer = null;
  $("ticket-search").addEventListener("input", () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      writeNavigation("replace");
      loadTickets();
    }, 240);
  });
  $("related-information").addEventListener("toggle", loadRelated);
  initialize();
})();
