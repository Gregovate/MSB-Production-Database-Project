"""Work Orders V1 protected WSGI entry — source-only; no auto-start.

Server Management owns the actual loopback binding/registered Production port,
Cloudflare Access/proxy stripping user-controlled identity headers, service
credentials, maintenance deployment and rollback. This module does NOT run a
development server or start a second listener.

Refuse to initialize if the guarded native Work Orders runtime is not explicitly
configured. A staged source checkout cannot accidentally become live by importing
backend.py or setting the disposable preview variables.
"""
from __future__ import annotations

import os

from v1_runtime import require_v1_production_configuration

if os.environ.get("WORK_MGMT_RUNTIME_MODE") != "production":
    raise RuntimeError("Work Orders V1 WSGI requires explicit production mode.")
if os.environ.get("WORK_MGMT_V1_WRITE_GATE") != "authorized_v1_release_only":
    raise RuntimeError("Work Orders V1 remains offline until release authorization.")
if os.environ.get("WORK_MGMT_PRODUCTION_PROXY_APPROVED") != "verified_synology_access":
    raise RuntimeError("Work Orders V1 requires a reviewed protected proxy/identity boundary.")
if len(os.environ.get("WORK_MGMT_PRODUCTION_COMMAND_SECRET", "")) < 48:
    raise RuntimeError("Work Orders V1 requires a private same-origin command secret.")
require_v1_production_configuration(writes=True)

from backend import app  # noqa: E402


def application(environ, start_response):
    """Fixed Synology perimeter; untrusted forwarded headers never grant access.

    Synology strips /workorder/ and supplies Host and X-Forwarded-Proto. The
    actual socket peer must match before either header is used. Cloudflare
    identity integrity/direct-origin restrictions remain an infrastructure gate.
    """
    if (environ.get("REMOTE_ADDR") != "192.168.5.4"
            or environ.get("HTTP_HOST") != "my.sheboyganlights.org"
            or environ.get("HTTP_X_FORWARDED_PROTO") != "https"):
        body = b'{"error":"Untrusted Work Management perimeter"}'
        start_response("403 Forbidden", [
            ("Content-Type", "application/json"),
            ("Content-Length", str(len(body))), ("Cache-Control", "no-store")])
        return [body]
    # Fixed deployment values: do not use client X-Forwarded-Prefix/For/Host.
    environ["SCRIPT_NAME"] = "/workorder"
    environ["wsgi.url_scheme"] = "https"
    return app(environ, start_response)

# WSGI application only. Server Management must configure its own accepted
# service runner and protected route: there is intentionally no __main__ port.

