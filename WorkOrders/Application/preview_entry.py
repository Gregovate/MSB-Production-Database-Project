"""#419 disposable browser WSGI entry — pinned operator identity, no Production use.

This module is intentionally separate from backend.py. The approved Server
Management launcher must provide exactly one existing reviewer email, one
isolated clone DSN, and a registered localhost listener.
"""
from __future__ import annotations

import os
import re

from flask import request

from backend import app
from repository import WorkManagementError, WorkManagementRepository

EMAIL_HEADER = "HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL"
PERSONAL_EMAIL = re.compile(r"^[A-Za-z0-9._%+\-]+@sheboyganlights\.org$")


def approved_preview_identity() -> str:
    if os.environ.get("WORK_MGMT_PREVIEW_MODE") != "disposable":
        raise RuntimeError("Work Management entry requires disposable preview mode.")
    email = os.environ.get("WORK_MGMT_PREVIEW_EMAIL", "").strip().lower()
    if not PERSONAL_EMAIL.fullmatch(email):
        raise RuntimeError("A named approved MSB preview reviewer is required.")
    # Validate DB name and active Person/Directus policy before accepting review.
    WorkManagementRepository().access(email)
    return email


PREVIEW_EMAIL = approved_preview_identity()


@app.before_request
def inject_review_identity() -> None:
    """Discard any client-supplied identity, use only runner-selected reviewer."""
    if request.remote_addr not in ("127.0.0.1", "::1"):
        raise WorkManagementError("Preview is restricted to localhost.", 403)
    request.environ.pop(EMAIL_HEADER, None)
    request.environ[EMAIL_HEADER] = PREVIEW_EMAIL


if __name__ == "__main__":
    from werkzeug.serving import run_simple

    port_text = os.environ.get("WORK_MGMT_PREVIEW_PORT", "")
    if not port_text.isdecimal() or int(port_text) < 1024 or int(port_text) > 65535:
        raise RuntimeError("Approved Work Management preview port required.")
    # The existing MSB disposable runner owns process lifetime and cleanup.
    run_simple("127.0.0.1", int(port_text), app, use_reloader=False, threaded=True)
