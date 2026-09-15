from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_DIR = BASE_DIR.parent / "Database"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_kit_inventory_exposes_resource_consistent_extra_material_catalog_management() -> None:
    page = text(BASE_DIR / "kit_inventory.html")
    review = text(BASE_DIR / "setup_kit_inventory_review.js")
    css = text(BASE_DIR / "setup_kit_inventory.css")

    assert "Manage Extra Material Catalog" in page
    assert 'id="extra-material-catalog-toggle"' in page
    assert 'id="expected-new-catalog-item"' in page
    assert 'id="extra-material-catalog-manager"' in page
    assert 'id="extra-material-catalog-search"' in page
    assert 'id="extra-material-catalog-select"' in page
    assert 'id="extra-material-catalog-name"' in page
    assert 'id="extra-material-catalog-lifecycle"' in page
    assert 'id="extra-material-catalog-uom"' in page
    assert 'id="extra-material-catalog-notes"' in page
    assert 'id="extra-material-catalog-active"' in page
    assert 'id="extra-material-new-form"' in page
    assert 'id="extra-material-new-name"' in page
    assert 'id="extra-material-new-lifecycle"' in page
    assert 'id="extra-material-new-uom"' in page

    assert "search before creating" in page
    assert "deactivate/reactivate rather than duplicating it" in page
    assert "stable catalog identity" in page
    assert "Kit-specific quantity, specification, verification, and notes remain on the Kit-content row" in page

    assert "loadAdminExtraMaterialCatalog" in review
    assert "renderExtraMaterialAdminCatalog" in review
    assert "possibleExistingExtraMaterialMatches" in review
    assert "normalizeCatalogText" in review
    assert "refreshExpectedItemCatalog" in review
    assert "openExtraMaterialCatalog('manage'" in review
    assert "openExtraMaterialCatalog('new'" in review

    assert ".catalog-manager-grid" in css
    assert ".catalog-manager-block" in css
    assert ".catalog-search-grid" in css
    assert ".catalog-edit-grid" in css
    assert ".catalog-picker-actions" in css


def test_inline_create_reuses_governed_extra_material_boundary_and_reselects_new_identity() -> None:
    review = text(BASE_DIR / "setup_kit_inventory_review.js")
    api = text(BASE_DIR / "setup_extra_material_api.py")
    repo = text(BASE_DIR / "setup_extra_material_repository.py")
    commands = text(DB_DIR / "033_add_setup_extra_material_manager_commands.sql")

    assert "'api/setup/extra-materials'" in review
    assert "catalogCommandOptions('POST'" in review
    assert "X-MSB-Setup-Command" in review
    assert "payload.extra_material?.setup_extra_material_id" in review
    assert "if (returnToExpectedDraft) await refreshExpectedItemCatalog(newId || null)" in review
    assert "openExpectedPanel('expected-qty')" in review
    assert "el('expected-uom').value = created.default_uom || 'EA'" in review

    assert '@setup_extra_material_api.post("/api/setup/extra-materials")' in api
    assert "require_setup_command()" in api
    assert "require_manager()" in api
    assert "repo().create_material" in api
    assert "ref.create_setup_extra_material" in repo
    assert "FROM ref.setup_management_actor(p_email, false)" in commands
    assert "An Extra Material with the same normalized name already exists" in commands


def test_catalog_management_uses_existing_update_boundary_for_edit_and_active_state() -> None:
    review = text(BASE_DIR / "setup_kit_inventory_review.js")
    api = text(BASE_DIR / "setup_extra_material_api.py")
    repo = text(BASE_DIR / "setup_extra_material_repository.py")

    assert "api/setup/extra-materials/${materialId}" in review
    assert "catalogCommandOptions('PATCH'" in review
    assert "active_flag: activeFlag" in review
    assert "display_order: displayOrder" in review
    assert "Existing Kit/task relationships remain attached" in review

    assert '@setup_extra_material_api.patch("/api/setup/extra-materials/<int:material_id>")' in api
    assert "repo().update_material" in api
    assert "ref.update_setup_extra_material" in repo


def test_existing_expected_row_identity_cannot_be_reinterpreted_by_catalog_creation() -> None:
    review = text(BASE_DIR / "setup_kit_inventory_review.js")

    assert "function isEditingExpectedRow()" in review
    assert "Material identity is locked" in review
    assert "if (el('expected-item')) el('expected-item').disabled = true" in review
    assert "button.hidden = !catalogState.canManage || editing" in review
    assert "mode === 'new' && isEditingExpectedRow()" in review
    assert "if (mode === 'manage') cancelExpectedWorkflowForCatalog()" in review
    assert "else if (el('expected-editor')) el('expected-editor').hidden = true" in review
    assert "catalogState.returnToExpectedDraft = mode === 'new'" in review
    assert "Expected Kit rows were left unchanged" in review
    assert "if (isEditingExpectedRow()) return" in review


def test_page_level_catalog_create_stays_in_catalog_and_inline_create_returns_to_new_row() -> None:
    review = text(BASE_DIR / "setup_kit_inventory_review.js")

    assert "const returnToExpectedDraft = catalogState.returnToExpectedDraft" in review
    assert "if (returnToExpectedDraft && exactExisting.active_flag)" in review
    assert "already exists and is now selected for this new Expected Kit row" in review
    assert "if (returnToExpectedDraft) await refreshExpectedItemCatalog(newId || null)" in review
    assert "else await refreshExpectedItemCatalog()" in review
    assert "Reusable Extra Material ${name} created in the catalog as a new identity. Expected Kit rows were left unchanged." in review


def test_remainders_are_temporary_evidence_with_a_normalization_path() -> None:
    page = text(BASE_DIR / "kit_inventory.html")
    review = text(BASE_DIR / "setup_kit_inventory_review.js")

    assert "Temporary evidence that has not yet been normalized or verified" in page
    assert "normalize it into the Extra Material catalog and Expected Kit Contents" in page
    assert 'id="normalize-remainder-item"' in page
    assert "Normalize as Extra Material…" in page
    assert "el('expected-add')?.click()" in review
    assert "queueMicrotask(() => openExtraMaterialCatalog('new', 'expected-new-catalog-item'))" in review


def test_issue_189_stays_out_of_wiring_topology_and_new_schema() -> None:
    page = text(BASE_DIR / "kit_inventory.html")
    review = text(BASE_DIR / "setup_kit_inventory_review.js")

    combined = f"{page}\n{review}".lower()
    assert "controller/channel" not in combined
    assert "wiring topology" not in combined
    assert "create table" not in combined
    assert "alter table" not in combined
