"""#419 single-recipient delivery over the established MSB Google relay.

This module does not query users, activate Flows, or select events. A durable
store must commit a claim before SMTP DATA. An uncertain attempt is never
automatically retried: SMTP cannot guarantee exactly-once delivery.
"""
from __future__ import annotations

from dataclasses import dataclass
from email.message import EmailMessage
from hashlib import sha256
import re
import smtplib
import ssl
from typing import Protocol

from email_templates import RenderedEmail

RELAY = 'smtp-relay.gmail.com'
FROM = 'no-reply@sheboyganlights.org'


@dataclass(frozen=True)
class Delivery:
    event_key: str
    recipient: str
    content: RenderedEmail

    @property
    def key(self) -> str:
        # Scope deduplication to event and actual intended mailbox.
        return sha256((self.event_key + '\0' + self.recipient.lower()).encode()).hexdigest()


class DeliveryStore(Protocol):
    def claim(self, delivery: Delivery) -> bool:
        """Atomically persist immutable content and IN_PROGRESS before network I/O."""
        ...

    def finish(self, key: str, status: str, evidence: str) -> None:
        """Durably persist the outcome; never turn uncertainty into SENT."""
        ...


def message_for(delivery: Delivery) -> EmailMessage:
    """Build one envelope recipient; reject display-name/list/header input."""
    if not delivery.event_key or len(delivery.event_key) > 500:
        raise ValueError('Invalid event identity')
    if not re.fullmatch(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}", delivery.recipient):
        raise ValueError('A single recipient mailbox is required')
    message = EmailMessage()
    message['From'] = FROM
    message['To'] = delivery.recipient
    message['Subject'] = delivery.content.subject
    message['Message-ID'] = '<wo-' + delivery.key + '@sheboyganlights.org>'
    message.set_content(delivery.content.text)
    message.add_alternative(delivery.content.html, subtype='html')
    return message


def dispatch(delivery: Delivery, store: DeliveryStore, *, enabled: bool = False,
             smtp_factory=smtplib.SMTP) -> str:
    """Send only after explicit activation and an exclusive durable claim.

    FAILED_BEFORE_DATA is provably unsent. UNKNOWN needs operator review.
    SMTP_ACCEPTED means the relay accepted responsibility, not Inbox receipt.
    Even proven-unsent attempts require an explicit governed retry, not a loop.
    """
    message = message_for(delivery)
    if not enabled:
        return 'PREVIEW_ONLY'
    if not store.claim(delivery):
        return 'ALREADY_ATTEMPTED'
    smtp = None
    data_started = False
    accepted = False
    status = 'FAILED_BEFORE_DATA'
    evidence = 'connection_or_tls_failure'
    try:
        smtp = smtp_factory(RELAY, 587, timeout=20)
        smtp.ehlo()
        if not smtp.has_extn('starttls'):
            raise RuntimeError('STARTTLS required')
        smtp.starttls(context=ssl.create_default_context())
        smtp.ehlo()
        data_started = True
        refused = smtp.send_message(message, from_addr=FROM,
                                    to_addrs=[delivery.recipient])
        if refused:
            status, evidence = 'REJECTED', 'recipient_refused'
        else:
            accepted = True
            status, evidence = 'SMTP_ACCEPTED', 'send_message_returned_accepted'
    except smtplib.SMTPRecipientsRefused:
        status, evidence = 'REJECTED', 'all_recipients_refused'
    except Exception:
        # Never store raw SMTP errors: they can contain addresses/content.
        if data_started:
            status, evidence = 'UNKNOWN', 'delivery_outcome_uncertain'
    finally:
        if smtp is not None:
            # QUIT failure after positive DATA acceptance must not cause replay.
            try:
                smtp.quit()
            except Exception:
                try:
                    smtp.close()
                except Exception:
                    pass
    store.finish(delivery.key, status, evidence)
    return 'SMTP_ACCEPTED' if accepted else status
