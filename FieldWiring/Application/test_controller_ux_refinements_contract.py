from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
STATIC = BASE_DIR / "static"


def test_controller_page_loads_management_assets_exactly_once() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")
    extras = (STATIC / "controllers_detail_extras.js").read_text(encoding="utf-8")

    # Management assets are loaded once, statically. Capability checks remain
    # inside the management code/server boundary; detail extras must not append
    # a second script instance after authorization resolves.
    assert html.count('static/controllers_management.js') == 1
    assert html.count('static/controllers_management.css') == 1
    assert "loadManagementAssets" not in extras
    assert "controller-management-js" not in extras
    assert "controller-management-css" not in extras


def test_live_ux_refinement_assets_are_loaded() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")

    assert "static/controllers_ux_refinements.css" in html
    assert "static/controllers_ux_refinements.js" in html
    assert html.index("controllers_management.js") < html.index("controllers_ux_refinements.js")


def test_ux_refinements_clarify_physical_attachment_and_context_help() -> None:
    source = (STATIC / "controllers_ux_refinements.js").read_text(encoding="utf-8")

    assert "Physically Attached to Display" in source
    assert "separate from Controller-to-Display assignments" in source
    assert "Physical Verification" in source
    assert "Configuration Verification" in source
    assert "Firmware Verification" in source
    assert "Wiring Source Display" in source
    assert "field-help" in source
    assert "aria-label" in source


def test_ux_refinements_defensively_remove_duplicate_add_controller_buttons() -> None:
    source = (STATIC / "controllers_ux_refinements.js").read_text(encoding="utf-8")

    assert "querySelectorAll('#add-controller-button')" in source
    assert "buttons.slice(1)" in source
    assert "duplicate.remove()" in source


def test_print_label_has_distinct_non_blue_action_treatment() -> None:
    css = (STATIC / "controllers_ux_refinements.css").read_text(encoding="utf-8")
    source = (STATIC / "controllers_ux_refinements.js").read_text(encoding="utf-8")

    assert "#request-controller-label.print-action-button" in css
    assert "#7c3aed" in css
    assert "print-action-button" in source


def test_human_facing_label_request_prefers_mapped_operator_display_name() -> None:
    source = (STATIC / "controllers_detail_extras.js").read_text(encoding="utf-8")

    assert "result.requested_by || controllerAccess?.display_name || result.updated_by" in source
