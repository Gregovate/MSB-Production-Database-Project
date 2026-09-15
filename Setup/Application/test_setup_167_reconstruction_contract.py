from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_DIR = BASE_DIR.parent / "Database"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_167_is_one_time_data_load_not_permanent_schema_or_runtime() -> None:
    preload = text(DB_DIR / "038_preload_setup_extra_material_known_evidence.sql")
    kit_load = text(DB_DIR / "043_preload_setup_kit_inventory_and_tpost_stock.sql")
    elf_tpost = text(DB_DIR / "044_preload_elf_choir_tpost_requirement.sql")
    explicit_tposts = text(DB_DIR / "046_preload_explicit_tpost_requirements.sql")
    assigned_kit_inventory = text(DB_DIR / "047_finalize_assigned_kit_inventory_coverage.sql")
    final_tposts = text(DB_DIR / "048_complete_tpost_requirements_and_stock_variants.sql")

    for sql in (
        preload,
        kit_load,
        elf_tpost,
        explicit_tposts,
        assigned_kit_inventory,
        final_tposts,
    ):
        assert "CREATE TABLE" not in sql
        assert "ALTER TABLE" not in sql
        assert "CREATE OR REPLACE FUNCTION" not in sql
        assert "INSERT INTO ops.setup_session" not in sql
        assert "INSERT INTO ops.setup_extra_material_inventory_event" not in sql
        assert "INSERT INTO ref.setup_task_container_support" not in sql

    assert "verification_state" in preload
    assert "'UNVERIFIED'" in preload
    assert "Procedure-derived Kit preload v6." in kit_load
    assert "[#167 PROCEDURE REMAINDERS v6]" in kit_load


def test_167_preserves_task_requirements_and_known_quantities_without_guessing() -> None:
    preload = text(DB_DIR / "038_preload_setup_extra_material_known_evidence.sql")

    assert "Missing counts stay NULL, not zero" in preload
    assert "(73, 'Ratchet Strap', 3" in preload
    assert "(1, 'Foam Noodle', 4" in preload
    assert "(205, 'Arch Foot Pad', 6" in preload
    assert "(60, 'Post Base', 8" in preload
    assert "Expected 23 normalized task preload rows" in preload


def test_167_initial_tpost_reconciliation_moves_generic_stock_out_of_legacy_kits() -> None:
    kit_load = text(DB_DIR / "043_preload_setup_kit_inventory_and_tpost_stock.sql")

    assert "T-Posts are NOT loaded as Kit contents" in kit_load
    assert "container_id=36" in kit_load
    assert "container_id=118" in kit_load
    assert "r.setup_extra_material_id <>" in kit_load
    assert "material_name='T-Post'" in kit_load
    assert "Procedure says C072 carried extra T-Posts" in kit_load
    assert "Procedure preload incorrectly placed T-Post stock inside a Kit" in kit_load


def test_167_migration_keeps_remainders_and_loads_useful_normalized_kit_rows() -> None:
    kit_load = text(DB_DIR / "043_preload_setup_kit_inventory_and_tpost_stock.sql")

    assert "Expected at least 60 normalized Kit-content preload rows" in kit_load
    assert "(60, 'Ball Bungee'" in kit_load
    assert "(60, 'Post Base'" in kit_load
    assert "(76, 'Arch Foot'" in kit_load
    assert "(59, 'Foam Noodle'" in kit_load
    assert "ON CONFLICT (container_id)" in kit_load
    assert "[#167 PROCEDURE REMAINDERS v6]" in kit_load


def test_167_elf_choir_tpost_requirement_is_task_fact_with_separate_stock_source() -> None:
    sql = text(DB_DIR / "044_preload_elf_choir_tpost_requirement.sql")

    assert "setup_task_id=16" in sql
    assert "Install Notes and Conductor" in sql
    assert "18 Note panels + 2 Conductor panels" in sql
    assert "20 T-Posts" in sql
    assert "20," in sql
    assert "'EA'" in sql
    assert "length/height is not stated and remains unresolved" in sql
    assert "'UNVERIFIED'" in sql
    assert "container_id=36" in sql
    assert "source_expected_quantity" in sql
    assert "Container 36" in sql
    assert "container_id=118" not in sql


def test_167_explicit_tpost_preload_uses_task_scope_and_preserves_conflicts() -> None:
    sql = text(DB_DIR / "046_preload_explicit_tpost_requirements.sql")

    for task_id in (1, 65, 109, 112, 132, 200):
        assert f"({task_id}::bigint" in sql

    assert "procedure conflicts between 5 ft and 6 ft" in sql
    assert "Front Entrance Panels subsection: 5 x 5-ft" in sql
    assert "Front Entrance Panels subsection: 3 x 6-ft" in sql
    assert "03-Welcome Area-WA Setup procedure: 6 x 5-ft" in sql
    assert "6 x 5-ft T-Posts" in sql
    assert "8 x nominal 6-ft T-Posts" in sql
    assert "4 x 8-ft T-Posts" in sql
    assert "11-Sledders-SL REV 202607" in sql
    assert "explicit terrain/layout exception total" in sql
    assert "64 shortened fence/T-Posts" in sql
    assert "'shortened stock'" in sql
    assert "INSERT INTO ref.setup_task_extra_material_source" in sql
    assert "Expected 12 explicit T-Post requirement preload rows" in sql


