"""Temporary browser-review entry point for an accepted FieldWiring candidate.

This file is acceptance infrastructure, not production application code. It imports
an exact detached candidate and injects one explicitly selected existing operator
identity at the WSGI boundary so the candidate's normal Controller authorization
and command code can be exercised against a disposable PostgreSQL clone.
"""
from __future__ import annotations

import os
import sys
from collections.abc import Callable


APP_DIR = os.environ["MSB_PREVIEW_APP_DIR"]
OPERATOR_EMAIL = os.environ["MSB_PREVIEW_OPERATOR_EMAIL"].strip().lower()
HOST = os.environ.get("MSB_PREVIEW_HOST", "127.0.0.1")
PORT = int(os.environ.get("MSB_PREVIEW_PORT", "8793"))

if not OPERATOR_EMAIL:
    raise RuntimeError("MSB_PREVIEW_OPERATOR_EMAIL is required")

sys.path.insert(0, APP_DIR)
from backend import app  # noqa: E402


class PreviewIdentityMiddleware:
    """Inject one reviewed Cloudflare identity only inside the preview process."""

    def __init__(self, wrapped: Callable) -> None:
        self.wrapped = wrapped

    def __call__(self, environ: dict, start_response: Callable):
        environ["HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL"] = OPERATOR_EMAIL
        return self.wrapped(environ, start_response)


app.wsgi_app = PreviewIdentityMiddleware(app.wsgi_app)


if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug=False, use_reloader=False)
