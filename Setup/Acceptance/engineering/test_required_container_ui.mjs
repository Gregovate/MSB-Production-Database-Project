// Actual candidate UI in an isolated DOM; supplemental to governed operator review.
const { JSDOM } = await import(process.env.JSDOM_MODULE || 'jsdom');
import fs from 'node:fs';
import assert from 'node:assert/strict';
const dom = new JSDOM('<section id="task-extra-material-section"></section>', {runScripts:'outside-only'});
const w = dom.window;
w.HTMLDialogElement.prototype.showModal = function() { this.open = true; };
w.HTMLDialogElement.prototype.close = function() { this.open = false; };
w.appState = {access:{can_manage_setup:true},selectedTaskId:10};
w.selectTask = id => { w.appState.selectedTaskId = id; };
w.escapeHtml = x => String(x).replaceAll('&','&amp;').replaceAll('<','&lt;');
w.commandOptions = (method, body) => ({method, body});
let rows = [{container_id:106,container_description:'Who Ville Panel Stands (8)',assigned:false},
            {container_id:107,container_description:'Kit',relationship_type:'KIT',assigned:false}];
let calls = []; let fail = false;
w.api = async (path, options) => {
  if (options) {
    calls.push({path,options});
    if (fail) throw Error('Save rejected');
    rows[0] = {...rows[0],assigned:options.body.assigned,
      relationship_type:options.body.assigned ? 'REQUIRED_CONTAINER' : null};
  }
  return {containers:rows.map(x=>({...x}))};
};
const tick = () => new Promise(resolve=>setTimeout(resolve,0));
w.eval(fs.readFileSync(new URL('../../Application/setup_required_containers.js',import.meta.url),'utf8'));
w.dispatchEvent(new w.Event('load')); await tick();
const el = id => w.document.getElementById(id);
el('required-container-open').click(); await tick();
assert(el('required-container-dialog').open);
for (const text of ['C106','106','Who Ville']) {
 el('required-container-search').value = text;
 el('required-container-search').dispatchEvent(new w.Event('input'));
 assert.equal(w.document.querySelectorAll('[data-required-container]').length,1);
}
let checkbox = w.document.querySelector('[data-required-container="106"]');
checkbox.checked = true; checkbox.dispatchEvent(new w.Event('change',{bubbles:true})); await tick();
assert.equal(calls.length,1); assert.equal(JSON.stringify(calls[0].options.body),JSON.stringify({assigned:true}));
assert.match(el('required-container-summary').textContent,/C106/);
el('required-container-close').click(); el('required-container-open').click(); await tick();
assert(w.document.querySelector('[data-required-container="106"]').checked);
assert(w.document.querySelector('[data-required-container="107"]').disabled);
fail = true; checkbox = w.document.querySelector('[data-required-container="106"]');
checkbox.checked = false; checkbox.dispatchEvent(new w.Event('change',{bubbles:true})); await tick();
assert(w.document.querySelector('[data-required-container="106"]').checked);
assert.match(el('required-container-message').textContent,/Save rejected/);
fail = false; checkbox = w.document.querySelector('[data-required-container="106"]');
checkbox.checked = false; checkbox.dispatchEvent(new w.Event('change',{bubbles:true})); await tick();
assert(!w.document.querySelector('[data-required-container="106"]').checked);
w.appState.access.can_manage_setup = false;w.selectTask(11);await tick();
assert(el('required-container-section').hidden);
dom.window.close();
console.log('PASS: actual UI search, one-click save without materials, readback, KIT lock, failed-save restore, removal, non-Manager visibility.');
