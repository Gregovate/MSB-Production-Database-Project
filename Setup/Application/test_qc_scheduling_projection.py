"""Execute the real scheduling projection with mixed historical/current tasks."""
from pathlib import Path
import shutil
import subprocess
import pytest


def test_schedule_excludes_qc_without_mutating_qc_source_or_history():
    node = shutil.which('node')
    if not node:
        pytest.skip('JavaScript runtime unavailable; also covered by Chromium fixture')
    source = Path(__file__).with_name('setup_scheduling_board.js').read_text()
    function = source.split('function board205SchedulingOnly',1)[1].split('async function board205Load',1)[0]
    script = 'const assert=require("node:assert/strict");\nfunction board205SchedulingOnly'+function+r'''
const original={tasks:[{setup_session_task_id:81,qc_check_flag:true},
 {setup_session_task_id:87,qc_check_flag:false}],
 assignments:[{setup_session_task_id:81},{setup_session_task_id:87}]};
const result=board205SchedulingOnly(original);
assert.deepEqual(result.tasks.map(t=>t.setup_session_task_id),[87]);
assert.deepEqual(result.assignments.map(t=>t.setup_session_task_id),[87]);
assert.equal(original.tasks.length,2);assert.equal(original.assignments.length,2);
// Historical catalog overlay may already have removed the annual QC row.
assert.equal(board205SchedulingOnly({tasks:[],assignments:[{setup_session_task_id:81}]},[81]).assignments.length,0);
'''
    subprocess.run([node,'-e',script],check=True,capture_output=True,text=True)


def test_perform_work_excludes_legacy_qc_before_counts_labor_and_batch_actions():
    node = shutil.which('node')
    if not node:
        pytest.skip('JavaScript runtime unavailable')
    source = Path(__file__).with_name('setup_next_pass.js').read_text()
    helper = source.split('function nextPerformWorkAssignments', 1)[1].split('function nextPerformScheduledCaptains', 1)[0]
    script = 'const assert=require("node:assert/strict");\nfunction nextPerformWorkAssignments' + helper + r'''
const board={tasks:[{setup_session_task_id:1,qc_check_flag:true,task_name:'Renamed QC'},
 {setup_session_task_id:2,qc_check_flag:false},{setup_session_task_id:3,qc_check_flag:true}],
 assignments:[{setup_work_day_task_id:10,setup_session_task_id:1,actual_person_minutes:999},
 {setup_work_day_task_id:11,setup_session_task_id:2,actual_person_minutes:60},
 {setup_work_day_task_id:12,setup_session_task_id:3},
 {setup_work_day_task_id:13,setup_session_task_id:4,qc_check_flag:true}]};
const before=JSON.stringify(board);
const rows=nextPerformWorkAssignments(board);
assert.deepEqual(rows.map(a=>a.setup_work_day_task_id),[11]);
assert.equal(rows.reduce((n,a)=>n+(a.actual_person_minutes||0),0),60);
assert.equal(JSON.stringify(board),before);
'''
    subprocess.run([node, '-e', script], check=True, capture_output=True, text=True)
    # These are the three entry points that previously consumed raw QC history.
    assert 'const allAssignments = nextPerformWorkAssignments(board);' in source
    assert 'const items = nextPerformWorkAssignments(setupNextState.performBoard)' in source
    assert 'nextPerformWorkAssignments(board).map((assignment)' in source
