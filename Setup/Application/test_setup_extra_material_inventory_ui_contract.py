from __future__ import annotations

import ast
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_DIR = BASE_DIR.parent / "Database"
ACCEPTANCE_DIR = BASE_DIR.parent / "Acceptance"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_inventory_requires_baseline_and_cannot_go_negative() -> None:
    sql = text(DB_DIR / "035_add_setup_extra_material_inventory_commands.sql")
    assert "Initial physical count must be recorded before inventory adjustments" in sql
    assert "Initial physical count already exists; use Count Correction for later recounts" in sql
    assert "Inventory adjustment would make physical on-hand quantity negative" in sql
    assert "v_event_count=0 AND v_event_type <> 'INITIAL_COUNT'" in sql
    assert "v_event_count>0 AND v_event_type='INITIAL_COUNT'" in sql


def test_inventoried_container_identity_is_immutable() -> None:
    sql = text(DB_DIR / "034_add_setup_extra_material_container_commands.sql")
    assert "Inventoried Container material identity cannot be changed" in sql
    assert "Container material cannot be removed while physical on-hand inventory is nonzero" in sql
    for field in (
        "cem.container_id IS DISTINCT FROM p_container_id",
        "cem.setup_extra_material_id IS DISTINCT FROM p_setup_extra_material_id",
        "cem.quantity_uom IS DISTINCT FROM v_uom",
        "cem.size_text IS DISTINCT FROM v_size",
        "cem.length_value IS DISTINCT FROM p_length_value",
        "cem.length_unit IS DISTINCT FROM v_length_unit",
        "cem.color IS DISTINCT FROM v_color",
    ):
        assert field in sql


def test_unverified_items_upsert_uses_named_primary_key_constraint() -> None:
    sql = text(DB_DIR / "034_add_setup_extra_material_container_commands.sql")
    function_sql = sql.split(
        "REVOKE ALL ON FUNCTION ref.set_setup_container_extra_material", 1
    )[0]

    # Inspect only executable function definitions. The migration's final
    # pg_get_functiondef diagnostic intentionally contains the legacy text
    # inside a LIKE pattern so acceptance can prove it is absent at runtime.
    assert "ON CONFLICT ON CONSTRAINT setup_container_extra_material_review_pkey" in function_sql
    assert "ON CONFLICT (container_id)" not in function_sql
    assert "named_remainder_constraint_fix_present" in sql
    assert "ambiguous_remainder_bare_column_present" in sql


def test_remainder_upsert_is_exercised_by_disposable_acceptance() -> None:
    validation = text(ACCEPTANCE_DIR / "setup_184_remainder_upsert_disposable_validation.sql")
    launcher = text(ACCEPTANCE_DIR / "run_setup_extra_material_foundation_disposable_acceptance.ps1")
    runner = text(ACCEPTANCE_DIR / "setup_extra_material_foundation_disposable_acceptance_server.sh")

    assert "set_setup_container_unverified_items" in validation
    assert "SETUP_184_REMAINDER_UPSERT_DISPOSABLE_PASS" in validation
    assert "setup_184_remainder_upsert_disposable_validation.sql" in launcher
    assert "REMAINDER_VALIDATION" in runner
    assert 'psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" < "$REMAINDER_VALIDATION"' in runner


def test_inventory_history_uses_real_person_columns() -> None:
    repo = text(BASE_DIR / "setup_extra_material_repository.py")
    assert "p.display_name" not in repo
    assert "p.first_name" in repo
    assert "p.last_name" in repo
    assert "p.email" in repo


def test_kit_detail_does_not_require_protected_container_type_lookup() -> None:
    repo = text(BASE_DIR / "setup_extra_material_repository.py")

    # fieldwiring_app intentionally lacks broad SELECT on ref.container_type.
    # Kit detail needs only the durable ref.container.container_type_id; the
    # known Kit Box label can be presented without broadening DB privileges.
    assert "ref.container_type" not in repo
    assert "c.container_type_id" in repo
    assert "CASE WHEN c.container_type_id = 2 THEN 'Kit Box' END AS container_type_name" in repo


def test_kit_inventory_is_standalone_route_not_annual_session_workspace() -> None:
    html = text(BASE_DIR / "production.html")
    host = text(BASE_DIR / "production_backend.py")
    bridge = text(BASE_DIR / "setup_extra_materials.js")
    page = text(BASE_DIR / "kit_inventory.html")
    js = text(BASE_DIR / "setup_kit_inventory.js")
    display_js = text(BASE_DIR / "setup_kit_inventory_displays.js")
    css = text(BASE_DIR / "setup_kit_inventory.css")

    # Setup retains an entry point, but the early embedded workspace is removed
    # at runtime and the tab routes to durable Kit Inventory instead.
    assert 'data-view="extra-materials"' in html
    assert "tab.textContent = 'Kit Inventory'" in bridge
    assert "document.getElementById('extra-materials-view')?.remove()" in bridge
    assert "window.location.assign(inventoryUrl(containerId))" in bridge

    assert '@app.get("/kit-inventory")' in host
    assert '@app.get("/kit-inventory/")' in host
    assert '@app.get("/kit-inventory/<int:container_id>")' in host
    assert 'send_from_directory(BASE_DIR, "kit_inventory.html")' in host
    assert 'app.register_blueprint(setup_kit_inventory_api)' in host
    assert '"setup_kit_inventory_displays.js"' in host

    assert '<h1>Kit Inventory</h1>' in page
    assert 'id="kit-list"' in page
    assert 'id="kit-display-body"' in page
    assert 'Displays Stored in This Kit' in page
    assert 'Expected Extra Material Contents' in page
    assert 'id="kit-content-body"' in page
    assert 'id="unverified-items"' in page
    assert 'id="inventory-form"' in page
    assert 'Back to Setup Session' in page
    assert 'setup_kit_inventory_displays.js?v=' in page

    assert "api/setup/kit-inventory/kit-boxes" in js
    assert "api/setup/containers/${state.selectedContainerId}/extra-materials" in js
    assert "api/setup/container-extra-materials/${state.inventoryContentId}/inventory-events" in js
    assert "Production Crew" in js
    assert ".inventory-layout" in css

    assert "kit-inventory/kit-boxes/${containerId}/displays" in display_js
    assert "No current Display identities are assigned to this Kit Box." in display_js
    assert "row.inventory_type" in display_js


