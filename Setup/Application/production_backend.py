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
from setup_display_ownership_api import setup_display_ownership_api
from setup_prerequisite_order_api import setup_prerequisite_order_api
from setup_material_resolution import install_setup_material_resolution
from setup_display_ownership import install_setup_display_ownership

PRODUCTION_VERSION = "V0.3.12-display-ownership"
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
        "setup_resource_picker_compact.css",
        "setup_resource_picker_compact.js",
        "setup_review_usability.css",
        "setup_review_usability.js",
        "setup_next_pass.css",
        "setup_next_pass.js",
        "setup_predecessor_drag.css",
        "setup_predecessor_drag.js",
        "setup_prerequisite_editor.css",
        "setup_prerequisite_editor.js",
        "setup_stage_order.css",
        "setup_stage_order.js",
        "setup_acceptance_fixes.css",
        "setup_acceptance_fixes.js",
        "setup_session_year_guard.css",
        "setup_session_year_guard.js",
        "setup_analytics.js",
        "setup_live_review_fixes.css",
        "setup_live_review_fixes.js",
        "setup_operational_search.js",
        "setup_training_ux.css",
        "setup_training_ux.js",
        "setup_assigned_review.js",
        "setup_training_review_refinement.css",
        "setup_training_review_refinement.js",
        "setup_catalog_effort.js",
        "setup_catalog_dirty_guard.js",
        "setup_task_detail_compact.css",
        "setup_task_detail_compact.js",
        "setup_active_task_context.css",
        "setup_active_task_context.js",
        "setup_display_ownership.css",
        "setup_display_ownership.js",
    }
)

# Accepted Setup material source resolution remains authoritative. #141 installs
# only the task-ownership layer after that resolver so LOR Stage/Scene membership
# and ref.display.container_id remain unchanged.
install_setup_material_resolution()
install_setup_display_ownership()

app = Flask(__name__)
app.register_blueprint(setup_api)
app.register_blueprint(setup_resource_api)
app.register_blueprint(setup_next_api)
app.register_blueprint(setup_training_api)
app.register_blueprint(setup_effort_api)
app.register_blueprint(setup_material_api)
app.register_blueprint(setup_display_ownership_api)
app.register_blueprint(setup_prerequisite_order_api)


def _no_store(response):
    """Never let an old Setup page/asset survive an application deployment."""
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response


@app.get("/")
def production_index():
    return _no_store(send_from_directory(BASE_DIR, "production.html"))


@app.get("/api/health")
def production_health():
    mode = "postgres" if any(
        os.environ.get(name, "").strip()
        for name in ("SETUP_DATABASE_DSN", "FIELDWIRING_DATABASE_DSN", "PROCEDURE_DATABASE_DSN")
    ) else "unconfigured"
    return _no_store(jsonify(status="ok", version=PRODUCTION_VERSION, data_mode=mode))


@app.get("/<path:name>")
def production_asset(name: str):
    if name not in PRODUCTION_ASSETS:
        abort(404)
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return _no_store(send_from_directory(BASE_DIR, name, mimetype=mimetype))


if __name__ == "__main__":
    app.run(
        host=os.environ.get("SETUP_BIND_HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "8780")),
        debug=False,
    )
