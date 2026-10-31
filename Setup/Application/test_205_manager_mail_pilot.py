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


def fixture_containers():
    return {
        "containers_total":8, "containers_park_recorded":3,
        "containers_outbound":1, "containers_empty_at_park":1,
        "containers_partial_at_park":1, "containers_returned":1,
        "containers_no_movement":2, "containers_location_review":1,
        "containers_contents_review_history":1,
        "containers_snapshot_as_of":"2026-10-17 02:00:00-05:00",
        "containers_session_id":2,
        "containers_evidence_note":"Recorded state; not verified empty",
    }


def setup_fakes(monkeypatch):
    class BoardRepo:
        def __init__(self, dsn):
            assert dsn == "fixture"
        def board(self, year):
            assert year == 2026
            return fixture_board()
    monkeypatch.setattr(mail,"container_summary",lambda dsn,season_year:fixture_containers())
    monkeypatch.setitem(sys.modules,"setup_scheduling_board_repository",
                        SimpleNamespace(SetupSchedulingBoardRepository=BoardRepo))
    monkeypatch.setattr(mail,"manager_directory",lambda dsn:[
        {"person_id":1,"email":"manager@sheboyganlights.org","display_name":"Manager One",
         "is_manager":True,"can_manage_setup":True,"identity_linked":True,
         "send_eligible":True,"review_status":"ELIGIBLE","review_reason":"Eligible"},
        {"person_id":2,"email":"second@sheboyganlights.org","display_name":"Manager Two",
         "is_manager":True,"can_manage_setup":True,"identity_linked":True,
         "send_eligible":True,"review_status":"ELIGIBLE","review_reason":"Eligible"},
    ])


def time_at(hour=4, day=17):
    return datetime(2026,10,day,hour,0,tzinfo=CHI)


def test_people_directory_has_no_direct_directus_select_and_keeps_held_rows():
    source = (PILOT_PATH/"manager_mail_pilot.py").read_text(encoding="utf-8")
    sql = source.split('    sql = """',1)[1].split('"""',1)[0]
    assert "FROM ref.person p" in sql
    assert "ref.setup_browser_capabilities(" in sql
    assert "JOIN public.directus_users" not in sql
    assert "SELECT p.person_id" in sql

    checked = mail.classify_manager_directory([
        {"person_id":11,"display_name":"A","email":"a@sheboyganlights.org",
         "is_manager":True,"identity_linked":True,"can_manage_setup":True},
        {"person_id":12,"display_name":"B","email":"b@sheboyganlights.org",
         "is_manager":True,"identity_linked":False,"can_manage_setup":False},
        {"person_id":13,"display_name":"C","email":"c@sheboyganlights.org",
         "is_manager":False,"identity_linked":True,"can_manage_setup":True},
    ])
    assert checked[0]["send_eligible"] is True
    assert checked[1]["review_status"] == "ELIGIBLE"
    assert "People-to-Directus link pending onboarding" in checked[1]["onboarding_note"]
    assert checked[2]["review_status"] == "ELIGIBLE"
    assert "Current Setup Manager" in checked[2]["onboarding_note"]


def test_duplicate_people_email_addresses_never_sent():
    rows = [
        {"person_id":i,"display_name":str(i),"email":"same@sheboyganlights.org",
         "is_manager":True,"identity_linked":True,"can_manage_setup":True}
        for i in (1,2)
    ]
    checked = mail.classify_manager_directory(rows)
    assert all(x["review_status"] == "HELD" for x in checked)
    assert all("Duplicate" in x["review_reason"] for x in checked)


def test_manager_email_live_holds_disputed_people_roster(monkeypatch,tmp_path):
    setup_fakes(monkeypatch)
    # Append a flagged, unauthenticated person to the fake eligible roster.
    eligible = mail.manager_directory("fixture")
    monkeypatch.setattr(mail, "manager_directory",lambda dsn: eligible + [{
        "person_id":20,"email":"held@sheboyganlights.org","display_name":"Held Person",
        "is_manager":True,"send_eligible":False,"review_status":"HELD",
        "review_reason":"No current Setup Manager access"
    }])
    monkeypatch.setattr(mail,"deliver",lambda *a:pytest.fail("SMTP attempted"))
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_SEND",mail.SEND_GUARD)
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED","1")
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER",
                       "manager@sheboyganlights.org,second@sheboyganlights.org")
    with pytest.raises(mail.PilotStop,match="unknown or malformed"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(),"live",None)


