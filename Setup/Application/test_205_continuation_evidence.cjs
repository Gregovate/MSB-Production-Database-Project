/* Render the real Action Center, preserving selection and original notes. */
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = fs.readFileSync(__dirname + '/setup_next_pass.js', 'utf8');
const start = source.indexOf('function setup205LatestWorkReportHtml(');
const end = source.indexOf('\nasync function ', start);
const context = {
  appState: {access:{can_manage_setup:true}, seasonYear:2026},
  escapeHtml: s => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'),
  nextSetupLocalDate: () => '2026-10-31',
};
vm.createContext(context);
// Evaluate individual declarations to avoid unrelated page initialization.
function declaration(name) {
  const begin=source.indexOf('function '+name+'(');
  const next=source.indexOf('\nfunction ',begin+1);
  const asyncNext=source.indexOf('\nasync function ',begin+1);
  return source.slice(begin,Math.min(...[next,asyncNext].filter(x=>x>begin)));
}
vm.runInContext(declaration('setup205LatestWorkReportHtml'),context);
vm.runInContext(declaration('setupAnnualMilestoneDates'),context);
assert.equal(context.setupAnnualMilestoneDates(2026).setupComplete.toISOString().slice(0,10),'2026-11-17');
assert.equal(context.setupAnnualMilestoneDates(2027).setupComplete.toISOString().slice(0,10),'2027-11-18');
for(let id=1;id<=23;id++) {
 const task={setup_session_task_id:id,latest_work_report:{setup_task_progress_id:id+100,
 setup_work_day_task_id:id+200,performed_on:'2026-10-30',percent_complete:50,
 progress_note:`Task ${id}: installed lights.\nOther crew handles <wiring>.`,recorded_by:'Greg',recorded_at:'2026-10-30T12:00:00Z'}};
 const before=JSON.stringify(task);
 const html=context.setup205LatestWorkReportHtml(task,(action,id,label)=>`${action}:${id}:${label}`);
 assert(html.includes(`Task ${id}: installed lights.\nOther crew handles &lt;wiring&gt;.`));
 assert(html.includes('2026-10-30') && html.includes('Greg') && html.includes('50%'));
 assert(html.includes(`report:${id+200}:Review original Report Work`));
 assert.equal(JSON.stringify(task),before);
}
const missing=context.setup205LatestWorkReportHtml({},()=>{throw Error('No invented assignment');});
assert(missing.includes('No Report Work note recorded'));
assert(missing.includes('Attribution not recorded'));
assert(source.includes('setup205LatestWorkReportHtml(t, button)'));
console.log('PASS: 23 original notes, safe rendering, attribution, original report actions and actual 2026 milestone');
