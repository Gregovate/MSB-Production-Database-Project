"""Offline regressions: no sockets, database, or email."""
import smtplib
import ssl
import pytest
from test_205_manager_mail_pilot import mail

class SMTP:
    def __init__(self, failure=None):
        self.failure = failure
        self.submissions = 0
        self.closed = False
    def ehlo(self):
        if self.failure == "ehlo":
            raise smtplib.SMTPServerDisconnected("fixture")
        return 250, b"ok"
    def has_extn(self, name):
        return self.failure != "no_tls"
    def starttls(self, context):
        assert context.check_hostname
        assert context.verify_mode == ssl.CERT_REQUIRED
        if self.failure == "certificate":
            raise ssl.SSLCertVerificationError("fixture")
    def send_message(self, message, **kwargs):
        self.submissions += 1
        assert message.get_content_type() == "multipart/alternative"
        assert kwargs["from_addr"] == mail.FROM
        if self.failure == "submission":
            raise smtplib.SMTPServerDisconnected("fixture")
        return {}
    def close(self):
        self.closed = True
        if self.failure == "close":
            raise OSError("fixture")

def call():
    return mail.deliver("example@sheboyganlights.org", "Fixture", "Text", "<p>HTML</p>")

def install(monkeypatch, values):
    created = []
    sleeps = []
    def factory(*args, **kwargs):
        v = values[len(created)]
        created.append(v)
        if isinstance(v, Exception):
            raise v
        return v
    monkeypatch.setattr(mail.smtplib, "SMTP", factory)
    monkeypatch.setattr(mail.time, "sleep", sleeps.append)
    return created, sleeps

def test_connection_disconnect_retries_before_any_submission(monkeypatch):
    good = SMTP()
    made, sleeps = install(monkeypatch, [smtplib.SMTPServerDisconnected("fixture"), good])
    assert call() == "SMTP_ACCEPTED_NOT_DELIVERED"
    assert len(made) == 2 and sleeps == [1] and good.submissions == 1

def test_ehlo_retries_are_bounded_and_closed(monkeypatch):
    sessions = [SMTP("ehlo") for _ in range(3)]
    made, sleeps = install(monkeypatch, sessions)
    with pytest.raises(mail.MailDeliveryError) as caught:
        call()
    assert caught.value.stage == "ehlo" and not caught.value.uncertain
    assert caught.value.attempts == 3 and sleeps == [1, 2]
    assert all(s.closed and s.submissions == 0 for s in sessions)

def test_submission_disconnect_never_retries(monkeypatch):
    session = SMTP("submission")
    made, sleeps = install(monkeypatch, [session])
    with pytest.raises(mail.MailDeliveryError) as caught:
        call()
    assert caught.value.uncertain and caught.value.stage == "submission"
    assert len(made) == 1 and sleeps == [] and session.submissions == 1

@pytest.mark.parametrize("failure", ["certificate", "no_tls"])
def test_tls_failures_never_downgrade_or_send(monkeypatch, failure):
    session = SMTP(failure)
    made, sleeps = install(monkeypatch, [session])
    with pytest.raises(mail.MailDeliveryError) as caught:
        call()
    assert caught.value.stage == "starttls" and not caught.value.uncertain
    assert len(made) == 1 and not sleeps and session.submissions == 0

def test_cleanup_error_does_not_erase_accepted_submission(monkeypatch):
    session = SMTP("close")
    install(monkeypatch, [session])
    assert call() == "SMTP_ACCEPTED_NOT_DELIVERED"
    assert session.submissions == 1

def test_invalid_recipient_never_connects(monkeypatch):
    monkeypatch.setattr(mail.smtplib, "SMTP", lambda *a, **k: pytest.fail("connected"))
    with pytest.raises(mail.PilotStop):
        mail.deliver("outside@example.com", "Fixture", "Text")

import hashlib
import json
from datetime import datetime
import pytest
from test_205_manager_mail_pilot import mail, setup_fakes, CHI

def enable(monkeypatch):
    setup_fakes(monkeypatch)
    monkeypatch.setenv("MSB_MANAGER_MAIL_STOP_DATE", "2026-11-27")
    monkeypatch.setenv("MSB_SETUP_MANAGER_SEASON_SEND", mail.SEASON_SEND_GUARD)
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", "1")
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER",
                       "manager@sheboyganlights.org,second@sheboyganlights.org")
    monkeypatch.setenv("MSB_SETUP_MANAGER_RECOVERY_DATE", "2026-10-22")