def test_urgent_manager_roster_randy_and_don_not_excluded():
    rows = mail.classify_manager_directory([
        {"person_id":18,"display_name":"Don","email":"dmartens@sheboyganlights.org",
         "is_manager":True,"identity_linked":False,"can_manage_setup":True},
        {"person_id":19,"display_name":"Randy","email":"rmiller@sheboyganlights.org",
         "is_manager":False,"identity_linked":True,"can_manage_setup":True},
    ])
    assert len(rows)==2 and all(p["send_eligible"] for p in rows)
    assert "onboarding" in rows[0]["onboarding_note"]
    assert "Current Setup Manager" in rows[1]["onboarding_note"]


def test_live_requires_exact_operator_acknowledged_email_roster(monkeypatch):
    rows=mail.classify_manager_directory([
        {"person_id":18,"display_name":"Don","email":"dmartens@sheboyganlights.org",
         "is_manager":True,"identity_linked":False,"can_manage_setup":True},
        {"person_id":19,"display_name":"Randy","email":"rmiller@sheboyganlights.org",
         "is_manager":False,"identity_linked":True,"can_manage_setup":True},
    ])
    monkeypatch.delenv("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER",raising=False)
    with pytest.raises(mail.PilotStop,match="not approved"):
        mail.enforce_approved_manager_audience(rows,rows)
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER",
                       "dmartens@sheboyganlights.org,rmiller@sheboyganlights.org")
    mail.enforce_approved_manager_audience(rows,rows)
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER",
                       "dmartens@sheboyganlights.org")
    with pytest.raises(mail.PilotStop,match="differs"):
        mail.enforce_approved_manager_audience(rows,rows)


def test_whole_setup_counts_and_historical_classification():
    a = mail.summarize(fixture_board(),date(2026,10,17))
    a.update(fixture_containers())
    assert [a["total_tasks"],a["completed_tasks"],a["remaining_tasks"]] == [3,1,2]
    assert a["blocked_tasks"] == 1
    assert a["missing_report_occurrences"] == 1
    assert a["continuation_needed"] == 1
    assert "Partially built" in a["overdue_lines"]
    assert "Future work" not in a["overdue_lines"]
    assert a["projected_finish"] == "INSUFFICIENT DATA"


def test_template_is_external_reviewable_and_no_fake_reporting():
    a = mail.summarize(fixture_board(),date(2026,10,17))
    a.update(fixture_containers())
    source = mail.DEFAULT_TEMPLATE.read_text(encoding="utf-8")
    body = mail.render(source,{"display_name":"Manager One"},a)
    assert "Good morning Manager One" in body
    assert "Reschedule" in body and "Do not enter fictitious" in body
    assert "No Captain reminders are being sent" in body
    assert "$" not in body


def test_manager_email_leads_with_kpis_not_training_or_a_long_task_list():
    report = mail.summarize(fixture_board(),date(2026,10,17))
    report.update(fixture_containers())
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
    monkeypatch.setattr(mail,"manager_directory",lambda dsn:pytest.fail("queried"))
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
    monkeypatch.setattr(mail,"deliver",lambda recipient,subject,body,html_body:
                        seen.append(recipient) or "SMTP_ACCEPTED_NOT_DELIVERED")
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER",
        "manager@sheboyganlights.org,second@sheboyganlights.org")
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
    monkeypatch.setattr(mail,"deliver",lambda recipient,subject,body,html_body:
                        seen.append(recipient) or "SMTP_ACCEPTED_NOT_DELIVERED")
    mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(20,16),
              "test","manager@sheboyganlights.org")
    assert seen==["manager@sheboyganlights.org"]
    with pytest.raises(mail.PilotStop,match="not exactly one"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(20,16),
                  "test","volunteer@example.org")
    assert len(seen)==1


