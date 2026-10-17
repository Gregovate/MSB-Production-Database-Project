/* #205 Production regression: schedule/move Crew choices identify their Captain. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(__dirname + '/setup_scheduling_board.js', 'utf8');
const begin = source.indexOf('function board205PopulateCrewSelect(');
const end = source.indexOf('\nfunction board205PopulateScenes(', begin);
assert(begin >= 0 && end > begin, 'Expected Schedule Annual Task Crew selector');
const select = { innerHTML: '', value: '' };
const crews = [
  { setup_work_day_crew_id: 101, crew_code: 'A', captain_display_name: 'Rick Hoffmann' },
  { setup_work_day_crew_id: 102, crew_code: 'B', captain_display_name: 'Rob VanderSchaaf' },
  { setup_work_day_crew_id: 103, crew_code: 'C', captain_display_name: null },
];
const context = {
  document: { getElementById: id => id === 'setup-board205-schedule-crew' ? select : null },
  board205CrewsForDay: day => {
    assert.equal(day, 17);
    return crews;
  },
  board205Esc: value => String(value).replaceAll('&','&amp;').replaceAll('<','&lt;'),
};
vm.createContext(context);
vm.runInContext(source.slice(begin,end),context);
context.board205PopulateCrewSelect(17,102);
assert.match(select.innerHTML, /Crew A · Rick Hoffmann/);
assert.match(select.innerHTML, /Crew B · Rob VanderSchaaf/);
assert.match(select.innerHTML, /Crew C · Captain not assigned/);
assert.equal(select.value,'102');
console.log('PASS #205 Scheduling Board Crew select includes Captain names');
