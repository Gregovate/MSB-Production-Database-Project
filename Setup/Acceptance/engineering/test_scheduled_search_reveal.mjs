// Execute the actual reveal handler against collapsed-day DOM, without a server.
const { JSDOM } = await import(process.env.JSDOM_MODULE || 'jsdom');
import fs from 'node:fs';
import assert from 'node:assert/strict';
const source = fs.readFileSync(new URL('../../Application/setup_scheduling_board.js',import.meta.url),'utf8');
const handler = source.slice(source.indexOf('function board205RevealScheduledAssignment('),
                             source.indexOf('function board205CollapseScheduledSearchResults('));
for (const state of ['COMPLETED','UNFINISHED','EMPTY']) {
 const dom = new JSDOM(`<input id="setup-board205-show-completed-days" type="checkbox">
 <input id="setup-board205-show-unfinished-days" type="checkbox">
 <input id="setup-board205-show-empty-days" type="checkbox"><main id="days"></main>`, {runScripts:'outside-only'});
 const w=dom.window;
 w.setupBoard205State={board:{work_days:[{setup_work_day_id:7}]}};
 w.board205DayViewState=()=>state;
 const frames=[]; const timers=[]; let scrolls=0;
 w.requestAnimationFrame=fn=>frames.push(fn);
 w.setTimeout=fn=>timers.push(fn);
 w.board205RenderBoard=()=>{
  const id=state==='COMPLETED'?'completed':state==='UNFINISHED'?'unfinished':'empty';
  assert(w.document.getElementById(`setup-board205-show-${id}-days`).checked);
  w.document.getElementById('days').innerHTML=`
   <section class="setup-board205-day" data-day-id="7">
    <button class="setup-board205-toggle-day" aria-expanded="false">▶ SETUP DAY 7</button>
    <div class="setup-board205-day-content" hidden><article class="setup-board205-assignment" data-assignment-id="71"></article></div>
   </section>
   <section class="setup-board205-day" data-day-id="8">
    <button class="setup-board205-toggle-day" aria-expanded="false">▶ SETUP DAY 8</button>
    <div class="setup-board205-day-content" hidden><article class="setup-board205-assignment" data-assignment-id="81"></article></div>
   </section>`;
 };
 w.HTMLElement.prototype.scrollIntoView=function(){
  assert.equal(this.dataset.assignmentId,'71');
  assert(!this.closest('.setup-board205-day-content').hidden,'expand before scroll'); scrolls++;
 };
 w.eval(handler);
 const item={setup_work_day_id:7,setup_work_day_task_id:71};
 w.board205RevealScheduledAssignment(item);
 assert.equal(frames.length,1);frames.shift()();
 const day=w.document.querySelector('[data-day-id="7"]');
 const card=day.querySelector('.setup-board205-assignment');
 assert.equal(scrolls,1);assert(!day.querySelector('.setup-board205-day-content').hidden);
 assert.equal(day.querySelector('button').getAttribute('aria-expanded'),'true');
 assert(day.querySelector('button').textContent.startsWith('▼'));
 assert.equal(w.document.activeElement,card);
 assert(card.classList.contains('scheduled-search-hit'));
 assert(w.document.querySelector('[data-day-id="8"] .setup-board205-day-content').hidden);
 timers.shift()();assert(!card.classList.contains('scheduled-search-hit'));
 w.board205RevealScheduledAssignment(null);assert.equal(frames.length,0);
 dom.window.close();
}
console.log('PASS: actual search reveal expands only matched day before scroll/focus, updates aria/arrow, highlights, enables day filters and handles absent selection.');
