/* Crew circuit capture. All facts and identities come from the PostgreSQL API.
 * Text uses textContent; server/DB own authorization, revisions and audit actors. */
"use strict";
(() => {
  const $ = (id) => document.getElementById(id);
  // Reuse the FieldWiring preference; no separate theme authority for this page.
  function setTheme(theme) {
    document.documentElement.dataset.theme = theme;
    $("theme-toggle").textContent = theme === "dark" ? "Light mode" : "Dark mode";
    try { localStorage.setItem("msb-theme", theme); } catch (_) { /* Theme still works without storage. */ }
  }
  let savedTheme;
  try { savedTheme = localStorage.getItem("msb-theme"); } catch (_) { /* Use OS preference. */ }
  setTheme(["light", "dark"].includes(savedTheme) ? savedTheme :
    (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"));
  $("theme-toggle").onclick = () => setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
  const keys = {
    controller_power_connection: "site_controller_power_connection_id",
    controller_installation: "site_controller_installation_id",
    panel: "site_panel_id",
    breaker: "site_power_breaker_id",
    cable_spec: "site_power_cable_spec_id",
    conductor: "site_power_conductor_id",
    conductor_circuit: "site_power_conductor_circuit_id",
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
      `${r.active ? "Active" : "Retired"} · ${r.verification_status || "UNVERIFIED"}${r.source_evidence ? " · " + r.source_evidence : ""}`,
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
          const d = device(f.destination_device_id);
          if (d?.site_waypoint_id) result.push({waypoint: wp(d.site_waypoint_id), chain: next});
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
    button("Edit / correct", () => kind === "breaker" ? openSchedule(r) : open(kind, r), box, true);
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
      const board = el("section", undefined, detail); board.className = "power-panelboard";
      el("h3", "Panel schedule", board);
      el("p", "Odd positions left, even positions right. Select a circuit to assign its supplied waypoints. Verify installed numbering.", board);
      const main = el("div", undefined, board); main.className = "power-main";
      el("h4", "Main disconnect", main);
      const breakers = (data.breakers || []).filter(b => b.site_panel_id === panelId && b.active);
      const drawBreaker = (b, parent) => {
        const row = el("div", undefined, parent); row.className="power-record power-breaker";
        row.dataset.breakerId=b.site_power_breaker_id;
        el("h3", `Breaker ${b.breaker_name}`, row);
        el("p", `${b.rated_amps ?? "Unknown"} A · ${b.pole_count ?? "Unknown"} poles · ${b.breaker_role || "UNKNOWN"}`, row);
        button("Breaker settings",()=>openSchedule(b),row,true);
        const circuits = data.circuits.filter(c => c.active && c.site_power_breaker_id === b.site_power_breaker_id)
          .sort((a,b)=>a.breaker_pole-b.breaker_pole);
        circuits.forEach(c => {
          const names=[...new Set(paths(c.site_power_circuit_id).map(x=>x.waypoint?.name || "Unknown waypoint"))];
          const leg=button(`Circuit ${c.circuit_code} — ${names.join(", ") || "Assign waypoints"}`,()=>openAssignments(c),row,true);
          leg.className="power-circuit-leg"; leg.dataset.circuitId=c.site_power_circuit_id;
        });
        el("p", `Season: ${b.show_desired_state} · Non-season: ${b.restoration_desired_state}`, row);
        const impact = (data.breaker_impacts || []).find(x => x.breaker.site_power_breaker_id === b.site_power_breaker_id);
        const details = el("details", undefined, row);
        el("summary", "Recorded affected endpoints — not verified isolation", details);
        if (impact?.missing_pole_membership) el("p", "Incomplete breaker/circuit membership", details);
        (impact?.paths || []).forEach(x => el("p", `${circuitName(x.site_power_circuit_id)} · ${x.waypoint_name || "Unknown waypoint"} · ${x.destination_device_id ? deviceName(x.destination_device_id) : "Receptacle unspecified"}`, details));
        (impact?.controller_connections || []).forEach(x=>el("p",`Plugged-in controller ${x.controller_id} · ${waypointName(x.site_waypoint_id)} · ${circuitName(x.site_power_circuit_id)}`,details));
        return row;
      };
      el("p", `Meter: ${selected.meter_information || "Not recorded"}`, main);
      const supply = data.breakers.find(b=>b.site_power_breaker_id===selected.supply_breaker_id);
      if (supply) el("p", `Remote main / supply: ${panel(supply.site_panel_id)?.panel_name} — ${supply.breaker_name}`, main);
      button("Meter / upstream supply",()=>openSupply(selected),main,true);
      const mains = breakers.filter(b => b.breaker_role === "MAIN");
      mains.forEach(b => drawBreaker(b,main));
      if (!mains.length && !selected.supply_breaker_id) {
        el("p", "Main breaker not recorded; rating unknown", main);
        button("Record main breaker",()=>openSchedule({site_panel_id:panelId,breaker_role:"MAIN"}),main,true);
      }
      button("Add branch breaker",()=>openSchedule({site_panel_id:panelId,breaker_role:"BRANCH"}),board,true);
      const schedule = el("div",undefined,board); schedule.className="power-slot-grid";
      const positioned = breakers.filter(b=>b.breaker_role!=="MAIN" && b.panel_positions?.length);
      const conventional=b=>b.panel_positions.every((p,i)=>p===b.panel_positions[0]+2*i);
      const last = Math.max(36,...positioned.flatMap(b=>b.panel_positions));
      for (let pos=1;pos<=last+(last%2);pos++) {
        const breaker=positioned.find(b=>b.panel_positions.includes(pos));
        if (breaker && (!conventional(breaker) || breaker.panel_positions[0]!==pos)) continue;
        const cell=el("div",undefined,schedule); cell.className="power-slot";
        cell.style.gridColumn=pos%2 ? "1" : "2";
        cell.style.gridRow=`${Math.ceil(pos/2)} / span ${breaker?.panel_positions.length || 1}`;
        if (breaker) {
          el("strong",`Positions ${breaker.panel_positions.join(" / ")}`,cell);
          drawBreaker(breaker,cell);
        } else button(`Position ${pos} · Add breaker`,()=>openSchedule({site_panel_id:panelId,breaker_role:"BRANCH",panel_positions:[pos],pole_count:1}),cell,true);
      }
      const unplaced=el("details",undefined,board);
      el("summary","Unknown or nonstandard positions — reconcile",unplaced);
      breakers.filter(b=>b.breaker_role!=="MAIN" && (!b.panel_positions?.length || !conventional(b))).forEach(b=>drawBreaker(b,unplaced));
      const legacy=el("details",undefined,detail);
      el("summary","Reconcile circuits with unknown breaker membership",legacy);
      button("Reconcile legacy circuit",()=>open("circuit",{site_panel_id:panelId}),legacy,true);
      data.circuits
        .filter((c) => c.site_panel_id === panelId && !c.site_power_breaker_id)
        .forEach((c) => {
          const row = record(
            legacy,
            `Circuit ${c.circuit_code} — ${c.description || "No description"}`,
            c,
            "circuit",
          );
          el(
            "p",
            `Rating: ${data.breakers?.find(b => b.site_power_breaker_id === c.site_power_breaker_id)?.rated_amps ?? "Unknown"} A · Show desired: ${c.show_desired_state} · Restoration desired: ${c.restoration_desired_state}`,
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
    const waypointSelect = $("detail-waypoint"), priorWaypoint = waypointSelect.value;
    waypointSelect.replaceChildren();
    el("option", "Select a waypoint", waypointSelect).value="";
    data.waypoints.forEach(w=>{const o=el("option",`${w.name} (${w.type})`,waypointSelect);o.value=w.id;});
    waypointSelect.value=priorWaypoint;
    const detailWaypoint=Number(priorWaypoint);
    const combo=wp(detailWaypoint)?.type?.trim().toLowerCase()==="out-combo";
    $("combo-network-box").hidden=!combo;
    $("waypoint-supply").replaceChildren();
    data.circuits.filter(c=>c.active && paths(c.site_power_circuit_id).some(x=>x.waypoint?.id===detailWaypoint))
      .forEach(c=>button(circuitName(c.site_power_circuit_id),()=>openAssignments(c),$("waypoint-supply"),true));
    if (detailWaypoint) {
      const label=el("label","Assign supplying circuit",$("waypoint-supply")), select=el("select",undefined,label);
      el("option","Select panel / circuit",select).value="";
      data.circuits.filter(c=>c.active).forEach(c=>{el("option",circuitName(c.site_power_circuit_id),select).value=c.site_power_circuit_id;});
      select.onchange=()=>{if(select.value) openAssignments(circuit(Number(select.value)));};
    }
    const powerOutlet=["power","out-power","out-combo"].includes(wp(detailWaypoint)?.type?.trim().toLowerCase());
    $("outlet-controllers").hidden=!powerOutlet;
    $("plugged-controllers").replaceChildren();
    (data.controller_power_connections || []).filter(i=>i.site_waypoint_id===detailWaypoint).forEach(i=>{
      const asset=data.controller_options.find(c=>c.id===i.controller_id);
      record($("plugged-controllers"),`Controller ${i.controller_id} · ${asset?.model || "Unknown model"} · ${circuitName(i.site_power_circuit_id)}`,i,"controller_power_connection");
    });
    $("equipment").replaceChildren();
    (data.controller_installations || []).filter(i=>i.site_waypoint_id===detailWaypoint).forEach(i=>{
      const asset=data.controller_options.find(c=>c.id===i.controller_id);
      record($("equipment"),`Controller ${i.controller_id} · ${asset?.model || "Unknown model"} · ${asset?.serial || "No serial recorded"}`,i,"controller_installation");
    });
    $("conductor-detail").replaceChildren();
    ["cable_spec", "conductor", "conductor_circuit"].forEach(kind => {
      button(`Add ${kind.replaceAll("_", " ")}`, () => open(kind, {}), $("conductor-detail"), true);
      (data[kind + "s"] || []).forEach(r => record($("conductor-detail"),
        r.cable_specification || r.conductor_label || `Conductor ${r.site_power_conductor_id} / ${circuitName(r.site_power_circuit_id)}`, r, kind));
    });
    $("feeds").replaceChildren();
    data.feeds.filter(f=>f.destination_waypoint_id===detailWaypoint || device(f.destination_device_id)?.site_waypoint_id===detailWaypoint || device(f.source_device_id)?.site_waypoint_id===detailWaypoint).forEach((f) => record($("feeds"), feedName(f), f, "feed"));
    $("networks").replaceChildren();
    data.networks.filter(n=>n.site_waypoint_id===detailWaypoint).forEach((n) =>
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
      "install-controller",
      "connect-controller",
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
      const target = a.site_power_breaker_id ? `Breaker ${data.breakers.find(b => b.site_power_breaker_id === a.site_power_breaker_id)?.breaker_name || a.site_power_breaker_id}` : a.site_power_circuit_id
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
  // Only the structured waypoint type is authoritative. "Combo" means
  // power + network; it is independent of a pole versus an outlet box.
  const isComboWaypoint = (w) =>
    String(w.type || "").trim().toLowerCase().split(/[-_\s]+/).includes("combo");
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
        select("owner_name", "Equipment owner (optional)", options([["MSB","MSB"],["Utility","Utility"],["Other","Other"]])),
        select("supply_breaker_id", "Remote supply breaker (leave blank for local main)", options(data.breakers.filter(b=>b.active).map(b=>[b.site_power_breaker_id,`${panel(b.site_panel_id)?.panel_name} / ${b.breaker_name}`]))),
        text(
          "meter_information",
          "Known meter identifier(s) / relationship notes",
        ),
      ],
      cable_spec: [
        select("site_cable_id", "Existing physical cable", options((data.cable_options || []).map(c => [c.id,c.name])), true),
        text("cable_specification", "Observed cable specification (for example 12-3)", true),
      ],
      conductor: [
        select("site_cable_id", "Existing physical cable", options((data.cable_options || []).map(c => [c.id,c.name])), true),
        text("conductor_label", "Observed conductor identifier", true),
        choose("conductor_role", "Conductor role", ["UNKNOWN","HOT","NEUTRAL","GROUND"]),
      ],
      conductor_circuit: [
        select("site_power_conductor_id", "Conductor", options((data.conductors || []).map(c => [c.site_power_conductor_id,`Cable ${c.site_cable_id} / ${c.conductor_label} / ${c.conductor_role}`])), true),
        select("site_power_circuit_id", "Circuit using this conductor", circuits, true),
      ],
      breaker: [
        select("site_panel_id", "Panel", options(data.panels.map(p => [p.site_panel_id,p.panel_name])), true),
        text("breaker_name", "Breaker designation", true),
        choose("breaker_role", "Main or branch breaker", ["UNKNOWN","MAIN","BRANCH"]),
        text("panel_positions", "Branch panel positions in pole order (for example 18/20 or 18,20; blank if unknown)"),
        select("rated_amps", "Breaker rating (A)", options([15,20,30,40,50,90,100,200].map(x=>[x,String(x)]))),
        select("pole_count", "Pole count", options([1,2,3].map(x=>[x,String(x)]))),
      ],
      circuit: [
        select(
          "site_panel_id",
          "Panel",
          options(data.panels.map((p) => [p.site_panel_id, p.panel_name])),
          true,
        ),
        text("circuit_code", "Circuit designation", true),
        text("description", "Notes (optional)"),
        select("site_power_breaker_id", "Supplying breaker (unknown allowed)", options((data.breakers || []).map(b => [b.site_power_breaker_id,b.breaker_name]))),
        {...text("breaker_pole", "Pole within breaker (1, 2…; not panel position)"), type: "number"},
        { ...text("voltage", "Voltage"), type: "number" },
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
      controller_power_connection: [
        select("controller_id","Existing controller inventory item",options((data.controller_options || []).map(c=>[c.id,`#${c.id} · ${c.model} · ${c.serial || "No serial"}`])),true),
        select("site_waypoint_id","Outlet waypoint",options(data.waypoints.filter(w=>["power","out-power","out-combo"].includes(w.type?.trim().toLowerCase())).map(w=>[w.id,w.name])),true),
        select("site_power_circuit_id","Supplying circuit leg",circuits,true),
      ],
      controller_installation: [
        select("controller_id","Existing inventory item",options((data.controller_options || []).map(c=>[c.id,`#${c.id} · ${c.model} · ${c.serial || "No serial"}`])),true),
        select("site_waypoint_id","Power + network location (Combo box or pole)",options(data.waypoints.filter(isComboWaypoint).map(w=>[w.id,`${w.name} (${w.type})`])),true),
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
        select("owner_name", "Equipment owner (optional)", options([["MSB","MSB"],["Utility","Utility"],["Other","Other"]])),
        text("utility_asset_id", "Utility asset identification"),
        text("rating", "Known rating"),
        text("description", "Notes (optional)"),
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
        select("site_power_breaker_id", "Affected breaker (choose exactly one target)", options((data.breakers || []).map(b => [b.site_power_breaker_id,b.breaker_name]))),
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
            text("source_evidence", "Notes (optional)"),
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
      else n.value = Array.isArray(value) ? value.join(",") : value ?? "";
      if (spec.type === "number") {
        n.min = ["breaker_pole","pole_count","rated_amps"].includes(spec.key) ? "1" : "0.000001";
        n.step = ["breaker_pole","pole_count","rated_amps"].includes(spec.key) ? "1" : "any";
        if (spec.key === "rated_amps") n.setAttribute("list", "breaker-amp-options");
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
        row[s.key] ?? (s.key.includes("desired_state") ? "UNKNOWN" : undefined),
      ),
    );
    if (kind === "controller_power_connection") {
      const form=$("edit-form"), waypoint=form.elements.site_waypoint_id, choice=form.elements.site_power_circuit_id;
      const refresh=()=>{
        const prior=choice.value; choice.replaceChildren();
        el("option","Select actual circuit leg",choice).value="";
        data.circuits.filter(c=>c.active && paths(c.site_power_circuit_id).some(x=>x.waypoint?.id===Number(waypoint.value))).forEach(c=>{
          const o=el("option",circuitName(c.site_power_circuit_id),choice);o.value=c.site_power_circuit_id;o.selected=String(c.site_power_circuit_id)===prior;
        });
      }; waypoint.onchange=refresh;refresh();
      if (row.site_controller_power_connection_id) {
        for(const name of ["controller_id","site_waypoint_id","site_power_circuit_id"]) form.elements[name].disabled=true;
        el("p","To move this plug-in connection, retire it and record the new outlet/circuit. History is retained.",$("edit-fields"));
      }
    }
    if (kind === "controller_installation" && row.site_controller_installation_id) {
      $("edit-form").elements.controller_id.disabled=true;
      $("edit-form").elements.site_waypoint_id.disabled=true;
      el("p","To move this item, retire this installation, then install the same inventory ID at its new network box.",$("edit-fields"));
    }
    if (kind === "breaker") {
      const form = $("edit-form"), role = form.elements.breaker_role, positions = form.elements.panel_positions;
      const updateRole = () => {
        positions.closest("label").hidden = role.value === "MAIN";
        positions.disabled = role.value === "MAIN";
        if (role.value === "MAIN") positions.value = "";
      };
      role.addEventListener("change", updateRole); updateRole();
    }
    if (kind === "circuit") {
      const form=$("edit-form"), panelSelect=form.elements.site_panel_id,
        breakerSelect=form.elements.site_power_breaker_id, pole=form.elements.breaker_pole;
      const updatePoles=()=>{
        const breaker=data.breakers.find(b=>String(b.site_power_breaker_id)===breakerSelect.value);
        pole.max=breaker?.pole_count || ""; pole.required=!!breaker;
        if (!breaker) pole.value="";
      };
      const updateBreakers=()=>{
        const prior=breakerSelect.value; breakerSelect.replaceChildren();
        const empty=el("option","Unknown / not specified",breakerSelect); empty.value="";
        data.breakers.filter(b=>b.active && b.breaker_role!=="MAIN" && String(b.site_panel_id)===panelSelect.value).forEach(b=>{
          const option=el("option",`${b.breaker_name} (${b.rated_amps ?? "?"} A; ${b.pole_count ?? "?"} poles)`,breakerSelect);
          option.value=b.site_power_breaker_id; option.selected=String(b.site_power_breaker_id)===prior;
        }); updatePoles();
      };
      panelSelect.addEventListener("change",updateBreakers);
      breakerSelect.addEventListener("change",updatePoles); updateBreakers();
    }
    if (kind === "event") {
      const actionSelect = $("edit-form").elements.site_power_action_id;
      const preview = el("div", undefined, $("edit-fields"));
      const review = () => {
        preview.replaceChildren();
        const a = data.actions.find(x => x.site_power_action_id === Number(actionSelect.value));
        if (!a?.site_power_breaker_id) return;
        const impact = data.breaker_impacts.find(x => x.breaker.site_power_breaker_id === a.site_power_breaker_id);
        el("p", "Recorded affected endpoints. Unknown or alternative supplies are not verified isolation.", preview);
        if (impact?.missing_pole_membership) el("p", "Incomplete pole assignments", preview);
        (impact?.paths || []).forEach(x => el("p", `${circuitName(x.site_power_circuit_id)} / ${x.waypoint_name || "Unknown waypoint"} / ${x.verification_states.join(" / ")}`, preview));
        const label = el("label", "I reviewed both circuit legs, recorded endpoints and uncertainties", preview);
        const check = el("input", undefined, label);
        check.type = "checkbox"; check.name = "impact_reviewed"; check.required = true;
      };
      actionSelect.addEventListener("change", review); review();
    }
    $("editor").showModal();
  }
  function openSupply(p) {
    open("panel", p);
    $("edit-title").textContent=`${p.panel_name} — meter / upstream supply`;
    for (const name of ["panel_name","panel_identification","site_waypoint_id","owner_name","active"])
      $("edit-form").elements[name].closest("label").hidden=true;
    const supply=$("edit-form").elements.supply_breaker_id;
    for (const option of Array.from(supply.options)) {
      const b=data.breakers.find(b=>String(b.site_power_breaker_id)===option.value);
      if (b?.site_panel_id===p.site_panel_id) option.remove();
    }
  }
  function openSchedule(row={}) {
    if (!data.access.can_edit) return;
    pending=null;
    edit={kind:"breaker_schedule",row};
    $("edit-title").textContent=`${panel(row.site_panel_id)?.panel_name || "Panel"} — ${row.site_power_breaker_id ? "Edit" : "Add"} breaker`;
    $("edit-fields").replaceChildren(); $("save-status").textContent=""; $("save").disabled=false;
    const role=row.breaker_role || "BRANCH";
    field(text("breaker_name","Breaker designation (optional; defaults to positions)"),row.breaker_name);
    const positions=field(text("panel_positions","Positions / circuits (for example 18/20)"),row.panel_positions);
    positions.closest("label").hidden=role==="MAIN";
    field({...text("rated_amps","Amps per pole"),type:"number"},row.rated_amps);
    const poles=field({...text("pole_count","Poles"),type:"number"},row.pole_count || (role==="MAIN"?2:1));
    field(text("source_evidence","Breaker notes / correction reason (optional)"),"");
    const states=options(["UNKNOWN","ON","OFF"].map(v=>[v,v]));
    field(select("show_desired_state","Season ON / OFF",states,true),row.show_desired_state || "UNKNOWN");
    field(select("restoration_desired_state","Non-season ON / OFF",states,true),row.restoration_desired_state || "UNKNOWN");
    positions.onchange=()=>{
      if (/^\d+(\s*[,/]\s*\d+)*$/.test(positions.value.trim())) poles.value=positions.value.split(/[,/]/).length;
    };
    poles.onchange=()=>{
      const first=Number(positions.value.split(/[,/]/)[0]), count=Number(poles.value);
      if (!row.site_power_breaker_id && first>0 && count>0 && count<=3)
        positions.value=Array.from({length:count},(_,i)=>first+2*i).join("/");
    };
    el("p","Save breaker settings, then select each circuit on the panel to assign its waypoints. Existing assignments and circuit IDs are retained.",$("edit-fields"));
    edit.read=()=>{
      const form=$("edit-form");
      const raw=positions.value.trim();
      if(role!=="MAIN" && raw && !/^\d+(\s*[,/]\s*\d+)*$/.test(raw)) throw new Error("Enter panel positions such as 1/3 or 18,20; use numbers only.");
      const slots=role!=="MAIN"&&raw?raw.split(/[,/]/).map(Number):null;
      const count=Number(poles.value);
      if(slots && slots.length!==count) throw new Error("Positions must match the number of circuit legs.");
      return {
        breaker:{site_panel_id:row.site_panel_id,breaker_role:role,
          breaker_name:form.elements.breaker_name.value.trim() || (role==="MAIN"?"Main":slots?.join("/")),
          panel_positions:slots,pole_count:count,rated_amps:form.elements.rated_amps.value?Number(form.elements.rated_amps.value):null,
          source_evidence:form.elements.source_evidence.value.trim() || "Operator breaker schedule entry; field verification pending",
          verification_status:"UNVERIFIED"},
        show_desired_state:form.elements.show_desired_state.value,restoration_desired_state:form.elements.restoration_desired_state.value,
        legs:role==="MAIN" ? [] : Array.from({length:count},(_,i)=>{
          const old=data.circuits.find(c=>c.active && c.site_power_breaker_id===row.site_power_breaker_id && c.breaker_pole===i+1);
          const code=old?.circuit_code || (slots?.[i]!==undefined ? String(slots[i]) : null);
          if(!code) throw new Error("Record explicit positions before creating circuit legs.");
          return {pole:i+1,circuit_code:code,waypoint_ids:old ? data.feeds.filter(f=>f.active && f.source_circuit_id===old.site_power_circuit_id && f.destination_waypoint_id).map(f=>f.destination_waypoint_id) : []};
        })
      };
    };
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
    field(text("source_evidence", "Notes (optional)"), "");
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
      if (s.key === "panel_positions" && v !== null) {
        if (!/^\d+(\s*[,/]\s*\d+)*$/.test(v)) throw new Error("Enter panel positions such as 1/3 or 18,20; use numbers only.");
        v=v.split(/[,/]/).map(Number);
        if (v.some(x=>!Number.isSafeInteger(x)||x<1||x>200)) throw new Error("Panel positions must be integers from 1 to 200.");
      }
      result[s.key] = v;
    }
    if (edit.kind === "event") result.impact_reviewed = !!$("edit-form").elements.impact_reviewed?.checked;
    return result;
  }
  function command(kind, id, fields) {
    return { kind, id: id ?? null, fields, request_id: crypto.randomUUID() };
  }
  $("edit-form").onsubmit = async (event) => {
    event.preventDefault();
    try {
    if (!pending) {
      let commands;
      if (edit.kind === "breaker_schedule") {
        commands=[command("breaker_schedule",edit.row.site_power_breaker_id,edit.read())];
      } else if (edit.kind === "assignments") {
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
          verification_status: "UNVERIFIED",
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
      $("save-status").focus();
      $("save-status").scrollIntoView({block:"nearest"});
      if (!pending || (e.status && e.status < 500)) {
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
  $("connect-controller").onclick=()=>open("controller_power_connection",{site_waypoint_id:Number($("detail-waypoint").value)});
  $("install-controller").onclick=()=>open("controller_installation",{site_waypoint_id:Number($("detail-waypoint").value)});
  $("detail-waypoint").onchange=()=>render();
  $("reload").onclick = load;
  $("find").oninput = () => data && render();
  $("season").onchange = renderActions;
  $("action-search").oninput = () => data && renderActions();
  for (const kind of ["panel", "device", "feed", "network", "action"])
    $(`add-${kind}`).onclick = () => open(kind, ["device","network"].includes(kind) ? {site_waypoint_id:Number($("detail-waypoint").value)||undefined} : {});
  // Expose pure relationship resolution only to the isolated browser harness.
  window.MSBPowerCapture = { paths };
  load();
})();
