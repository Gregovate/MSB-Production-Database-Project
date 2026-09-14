from __future__ import annotations

import ast
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_kit_inventory_keeps_permanent_task_assignment_visibility_and_unassigned_filter() -> None:
    page = text(BASE_DIR / "kit_inventory.html")
    review = text(BASE_DIR / "setup_kit_inventory_review.js")
    api = text(BASE_DIR / "setup_kit_inventory_api.py")

    assert 'id="kit-filter-assigned"' in page
    assert 'id="kit-filter-unassigned"' in page
    assert 'id="kit-task-assignment-body"' in page
    assert "Setup Task Assignments" in page
    assert "Unverified Items / Remainders" in page
    assert "setup_kit_inventory_review.js?v=" in page

    assert "state.filter === 'assigned'" in review
    assert "state.filter === 'unassigned'" in review
    assert "assigned_tasks" in review
    assert "Unassigned Kit." in review

    assert "ref.setup_task_container_support" in api
    assert "tc.relationship_type = 'KIT'" in api
    assert "assigned_task_count" in api
    assert "assigned_tasks" in api
    assert "jsonb_build_object" in api


def test_tpost_stock_is_permanent_separate_inventory_surface() -> None:
    host = text(BASE_DIR / "production_backend.py")
    page = text(BASE_DIR / "t_post_inventory.html")
    js = text(BASE_DIR / "setup_tpost_inventory.js")
    clarity_js = text(BASE_DIR / "setup_tpost_inventory_clarity.js")
    api = text(BASE_DIR / "setup_kit_inventory_api.py")

    assert '@app.get("/t-post-inventory")' in host
    assert 'send_from_directory(BASE_DIR, "t_post_inventory.html")' in host
    assert '"setup_tpost_inventory.js"' in host
    assert '"setup_tpost_inventory_clarity.js"' in host
    assert "T-Post Stock Inventory" in page
    assert "Shared warehouse/field stock only" in page
    assert "does <strong>not</strong> assign T-Posts to Displays" in page
    assert "Shared Stock Variants and Current Counts" in page
    assert "Count physical stock" in page
    assert "api/setup/t-post-inventory/containers" in js
    assert "INITIAL_COUNT" in js
    assert "COUNT_CORRECTION" in js
    assert "Edit stock definition" in clarity_js
    assert "Count physical stock" in clarity_js

    assert '"/api/setup/t-post-inventory/containers"' in api
    assert "m.material_name = 'T-Post'" in api
    assert "ref.setup_container_extra_material" in api

    # #184 supplies the durable T-Post workflow only. Specific current stock
    # Containers and initial rows are supplied later by #167's one-time load.
    assert "container_id = 36" not in api
    assert "container_id = 118" not in api


def test_one_time_reconstruction_does_not_become_production_runtime() -> None:
    host = text(BASE_DIR / "production_backend.py")
    kit_page = text(BASE_DIR / "kit_inventory.html")

    assert "setup_extra_material_evidence_api" not in host
    assert "/extra-material-evidence" not in host
    assert "Evidence Explorer" not in kit_page
    assert "setup_kit_inventory_evidence.js" not in kit_page


def test_new_runtime_modules_parse() -> None:
    for name in (
        "setup_kit_inventory_api.py",
        "production_backend.py",
    ):
        ast.parse(text(BASE_DIR / name), filename=name)
