"""#205 notification contract tests: no SMTP, no network, no Production writes."""
from datetime import date
from io import BytesIO
import json
from urllib.error import URLError

import pytest
import setup_notification_service as mail


TODAY = date(2026,10,15)


def board():
    return {
        "session":{"season_year":2026},
        "tasks":[
            {"setup_session_task_id":10,"task_name":"Place Polar Express Engine",
             "stage_name":"North Pole","execution_status":"IN_PROGRESS",
             "effective_complete":False,"percent_complete":90,
             "future_assignment_count":0,"prerequisites_complete":False,
             "readiness_state":"NOT_READY","readiness_note":"Ground needs repair"},
            {"setup_session_task_id":11,"task_name":"Finished Yesterday","stage_name":"Train",
             "execution_status":"COMPLETE","effective_complete":True,
             "future_assignment_count":0,"percent_complete":100},
            {"setup_session_task_id":12,"task_name":"Next Week","stage_name":"Park",
             "execution_status":"PLANNED","effective_complete":False,
             "future_assignment_count":1, "prerequisites_complete":True,
             "readiness_state":"READY"},
        ],
        "work_days":[
            {"setup_work_day_id":1,"work_date":"2026-10-13","setup_day_number":12,"day_status":"PLANNED"},
            {"setup_work_day_id":2,"work_date":"2026-10-14","setup_day_number":13,"day_status":"PLANNED"},
            {"setup_work_day_id":3,"work_date":"2026-10-16","setup_day_number":14,"day_status":"PLANNED"},
            {"setup_work_day_id":4,"work_date":"2026-10-11","setup_day_number":11,"day_status":"CANCELLED"}
        ],
        "crews":[
            {"setup_work_day_crew_id":1,"crew_code":"A","captain_person_id":25,
             "captain_display_name":"Captain Sample"},
            {"setup_work_day_crew_id":2,"crew_code":"B","captain_person_id":None,
             "captain_display_name":None},
        ],
        "assignments":[
            {"setup_work_day_task_id":100,"setup_work_day_id":1,
             "setup_session_task_id":10,"setup_work_day_crew_id":1,"shift_code":"MORNING",
             "work_report_count":0},
            {"setup_work_day_task_id":101,"setup_work_day_id":2,
             "setup_session_task_id":11,"setup_work_day_crew_id":1,"shift_code":"AFTERNOON",
             "work_report_count":0},
            {"setup_work_day_task_id":102,"setup_work_day_id":3,
             "setup_session_task_id":12,"setup_work_day_crew_id":2,"shift_code":"ALL_DAY",
             "work_report_count":0},
            {"setup_work_day_task_id":103,"setup_work_day_id":4,
             "setup_session_task_id":10,"setup_work_day_crew_id":1,"shift_code":"AFTERNOON",
             "work_report_count":0},
            {"setup_work_day_task_id":104,"setup_work_day_id":2,
             "setup_session_task_id":10,"setup_work_day_crew_id":1,"shift_code":"AFTERNOON",
             "work_report_count":1},
        ]
    }


def people():
    return [
        {"person_id":1,"email":"manager@sheboyganlights.org",
         "display_name":"Manager","can_manage_setup":True,"can_read_setup":True},
        {"person_id":2,"email":"second@sheboyganlights.org",
         "display_name":"Added Manager","can_manage_setup":True,"can_read_setup":True},
        {"person_id":25,"email":"captain@sheboyganlights.org",
         "display_name":"Captain Sample","can_manage_setup":False,"can_read_setup":True},
    ]


def test_past_no_report_preserved_after_annual_completion_and_canceled_ignored():
    c=mail.notification_context(board(),TODAY)
    assert [x["assignment_id"] for x in c["overdue"]]==[100,101]
    assert len(c["continuation"])==1
    assert c["continuation"][0]["percent_complete"]==90
    assert c["captain_tbd"][0]["assignment_id"]==102


def test_partial_report_suppresses_missing_report_but_not_continuation():
    b=board()
    b["assignments"][0]["work_report_count"]=1
    c=mail.notification_context(b,TODAY)
    assert [x["assignment_id"] for x in c["overdue"]]==[101]
    assert [x["task_id"] for x in c["continuation"]]==[10]


def test_future_unworked_assignment_is_not_a_missing_historical_report():
    c=mail.notification_context(board(),TODAY)
    assert 102 not in [x["assignment_id"] for x in c["overdue"]]


