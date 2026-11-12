"""Offline SMTP boundary checks; tests never contact a mail server."""
import ssl
import pytest
from mail_delivery import Delivery, dispatch, message_for
from email_templates import RenderedEmail


class Store:
    def __init__(self):
        self.claims = set()
        self.results = []

    def claim(self, delivery):
        if delivery.key in self.claims:
            return False
        self.claims.add(delivery.key)
        return True

    def finish(self, *outcome):
        self.results.append(outcome)


class SMTP:
    tls = True
    fail_data = False
    fail_quit = False
    refuse = False
    calls = []

    def __init__(self, host, port, timeout):
        self.calls.append(('connect', host, port, timeout))

    def ehlo(self):
        self.calls.append(('ehlo',))

    def has_extn(self, name):
        return self.tls and name == 'starttls'

    def starttls(self, context):
        assert context.verify_mode == ssl.CERT_REQUIRED
        assert context.check_hostname
        self.calls.append(('tls',))

    def send_message(self, message, from_addr, to_addrs):
        assert ('tls',) in self.calls
        self.calls.append(('data', from_addr, to_addrs))
        if self.fail_data:
            raise TimeoutError('uncertain server response')
        return {to_addrs[0]: (550, b'rejected')} if self.refuse else {}

    def quit(self):
        if self.fail_quit:
            raise OSError('connection closed')

    def close(self):
        pass


@pytest.fixture
def delivery():
    return Delivery('WO-1:complete:123', 'example@sheboyganlights.org',
                    RenderedEmail('WO-1 done', 'Work completed', '<p>Work completed</p>', 'digest'))


@pytest.fixture(autouse=True)
def reset_smtp():
    SMTP.calls = []
    SMTP.tls, SMTP.fail_data, SMTP.fail_quit, SMTP.refuse = True, False, False, False


def test_preview_has_no_network_or_claim(delivery):
    store = Store()
    assert dispatch(delivery, store, smtp_factory=SMTP) == 'PREVIEW_ONLY'
    assert not store.claims and not SMTP.calls


def test_accepted_once_and_stable_identity(delivery):
    store = Store()
    assert dispatch(delivery, store, enabled=True, smtp_factory=SMTP) == 'SMTP_ACCEPTED'
    assert dispatch(delivery, store, enabled=True, smtp_factory=SMTP) == 'ALREADY_ATTEMPTED'
    assert sum(c[0] == 'data' for c in SMTP.calls) == 1
    msg = message_for(delivery)
    assert msg['Message-ID'] == message_for(delivery)['Message-ID']
    assert msg.get_content_type() == 'multipart/alternative'


def test_no_tls_no_data(delivery):
    SMTP.tls = False
    assert dispatch(delivery, Store(), enabled=True, smtp_factory=SMTP) == 'FAILED_BEFORE_DATA'
    assert not any(c[0] == 'data' for c in SMTP.calls)


def test_timeout_uncertain_never_automatic_retry(delivery):
    SMTP.fail_data = True
    store = Store()
    assert dispatch(delivery, store, enabled=True, smtp_factory=SMTP) == 'UNKNOWN'
    assert dispatch(delivery, store, enabled=True, smtp_factory=SMTP) == 'ALREADY_ATTEMPTED'


def test_quit_error_does_not_reclassify_accepted(delivery):
    SMTP.fail_quit = True
    assert dispatch(delivery, Store(), enabled=True, smtp_factory=SMTP) == 'SMTP_ACCEPTED'


def test_refusal_not_sent(delivery):
    SMTP.refuse = True
    assert dispatch(delivery, Store(), enabled=True, smtp_factory=SMTP) == 'REJECTED'


@pytest.mark.parametrize('address', ['a@example.org,b@example.org',
    'Someone <a@example.org>', 'a@example.org\r\nBcc:x@example.org', '', 'bad'])
def test_invalid_recipient_never_connects(delivery, address):
    with pytest.raises(ValueError):
        dispatch(Delivery(delivery.event_key, address, delivery.content),
                 Store(), enabled=True, smtp_factory=SMTP)
    assert not SMTP.calls


def test_claim_error_prevents_network(delivery):
    class FailedStore(Store):
        def claim(self, delivery):
            raise OSError('database unavailable')
    with pytest.raises(OSError):
        dispatch(delivery, FailedStore(), enabled=True, smtp_factory=SMTP)
    assert not SMTP.calls


def test_receipt_error_retains_claim(delivery):
    class FailedReceipt(Store):
        def finish(self, *args):
            raise OSError('database unavailable')
    store = FailedReceipt()
    with pytest.raises(OSError):
        dispatch(delivery, store, enabled=True, smtp_factory=SMTP)
    assert dispatch(delivery, store, enabled=True, smtp_factory=SMTP) == 'ALREADY_ATTEMPTED'
