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
if os.environ.get("WORK_MGMT_PRODUCTION_PROXY_APPROVED") != "verified_cloudflare_loopback":
    raise RuntimeError("Work Orders V1 requires a reviewed protected proxy/identity boundary.")
if len(os.environ.get("WORK_MGMT_PRODUCTION_COMMAND_SECRET", "")) < 48:
    raise RuntimeError("Work Orders V1 requires a private same-origin command secret.")
require_v1_production_configuration(writes=True)

from backend import app as application  # noqa: E402

# WSGI application only. Server Management must configure its own accepted
# service runner and protected route: there is intentionally no __main__ port.
