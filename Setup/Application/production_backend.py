"""MSB Setup Session protected production application host.

The local prototype remains available through backend.py on the prototype branch.
This entry point deliberately serves production.html, registers the database-backed
Cloudflare/Directus-governed API, and blocks prototype-only Procedure/UI routes so
shared users cannot accidentally operate against browser-local prototype state.
"""
from __future__ import annotations

import os

from flask import abort, jsonify, request, send_from_directory

from backend import BASE_DIR, app
from setup_api import setup_api

PRODUCTION_VERSION = "V0.1.0-production-foundation"

app.register_blueprint(setup_api)


@app.before_request
def block_prototype_only_routes() -> None:
    """Do not expose the local prototype surfaces from the production service."""
    if request.path.startswith("/api/setup-instructions"):
        abort(404)
    if request.path in {
        "/index.html",
        "/setup.js",
        "/setup_review_extensions.js",
        "/setup_instruction_live.js",
        "/setup_review_clarity.js",
    }:
        abort(404)


def production_index():
    return send_from_directory(BASE_DIR, "production.html")


def production_health():
    mode = "postgres" if any(
        os.environ.get(name, "").strip()
        for name in ("SETUP_DATABASE_DSN", "FIELDWIRING_DATABASE_DSN", "PROCEDURE_DATABASE_DSN")
    ) else "unconfigured"
    return jsonify(status="ok", version=PRODUCTION_VERSION, data_mode=mode)


# Replace the prototype root/health view functions only in this production entry point.
app.view_functions["index"] = production_index
app.view_functions["health"] = production_health


if __name__ == "__main__":
    app.run(
        host=os.environ.get("SETUP_BIND_HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "8780")),
        debug=False,
    )
