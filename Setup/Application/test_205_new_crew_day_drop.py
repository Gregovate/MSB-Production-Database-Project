"""#205 calendar-first day drop: protected, transactional, shift-preserving."""
from contextlib import contextmanager
from pathlib import Path
import pytest

from setup_scheduling_board_repository import (
    SetupSchedulingBoardRepository, SetupSchedulingBoardRepositoryError,
)

APP = Path(__file__).resolve().parent


class FakeCursor:
    def __init__(self, *, fail_on_update=0, cancelled=False):
        self.calls = []
        self.result = None
        self.update_calls = 0
        self.fail_on_update = fail_on_update
        self.cancelled = cancelled

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def execute(self, sql, params):
        self.calls.append((sql, params))
        if "SELECT setup_session_id, day_status FROM ops.setup_work_day" in sql:
            self.result = {"setup_session_id":2,"day_status":"CANCELLED" if self.cancelled else "PLANNED"}
        elif "ops.add_setup_work_day_crew" in sql:
            self.result = {"setup_work_day_crew_id":99,"crew_code":"C","crew_number":3}
        elif "SELECT shift_code FROM ops.setup_work_day_task" in sql:
            self.result = {"shift_code": {41:"MORNING",42:"AFTERNOON"}.get(params[0],"ALL_DAY")}
        elif "ops.update_setup_work_day_assignment" in sql:
            self.update_calls += 1
            if self.fail_on_update == self.update_calls:
                raise RuntimeError("existing assignment has real work; must not move")
            self.result = {"setup_work_day_task_id": params[1]}
        elif "SELECT execution_status, annual_task_action_type" in sql:
            self.result = {"execution_status":"PLANNED","annual_task_action_type":"SETUP_WORK"}
        elif "ops.create_setup_work_day_assignment" in sql:
            self.result = {"setup_work_day_task_id": 142}
        else:
            raise AssertionError("Unexpected query: " + sql)

    def fetchone(self):
        return self.result


class FakeConnection:
    def __init__(self, cursor):
        self.c = cursor
        self.commits = 0
    def cursor(self, cursor_factory=None):
        return self.c
    def commit(self):
        self.commits += 1


def fake_repository(cursor):
    conn = FakeConnection(cursor)
    repo = SetupSchedulingBoardRepository("never-connect-to-real-db")
    @contextmanager
    def connect():
        yield conn
    repo.write_connect = connect
    return repo, conn


def test_mixed_shift_move_keeps_actual_db_shifts_in_one_commit():
    cur = FakeCursor()
    repo, conn = fake_repository(cur)
    result = repo.add_crew_with_tasks(
        email="manager@sheboyganlights.org", work_day_id=17,
        items=[{"kind":"assignment","id":41,"shift":None},
               {"kind":"assignment","id":42,"shift":None}],
    )
    assert conn.commits == 1
    moves = [args for sql,args in cur.calls if "ops.update_setup_work_day_assignment" in sql]
    assert len(moves) == 2
    assert [row[3] for row in moves] == ["MORNING","AFTERNOON"]
    assert all(row[4] == 99 for row in moves)
    assert [row[5] for row in moves] == [10,20]
    assert len(result["assignments"]) == 2


def test_failed_group_move_never_commits_new_crew():
    cur = FakeCursor(fail_on_update=2)
    repo, conn = fake_repository(cur)
    with pytest.raises(RuntimeError,match="must not move"):
        repo.add_crew_with_tasks(
            email="manager@sheboyganlights.org",work_day_id=17,
            items=[{"kind":"assignment","id":41}, {"kind":"assignment","id":42}],
        )
    assert conn.commits == 0


def test_first_unscheduled_task_creates_new_crew_with_explicit_pm():
    cur = FakeCursor()
    repo,conn = fake_repository(cur)
    repo.add_crew_with_tasks(
        email="manager@sheboyganlights.org", work_day_id=17,
        items=[{"kind":"task","id":23,"shift":"AFTERNOON"}],
    )
    assert conn.commits == 1
    rows = [args for sql,args in cur.calls if "ops.create_setup_work_day_assignment" in sql]
    assert len(rows)==1 and rows[0][3]=="AFTERNOON" and rows[0][4]==99


def test_cancelled_day_creates_no_crew():
    cur=FakeCursor(cancelled=True)
    repo,conn=fake_repository(cur)
    with pytest.raises(SetupSchedulingBoardRepositoryError,match="cancelled"):
        repo.add_crew_with_tasks(
            email="manager@sheboyganlights.org",work_day_id=17,
            items=[{"kind":"task","id":23,"shift":"MORNING"}],
        )
    assert conn.commits == 0
    assert not any("ops.add_setup_work_day_crew" in sql for sql,_ in cur.calls)


def test_operator_controls_and_access_checks():
    ui=(APP/"setup_scheduling_board.js").read_text()
    css=(APP/"setup_scheduling_board.css").read_text()
    api=(APP/"setup_scheduling_board_api.py").read_text()
    assert "setup-board205-new-crew-row" in ui
    assert 'data-shift="MORNING"' in ui and 'data-shift="AFTERNOON"' in ui
    assert "board205DropToNewCrew(" in ui
    assert "setupBoard205State.dragged" in ui
    assert "New AM Crew" in ui and "New PM Crew" in ui
    assert "Existing AM and PM shifts will both be preserved." in ui
    assert ".setup-board205-new-crew-drop.drop-target" in css
    assert "role=\"button\" tabindex=\"0\"" in ui
    assert "@setup_scheduling_board_api.post(" in api
    assert "/crews/with-tasks" in api
    code=api.split("def api_setup_scheduling_board_crew_with_tasks",1)[1].split(
        "@setup_scheduling_board_api.patch",1
    )[0]
    assert "require_setup_command()" in code
    assert "require_manager()" in code
    assert "repo().add_crew_with_tasks(" in code
    assert "Choose one to 25" in code
    assert "item[\"kind\"] == \"task\"" in code
