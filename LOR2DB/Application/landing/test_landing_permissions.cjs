// Execute the actual landing-page render for viewer and operator fixtures.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
async function render(operator) {
  const nodes = new Map();
  const get = selector => {
    if (!nodes.has(selector)) nodes.set(selector, {innerHTML:'', addEventListener() {}});
    return nodes.get(selector);
  };
  const model = {
    access:{can_run_parser:operator, can_operate_lor:operator},
    workflow:{state:'SNAPSHOT_CONSUMED', message:'Snapshot accepted', can_start:false},
    snapshot:null,
    latest_run:{lor_reconciliation_run_id:32, import_run_id:74, status:'COMPLETED', report_url:'reports/run32.html', validation_state:'PASSED'},
    parser_runner:{runner_version:'V1.7.2', current_lor_version:'6.6.12', current_preview_folder:'master', production_parser_run:{validation_status:'PASSED'}}
  };
  vm.runInNewContext(fs.readFileSync(__dirname + '/lor2db.js', 'utf8'), {
    document:{querySelector:get}, Intl, Date,
    fetch:async () => ({ok:true, json:async () => model})
  });
  await new Promise(resolve => setImmediate(resolve));
  return get('#app').innerHTML;
}
(async () => {
  const viewer = await render(false), operator = await render(true);
  assert.ok(viewer.includes('Open Run 32 report'));
  assert.ok(viewer.includes('LOR version approval'));
  assert.ok(viewer.includes('Parser execution is restricted'));
  assert.ok(!viewer.includes('href="parser/"'));
  assert.ok(operator.includes('href="parser/"'));
  console.log('PASS: shared landing information/report rendering and restricted parser launch');
})();
