"""MSB FieldWiring browser API and static application host — V0.4.0."""

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
from controller_commands import (
    ControllerCommandAuthorizationError,
    ControllerCommandConflictError,
    ControllerCommandError,
    ControllerCommandNotFoundError,
    ControllerCommandValidationError,
    assign_controller_display,
    create_controller,
    reassign_controller_display,
    request_controller_label,
    unassign_controller_display,
    update_controller,
    update_controller_display_assignment,
)
from controller_inventory import (
    ControllerInventoryError,
    controller_detail,
    controller_list,
)
from controller_management import (
    ControllerManagementAuthorizationError,
    ControllerManagementError,
    controller_assignment_display_search,
    controller_management_options,
)
from field_context_hierarchy import build_field_hierarchy
from repository import ConfigError, PostgresRepository, Repository, SQLiteSnapshotRepository
from wiring import WiringError, build_wiring_package, safe_image_path

APP_VERSION = "V0.4.0"
BASE_DIR = Path(__file__).resolve().parent
CONTROLLER_COMMAND_HEADER = "X-MSB-Controller-Command"
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


def require_controller_command_request() -> None:
    """Require the non-simple same-origin command shape used by Controller UI.

    Cloudflare Access authenticates the user. This additional browser command
    guard prevents a simple cross-site form submission from invoking a write.
    FieldWiring does not expose a permissive CORS policy for this custom header.
    """
    if not request.is_json:
        raise ControllerCommandAuthorizationError(
            "Controller command requires an application/json request"
        )
    if request.headers.get(CONTROLLER_COMMAND_HEADER, "") != "1":
        raise ControllerCommandAuthorizationError(
            "Controller command request guard is missing"
        )


def controller_json_body() -> dict:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise ControllerCommandValidationError(
            "Controller command requires a JSON object"
        )
    return payload


def require_controller_manager() -> tuple[Repository, str]:
    """Resolve presentation-side Manager access; DB commands recheck independently."""
    repo = repository()
    email = cloudflare_operator_email(request.headers)
    access = controller_browser_access(repo, email)
    if not access.get("can_manage_controllers"):
        raise ControllerCommandAuthorizationError(
            "Controller maintenance is not authorized for this account"
        )
    return repo, email


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


@app.post("/api/controllers")
def api_controller_create() -> Response:
    require_controller_command_request()
    email = cloudflare_operator_email(request.headers)
    result = create_controller(
        repository(),
        email=email,
        payload=controller_json_body(),
    )
    return jsonify(controller=result), 201


@app.get("/api/controllers/<int:controller_id>")
def api_controller_detail(controller_id: int) -> Response:
    data = controller_detail(repository(), controller_id)
    if data is None:
        return jsonify(error="Controller was not found"), 404
    return jsonify(**data)


@app.patch("/api/controllers/<int:controller_id>")
def api_controller_update(controller_id: int) -> Response:
    require_controller_command_request()
    email = cloudflare_operator_email(request.headers)
    result = update_controller(
        repository(),
        email=email,
        controller_id=controller_id,
        payload=controller_json_body(),
    )
    return jsonify(controller=result)


@app.post("/api/controllers/<int:controller_id>/print-label")
def api_controller_print_label(controller_id: int) -> Response:
    require_controller_command_request()
    email = cloudflare_operator_email(request.headers)
    result = request_controller_label(
        repository(),
        email=email,
        controller_id=controller_id,
    )
    return jsonify(controller=result)


@app.get("/api/controller-management/options")
def api_controller_management_options() -> Response:
    repo, email = require_controller_manager()
    return jsonify(options=controller_management_options(repo, email))


@app.get("/api/controller-management/displays")
def api_controller_management_displays() -> Response:
    repo, _email = require_controller_manager()
    query = request.args.get("q", "")
    return jsonify(displays=controller_assignment_display_search(repo, query))


@app.post("/api/controllers/<int:controller_id>/assignments")
def api_controller_assignment_create(controller_id: int) -> Response:
    require_controller_command_request()
    email = cloudflare_operator_email(request.headers)
    result = assign_controller_display(
        repository(),
        email=email,
        controller_id=controller_id,
        payload=controller_json_body(),
    )
    return jsonify(assignment=result), 201


@app.patch("/api/controllers/<int:controller_id>/assignments/<int:display_id>")
def api_controller_assignment_update(controller_id: int, display_id: int) -> Response:
    require_controller_command_request()
    email = cloudflare_operator_email(request.headers)
    result = update_controller_display_assignment(
        repository(),
        email=email,
        controller_id=controller_id,
        display_id=display_id,
        payload=controller_json_body(),
    )
    return jsonify(assignment=result)


@app.post("/api/controllers/<int:controller_id>/assignments/<int:display_id>/reassign")
def api_controller_assignment_reassign(controller_id: int, display_id: int) -> Response:
    require_controller_command_request()
    email = cloudflare_operator_email(request.headers)
    result = reassign_controller_display(
        repository(),
        email=email,
        controller_id=controller_id,
        old_display_id=display_id,
        payload=controller_json_body(),
    )
    return jsonify(assignment=result)


@app.delete("/api/controllers/<int:controller_id>/assignments/<int:display_id>")
def api_controller_assignment_delete(controller_id: int, display_id: int) -> Response:
    require_controller_command_request()
    email = cloudflare_operator_email(request.headers)
    payload = controller_json_body()
    result = unassign_controller_display(
        repository(),
        email=email,
        controller_id=controller_id,
        display_id=display_id,
        return_available=payload.get("return_available", True),
    )
    return jsonify(assignment=result)


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


@app.errorhandler(ControllerCommandAuthorizationError)
def controller_command_authorization_error(
    exc: ControllerCommandAuthorizationError,
) -> tuple[Response, int]:
    return jsonify(
        error="This account is not authorized for that Controller action.",
        engineering_error=str(exc),
    ), 403


@app.errorhandler(ControllerCommandNotFoundError)
def controller_command_not_found_error(
    exc: ControllerCommandNotFoundError,
) -> tuple[Response, int]:
    return jsonify(
        error=str(exc) or "Controller or assignment was not found.",
        engineering_error=str(exc),
    ), 404


@app.errorhandler(ControllerCommandValidationError)
def controller_command_validation_error(
    exc: ControllerCommandValidationError,
) -> tuple[Response, int]:
    return jsonify(
        error=str(exc) or "Controller data is invalid.",
        engineering_error=str(exc),
    ), 400


@app.errorhandler(ControllerCommandConflictError)
def controller_command_conflict_error(
    exc: ControllerCommandConflictError,
) -> tuple[Response, int]:
    return jsonify(
        error=str(exc) or "That Controller relationship already exists.",
        engineering_error=str(exc),
    ), 409


@app.errorhandler(ControllerCommandError)
def controller_command_error(exc: ControllerCommandError) -> tuple[Response, int]:
    return jsonify(
        error="Controller action could not be completed.",
        engineering_error=str(exc),
    ), 503


@app.errorhandler(ControllerManagementAuthorizationError)
def controller_management_authorization_error(
    exc: ControllerManagementAuthorizationError,
) -> tuple[Response, int]:
    return jsonify(
        error="This account is not authorized for Controller maintenance.",
        engineering_error=str(exc),
    ), 403


@app.errorhandler(ControllerManagementError)
def controller_management_error(exc: ControllerManagementError) -> tuple[Response, int]:
    return jsonify(
        error="Controller maintenance reference data could not be loaded.",
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
