/* Read-only browsing of retained test evidence; never invent speed or topology. */
"use strict";
window.MSBCableHistory=(()=>{
 const el=(tag,text,parent)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;parent?.append(n);return n;};
 const cache=new WeakMap();
 const networkKey=value=>String(value||'').trim().toUpperCase().replace(/^AUX[ -]+([A-Z])$/, 'AUX-$1');
 // Records.Standard is a saved test standard, never negotiated throughput.
 function speedLabel(test){
   const standard=String(test.test_standard||'').trim();
   if(!standard)return 'Not recorded';
   const match=/^(10|100|1000|2\.5G|5G|10G)BASE-T(?:X)?$/i.exec(standard);
   if(!match)return 'Not recorded';
   const rate=/G$/i.test(match[1])?parseFloat(match[1])*1000:Number(match[1]);
   return `${rate} Mbps`;
 }
 function rows(data){
 if(cache.has(data))return cache.get(data);
 const dated=new Map((data.flw_cable_tests||[]).map(t=>[t.test_uuid,t]));
 const waypoints=new Map((data.waypoints||[]).map(w=>[Number(w.id),w.name]));
 const identities=new Map();for(const w of data.waypoints||[])for(const label of [w.name,...(w.aliases||[])]){const k=String(label).trim().toUpperCase();if(!identities.has(k))identities.set(k,new Set());identities.get(k).add(Number(w.id));}
 const resolve=label=>{const matches=identities.get(String(label||'').trim().toUpperCase());return matches?.size===1?[...matches][0]:null;};
 const catalog=new Map();for(const n of data.network_options||[]){const key=networkKey(n.network_code);if(!catalog.has(key))catalog.set(key,[]);catalog.get(key).push(n.network_code);}
 const byCable=new Map();for(const t of data.flw_cable_tests||[]){if(!t.physical_site_cable_id)continue;if(!byCable.has(t.physical_site_cable_id))byCable.set(t.physical_site_cable_id,new Set());if(t.network_key)byCable.get(t.physical_site_cable_id).add(t.network_key);}
 const result=(data.linkiq_evidence||[]).map(t=>{const d=dated.get(t.test_uuid),p=t.source_pair||{};const candidates=p.endpoint_candidates||[];
 let ids=(d?[d.endpoint_a,d.endpoint_b]:t.endpoint_a&&t.endpoint_b?[t.endpoint_a,t.endpoint_b]:candidates.length===2&&candidates.every(x=>x.length===1)?candidates.map(x=>x[0]):[]).map(Number);
 const sourceLabels=p.endpoint_labels?.length===2?p.endpoint_labels:null;
 if(ids.length!==2&&sourceLabels)ids=sourceLabels.map(resolve);
 const labels=ids.length===2?ids.map((id,i)=>waypoints.get(id)||sourceLabels?.[i]||(id?`Waypoint ${id}`:'Unresolved')):sourceLabels||['Unresolved','Unresolved'];
 const known=[...(byCable.get(t.cable_id)||[])];
 const designation=d?.network_key||(known.length===1?known[0]:null)||p.designation||'';
 const matches=catalog.get(networkKey(designation))||[];
 const network=matches.length===1?matches[0]:'Unresolved';
 const reliable=d?d.reliable_test_time:(t.test_time&&!/^(?:19[0-6][0-9]|1970)-/.test(t.test_time)?t.test_time:null);
 const points=labels.flatMap((label,i)=>label==='Unresolved'?[]:[{value:ids[i]?String(ids[i]):`label:${label}`,label:ids[i]?label:`Unresolved label: ${label}`}]);
 const pair=[...labels].sort().join(' ↔ ');const key=t.cable_id?`cable:${t.cable_id}`:ids.length===2||sourceLabels?`${networkKey(designation)}:${pair}`:`unresolved:${t.test_uuid}`;
 return {...t,ids,labels,points,designation,network,pair,key,reliable,uncertain:d?.has_unknown_test_order||!reliable};});
 cache.set(data,result);return result;}
 function pointOptions(all){const points=new Map();for(const t of all)for(const p of t.points)points.set(p.value,p.label);return [...points].sort((a,b)=>a[1].localeCompare(b[1],undefined,{numeric:true}));}
 function resultLabel(test){return ['PASS','FAIL'].includes(test.result)?test.result:'Not decoded';}
 function dateLabel(value){
   if(!value)return 'Date unknown';
   // Display the saved tester-local wall clock without applying the browser timezone.
   const m=/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?/.exec(value);
   if(!m)return 'Date unknown';
   const date=new Date(Date.UTC(+m[1],+m[2]-1,+m[3],+(m[4]||0),+(m[5]||0)));
   return new Intl.DateTimeFormat('en-US',{timeZone:'UTC',month:'short',day:'numeric',year:'numeric',...(m[4]?{hour:'numeric',minute:'2-digit'}:{})}).format(date);
 }
 const displayPoints=t=>t.labels.map((label,i)=>t.ids[i]?label:`Unresolved: ${label}`);
 const newest=(a,b)=>String(b.reliable||'').localeCompare(String(a.reliable||''))||String(a.test_uuid).localeCompare(String(b.test_uuid));
 function render(data,root){
   root._cableData=data;
   if(!root.dataset.ready){root.dataset.ready='1';const controls=el('div',undefined,root);controls.className='power-toolbar';
     const network=el('select',undefined,el('label','Network',controls));network.dataset.filter='network';
     const search=el('input',undefined,el('label','Find test point',controls));search.type='search';search.placeholder='Type LP-, CL-10…';search.dataset.filter='search';
     const waypoint=el('select',undefined,el('label','Cable test point / waypoint',controls));waypoint.dataset.filter='waypoint';
     for(const n of [network,waypoint])n.onchange=()=>{root.dataset.segment='';render(root._cableData,root);};
     search.oninput=()=>{waypoint.value='';root.dataset.segment='';render(root._cableData,root);};
     el('div',undefined,root).className='cable-results';
     const comparison=el('section',undefined,root);comparison.className='cable-comparison';comparison.setAttribute('aria-live','polite');
   }
   const all=rows(data),network=root.querySelector('[data-filter="network"]'),waypoint=root.querySelector('[data-filter="waypoint"]'),search=root.querySelector('[data-filter="search"]');
   function fill(s,options){const prior=s.value;s.replaceChildren();el('option','All',s).value='';for(const [v,l] of options)el('option',l,s).value=v;s.value=prior;if(s.selectedIndex<0)s.value='';}
   fill(network,[...new Set(all.map(t=>t.network))].sort().map(x=>[x,x]));
   const scoped=all.filter(t=>!network.value||t.network===network.value),query=search.value.trim().toLowerCase();
   fill(waypoint,pointOptions(scoped).filter(p=>p[1].toLowerCase().includes(query)));
   if(!root.dataset.linkApplied){waypoint.value=new URLSearchParams(location.search).get('waypoint')||'';root.dataset.linkApplied='1';}
   const filtered=scoped.filter(t=>(!waypoint.value||t.points.some(p=>p.value===waypoint.value))&&(!query||t.points.some(p=>p.label.toLowerCase().includes(query))));
   const host=root.querySelector('.cable-results');host.replaceChildren();
   const comparison=root.querySelector('.cable-comparison');comparison.replaceChildren();
   if(!filtered.length){el('p','No cable tests match these filters.',host);return;}
   const groups=new Map();for(const t of filtered){if(!groups.has(t.key))groups.set(t.key,[]);groups.get(t.key).push(t);}
   const columns=[['network','Network',t=>t.network],['a','Test point A',t=>t.labels[0]],['b','Test point B',t=>t.labels[1]],['length','Length (ft)',t=>t.length_ft??null],['speed','Speed (Mbps)',t=>{const n=parseFloat(speedLabel(t));return Number.isFinite(n)?n:null;}],['result','Result',resultLabel],['date','Test date/time',t=>t.reliable]];
   const sort=root.dataset.sort||'date',direction=root.dataset.direction||'desc',column=columns.find(c=>c[0]===sort);
   const ordered=[...groups.values()].map(g=>g.sort(newest)).sort((a,b)=>{const av=column[2](a[0]),bv=column[2](b[0]);if(av==null||bv==null)return av==null?(bv==null?0:1):-1;const cmp=typeof av==='number'?av-bv:String(av).localeCompare(String(bv),undefined,{numeric:true});return (direction==='asc'?cmp:-cmp)||newest(a[0],b[0]);});
   el('p',`${groups.size} segment(s) · ${filtered.length} test(s). Newest dated result per segment.`,host);
   const scroll=el('div',undefined,host);scroll.className='cable-table-scroll';
   const table=el('table',undefined,scroll);table.className='cable-test-table';const head=el('tr',undefined,el('thead',undefined,table));
   for(const [key,label] of columns){const th=el('th',undefined,head);th.setAttribute('aria-sort',key===sort?(direction==='asc'?'ascending':'descending'):'none');const b=el('button',label+(key===sort?(direction==='asc'?' ↑':' ↓'):''),th);b.type='button';b.onclick=()=>{root.dataset.sort=key;root.dataset.direction=key===sort&&direction==='asc'?'desc':'asc';render(data,root);};}
   el('th','History',head);const body=el('tbody',undefined,table);
   function compare(group){comparison.replaceChildren();root.dataset.segment=group[0].key;el('h3',`${group[0].network}: ${displayPoints(group[0]).join(' ↔ ')}`,comparison);const wrap=el('div',undefined,comparison);wrap.className='cable-table-scroll';const grid=el('table',undefined,wrap);grid.className='cable-test-table';const header=el('tr',undefined,el('thead',undefined,grid));['Date/time','Length (ft)','Speed (Mbps)','Result'].forEach(v=>el('th',v,header));const tbody=el('tbody',undefined,grid);for(const t of group){const tr=el('tr',undefined,tbody);[dateLabel(t.reliable),t.length_ft??'Not recorded',speedLabel(t).replace(' Mbps',''),resultLabel(t)].forEach(v=>el('td',v,tr));}}
   for(const group of ordered){const t=group[0],tr=el('tr',undefined,body);[t.network,...displayPoints(t),t.length_ft??'Not recorded',speedLabel(t).replace(' Mbps',''),resultLabel(t),dateLabel(t.reliable)].forEach(v=>el('td',v,tr));const b=el('button',`Compare tests (${group.length})`,el('td',undefined,tr));b.type='button';b.onclick=()=>compare(group);if(root.dataset.segment===t.key)compare(group);}
 }
 return {rows,pointOptions,speedLabel,resultLabel,dateLabel,render};
})();
