/* #205 sticky day/search regression: day identity must never disappear. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const js = fs.readFileSync(__dirname + '/setup_scheduling_board.js', 'utf8');
function section(start, end) {
  const a = js.indexOf(start);
  const b = js.indexOf(end, a + start.length);
  assert(a !== -1 && b > a, 'Missing sticky function: ' + start);
  return js.slice(a, b);
}
const on = {};
const cssVars = {};
const heading = {getBoundingClientRect: () => ({top:0,bottom:68,height:68})};
const badge = {textContent:'Loading',hidden:false};
let offset = 0;
const days = [0, 1, 2].map((i) => ({
  dataset: {dayId:String(i + 11), dayLabel:'SETUP DAY ' + (i + 16) + ' · TUE · 2026-10-' + (20 + i)},
  getBoundingClientRect: () => ({top: 150 + i * 400 - offset, bottom:540 + i * 400 - offset}),
  querySelector: () => ({getBoundingClientRect: () => ({top:150 + i * 400 - offset,bottom:210 + i * 400 - offset})})
}));
const pane = {
  dataset:{},
  style:{setProperty:(name,value)=>{cssVars[name]=value}},
  addEventListener:(name,fn)=>{on[name]=fn},
  getBoundingClientRect:()=>({top:0,bottom:750})
};
const ctx = {
  document:{
    querySelector:selector=> selector==='.setup-board205-board-heading'?heading:selector==='.setup-board205-right'?pane:null,
    getElementById:id=>id==='setup-board205-current-day'?badge:null,
    querySelectorAll:selector=> selector.includes('.setup-board205-day[data-day-id]')?days:[]
  },
  window:{addEventListener:(name,fn)=>on['window-'+name]=fn}
};
vm.createContext(ctx);
vm.runInContext(section('function board205UpdateStickyDay()', '\nfunction board205RenderBoard()'),ctx);
ctx.board205BindStickyDay();
assert.match(badge.textContent,/SETUP DAY 16/,'First day identity must be available');
assert.equal(badge.hidden,true,'Do not duplicate the day/date while its full header is visible');
assert.equal(cssVars['--setup-board205-sticky-heading-height'],'68px');
assert.equal(typeof on.scroll,'function','Own right-pane scroll listener needed');
offset=550; on.scroll();
assert.equal(badge.hidden,false,'Compact day/date appears when full day header scrolls away');
assert.match(badge.textContent,/SETUP DAY 17/,'Sticky day changes as next day enters search row');
offset=950; on.scroll();
assert.match(badge.textContent,/SETUP DAY 18/,'Day identity must remain visible late in board');
assert.equal(typeof on['window-resize'],'function');
assert.equal(typeof on['window-scroll'],'function');
assert.match(js,/id="setup-board205-current-day"/,'Badge must live in shared heading');
assert.match(js,/data-day-label="SETUP DAY/,'Each board day must expose its identity');
assert(js.indexOf('id="setup-board205-current-day"') < js.indexOf('id="setup-board205-scheduled-search"'));
const css=fs.readFileSync(__dirname+'/setup_scheduling_board.css','utf8');
assert(css.includes('.setup-board205-day-header { position: static; top: auto; }'),
  'No second sticky day header may consume vertical space');
assert(css.includes('.setup-board205-current-day[hidden] { display: none !important; }'),
  'Hidden compact day identity must not reserve horizontal space');
console.log('PASS #205 sticky scheduled search and current Setup Day remain together while scrolling');
