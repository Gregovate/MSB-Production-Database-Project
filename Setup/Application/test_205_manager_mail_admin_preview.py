"""#205: Admin-only recipient/2026 preview, never SMTP or mutations."""
from types import SimpleNamespace
from flask import Flask
import pytest

import setup_manager_mail_admin_api as m
from setup_api import SetupAuthenticationError, SetupCommandError


@pytest.fixture
def client(monkeypatch):
    app = Flask(__name__)
    app.testing = True
    app.register_blueprint(m.setup_manager_mail_admin_api)

    class FakeRepo:
        def __init__(self, dsn):
            assert dsn == "isolated-readonly"
        def board(self, year):
            assert year == 2026
            return {"session":{"season_year":2026},"tasks":[{"setup_session_task_id":1}]}

    def fake_report(board, today):
        assert board["session"]["season_year"] == 2026
        return {
            "continuation_rows": [], "report_date": today.isoformat(), "completion_percent":"30.4",
            "total_tasks": 296, "completed_tasks":90, "remaining_tasks":206,
            "blocked_tasks":140, "actual_pace":"7.86","required_pace":"6.06",
            "projected_finish":"INSUFFICIENT DATA",
            "projection_confidence":"Mock isolated data",
            "missing_report_occurrences":4,"continuation_needed":12,
            "readiness_exceptions":46, "captain_tbd_count":0
        }

    fake_managers = [
        {"person_id":11,"display_name":"Administrator Example",
         "email":"admin@sheboyganlights.org", "is_manager":True,
         "can_manage_setup":True, "identity_linked":True,
         "send_eligible":True,"review_status":"ELIGIBLE","review_reason":"Eligible"},
        {"person_id":12,"display_name":"Manager Example",
         "email":"manager@sheboyganlights.org", "is_manager":True,
         "can_manage_setup":True, "identity_linked":True,
         "send_eligible":True,"review_status":"ELIGIBLE","review_reason":"Eligible"},
        {"person_id":13,"display_name":"Held Manager",
         "email":"held@sheboyganlights.org", "is_manager":True,
         "can_manage_setup":False, "identity_linked":False,
         "send_eligible":False,"review_status":"HELD","review_reason":"No Setup access"}
    ]
    monkeypatch.setattr(m,"setup_database_dsn",lambda:"isolated-readonly")
    monkeypatch.setattr(m,"SetupSchedulingBoardRepository",FakeRepo)
    monkeypatch.setattr(m,"_piloted_digest_module",lambda:SimpleNamespace(
        SETUP_URL="https://my.sheboyganlights.org/setup/",
        enrich_continuations=lambda report,evidence: None,
        report_work_evidence=lambda dsn,ids: {},
        manager_directory=lambda dsn: fake_managers,
        accepted_setup_dsn=lambda: (_ for _ in ()).throw(AssertionError("Browser must not call production sender guard")),
        summarize=fake_report,
        container_summary=lambda dsn,season_year:{
            "containers_total":8,"containers_park_recorded":3,
            "containers_outbound":1,"containers_empty_at_park":1,
            "containers_partial_at_park":1,"containers_returned":1,
            "containers_no_movement":2,"containers_location_review":1,
            "containers_contents_review_history":0,
            "containers_snapshot_as_of":"2026-10-17T02:00:00-05:00",
            "containers_session_id":2,
        },
        render_html=lambda template,person,report:
            "<html><body>Containers · Field movement — " +
            str(report["containers_park_recorded"]) + "</body></html>",
        render=lambda template, person, report:
            "Actual preview for " + person["display_name"] + "\n" +
            f"Total {report['total_tasks']}, Remaining {report['remaining_tasks']}",
    ))
    return app.test_client()


def test_manager_roster_preview_only_with_auth(client,monkeypatch):
    monkeypatch.setattr(m,"require_admin",lambda:(None,"admin@sheboyganlights.org",{"can_admin_setup":True}))
    resp=client.get("/api/setup/notifications/manager-preview")
    assert resp.status_code==200
    data=resp.get_json()
    assert data["mode"]=="READ_ONLY_NO_SEND"
    assert data["recipient_count"]==2
    assert [x["email"] for x in data["recipients"]]==[
        "admin@sheboyganlights.org","manager@sheboyganlights.org",
        "held@sheboyganlights.org"]
    assert data["reviewed_count"] == 3
    assert data["held_count"] == 1
    assert [x["status"] for x in data["recipients"]] == ["ELIGIBLE","ELIGIBLE","HELD"]
    assert "no-reply@sheboyganlights.org" in data["sender"]
    assert "preview does not inspect or change delivery" in data["automatic_status"]
    assert data["captain_status"]=="OFF"
    assert data["metrics"]["total_tasks"]==296
    assert data["metrics"]["containers_park_recorded"]==3
    assert data["metrics"]["containers_returned"]==1
    assert "Containers · Field movement" in data["body_html"]
    assert data["metrics"]["remaining_tasks"]==206
    assert data["preview_for"]=="Administrator Example"
    assert resp.headers["Cache-Control"].startswith("private, no-store")


def test_only_admin_can_open_screen(client,monkeypatch):
    monkeypatch.setattr(m,"require_admin",lambda:(_ for _ in ()).throw(
        SetupCommandError("not authorized")
    ))
    assert client.get("/notifications/").status_code==403
    assert client.get("/api/setup/notifications/manager-preview").status_code==403