def test_recovery_preserves_uncertain_receipt_and_is_idempotent(monkeypatch, tmp_path):
    enable(monkeypatch)
    name = "manager-2026-10-22-" + hashlib.sha256(b"manager@sheboyganlights.org").hexdigest()[:24]+".json"
    original = b'{"status":"UNKNOWN_NO_AUTORETRY"}\n'
    (tmp_path/name).write_bytes(original)
    sent = []
    monkeypatch.setattr(mail, "deliver", lambda to,*args: sent.append(to) or "SMTP_ACCEPTED_NOT_DELIVERED")
    now = datetime(2026,10,22,10,0,tzinfo=CHI)
    result = mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,now,"recover",None)
    assert sent == ["second@sheboyganlights.org"]
    assert result["recipients"] == 1 and result["skipped_existing"] == 1
    assert (tmp_path/name).read_bytes() == original
    result = mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,now,"recover",None)
    assert result["recipients"] == 0 and result["skipped_existing"] == 2
    assert sent == ["second@sheboyganlights.org"]

def test_daily_failure_does_not_block_other_recipients(monkeypatch,tmp_path):
    enable(monkeypatch)
    sent = []
    def deliver(to,*args):
        sent.append(to)
        if len(sent) == 1:
            raise mail.MailDeliveryError("submission",mail.smtplib.SMTPServerDisconnected("fixture"),1)
        return "SMTP_ACCEPTED_NOT_DELIVERED"
    monkeypatch.setattr(mail,"deliver",deliver)
    with pytest.raises(mail.PilotStop,match="accepted=1, held=1"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,
                  datetime(2026,10,22,4,0,tzinfo=CHI),"daily",None)
    records = [json.loads(p.read_text()) for p in tmp_path.iterdir()]
    assert len(sent) == 2
    assert {r["status"] for r in records} == {"UNKNOWN_NO_AUTORETRY","SMTP_ACCEPTED_NOT_DELIVERED"}
    failed = next(r for r in records if r["status"] == "UNKNOWN_NO_AUTORETRY")
    assert failed["smtp_stage"] == "submission"
    assert failed["error_class"] == "SMTPServerDisconnected"

@pytest.mark.parametrize("day,guard",[(23,"2026-10-22"),(22,""),(22,"2026-10-21")])
def test_recovery_rejects_other_date_or_missing_authority(monkeypatch,tmp_path,day,guard):
    enable(monkeypatch)
    monkeypatch.setenv("MSB_SETUP_MANAGER_RECOVERY_DATE",guard)
    monkeypatch.setattr(mail,"manager_directory",lambda *a: pytest.fail("queried"))
    with pytest.raises(mail.PilotStop,match="Recovery requires"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,
                  datetime(2026,10,day,10,0,tzinfo=CHI),"recover",None)
    assert not list(tmp_path.iterdir())


@pytest.mark.parametrize("dry_run", [False, True])
def test_recovery_rejects_changed_audience(monkeypatch,tmp_path,dry_run):
    enable(monkeypatch)
    monkeypatch.setenv("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER", "other@sheboyganlights.org")
    monkeypatch.setattr(mail,"deliver",lambda *a:pytest.fail("SMTP called"))
    with pytest.raises(mail.PilotStop):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,datetime(2026,10,22,10,tzinfo=CHI),"recover",None,dry_run=dry_run)
    assert not list(tmp_path.iterdir())


def test_recovery_preview_checks_approval_and_never_sends(monkeypatch,tmp_path):
    enable(monkeypatch)
    monkeypatch.setattr(mail,"deliver",lambda *a:pytest.fail("SMTP called"))
    now=datetime(2026,10,22,10,tzinfo=CHI)
    result=mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,now,"recover",None,dry_run=True)
    assert result == {"status":"PREVIEW_ONLY","sent":0}
    assert not list(tmp_path.iterdir())
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED","0")
    with pytest.raises(mail.PilotStop,match="approval is OFF"):
        mail.send("fixture",mail.DEFAULT_TEMPLATE,tmp_path,now,"recover",None,dry_run=True)
    assert not list(tmp_path.iterdir())


def test_preview_recovery_cli_uses_full_guards_and_original_ledger(monkeypatch,tmp_path):
    monkeypatch.setattr(mail,"accepted_setup_dsn",lambda:"fixture")
    calls=[]
    monkeypatch.setattr(mail,"send",lambda *args,**kwargs:calls.append((args,kwargs)) or {})
    assert mail.main(["--preview-recovery"]) == 0
    assert calls[0][0][4] == "recover" and calls[0][1] == {"dry_run":True}
    assert mail.main(["--preview-recovery","--ledger",str(tmp_path)]) == 2
    assert len(calls)==1
