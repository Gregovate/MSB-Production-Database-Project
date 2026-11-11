/* #205 real summary/status markup and theme-token contrast regression. */
const fs=require('fs'),vm=require('vm');
const assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/setup_next_pass.js','utf8');
const start=source.indexOf('          const crewShifts',source.indexOf('function renderNextExecution'));
const end=source.indexOf('\n        })()}',start);
const ctx={dayAssignments:[{shift_code:'MORNING',setup_work_day_crew_id:1}],day:{setup_work_day_id:1,work_date:'2026-11-11'},scopedAssignments:[],scopedDayAssignments:[],board:{crews:[],tasks:[]},setupNextState:{performCaptainFilter:'ALL'},reportedPersonHours:'0.0',nextAssignmentReported:()=>false,nextSetupLocalDate:()=> '2026-11-11',escapeHtml:s=>String(s),nextDayStaffingSummary:()=> 'AM: 3 crews · 6 tasks · 3 volunteers planned / 11 minimum needed · 8.2 known task-hours\nPM: 0 crews · 0 tasks',nextPerformShiftWorkload:()=>({known:240,capacity:180,count:1,overload:60,unknown:0,notReady:1}),nextPerformCrew:()=>({captain_person_id:1,am_planned_crew_count:1})};
vm.createContext(ctx);
vm.runInContext('function daily(){'+source.slice(start,end)+'}',ctx);
const ws=source.indexOf('function nextPerformWorkloadLabel('),we=source.indexOf('\n// Count each crew',ws);
vm.runInContext(source.slice(ws,we),ctx);
let result='<h2>Daily staffing summary</h2>'+ctx.daily()+'<h2>Shift status</h2>'+ctx.nextPerformWorkloadLabel([{}],'MORNING');
ctx.nextPerformShiftWorkload=()=>({known:60,capacity:180,count:1,overload:0,unknown:0,notReady:0});
result+=ctx.nextPerformWorkloadLabel([{}],'MORNING');
// Evaluate the generated inline styles against the actual explicit theme palettes.
const base=fs.readFileSync(__dirname+'/setup.css','utf8');
const theme=fs.readFileSync(__dirname+'/setup_theme.css','utf8');
const root=base.match(/:root\s*\{([^}]+)\}/)[1];
const dark=theme.match(/html\[data-theme="dark"\]\s*\{([^}]+)\}/)[1];
const systemDark=theme.match(/html:not\(\[data-theme="light"\]\)\s*\{([^}]+)\}/)[1];
const palette=s=>Object.fromEntries([...s.matchAll(/(--[\w-]+):\s*(#[0-9a-f]{6})/gi)].map(m=>[m[1],m[2]]));
const luminance=hex=>{
 const rgb=[1,3,5].map(n=>parseInt(hex.slice(n,n+2),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);
 return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;
};
const contrast=(a,b)=>{const x=luminance(a),y=luminance(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05);};
const daily=ctx.daily();
assert(daily.includes('background:var(--card, #fff);color:var(--text, #18212b)'));
assert(!daily.includes('--surface'));
for (const [name,vars] of [['light',palette(root)],['dark',{...palette(root),...palette(dark)}],['system-dark',{...palette(root),...palette(systemDark)}]]) {
 for(const [foreground,background] of [['--text','--card'],['--warning','--warning-soft'],['--success','--success-soft']]) {
  const ratio=contrast(vars[foreground],vars[background]);
  assert(ratio>=4.5,`${name} ${foreground} contrast ${ratio}`);
 }
 console.log('PASS '+name+' daily/shift text contrast >=4.5:1');
}
assert(result.includes('var(--warning-soft, #fff4df)'));
assert(result.includes('var(--success-soft, #eaf6ee)'));

