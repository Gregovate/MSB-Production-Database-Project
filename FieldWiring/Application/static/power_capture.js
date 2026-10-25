/* Crew circuit capture. All facts and identities come from the PostgreSQL API.
 * Text uses textContent; server/DB own authorization, revisions and audit actors. */
"use strict";
(() => {
  const $ = (id) => document.getElementById(id);
  // Focused routes share one snapshot and command implementation, not stores.
  const mode = ({waypoints:"waypoints",equipment:"equipment","cable-tests":"tests"})[location.pathname.split("/").pop()] || "panels";
  document.body.dataset.powerScreen=mode;
  const title={panels:"Panel Circuits",waypoints:"Waypoint Connections",equipment:"Combo Equipment",tests:"Cable Test History"}[mode];
  document.querySelector("h1").textContent=title; document.title=`${title} — MSB Field Wiring`;
  $("waypoint-detail").open=true;
  $("cable-history").hidden=mode!=="tests";
  if(mode==="equipment") $("equipment-heading").textContent="Installed Combo equipment";
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
    action: "site_power_action_id",
  };
  let data,
    panelId = null,
    edit = null,
    pending = null,
    loading = false;
  // Tab-local navigation context only; installed inventory remains in the shared model.
  const panelViewKey = "msb-power-panel-view:" + new URL(".",location.href).pathname;
  let restoredPanelView=false;
  function savedPanelView() {
    try {const v=JSON.parse(sessionStorage.getItem(panelViewKey));return v && Number.isSafeInteger(v.panelId) ? v : null;}
    catch (_) {return null;}
  }
  function savePanelView() {
    if(mode!=="panels" || !panelId) return;
    const view={panelId:Number(panelId),filter:$("find").value,scrollY:window.scrollY,
      open:Array.from(document.querySelectorAll('#panel-detail details[open][data-view-key]'),n=>n.dataset.viewKey)};
    try {sessionStorage.setItem(panelViewKey,JSON.stringify(view));} catch (_) { /* URL still preserves panel identity. */ }
    const url=new URL(location.href);url.searchParams.set("panel",String(panelId));url.searchParams.delete("circuit");
    history.replaceState(history.state,"",url);
  }
  window.addEventListener("pagehide",savePanelView);
  const navigation=document.querySelector('nav[aria-label="Field wiring screens"]');
  for(const link of navigation.querySelectorAll('a')) {
    const linkMode=({circuits:"panels",waypoints:"waypoints",equipment:"equipment","cable-tests":"tests"})[link.getAttribute('href')];
    if(linkMode===mode) link.setAttribute('aria-current','page');
  }
  if(mode!=="panels") {
    const previous=savedPanelView();
    if(previous) {
      const back=el("a","Back to panel",$("status").parentNode);
      back.className="power-return power-navigation";
      back.href="circuits?panel="+previous.panelId;
      $("status").after(back);
      navigation.querySelector('a[href="circuits"]').href=back.href;
    }
  }
  function el(tag, text, parent) {
    const n = document.createElement(tag);
    if (text !== undefined) n.textContent = text;
    if (parent) parent.append(n);
    return n;
  }
  function button(text, action, parent, write = false) {
    const n = el("button", text, parent);
    n.type = "button";
    n.className = "power-secondary";
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
      const query=new URLSearchParams(location.search);
      const previous=mode==="panels" && !restoredPanelView ? savedPanelView() : null;
      const requestedPanel=Number(query.get("panel"));
      if(mode==="panels" && !restoredPanelView && panel(requestedPanel)) {
        panelId=requestedPanel;
        if(previous?.panelId===panelId && typeof previous.filter==="string") $("find").value=previous.filter;
      }
      if(mode==="panels" && query.get("circuit") && !$("panel-detail").dataset.linkOpened) {
        const target=circuit(Number(query.get("circuit")));
        if(target) {panelId=target.site_panel_id;render();if(data.access.can_edit) openAssignments(target);$("panel-detail").dataset.linkOpened="1";}
      }
      render();
      if(mode==="panels" && !restoredPanelView) {
        restoredPanelView=true;
        if(previous?.panelId===panelId && !query.get("circuit")) {
          for(const d of document.querySelectorAll('#panel-detail details[data-view-key]'))
            d.open=Array.isArray(previous.open) && previous.open.includes(d.dataset.viewKey);
          requestAnimationFrame(()=>window.scrollTo(0,Number.isFinite(previous.scrollY)?Math.max(0,previous.scrollY):0));
        }
      }
      const back=document.querySelector('.power-return');
      if(back) {
        const previousPanel=panel(Number(new URL(back.href).searchParams.get('panel')));
        if(previousPanel) back.textContent=`Back to ${previousPanel.panel_name}`; else {back.remove(); navigation.querySelector('a[href^="circuits"]').href="circuits";}
      }
      const requested=new URLSearchParams(location.search).get("waypoint");
      if(requested && !$("waypoint-detail").dataset.linkOpened) {
        if(mode==="equipment") {$("detail-waypoint").value=requested;render();} else viewWaypoint(Number(requested));$("waypoint-detail").dataset.linkOpened="1";
      }
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
    button(kind==="controller_installation"&&r.active ? "Edit IN / OUT" : "Edit / correct", () => kind==="controller_installation"&&r.active ? openPorts(r.controller_id) : kind === "breaker" ? openSchedule(r) : open(kind, r), box, true);
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
            savePanelView();
          },
          $("panels"),
        );
        b.className = p.site_panel_id === panelId ? "power-selected" : "";
        // Ownership is descriptive; these colors never indicate electrical state.
        b.dataset.owner = p.owner_name === "MSB Owned" ? "msb" : p.owner_name === "City Owned" ? "city" : "other";
        b.setAttribute("aria-label", `${p.panel_name}${p.active ? "" : " (retired)"}`);
        b.setAttribute("aria-pressed", String(p.site_panel_id === panelId));
        const ownerLabel = el("small", p.owner_name || "Owner unknown", b);
        ownerLabel.className = "power-owner-label";
      });
    const selected = panel(panelId),
      detail = $("panel-detail");
    detail.replaceChildren();
    if (selected) {
      const box = record(detail, selected.panel_name, selected, "panel");
      el(
        "p",
        `Location: ${selected.site_waypoint_id ? waypointName(selected.site_waypoint_id) : "Unknown"} · Owner: ${selected.owner_name || "Unknown"} · Installed: ${selected.year_installed ?? "Unknown"}`,
        box,
      );
      el(
        "p",
        `Identification: ${selected.panel_identification || "Unknown"} · Meter information: ${selected.meter_information || "Unknown"}`,
        box,
      );
      el("p",`Panel plan — show: ${selected.show_desired_state}; off-season: ${selected.restoration_desired_state}. Actual condition requires separate field evidence.`,box);
      const unresolved=el("details",undefined,box); unresolved.dataset.viewKey="unresolved";
      el("summary","Unresolved Display loads (all locations)",unresolved);
      (data.load_lineage || []).filter(x=>x.load_status!=="RECORDED_BASIS_UNVERIFIED").forEach(x=>el("p",`Display ${x.display_id} ${x.display_name} · Controller ${x.controller_id ?? "Unknown"} · ${x.load_status}`,unresolved));
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
        // Render existing notes as text, including breakers with no mapped endpoints.
        if (b.source_evidence) el("p", b.source_evidence, row).className="power-breaker-notes";
        drawState(b,row);
        button("Breaker settings",()=>openSchedule(b),row,true);
        const circuits = data.circuits.filter(c => c.active && c.site_power_breaker_id === b.site_power_breaker_id)
          .sort((a,b)=>a.breaker_pole-b.breaker_pole);
        circuits.forEach(c => {
          const names=[...new Set(paths(c.site_power_circuit_id).map(x=>x.waypoint?.name || "Unknown waypoint"))];
          const leg=button(`Circuit ${c.circuit_code} — ${names.join(", ") || "Waypoints (optional)"}`,()=>openAssignments(c),row,true);
          if (c.description) el("p", c.description, row).className="power-circuit-notes";
          const load=(data.circuit_loads || []).find(x=>x.site_power_circuit_id===c.site_power_circuit_id);
          if (load) {
            const loads=el("details",undefined,row); loads.className="power-load"; loads.dataset.viewKey="load:"+c.site_power_circuit_id;
            el("summary",`Display load: ${load.recorded_display_amps == null ? "Unknown" : load.recorded_display_amps+" A"} · incomplete`,loads);
            el("p",`Breaker rating: ${load.rated_amps ?? "Unknown"} A per pole. Nominal headroom: ${load.nominal_headroom_amps ?? "Unknown"} A; nominal utilization: ${load.nominal_utilization_percent == null ? "Unknown" : Number(load.nominal_utilization_percent).toFixed(1)+"%"}. Basis/voltage unverified; excludes unresolved loads. This is not usable capacity.`,loads);
            el("p","Controller/auxiliary consumption and field demand are unknown. Conductor, receptacle, shared-neutral and continuous-load limits require verification.",loads);
            (data.load_lineage || []).filter(x=>x.site_power_circuit_id===c.site_power_circuit_id).forEach(x=>el("p",`Display ${x.display_id} ${x.display_name} → Controller ${x.controller_id}: ${x.amps_measured ?? "Unknown"} A · ${x.load_status}`,loads));
          }
          leg.className="power-circuit-leg"; leg.dataset.circuitId=c.site_power_circuit_id;
          for (const id of [...new Set(paths(c.site_power_circuit_id).map(x=>x.waypoint?.id).filter(Boolean))]) {
            button(`Open ${waypointName(id)} / equipment`,()=>viewWaypoint(id),row).className="power-navigation";
          }
        });
        el("p", `Required for show: ${b.show_desired_state} · Off-season: ${b.restoration_desired_state}`, row);
        const impact = (data.breaker_impacts || []).find(x => x.breaker.site_power_breaker_id === b.site_power_breaker_id);
        const details = el("details", undefined, row); details.dataset.viewKey="impact:"+b.site_power_breaker_id;
        el("summary", "Connections · unverified", details);
        el("p", "Recorded endpoints are not proof of electrical isolation.", details);
        if (impact?.missing_pole_membership) el("p", "Incomplete breaker/circuit membership", details);
        (impact?.paths || []).forEach(x => el("p", `${circuitName(x.site_power_circuit_id)} · ${x.waypoint_name || "Unknown waypoint"} · ${x.destination_device_id ? deviceName(x.destination_device_id) : "Receptacle unspecified"}`, details));
        (impact?.controller_connections || []).forEach(x=>el("p",`Plugged-in controller ${x.controller_id} · ${waypointName(x.site_waypoint_id)} · ${circuitName(x.site_power_circuit_id)}`,details));
        return row;
      };
      el("p", `Meter: ${selected.meter_information || "Not recorded"}`, main);
      const supply = data.breakers.find(b=>b.site_power_breaker_id===selected.supply_breaker_id);
      if (!supply && selected.supply_panel_id) el("p",`Remote supply panel: ${panel(selected.supply_panel_id)?.panel_name || "Unknown"} — feeder breaker unknown`,main);
      if (supply) el("p", `Remote main / supply: ${panel(supply.site_panel_id)?.panel_name} — ${supply.breaker_name}`, main);
      button("Meter / upstream supply",()=>openSupply(selected),main,true);
      const mains = breakers.filter(b => b.breaker_role === "MAIN");
      mains.forEach(b => drawBreaker(b,main));
      if (!mains.length && !selected.supply_breaker_id && !selected.supply_panel_id) {
        el("p", "Main breaker not recorded; rating unknown", main);
        button("Record main breaker",()=>openSchedule({site_panel_id:panelId,breaker_role:"MAIN"}),main,true).className="power-primary";
      }
      button("Add branch breaker",()=>openSchedule({site_panel_id:panelId,breaker_role:"BRANCH"}),board,true).className="power-primary";
      const schedule = el("div",undefined,board); schedule.className="power-slot-grid";
      const positioned = breakers.filter(b=>b.breaker_role!=="MAIN" && b.panel_positions?.length);
      const conventional=b=>b.panel_positions.every((p,i)=>p===b.panel_positions[0]+2*i);
      // Unknown counts show only recorded extent, never inferred spare capacity.
      if (selected.branch_position_count == null) {
        el("p", "Number of slots not recorded. Only recorded positions are shown.", board);
        button("Set number of slots",()=>open("panel",selected),board,true).className="power-primary";
      } else el("p", `${selected.branch_position_count} slots · main separate`, board);
      const last = Math.max(selected.branch_position_count ?? 0,...positioned.flatMap(b=>b.panel_positions));
      for (let pos=1;pos<=last;pos++) {
        const breaker=positioned.find(b=>b.panel_positions.includes(pos));
        if (breaker && (!conventional(breaker) || breaker.panel_positions[0]!==pos)) continue;
        const cell=el("div",undefined,schedule); cell.className="power-slot";
        cell.style.gridColumn=pos%2 ? "1" : "2";
        cell.style.gridRow=`${Math.ceil(pos/2)} / span ${breaker?.panel_positions.length || 1}`;
        if (breaker) {
          if (breaker.breaker_name !== breaker.panel_positions.join("/"))
            el("small",`Positions ${breaker.panel_positions.join(" / ")}`,cell);
          drawBreaker(breaker,cell);
        } else button(`Position ${pos} · Add breaker`,()=>openSchedule({site_panel_id:panelId,breaker_role:"BRANCH",panel_positions:[pos],pole_count:1}),cell,true);
      }
      const unplaced=el("details",undefined,board); unplaced.dataset.viewKey="unplaced";
      el("summary","Unknown or nonstandard positions — reconcile",unplaced);
      breakers.filter(b=>b.breaker_role!=="MAIN" && (!b.panel_positions?.length || !conventional(b))).forEach(b=>drawBreaker(b,unplaced));
      const legacy=el("details",undefined,detail); legacy.dataset.viewKey="legacy";
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
            `Rating: ${data.breakers?.find(b => b.site_power_breaker_id === c.site_power_breaker_id)?.rated_amps ?? "Unknown"} A · Show desired: ${c.show_desired_state} · Season OFF required: ${c.restoration_desired_state}`,
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
    data.waypoints.filter(w=>mode==="equipment" ? isComboWaypoint(w) : isDeploymentWaypoint(w)).forEach(w=>{const o=el("option",`${w.name} (${w.type})`,waypointSelect);o.value=w.id;});
    waypointSelect.value=priorWaypoint;
    const detailWaypoint=Number(priorWaypoint);
    const combo=isComboWaypoint(wp(detailWaypoint) || {});
    $("combo-network-box").hidden=mode==="equipment" ? !combo : !isNetworkWaypoint(wp(detailWaypoint) || {});
    $("waypoint-supply").replaceChildren();
    data.circuits.filter(c=>c.active && paths(c.site_power_circuit_id).some(x=>x.waypoint?.id===detailWaypoint))
      .forEach(c=>button(circuitName(c.site_power_circuit_id),()=>{location.href=`circuits?circuit=${c.site_power_circuit_id}`;},$("waypoint-supply")));
    if (detailWaypoint) {
      const label=el("label","Manage supplying circuit on Panel Circuits",$("waypoint-supply")), select=el("select",undefined,label);
      el("option","Select panel / circuit",select).value="";
      data.circuits.filter(c=>c.active).forEach(c=>{el("option",circuitName(c.site_power_circuit_id),select).value=c.site_power_circuit_id;});
      select.onchange=()=>{if(select.value) location.href=`circuits?circuit=${select.value}`;};
    }
    const powerOutlet=isElectricalEndpoint(wp(detailWaypoint) || {});
    $("outlet-controllers").hidden=!powerOutlet;
    $("plugged-controllers").replaceChildren();
    (data.controller_power_connections || []).filter(i=>i.site_waypoint_id===detailWaypoint).forEach(i=>{
      const asset=data.controller_options.find(c=>c.id===i.controller_id);
      record($("plugged-controllers"),`Controller ${i.controller_id} · ${asset?.model || "Unknown model"} · ${circuitName(i.site_power_circuit_id)}`,i,"controller_power_connection");
    });
    $("equipment").replaceChildren();
    $("installations").replaceChildren();
    (data.controller_installations || []).filter(i=>i.site_waypoint_id===detailWaypoint).forEach(i=>{
      const asset=data.controller_options.find(c=>c.id===i.controller_id);
      if(i.active && !(data.placement_eligibility || []).some(e=>e.controller_id===i.controller_id && e.site_waypoint_id===i.site_waypoint_id)) el("p",`Controller ${i.controller_id}: current network eligibility unresolved; recorded placement retained for reconciliation.`,$("equipment"));
      const box=el("div",undefined,$("installations"));box.className="power-record";
      el("h3",`CTRL ${i.controller_id}`,box);stamp(i,box);
      const next=data.controller_installations.find(c=>c.active&&c.upstream_controller_id===i.controller_id);
      const table=el("table",undefined,box);table.className="controller-port-summary";
      const head=el("tr",undefined,el("thead",undefined,table));["IN","Controller","OUT"].forEach(t=>el("th",t,head));
      const row=el("tr",undefined,el("tbody",undefined,table));
      if(i.upstream_kind==="CONTROLLER")window.MSBControllerDeployment.controllerCell(data,i.upstream_controller_id,row);
      else el("td",i.upstream_kind==="WAYPOINT"?wp(i.site_waypoint_id)?.name:"Not recorded",row);
      window.MSBControllerDeployment.controllerCell(data,i.controller_id,row);
      if(next)window.MSBControllerDeployment.controllerCell(data,next.controller_id,row);
      else el("td",i.chain_end==="TERMINATOR"?"Terminating resistor":i.chain_end==="RETURN_TO_ORIGIN"?`${wp(i.site_waypoint_id)?.name} — return`:"Not recorded",row);
      if(i.active)button("Edit IN / OUT",()=>openPorts(i.controller_id),box,true);

    });
    data.devices.filter(d=>d.site_waypoint_id===detailWaypoint).forEach(d=>{
      record($("equipment"),`${d.device_name} · ${d.device_kind}`,d,"device");
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
    const available=(data.networks || []).filter(n=>n.site_waypoint_id===detailWaypoint);
    [...new Set(available.map(n=>n.network_code))].forEach(code=>el("p",`${code} · FLW endpoint record`, $("networks")));
    if (!available.length) el("p","No resolved FLW network endpoints at this waypoint. Reconcile the FLW endpoint records before network placement.",$("networks"));
    // Expectations are prompts only: no inventory writes or inferred installation.
    for(const id of new Set(available.map(n=>n.site_network_id))) {
      const net=(data.network_options || []).find(n=>n.site_network_id===id);
      const code=net?.network_code || available.find(n=>n.site_network_id===id)?.network_code || "";
      const key=code.trim().toUpperCase().replace(/^AUX[ -]+/,"AUX-");
      const cables=(data.flw_cable_tests || []).filter(t=>t.network_key===key && [t.endpoint_a,t.endpoint_b].includes(detailWaypoint));
      const neighbors=new Set(cables.map(t=>t.endpoint_a===detailWaypoint ? t.endpoint_b : t.endpoint_a));
      if(net?.network_kind==="LOR" && neighbors.size>1)
        el("p",`${code}: multiple cable paths. Verify whether this is a branch requiring a LOR repeater or a continuing line. No repeater inventory is inferred.`, $("networks"));
      if(key==="INET" || key.startsWith("E1.31"))
        el("p",`${code}: verify switch and power-supply inventory at distribution points where runs approach 300 ft; verify PoE for security cameras on the line. These are equipment expectations, not installed records.`, $("networks"));
    }
    renderCableHistory();
    renderSafety(detailWaypoint);
    const year = $("season").value;
    $("season").replaceChildren();
    data.seasons.forEach((y) => {
      const o = el("option", y, $("season"));
      o.value = y;
    });
    if (data.seasons.includes(Number(year))) $("season").value = year;
    renderChecklist();
    renderReports();
    renderActions();
    $("history").replaceChildren();
    data.history.slice(0, 100).forEach((h) => {
      const d = el("details", undefined, $("history"));
      el(
        "summary",
        `${h.recorded_at} · ${h.operator_name || "Name unavailable"} · ${h.command} #${h.target_id}`,
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
      "add-action",
    ].forEach((id) => ($(id).disabled = !data.access.can_edit));
  }
  function renderSafety(waypointId) {
    const root=$("waypoint-safety");root.replaceChildren();
    if(!waypointId) return;
    el("h3","Recorded potential electrical sources",root);
    el("p","Incomplete topology or alternate supplies may exist. Planned OFF and recorded events do not prove absence of voltage. Follow field isolation, lockout/tagout and voltage-testing procedures; utility equipment requires authorized utility coordination.",root);
    const sources=(data.waypoint_power_sources || []).filter(x=>x.site_waypoint_id===waypointId);
    data.panels.filter(p=>p.site_waypoint_id===waypointId).forEach(p=>sources.push({site_panel_id:p.site_panel_id,verification_states:[p.verification_status]}));
    if(!sources.length) el("p","Supply path unknown — no de-energization assurance.",root);
    const panelIds=new Set(), breakerIds=new Set(), circuitIds=new Set(), deviceIds=new Set();
    sources.forEach(x=>{
      if(x.site_power_circuit_id)circuitIds.add(x.site_power_circuit_id);if(x.destination_device_id)deviceIds.add(x.destination_device_id);
      el("p",`${x.site_power_circuit_id ? circuitName(x.site_power_circuit_id) : "Panel at this waypoint"} · pole ${x.breaker_pole ?? "Unknown"} · feed evidence ${x.verification_states.join(" / ")}`,root);
      let current=panel(x.site_panel_id), seen=new Set();
      if(x.site_power_breaker_id)breakerIds.add(x.site_power_breaker_id);
      while(current && !seen.has(current.site_panel_id)) {
        seen.add(current.site_panel_id);panelIds.add(current.site_panel_id);
        el("p",`${current.panel_name} · ${current.owner_name || "Owner unknown"} · ${waypointName(current.site_waypoint_id)} · meter ${current.meter_information || "Unknown"} · installed ${current.year_installed ?? "Unknown"} · panel plan show ${current.show_desired_state}, off-season ${current.restoration_desired_state}`,root);
        const mains=data.breakers.filter(b=>b.active && b.site_panel_id===current.site_panel_id && b.breaker_role==="MAIN");
        mains.forEach(b=>breakerIds.add(b.site_power_breaker_id));
        const upstream=data.breakers.find(b=>b.site_power_breaker_id===current.supply_breaker_id);
        if(!upstream){
          if(current.supply_panel_id) {el("p","Upstream panel recorded; specific feeder breaker/isolation point unknown.",root);current=panel(current.supply_panel_id);continue;}
          if(!mains.length)el("p","Main/upstream isolation point unknown.",root);break;
        }
        breakerIds.add(upstream.site_power_breaker_id);current=panel(upstream.site_panel_id);
        if(current && seen.has(current.site_panel_id))el("p","Upstream topology cycle: resolve before relying on isolation instructions.",root);
      }
    });
    data.breakers.filter(b=>breakerIds.has(b.site_power_breaker_id)).forEach(b=>el("p",`Breaker ${b.breaker_name} · ${b.rated_amps ?? "Unknown"} A per pole · positions ${b.panel_positions?.join("/") || "Unknown"} · plan show ${b.show_desired_state}, off-season ${b.restoration_desired_state}`,root));
    const actions=data.actions.filter(a=>panelIds.has(a.site_panel_id)||breakerIds.has(a.site_power_breaker_id)||circuitIds.has(a.site_power_circuit_id)||deviceIds.has(a.site_power_device_id));
    actions.forEach(a=>{
      el("p",`${a.action_name}: ${a.instructions || "Instructions unknown"}; responsible ${a.responsible_party || "Unknown"}; prerequisite activities ${a.prerequisite_action_ids.join(", ") || "None recorded"}`,root);
      data.events.filter(e=>e.site_power_action_id===a.site_power_action_id).forEach(e=>el("p",`Evidence: ${e.season_year} · ${e.observed_at} · ${e.event_kind} · ${e.condition} · ${e.evidence}${data.events.some(c=>c.corrects_event_id===e.event_id)?" (corrected; historical)":""}`,root));
    });
    if(!actions.length)el("p","No field switching/utility verification activity recorded for these sources.",root);
  }
  function viewWaypoint(waypointId) {
    if (!waypointId || !wp(waypointId)) return;
    if (mode!=="waypoints") { savePanelView(); location.href=`waypoints?waypoint=${waypointId}`; return; }
    const section=$("waypoint-detail");
    section.open=true;
    $("detail-waypoint").value=String(waypointId);
    render();
    section.scrollIntoView({block:"start",behavior:"instant"});
  }
  const states = window.MSBBreakerState;
  function drawState(b, root) {
    const e=states.latest(data.events,b.site_power_breaker_id);
    const state=["ON","OFF"].includes(e?.condition)?e.condition:"UNKNOWN";
    const box=el("div",undefined,root); box.className="power-switch-state";
    const badge=el("strong",state==="UNKNOWN"?"Not recorded / unknown":`Recorded ${state}`,box);
    badge.className="power-state power-state-"+state.toLowerCase();
    if(e) el("small",`${new Date(e.observed_at).toLocaleString()} · ${e.operator_name || "Name unavailable"} · Season ${e.season_year}`,box);
    const controls=el("div",undefined,box); controls.className="power-toolbar power-state-controls";
    for(const value of ["ON","OFF"]) {
      const bttn=button(`Record ${value}`,()=>recordState(b,value),controls,true);
      bttn.className="power-record-state power-secondary"; bttn.disabled=stateSaving || !!statePending || !data.access.can_edit; bttn.dataset.recordState=value;
    }
    return e;
  }
  function renderChecklist() {
    $("breaker-checklist").hidden=mode!=="panels";
    $("breaker-context").hidden=mode!=="panels";
    if(mode!=="panels") return;
    const root=$("breaker-checklist-rows"); root.replaceChildren();
    const phase=$("breaker-phase").value, year=Number($("season").value), filter=$("breaker-filter").value;
    const counts={open:0,completed:0,configuration:0,unchanged:0};
    const rows=data.breakers.filter(b=>b.active && panel(b.site_panel_id)?.active)
      .sort((a,b)=>panel(a.site_panel_id).panel_name.localeCompare(panel(b.site_panel_id).panel_name,undefined,{numeric:true}) || a.breaker_name.localeCompare(b.breaker_name,undefined,{numeric:true}));
    for(const b of rows) {
      const event=states.latest(data.events,b.site_power_breaker_id);
      const state=states.classify(b,event,year,phase); counts[state]++;
      if(state!==filter) continue;
      const row=el("article",undefined,root); row.className="power-checklist-row"; row.dataset.breakerId=b.site_power_breaker_id;
      const p=panel(b.site_panel_id);
      el("h3",`${p.panel_name} — Breaker ${b.breaker_name}`,row).className="power-print-title";
      button(`${p.panel_name} — Breaker ${b.breaker_name}`,()=>{panelId=b.site_panel_id;render();$("panel-detail").scrollIntoView({block:"start"});},row).className="power-navigation";
      const descriptions=[b.source_evidence,...data.circuits.filter(c=>c.active && c.site_power_breaker_id===b.site_power_breaker_id).map(c=>c.description)].filter(Boolean);
      if(descriptions.length) el("p",[...new Set(descriptions)].join(" · "),row);
      el("p",`Required: ${phase==="RESTORATION"?b.restoration_desired_state:b.show_desired_state} · ${state==="configuration"?"Set both seasonal targets in Breaker settings":state==="completed"?"Completed":"Needs change / confirmation"}`,row);
      drawState(b,row);
      if(p.site_waypoint_id) {
        const link=el("a",`Locate ${waypointName(p.site_waypoint_id)} on Park Map`,row);
        link.href="/setup/locate/?view=fieldwiring&waypoint_id="+encodeURIComponent(p.site_waypoint_id);
        link.className="power-navigation";
      } else el("p","Panel map location not recorded",row);
      if(state==="configuration") button("Breaker settings",()=>openSchedule(b),row,true);
    }
    $("breaker-progress").textContent=`${counts.completed} of ${counts.open+counts.completed} seasonal changes confirmed · ${counts.open} pending · ${counts.configuration} need configuration · ${counts.unchanged} unchanged targets omitted. Season ${year}, ${phase==="SETUP"?"ON":"OFF"}.`;
    if(!root.children.length) el("p","No breakers in this view.",root);
  }
  let statePending=null, stateSaving=false;
  function stateControls() {
    document.querySelectorAll('[data-record-state]').forEach(n=>n.disabled=stateSaving || !!statePending || !data.access.can_edit);
    $("season").disabled=stateSaving || !!statePending; $("breaker-phase").disabled=stateSaving || !!statePending;
    $("retry-state").hidden=!statePending || stateSaving;
  }
  async function recordState(b, condition) {
    if(!data.access.can_edit || stateSaving || (b && statePending)) return;
    if(!statePending) statePending={revision:data.revision,commands:[command("breaker_state",b.site_power_breaker_id,
      {season_year:Number($("season").value),phase:$("breaker-phase").value,condition,observed_at:new Date().toISOString()})]};
    stateSaving=true; stateControls(); $("state-save-status").textContent="Recording…";
    try {
      await api("api/power/commands",{method:"POST",headers:{"Content-Type":"application/json","X-MSB-Power-Command":"1"},body:JSON.stringify(statePending)});
      statePending=null; await load(); $("state-save-status").textContent="Breaker position recorded.";
    } catch(e) {
      if(e.status && e.status<500) {statePending=null; await load();}
      $("state-save-status").textContent=e.message+(statePending?" Use Retry recording to resend the same observation safely.":" Reloaded current records; record again after checking the current state.");
    } finally {stateSaving=false; stateControls();}
  }
  function renderReports() {
    $("breaker-reports").hidden=mode!=="panels";
    const year=Number($("season").value), phase=$("breaker-phase").value, filter=$("breaker-report-filter").value;
    $("download-breaker-report").href=`api/power/report.pdf?season=${year}&phase=${phase}&view=${filter}`;
    const root=$("breaker-report-rows"); root.replaceChildren();
    const table=el("table",undefined,root); table.className="power-report-table";
    const head=el("tr",undefined,el("thead",undefined,table));
    for(const text of ["Panel / breaker","Description","Required","Recorded","Status","Person / time"]) el("th",text,head);
    const body=el("tbody",undefined,table);let total=0,completed=0,missing=0;
    for(const b of data.breakers.filter(b=>b.active && panel(b.site_panel_id)?.active).sort((a,b)=>panel(a.site_panel_id).panel_name.localeCompare(panel(b.site_panel_id).panel_name,undefined,{numeric:true}) || a.breaker_name.localeCompare(b.breaker_name,undefined,{numeric:true}))) {
      const e=states.latest(data.events,b.site_power_breaker_id), status=states.status(b,e,year,phase);
      total++; if(status==="Completed") completed++; if(status==="No recorded state") missing++;
      if(filter==="exceptions" && status==="Completed" || filter==="completed" && status!=="Completed") continue;
      const row=el("tr",undefined,body); row.dataset.reportBreaker=b.site_power_breaker_id;
      const notes=[b.source_evidence,...data.circuits.filter(c=>c.active && c.site_power_breaker_id===b.site_power_breaker_id).map(c=>c.description)].filter(Boolean);
      button(`${panel(b.site_panel_id).panel_name} / ${b.breaker_name}`,()=>{panelId=b.site_panel_id;render();$("panel-detail").scrollIntoView({block:"start"});},el("td",undefined,row)).className="power-navigation";
      for(const text of [[...new Set(notes)].join("; "),phase==="RESTORATION"?b.restoration_desired_state:b.show_desired_state,e?.condition||"Not recorded",status,e?`${e.operator_name || "Name unavailable"} · ${new Date(e.observed_at).toLocaleString()}`:"—"]) el("td",text,row);
    }
    $("report-counts").textContent=`Season ${year} ${phase==="SETUP"?"ON":"OFF"}: ${completed} completed / ${total} breakers; ${total-completed} exceptions, including ${missing} with no recorded state.`;
    if(!body.children.length) el("p","No breakers in this report.",root);
  }
  function renderActions() {
    const root = $("actions");
    root.replaceChildren();
    const q = $("action-search").value.toLowerCase();
    data.actions.forEach((a) => {
      const target = a.site_panel_id ? `Panel ${panel(a.site_panel_id)?.panel_name || a.site_panel_id}` : a.site_power_breaker_id ? `Breaker ${data.breakers.find(b => b.site_power_breaker_id === a.site_power_breaker_id)?.breaker_name || a.site_power_breaker_id}` : a.site_power_circuit_id
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
        `${a.phase==="RESTORATION"?"Season OFF":a.phase==="SETUP"?"Season ON":a.phase} · Desired: ${a.desired_state} · Responsible: ${a.responsible_party || "Unknown"}`,
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
            `${e.observed_at} · ${e.event_kind} · ${e.condition} · ${e.operator_name || "Name unavailable"} · ${e.evidence}${e.corrects_event_id ? ` · corrects event ${e.corrects_event_id}` : ""}${data.events.some((c) => c.corrects_event_id === e.event_id) ? " · CORRECTED" : ""}`,
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
  const ownerOptions = () => options(
    [...new Set([
      "City Owned", "MSB Owned",
      ...data.panels.map(p => p.owner_name),
      ...data.devices.map(d => d.owner_name),
    ].filter(Boolean))].sort().map(name => [name, name]),
  );
  // A small controlled field-picker vocabulary, not installed inventory.
  // Every Save creates/updates a separate database device ID at the waypoint.
  const equipmentModels = [
    ["Mean Well MDR-60-24 · 24 V 2.5 A", "POWER_SUPPLY"],
    ["NDR 120 W · 48 V 2.5 A DIN supply", "POWER_SUPPLY"],
    ["TRENDnet TI-PGLC50 · 5-port PoE+", "POE_SWITCH"],
    ["Industrial 5-port Gigabit switch", "ETHERNET_SWITCH"],
    ["VDSL Ethernet extender kit", "ETHERNET_EXTENDER"],
    ["RJ45 1-to-2 Ethernet splitter", "ETHERNET_SPLITTER"],
    ["RS485 network repeater", "RS485_REPEATER"],
    ["Fuse", "FUSE"],
    ["Disconnect", "DISCONNECT"],
    ["Outlet", "OUTLET"],
    ["Light pole", "LIGHT_POLE"],
    ["Other equipment", "OTHER"],
  ];
  const equipmentNameOptions = () => options(
    [...new Set([
      ...equipmentModels.map(x=>x[0]),
      ...data.devices.map(d=>d.device_name).filter(Boolean),
    ])].map(name=>[name,name]),
  );
  const ratingOptions = () => options(
    [...new Set([
      10,15,20,25,30,35,40,45,50,60,70,80,90,100,110,125,150,175,200,
      ...data.breakers.map(b => Number(b.rated_amps)).filter(x => Number.isFinite(x) && x > 0),
    ])].sort((a,b) => a-b).map(x => [x, String(x)]),
  );
  // Only the structured waypoint type is authoritative. "Combo" means
  // power + network; it is independent of a pole versus an outlet box.
  const isComboWaypoint = (w) =>
    String(w.type || "").trim().toLowerCase().split(/[-_\s]+/).includes("combo");
  const isElectricalEndpoint = (w) => {
    // Endpoint eligibility is based on the maintained waypoint TYPE, never
    // display-name text. Unknown types are not silently treated as outlets.
    const tokens=String(w.type||"").trim().toLowerCase().split(/[-_ ]+/);
    return ["power","combo"].some(t=>tokens.includes(t));
  };
  const isNetworkWaypoint = w => w.network_capable===true;
  const isDeploymentWaypoint = w => isElectricalEndpoint(w) || isNetworkWaypoint(w);
  function renderCableHistory() {
    const selector=$("test-pair"), prior=selector.value;
    const tests=data.linkiq_evidence || [];
    const chronology=new Map((data.flw_cable_tests || []).map(t=>[t.test_uuid,t]));
    // Reuse persisted intake proposals: source-declared endpoints do not create
    // reviewed cable bindings or route geometry. Resolved endpoints supply networks.
    const endpoints=t=>{
      if(t.endpoint_a && t.endpoint_b) return {key:[t.endpoint_a,t.endpoint_b].sort((a,b)=>a-b).join(":"),label:[t.endpoint_a,t.endpoint_b].sort((a,b)=>a-b).map(waypointName).join(" ↔ ")};
      const proposal=t.source_pair || {}, ids=proposal.endpoint_candidates || [];
      if(ids.length===2 && ids.every(x=>x.length===1) && ids[0][0]!==ids[1][0]) {
        const pair=ids.map(x=>x[0]).sort((a,b)=>a-b);return {key:pair.join(":"),label:pair.map(waypointName).join(" ↔ ")};
      }
      const labels=proposal.endpoint_labels || [];
      if(labels.length===2 && labels[0]!==labels[1]) {const pair=[...labels].sort();return {key:"label:"+JSON.stringify(pair),label:pair.join(" ↔ ")+" (source labels; waypoint match unresolved)"};}
      return {key:"unresolved",label:"Unparsed / ambiguous endpoint labels"};
    };
    const pairs=new Map(tests.map(t=>{const pair=endpoints(t);return [pair.key,pair.label];}));
    selector.replaceChildren(); el("option","Select endpoint pair",selector).value="";
    for(const [key,label] of pairs) el("option",label,selector).value=key;
    selector.value=prior;
    const root=$("test-history");root.replaceChildren();
    if(!tests.length) el("p","No retained cable tests.",root);
    const selected=tests.filter(t=>endpoints(t).key===selector.value);
    const cableKey=t=>t.cable_id ? `Physical cable ${t.cable_id}` : `Source designation ${chronology.get(t.test_uuid)?.network_key || t.source_pair?.designation || "unknown"} — physical cable unreviewed`;
    for(const key of new Set(selected.map(cableKey))) {
      const section=el("section",undefined,root);el("h3",key,section);
      for(const t of selected.filter(t=>cableKey(t)===key).sort((a,b)=>String(b.test_time||"").localeCompare(String(a.test_time||"")))) {
        const entry=el("article",undefined,section); entry.className="power-record";
        const dated=chronology.get(t.test_uuid);
        const clockUnset=!t.test_time || /^1970-/.test(t.test_time);
        el("h4",`${clockUnset ? "Tester date unset / unknown" : t.test_time} · ${t.test_uuid}`,entry);
        if(dated?.latest_reliably_dated) el("p",`Latest dated test${dated.has_unknown_test_order || dated.latest_time_tied ? " — test order uncertain" : ""}`,entry);
        if(dated?.has_unknown_test_order) el("p","This cable also has tests without a reliable date; their order cannot be established.",entry);
        el("p",`Raw result code: ${t.status_code ?? "Unknown"} · Standard: ${t.test_standard || "Unknown"} · Length: ${t.length_ft ?? "Unknown"} ft · Review: ${t.review_status || "Unknown"}`,entry);
        if(t.source_pair) el("p",`FLW source label: ${t.source_pair.display_label} · Designation: ${t.source_pair.designation || "Unknown"} · Source: ${t.source_pair.source_sha256 || "Unknown"}`,entry);
        el("p",`Original test name: ${t.original_name || "Unknown"} · First source SHA-256: ${t.source_sha256 || "Unknown"}`,entry);
      }
    }
  }
  $("test-pair").onchange=renderCableHistory;
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
        choose("show_desired_state", "Panel planned show-season supply", ["UNKNOWN","ON","OFF"]),
        choose("restoration_desired_state", "Panel planned off-season supply", ["UNKNOWN","ON","OFF"]),
        text("panel_name", "Readable panel name", true),
        text("panel_identification", "Panel identification / label"),
        {...text("branch_position_count", "Number of slots"), type:"number", min:1, max:200, hint:"Enter any whole number from 1 to 200, including 8 for FE-00. Numbered branch slots exclude the main. A two-pole breaker uses two slots. Leave blank if unknown."},
        select("site_waypoint_id", "Associated waypoint (optional)", waypoints),
        select("owner_name", "Panel owner (optional)", ownerOptions()),
        {...text("year_installed", "Year installed (optional)"), type: "number"},
        select("supply_panel_id", "Remote supply panel (optional)", options(data.panels.filter(p=>p.active).map(p=>[p.site_panel_id,p.panel_name]))),
        select("supply_breaker_id", "Remote feeder breaker (unknown allowed)", options(data.breakers.filter(b=>b.active).map(b=>[b.site_power_breaker_id,`${panel(b.site_panel_id)?.panel_name} / ${b.breaker_name}`]))),
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
        select("rated_amps", "Breaker rating (A)", ratingOptions()),
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
          "Season OFF required state",
          ["UNKNOWN", "ON", "OFF"],
        ),
      ],
      controller_power_connection: [
        select("controller_id","Existing controller inventory item",options((data.controller_options || []).map(c=>[c.id,`#${c.id} · ${c.model} · ${c.serial || "No serial"}`])),true),
        select("site_waypoint_id","Outlet waypoint",options(data.waypoints.filter(isElectricalEndpoint).map(w=>[w.id,w.name])),true),
        select("site_power_circuit_id","Supplying circuit leg",circuits,true),
      ],
      device: [
        select("device_name", "Equipment / model", equipmentNameOptions(), true),
        choose("device_kind", "Equipment type", [
          "FUSE",
          "DISCONNECT",
          "OUTLET",
          "LIGHT_POLE",
          "POWER_SUPPLY",
          "ETHERNET_SWITCH",
          "POE_SWITCH",
          "ETHERNET_EXTENDER",
          "ETHERNET_SPLITTER",
          "RS485_REPEATER",
          "OTHER",
        ]),
        select("site_waypoint_id", "Waypoint (optional)", waypoints),
        select("owner_name", "Equipment owner (optional)", ownerOptions()),
        text("utility_asset_id", "Existing utility asset reference (advanced)"),
        text("rating", "Existing rating (advanced)"),
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
      action: [
        select("site_panel_id", "Affected panel (choose exactly one target)", options(data.panels.map(p=>[p.site_panel_id,p.panel_name]))),
        text("action_name", "Activity name", true),
        select(
          "site_power_circuit_id",
          "Affected circuit (choose circuit OR equipment)",
          circuits,
        ),
        select("site_power_device_id", "Affected equipment", devices),
        select("site_power_breaker_id", "Affected breaker (choose exactly one target)", options((data.breakers || []).map(b => [b.site_power_breaker_id,b.breaker_name]))),
        select("phase", "Season mode", options([["SETUP","Season ON"],["OPERATION","Operation"],["RESTORATION","Season OFF"]]),true),
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
      if (spec.key === "device_name" && !value) {
        const o=el("option","Select equipment model",n);
        o.value=""; o.disabled=true; o.selected=true;
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
        n.min = spec.key === "year_installed" ? "1900" : ["breaker_pole","pole_count","rated_amps"].includes(spec.key) ? "1" : "0.000001";
        n.step = ["year_installed","breaker_pole","pole_count","rated_amps"].includes(spec.key) ? "1" : "any";
        if (spec.key === "branch_position_count") {n.min="1"; n.max="200"; n.step="1"; n.setAttribute("list","panel-slot-options");}
        if (spec.key === "year_installed") n.max="2100";
        if (spec.key === "rated_amps") n.setAttribute("list", "breaker-amp-options");
      }
    }
    if (spec.hint) {
      const hint=el("small",spec.hint,label);hint.id=`${spec.key}-hint`;
      n.setAttribute("aria-describedby",hint.id);
    }
    return n;
  }
  // The same port editor runs on both screens; no independent successor state.
  function openPorts(controllerId=null) {
    if(!data.access.can_edit)return;
    $("edit-form").hidden=true;
    const area=el("section",undefined,$("editor"));area.id="network-port-editor";
    const label=el("label","Controller",area), choice=el("select",undefined,label);choice.id="port-controller";
    el("option","Select controller",choice).value="";
    for(const c of data.controller_options)el("option",window.MSBControllerDeployment.controllerLabel(data,c.id),choice).value=c.id;
    choice.value=controllerId || "";
    const host=el("div",undefined,area);
    const show=()=>{if(choice.value)window.MSBControllerDeployment.render(Number(choice.value),host,Number($("detail-waypoint").value));};
    let selected=choice.value;
    choice.onchange=()=>{if(!window.MSBControllerDeployment.mayLeave()){choice.value=selected;return;}selected=choice.value;show();};
    button("Done",closePorts,area);
    $("editor").showModal();show();
  }
  function closePorts() {
    if(!window.MSBControllerDeployment.mayLeave())return;
    $("network-port-editor")?.remove();$("edit-form").hidden=false;$("editor").close();load();
  }
  function open(kind, row = {}) {
    if (!data.access.can_edit) return;
    pending = null;
    // New records always start active; hide the retirement control until an
    // existing record is deliberately corrected. Default remains DB-owned.
    edit = {
      kind, row,
      specs: specs(kind).filter((spec) => spec.key !== "active" || !!row[keys[kind]]),
    };
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
    if (kind === "device") {
      const form=$("edit-form"), model=form.elements.device_name, type=form.elements.device_kind;
      // One equipment-model choice automatically sets the governed type.
      // Existing site devices retain their recorded names and classification.
      const syncType=()=>{
        const selected=equipmentModels.find(x=>x[0]===model.value);
        const existing=data.devices.find(d=>d.device_name===model.value);
        const kind=selected?.[1] || existing?.device_kind;
        if(kind) type.value=kind;
      };
      model.addEventListener("change",syncType);
      syncType();
      type.closest("label").hidden=true;
      for(const name of ["utility_asset_id","rating"]) {
        if (!row[name]) form.elements[name].closest("label").hidden=true;
      }
      if(row.site_waypoint_id) form.elements.site_waypoint_id.closest("label").hidden=true;
      $("edit-title").textContent=row.site_power_device_id ? "Correct equipment" : "Add equipment";
    }
    if(kind==="panel") {
      const form=$("edit-form"), upstream=form.elements.supply_panel_id, feeder=form.elements.supply_breaker_id;
      for(const option of Array.from(upstream.options)) if(option.value===String(row.site_panel_id)) option.remove();
      const recorded=data.breakers.find(b=>b.site_power_breaker_id===row.supply_breaker_id);
      upstream.value=row.supply_panel_id || recorded?.site_panel_id || "";
      const refresh=()=>{
        const previous=feeder.value;feeder.replaceChildren();el("option","Unknown / not recorded",feeder).value="";
        data.breakers.filter(b=>b.active && b.site_panel_id!==row.site_panel_id && (!upstream.value || b.site_panel_id===Number(upstream.value))).forEach(b=>{el("option",`${panel(b.site_panel_id)?.panel_name} / ${b.breaker_name}`,feeder).value=b.site_power_breaker_id;});
        feeder.value=previous;
      };
      upstream.onchange=refresh;refresh();feeder.value=row.supply_breaker_id || "";
      feeder.onchange=()=>{const b=data.breakers.find(b=>b.site_power_breaker_id===Number(feeder.value));if(b){upstream.value=b.site_panel_id;refresh();}};
      el("p","A known remote panel can be saved before its feeder breaker is inventoried. Unknown breaker means the isolation point is still unresolved.",$("edit-fields"));
    }
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
    for (const name of ["panel_name","panel_identification","site_waypoint_id","owner_name","year_installed","branch_position_count","active"])
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
    field(select("rated_amps","Breaker rating (A)",ratingOptions()),row.rated_amps);
    const poles=field(select("pole_count","Poles",options([1,2,3].map(x=>[x,String(x)])),true),row.pole_count || (role==="MAIN"?2:1));
    field(text("source_evidence","Breaker notes / correction reason (optional)"),row.source_evidence);
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
    el("p","Save breaker settings. Waypoint assignment is optional: gate loads and receptacles at the panel can be recorded without a waypoint. Existing assignments and circuit IDs are retained.",$("edit-fields"));
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
          source_evidence:form.elements.source_evidence.value.trim() || null,
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
      `Circuit ${circuitName(c.site_power_circuit_id)} — notes and waypoints`;
    $("edit-fields").replaceChildren();
    $("save-status").textContent = "";
    $("save").disabled = false;
    el(
      "p",
      "Intermediate feed paths remain unchanged. Clear a selection to retire that direct relationship; its history is retained.",
      $("edit-fields"),
    );
    field(text("description", "Circuit notes (optional; no waypoint required)"), c.description);
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
    const owner=panel(c.site_panel_id);
    const prefix=(owner?.panel_name || "").toUpperCase().match(/(?:^|\s)([A-Z0-9]{2})-00(?:\s|$)/)?.[1] ||
      (wp(owner?.site_waypoint_id)?.name || "").toUpperCase().match(/(?:^|\s)([A-Z0-9]{2})-00(?:\s|$)/)?.[1];
    const matches=w=>!!prefix && [w.name,...(w.aliases||[])].some(n=>String(n).toUpperCase().startsWith(prefix+"-"));
    if(prefix) el("p",`${prefix} waypoints are listed first. Powered poles and other exceptions remain selectable. Prefixes do not assign a circuit.`,$("edit-fields"));
    el("p","A circuit may have no discovered waypoint, including non-show lighting. Keep its description and seasonal instructions; no waypoint does not mean no load.",$("edit-fields"));
    data.waypoints.filter(w=>isElectricalEndpoint(w) || direct.some(f=>f.destination_waypoint_id===w.id))
      .sort((a,b)=>Number(matches(b))-Number(matches(a)) || a.name.localeCompare(b.name,undefined,{numeric:true})).forEach((w) => {
      const l = el("label", undefined, list),
        i = el("input", undefined, l);
      i.type = "checkbox";
      i.name = "waypoint";
      i.value = w.id;
      i.checked = direct.some((f) => f.destination_waypoint_id === w.id);
      const competing = data.circuits.filter(other => other.active &&
        other.site_power_circuit_id !== c.site_power_circuit_id &&
        (!c.site_power_breaker_id || other.site_power_breaker_id !== c.site_power_breaker_id) &&
        paths(other.site_power_circuit_id).some(x => x.waypoint?.id === w.id));
      i.disabled = competing.length > 0 && !i.checked;
      if (competing.length) el("span", ` · Already supplied by ${competing.map(x => circuitName(x.site_power_circuit_id)).join(", ")}. Retire that supply before reassignment.`, l);
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
    // An explicit both-legs choice is offered only for a known two-leg breaker.
    // The other leg's unrelated waypoint assignments are never replaced.
    const siblings=data.circuits.filter(other=>
      other.active && c.site_power_breaker_id &&
      other.site_power_breaker_id===c.site_power_breaker_id &&
      other.site_power_circuit_id!==c.site_power_circuit_id);
    if (siblings.length===1 && data.breakers.some(b=>b.site_power_breaker_id===c.site_power_breaker_id && b.pole_count===2)) {
      const label=el("label","Also add checked waypoints to the other breaker leg (keep its existing destinations)",$("edit-fields"));
      const both=el("input",undefined,label);
      both.type="checkbox"; both.name="also_other_leg"; both.value=String(siblings[0].site_power_circuit_id);
      both.checked=false;
    }
    field(text("source_evidence", "Assignment correction note (optional)"), "");
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
      if (s.key === "branch_position_count" && v !== null && (!Number.isSafeInteger(v) || v<1 || v>200))
        throw new Error("Number of slots must be a whole number from 1 to 200.");
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
          // A circuit-description edit must leave unchanged feed evidence alone.
          if (old && !evidence.source_evidence) return;
          commands.push(
            command("feed", old?.site_power_feed_id, {
              ...evidence,
              source_circuit_id: edit.row.site_power_circuit_id,
              destination_waypoint_id: id,
            }),
          );
        });
        const description = form.elements.description.value.trim() || null;
        if (description !== (edit.row.description || null)) {
          commands.push(command("circuit", edit.row.site_power_circuit_id, {description}));
        }
        const both=form.elements.namedItem("also_other_leg");
        if (both?.checked) {
          const siblingId=Number(both.value);
          // This intentionally ADDS new direct feeds only; existing feeds on
          // the other leg, including unrelated destinations, are preserved.
          for (const id of selected) {
            if (!data.feeds.some(f=>f.active && f.source_circuit_id===siblingId && f.destination_waypoint_id===id)) {
              commands.push(command("feed",null,{...evidence,source_circuit_id:siblingId,destination_waypoint_id:id}));
            }
          }
        }
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
    if($("network-port-editor"))closePorts();else $("cancel").click();
  });
  $("connect-controller").onclick=()=>open("controller_power_connection",{site_waypoint_id:Number($("detail-waypoint").value)});
  $("install-controller").onclick=()=>openPorts();
  $("detail-waypoint").onchange=()=>render();
  $("reload").onclick = () => {if(stateSaving)return;statePending=null;stateControls();load();};
  $("retry-state").onclick=()=>recordState();
  $("breaker-report-filter").onchange=renderReports;
  $("show-breaker-report").onclick=()=>{$("breaker-report-rows").hidden=!$("breaker-report-rows").hidden;};
  $("find").oninput = () => data && render();
  $("season").onchange = () => {renderChecklist(); renderReports(); renderActions();};
  $("breaker-phase").onchange = () => {renderChecklist();renderReports();};
  $("breaker-filter").onchange = renderChecklist;
  $("print-breakers").onclick = () => window.print();
  let checklistWasOpen=false;
  window.addEventListener("beforeprint",()=>{checklistWasOpen=$("breaker-checklist").open;$("breaker-checklist").open=true;});
  window.addEventListener("afterprint",()=>{$("breaker-checklist").open=checklistWasOpen;});
  $("action-search").oninput = () => data && renderActions();
  for (const kind of ["panel", "device", "feed", "action"])
    $(`add-${kind}`).onclick = () => open(kind, kind === "device" ? {site_waypoint_id:Number($("detail-waypoint").value)||undefined} : {});
  // Expose pure relationship resolution only to the isolated browser harness.
  window.MSBPowerCapture = { paths };
  load();
})();