def test_permanent_inventory_ui_uses_durable_184_wording() -> None:
    html = text(BASE_DIR / "production.html")
    tpost = text(BASE_DIR / "t_post_inventory.html")

    assert "Issue #167 bolt-on" not in html
    assert "Durable Setup inventory" in html
    assert "generic preload row" not in tpost
    assert "Shared stock Containers are not Kit Boxes" in tpost


def test_setup_assignments_link_directly_to_kit_inventory() -> None:
    bridge = text(BASE_DIR / "setup_extra_materials.js")
    assert "setup-kit-box-chip[data-container-id]" in bridge
    assert "setup-kit-box-row[data-container-id]" in bridge
    assert "View Inventory" in bridge
    assert "openInventory(containerId)" in bridge


def test_manager_and_production_crew_split_is_preserved() -> None:
    js = text(BASE_DIR / "setup_kit_inventory.js")
    api = text(BASE_DIR / "setup_extra_material_api.py")

    assert "state.access?.can_manage_setup" in js
    assert "canAdjustInventory()" in js
    assert "role === 'Production Crew'" in js
    assert "policies.has('Production Crew')" in js
    assert "Volunteer" not in js

    assert "require_manager()" in api
    assert "require_inventory_operator()" in api
    assert "role_name == \"Production Crew\"" in api
    assert "role_name == \"Volunteer\"" not in api


def test_disposable_volunteer_negative_proof_excludes_elevated_accounts() -> None:
    sql = text(ACCEPTANCE_DIR / "setup_extra_material_foundation_disposable_validation.sql")

    # The denial actor must be Volunteer-only. A user who also has Production
    # Crew/Manager/Administrator authority is legitimately allowed inventory and
    # would make the negative proof a false failure.
    assert "Volunteer-only account" in sql
    assert "coalesce(r.name,'') NOT IN ('Production Crew','Manager','Administrator')" in sql
    assert "p.name IN ('Production Crew','Manager','Administrator')" in sql
    assert "Volunteer-only denial actor" in sql


def test_kit_inventory_list_reads_existing_141_assignments_and_display_contents() -> None:
    api = text(BASE_DIR / "setup_kit_inventory_api.py")
    assert "ref.setup_task_container_support" in api
    assert "tc.relationship_type = 'KIT'" in api
    assert "WHERE c.container_type_id = 2" in api
    assert "INSERT INTO ref.setup_task_container_support" not in api

    # A Kit may contain normal Production Displays. Those rows remain their own
    # authoritative physical identities and are presented read-only, separately
    # from durable Extra Material expected contents.
    assert '"/api/setup/kit-inventory/kit-boxes/<int:container_id>/displays"' in api
    assert "FROM ref.display AS d" in api
    assert "d.container_id = %s" in api
    assert "c.container_type_id = 2" in api
    assert "d.inventory_type" in api
    assert "d.lor_prop_id" in api
    assert "INSERT INTO ref.display" not in api
    assert "UPDATE ref.display" not in api


def test_inventory_browser_review_makes_edit_state_and_balance_math_explicit() -> None:
    kit_page = text(BASE_DIR / "kit_inventory.html")
    kit_review = text(BASE_DIR / "setup_kit_inventory_review.js")
    tpost_page = text(BASE_DIR / "t_post_inventory.html")
    tpost_js = text(BASE_DIR / "setup_tpost_inventory.js")
    css = text(BASE_DIR / "setup_kit_inventory.css")

    assert "Expected in Kit" in kit_page
    assert "Physical On Hand" in kit_page
    assert 'id="expected-editor-status"' in kit_page
    assert 'id="inventory-math"' in kit_page
    assert "Count correction (+/-)" in kit_page
    assert "normalizeRemainderDisplay" in kit_review
    assert "textarea.value.replace(/\\\\n/g, '\\n')" in kit_review
    assert "EDITING EXISTING ROW" in kit_review
    assert "editing-source-row" in kit_review
    assert "Current on hand:" in kit_review

    assert "Expected / Target" in tpost_page
    assert "Physical On Hand" in tpost_page
    assert 'id="tpost-editor-status"' in tpost_page
    assert 'id="tpost-inventory-math"' in tpost_page
    assert "Expected / target qty (not count)" in tpost_page
    assert "Current physical on hand:" in tpost_js
    assert "await selectInventoryRow(contentId)" in tpost_js
    assert "balanceAfter" in tpost_js
    assert "editing-source-row" in tpost_js
    assert "EDITING EXISTING ROW" in tpost_js

    assert ".editor-panel.editing" in css
    assert ".editor-banner" in css
    assert ".inventory-math" in css


def test_new_python_modules_parse() -> None:
    for name in (
        "setup_extra_material_repository.py",
        "setup_extra_material_api.py",
        "setup_kit_inventory_api.py",
        "production_backend.py",
    ):
        ast.parse(text(BASE_DIR / name), filename=name)
