"""MSB FieldWiring browser API and static application host — V0.3.2."""

from __future__ import annotations

import os
from pathlib import Path

from flask import Flask, Response, jsonify, request, send_file, send_from_directory

from controller_access import (
    ControllerAccessError,
    ControllerAuthenticationError,
    cloudflare_operator_email,
    controller_browser_access,
)
from controller_inventory import (
    ControllerInventoryError,
    controller_detail,
    controller_list,
)
from field_context_hierarchy import build_field_hierarchy
from repository import ConfigError, PostgresRepository, Repository, SQLiteSnapshotRepository
from wiring import WiringError, build_wiring_package, safe_image_path

APP_VERSION = "V0.3.2"
BASE_DIR = Path(__file__).resolve().parent
app = Flask(__name__)


def repository() -> Repository:
    dev_snapshot = os.environ.get("FIELDWIRING_DEV_SNAPSHOT", "").strip()
    if dev_snapshot:
        return SQLiteSnapshotRepository(dev_snapshot)
    dsn = os.environ.get("FIELDWIRING_DATABASE_DSN", "").strip()
    if dsn:
        return PostgresRepository(dsn)
    raise ConfigError(
        "Configure FIELDWIRING_DATABASE_DSN for PostgreSQL or "
        "FIELDWIRING_DEV_SNAPSHOT for explicit read-only development mode"
    )


def optional_int(name: str) -> int | None:
    raw = request.args.get(name, "").strip()
    if not raw:
        return None
    if not raw.isdigit():
        raise WiringError(f"Invalid {name}")
    return int(raw)


def operator_config_error(_: ConfigError) -> str:
    """Formatting-only operator message; retain configuration detail separately."""
    return (
        "Field Wiring is temporarily unavailable because its current data source "
        "could not be opened. Report that the Field Wiring service is unavailable."
    )


def operator_wiring_error(exc: WiringError) -> str:
    """Translate internal FieldWiring failures without changing engineering errors."""
    text = str(exc)
    folded = text.casefold()

    if folded.startswith("invalid "):
        return "This Field Wiring link is invalid. Return to lookup and select the Display or Stage again."

    if "does not belong to the requested" in folded or "requires a resolved stage and preview" in folded:
        return (
            "This Field Wiring link no longer matches the current Display, Stage, or Scene. "
            "Return to lookup and select it again."
        )

    if "not present in the current" in folded or "not present in the production database" in folded:
        return (
            "This Field Wiring link no longer matches the current approved data. "
            "Return to lookup and select it again."
        )

    if "no applicable field wiring" in folded or "display is not available for current fieldwiring" in folded:
        return "No current Field Wiring is available for this Display."

    if "no current field wiring rows" in folded:
        return "No current Field Wiring data is available for this Stage or Scene."

    if (
        "dmx source" in folded
        or "dmx source-detail" in folded
        or "atomic dmx" in folded
        or "v7.0.11" in folded
    ):
        return (
            "Current Field Wiring data for this selection is incomplete. "
            "Report the selected Display, Stage, or Scene so engineering can verify the current wiring data."
        )

    if "image path" in folded or "wiring image is not available" in folded or "sourcedocs content" in folded:
        return "The requested wiring image is not available. Return to the current Field Wiring page and try another image."

    return (
        "Field Wiring could not be opened for this selection. Return to lookup and try again, "
        "or report the selected Display, Stage, or Scene."
    )


@app.get("/")
def index() -> Response:
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/fieldwiring.css")
def css() -> Response:
    return send_from_directory(BASE_DIR, "fieldwiring.css")


@app.get("/fieldwiring.js")
def js() -> Response:
    return send_from_directory(BASE_DIR, "fieldwiring.js")


@app.get("/controllers")
@app.get("/controllers.html")
def controllers_page() -> Response:
    return send_from_directory(BASE_DIR, "controllers.html")


@app.get("/controllers.css")
def controllers_css() -> Response:
    return send_from_directory(BASE_DIR, "controllers.css")


@app.get("/controllers.js")
def controllers_js() -> Response:
    return send_from_directory(BASE_DIR, "controllers.js")


@app.get("/wiring")
@app.get("/wiring.html")
def wiring_page() -> Response:
    return send_from_directory(BASE_DIR, "wiring.html")


@app.get("/wiring.css")
def wiring_css() -> Response:
    return send_from_directory(BASE_DIR, "wiring.css")


@app.get("/wiring_sticky_context.css")
def wiring_sticky_context_css() -> Response:
    return send_from_directory(BASE_DIR, "wiring_sticky_context.css")


