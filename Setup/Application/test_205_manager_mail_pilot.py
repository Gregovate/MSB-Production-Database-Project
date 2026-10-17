"""#205 one-day Manager pilot tests: never touch live PostgreSQL or SMTP."""
from datetime import date, datetime
import importlib.util
from pathlib import Path
import sys
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import pytest

PILOT_PATH = Path(__file__).resolve().parents[1] / "Acceptance" / "manager_mail_pilot"
spec = importlib.util.spec_from_file_location("manager_mail_pilot", PILOT_PATH / "manager_mail_pilot.py")
mail = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mail)
CHI = ZoneInfo("America/Chicago")


def fixture_board():
    return {
        "session":{"season_year":2026},
        "tasks":[
            {"setup_session_task_id":1,"task_name":"Complete","effective_complete":True,
             "completion_work_date":"2026-10-16"},
            {"setup_session_task_id":2,"task_name":"Partially built","effective_complete":False,
             "execution_status":"IN_PROGRESS","percent_complete":55,
             "future_assignment_count":0,"readiness_state":"NOT_READY"},
            {"setup_session_task_id":3,"task_name":"Future work","effective_complete":False,
             "execution_status":"PLANNED","future_assignment_count":1},
        ],
        "work_days":[
            {"setup_work_day_id":9,"work_date":"2026-10-15"},
            {"setup_work_day_id":10,"work_date":"2026-10-17"},
            {"setup_work_day_id":11,"work_date":"2026-10-15","day_status":"CANCELLED"},
        ],
        "crews":[{"setup_work_day_crew_id":1,"crew_code":"A","captain_display_name":"Captain",
                  "captain_person_id":42}],
        "assignments":[
            {"setup_work_day_task_id":30,"setup_work_day_id":9,"setup_session_task_id":2,
             "setup_work_day_crew_id":1,"shift_code":"MORNING","work_report_count":0},
            {"setup_work_day_task_id":31,"setup_work_day_id":9,"setup_session_task_id":1,
             "setup_work_day_crew_id":1,"shift_code":"AFTERNOON","work_report_count":1},
            {"setup_work_day_task_id":32,"setup_work_day_id":10,"setup_session_task_id":3,
             "setup_work_day_crew_id":1,"shift_code":"AFTERNOON","work_report_count":0},
            {"setup_work_day_task_id":33,"setup_work_day_id":11,"setup_session_task_id":2,
             "setup_work_day_crew_id":1,"shift_code":"MORNING","work_report_count":0},
        ],
    }


def setup_fakes(monkeypatch):
    class BoardRepo:
        def __init__(self, dsn):
            assert dsn == "fixture"
        def board(self, year):
            assert year == 2026
            return fixture_board()
    monkeypatch.setitem(sys.modules,"setup_scheduling_board_repository",
                        SimpleNamespace(SetupSchedulingBoardRepository=BoardRepo))
    monkeypatch.setattr(mail,"people_managers",lambda dsn:[
        {"person_id":1,"email":"manager@sheboyganlights.org","display_name":"Manager One"},
        {"person_id":2,"email":"second@sheboyganlights.org","display_name":"Manager Two"},
    ])


def time_at(hour=4, day=17):
    return datetime(2026,10,day,hour,0,tzinfo=CHI)


def test_whole_setup_counts_and_historical_classification():
    a = mail.summarize(fixture_board(),date(2026,10,17))
    assert [a["total_tasks"],a["completed_tasks"],a["remaining_tasks"]] == [3,1,2]
    assert a["blocked_tasks"] == 1
    assert a["missing_report_occurrences"] == 1
    assert a["continuation_needed"] == 1
    assert "Partially built" in a["overdue_lines"]
    assert "Future work" not in a["overdue_lines"]
    assert a["projected_finish"] == "INSUFFICIENT DATA"


def test_template_is_external_reviewable_and_no_fake_reporting():
    a = mail.summarize(fixture_board(),date(2026,10,17))
    source = mail.DEFAULT_TEMPLATE.read_text(encoding="utf-8")
    body = mail.render(source,{"display_name":"Manager One"},a)
    assert "Hello Manager One" in body
    assert "Reschedule" in body and "Do not enter fictitious" in body
    assert "No Captain reminders are being sent" in body
    assert "$" not in body