def test_existing_88_171_container_projector_is_evidence_qualified():
    make = lambda ident, status, load="UNKNOWN", note=None, event=None: {
        "container_id":ident,"movement_status":status,"load_state":load,
        "current_location_note":note,"observation":event or {},
    }
    rows=[
        make(1,"DELIVERED","LOADED"),
        make(2,"CONTAINER_MOVE","EMPTY","Near Icicle Tunnel"),
        make(3,"STAGED","PARTIAL"),
        make(4,"PICKED"),
        make(5,"RETURNED","EMPTY"),
        make(6,None),
        make(7,None),
        make(8,"CONTAINER_MOVE","UNKNOWN"),
    ]
    counts=mail.summarize_container_snapshot(rows,"2026-10-17T02:00:00-05:00")
    assert counts["containers_park_recorded"]==3
    assert counts["containers_empty_at_park"]==1
    assert counts["containers_partial_at_park"]==1
    assert counts["containers_outbound"]==1
    assert counts["containers_returned"]==1
    assert counts["containers_no_movement"]==2
    assert counts["containers_location_review"]==1
    assert counts["containers_total"]==8
    assert "not physical inspections" in counts["containers_evidence_note"]
    assert counts["containers_empty_at_park"] <= counts["containers_park_recorded"]


def test_html_protects_people_task_content_and_matches_text_numbers():
    report=mail.summarize(fixture_board(),date(2026,10,17))
    report.update(fixture_containers())
    report["past_rows"][0]["name"]='<script>alert("no")</script>'
    email=mail.render_html(mail.DEFAULT_HTML_TEMPLATE.read_text(encoding="utf-8"),
                           {"display_name":"A & B"},report)
    assert "Containers · Field movement" in email
    assert "Park stops recorded" in email
    assert "Returned Home" in email
    assert "8 reference Containers" in email
    assert "A &amp; B" in email
    assert "&lt;script&gt;" in email
    assert '<script>alert("no")</script>' not in email
    assert "$" not in email


def test_header_uses_exact_existing_setup_dark_white_logo_only():
    html = mail.DEFAULT_HTML_TEMPLATE.read_text(encoding="utf-8")
    theme = (PILOT_PATH.parents[1] / "Application" / "setup_theme.js").read_text(encoding="utf-8")
    svg = "https://webassets.sheboyganlights.org/images/branding/msb-white-logo-600-plain.svg"
    logo = "https://webassets.sheboyganlights.org/images/branding/msb-white-logo-600-plain.png"
    assert svg in theme
    assert logo == svg.removesuffix(".svg") + ".png"
    assert html.count(logo) == 1
    assert svg not in html
    assert 'alt="Making Spirits Bright"' in html
    assert 'width="177"' in html
    assert html.count('width="177"') == 1
    assert 'valign="middle"' in html
    assert html.index(logo) < html.index("Making Spirits Bright · Production")
    assert html.index(logo) < html.index("Setup Morning Brief")
    header = html.split("</td></tr>", 1)[0]
    assert '<table role="presentation"' in header
    assert header.index(logo) < header.index("Setup Morning Brief")
    assert "msb-white-logo-600-plain.svg" not in html
    assert "https://my.sheboyganlights.org/setup/" in html


def test_mail_delivery_contains_html_and_complete_plain_text(monkeypatch):
    sent=[]
    class SMTP:
        def __init__(self,host,port,timeout):
            assert (host,port)==("smtp-relay.gmail.com",587)
            self.started=False
        def close(self):pass
        def __enter__(self):return self
        def __exit__(self,*a):return None
        def ehlo(self):return 250, b"ok"
        def has_extn(self,x):return x=="starttls"
        def starttls(self,context):
            self.started=True
        def send_message(self,message,from_addr,to_addrs):
            assert self.started
            sent.append(message)
            assert from_addr=="no-reply@sheboyganlights.org"
            assert to_addrs==["manager@sheboyganlights.org"]
            return {}
    monkeypatch.setattr(mail.smtplib,"SMTP",SMTP)
    result=mail.deliver("manager@sheboyganlights.org","TEST","Text body",
                        "<html><body>Styled</body></html>")
    assert result=="SMTP_ACCEPTED_NOT_DELIVERED"
    assert len(sent)==1 and sent[0].get_content_type()=="multipart/alternative"
    assert sent[0].get_body(preferencelist=('plain',)).get_content()=="Text body\n"
    assert "Styled" in sent[0].get_body(preferencelist=('html',)).get_content()


