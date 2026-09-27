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

PREVIEW_INTAKE_DSN = os.environ.get("MSB_SETUP_PREVIEW_INTAKE_DSN", "").strip()

if PREVIEW_INTAKE_DSN:
    import psycopg2  # noqa: E402
    from psycopg2.extras import Json  # noqa: E402
    import setup_work_order_intake_api as intake_api  # noqa: E402

    class PreviewDirectusIntakeClient:
        """Disposable-only Directus sink; never used by Production application."""

        _columns = (
            "source_system",
            "source_form_name",
            "source_payload",
            "submitter_email_raw",
            "submitter_name_raw",
            "submitted_at",
            "priority_raw",
            "task_type_raw",
            "stage_raw",
            "problem_raw",
            "notes_raw",
            "location_type_raw",
            "submitter_person_id",
            "stage_id",
            "target_year",
            "triage_dropdown",
        )

        def create_intake(self, payload):
            values = [payload.get(column) for column in self._columns]
            values[2] = Json(values[2]) if values[2] is not None else None
            placeholders = ",".join(["%s"] * len(self._columns))
            columns = ",".join(self._columns)
            with psycopg2.connect(PREVIEW_INTAKE_DSN) as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        f"INSERT INTO stage.work_order_intake ({columns}) "
                        f"VALUES ({placeholders}) RETURNING intake_id",
                        values,
                    )
                    intake_id = cur.fetchone()[0]
                conn.commit()
            return {"intake_id": intake_id}

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
