"""MSB Setup Session protected production application host.

This entry point is deliberately separate from the local prototype Flask app.
It serves only the shared Production UI/static assets plus the protected
Cloudflare/Directus-governed Setup API. Prototype routes and source files are
not exposed by this WSGI application.
"""
from __future__ import annotations

import os

from flask import Flask, abort, jsonify, send_from_directory

from backend import BASE_DIR
from setup_api import setup_api
from setup_resource_api import setup_resource_api
from setup_next_api import setup_next_api

PRODUCTION_VERSION = "V0.3.0-final-browser-review"
PRODUCTION_ASSETS = frozenset(
    {
        "setup.css",
        "setup_review_clarity.css",
        "setup_theme.css",
        "setup_theme.js",
        "setup_production.css",
        "setup_production.js",
        "setup_resource_review.css",
        "setup_resource_review.js",
        "setup_review_usability.css",
        "setup_review_usability.js",
        "setup_next_pass.css",
        "setup_next_pass.js",
    }
)

app = Flask(__name__)
app.register_blueprint(setup_api)
app.register_blueprint(setup_resource_api)
app.register_blueprint(setup_next_api)


@app.get("/")
def production_index():
    return send_from_directory(BASE_DIR, "production.html")


@app.get("/api/health")
def production_health():
    mode = "postgres" if any(
        os.environ.get(name, "").strip()
        for name in ("SETUP_DATABASE_DSN", "FIELDWIRING_DATABASE_DSN", "PROCEDURE_DATABASE_DSN")
    ) else "unconfigured"
    return jsonify(status="ok", version=PRODUCTION_VERSION, data_mode=mode)


@app.get("/<path:name>")
def production_asset(name: str):
    if name not in PRODUCTION_ASSETS:
        abort(404)
    return send_from_directory(BASE_DIR, name)


if __name__ == "__main__":
    app.run(
        host=os.environ.get("SETUP_BIND_HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "8780")),
        debug=False,
    )
