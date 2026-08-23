"""MSB FieldWiring browser API and static application host — V0.2.0."""

from __future__ import annotations

import os
from pathlib import Path

from flask import Flask, Response, jsonify, request, send_file, send_from_directory

from field_context_hierarchy import build_field_hierarchy
from repository import ConfigError, PostgresRepository, Repository, SQLiteSnapshotRepository
from wiring import WiringError, build_wiring_package, safe_image_path

APP_VERSION = "V0.2.0"
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
            "Return to lookup and select the Display or Stage again."
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


@app.errorhandler(WiringError)
def wiring_error(exc: WiringError) -> tuple[Response, int]:
    return jsonify(
        error=operator_wiring_error(exc),
        engineering_error=str(exc),
    ), 400


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8790")), debug=False)
