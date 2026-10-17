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
            "report_date": today.isoformat(), "completion_percent":"30.4",
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
        manager_directory=lambda dsn: fake_managers,
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
    assert data["automatic_status"]=="NOT ACTIVATED"
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
