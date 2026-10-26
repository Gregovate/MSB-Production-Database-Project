/* Controller deployment edits reuse the waypoint snapshot and audited command
 * batch. No inventory location, LOR programming or GIS source is rewritten. */
"use strict";
(() => {
  let generation=0, dirty=false, pending=null, saving=false;
  const root=()=>document.getElementById("controller-deployment");
  // A page-local read snapshot, like Panel Circuits. Writes still use its revision.
  let snapshot=null, snapshotRequest=null, snapshotEpoch=0;
  function invalidate() {snapshot=null;snapshotRequest=null;snapshotEpoch++;}
  async function connectionSnapshot(shared) {
    if(!shared)return api("api/power?view=controller");
    if(snapshot)return snapshot;
    if(snapshotRequest)return snapshotRequest;
    const epoch=snapshotEpoch;
    const request=api("api/power?view=controller").then(data=>{
      if(epoch===snapshotEpoch)snapshot=data;
      return data;
    }).finally(()=>{if(snapshotRequest===request)snapshotRequest=null;});
    snapshotRequest=request;return request;
  }
  document.addEventListener("visibilitychange",()=>{if(document.hidden)invalidate();});
  const node=(tag,text,parent)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(parent)parent.append(n);return n;};
  const tokens=w=>String(w.type||"").toLowerCase().split(/[-_\s]+/);
  const power=w=>tokens(w).some(t=>["power","combo"].includes(t));
  const network=w=>w.network_capable===true;
  // Physical display assignments are already in the shared snapshot, even when
  // no power connection exists. Never substitute a wiring-source template name.
  const displayNames=(data,id)=>[...new Set((data.load_lineage || []).filter(x=>x.controller_id===Number(id)).map(x=>x.display_name).filter(Boolean))].sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));
  const displayText=(data,id)=>displayNames(data,id).join(" / ") || "No display assigned";
  const controllerLabel=(data,id)=>`CTRL ${id} — ${displayText(data,id)}`;
  const nameOrder=new Intl.Collator(undefined,{numeric:true,sensitivity:"base"});
  function compareControllers(aId,aName,bId,bName,mode) {
    if(mode==="display") {
      aName=String(aName||"").trim();bName=String(bName||"").trim();
      if(Boolean(aName)!==Boolean(bName))return aName ? -1 : 1;
      const byName=nameOrder.compare(aName,bName);if(byName)return byName;
    }
    return Number(aId)-Number(bId);
  }
  function sortPortOptions(select) {
    if(!select)return;
    const selected=select.value, mode=document.getElementById("controller-sort")?.value || "id";
    // Move existing options only: preserve eligibility, reconciliation labels,
    // special choices and dirty selections without dispatching a change event.
    const controllers=Array.from(select.options).filter(o=>/^\d+$/.test(o.value));
    controllers.sort((a,b)=>compareControllers(a.value,a.dataset.displayName,b.value,b.dataset.displayName,mode));
    select.append(...controllers);select.value=selected;
  }
  function sortPickers() {
    for(const id of ["deployment-upstream","deployment-out"])sortPortOptions(document.getElementById(id));
  }
  function controllerCell(data,id,row) {
    const cell=node("td",undefined,row);
    node("strong",`CTRL ${id}`,cell);
    const names=node("span",displayText(data,id),cell);names.className="controller-port-display";
    return cell;
  }
  async function api(path,options) {
    const response=await fetch(path,options);
    let body;
    try {body=await response.json();} catch (_) {throw new Error("Unreadable response; save outcome unknown.");}
    if(!response.ok){const e=new Error(body.error||"Request failed");e.status=response.status;throw e;}
    return body;
  }
  function mayLeave() {
    if(saving) return false;
    return !(dirty||pending) || confirm("Discard deployment edits? If a save outcome is unknown, reload the records before editing again.");
  }
  async function render(controllerId, mount=null, initialWaypoint=null) {
    const ticket=++generation; dirty=false;pending=null;
    const host=mount || root();host.replaceChildren();node("h3",`CTRL ${controllerId} · Network IN / OUT`,host);
    const status=node("p","Loading deployment records…",host);status.setAttribute("role","status");
    try {
      const data=await connectionSnapshot(host===root());if(ticket!==generation)return;
      const installation=data.controller_installations.find(x=>x.active&&x.controller_id===controllerId);
      const connection=data.controller_power_connections.find(x=>x.active&&x.controller_id===controllerId);
      const name=id=>data.waypoints.find(w=>w.id===id)?.name||`Waypoint ${id}`;
      const circuitName=id=>{const c=data.circuits.find(x=>x.site_power_circuit_id===id);return c ? `${data.panels.find(x=>x.site_panel_id===c.site_panel_id)?.panel_name||"Panel"} / ${c.circuit_code}` : `Circuit ${id}`;};
      node("p",`Network origin: ${installation ? name(installation.site_waypoint_id) : "Not connected"}`,host);
      node("p",`Power outlet: ${connection ? `${name(connection.site_waypoint_id)} · ${circuitName(connection.site_power_circuit_id)}` : "Not connected"}`,host);
      for(const id of new Set([installation?.site_waypoint_id,connection?.site_waypoint_id].filter(Boolean))) {
        const link=node("a",`Open ${name(id)}`,host);link.href=`waypoints?waypoint=${id}`;node("span"," · ",host);
      }
      const form=node("form",undefined,host); form.id="deployment-form";
      const choose=(id,label)=>{const l=node("label",label,form);l.style.display="block";const s=node("select",undefined,l);s.id=id;s.style.maxWidth="100%";node("option","Not connected",s).value="";return s;};
      const location=choose("deployment-network","Network origin waypoint ");
      const networkStatus=node("p",undefined,form);networkStatus.id="deployment-network-status";
      networkStatus.setAttribute("role","status");
      const upstream=choose("deployment-upstream","IN — cable comes from ");
      const ending=choose("deployment-out","OUT — cable goes to ");
      const outlet=choose("deployment-outlet","Power outlet waypoint ");
      const circuit=choose("deployment-circuit","Actual supplying circuit ");
      for(const control of [location,upstream,ending])control.closest("label").classList.add("connection-network");
      for(const control of [outlet,circuit])control.closest("label").classList.add("connection-power");
      const supplyStatus=node("p",undefined,form);supplyStatus.id="deployment-supply-status";
      supplyStatus.setAttribute("role","status");
      const supplyLink=node("a","Manage panel / circuit assignments",form);
      supplyLink.href="circuits";supplyLink.id="deployment-supply-link";supplyLink.hidden=true;
      const eligible=new Set(data.placement_eligibility.filter(x=>x.controller_id===controllerId).map(x=>x.site_waypoint_id));
      for(const w of data.waypoints.filter(w=>network(w)&&eligible.has(w.id))) node("option",`${w.name} (${w.type})`,location).value=w.id;
      // Explain the existing authority's result without widening eligibility.
      const requirement=(data.network_requirements || []).find(x=>x.controller_id===controllerId);
      const eligibleCount=Array.from(location.options).filter(o=>o.value).length;
      networkStatus.textContent=eligibleCount
        ? `${eligibleCount} eligible network waypoint(s) for ${requirement?.lor_network || "the current network"}.`
        : requirement?.requirement_status==="CONFIRMED"
          ? `No eligible network waypoints for ${requirement.lor_network || requirement.required_network}. Its FLW endpoint records are missing or need reconciliation.`
          : "No eligible network waypoints: this controller's current LOR network requirement is unresolved. Reconcile its Display assignments and LOR programming first.";
      // Preserve a recorded placement when its evidence later becomes unresolved;
      // it may be retained or disconnected, never silently reassigned.
      if(installation && !Array.from(location.options).some(o=>o.value===String(installation.site_waypoint_id))) {
        node("option",`${name(installation.site_waypoint_id)} — recorded; eligibility unresolved`,location).value=installation.site_waypoint_id;
      }
      location.value=installation?.site_waypoint_id || initialWaypoint || "";
      function orderChoices(select) {
        for(const option of select.options) {
          if(/^\d+$/.test(option.value))option.dataset.displayName=displayNames(data,option.value).join(" / ");
        }
        sortPortOptions(select);
      }
      function upstreamChoices(selected) {
        upstream.replaceChildren();
        node("option","Not recorded",upstream).value="UNKNOWN";
        node("option",location.value ? name(Number(location.value)) : "Select network origin first",upstream).value="WAYPOINT";
        const active=data.controller_installations.filter(i=>i.active);
        const descendants=new Set([controllerId]);
        for(let changed=true;changed;) {changed=false;for(const i of active) if(descendants.has(i.upstream_controller_id)&&!descendants.has(i.controller_id)){descendants.add(i.controller_id);changed=true;}}
        for(const i of active.filter(i=>i.site_waypoint_id===Number(location.value)&&!descendants.has(i.controller_id)&&i.chain_end==="UNKNOWN")) {
          const req=data.network_requirements.find(r=>r.controller_id===i.controller_id);
          if(req?.requirement_status!=="CONFIRMED"||req.required_network!==requirement?.required_network)continue;
          if(active.some(child=>child.upstream_controller_id===i.controller_id&&child.controller_id!==controllerId))continue;
          node("option",controllerLabel(data,i.controller_id),upstream).value=String(i.controller_id);
        }
        if(selected&&!Array.from(upstream.options).some(o=>o.value===String(selected))) node("option",`${controllerLabel(data,selected)} — recorded; reconcile connection`,upstream).value=selected;
        upstream.value=selected || "WAYPOINT";
        orderChoices(upstream);
      }
      upstreamChoices(installation ? (installation.upstream_controller_id || installation.upstream_kind || "UNKNOWN") : null);

      const successor=data.controller_installations.find(i=>i.active&&i.upstream_controller_id===controllerId);
      function outChoices(selected) {
        ending.replaceChildren();
        node("option","Not recorded",ending).value="UNKNOWN";
        node("option","Terminating resistor",ending).value="TERMINATOR";
        node("option",location.value ? `${name(Number(location.value))} — return cable` : "Return cable (select origin first)",ending).value="RETURN_TO_ORIGIN";
        const active=data.controller_installations.filter(i=>i.active), ancestors=new Set([controllerId]);
        let current=active.find(i=>i.controller_id===Number(upstream.value));
        while(current&&!ancestors.has(current.controller_id)){ancestors.add(current.controller_id);current=active.find(i=>i.controller_id===current.upstream_controller_id);}
        for(const c of data.controller_options) {
          if(ancestors.has(c.id))continue;
          const req=data.network_requirements.find(r=>r.controller_id===c.id);
          if(req?.requirement_status!=="CONFIRMED"||req.required_network!==requirement?.required_network)continue;
          if(!data.placement_eligibility.some(e=>e.controller_id===c.id&&e.site_waypoint_id===Number(location.value)))continue;
          const i=active.find(i=>i.controller_id===c.id);
          if(i&&(i.site_waypoint_id!==Number(location.value)||(i.upstream_kind!=="UNKNOWN"&&i.upstream_controller_id!==controllerId)))continue;
          node("option",controllerLabel(data,c.id),ending).value=String(c.id);
        }
        if(selected&&!Array.from(ending.options).some(o=>o.value===String(selected)))node("option",`${controllerLabel(data,selected)} — recorded; reconcile connection`,ending).value=selected;
        ending.value=selected || "UNKNOWN";
        orderChoices(ending);
      }
      outChoices(successor?.controller_id || installation?.chain_end);
      location.onchange=()=>{upstreamChoices(null);outChoices(null);};
      upstream.onchange=()=>outChoices(ending.value);
      const summary=node("table",undefined,host);summary.className="controller-port-summary";
      const headings=node("tr",undefined,node("thead",undefined,summary));for(const text of ["IN","Controller","OUT"])node("th",text,headings);
      const values=node("tr",undefined,node("tbody",undefined,summary));
      if(installation?.upstream_kind==="CONTROLLER")controllerCell(data,installation.upstream_controller_id,values);
      else node("td",installation?.upstream_kind==="WAYPOINT"?name(installation.site_waypoint_id):"Not recorded",values);
      controllerCell(data,controllerId,values);
      if(successor)controllerCell(data,successor.controller_id,values);
      else node("td",installation?.chain_end==="TERMINATOR"?"Terminating resistor":installation?.chain_end==="RETURN_TO_ORIGIN"?`${name(installation.site_waypoint_id)} — return`:"Not recorded",values);
      host.insertBefore(summary,form);
      const verification=node("p",`Wiring verification: ${installation?.verification_status || "UNVERIFIED"}`,host);
      host.insertBefore(verification,form);
      if(installation) {
        // Follow explicit controller links only; RETURN_TO_ORIGIN is an ending,
        // never another predecessor edge that would manufacture a closed ring.
        const active=data.controller_installations.filter(i=>i.active), seen=new Set();
        let first=installation;
        while(first.upstream_controller_id&&!seen.has(first.controller_id)) {
          seen.add(first.controller_id);
          const parent=active.find(i=>i.controller_id===first.upstream_controller_id);if(!parent)break;first=parent;
        }
        const labels=[first.upstream_kind==="WAYPOINT"?name(first.site_waypoint_id):"Upstream order not recorded"];
        seen.clear();let current=first;
        while(current&&!seen.has(current.controller_id)) {
          seen.add(current.controller_id);labels.push(controllerLabel(data,current.controller_id));
          const next=active.find(i=>i.upstream_controller_id===current.controller_id);
          if(!next)labels.push(current.chain_end==="TERMINATOR"?"Terminating resistor":current.chain_end==="RETURN_TO_ORIGIN"?`Return to ${name(current.site_waypoint_id)}`:"Ending not recorded");
          current=next;
        }
        const chain=node("ol",undefined,host);chain.id="deployment-chain";
        for(const label of labels){const item=node("li",label,chain);if(label===controllerLabel(data,controllerId))item.setAttribute("aria-current","true");}
      }

      for(const w of data.waypoints.filter(power)) node("option",`${w.name} (${w.type})`,outlet).value=w.id;
      if(connection&&!Array.from(outlet.options).some(o=>o.value===String(connection.site_waypoint_id))) node("option",`${name(connection.site_waypoint_id)} — recorded; reconcile capability`,outlet).value=connection.site_waypoint_id;
      outlet.value=connection?.site_waypoint_id||"";
      function circuits(selected) {
        circuit.replaceChildren();node("option",outlet.value ? "Select actual circuit" : "Not connected",circuit).value="";
        const ids=new Set(data.waypoint_power_sources.filter(x=>x.site_waypoint_id===Number(outlet.value)).map(x=>x.site_power_circuit_id));
        const available=data.circuits.filter(c=>c.active&&ids.has(c.site_power_circuit_id));
        supplyLink.hidden=!outlet.value;
        supplyStatus.textContent=!outlet.value ? "Select the actual power outlet to see its recorded circuits."
          : !available.length ? `No supplying circuit is recorded for ${name(Number(outlet.value))}. Assign this waypoint from Panel Circuits, then reload connections.`
          : `${available.length} supplying circuit(s) recorded. Select the circuit this controller actually plugs into.`;
        if(outlet.value&&!available.length) circuit.options[0].textContent="No supplying circuit recorded";
        for(const c of available) node("option",circuitName(c.site_power_circuit_id),circuit).value=c.site_power_circuit_id;
        if(selected&&!Array.from(circuit.options).some(o=>o.value===String(selected))) node("option",`${circuitName(selected)} — recorded; reconcile supply`,circuit).value=selected;
        circuit.value=selected||"";circuit.required=!!outlet.value;
      }
      circuits(connection?.site_power_circuit_id);
      outlet.onchange=()=>circuits(null);
      node("p","Network choices require current LOR programming and FLW endpoint/network evidence. Choose the actual IN and OUT. Selecting another controller updates both ends together. Changing OUT releases the previous controller’s IN to Not recorded; it does not invent replacement wiring. Occupied ports must be reconciled first. Saved wiring remains unverified. Power records the actual outlet and circuit separately. Choosing Not connected retires that connection and retains its history.",form);
      const save=node("button","Save connections",form);save.type="submit";save.id="deployment-save";save.className="equipment-save";
      const refresh=node("button","Reload connections",host);refresh.type="button";refresh.className="deployment-reload";refresh.onclick=()=>{if(mayLeave()){invalidate();render(controllerId,host,initialWaypoint);}};
      for(const s of [location,upstream,ending,outlet,circuit,save])s.disabled=!data.access.can_edit;
      status.textContent=`Loaded connection revision ${data.revision}. Reload connections for newer records.${data.access.can_edit ? "" : " Read only."}`;
      form.onchange=()=>{dirty=true;};
      form.onsubmit=async event=>{
        event.preventDefault();if(saving)return;
        if(!pending) {
          const retires=[],creates=[];
          const command=(kind,id,fields)=>({kind,id,fields,request_id:crypto.randomUUID()});
          const nextNetwork=Number(location.value)||null, nextOutlet=Number(outlet.value)||null, nextCircuit=Number(circuit.value)||null;
          if(nextOutlet&&!nextCircuit){status.textContent="Select the actual supplying circuit.";return;}
          const inKind=nextNetwork ? (["UNKNOWN","WAYPOINT"].includes(upstream.value)?upstream.value:"CONTROLLER") : "UNKNOWN";
          const outKind=nextNetwork ? (["UNKNOWN","TERMINATOR","RETURN_TO_ORIGIN"].includes(ending.value)?ending.value:"CONTROLLER") : "UNKNOWN";
          const ports={site_waypoint_id:nextNetwork,in_kind:inKind,in_controller_id:nextNetwork?(Number(upstream.value)||null):null,out_kind:outKind,out_controller_id:nextNetwork?(Number(ending.value)||null):null};
          const oldOut=successor ? "CONTROLLER" : (installation?.chain_end || "UNKNOWN");
          if(nextNetwork!==(installation?.site_waypoint_id||null)||inKind!==(installation?.upstream_kind||"UNKNOWN")||ports.in_controller_id!==(installation?.upstream_controller_id||null)||outKind!==oldOut||ports.out_controller_id!==(successor?.controller_id||null)) {
            creates.push(command("controller_ports",controllerId,ports));
          }
          if(nextOutlet!==(connection?.site_waypoint_id||null)||nextCircuit!==(connection?.site_power_circuit_id||null)) {
            if(connection)retires.push(command("controller_power_connection",connection.site_controller_power_connection_id,{active:false}));
            if(nextOutlet)creates.push(command("controller_power_connection",null,{controller_id:controllerId,site_waypoint_id:nextOutlet,site_power_circuit_id:nextCircuit}));
          }
          if(!retires.length&&!creates.length){dirty=false;status.textContent="No connection changes.";return;}
          pending={revision:data.revision,commands:[...retires,...creates]};
        }
        saving=true;save.disabled=true;refresh.disabled=true;status.textContent="Saving connections…";
        try {
          invalidate(); // A failed response can still mean the server committed.
          await api("api/power/commands",{method:"POST",headers:{"Content-Type":"application/json","X-MSB-Power-Command":"1"},body:JSON.stringify(pending)});
          pending=null;dirty=false;await render(controllerId,host,initialWaypoint);
        } catch(e) {
          status.textContent=e.message;
          if(e.status&&e.status<500) {
            pending=null;
            if(e.status===409){status.textContent+=" Records changed. Reload connections before editing again.";form.querySelectorAll("select").forEach(s=>s.disabled=true);save.dataset.stale="1";}
          } else {
            status.textContent+=" Save outcome unknown. Retry Save connections resends the identical request safely, or reload to inspect.";
            form.querySelectorAll("select").forEach(s=>s.disabled=true);
          }
        } finally {saving=false;save.disabled=save.dataset.stale==="1";refresh.disabled=false;}
      };
    } catch(e){if(ticket===generation)status.textContent=e.message;}
  }
  window.addEventListener("beforeunload",e=>{if(dirty||pending||saving){e.preventDefault();e.returnValue="";}});
  window.MSBControllerDeployment={render,mayLeave,invalidate,controllerLabel,controllerCell,compareControllers,sortPickers};
})();
