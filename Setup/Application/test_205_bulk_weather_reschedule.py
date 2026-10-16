"""#205 Manager weather-lost shift moves; transactional, no real DB/network."""
from contextlib import contextmanager
from pathlib import Path
import pytest

from setup_scheduling_board_repository import SetupSchedulingBoardRepository, SetupSchedulingBoardRepositoryError


class Cursor:
    def __init__(self,fail_on=None):
        self.fail_on=fail_on
        self.moves=[]
        self.result=None
    def __enter__(self):
        return self
    def __exit__(self,*args):
        return False
    def execute(self,query,params):
        if "SELECT shift_code FROM ops.setup_work_day_task" in query:
            self.result={"shift_code":{81:"MORNING",82:"AFTERNOON",83:"ALL_DAY"}.get(params[0])}
        elif "ops.update_setup_work_day_assignment" in query:
            self.moves.append(params)
            if len(self.moves)==self.fail_on:
                raise RuntimeError("Actual work progress lock")
            self.result={"setup_work_day_task_id":params[1]}
        else:
            raise AssertionError(query)
    def fetchone(self):
        return self.result


def make_repo(cursor):
    class Conn:
        commits=0
        def cursor(self,cursor_factory=None):
            return cursor
        def commit(self):
            self.commits+=1
    connection=Conn()
    repo=SetupSchedulingBoardRepository("no-live-connection")
    @contextmanager
    def connect():
        yield connection
    repo.write_connect=connect
    return repo,connection


def test_atomic_bulk_move_preserves_original_shifts_and_audits_via_governed_function():
    cur=Cursor()
    repo,conn=make_repo(cur)
    rows=repo.bulk_reschedule_unworked(
        email="manager@sheboyganlights.org",work_day_id=14,crew_id=19,
        assignment_ids=[81,82],
    )
    assert len(rows)==2
    assert conn.commits==1
    assert [x[3] for x in cur.moves]==["MORNING","AFTERNOON"]
    assert all(x[2]==14 and x[4]==19 for x in cur.moves)


def test_failed_second_assignment_does_not_commit_partial_weather_move():
    cur=Cursor(fail_on=2)
    repo,conn=make_repo(cur)
    with pytest.raises(RuntimeError,match="Actual work progress lock"):
        repo.bulk_reschedule_unworked(
            email="manager@sheboyganlights.org",work_day_id=14,crew_id=19,
            assignment_ids=[81,82],
        )
    assert conn.commits==0


def test_legacy_shift_or_repeated_selection_fails_without_commit():
    cur=Cursor()
    repo,conn=make_repo(cur)
    with pytest.raises(SetupSchedulingBoardRepositoryError):
        repo.bulk_reschedule_unworked(
            email="manager@sheboyganlights.org",work_day_id=14,crew_id=19,
            assignment_ids=[81,81],
        )
    assert conn.commits==0


def test_manager_only_route_and_no_fake_progress():
    api=(Path(__file__).parent/"setup_scheduling_board_api.py").read_text()
    js=(Path(__file__).parent/"setup_next_pass.js").read_text()
    sql=(Path(__file__).resolve().parents[1]/"Database/069_fix_setup_day_sequence_and_audit.sql").read_text()
    fragment=api.split("def api_setup_scheduling_board_bulk_reschedule()",1)[1].split(
        "@setup_scheduling_board_api.delete(",1)[0]
    assert "require_manager()" in fragment and "require_setup_command()" in fragment
    assert "bulk_reschedule_unworked(" in fragment
    assert "nextOpenRescheduleNoWorkBatch(" in js
    assert "next-reschedule-unworked-shift" in js
    assert "NO WORK WAS PERFORMED" in js
    assert "'ASSIGNMENT_MOVED'" in sql
    assert "ops.record_setup_task_progress" not in fragment
