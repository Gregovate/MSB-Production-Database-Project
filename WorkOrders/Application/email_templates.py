"""Render #419 editable message files without sending mail or choosing recipients.

Only literal $name placeholders are supported: no executable template language.
The delivery worker must persist this result before its first delivery attempt.
"""
from dataclasses import dataclass
from hashlib import sha256
from html import escape
import json
from pathlib import Path
from string import Template
from urllib.parse import urlsplit, parse_qs
import re

TEMPLATE_ROOT = Path(__file__).with_name('email_templates')
FIELDS = frozenset({'ticket', 'title', 'reporter', 'assignees', 'due_by',
                    'question', 'outcome', 'reason', 'ticket_url'})
KINDS = frozenset({'new_request', 'assignment', 'outcome', 'more_info'})


@dataclass(frozen=True)
class RenderedEmail:
    subject: str
    text: str
    html: str
    template_sha256: str


def render_email(kind: str, values: dict[str, str], *,
                 template_root: Path = TEMPLATE_ROOT) -> RenderedEmail:
    """Fail visibly on invalid configuration; never silently omit a placeholder.

    Templates are trusted, reviewed administrator files. Ticket content is not
    trusted, and is escaped independently for the HTML alternative. Recipients,
    sender identity and SMTP settings are deliberately outside this interface.
    """
    if kind not in KINDS:
        raise ValueError('Unknown email type')
    raw = (template_root / (kind + '.json')).read_bytes()
    if len(raw) > 65536:
        raise ValueError('Email template exceeds 64 KiB')
    document = json.loads(raw)
    if not isinstance(document, dict) or set(document) != {'subject', 'text', 'html'}:
        raise ValueError('Template must contain only subject, text and html')
    rendered = {}
    for part, source in document.items():
        if not isinstance(source, str) or not source.strip():
            raise ValueError('Empty or invalid template part: ' + part)
        template = Template(source)
        if not template.is_valid():
            raise ValueError('Invalid placeholder in ' + part)
        names = set(template.get_identifiers())
        if names - FIELDS or names - values.keys():
            raise ValueError('Unknown or missing placeholder in ' + part)
        context = {}
        for name in names:
            value = values[name]
            if not isinstance(value, str) or not value.strip():
                raise ValueError('Missing text for ' + name)
            if name == 'ticket_url':
                url = urlsplit(value)
                if (url.scheme != 'https' or url.netloc != 'my.sheboyganlights.org'
                        or url.path != '/workorder/'
                        or url.fragment
                        or not re.fullmatch(r'(WO|INTAKE)-[1-9][0-9]*', values.get('ticket', ''))
                        or parse_qs(url.query).get('ticket') != [values.get('ticket')]
                        or any(c.isspace() or ord(c) < 32 for c in value)):
                    raise ValueError('Ticket link must use the protected Work Orders route')
            context[name] = escape(value, quote=True) if part == 'html' else value
        result = template.substitute(context)
        if part == 'subject' and (len(result) > 240 or any(ord(c) < 32 or ord(c) == 127 for c in result)):
            raise ValueError('Invalid email subject')
        rendered[part] = result
    return RenderedEmail(**rendered, template_sha256=sha256(raw).hexdigest())
