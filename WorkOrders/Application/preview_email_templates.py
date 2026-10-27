"""Render the four editable templates as local HTML; no database or mail access.

Run from the repository root:
  python WorkOrders/Application/preview_email_templates.py --output-dir /tmp/wo-mail-preview
Open index.html in that directory. All ticket details below are fictional.
"""
import argparse
from html import escape
from pathlib import Path

from email_templates import KINDS, render_email


def sample_messages() -> dict:
    """Shared fictional examples for offline and Manager previews; no side effects."""
    values = dict(ticket='WO-123', title='Replace damaged light strand',
                  reporter='Example Reporter', assignees='Example Volunteer',
                  due_by='2026-10-25', question='Which side of the display needs repair?',
                  outcome='Canceled — no work performed',
                  reason='Duplicate report; the original Work Order remains open.',
                  ticket_url='https://my.sheboyganlights.org/workorder/?ticket=WO-123')
    rendered = {}
    for kind in sorted(KINDS):
        sample = dict(values)
        if kind in {'new_request', 'more_info', 'reporter_reply'}:
            sample.update(ticket='INTAKE-123',
                          ticket_url='https://my.sheboyganlights.org/workorder/?ticket=INTAKE-123')
        if kind == 'reporter_reply':
            sample['question'] = 'The connector on the left side is damaged.'
        rendered[kind] = render_email(kind, sample)
    # Feedback is a source variant of the same new-request event, not another send.
    rendered['task_feedback'] = render_email('new_request', dict(values,
        ticket='INTAKE-66', source_form_name='SETUP_CORRECTION',
        task_name='Example Setup task',
        title='Need a place to store the stakes for the UTV garage.',
        ticket_url='https://my.sheboyganlights.org/workorder/?ticket=INTAKE-66'))
    return rendered


def preview(output_dir: Path) -> None:
    rendered = sample_messages()
    output_dir.mkdir(parents=True, exist_ok=True)
    links = []
    for kind, message in rendered.items():
        (output_dir / (kind + '.html')).write_text(message.html, encoding='utf-8')
        (output_dir / (kind + '.txt')).write_text(
            message.subject + '\n\n' + message.text, encoding='utf-8')
        links.append('<li><a href="' + kind + '.html">' + escape(kind) + '</a>: '
                     + escape(message.subject) + ' (<a href="' + kind
                     + '.txt">plain text</a>)</li>')
    (output_dir / 'index.html').write_text(
        '<!doctype html><meta charset="utf-8"><title>Work Order email previews</title>'
        '<h1>Work Order email previews</h1>'
        '<p>Fictional examples only. No messages sent. Ticket links are examples.</p>'
        '<ul>' + ''.join(links) + '</ul>', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    preview(parser.parse_args().output_dir)
