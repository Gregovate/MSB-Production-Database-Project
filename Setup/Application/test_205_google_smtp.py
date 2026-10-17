"""#205 Google relay transport tests: no network, credentials or Production writes."""

import smtplib

import pytest
import setup_google_smtp as smtp


class FakeSMTP:
    """Capture protocol use and prevent real SMTP traffic in unit tests."""

    calls = []
    extn = True
    refused = {}

    def __init__(self, host, port, timeout):
        self.calls.append(("connect", host, port, timeout))

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.calls.append(("close",))

    def ehlo(self):
        self.calls.append(("ehlo",))

    def has_extn(self, name):
        self.calls.append(("extension", name))
        return self.extn

    def starttls(self, *, context):
        self.calls.append(("starttls", context.check_hostname, context.verify_mode))

    def send_message(self, message, *, from_addr, to_addrs):
        self.calls.append(("send", message, from_addr, to_addrs))
        return self.refused


@pytest.fixture(autouse=True)
def clear_smtp(monkeypatch):
    FakeSMTP.calls = []
    FakeSMTP.extn = True
    FakeSMTP.refused = {}
    monkeypatch.delenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", raising=False)
    monkeypatch.delenv("SETUP_NOTIFICATION_FROM_EMAIL", raising=False)
    monkeypatch.setattr(smtp.smtplib, "SMTP", FakeSMTP)


def test_disabled_by_default_even_with_message():
    with pytest.raises(smtp.SetupSMTPError, match="disabled"):
        smtp.send_setup_email(
            sender="reports@sheboyganlights.org",
            recipient="manager@sheboyganlights.org",
            subject="Test", body_text="No email should be sent",
        )
    assert not FakeSMTP.calls


def test_ip_relay_uses_verified_tls_no_password_and_only_one_recipient(monkeypatch):
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", "1")
    monkeypatch.setenv("SETUP_NOTIFICATION_FROM_EMAIL", "reports@sheboyganlights.org")
    outcome = smtp.send_setup_email(
        recipient="captain@sheboyganlights.org",
        subject="MSB Setup — Report Work",
        body_text="Complete your actual work report.\nOnly if work occurred.",
    )
    assert outcome == "SMTP_ACCEPTED_NOT_DELIVERED"
    assert FakeSMTP.calls[0] == ("connect", "smtp-relay.gmail.com", 587, 20)
    assert ("extension", "starttls") in FakeSMTP.calls
    assert ("starttls", True, __import__("ssl").CERT_REQUIRED) in FakeSMTP.calls
    entries = [x for x in FakeSMTP.calls if x[0] == "send"]
    assert len(entries) == 1
    _, message, from_addr, to_addrs = entries[0]
    assert from_addr == "reports@sheboyganlights.org"
    assert message["From"] == "MSB Production DB <reports@sheboyganlights.org>"
    assert to_addrs == ["captain@sheboyganlights.org"]
    assert "Complete your actual work report." in message.get_content()
    assert [x[0] for x in FakeSMTP.calls].count("ehlo") == 2


@pytest.mark.parametrize("address", [
    "personal@example.com", "bad @sheboyganlights.org",
    "two@example.com,someone@sheboyganlights.org",
    "nobody@sheboyganlights.org\r\nBcc:evil@example.com",
])
def test_external_or_header_injected_recipient_is_rejected(monkeypatch, address):
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", "1")
    with pytest.raises(smtp.SetupSMTPError):
        smtp.send_setup_email(
            sender="reports@sheboyganlights.org",
            recipient=address, subject="Test", body_text="Example",
        )
    assert not FakeSMTP.calls


def test_starttls_is_required_without_fallback(monkeypatch):
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", "1")
    FakeSMTP.extn = False
    with pytest.raises(smtp.SetupSMTPError, match="STARTTLS"):
        smtp.send_setup_email(
            sender="reports@sheboyganlights.org",
            recipient="manager@sheboyganlights.org",
            subject="Test", body_text="Example",
        )
    assert not any(x[0] == "send" for x in FakeSMTP.calls)


def test_smtp_refusal_does_not_claim_delivery(monkeypatch):
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", "1")
    FakeSMTP.refused = {"manager@sheboyganlights.org": (550, b"rejected")}
    with pytest.raises(smtp.SetupSMTPError, match="rejected"):
        smtp.send_setup_email(
            sender="reports@sheboyganlights.org",
            recipient="manager@sheboyganlights.org",
            subject="Test", body_text="Example",
        )


def test_smtp_timeout_is_unconfirmed_not_automatically_retried(monkeypatch):
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", "1")
    class BrokenSMTP(FakeSMTP):
        def send_message(self, message, *, from_addr, to_addrs):
            raise TimeoutError("simulated timeout after send")
    monkeypatch.setattr(smtp.smtplib, "SMTP", BrokenSMTP)
    with pytest.raises(smtp.SetupSMTPError, match="unconfirmed"):
        smtp.send_setup_email(
            sender="reports@sheboyganlights.org",
            recipient="manager@sheboyganlights.org",
            subject="Test", body_text="Example",
        )
    assert [x[0] for x in FakeSMTP.calls].count("connect") == 1


def test_sender_not_guessed_or_implicitly_created(monkeypatch):
    monkeypatch.setenv("SETUP_NOTIFICATION_SMTP_SEND_ENABLED", "1")
    with pytest.raises(smtp.SetupSMTPError, match="organizational"):
        smtp.send_setup_email(
            recipient="manager@sheboyganlights.org",
            subject="Test", body_text="Example",
        )
    assert not FakeSMTP.calls
