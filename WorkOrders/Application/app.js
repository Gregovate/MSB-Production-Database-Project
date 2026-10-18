/* #419 disposable-only read browser. All ticket operations are GET. */
(() => {
  "use strict";
  const $ = (id) => document.getElementById(id);
  const state = {
    actor: null, tickets: [], assignees: [], selected: null,
    detail: null, relatedLoadedFor: null, fetchId: 0, listFetchId: 0,
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

  function error(message) {
    const box = $("page-error");
    box.textContent = message || "";
    box.hidden = !message;
  }

  function scopeLabel() {
    const scope = $("scope").value;
    if (scope === "mine") return "My Work";
    if (scope === "all") return "All Work Orders and Intake";
    const name = state.assignees.find((p) =>
      String(p.person_id) === $("assignee").value);
    return name ? "Assigned to " + name.display_name : "Choose a volunteer";
  }

  function statusLabel(row) {
    if (row.done_at) return "Completed (date recorded)";
    if (row.type !== "WORK_ORDER") return "Submitted — awaiting review";
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
        ($("scope").value === "mine"
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
        '<p class="card-meta">' + escapeHtml(loc) + '</p>' +
        '<div class="card-footer"><span>' +
        escapeHtml(row.owners || "Unassigned") + '</span><span class="status' +
        (row.done_at ? " done" : "") + '">' +
        escapeHtml(statusLabel(row)) + '</span></div></button>';
    }).join("");
    list.querySelectorAll(".ticket-card").forEach((button) => {
      button.addEventListener("click", () => selectTicket(button.dataset.ticket));
    });
  }

  async function loadTickets() {
    const serial = ++state.listFetchId;
    const scope = $("scope").value;
    const person = $("assignee").value;
    if (scope === "person" && !person) {
      state.tickets = [];
      renderList();
      return;
    }
    const params = new URLSearchParams({
      scope, q: $("ticket-search").value.trim(),
      show_completed: $("show-completed").checked ? "1" : "0",
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
    loadTickets();
  }

  function setText(id, value) {
    $(id).textContent = String(value ?? "");
  }

  function showDetail(row) {
    state.detail = row;
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
    setText("detail-location", row.location || "Location not recorded");
    setText("detail-owner", row.owners || "Unassigned");
    setText("detail-reporter", row.reported_by || "Not recorded");
    setText("detail-source", row.source || "Not recorded");
    const detail = row.detail || {};
    setText("detail-description", detail.problem_raw || detail.problem || row.title);
    const extra = detail.notes_raw || detail.notes || "";
    $("detail-extra-note").hidden = !extra;
    setText("detail-extra-note", extra);
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
    const match = String(item.url || "").match(/^\/setup\/kit-inventory\/([1-9]\d*)$/);
    if (!match) return "";
    const target = "https://my.sheboyganlights.org/setup/kit-inventory/" + match[1];
    return '<a href="' + escapeHtml(target) +
      '" target="_blank" rel="noopener noreferrer" title="Opens existing MSB Setup in a new tab">Open in Setup ↗</a>';
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
      state.assignees = people.assignees || [];
      setText("user-identity", state.actor.display_name || "Signed in");
      const picker = $("assignee");
      state.assignees.forEach((person) => {
        const option = document.createElement("option");
        option.value = String(person.person_id);
        option.textContent = person.display_name;
        picker.appendChild(option);
      });
      await loadTickets();
    } catch (exc) {
      error(exc.message);
      setText("user-identity", "Access unavailable");
      setText("list-count", "Unable to load work");
    }
  }

  $("scope").addEventListener("change", scopeChanged);
  $("assignee").addEventListener("change", loadTickets);
  $("show-completed").addEventListener("change", loadTickets);
  $("refresh").addEventListener("click", loadTickets);
  let searchTimer = null;
  $("ticket-search").addEventListener("input", () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(loadTickets, 240);
  });
  $("related-information").addEventListener("toggle", loadRelated);
  initialize();
})();
