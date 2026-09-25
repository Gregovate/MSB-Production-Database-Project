"""MSB Setup Session protected production application host.

This entry point is deliberately separate from the local prototype Flask app.
It serves only the shared Production UI/static assets plus the protected
Cloudflare/Directus-governed Setup API. Prototype routes and source files are
not exposed by this WSGI application.
"""
from __future__ import annotations

import gzip
import logging
import os
import threading
import time
import uuid

from flask import Flask, abort, g, jsonify, request, send_from_directory

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
from setup_material_readiness_api import setup_material_readiness_api
from setup_material_resolution import install_setup_material_resolution
from setup_display_ownership import install_setup_display_ownership
from setup_assignment_layer import install_setup_assignment_layer
from setup_kit_box_catalog_fix import install_setup_kit_box_catalog_fix

PRODUCTION_VERSION = "V0.3.18-scheduling-board"

# #222 lightweight Production request instrumentation.
#
# This deliberately measures only protected Setup API request handling. It does
# not issue database queries, add network calls, inspect request bodies, or log
# query-string/form values. The authenticated Cloudflare email is logged so
# operator reports can be correlated to the exact server-side requests that
# occurred at the same time.
_SETUP_PERF_LOCK = threading.Lock()
_SETUP_PERF_ACTIVE_REQUESTS = 0
_SETUP_PERF_PREFIX = "SETUP_PERF"
_SETUP_PERF_SUMMARY_SECONDS = 60.0
_SETUP_PERF_SLOW_MS = 250.0
_SETUP_JSON_GZIP_MIN_BYTES = 16 * 1024
_SETUP_PERF_WINDOWS: dict[str, dict] = {}
_SETUP_OPERATOR_HEADER = "Cf-Access-Authenticated-User-Email"
_SETUP_PERF_LOGGER = logging.getLogger("msb.setup.performance")
_SETUP_PERF_LOGGER.setLevel(logging.INFO)
_SETUP_PERF_LOGGER.propagate = False
if not _SETUP_PERF_LOGGER.handlers:
    _setup_perf_handler = logging.StreamHandler()
    _setup_perf_handler.setFormatter(logging.Formatter("%(message)s"))
    _SETUP_PERF_LOGGER.addHandler(_setup_perf_handler)
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
PICK_LIST_ASSETS = frozenset(
    {
        "setup_pick_list.css",
        "setup_pick_list.js",
        "qrcode.min.js",
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
app.register_blueprint(setup_material_readiness_api)


def _setup_perf_is_traced_request() -> bool:
    return request.path.startswith("/api/setup/")


def _setup_perf_increment_active() -> int:
    global _SETUP_PERF_ACTIVE_REQUESTS
    with _SETUP_PERF_LOCK:
        _SETUP_PERF_ACTIVE_REQUESTS += 1
        return _SETUP_PERF_ACTIVE_REQUESTS


def _setup_perf_current_active() -> int:
    with _SETUP_PERF_LOCK:
        return _SETUP_PERF_ACTIVE_REQUESTS


def _setup_perf_decrement_active() -> None:
    global _SETUP_PERF_ACTIVE_REQUESTS
    with _SETUP_PERF_LOCK:
        _SETUP_PERF_ACTIVE_REQUESTS = max(0, _SETUP_PERF_ACTIVE_REQUESTS - 1)


def _setup_perf_new_window(started: float) -> dict:
    return {
        "started": started,
        "requests": 0,
        "total_ms": 0.0,
        "response_bytes": 0,
        "max_active": 0,
        "routes": {},
    }


def _setup_perf_record_summary(
    *,
    operator: str,
    method: str,
    route: str,
    elapsed_ms: float,
    response_bytes: int,
    active: int,
) -> str | None:
    now = time.perf_counter()
    with _SETUP_PERF_LOCK:
        window = _SETUP_PERF_WINDOWS.setdefault(operator, _setup_perf_new_window(now))
        window["requests"] += 1
        window["total_ms"] += elapsed_ms
        window["response_bytes"] += max(0, response_bytes)
        window["max_active"] = max(window["max_active"], active)

        route_key = f"{method} {route}"
        route_stats = window["routes"].setdefault(
            route_key,
            {"count": 0, "total_ms": 0.0, "max_ms": 0.0, "response_bytes": 0},
        )
        route_stats["count"] += 1
        route_stats["total_ms"] += elapsed_ms
        route_stats["max_ms"] = max(route_stats["max_ms"], elapsed_ms)
        route_stats["response_bytes"] += max(0, response_bytes)

        window_seconds = now - window["started"]
        if window_seconds < _SETUP_PERF_SUMMARY_SECONDS:
            return None

        route_parts = []
        for key, stats in sorted(
            window["routes"].items(),
            key=lambda item: (-item[1]["count"], item[0]),
        ):
            average_ms = stats["total_ms"] / stats["count"]
            route_parts.append(
                f"{key}|n={stats['count']}|avg_ms={average_ms:.1f}|"
                f"max_ms={stats['max_ms']:.1f}|bytes={stats['response_bytes']}"
            )

        average_ms = window["total_ms"] / window["requests"]
        summary = (
            f"{_SETUP_PERF_PREFIX}_SUMMARY operator={operator} pid={os.getpid()} "
            f"window_s={window_seconds:.1f} requests={window['requests']} "
            f"avg_ms={average_ms:.1f} max_active={window['max_active']} "
            f"response_bytes={window['response_bytes']} routes="
            + ";".join(route_parts)
        )
        _SETUP_PERF_WINDOWS[operator] = _setup_perf_new_window(now)
        return summary


def _setup_maybe_gzip_json(response):
    """Compress large protected Setup JSON responses for slow field links."""
    if request.method == "HEAD" or response.status_code in (204, 304):
        return response
    if response.headers.get("Content-Encoding"):
        return response

    content_type = (response.headers.get("Content-Type") or "").lower()
    if not content_type.startswith("application/json"):
        return response

    accepted = (request.headers.get("Accept-Encoding") or "").lower()
    if "gzip" not in accepted:
        return response

    data = response.get_data()
    if len(data) < _SETUP_JSON_GZIP_MIN_BYTES:
        return response

    compressed = gzip.compress(data, compresslevel=5, mtime=0)
    if len(compressed) >= len(data):
        return response

    response.set_data(compressed)
    response.headers["Content-Encoding"] = "gzip"
    response.headers["Content-Length"] = str(len(compressed))
    response.vary.add("Accept-Encoding")
    return response


@app.before_request
def setup_performance_trace_start() -> None:
    if not _setup_perf_is_traced_request():
        return

    g.setup_perf_started = time.perf_counter()
    g.setup_perf_request_id = uuid.uuid4().hex[:12]
    g.setup_perf_active = _setup_perf_increment_active()


@app.after_request
def setup_performance_trace_finish(response):
    started = getattr(g, "setup_perf_started", None)
    request_id = getattr(g, "setup_perf_request_id", None)
    if started is None or request_id is None:
        return response

    response = _setup_maybe_gzip_json(response)
    elapsed_ms = (time.perf_counter() - started) * 1000.0
    route = request.url_rule.rule if request.url_rule is not None else "<unmatched>"
    operator = (request.headers.get(_SETUP_OPERATOR_HEADER) or "<unauthenticated>").strip().lower()
    response_bytes = response.content_length if response.content_length is not None else -1
    active = _setup_perf_current_active()

    response.headers["Server-Timing"] = f"app;dur={elapsed_ms:.1f}"
    response.headers["X-MSB-Request-ID"] = request_id

    event_kind = None
    if response.status_code >= 400:
        event_kind = "ERROR"
    elif request.method != "GET":
        event_kind = "WRITE"
    elif elapsed_ms >= _SETUP_PERF_SLOW_MS:
        event_kind = "SLOW"

    if event_kind is not None:
        _SETUP_PERF_LOGGER.info(
            "%s_EVENT kind=%s request_id=%s operator=%s method=%s route=%s "
            "status=%s app_ms=%.1f response_bytes=%s pid=%s thread=%s "
            "active_in_worker=%s",
            _SETUP_PERF_PREFIX,
            event_kind,
            request_id,
            operator,
            request.method,
            route,
            response.status_code,
            elapsed_ms,
            response_bytes,
            os.getpid(),
            threading.get_ident(),
            active,
        )

    summary = _setup_perf_record_summary(
        operator=operator,
        method=request.method,
        route=route,
        elapsed_ms=elapsed_ms,
        response_bytes=response_bytes,
        active=active,
    )
    if summary is not None:
        _SETUP_PERF_LOGGER.info(summary)

    return response


@app.teardown_request
def setup_performance_trace_teardown(_error) -> None:
    if getattr(g, "setup_perf_started", None) is not None:
        _setup_perf_decrement_active()


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

@app.get("/pick-list")
@app.get("/pick-list/")
def pick_list():
    """Read-only scheduled physical-demand Pick List."""
    return _no_store(send_from_directory(BASE_DIR, "pick_list.html"))


@app.get("/pick-list/assets/<path:name>")
def pick_list_asset(name: str):
    if name not in PICK_LIST_ASSETS:
        abort(404)
    mimetype = "application/javascript" if name.casefold().endswith(".js") else None
    return _no_store(send_from_directory(BASE_DIR, name, mimetype=mimetype))

