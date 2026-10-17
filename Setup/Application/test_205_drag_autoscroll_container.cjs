/* Production #205 drag auto-scroll must follow the actual right-pane scroll owner. */
const fs=require('node:fs'),assert=require('node:assert/strict');
const js=fs.readFileSync(__dirname+'/setup_scheduling_board.js','utf8');
const css=fs.readFileSync(__dirname+'/setup_scheduling_board.css','utf8');
assert.match(css,/\.setup-board205-right\s*\{[^}]*overflow-y:\s*auto;/s);
assert.match(css,/\.setup-board205-right\s*>\s*\.setup-board205-board\s*\{[^}]*overflow-y:\s*visible;/s);
assert.match(js,/querySelectorAll\('\.setup-board205-backlog, \.setup-board205-right'\)/);
assert.doesNotMatch(js,/querySelectorAll\('\.setup-board205-backlog, \.setup-board205-board'\)/);
assert.match(js,/pane\.scrollTop \+= direction \* step;/);
console.log('PASS #205 drag edge autoscroll owner matches desktop scrolling');
