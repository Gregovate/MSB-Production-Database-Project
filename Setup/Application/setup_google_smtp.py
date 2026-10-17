"""#205 Google Workspace SMTP relay transport for Setup notifications.

Uses the existing IP-authorized Google Workspace relay with mandatory STARTTLS
and certificate verification. This module does not query PostgreSQL, create
notifications, determine recipients, schedule jobs or silently retry sends.
An SMTP 250 acceptance is NOT proof of mailbox delivery or message reading.
"""

from __future__ import annotations

from email.message import EmailMessage
from email.policy import SMTP as SMTP_POLICY
from email.utils import formataddr
import os
import smtplib
import ssl


RELAY_HOST = "smtp-relay.gmail.com"
RELAY_PORT = 587
ALLOWED_DOMAIN = "@sheboyganlights.org"
# Keep the same display identity already used by Work Order triage.
SENDER_DISPLAY_NAME = "MSB Production DB"


class SetupSMTPError(RuntimeError):
    """The outbound SMTP request was not confirmed accepted by the relay."""


def _organization_address(raw: object) -> str:
    """Reject malformed addresses and all non-organizational recipients."""
    address = str(raw or "").strip().lower()
    if (
        not address.endswith(ALLOWED_DOMAIN)
        or address.count("@") != 1
        or len(address) > 254
        or len(address) < len(ALLOWED_DOMAIN) + 1
        or any(c.isspace() or ord(c) < 33 or ord(c) > 126 for c in address)
        or any(c in address for c in "<>(),;:\\[]")
    ):
        raise SetupSMTPError("Email address must be one valid MSB organizational address")
    return address


def send_setup_email(
    *,
    recipient: str,
    subject: str,
    body_text: str,
    sender: str | None = None,
) -> str:
    """Submit exactly one plain-text email through Google Workspace.

    The calling notification workflow must first validate authorization,
    reporting state, idempotency and outbox claim. Only that workflow decides
    whether a send is permitted. This function performs no automatic retries.
    """
    if os.environ.get("SETUP_NOTIFICATION_SMTP_SEND_ENABLED") != "1":
        raise SetupSMTPError("SMTP sending is disabled")

    from_address = _organization_address(
        sender if sender is not None else os.environ.get("SETUP_NOTIFICATION_FROM_EMAIL")
    )
    to_address = _organization_address(recipient)
    if not isinstance(subject, str) or not subject.strip() or len(subject) > 250:
        raise SetupSMTPError("Email subject is missing or too long")
    if any(c in subject for c in "\r\n\x00"):
        raise SetupSMTPError("Email subject contains prohibited characters")
    if not isinstance(body_text, str) or not body_text.strip() or len(body_text) > 50000:
        raise SetupSMTPError("Email body is missing or too long")

    message = EmailMessage(policy=SMTP_POLICY)
    message["From"] = formataddr((SENDER_DISPLAY_NAME, from_address))
    message["To"] = to_address
    message["Subject"] = subject
    message.set_content(body_text, subtype="plain", charset="utf-8")

    try:
        # The approved relay is authenticated by the server's external IP;
        # SSL verification still validates the SMTP destination certificate.
        with smtplib.SMTP(RELAY_HOST, RELAY_PORT, timeout=20) as connection:
            connection.ehlo()
            if not connection.has_extn("starttls"):
                raise SetupSMTPError("Relay did not advertise STARTTLS")
            connection.starttls(context=ssl.create_default_context())
            connection.ehlo()
            # send_message raises on SMTP rejection; no AUTH or plaintext fallback.
            refused = connection.send_message(
                message, from_addr=from_address, to_addrs=[to_address]
            )
            if refused:
                raise SetupSMTPError("Google relay rejected the recipient")
    except SetupSMTPError:
        raise
    except (smtplib.SMTPException, OSError, TimeoutError) as exc:
        # Network interruption after DATA can leave the outcome uncertain;
        # caller must consult the authoritative outbox before any retry.
        raise SetupSMTPError("SMTP outcome unconfirmed; inspect outbox before retry") from exc

    return "SMTP_ACCEPTED_NOT_DELIVERED"