def test_dynamic_manager_roster_and_captain_isolation():
    plans=mail.notice_plans(board(),people(),TODAY)
    assert sum(p["kind"]=="MANAGER_DAILY" for p in plans)==2
    captain=[p for p in plans if p["kind"]=="CAPTAIN_DAILY"]
    assert len(captain)==1
    assert captain[0]["recipient_email"]=="captain@sheboyganlights.org"
    assert "Place Polar Express Engine" in captain[0]["body_text"]
    assert "Finished Yesterday" in captain[0]["body_text"]
    assert "Next Week" not in captain[0]["body_text"]
    assert "Please report your work" in captain[0]["subject"]
    assert len({p["message_key"] for p in plans})==len(plans)


def test_unmapped_captain_routes_to_manager_only():
    p=[x for x in people() if x["person_id"]!=25]
    plans=mail.notice_plans(board(),p,TODAY)
    assert len(plans)==2
    assert all(x["kind"]=="MANAGER_DAILY" for x in plans)


def test_removed_manager_reevaluates_and_does_not_receive():
    p=people()
    p[1]["can_manage_setup"]=False
    plans=mail.notice_plans(board(),p,TODAY)
    assert sum(x["kind"]=="MANAGER_DAILY" for x in plans)==1


def test_invalid_person_mail_is_never_eligible():
    assert mail.organizational_email("someone@gmail.com") is None
    assert mail.organizational_email("bad @sheboyganlights.org") is None
    assert mail.organizational_email("CAPTAIN@SHEBOYGANLIGHTS.ORG")=="captain@sheboyganlights.org"


def test_transport_disabled_fails_before_network_or_token(monkeypatch):
    monkeypatch.delenv("SETUP_NOTIFICATION_DAILY_ENABLED",raising=False)
    client=mail.DirectusSetupOutboxClient(token="fake-token")
    with pytest.raises(mail.SetupNotificationError,match="not enabled"):
        client.queue(mail.notice_plans(board(),people(),TODAY)[0])


def test_directus_transport_forbids_external_host():
    with pytest.raises(mail.SetupNotificationError,match="loopback-only"):
        mail.DirectusSetupOutboxClient(base_url="https://public.sheboyganlights.org",token="fake")


def test_directus_items_post_is_only_transport_and_does_not_claim_delivery(monkeypatch):
    monkeypatch.setenv("SETUP_NOTIFICATION_DAILY_ENABLED","1")
    requested=[]
    class Response:
        def __enter__(self):return self
        def __exit__(self,*args):pass
        def read(self):return b'{"data":{"id":"opaque-id"}}'
    class FakeOpener:
        def open(self,req,timeout):
            requested.append((req.full_url,req.get_method(),json.loads(req.data),timeout))
            return Response()
    monkeypatch.setattr(mail,"DIRECTUS_OPENER",FakeOpener())
    client=mail.DirectusSetupOutboxClient(token="test-credential")
    result=client.queue(mail.notice_plans(board(),people(),TODAY)[0])
    assert result=={"outbox_id":"opaque-id","status":"QUEUED_NOT_DELIVERED"}
    url,method,payload,timeout=requested[0]
    assert url=="http://127.0.0.1:8055/items/setup_notification_outbox"
    assert method=="POST" and timeout==15
    assert "recipient_email" in payload and "message_key" in payload


def test_network_timeout_is_delivery_unknown_no_auto_retry(monkeypatch):
    monkeypatch.setenv("SETUP_NOTIFICATION_DAILY_ENABLED","1")
    class Broken:
        def open(self,*a,**kw):
            raise URLError("unreachable")
    monkeypatch.setattr(mail,"DIRECTUS_OPENER",Broken())
    client=mail.DirectusSetupOutboxClient(token="test")
    with pytest.raises(mail.SetupNotificationError,match="UNKNOWN"):
        client.queue(mail.notice_plans(board(),people(),TODAY)[0])


def test_2026_only_and_no_fake_report():
    wrong=board()
    wrong["session"]["season_year"]=2027
    with pytest.raises(mail.SetupNotificationError,match="2026"):
        mail.notice_plans(wrong,people(),TODAY)
    _,body=mail.captain_email(mail.notification_context(board(),TODAY)["overdue"])
    assert "DO NOT invent hours" in body
    assert "Correct report" in body


def test_manager_self_email_is_guarded_in_source():
    from pathlib import Path
    api=(Path(__file__).parent/"setup_notification_api.py").read_text()
    assert "require_manager()" in api and "require_setup_command()" in api
    assert 'operator["email"]' in api and '"MANAGER_SELF_TEST"' in api
    assert "test_mode=True" in api and "json_body()" in api