def test_missing_cloudflare_login_is_unauthorized(client,monkeypatch):
    monkeypatch.setattr(m,"require_admin",lambda:(_ for _ in ()).throw(
        SetupAuthenticationError("missing")
    ))
    assert client.get("/notifications/").status_code==401
    assert client.get("/api/setup/notifications/manager-preview").status_code==401


def test_admin_can_open_actual_candidate_screen(client,monkeypatch):
    monkeypatch.setattr(m,"require_admin",lambda:(None,"admin@sheboyganlights.org",{}))
    result=client.get("/notifications/")
    assert result.status_code==200
    html=result.get_data(as_text=True)
    assert "Manager email" in html
    assert "recipient" in html
    assert "manager-preview" in html
    assert "No messages sent" in html


def test_empty_recipient_or_db_problem_fails_closed(client,monkeypatch):
    monkeypatch.setattr(m,"require_admin",lambda:(None,"admin@sheboyganlights.org",{}))
    monkeypatch.setattr(m,"_piloted_digest_module",lambda:SimpleNamespace(
        manager_directory=lambda dsn: (_ for _ in ()).throw(RuntimeError("Sensitive DSN")),
    ))
    resp=client.get("/api/setup/notifications/manager-preview")
    assert resp.status_code==503
    assert "Sensitive DSN" not in resp.get_data(as_text=True)
    assert "STOP" in resp.get_data(as_text=True)


def test_no_post_actions_or_send_routes(client,monkeypatch):
    monkeypatch.setattr(m,"require_admin",lambda:(None,"admin@sheboyganlights.org",{}))
    assert client.post("/api/setup/notifications/manager-preview",json={}).status_code==405
    assert client.post("/api/setup/notifications/send",json={}).status_code==404


def test_disposable_dsn_is_preserved_and_sender_guard_stays_strict(client, monkeypatch):
    from setup_api import setup_database_dsn
    # Load the actual sender module; only DB reads in the browser fixture are fake.
    import importlib.util
    spec = importlib.util.spec_from_file_location("actual_sender_guard", m._PILOT_DIR / "manager_mail_pilot.py")
    pilot = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pilot)
    clone_dsn = "host=172.18.0.2 port=5432 dbname=msb_disposable user=fieldwiring_app"
    monkeypatch.setenv("SETUP_DATABASE_DSN", clone_dsn)
    assert setup_database_dsn() == clone_dsn
    with pytest.raises(pilot.PilotStop):
        pilot.accepted_setup_dsn()
    monkeypatch.setattr(m, "setup_database_dsn", setup_database_dsn)
    monkeypatch.setattr(m, "require_admin", lambda: (None, "admin@sheboyganlights.org", {}))
    class CloneRepo:
        def __init__(self, dsn):
            assert dsn == clone_dsn
        def board(self, year):
            return {"session": {"season_year": year}, "tasks": []}
    monkeypatch.setattr(m, "SetupSchedulingBoardRepository", CloneRepo)
    assert client.get("/api/setup/notifications/manager-preview").status_code == 200


def test_safe_failure_stage_and_reference(client, monkeypatch, caplog):
    monkeypatch.setattr(m, "require_admin", lambda: (None, "admin@sheboyganlights.org", {}))
    monkeypatch.setattr(m, "setup_database_dsn", lambda: (_ for _ in ()).throw(RuntimeError("password=secret")))
    response = client.get("/api/setup/notifications/manager-preview")
    assert response.status_code == 503
    data = response.get_json()
    assert data["failure_stage"] == "read Manager directory"
    assert data["reference"] in caplog.text
    assert "password=secret" not in caplog.text + response.get_data(as_text=True)


def test_actual_templates_render_23_notes_through_disposable_endpoint(client, monkeypatch):
    from test_205_manager_mail_pilot import mail, fixture_containers
    from html import unescape
    import re
    tasks = [dict(setup_session_task_id=i, task_name=f'Task {i}', execution_status='IN_PROGRESS',
                  percent_complete=50, future_assignment_count=0) for i in range(1, 24)]
    evidence = {i:dict(setup_task_progress_id=100+i, performed_on='2026-10-30', percent_complete=50,
                      progress_note=f'Original work {i}\nOther task owns <wiring>.', recorded_by='Greg')
                for i in range(1, 24)}
    roster = m._piloted_digest_module().manager_directory('isolated-readonly')
    monkeypatch.setattr(m, '_piloted_digest_module', lambda: mail)
    monkeypatch.setattr(mail, 'manager_directory', lambda dsn: roster)
    monkeypatch.setattr(mail, 'report_work_evidence', lambda dsn, ids: evidence)
    monkeypatch.setattr(mail, 'container_summary', lambda dsn, season_year: fixture_containers())
    monkeypatch.setattr(m, 'require_admin', lambda: (None, 'admin@sheboyganlights.org', {}))
    class Board:
        def __init__(self, dsn):
            assert dsn == 'isolated-readonly'
        def board(self, year):
            return dict(session={'season_year': year}, tasks=tasks)
    monkeypatch.setattr(m, 'SetupSchedulingBoardRepository', Board)
    response = client.get('/api/setup/notifications/manager-preview')
    assert response.status_code == 200
    data = response.get_json()
    assert data['metrics']['continuation_needed'] == len(data['continuation_evidence']) == 23
    html_text = unescape(re.sub('<[^>]*>', '', data['body_html']))
    for row in data['continuation_evidence']:
        assert row['note'] == evidence[row['id']]['progress_note']
        assert row['detail'] in data['body_text'] and row['detail'] in html_text
    assert 'https://my.sheboyganlights.org/setup/' not in data['body_html']
