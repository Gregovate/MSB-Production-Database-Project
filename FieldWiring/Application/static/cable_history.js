/* Read-only browsing of retained test evidence; never invent speed or topology. */
"use strict";
window.MSBCableHistory=(()=>{
 const el=(tag,text,parent)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;parent?.append(n);return n;};
 function rows(data){const dated=new Map((data.flw_cable_tests||[]).map(t=>[t.test_uuid,t]));const wp=id=>data.waypoints.find(w=>w.id===id)?.name||`Waypoint ${id}`;
 return (data.linkiq_evidence||[]).map(t=>{const d=dated.get(t.test_uuid),p=t.source_pair||{};const candidates=p.endpoint_candidates||[];
 const ids=d?[d.endpoint_a,d.endpoint_b]:t.endpoint_a&&t.endpoint_b?[t.endpoint_a,t.endpoint_b]:candidates.length===2&&candidates.every(x=>x.length===1)?candidates.map(x=>x[0]):[];
 const labels=ids.length===2?ids.map(wp):p.endpoint_labels?.length===2?p.endpoint_labels:['Unresolved','Unresolved'];
 const related=(data.flw_cable_tests||[]).filter(x=>t.cable_id&&x.physical_site_cable_id===t.cable_id);const known=[...new Set(related.map(x=>x.network_key).filter(Boolean))];
 const network=d?.network_key||(known.length===1?known[0]:null)||p.designation||'Unresolved';const reliable=d?d.reliable_test_time:(t.test_time&&!/^1970-/.test(t.test_time)?t.test_time:null);
 const pair=[...labels].sort().join(' ↔ ');const key=t.cable_id?`cable:${t.cable_id}`:ids.length===2||p.endpoint_labels?.length===2?`${network}:${pair}`:`unresolved:${t.test_uuid}`;
 return {...t,ids,labels,network,pair,key,reliable,uncertain:d?.has_unknown_test_order||!reliable};});}
 function render(data,root){if(!root.dataset.ready){root.dataset.ready='1';const controls=el('div',undefined,root);controls.className='power-toolbar';
 for(const [id,label] of [['network','Network'],['waypoint','Waypoint']]){const s=el('select',undefined,el('label',label,controls));s.dataset.filter=id;s.onchange=()=>render(data,root);}
 el('div',undefined,root).className='cable-results';}
 const all=rows(data),network=root.querySelector('[data-filter="network"]'),waypoint=root.querySelector('[data-filter="waypoint"]');
 function fill(s,options){const prior=s.value;s.replaceChildren();el('option','All',s).value='';for(const [v,l] of options)el('option',l,s).value=v;s.value=prior;if(s.selectedIndex<0)s.value='';s.onchange=()=>render(data,root);}
 fill(network,[...new Set(all.map(t=>t.network))].sort().map(x=>[x,x]));fill(waypoint,data.waypoints.map(w=>[w.id,w.name]));
 if(!root.dataset.linkApplied){waypoint.value=new URLSearchParams(location.search).get('waypoint')||'';root.dataset.linkApplied='1';}
 const filtered=all.filter(t=>(!network.value||t.network===network.value)&&(!waypoint.value||t.ids.includes(Number(waypoint.value))));
 const host=root.querySelector('.cable-results');host.replaceChildren();el('p',`${filtered.length} retained test(s). Latest reliably dated results shown; undated tests remain visible because their order is unknown.`,host);
 if(!filtered.length){el('p','No cable tests match these filters.',host);return;}
 const table=el('table',undefined,host);table.className='cable-test-table';const head=el('tr',undefined,el('thead',undefined,table));
 ['Network','Test point A','Test point B','Length (ft)','Speed / test standard','Result','Test date / history'].forEach(x=>el('th',x,head));const body=el('tbody',undefined,table);
 const groups=new Map();for(const t of filtered){if(!groups.has(t.key))groups.set(t.key,[]);groups.get(t.key).push(t);}
 const ordered=[...groups.values()].map(group=>group.sort((a,b)=>String(b.reliable||'').localeCompare(String(a.reliable||''))||String(a.test_uuid).localeCompare(String(b.test_uuid)))).sort((a,b)=>String(b[0].reliable||'').localeCompare(String(a[0].reliable||'')));
 for(const group of ordered){const top=group[0],tr=el('tr',undefined,body);[top.network,...top.labels,top.length_ft??'Unknown',`${top.measured_link_speed_mbps??'Unknown'}${top.measured_link_speed_mbps?' Mbps':''} / ${top.test_standard||'Unknown standard'}`,`Recorded code: ${top.status_code??'Unknown'}`].forEach(v=>el('td',v,tr));
 const cell=el('td',undefined,tr);el('p',top.reliable||'Date unknown / tester clock unset',cell);if(group.some(t=>t.uncertain))el('strong','Test order uncertain',cell);
 if(group.filter(t=>t.reliable===top.reliable).length>1)el('p','Latest date tied',cell);
 const history=el('details',undefined,cell);el('summary',`All ${group.length} test(s)`,history);
 for(const t of group){const article=el('article',undefined,history);el('p',`${t.reliable||'Date unknown'} · ${t.length_ft??'Unknown'} ft · ${t.test_standard||'Unknown standard'} · Recorded result ${t.status_code??'Unknown'}`,article);el('p',`Original date: ${t.test_time||'Unknown'} · ${t.original_name||''} · Test ${t.test_uuid} · Source ${t.source_sha256||'Unknown'} · ${t.review_status||'Unreviewed'}`,article);}
 }
 }
 return {rows,render};
})();
