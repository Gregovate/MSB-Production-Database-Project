from pathlib import Path

APP_DIR = Path(__file__).resolve().parent


def text(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_existing_catalog_edit_is_opt_in_and_new_material_flow_stays_separate() -> None:
    page = text("kit_inventory.html")

    assert "Find or edit an existing catalog material" in page
    assert "Nothing is edited until you explicitly choose a catalog material below" in page
    assert "Select a catalog material to edit…" in page
    assert "Save Changes to Existing Material" in page
    assert "Create a new catalog material" in page
    assert "Save New Catalog Material" in page
    assert "catalog-edit-active" in page
    assert "explicitValue" in page


def test_kit_primary_actions_are_visible_without_becoming_commit_buttons() -> None:
    css = text("setup_kit_inventory.css")

    assert "#expected-add," in css
    assert "#extra-material-catalog-toggle" in css
    assert "border: 2px solid var(--accent)" in css
    assert "background: var(--soft)" in css
    assert "font-weight: 700" in css


def test_expected_quantity_and_uom_use_compact_desktop_columns() -> None:
    css = text("setup_kit_inventory.css")

    assert "#expected-form .form-grid" in css
    assert "135px 185px" in css
    assert "#expected-form .form-grid > label" in css
    assert "align-self: start" in css
    assert "@media (max-width: 980px)" in css
    assert "@media (max-width: 600px)" in css
