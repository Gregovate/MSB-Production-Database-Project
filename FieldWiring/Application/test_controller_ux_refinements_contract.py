from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
STATIC = BASE_DIR / "static"


def test_controller_page_loads_management_once_through_authorized_loader() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")
    extras = (STATIC / "controllers_detail_extras.js").read_text(encoding="utf-8")

    # Controller management is capability-gated by controllers_detail_extras.js.
    # Do not also load the same management assets statically or authorized users
    # receive a second script instance and duplicate Add Controller controls.
    assert '<script src="static/controllers_management.js' not in html
    assert '<link rel="stylesheet" href="static/controllers_management.css' not in html
    assert "controller-management-js" in extras
    assert "controller-management-css" in extras
    assert "if (controllerAccess?.can_manage_controllers) loadManagementAssets();" in extras


def test_live_ux_refinement_assets_are_loaded() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")

    assert "static/controllers_ux_refinements.css" in html
    assert "static/controllers_ux_refinements.js" in html
    assert html.index("controllers_detail_extras.js") < html.index("controllers_ux_refinements.js")


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