def test_manager_email_leads_with_kpis_not_training_or_a_long_task_list():
    report = mail.summarize(fixture_board(),date(2026,10,17))
    body = mail.render(
        mail.DEFAULT_TEMPLATE.read_text(encoding="utf-8"),
        {"display_name":"Manager One"}, report,
    )
    assert body.index("TOTAL 3") < body.index("MANAGER DECISIONS")
    assert body.index("MANAGER DECISIONS") < body.index("WHAT TO DO")
    assert body.index("WHAT TO DO") < body.index("PAST ASSIGNMENTS TO VERIFY")
    assert "Task pace:" in body and "November 19" in body
    assert "No Captain reminders are being sent" in body
    assert "Unresolved items remain in the Manager Action Center" in body
    assert "tomorrow's Manager-only report" not in body
    assert len(body.split()) < 300, "Template briefing must stay concise with small fixture"


def test_subject_and_body_are_both_reviewable_external_templates():
    source=mail.DEFAULT_SUBJECT_TEMPLATE.read_text(encoding="utf-8")
    subject=mail.Template(source).substitute(report_date="2026-10-17").strip()
    assert subject == "MSB Setup — Manager Actions — 2026-10-17"
    assert "recipient_name" in mail.DEFAULT_TEMPLATE.read_text(encoding="utf-8")


@pytest.mark.parametrize("bad_subject", [
    "Subject\nBcc: someone@example.com",
    "Oops: $unsupported_field",
])
def test_unsafe_or_unknown_subject_placeholder_blocks_preview(
        monkeypatch,tmp_path,bad_subject):
    setup_fakes(monkeypatch)
    subject_path=tmp_path/"subject.txt"
    subject_path.write_text(bad_subject,encoding="utf-8")
    monkeypatch.setattr(mail,"DEFAULT_SUBJECT_TEMPLATE",subject_path)
    monkeypatch.setattr(mail,"deliver",lambda *a:pytest.fail("sent"))
    with pytest.raises(mail.PilotStop,match="Subject template"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(),"preview",None)


def test_no_send_preview_never_touches_smtp_or_ledger(monkeypatch,tmp_path,capsys):
    setup_fakes(monkeypatch)
    monkeypatch.setattr(mail,"deliver",lambda *args: pytest.fail("no SMTP in preview"))
    result = mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(), "preview", None)
    assert result["status"] == "PREVIEW_ONLY"
    printed=capsys.readouterr().out
    assert "manager@sheboyganlights.org" in printed
    assert '"total_tasks": 3' in printed
    assert not list(tmp_path.iterdir())


@pytest.mark.parametrize("moment", [
    time_at(3), time_at(5), time_at(4,18), time_at(1,17),
])
def test_send_outside_exact_window_fails_before_db_or_smtp(monkeypatch,tmp_path,moment):
    monkeypatch.setattr(mail,"people_managers",lambda dsn:pytest.fail("queried"))
    with pytest.raises(mail.PilotStop,match="window"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,moment,"live",None)


def test_disabled_by_default_does_not_create_receipts(monkeypatch,tmp_path):
    setup_fakes(monkeypatch)
    monkeypatch.delenv("MSB_SETUP_MANAGER_PILOT_SEND",raising=False)
    monkeypatch.setattr(mail,"deliver",lambda *args:pytest.fail("sent"))
    with pytest.raises(mail.PilotStop,match="approval"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(),"live",None)
    assert not list(tmp_path.iterdir())


def test_success_then_no_duplicate_send(monkeypatch,tmp_path):
    setup_fakes(monkeypatch)
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_SEND",mail.SEND_GUARD)
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED","1")
    seen=[]
    monkeypatch.setattr(mail,"deliver",lambda recipient,subject,body:
                        seen.append(recipient) or "SMTP_ACCEPTED_NOT_DELIVERED")
    result=mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(),"live",None)
    assert result["recipients"]==2
    assert seen==["manager@sheboyganlights.org","second@sheboyganlights.org"]
    assert len(list(tmp_path.iterdir()))==2
    with pytest.raises(mail.PilotStop,match="Prior recipient attempt"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(),"live",None)
    assert len(seen)==2


def test_one_recipient_test_and_unknown_identity_rejected(monkeypatch,tmp_path):
    setup_fakes(monkeypatch)
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_SEND",mail.SEND_GUARD)
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED","1")
    seen=[]
    monkeypatch.setattr(mail,"deliver",lambda recipient,subject,body:
                        seen.append(recipient) or "SMTP_ACCEPTED_NOT_DELIVERED")
    mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(20,16),
              "test","manager@sheboyganlights.org")
    assert seen==["manager@sheboyganlights.org"]
    with pytest.raises(mail.PilotStop,match="not exactly one"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(20,16),
                  "test","volunteer@example.org")
    assert len(seen)==1


def test_no_sender_header_from_operator_content():
    assert mail.FROM == "no-reply@sheboyganlights.org"
    assert not hasattr(mail,"captain_email")
