/* Equipment history reuses device IDs and the existing revisioned command API. */
"use strict";
window.MSBEquipmentCapture = (() => {
  const el=(tag,text,parent)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;parent?.append(n);return n;};
  const infrastructureKinds=new Set(['FUSE','DISCONNECT','OUTLET','LIGHT_POLE']);
  const isAdditionalDevice=device=>!infrastructureKinds.has(device.device_kind);
  // Installation capability comes from maintained waypoint type, not LOR evidence.
  const isEquipmentWaypoint=waypoint=>String(waypoint?.type||'').toLowerCase()
    .split(/[-_\s]+/).some(token=>['power','network','combo'].includes(token));
  function waypointChoices(data,recordedIds=[]) {
    const recorded=new Set(recordedIds);
    return data.waypoints.filter(w=>isEquipmentWaypoint(w)||recorded.has(w.id))
      .map(w=>[w.id,`${w.name} (${w.type})${isEquipmentWaypoint(w)?'':' — recorded; reconcile location'}`]);
  }
  function render(data,device,host,reload) {
    const events=(data.equipment_events||[]).filter(e=>e.site_power_device_id===device.site_power_device_id).sort((a,b)=>b.event_id-a.event_id);
    const corrected=new Set(events.map(e=>e.corrects_event_id));
    const latest=events.find(e=>e.event_kind==='TEST'&&!corrected.has(e.event_id));
    el('p',`Condition: ${latest?.condition||'UNTESTED'} · Equipment #${device.site_power_device_id}`,host);
    const wp=id=>data.waypoints.find(w=>w.id===id)?.name||'Uninstalled / spares';
    function open(kind,corrects=null) {
      const dialog=el('dialog',undefined,document.body),form=el('form',undefined,dialog);
      el('h2',`${kind==='TEST'?'Record test':kind==='MOVE'?'Move / remove':'Replace'} — ${device.device_name}`,form);
      const input=(name,label,type='text')=>{const n=el('input',undefined,el('label',label,form));n.name=name;n.type=type;return n;};
      const select=(name,label,rows)=>{const n=el('select',undefined,el('label',label,form));n.name=name;for(const [value,text] of rows)el('option',text,n).value=value;return n;};
      let condition,date,destination,replacement;
      if(kind==='TEST') {condition=select('condition','Test result',[['UNTESTED','Untested'],['WORKING','Working'],['FAILED','Failed']]); date=input('observed_at','Test date/time (leave blank if unknown)','datetime-local');const now=new Date();date.value=new Date(now-now.getTimezoneOffset()*60000).toISOString().slice(0,16);}
      if(kind==='MOVE')destination=select('destination','Install at / move to',[['','Uninstalled / spares'],...waypointChoices(data)]);
      if(kind==='REPLACE') {el('p','Select an existing spare. Add an unrecorded replacement to inventory first. Connections are not transferred automatically.',form);replacement=select('replacement','Replacement device',[['','Select spare'],...data.devices.filter(d=>isAdditionalDevice(d)&&d.active&&!d.site_waypoint_id&&d.site_power_device_id!==device.site_power_device_id).map(d=>[d.site_power_device_id,`#${d.site_power_device_id} · ${d.device_name}`])]);replacement.required=true;}
      const notes=input('notes','Notes (optional)');notes.maxLength=4000;
      const status=el('p','',form);status.setAttribute('role','alert');
      const save=el('button','Save',form);save.type='submit';save.className='equipment-save';
      const cancel=el('button','Cancel',form);cancel.type='button';
      let pending=null,busy=false;
      const close=()=>{if(busy)return;if(pending&&!confirm('Save outcome may be unknown. Close and reload records?'))return;dialog.close();dialog.remove();reload();};
      cancel.onclick=close;dialog.addEventListener('cancel',e=>{e.preventDefault();close();});
      form.onsubmit=async e=>{e.preventDefault();if(busy)return;
        if(!pending){const fields={event_kind:kind,notes:notes.value};if(kind==='TEST'){fields.condition=condition.value;fields.observed_at=date.value?new Date(date.value).toISOString():null;if(corrects)fields.corrects_event_id=corrects;}
          if(kind==='MOVE')fields.to_waypoint_id=destination.value?Number(destination.value):null;
          if(kind==='REPLACE')fields.replacement_device_id=Number(replacement.value);
          pending={revision:data.revision,commands:[{kind:'equipment_event',id:device.site_power_device_id,request_id:crypto.randomUUID(),fields}]};}
        busy=true;save.disabled=true;cancel.disabled=true;form.querySelectorAll('input,select').forEach(n=>n.disabled=true);
        try {const response=await fetch('api/power/commands',{method:'POST',headers:{'Content-Type':'application/json','X-MSB-Power-Command':'1'},body:JSON.stringify(pending)});const result=await response.json();
          if(!response.ok){if(response.status<500){pending=null;form.querySelectorAll('input,select').forEach(n=>n.disabled=false);}if(response.status===409){save.dataset.stale='1';}throw Error(result.error||'Save rejected');}
          pending=null;dialog.close();dialog.remove();reload();
        }catch(error){status.textContent=error.message+(pending?' Retry Save resends the identical request, or Cancel and reload to inspect.':save.dataset.stale?' Close and reload current records.':'');}
        finally{busy=false;save.disabled=!!save.dataset.stale;cancel.disabled=false;}
      };dialog.showModal();
    }
    if(data.access.can_edit&&device.active&&Array.isArray(data.equipment_events))for(const [kind,label] of [['TEST','Record test / failure'],['MOVE','Move / remove'],['REPLACE','Replace']]){const b=el('button',label,host);b.type='button';b.onclick=()=>open(kind);}
    if(!Array.isArray(data.equipment_events))el('p','Equipment history is unavailable until its database release is installed.',host);
    const history=el('details',undefined,host);el('summary',`Equipment history (${events.length})`,history);
    for(const e of events){const row=el('article',undefined,history);el('p',`${e.event_kind} ${e.condition||''} · ${e.observed_at?new Date(e.observed_at).toLocaleString():'Date unknown'} · ${e.operator_name||'Name unavailable'}${corrected.has(e.event_id)?' · Corrected':''}`,row);
      el('p',`${wp(e.from_waypoint_id)} → ${wp(e.to_waypoint_id)}${e.replacement_device_id?` · Replaced by equipment #${e.replacement_device_id}`:''} · ${e.notes||''}`,row);
      if(e.event_kind==='TEST'&&!corrected.has(e.event_id)&&data.access.can_edit&&device.active){const b=el('button','Correct test',row);b.type='button';b.onclick=()=>open('TEST',e.event_id);}}
    const incoming=(data.equipment_events||[]).filter(e=>e.replacement_device_id===device.site_power_device_id);
    incoming.forEach(e=>el('p',`Installed as replacement for equipment #${e.site_power_device_id} · ${new Date(e.recorded_at).toLocaleString()}`,history));
  }
  // Models are reference records; owned units always remain in site_power_device.
  function manage(data,waypointId,reload,mode=waypointId?'install':'inventory',row=null) {
    const dialog=el('dialog',undefined,document.body),form=el('form',undefined,dialog);
    const title={install:'Install Equipment',inventory:'Add new item to inventory',model:'Add equipment model',type:'Add equipment type',correct:'Correct equipment'}[mode];
    el('h2',title,form);
    if(waypointId)el('p',`Waypoint: ${data.waypoints.find(w=>w.id===waypointId)?.name||waypointId}`,form);
    const field=(tag,name,label)=>{const n=el(tag,undefined,el('label',label,form));n.name=name;return n;};
    const select=(name,label,choices)=>{const n=field('select',name,label);for(const [value,text] of choices)el('option',text,n).value=value;n.required=true;return n;};
    const input=(name,label)=>{const n=field('input',name,label);n.required=true;return n;};
    const jump=(label,next)=>{const b=el('button',label,form);b.type='button';b.onclick=()=>{dialog.remove();manage(data,waypointId,reload,next);};};
    let model,type,name,quantity,unitChoice,units=[],notes;
    if(['install','inventory'].includes(mode)) {
      if(!Array.isArray(data.equipment_models)){el('p','Equipment catalog release is required.',form);const close=el('button','Close',form);close.type='button';close.onclick=()=>dialog.remove();dialog.showModal();return;}
      const spare=data.devices.filter(d=>isAdditionalDevice(d)&&d.active&&!d.site_waypoint_id);
      const choices=mode==='install'? [...new Map(spare.map(d=>[d.equipment_model_id?`model:${d.equipment_model_id}`:`legacy:${d.device_kind}:${d.device_name}`,d])).entries()].map(([key,d])=>[key,`${d.device_name} · ${d.device_kind.replaceAll('_',' ')}`]):data.equipment_models.map(m=>[m.equipment_model_id,`${m.model_name} · ${m.device_kind.replaceAll('_',' ')}`]);
      model=select('model','Equipment model',[['','Select model'],...choices]);
      quantity=input('quantity','Quantity');quantity.type='number';quantity.min='1';quantity.max='100';quantity.step='1';quantity.value='1';
      if(mode==='install') {
        const stock=el('p','Select a model to see available spares.',form);
        unitChoice=select('units','Spare units to install',[]);unitChoice.multiple=true;unitChoice.size=4;
        model.onchange=()=>{units=spare.filter(d=>(d.equipment_model_id?`model:${d.equipment_model_id}`:`legacy:${d.device_kind}:${d.device_name}`)===model.value).sort((a,b)=>a.site_power_device_id-b.site_power_device_id);stock.textContent=units.length?`${units.length} spare(s): ${units.map(d=>'#'+d.site_power_device_id).join(', ')}`:'No spares available';quantity.max=String(Math.max(1,units.length));unitChoice.replaceChildren();for(const d of units)el('option',`#${d.site_power_device_id} · ${d.device_name}`,unitChoice).value=d.site_power_device_id;quantity.oninput();};
        quantity.oninput=()=>Array.from(unitChoice.options).forEach((o,i)=>o.selected=i<Number(quantity.value));
        jump('Add new item to inventory','inventory');
      } else jump('Add new equipment model','model');
    } else if(mode==='model') {
      name=input('model_name','Model name');name.maxLength=200;
      type=select('device_kind','Equipment type',[['','Select type'],...(data.equipment_types||[]).map(t=>[t.device_kind,t.type_name])]);
      jump('Add new equipment type','type');
    } else if(mode==='type') {name=input('type_name','Equipment type name');name.maxLength=100;}
    else {name=input('device_name','Equipment name');name.value=row.device_name;name.maxLength=200;}
    if(['install','inventory','correct'].includes(mode)){notes=field('textarea','notes','Notes (optional)');notes.maxLength=4000;notes.value=row?.description||'';}
    const status=el('p','',form);status.setAttribute('role','alert');
    const save=el('button','Save',form);save.type='submit';save.className='equipment-save';
    const cancel=el('button','Cancel',form);cancel.type='button';
    let pending=null,busy=false,stale=false,completed=false;
    const close=()=>{if(busy)return;if(pending&&!confirm('Save outcome may be unknown. Close and reload records?'))return;dialog.remove();reload();};
    cancel.onclick=close;dialog.addEventListener('cancel',e=>{e.preventDefault();close();});
    form.onsubmit=async e=>{e.preventDefault();if(busy||stale||completed)return;
      if(!pending){
        const command=(kind,id,fields)=>({kind,id,fields,request_id:crypto.randomUUID()});let commands;
        if(mode==='install') {
          const qty=Number(quantity.value);
          if(!Number.isInteger(qty)||qty<1||qty>units.length||qty>100){status.textContent='Choose a quantity within available stock.';return;}
          const selected=new Set(Array.from(unitChoice.selectedOptions,o=>Number(o.value)));
          if(selected.size!==qty){status.textContent='Select the same number of spare units as the quantity.';return;}
          commands=units.filter(d=>selected.has(d.site_power_device_id)).map(d=>command('equipment_event',d.site_power_device_id,{event_kind:'MOVE',to_waypoint_id:waypointId,notes:notes.value}));
        } else if(mode==='inventory')commands=[command('equipment_inventory',null,{equipment_model_id:Number(model.value),quantity:Number(quantity.value),notes:notes.value})];
        else if(mode==='model')commands=[command('equipment_model',null,{device_kind:type.value,model_name:name.value})];
        else if(mode==='type')commands=[command('equipment_type',null,{type_name:name.value})];
        else commands=[command('device',row.site_power_device_id,{device_name:name.value,description:notes.value})];
        pending={revision:data.revision,commands};
      }
      busy=true;form.querySelectorAll('input,select,textarea,button').forEach(n=>n.disabled=true);
      try {
        const response=await fetch('api/power/commands',{method:'POST',headers:{'Content-Type':'application/json','X-MSB-Power-Command':'1'},body:JSON.stringify(pending)}),result=await response.json();
        if(!response.ok){if(response.status<500)pending=null;stale=response.status===409;throw Error(result.error||'Save rejected');}
        pending=null;completed=true;
        if(['inventory','model','type'].includes(mode)) {
          const fresh=await fetch('api/power');if(!fresh.ok)throw Error('Saved. Reload records before continuing.');
          const updated=await fresh.json();dialog.remove();reload();
          manage(updated,waypointId,reload,mode==='type'?'model':mode==='model'?'inventory':waypointId?'install':'inventory');
        } else {dialog.remove();reload();}
      }catch(error){status.textContent=error.message+(pending?' Retry Save resends the identical request.':stale?' Close and reload current records.':'');}
      finally {busy=false;form.querySelectorAll('input,select,textarea,button').forEach(n=>n.disabled=!!pending);save.disabled=stale||completed;cancel.disabled=false;}
    };
    dialog.showModal();
  }

  return {manage,render,isAdditionalDevice,isEquipmentWaypoint,waypointChoices};
})();
