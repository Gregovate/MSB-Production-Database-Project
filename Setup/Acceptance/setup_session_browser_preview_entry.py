"""Temporary browser-review entry point for the accepted Setup Session candidate.

Acceptance infrastructure only. It imports the exact detached Setup production
candidate and injects one explicitly selected existing operator identity at the
WSGI boundary so normal Setup authorization and narrow command behavior can be
reviewed against a disposable current-production PostgreSQL clone.
"""
from __future__ import annotations

import os
import sys
from collections.abc import Callable


APP_DIR = os.environ["MSB_SETUP_PREVIEW_APP_DIR"]
OPERATOR_EMAIL = os.environ["MSB_SETUP_PREVIEW_OPERATOR_EMAIL"].strip().lower()
HOST = os.environ.get("MSB_SETUP_PREVIEW_HOST", "127.0.0.1")
PORT = int(os.environ.get("MSB_SETUP_PREVIEW_PORT", "8794"))

if not OPERATOR_EMAIL:
    raise RuntimeError("MSB_SETUP_PREVIEW_OPERATOR_EMAIL is required")

sys.path.insert(0, APP_DIR)
from production_backend import app  # noqa: E402


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
