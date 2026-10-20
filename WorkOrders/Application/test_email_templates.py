"""No-network checks for editable notification content and unsafe input."""
import json
import pytest
from email_templates import KINDS, render_email


@pytest.fixture
def values():
    return dict(ticket='WO-123', title='Repair <unsafe> & inspect', reporter='Reporter',
                assignees='Assigned volunteer', due_by='2026-10-25',
                question='Which connector failed?', outcome='Canceled — no work performed',
                reason='Duplicate request; original work remains open.',
                ticket_url='https://my.sheboyganlights.org/workorder/?ticket=WO-123')


@pytest.mark.parametrize('kind', sorted(KINDS))
def test_templates_render_without_sending(kind, values):
    result = render_email(kind, values)
    assert 'WO-123' in result.subject
    assert '<unsafe>' not in result.html
    assert '&lt;unsafe&gt;' in result.html
    assert '<unsafe>' in result.text
    assert len(result.template_sha256) == 64


def test_cancel_is_not_worded_as_completed(values):
    result = render_email('outcome', values)
    assert 'Canceled' in result.subject
    assert 'no work performed' in result.text
    assert 'completed' not in result.text.lower()


def test_header_injection_rejected(values):
    values['ticket'] = 'WO-123\r\nBcc: someone@example.com'
    with pytest.raises(ValueError):
        render_email('assignment', values)


@pytest.mark.parametrize('url', ['http://my.sheboyganlights.org/workorder/',
    'https://evil.example/workorder/', 'javascript:alert(1)',
    'https://my.sheboyganlights.org/people/',
    'https://my.sheboyganlights.org@evil.example/workorder/',
    'https://my.sheboyganlights.org/workorder/',
    'https://my.sheboyganlights.org/workorder/?ticket=WO-999'])
def test_unapproved_link_rejected(url, values):
    values['ticket_url'] = url
    with pytest.raises(ValueError):
        render_email('more_info', values)


def test_template_edits_change_content_and_digest(tmp_path, values):
    path = tmp_path / 'new_request.json'
    config = dict(subject='$ticket: review needed', text='$title', html='<p>$title</p>')
    path.write_text(json.dumps(config))
    first = render_email('new_request', values, template_root=tmp_path)
    config['subject'] = '$ticket: please review'
    path.write_text(json.dumps(config))
    second = render_email('new_request', values, template_root=tmp_path)
    assert first.subject != second.subject
    assert first.template_sha256 != second.template_sha256


@pytest.mark.parametrize('text', ['$unknown', '${title.__class__}', '$'])
def test_bad_placeholders_rejected(tmp_path, values, text):
    (tmp_path / 'new_request.json').write_text(json.dumps(
        dict(subject='Request', text=text, html='<p>$title</p>')))
    with pytest.raises(ValueError):
        render_email('new_request', values, template_root=tmp_path)


def test_no_recipient_override(tmp_path, values):
    (tmp_path / 'new_request.json').write_text(json.dumps(
        dict(subject='Request', text='$title', html='$title', to='other@example.com')))
    with pytest.raises(ValueError):
        render_email('new_request', values, template_root=tmp_path)


def test_missing_question_rejected(values):
    del values['question']
    with pytest.raises(ValueError):
        render_email('more_info', values)


def test_setup_feedback_names_task_and_does_not_call_it_a_work_request(values):
    values.update(source_form_name='SETUP_CORRECTION', task_name='Build command center')
    message = render_email('new_request', values)
    assert message.subject.startswith('Build command center has feedback that needs review')
    assert 'Work Order request' not in message.text
    assert 'approve or deny' not in message.text
    assert 'Review feedback and respond' in message.html
    assert 'db.sheboyganlights.org' not in message.html


def test_public_request_keeps_received_from_wording(values):
    values.update(source_form_name='Public form', task_name='Not applicable')
    message = render_email('new_request', values)
    assert 'Work Order request was received from Reporter' in message.text
    assert 'has feedback' not in message.subject
