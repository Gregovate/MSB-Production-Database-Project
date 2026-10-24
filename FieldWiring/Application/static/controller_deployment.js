/* Controller deployment edits reuse the waypoint snapshot and audited command
 * batch. No inventory location, LOR programming or GIS source is rewritten. */
"use strict";
(() => {
  let generation=0, dirty=false, pending=null, saving=false;
  const root=()=>document.getElementById("controller-deployment");
  const node=(tag,text,parent)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(parent)parent.append(n);return n;};
  const tokens=w=>String(w.type||"").toLowerCase().split(/[-_\s]+/);
  const power=w=>tokens(w).some(t=>["power","combo"].includes(t));
  const network=w=>tokens(w).some(t=>["network","net","combo"].includes(t));
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
  async function render(controllerId) {
    const ticket=++generation; dirty=false;pending=null;
    const host=root();host.replaceChildren();node("h3","Waypoint connections",host);
    const status=node("p","Loading deployment records…",host);status.setAttribute("role","status");
    try {
      const data=await api("api/power");if(ticket!==generation)return;
      const installation=data.controller_installations.find(x=>x.active&&x.controller_id===controllerId);
      const connection=data.controller_power_connections.find(x=>x.active&&x.controller_id===controllerId);
      const name=id=>data.waypoints.find(w=>w.id===id)?.name||`Waypoint ${id}`;
      const circuitName=id=>{const c=data.circuits.find(x=>x.site_power_circuit_id===id);return c ? `${data.panels.find(x=>x.site_panel_id===c.site_panel_id)?.panel_name||"Panel"} / ${c.circuit_code}` : `Circuit ${id}`;};
      node("p",`Network waypoint: ${installation ? name(installation.site_waypoint_id) : "Not connected"}`,host);
      node("p",`Power outlet: ${connection ? `${name(connection.site_waypoint_id)} · ${circuitName(connection.site_power_circuit_id)}` : "Not connected"}`,host);
      for(const id of new Set([installation?.site_waypoint_id,connection?.site_waypoint_id].filter(Boolean))) {
        const link=node("a",`Open ${name(id)}`,host);link.href=`waypoints?waypoint=${id}`;node("span"," · ",host);
      }
      const form=node("form",undefined,host); form.id="deployment-form";
      const choose=(id,label)=>{const l=node("label",label,form);l.style.display="block";const s=node("select",undefined,l);s.id=id;s.style.maxWidth="100%";node("option","Not connected",s).value="";return s;};
      const location=choose("deployment-network","Network waypoint ");
      const networkStatus=node("p",undefined,form);networkStatus.id="deployment-network-status";
      networkStatus.setAttribute("role","status");
      const outlet=choose("deployment-outlet","Power outlet waypoint ");
      const circuit=choose("deployment-circuit","Actual supplying circuit ");
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
          ? `No eligible network waypoints for ${requirement.lor_network || requirement.required_network}. Its reviewed GIS network path is missing or needs reconciliation.`
          : "No eligible network waypoints: this controller's current LOR network requirement is unresolved. Reconcile its Display assignments and LOR programming first.";
      // Preserve a recorded placement when its evidence later becomes unresolved;
      // it may be retained or disconnected, never silently reassigned.
      if(installation && !Array.from(location.options).some(o=>o.value===String(installation.site_waypoint_id))) {
        node("option",`${name(installation.site_waypoint_id)} — recorded; eligibility unresolved`,location).value=installation.site_waypoint_id;
      }
      location.value=installation?.site_waypoint_id||"";
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
      node("p","Network choices require current LOR programming and a reviewed GIS path. Power records the actual outlet and circuit separately. Choosing Not connected retires that connection and retains its history.",form);
      const save=node("button","Save connections",form);save.type="submit";save.id="deployment-save";
      const refresh=node("button","Reload connections",host);refresh.type="button";refresh.onclick=()=>{if(mayLeave())render(controllerId);};
      for(const s of [location,outlet,circuit,save])s.disabled=!data.access.can_edit;
      status.textContent=data.access.can_edit ? "Current shared waypoint records loaded." : "Read only";
      form.onchange=()=>{dirty=true;};
      form.onsubmit=async event=>{
        event.preventDefault();if(saving)return;
        if(!pending) {
          const retires=[],creates=[];
          const command=(kind,id,fields)=>({kind,id,fields,request_id:crypto.randomUUID()});
          const nextNetwork=Number(location.value)||null, nextOutlet=Number(outlet.value)||null, nextCircuit=Number(circuit.value)||null;
          if(nextOutlet&&!nextCircuit){status.textContent="Select the actual supplying circuit.";return;}
          if(nextNetwork!==(installation?.site_waypoint_id||null)) {
            if(installation)retires.push(command("controller_installation",installation.site_controller_installation_id,{active:false}));
            if(nextNetwork)creates.push(command("controller_installation",null,{controller_id:controllerId,site_waypoint_id:nextNetwork}));
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
          await api("api/power/commands",{method:"POST",headers:{"Content-Type":"application/json","X-MSB-Power-Command":"1"},body:JSON.stringify(pending)});
          pending=null;dirty=false;await render(controllerId);
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
  window.MSBControllerDeployment={render,mayLeave};
})();