def test_host_only_production_env_gets_accepted_db_user_without_password_exposure(monkeypatch):
    from psycopg2.extensions import parse_dsn
    for key in ("SETUP_DATABASE_DSN","FIELDWIRING_DATABASE_DSN","PROCEDURE_DATABASE_DSN"):
        monkeypatch.delenv(key,raising=False)
    monkeypatch.setenv("SETUP_DATABASE_DSN","host=127.0.0.1")
    opts=parse_dsn(mail.accepted_setup_dsn())
    assert opts["host"]=="127.0.0.1"
    assert opts["dbname"]=="msb"
    assert opts["user"]=="fieldwiring_app"
    assert opts["port"]=="5432"


def test_other_database_or_role_is_never_substituted(monkeypatch):
    for raw in ("host=otherhost", "dbname=some_other_db",
                "user=msbadmin", "port=1555"):
        monkeypatch.setenv("SETUP_DATABASE_DSN",raw)
        with pytest.raises(mail.PilotStop,match="does not match"):
            mail.accepted_setup_dsn()


def test_formatted_review_is_distinct_one_recipient_and_keeps_original_test_receipt(monkeypatch,tmp_path):
    setup_fakes(monkeypatch)
    monkeypatch.setattr(mail, "manager_directory", lambda dsn: [
        {"person_id":17,"email":"gliebig@sheboyganlights.org","display_name":"Greg",
         "is_manager":True,"send_eligible":True,"review_status":"ELIGIBLE",
         "review_reason":"Current Setup Manager","identity_linked":True,
         "can_manage_setup":True},
        {"person_id":15,"email":"rhoffmann@sheboyganlights.org","display_name":"Rick",
         "is_manager":True,"send_eligible":True,"review_status":"ELIGIBLE",
         "review_reason":"Current Setup Manager","identity_linked":True,
         "can_manage_setup":True},
    ])
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_SEND",mail.SEND_GUARD)
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED","1")
    sent=[]
    def stub_delivery(to,subject,body,html):
        assert html.startswith("<!doctype html>")
        assert "Containers · Field movement" in html
        assert "CONTAINERS — RECORDED FIELD MOVEMENT" in body
        sent.append((to,subject))
        return "SMTP_ACCEPTED_NOT_DELIVERED"
    monkeypatch.setattr(mail,"deliver",stub_delivery)
    day=time_at()
    # The existing accepted original test remains its own protected attempt.
    first=mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,day,"test",
                    "gliebig@sheboyganlights.org")
    files_before=set(p.name for p in tmp_path.iterdir())
    assert len(files_before)==1
    original=next(iter(tmp_path.iterdir()))
    original_bytes=original.read_bytes()
    second=mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,day,"html_test",
                     "gliebig@sheboyganlights.org")
    assert first["recipients"]==1 and second["recipients"]==1
    assert sent==[
        ("gliebig@sheboyganlights.org","TEST — MSB Setup — Manager Actions — 2026-10-17"),
        ("gliebig@sheboyganlights.org","FORMATTED TEST — MSB Setup — Manager Actions — 2026-10-17"),
    ]
    all_files=list(tmp_path.iterdir())
    assert len(all_files)==2
    assert original.read_bytes()==original_bytes
    assert any(x.name.startswith("test-") for x in all_files)
    assert any(x.name.startswith("html-test-") for x in all_files)
    import json
    receipt=next(x for x in all_files if x.name.startswith("html-test-"))
    assert json.loads(receipt.read_text())["purpose"]=="MANAGER_HTML_REVIEW_TEST"
    with pytest.raises(mail.PilotStop,match="Prior recipient attempt"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,day,"html_test",
                  "gliebig@sheboyganlights.org")
    assert len(sent)==2


@pytest.mark.parametrize("day,recipient", [
    (17,"other@sheboyganlights.org"),(18,"gliebig@sheboyganlights.org"),
    (16,"gliebig@sheboyganlights.org"),
])
def test_formatted_review_wrong_person_or_day_fails_before_any_db_or_smtp(
        monkeypatch,tmp_path,day,recipient):
    monkeypatch.setattr(mail,"manager_directory",lambda dsn:pytest.fail("no DB query"))
    monkeypatch.setattr(mail,"deliver",lambda *a:pytest.fail("no SMTP"))
    with pytest.raises(mail.PilotStop,match="Formatted test limited"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(day=day),
                  "html_test",recipient)
    assert not list(tmp_path.iterdir())