def test_167_kit_assignment_step_preserves_current_production_authority() -> None:
    sql = text(DB_DIR / "045_preload_reviewed_kit_assignments.sql")

    assert "Managers subsequently completed the real reusable task -> KIT assignments" in sql
    assert "authoritative operator record" in sql
    assert "this migration MUST NOT insert, update, or delete task -> KIT assignments" in sql
    assert "relationship_type='KIT'" in sql
    assert "container_type_id <> 2" in sql
    assert "missing/inactive/unscoped reusable tasks" in sql
    assert "Read-only evidence of the authoritative current Production KIT assignments" in sql

    assert "INSERT INTO ref.setup_task_container_support" not in sql
    assert "UPDATE ref.setup_task_container_support" not in sql
    assert "DELETE FROM ref.setup_task_container_support" not in sql
    assert "Initial Kit assignment reviewed in disposable reconstruction workbench." not in sql
    assert "(25,58)" not in sql.replace(" ", "")
    assert "(123,66)" not in sql.replace(" ", "")
    assert "(141,61)" not in sql.replace(" ", "")
    assert "(141,62)" not in sql.replace(" ", "")
    assert "(178,68)" not in sql.replace(" ", "")
    assert "(190,79)" not in sql.replace(" ", "")
    assert "INSERT INTO ops.setup_session" not in sql
    assert "INSERT INTO ops.setup_extra_material_inventory_event" not in sql


def test_167_assignment_driven_kit_inventory_closes_coverage_without_guessing() -> None:
    sql = text(DB_DIR / "047_finalize_assigned_kit_inventory_coverage.sql")

    assert "Current Container 63 is Fred Stars" in sql
    assert "Container 74 description: Festive Tree Eastside Cords" in sql
    assert "Container 75 description: Festive Tree Westside Cords" in sql
    assert "Traditional Kit C105 includes 3 x 4x4 blocking" in sql
    assert "Traditional Kit C105 includes 2 x 2x6 blocking" in sql
    assert "VALUES (123),(124),(125),(128)" in sql
    assert "Misc Size Spacers" in sql
    assert "unknown does not mean empty" in sql
    assert "[#167 ASSIGNED KIT COVERAGE]" in sql
    assert "INSERT INTO ops.setup_extra_material_inventory_event" not in sql
    assert "INSERT INTO ops.setup_session" not in sql


def test_167_final_tpost_completion_supports_shared_stock_and_explicit_kit_exceptions() -> None:
    sql = text(DB_DIR / "048_complete_tpost_requirements_and_stock_variants.sql")

    assert "VALUES (5::numeric),(6::numeric),(7::numeric),(8::numeric)" in sql
    assert "[#167 TPOST STOCK SPLIT]" in sql
    assert "Container 118 special short T-Post stock row is missing" in sql

    assert "(58, NULL::numeric" in sql
    assert "(105, 2::numeric" in sql
    assert "(145, 3::numeric" in sql
    assert "(146, 4::numeric" in sql
    assert "(146, 9::numeric" in sql

    for task_id in (127, 147, 160, 173, 194):
        assert f"({task_id}::bigint" in sql

    assert "195::bigint,20::numeric" in sql
    assert "210,4,'EXACT'" in sql
    assert "73,2,'MINIMUM'" in sql
    assert "136,6,'EXACT'" in sql
    assert "136,16,'EXACT'" in sql
    assert "13-Polar Express" in sql
    assert "13-Christmas Story" in sql
    assert "13-Christmas With the Kranks" in sql
    assert "Setup Polar Express (Grover Train)" in sql
    assert "Install Christmas Story panels" in sql
    assert "Setup Flick and Flagpole" in sql
    assert "Kranks VW Setup" in sql
    assert "Santa''s Station exterior setup" in sql

    assert "5-ft detail vs 6-ft summary conflict" in sql
    assert "7-ft detail vs 8-ft summary conflict" in sql
    assert "5-ft summary vs 6-ft detail conflict" in sql
    assert "7-ft cell vs 8-ft note/summary conflict" in sql
    assert "two-post source gap remains reviewable" in sql

    assert "Expected 14 final T-Post requirement rows" in sql
    assert "INSERT INTO ops.setup_extra_material_inventory_event" not in sql
    assert "INSERT INTO ops.setup_session" not in sql
    assert "INSERT INTO ref.setup_task_container_support" not in sql