@app.get("/wiring_workspace_focus.css")
def wiring_workspace_focus_css() -> Response:
    return send_from_directory(BASE_DIR, "wiring_workspace_focus.css")


@app.get("/wiring.js")
def wiring_js() -> Response:
    return send_from_directory(BASE_DIR, "wiring.js")


@app.get("/wiring_e131.js")
def wiring_e131_js() -> Response:
    return send_from_directory(BASE_DIR, "wiring_e131.js")


@app.get("/wiring_dumbrgb.js")
def wiring_dumbrgb_js() -> Response:
    return send_from_directory(BASE_DIR, "wiring_dumbrgb.js")


@app.get("/wiring_disclosure.js")
def wiring_disclosure_js() -> Response:
    return send_from_directory(BASE_DIR, "wiring_disclosure.js")


@app.get("/wiring_workspace_focus.js")
def wiring_workspace_focus_js() -> Response:
    return send_from_directory(BASE_DIR, "wiring_workspace_focus.js")


@app.get("/api/health")
def health() -> Response:
    mode = "sqlite-dev" if os.environ.get("FIELDWIRING_DEV_SNAPSHOT") else "postgres"
    return jsonify(status="ok", version=APP_VERSION, data_mode=mode)


@app.get("/api/controller-access")
def api_controller_access() -> Response:
    email = cloudflare_operator_email(request.headers)
    return jsonify(access=controller_browser_access(repository(), email))


@app.get("/api/displays")
def api_displays() -> Response:
    query = request.args.get("q", "")
    return jsonify(displays=repository().search_displays(query))


@app.get("/api/displays/<int:display_id>/context")
def api_display_context(display_id: int) -> Response:
    context = repository().display_context(display_id)
    if context is None:
        return jsonify(error="Display is not available for FieldWiring"), 404
    return jsonify(context=context)


@app.get("/api/stages")
def api_stages() -> Response:
    hierarchy = build_field_hierarchy(repository().shared_stages())
    return jsonify(
        stages=hierarchy["stages"],
        review_required=hierarchy["review_required"],
    )


@app.get("/api/controllers")
def api_controllers() -> Response:
    data = controller_list(
        repository(),
        query=request.args.get("q", ""),
        stage_id=optional_int("stage_id"),
        status=request.args.get("status", ""),
        model=request.args.get("model", ""),
        assignment=request.args.get("assignment", ""),
    )
    return jsonify(**data)


@app.get("/api/controllers/<int:controller_id>")
def api_controller_detail(controller_id: int) -> Response:
    data = controller_detail(repository(), controller_id)
    if data is None:
        return jsonify(error="Controller was not found"), 404
    return jsonify(**data)


@app.get("/api/wiring")
def api_wiring() -> Response:
    package = build_wiring_package(
        repository(),
        display_id=optional_int("display_id"),
        stage_id=optional_int("stage_id"),
        preview_uuid=request.args.get("preview_uuid", "").strip() or None,
        scene_uuid=request.args.get("scene_uuid", "").strip() or None,
    )
    return jsonify(wiring=package)


@app.get("/api/wiring/image")
def api_wiring_image() -> Response:
    path = safe_image_path(request.args.get("path", ""))
    return send_file(path, conditional=True, max_age=300)


@app.errorhandler(ConfigError)
def config_error(exc: ConfigError) -> tuple[Response, int]:
    return jsonify(
        error=operator_config_error(exc),
        engineering_error=str(exc),
    ), 503


@app.errorhandler(ControllerAuthenticationError)
def controller_authentication_error(exc: ControllerAuthenticationError) -> tuple[Response, int]:
    return jsonify(
        error="Cloudflare Access identity is required for Controller management.",
        engineering_error=str(exc),
    ), 401


@app.errorhandler(ControllerAccessError)
def controller_access_error(exc: ControllerAccessError) -> tuple[Response, int]:
    return jsonify(
        error="Controller permissions could not be resolved.",
        engineering_error=str(exc),
    ), 503


@app.errorhandler(ControllerInventoryError)
def controller_inventory_error(exc: ControllerInventoryError) -> tuple[Response, int]:
    return jsonify(
        error="Controller Inventory is available only from the production PostgreSQL data source.",
        engineering_error=str(exc),
    ), 503


@app.errorhandler(WiringError)
def wiring_error(exc: WiringError) -> tuple[Response, int]:
    return jsonify(
        error=operator_wiring_error(exc),
        engineering_error=str(exc),
    ), 400


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8790")), debug=False)