def test_final_logo_review_distinct_from_both_prior_receipts(monkeypatch,tmp_path):
    setup_fakes(monkeypatch)
    monkeypatch.setattr(mail,"manager_directory",lambda dsn:[
        {"person_id":17,"email":"gliebig@sheboyganlights.org","display_name":"Greg",
         "is_manager":True,"send_eligible":True,"review_status":"ELIGIBLE",
         "review_reason":"Eligible","identity_linked":True,"can_manage_setup":True},
    ])
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_SEND",mail.SEND_GUARD)
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED","1")
    sent=[]
    def delivery(recipient,subject,body,html):
        assert recipient=="gliebig@sheboyganlights.org"
        assert subject.startswith("FINAL LOGO TEST —")
        assert "msb-white-logo-600-plain.png" in html
        assert ".svg" not in html
        sent.append(recipient)
        return "SMTP_ACCEPTED_NOT_DELIVERED"
    monkeypatch.setattr(mail,"deliver",delivery)
    import hashlib
    digest=hashlib.sha256(b"gliebig@sheboyganlights.org").hexdigest()[:24]
    for prefix in ("test", "html-test"):
        (tmp_path/f"{prefix}-2026-10-17-{digest}.json").write_text('{"status":"SMTP_ACCEPTED_NOT_DELIVERED"}')
    prior={p.name:p.read_bytes() for p in tmp_path.iterdir()}
    result=mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(),"logo_test",
                     "gliebig@sheboyganlights.org")
    assert result["recipients"]==1 and sent==["gliebig@sheboyganlights.org"]
    for name,value in prior.items():
        assert (tmp_path/name).read_bytes()==value
    receipt=tmp_path/f"logo-test-2026-10-17-{digest}.json"
    assert receipt.exists()
    import json
    assert json.loads(receipt.read_text())["purpose"]=="MANAGER_LOGO_REVIEW_TEST"
    with pytest.raises(mail.PilotStop,match="Prior recipient attempt"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(),"logo_test",
                  "gliebig@sheboyganlights.org")
    assert len(sent)==1


@pytest.mark.parametrize("day,recipient", [
    (16,"gliebig@sheboyganlights.org"),(18,"gliebig@sheboyganlights.org"),
    (17,"rhoffmann@sheboyganlights.org"),
])
def test_final_logo_review_wrong_date_or_person_never_queries_or_sends(
        monkeypatch,tmp_path,day,recipient):
    monkeypatch.setattr(mail,"manager_directory",lambda dsn:pytest.fail("DB read"))
    monkeypatch.setattr(mail,"deliver",lambda *a:pytest.fail("email sent"))
    with pytest.raises(mail.PilotStop,match="Final logo test limited"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,time_at(day=day),"logo_test",recipient)


def test_final_logo_review_cli_cannot_redirect_protected_receipts(monkeypatch,tmp_path,capsys):
    monkeypatch.setenv("SETUP_DATABASE_DSN","host=127.0.0.1")
    assert mail.main(["--logo-test-to","gliebig@sheboyganlights.org",
                      "--ledger",str(tmp_path)])==2
    assert "STOP" in capsys.readouterr().out


def test_no_sender_header_from_operator_content():
    assert mail.FROM == "no-reply@sheboyganlights.org"
    assert not hasattr(mail,"captain_email")


@pytest.mark.parametrize("gate,complete,expected", [(True,True,0),(True,False,1),(False,True,1)])
def test_completed_work_order_gate_needs_no_duplicate_setup_report(gate,complete,expected):
    board=fixture_board()
    task=board["tasks"][1]
    task.update(task_name="Replace Light Pole 8 Outlet Box",execution_status="PLANNED",
                linked_work_order_gate=gate,linked_work_order_id=416,effective_complete=complete)
    report=mail.summarize(board,date(2026,10,17))
    report.update(fixture_containers())
    assert report["missing_report_occurrences"]==expected
    assert (task["task_name"] in report["overdue_lines"]) == bool(expected)
    html=mail.render_html(mail.DEFAULT_HTML_TEMPLATE.read_text(),{"display_name":"Fixture"},report)
    assert (task["task_name"] in html) == bool(expected)
