from __future__ import annotations

import ast
import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_DIR = BASE_DIR.parent / "Database"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _executable_sql(path: Path) -> str:
    return re.sub(r"/\*.*?\*/", "", _text(path), flags=re.S)


def test_extra_material_migration_chain_exists_and_is_bounded() -> None:
    schema = _executable_sql(DB_DIR / "032_add_setup_extra_material_schema.sql")
    manager = _executable_sql(DB_DIR / "033_add_setup_extra_material_manager_commands.sql")
    container = _executable_sql(DB_DIR / "034_add_setup_extra_material_container_commands.sql")
    inventory = _executable_sql(DB_DIR / "035_add_setup_extra_material_inventory_commands.sql")
    seed = _executable_sql(DB_DIR / "036_seed_setup_extra_material_catalog.sql")

    assert "CREATE TABLE IF NOT EXISTS ref.setup_extra_material" in schema
    assert "CREATE TABLE IF NOT EXISTS ref.setup_task_extra_material" in schema
    assert "CREATE TABLE IF NOT EXISTS ref.setup_task_extra_material_source" in schema
    assert "CREATE TABLE IF NOT EXISTS ref.setup_container_extra_material" in schema
    assert "CREATE TABLE IF NOT EXISTS ref.setup_container_extra_material_review" in schema
    assert "CREATE TABLE IF NOT EXISTS ops.setup_extra_material_inventory_event" in schema
    assert "CREATE OR REPLACE VIEW ops.setup_extra_material_inventory_balance" in schema

    # #141 already owns task -> KIT assignment; #167 must not create another one.
    for sql in (schema, manager, container, inventory, seed):
        assert "CREATE TABLE IF NOT EXISTS ref.setup_task_container_support" not in sql
        assert "INSERT INTO ref.setup_task_container_support" not in sql
        assert "CREATE TABLE IF NOT EXISTS ops.setup_session" not in sql
        assert "INSERT INTO ops.setup_session" not in sql


def test_catalog_is_normalized_and_excludes_bad_legacy_names() -> None:
    seed = _executable_sql(DB_DIR / "036_seed_setup_extra_material_catalog.sql")

    for accepted in (
        "'T-Post'",
        "'Ball Bungee'",
        "'Standard Panel Spacer'",
        "'D-Ring'",
        "'Concrete Block'",
        "'Eye Bolt'",
        "'Velcro Cord Fastener'",
        "'Electrical Tape'",
        "'Tripple Tap'",
        "'Cribbing / Shim'",
        "'Arch Foot'",
        "'Waterproof Coupler'",
    ):
        assert accepted in seed

    for rejected in (
        "'Y-Post'",
        "'Fence Post'",
        "'Tie Strap'",
        "'PVC Distance Pipe'",
        "'Screw Anchor'",
        "'Nylon Cord'",
        "'Bull Line'",
        "'Bow Line'",
    ):
        assert rejected not in seed

    # Variant identity lives on relationship rows instead of multiplying catalog entries.
    assert "size_text text" in _text(DB_DIR / "032_add_setup_extra_material_schema.sql")
    assert "length_value numeric" in _text(DB_DIR / "032_add_setup_extra_material_schema.sql")
    assert "color text" in _text(DB_DIR / "032_add_setup_extra_material_schema.sql")


def test_expected_contents_and_inventory_are_distinct_facts() -> None:
    schema = _executable_sql(DB_DIR / "032_add_setup_extra_material_schema.sql")
    repo = _text(BASE_DIR / "setup_extra_material_repository.py")

    assert "expected_quantity numeric" in schema
    assert "quantity_delta numeric" in schema
    assert "DAMAGE_LOSS" in schema
    assert "CASE WHEN count(e.setup_extra_material_inventory_event_id) = 0 THEN NULL" in schema
    assert "required_quantity" in repo
    assert "on_hand_quantity" in repo
    assert "available_after_requirement" in repo
    assert "uncounted_stock_rows" in repo


def test_production_crew_inventory_boundary_excludes_volunteer() -> None:
    inventory = _executable_sql(DB_DIR / "035_add_setup_extra_material_inventory_commands.sql")
    api = _text(BASE_DIR / "setup_extra_material_api.py")

    assert "v_role_name='Production Crew'" in inventory
    assert "'Production Crew'=ANY(v_policy_names)" in inventory
    assert "v_role_name='Volunteer'" not in inventory
    assert "'Volunteer'=ANY(v_policy_names)" not in inventory

    assert 'role_name == "Production Crew"' in api
    assert '"Production Crew" in policy_names' in api
    assert 'role_name == "Volunteer"' not in api
    assert "require_inventory_operator()" in api
    assert "require_manager()" in api


def test_no_broad_extra_material_dml_grants() -> None:
    schema = _executable_sql(DB_DIR / "032_add_setup_extra_material_schema.sql")
    inventory = _executable_sql(DB_DIR / "035_add_setup_extra_material_inventory_commands.sql")

    assert "REVOKE INSERT, UPDATE, DELETE ON ref.setup_extra_material" in schema
    assert "REVOKE INSERT, UPDATE, DELETE ON ops.setup_extra_material_inventory_event" in schema
    assert "GRANT INSERT ON ref.setup_extra_material TO fieldwiring_app" not in schema
    assert "GRANT UPDATE ON ref.setup_extra_material TO fieldwiring_app" not in schema
    assert "GRANT INSERT ON ops.setup_extra_material_inventory_event TO fieldwiring_app" not in inventory


def test_tpost_requirement_is_task_scoped_not_display_derived() -> None:
    schema = _text(DB_DIR / "032_add_setup_extra_material_schema.sql")
    seed = _text(DB_DIR / "036_seed_setup_extra_material_catalog.sql")
    repo = _text(BASE_DIR / "setup_extra_material_repository.py")

    assert "task/installation scope" in schema
    assert "not 2 posts per Display" in schema
    assert "not 2 posts per Display" in seed
    assert "tm.setup_task_id" in repo
    assert "sum(tm.quantity_required)" in repo


def test_extra_material_python_modules_parse_and_blueprint_is_registered() -> None:
    for name in (
        "setup_extra_material_repository.py",
        "setup_extra_material_api.py",
        "production_backend.py",
    ):
        ast.parse(_text(BASE_DIR / name), filename=name)

    host = _text(BASE_DIR / "production_backend.py")
    assert "from setup_extra_material_api import setup_extra_material_api" in host
    assert "app.register_blueprint(setup_extra_material_api)" in host


def test_container_unverified_items_is_not_a_catalog_identity() -> None:
    schema = _executable_sql(DB_DIR / "032_add_setup_extra_material_schema.sql")
    container = _executable_sql(DB_DIR / "034_add_setup_extra_material_container_commands.sql")
    seed = _executable_sql(DB_DIR / "036_seed_setup_extra_material_catalog.sql")

    assert "CREATE TABLE IF NOT EXISTS ref.setup_container_extra_material_review" in schema
    assert "unverified_items_text" in schema
    assert "DELETE FROM ref.setup_container_extra_material_review" in container
    assert "'Unverified'" not in seed
