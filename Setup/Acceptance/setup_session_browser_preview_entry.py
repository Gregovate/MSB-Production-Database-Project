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

# Browser acceptance must never post a clone-only test correction into
# Production Directus. PostgreSQL preparation/authorization still executes
# against the disposable clone; only the final external Directus create call
# is replaced with a no-write preview sink.
import setup_work_order_intake_api as intake_api  # noqa: E402


class PreviewDirectusIntakeClient:
    """No-write Directus boundary used only by disposable browser review."""

    def create_intake(self, payload):
        if payload.get("source_system") != "SETUP":
            raise RuntimeError("Preview Intake payload source_system is not SETUP")
        if payload.get("source_form_name") != "SETUP_CORRECTION":
            raise RuntimeError("Preview Intake payload source_form_name is invalid")
        if str(payload.get("triage_dropdown") or "") != "1":
            raise RuntimeError("Preview Intake payload is not Submitted")
        return {"intake_id": 0, "preview_only": True}


intake_api.directus_client = lambda: PreviewDirectusIntakeClient()


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
