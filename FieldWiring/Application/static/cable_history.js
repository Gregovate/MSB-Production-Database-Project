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
   if(!match)return standard;
   const rate=/G$/i.test(match[1])?parseFloat(match[1])*1000:Number(match[1]);
   return `${rate} Mbps · ${standard}`;
 }
 function rows(data){
 if(cache.has(data))return cache.get(data);
 const dated=new Map((data.flw_cable_tests||[]).map(t=>[t.test_uuid,t]));
 const waypoints=new Map((data.waypoints||[]).map(w=>[Number(w.id),w.name]));
 const catalog=new Map();for(const n of data.network_options||[]){const key=networkKey(n.network_code);if(!catalog.has(key))catalog.set(key,[]);catalog.get(key).push(n.network_code);}
 const byCable=new Map();for(const t of data.flw_cable_tests||[]){if(!t.physical_site_cable_id)continue;if(!byCable.has(t.physical_site_cable_id))byCable.set(t.physical_site_cable_id,new Set());if(t.network_key)byCable.get(t.physical_site_cable_id).add(t.network_key);}
 const result=(data.linkiq_evidence||[]).map(t=>{const d=dated.get(t.test_uuid),p=t.source_pair||{};const candidates=p.endpoint_candidates||[];
 const ids=(d?[d.endpoint_a,d.endpoint_b]:t.endpoint_a&&t.endpoint_b?[t.endpoint_a,t.endpoint_b]:candidates.length===2&&candidates.every(x=>x.length===1)?candidates.map(x=>x[0]):[]).map(Number);
 const sourceLabels=p.endpoint_labels?.length===2?p.endpoint_labels:null;
 const labels=ids.length===2?ids.map((id,i)=>waypoints.get(id)||sourceLabels?.[i]||`Waypoint ${id}`):sourceLabels||['Unresolved','Unresolved'];
 const known=[...(byCable.get(t.cable_id)||[])];
 const designation=d?.network_key||(known.length===1?known[0]:null)||p.designation||'';
 const matches=catalog.get(networkKey(designation))||[];
 const network=matches.length===1?matches[0]:'Unresolved';
 const reliable=d?d.reliable_test_time:(t.test_time&&!/^(?:19[0-6][0-9]|1970)-/.test(t.test_time)?t.test_time:null);
 const points=labels.flatMap((label,i)=>label==='Unresolved'?[]:[{value:ids.length===2?String(ids[i]):`label:${label}`,label}]);
 const pair=[...labels].sort().join(' ↔ ');const key=t.cable_id?`cable:${t.cable_id}`:ids.length===2||sourceLabels?`${networkKey(designation)}:${pair}`:`unresolved:${t.test_uuid}`;
 return {...t,ids,labels,points,designation,network,pair,key,reliable,uncertain:d?.has_unknown_test_order||!reliable};});
 cache.set(data,result);return result;}
 function pointOptions(all){const points=new Map();for(const t of all)for(const p of t.points)points.set(p.value,p.label);return [...points].sort((a,b)=>a[1].localeCompare(b[1],undefined,{numeric:true}));}
 function render(data,root){if(!root.dataset.ready){root.dataset.ready='1';const controls=el('div',undefined,root);controls.className='power-toolbar';
 for(const [id,label] of [['network','Network'],['waypoint','Cable test point / waypoint']]){const s=el('select',undefined,el('label',label,controls));s.dataset.filter=id;s.onchange=()=>render(data,root);}
 el('div',undefined,root).className='cable-results';}
 const all=rows(data),network=root.querySelector('[data-filter="network"]'),waypoint=root.querySelector('[data-filter="waypoint"]');
 function fill(s,options){const prior=s.value;s.replaceChildren();el('option','All',s).value='';for(const [v,l] of options)el('option',l,s).value=v;s.value=prior;if(s.selectedIndex<0)s.value='';s.onchange=()=>render(data,root);}
 fill(network,[...new Set(all.map(t=>t.network))].sort().map(x=>[x,x]));fill(waypoint,pointOptions(all));
 if(!root.dataset.linkApplied){waypoint.value=new URLSearchParams(location.search).get('waypoint')||'';root.dataset.linkApplied='1';}
 const filtered=all.filter(t=>(!network.value||t.network===network.value)&&(!waypoint.value||t.points.some(p=>p.value===waypoint.value)));
 const host=root.querySelector('.cable-results');host.replaceChildren();el('p',`${filtered.length} retained test(s). Latest reliably dated results shown; undated tests remain visible because their order is unknown.`,host);
 if(!filtered.length){el('p','No cable tests match these filters.',host);return;}
 const table=el('table',undefined,host);table.className='cable-test-table';const head=el('tr',undefined,el('thead',undefined,table));
 ['Network','Test point A','Test point B','Length (ft)','Test speed / standard','Result','Test date / history'].forEach(x=>el('th',x,head));const body=el('tbody',undefined,table);
 const groups=new Map();for(const t of filtered){if(!groups.has(t.key))groups.set(t.key,[]);groups.get(t.key).push(t);}
 const ordered=[...groups.values()].map(group=>group.sort((a,b)=>String(b.reliable||'').localeCompare(String(a.reliable||''))||String(a.test_uuid).localeCompare(String(b.test_uuid)))).sort((a,b)=>String(b[0].reliable||'').localeCompare(String(a[0].reliable||'')));
 for(const group of ordered){const top=group[0],tr=el('tr',undefined,body);[top.network,...top.labels,top.length_ft??'Unknown',speedLabel(top),`Recorded code: ${top.status_code??'Unknown'}`].forEach(v=>el('td',v,tr));
 const cell=el('td',undefined,tr);el('p',top.reliable||'Date unknown / tester clock unset',cell);if(group.some(t=>t.uncertain))el('strong','Test order uncertain',cell);
 if(group.filter(t=>t.reliable===top.reliable).length>1)el('p','Latest date tied',cell);
 const history=el('details',undefined,cell);el('summary',`All ${group.length} test(s)`,history);
 history.ontoggle=()=>{if(!history.open||history.dataset.loaded)return;history.dataset.loaded='1';
 for(const t of group){const article=el('article',undefined,history);el('p',`${t.reliable||'Date unknown'} · ${t.length_ft??'Unknown'} ft · ${speedLabel(t)} · Recorded result ${t.status_code??'Unknown'}`,article);el('p',`Original date: ${t.test_time||'Unknown'} · ${t.original_name||''} · Source designation ${t.designation||'Unknown'} · Test ${t.test_uuid} · Source ${t.source_sha256||'Unknown'} · ${t.review_status||'Unreviewed'}`,article);}
 };
 }
 }
 return {rows,pointOptions,speedLabel,render};
})();
