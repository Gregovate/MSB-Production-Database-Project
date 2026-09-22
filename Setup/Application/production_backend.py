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
from setup_extra_material_api import setup_extra_material_api
from setup_kit_inventory_api import setup_kit_inventory_api
from setup_material_audit_api import setup_material_audit_api
from setup_next_api import setup_next_api
from setup_training_api import setup_training_api
from setup_effort_api import setup_effort_api
from setup_material_api import setup_material_api
from setup_display_ownership_api import setup_display_ownership_api
from setup_assignment_api import setup_assignment_api
from setup_prerequisite_order_api import setup_prerequisite_order_api
from setup_planning_summary_api import setup_planning_summary_api
from setup_scheduling_board_api import setup_scheduling_board_api
from setup_material_resolution import install_setup_material_resolution
from setup_display_ownership import install_setup_display_ownership
from setup_assignment_layer import install_setup_assignment_layer
from setup_kit_box_catalog_fix import install_setup_kit_box_catalog_fix

PRODUCTION_VERSION = "V0.3.15-material-audit-candidate"
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
        "setup_display_ownership_large_scope_fix.js",
        "setup_kit_box_assignment.css",
        "setup_kit_box_assignment.js",
        "setup_extra_materials.css",
        "setup_extra_materials.js",
        "setup_task_extra_materials.js",
        "setup_task_extra_material_sources.js",
        "setup_extra_material_source_usability.js",
        "setup_uom_catalog.js",
        "setup_planning_summary.js",
        "setup_scheduling_board.css",
        "setup_scheduling_board.js",
    }
)
KIT_INVENTORY_ASSETS = frozenset(
    {
        "setup_kit_inventory.css",
        "setup_kit_inventory.js",
        "setup_kit_inventory_displays.js",
        "setup_kit_inventory_review.js",
        "setup_uom_catalog.js",
    }
)
TPOST_INVENTORY_ASSETS = frozenset(
    {
        "setup_tpost_inventory.js",
        "setup_tpost_inventory_clarity.css",
        "setup_tpost_inventory_clarity.js",
        "setup_tpost_inventory_bootstrap.js",
    }
)
PLANNING_SUMMARY_ASSETS = frozenset(
    {
        "setup_planning_summary.css",
        "setup_planning_summary.js",
    }
)
MATERIAL_AUDIT_ASSETS = frozenset(
    {
        "setup_material_audit.css",
        "setup_material_audit.js",
    }
)
CAPTAIN_WORK_LIST_ASSETS = frozenset(
    {
        "setup_captain_work_list.css",
        "setup_captain_work_list.js",
    }
)

# Accepted Setup material source resolution remains authoritative. The original
# #141 ownership layer is installed first, then the corrected assignment layer
# supersedes its first-use target logic and adds explicit Kit Box assignment.
# The final catalog fix keeps Kit Box reads on the already-used Setup/container
# tables and avoids an unnecessary runtime lookup join.
install_setup_material_resolution()
install_setup_display_ownership()
install_setup_assignment_layer()
install_setup_kit_box_catalog_fix()

app = Flask(__name__)
app.register_blueprint(setup_api)
app.register_blueprint(setup_resource_api)
app.register_blueprint(setup_extra_material_api)
app.register_blueprint(setup_kit_inventory_api)
app.register_blueprint(setup_material_audit_api)
app.register_blueprint(setup_next_api)
app.register_blueprint(setup_training_api)
app.register_blueprint(setup_effort_api)
app.register_blueprint(setup_material_api)
app.register_blueprint(setup_display_ownership_api)
app.register_blueprint(setup_assignment_api)
app.register_blueprint(setup_prerequisite_order_api)
app.register_blueprint(setup_planning_summary_api)
app.register_blueprint(setup_scheduling_board_api)


def _no_store(response):
    """Never let an old Setup page/asset survive an application deployment."""
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response


@app.get("/")
def production_index():
    return _no_store(send_from_directory(BASE_DIR, "production.html"))


@app.get("/planning-summary")
@app.get("/planning-summary/")
def planning_summary():
    """Read-only reusable-Catalog Planning Summary print surface."""
    return _no_store(send_from_directory(BASE_DIR, "planning_summary.html"))


@app.get("/planning-summary/assets/<path:name>")
def planning_summary_asset(name: str):
    if name not in PLANNING_SUMMARY_ASSETS:
        abort(404)
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return _no_store(send_from_directory(BASE_DIR, name, mimetype=mimetype))


@app.get("/captain-work-list")
@app.get("/captain-work-list/")
def captain_work_list():
    """Read-only connected/printable Captain work list over the annual schedule."""
    return _no_store(send_from_directory(BASE_DIR, "captain_work_list.html"))


@app.get("/captain-work-list/assets/<path:name>")
def captain_work_list_asset(name: str):
    if name not in CAPTAIN_WORK_LIST_ASSETS:
        abort(404)
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return _no_store(send_from_directory(BASE_DIR, name, mimetype=mimetype))


@app.get("/material-audit")
@app.get("/material-audit/")
def material_audit():
    """Manager-facing reusable-Catalog Material Completeness Audit."""
    return _no_store(send_from_directory(BASE_DIR, "material_audit.html"))


@app.get("/material-audit/assets/<path:name>")
def material_audit_asset(name: str):
    if name not in MATERIAL_AUDIT_ASSETS:
        abort(404)
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return _no_store(send_from_directory(BASE_DIR, name, mimetype=mimetype))


@app.get("/kit-inventory")
@app.get("/kit-inventory/")
@app.get("/kit-inventory/<int:container_id>")
def kit_inventory(container_id: int | None = None):
    """Standalone durable Kit Box inventory route."""
    _ = container_id
    return _no_store(send_from_directory(BASE_DIR, "kit_inventory.html"))


@app.get("/kit-inventory/assets/<path:name>")
def kit_inventory_asset(name: str):
    if name not in KIT_INVENTORY_ASSETS:
        abort(404)
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return _no_store(send_from_directory(BASE_DIR, name, mimetype=mimetype))


@app.get("/t-post-inventory")
@app.get("/t-post-inventory/")
def tpost_inventory():
    """Standalone shared T-Post stock inventory outside Kit Boxes."""
    return _no_store(send_from_directory(BASE_DIR, "t_post_inventory.html"))


@app.get("/t-post-inventory/assets/<path:name>")
def tpost_inventory_asset(name: str):
    if name not in TPOST_INVENTORY_ASSETS:
        abort(404)
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return _no_store(send_from_directory(BASE_DIR, name, mimetype=mimetype))


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
