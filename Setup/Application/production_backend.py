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
from setup_training_api import setup_training_api
from setup_effort_api import setup_effort_api
from setup_material_api import setup_material_api

PRODUCTION_VERSION = "V0.3.5-reconstruction-material-review"
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
        "setup_acceptance_fixes.css",
        "setup_acceptance_fixes.js",
        "setup_session_year_guard.css",
        "setup_session_year_guard.js",
        "setup_analytics.js",
        "setup_live_review_fixes.css",
        "setup_live_review_fixes.js",
        "setup_training_ux.css",
        "setup_training_ux.js",
        "setup_assigned_review.js",
        "setup_training_review_refinement.css",
        "setup_training_review_refinement.js",
        "setup_catalog_effort.js",
        "setup_material.css",
        "setup_material.js",
    }
)

app = Flask(__name__)
app.register_blueprint(setup_api)
app.register_blueprint(setup_resource_api)
app.register_blueprint(setup_next_api)
app.register_blueprint(setup_training_api)
app.register_blueprint(setup_effort_api)
app.register_blueprint(setup_material_api)


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
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return send_from_directory(BASE_DIR, name, mimetype=mimetype)


if __name__ == "__main__":
    app.run(
        host=os.environ.get("SETUP_BIND_HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "8780")),
        debug=False,
    )
