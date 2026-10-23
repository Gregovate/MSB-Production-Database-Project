/* Crew circuit capture. All facts and identities come from the PostgreSQL API.
 * Text uses textContent; server/DB own authorization, revisions and audit actors. */
"use strict";
(() => {
  const $ = (id) => document.getElementById(id);
  const keys = {
    panel: "site_panel_id",
    circuit: "site_power_circuit_id",
    device: "site_power_device_id",
    feed: "site_power_feed_id",
    network: "site_waypoint_network_id",
    action: "site_power_action_id",
  };
  let data,
    panelId = null,
    edit = null,
    pending = null,
    loading = false;
  function el(tag, text, parent) {
    const n = document.createElement(tag);
    if (text !== undefined) n.textContent = text;
    if (parent) parent.append(n);
    return n;
  }
  function button(text, action, parent, write = false) {
    const n = el("button", text, parent);
    n.type = "button";
    n.disabled = write && !data?.access?.can_edit;
    n.onclick = action;
    return n;
  }
  const wp = (id) => data.waypoints.find((w) => w.id === Number(id));
  const panel = (id) => data.panels.find((p) => p.site_panel_id === Number(id));
  const circuit = (id) =>
    data.circuits.find((c) => c.site_power_circuit_id === Number(id));
  const device = (id) =>
    data.devices.find((d) => d.site_power_device_id === Number(id));
  const circuitName = (id) => {
    const c = circuit(id);
    return c
      ? `${panel(c.site_panel_id)?.panel_name || "Unknown panel"} / ${c.circuit_code}`
      : "Unknown circuit";
  };
  const deviceName = (id) => device(id)?.device_name || "Unknown equipment";
  const waypointName = (id) => wp(id)?.name || "Unknown waypoint";
  const feedName = (f) =>
    `${f.source_circuit_id ? circuitName(f.source_circuit_id) : deviceName(f.source_device_id)} → ${f.destination_waypoint_id ? waypointName(f.destination_waypoint_id) : deviceName(f.destination_device_id)}`;
  function stamp(r, p) {
    el(
      "p",
      `${r.active ? "Active" : "Retired"} · ${r.verification_status} · ${r.source_evidence}`,
      p,
    );
    if (r.verified_at)
      el(
        "p",
        `Reference verification: person ${r.verified_by_person_id} · ${r.verified_at}`,
        p,
      );
  }
  // Follow only stored active feed edges, preserving every path and its uncertainty.
  function paths(circuitId) {
    const result = [];
    const walk = (feeds, chain, seen) =>
      feeds.forEach((f) => {
        if (!f.active) return;
        const next = [...chain, f];
        if (f.destination_waypoint_id)
          result.push({ waypoint: wp(f.destination_waypoint_id), chain: next });
        else if (!seen.has(f.destination_device_id)) {
          const visit = new Set(seen);
          visit.add(f.destination_device_id);
          walk(
            data.feeds.filter(
              (e) => e.source_device_id === f.destination_device_id,
            ),
            next,
            visit,
          );
        }
      });
    walk(
      data.feeds.filter((f) => f.source_circuit_id === circuitId),
      [],
      new Set(),
    );
    return result;
  }
  async function api(url, options) {
    const response = await fetch(url, options);
    let body;
    try {
      body = await response.json();
    } catch {
      throw new Error(
        "No readable server response. The save outcome is unknown; retry the same save or reload records.",
      );
    }
    if (!response.ok) {
      const e = new Error(body.error || "Request failed");
      e.status = response.status;
      throw e;
    }
    return body;
  }
  async function load() {
    if (loading) return;
    loading = true;
    $("status").textContent = "Loading current records…";
    try {
      data = await api("api/power");
      render();
      $("status").textContent =
        `${data.access.display_name} · ${data.access.can_edit ? "Production Crew editing available" : "Read only"} · Revision ${data.revision}`;
      $("status").dataset.error = "false";
    } catch (e) {
      $("status").textContent = e.message;
      $("status").dataset.error = "true";
    } finally {
      loading = false;
    }
  }
  function record(parent, title, r, kind) {
    const box = el("div", undefined, parent);
    box.className = "power-record";
    el("h3", title, box);
    stamp(r, box);
    button("Edit / correct", () => open(kind, r), box, true);
    return box;
  }
  function render() {
    const q = $("find").value.trim().toLowerCase();
    $("panels").replaceChildren();
    data.panels
      .filter(
        (p) =>
          !q ||
          [
            p.panel_name,
            p.panel_identification,
            wp(p.site_waypoint_id)?.name,
            ...(wp(p.site_waypoint_id)?.aliases || []),
            ...data.circuits
              .filter((c) => c.site_panel_id === p.site_panel_id)
              .flatMap((c) =>
                paths(c.site_power_circuit_id).flatMap((x) => [
                  x.waypoint?.name,
                  ...(x.waypoint?.aliases || []),
                ]),
              ),
          ].some((s) =>
            String(s || "")
              .toLowerCase()
              .includes(q),
          ),
      )
      .forEach((p) => {
        const b = button(
          `${p.panel_name}${p.active ? "" : " (retired)"}`,
          () => {
            panelId = p.site_panel_id;
            render();
          },
          $("panels"),
        );
        b.className = p.site_panel_id === panelId ? "power-selected" : "";
      });
    const selected = panel(panelId),
      detail = $("panel-detail");
    detail.replaceChildren();
    if (selected) {
      const box = record(detail, selected.panel_name, selected, "panel");
      el(
        "p",
        `Location: ${selected.site_waypoint_id ? waypointName(selected.site_waypoint_id) : "Unknown"} · Owner: ${selected.owner_name || "Unknown"}`,
        box,
      );
      el(
        "p",
        `Identification: ${selected.panel_identification || "Unknown"} · Meter information: ${selected.meter_information || "Unknown"}`,
        box,
      );
      button(
        "Add circuit",
        () => open("circuit", { site_panel_id: panelId }),
        box,
        true,
      );
      data.circuits
        .filter((c) => c.site_panel_id === panelId)
        .forEach((c) => {
          const row = record(
            detail,
            `Circuit ${c.circuit_code} — ${c.description || "No description"}`,
            c,
            "circuit",
          );
          el(
            "p",
            `Rating: ${c.breaker_rating_amps ?? "Unknown"} A · Show desired: ${c.show_desired_state} · Restoration desired: ${c.restoration_desired_state}`,
            row,
          );
          const assigned = paths(c.site_power_circuit_id);
          if (!assigned.length)
            el("p", "No supplying relationships recorded.", row);
          assigned.forEach((x) =>
            el(
              "p",
              `${x.waypoint?.name || "Unknown waypoint"} · ${x.chain.map(feedName).join(" / ")} · ${x.chain.map((f) => f.verification_status).join(" / ")}`,
              row,
            ),
          );
          button(
            "Assign multiple waypoints",
            () => openAssignments(c),
            row,
            true,
          );
        });
    } else
      el(
        "p",
        "Select a panel to retrieve its circuits and assignments.",
        detail,
      );
    $("equipment").replaceChildren();
    data.devices.forEach((d) =>
      record(
        $("equipment"),
        `${d.device_name} · ${d.device_kind}`,
        d,
        "device",
      ),
    );
    $("feeds").replaceChildren();
    data.feeds.forEach((f) => record($("feeds"), feedName(f), f, "feed"));
    $("networks").replaceChildren();
    data.networks.forEach((n) =>
      record(
        $("networks"),
        `${waypointName(n.site_waypoint_id)} · ${data.network_options.find((o) => o.site_network_id === n.site_network_id)?.network_code || "Unknown network"}`,
        n,
        "network",
      ),
    );
    const year = $("season").value;
    $("season").replaceChildren();
    data.seasons.forEach((y) => {
      const o = el("option", y, $("season"));
      o.value = y;
    });
    if (data.seasons.includes(Number(year))) $("season").value = year;
    renderActions();
    $("history").replaceChildren();
    data.history.slice(0, 100).forEach((h) => {
      const d = el("details", undefined, $("history"));
      el(
        "summary",
        `${h.recorded_at} · ${h.operator_email} · ${h.command} #${h.target_id}`,
        d,
      );
      el(
        "pre",
        JSON.stringify({ before: h.before_data, after: h.after_data }, null, 2),
        d,
      );
    });
    [
      "add-panel",
      "add-device",
      "add-feed",
      "add-network",
      "add-action",
    ].forEach((id) => ($(id).disabled = !data.access.can_edit));
  }
  function renderActions() {
    const root = $("actions");
    root.replaceChildren();
    const q = $("action-search").value.toLowerCase();
    data.actions.forEach((a) => {
      const target = a.site_power_circuit_id
        ? circuitName(a.site_power_circuit_id)
        : deviceName(a.site_power_device_id);
      const waypointNames = a.site_power_circuit_id
        ? paths(a.site_power_circuit_id)
            .map((x) => x.waypoint?.name)
            .join(" ")
        : waypointName(device(a.site_power_device_id)?.site_waypoint_id);
      if (
        q &&
        !`${a.action_name} ${target} ${waypointNames} ${a.responsible_party || ""} ${a.phase}`
          .toLowerCase()
          .includes(q)
      )
        return;
      const r = record(root, `${a.action_name} · ${target}`, a, "action");
      el(
        "p",
        `${a.phase} · Desired: ${a.desired_state} · Responsible: ${a.responsible_party || "Unknown"}`,
        r,
      );
      el("p", a.instructions || "Instructions not recorded", r);
      el(
        "p",
        `Prerequisites: ${a.prerequisite_action_ids.map((id) => data.actions.find((x) => x.site_power_action_id === id)?.action_name || id).join(", ") || "None recorded"}`,
        r,
      );
      button(
        "Record seasonal activity / condition",
        () =>
          open("event", {
            site_power_action_id: a.site_power_action_id,
            season_year: Number($("season").value),
          }),
        r,
        true,
      );
      data.events
        .filter(
          (e) =>
            e.site_power_action_id === a.site_power_action_id &&
            e.season_year === Number($("season").value),
        )
        .forEach((e) => {
          el(
            "p",
            `${e.observed_at} · ${e.event_kind} · ${e.condition} · ${e.operator_email} · ${e.evidence}${e.corrects_event_id ? ` · corrects event ${e.corrects_event_id}` : ""}${data.events.some((c) => c.corrects_event_id === e.event_id) ? " · CORRECTED" : ""}`,
            r,
          );
          button(
            "Correct this event",
            () =>
              open("event", {
                site_power_action_id: a.site_power_action_id,
                season_year: e.season_year,
                corrects_event_id: e.event_id,
              }),
            r,
            true,
          );
        });
    });
  }
  const text = (key, label, required = false) => ({
    key,
    label,
    type: "text",
    required,
  });
  const select = (key, label, options, required = false) => ({
    key,
    label,
    type: "select",
    options,
    required,
  });
  const options = (items) => items.map(([value, label]) => ({ value, label }));
  function specs(kind) {
    const waypoints = options(
      data.waypoints.map((w) => [w.id, `${w.name} (${w.type})`]),
    );
    const circuits = options(
      data.circuits.map((c) => [
        c.site_power_circuit_id,
        circuitName(c.site_power_circuit_id),
      ]),
    );
    const devices = options(
      data.devices.map((d) => [d.site_power_device_id, d.device_name]),
    );
    const choose = (key, label, values, required = true) =>
      select(key, label, options(values.map((v) => [v, v])), required);
    const fields = {
      panel: [
        text("panel_name", "Readable panel name", true),
        text("panel_identification", "Panel identification / label"),
        select("site_waypoint_id", "Associated waypoint (optional)", waypoints),
        text("owner_name", "Equipment owner"),
        text(
          "meter_information",
          "Known meter identifier(s) / relationship notes",
        ),
      ],
      circuit: [
        select(
          "site_panel_id",
          "Panel",
          options(data.panels.map((p) => [p.site_panel_id, p.panel_name])),
          true,
        ),
        text("circuit_code", "Breaker / circuit designation", true),
        text("description", "Description"),
        {
          ...text("breaker_rating_amps", "Breaker rating (amps)"),
          type: "number",
        },
        { ...text("voltage", "Voltage"), type: "number" },
        { ...text("poles", "Pole count"), type: "number" },
        text("ganged_device", "Ganged device information"),
        choose("show_desired_state", "Show season desired state", [
          "UNKNOWN",
          "ON",
          "OFF",
        ]),
        choose(
          "restoration_desired_state",
          "Off-season / restoration desired state",
          ["UNKNOWN", "ON", "OFF"],
        ),
      ],
      device: [
        text("device_name", "Equipment name / identification", true),
        choose("device_kind", "Equipment type", [
          "FUSE",
          "DISCONNECT",
          "OUTLET",
          "LIGHT_POLE",
          "OTHER",
        ]),
        select("site_waypoint_id", "Waypoint (optional)", waypoints),
        text("owner_name", "Equipment owner"),
        text("utility_asset_id", "Utility asset identification"),
        text("rating", "Known rating"),
        text("description", "Description"),
      ],
      feed: [
        select(
          "source_circuit_id",
          "From circuit (choose circuit OR equipment)",
          circuits,
        ),
        select("source_device_id", "From equipment", devices),
        select(
          "destination_waypoint_id",
          "To waypoint (choose waypoint OR equipment)",
          waypoints,
        ),
        select("destination_device_id", "To equipment", devices),
      ],
      network: [
        select("site_waypoint_id", "Waypoint", waypoints, true),
        select(
          "site_network_id",
          "Network",
          options(
            data.network_options.map((n) => [
              n.site_network_id,
              n.network_code,
            ]),
          ),
          true,
        ),
      ],
      action: [
        text("action_name", "Activity name", true),
        select(
          "site_power_circuit_id",
          "Affected circuit (choose circuit OR equipment)",
          circuits,
        ),
        select("site_power_device_id", "Affected equipment", devices),
        choose("phase", "Seasonal phase", [
          "SETUP",
          "OPERATION",
          "RESTORATION",
        ]),
        choose("action_kind", "Activity", [
          "TURN_OFF_LIGHT",
          "REMOVE_FUSE",
          "REQUEST_UTILITY",
          "ENERGIZE",
          "RESTORE",
          "OTHER",
        ]),
        choose("desired_state", "Desired state", [
          "UNKNOWN",
          "ON",
          "OFF",
          "REMOVED",
          "INSTALLED",
        ]),
        text("responsible_party", "Responsible party"),
        text("instructions", "Instructions / procedure link"),
        {
          ...select(
            "prerequisite_action_ids",
            "Prerequisite activities",
            options(
              data.actions.map((a) => [a.site_power_action_id, a.action_name]),
            ),
          ),
          multiple: true,
        },
      ],
      event: [
        select(
          "site_power_action_id",
          "Activity",
          options(
            data.actions.map((a) => [a.site_power_action_id, a.action_name]),
          ),
          true,
        ),
        choose("season_year", "Season", data.seasons),
        choose("event_kind", "Evidence type", [
          "REPORTED",
          "FIELD_VERIFIED",
          "STARTED",
          "COMPLETED",
          "UTILITY_REQUESTED",
          "UTILITY_CONFIRMED",
          "EXCEPTION",
        ]),
        choose("condition", "Condition recorded by this event", [
          "UNKNOWN",
          "ON",
          "OFF",
          "REMOVED",
          "INSTALLED",
          "NOT_APPLICABLE",
        ]),
        {
          key: "observed_at",
          label: "When observed (your local time)",
          type: "datetime-local",
          required: true,
        },
        text("evidence", "Observation / supporting evidence", true),
        {
          ...text("corrects_event_id", "Corrects event ID (optional)"),
          type: "number",
        },
      ],
    };
    return fields[kind].concat(
      kind === "event"
        ? []
        : [
            {
              key: "active",
              label: "Active record (clear to retire)",
              type: "checkbox",
            },
            choose(
              "verification_status",
              "Reference verification (explicitly select)",
              ["UNKNOWN", "UNVERIFIED", "VERIFIED", "CONFLICTING"],
            ),
            text(
              "source_evidence",
              "Source / verification evidence / correction reason",
              true,
            ),
          ],
    );
  }
  function field(spec, value) {
    const label = el("label", spec.label, $("edit-fields"));
    const n = el(spec.type === "select" ? "select" : "input", undefined, label);
    n.name = spec.key;
    n.required = !!spec.required;
    if (spec.type === "select") {
      n.multiple = !!spec.multiple;
      if (!spec.required && !spec.multiple) {
        const o = el("option", "Unknown / not specified", n);
        o.value = "";
      }
      spec.options.forEach((x) => {
        const o = el("option", x.label, n);
        o.value = x.value;
        o.selected = spec.multiple
          ? (value || []).includes(Number(x.value))
          : String(value) === String(x.value);
      });
    } else {
      n.type = spec.type;
      if (spec.type === "checkbox") n.checked = value !== false;
      else n.value = value ?? "";
      if (spec.type === "number") {
        n.min = "0.000001";
        n.step = spec.key === "poles" ? "1" : "any";
      }
    }
    return n;
  }
  function open(kind, row = {}) {
    if (!data.access.can_edit) return;
    pending = null;
    edit = { kind, row, specs: specs(kind) };
    $("edit-title").textContent =
      kind === "event"
        ? "Record seasonal evidence"
        : `${row[keys[kind]] ? "Correct" : "Define"} ${kind}`;
    $("edit-fields").replaceChildren();
    $("save-status").textContent = "";
    $("save").disabled = false;
    edit.specs.forEach((s) =>
      field(
        s,
        s.key === "verification_status"
          ? "UNVERIFIED"
          : (row[s.key] ??
              (s.key.includes("desired_state") ? "UNKNOWN" : undefined)),
      ),
    );
    $("editor").showModal();
  }
  function openAssignments(c) {
    pending = null;
    edit = { kind: "assignments", row: c };
    $("edit-title").textContent =
      `Waypoints supplied directly by ${circuitName(c.site_power_circuit_id)}`;
    $("edit-fields").replaceChildren();
    $("save-status").textContent = "";
    $("save").disabled = false;
    el(
      "p",
      "Intermediate feed paths remain unchanged. Clear a selection to retire that direct relationship; its history is retained.",
      $("edit-fields"),
    );
    const search = field(
      text("waypoint_search", "Search current names and aliases"),
      "",
    );
    const list = el("div", undefined, $("edit-fields"));
    list.className = "power-choices";
    const direct = data.feeds.filter(
      (f) =>
        f.active &&
        f.source_circuit_id === c.site_power_circuit_id &&
        f.destination_waypoint_id,
    );
    data.waypoints.forEach((w) => {
      const l = el("label", undefined, list),
        i = el("input", undefined, l);
      i.type = "checkbox";
      i.name = "waypoint";
      i.value = w.id;
      i.checked = direct.some((f) => f.destination_waypoint_id === w.id);
      l.append(
        document.createTextNode(
          ` ${w.name} (${w.type})${w.aliases.length ? " · " + w.aliases.join(", ") : ""}`,
        ),
      );
      l.dataset.search = [w.name, ...w.aliases].join(" ").toLowerCase();
    });
    search.oninput = () => {
      for (const l of list.children)
        l.hidden = !l.dataset.search.includes(search.value.toLowerCase());
    };
    field(
      select(
        "verification_status",
        "Assignment verification",
        options(
          ["UNKNOWN", "UNVERIFIED", "VERIFIED", "CONFLICTING"].map((x) => [
            x,
            x,
          ]),
        ),
        true,
      ),
      "UNVERIFIED",
    );
    field(text("source_evidence", "Source / correction evidence", true), "");
    $("editor").showModal();
  }
  function readFields() {
    const result = {};
    for (const s of edit.specs) {
      const n = $("edit-form").elements.namedItem(s.key);
      let v = s.multiple
        ? Array.from(n.selectedOptions, (o) => Number(o.value))
        : s.type === "checkbox"
          ? n.checked
          : n.value.trim();
      if (!s.multiple && s.type !== "checkbox") {
        if (!v) v = null;
        else if (
          s.type === "number" ||
          s.key.endsWith("_id") ||
          s.key === "season_year"
        )
          v = Number(v);
        else if (s.type === "datetime-local") v = new Date(v).toISOString();
      }
      result[s.key] = v;
    }
    return result;
  }
  function command(kind, id, fields) {
    return { kind, id: id ?? null, fields, request_id: crypto.randomUUID() };
  }
  $("edit-form").onsubmit = async (event) => {
    event.preventDefault();
    if (!pending) {
      let commands;
      if (edit.kind === "assignments") {
        const form = $("edit-form"),
          selected = Array.from(
            form.querySelectorAll("input[name=waypoint]:checked"),
            (i) => Number(i.value),
          );
        const direct = data.feeds.filter(
          (f) =>
            f.active &&
            f.source_circuit_id === edit.row.site_power_circuit_id &&
            f.destination_waypoint_id,
        );
        const evidence = {
          source_evidence: form.elements.source_evidence.value.trim(),
          verification_status: form.elements.verification_status.value,
        };
        commands = direct
          .filter((f) => !selected.includes(f.destination_waypoint_id))
          .map((f) =>
            command("feed", f.site_power_feed_id, {
              ...evidence,
              active: false,
            }),
          );
        selected.forEach((id) => {
          const old = direct.find((f) => f.destination_waypoint_id === id);
          commands.push(
            command("feed", old?.site_power_feed_id, {
              ...evidence,
              source_circuit_id: edit.row.site_power_circuit_id,
              destination_waypoint_id: id,
            }),
          );
        });
      } else
        commands = [
          command(edit.kind, edit.row[keys[edit.kind]], readFields()),
        ];
      if (!commands.length) {
        $("save-status").textContent = "No assignment changes selected.";
        return;
      }
      pending = { revision: data.revision, commands };
    }
    $("save").disabled = true;
    $("save-status").textContent = "Saving…";
    try {
      await api("api/power/commands", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-MSB-Power-Command": "1",
        },
        body: JSON.stringify(pending),
      });
      pending = null;
      $("editor").close();
      await load();
    } catch (e) {
      $("save-status").textContent = e.message;
      if (e.status && e.status < 500) {
        pending = null;
      } else {
        $("save-status").textContent +=
          " Retry Save resends the same request safely. Close and reload to inspect current records.";
        for (const n of $("edit-fields").querySelectorAll("input,select"))
          n.disabled = true;
      }
    } finally {
      $("save").disabled = false;
    }
  };
  $("cancel").onclick = () => {
    if (confirm("Close this edit? Unsaved changes will be discarded.")) {
      $("editor").close();
      pending = null;
    }
  };
  $("editor").addEventListener("cancel", (e) => {
    e.preventDefault();
    $("cancel").click();
  });
  $("reload").onclick = load;
  $("find").oninput = () => data && render();
  $("season").onchange = renderActions;
  $("action-search").oninput = () => data && renderActions();
  for (const kind of ["panel", "device", "feed", "network", "action"])
    $(`add-${kind}`).onclick = () => open(kind);
  // Expose pure relationship resolution only to the isolated browser harness.
  window.MSBPowerCapture = { paths };
  load();
})();
