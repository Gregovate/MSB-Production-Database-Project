"""Acceptance-only integrated browser preview for People #395 + Apps #24.

This process serves the exact Backbone Apps HTML candidate at / and mounts the
exact People candidate under /people. One synthetic clone-only Cloudflare
identity is injected at the WSGI boundary. Production Cloudflare, Production
PostgreSQL, Production Directus, and Production application services are not
used for browser writes.
"""
from __future__ import annotations

import os
import sys
from collections.abc import Callable
from pathlib import Path

from flask import Flask, Response, send_file
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from werkzeug.serving import run_simple


APP_DIR = os.environ["MSB_PREVIEW_APP_DIR"]
APPS_HTML = Path(os.environ["MSB_PREVIEW_APPS_HTML"])
OPERATOR_EMAIL = os.environ["MSB_PREVIEW_OPERATOR_EMAIL"].strip().lower()
HOST = os.environ.get("MSB_PREVIEW_HOST", "127.0.0.1")
PORT = int(os.environ["MSB_PREVIEW_PORT"])

if not OPERATOR_EMAIL:
    raise RuntimeError("MSB_PREVIEW_OPERATOR_EMAIL is required")
if not APPS_HTML.is_file():
    raise RuntimeError(f"Exact Apps candidate is missing: {APPS_HTML}")

sys.path.insert(0, APP_DIR)
from backend import app as people_app  # noqa: E402


apps_app = Flask("msb_395_apps_preview")


@apps_app.get("/")
def apps_index() -> Response:
    return send_file(APPS_HTML, mimetype="text/html")


@apps_app.get("/analytics.js")
def no_analytics() -> Response:
    # Browser review must not emit Production analytics.
    return Response(
        "/* #395 disposable browser preview: analytics intentionally disabled */\n",
        mimetype="application/javascript",
    )


@apps_app.get("/preview/health")
def preview_health() -> Response:
    return Response("ok\n", mimetype="text/plain")


class PreviewIdentityMiddleware:
    """Inject exactly one clone-only Cloudflare identity in this preview."""

    def __init__(self, wrapped: Callable) -> None:
        self.wrapped = wrapped

    def __call__(self, environ: dict, start_response: Callable):
        environ["HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL"] = OPERATOR_EMAIL
        return self.wrapped(environ, start_response)


application = PreviewIdentityMiddleware(
    DispatcherMiddleware(apps_app, {"/people": people_app})
)


if __name__ == "__main__":
    run_simple(HOST, PORT, application, use_reloader=False)
