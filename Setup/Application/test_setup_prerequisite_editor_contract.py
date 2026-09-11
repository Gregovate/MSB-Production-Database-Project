from __future__ import annotations

import re
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_dependency_order_migration_adds_persistent_governed_order_without_audit_backfill() -> None:
    sql = (DB_DIR / "026_add_setup_dependency_order.sql").read_text(encoding="utf-8")

    assert "ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 100" in sql
    assert "Existing audit actor/timestamps must not be rewritten" in sql
    assert "row_number() OVER" not in sql
    assert "UPDATE ref.setup_task_dependency d\nSET sort_order" not in sql
    assert "ck_setup_task_dependency_sort_order" in sql
    assert "ix_setup_task_dependency_order" in sql
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_dependency(" in sql
    assert "coalesce(max(d.sort_order), 0) + 10" in sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_task_dependency" in sql
    assert "DO UPDATE SET dependency_note = EXCLUDED.dependency_note" in sql
    assert "CREATE OR REPLACE FUNCTION ref.reorder_setup_task_dependencies(" in sql
    assert "Complete ordered prerequisite list is required" in sql
    assert "Prerequisite order contains duplicate task IDs" in sql
    assert "Prerequisite order must contain the complete current prerequisite set" in sql
    assert "ordered.ordinality::integer * 10" in sql
    assert "ORDER BY d.sort_order, pt.display_order, d.prerequisite_setup_task_id" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.reorder_setup_task_dependencies" in sql
    assert "GRANT UPDATE ON ref.setup_task_dependency" not in sql
    assert "GRANT INSERT ON ref.setup_task_dependency" not in sql


def test_ordered_prerequisite_api_and_repository_use_governed_boundaries() -> None:
    api = read_app("setup_prerequisite_order_api.py")
    repo = read_app("setup_prerequisite_order_repository.py")

    assert '@setup_prerequisite_order_api.get("/api/setup/dependencies/ordered")' in api
    assert "require_reader()" in api
    assert '@setup_prerequisite_order_api.patch("/api/setup/tasks/<int:setup_task_id>/dependencies/order")' in api
    assert "require_setup_command()" in api
    assert "require_manager()" in api
    assert "prerequisite_setup_task_ids" in api
    assert "ref.reorder_setup_task_dependencies(%s,%s,%s::bigint[])" in repo
    assert "FROM ref.setup_task_dependency d" in repo
    assert "ORDER BY d.setup_task_id" in repo
    assert "d.sort_order" in repo
    assert "pt.display_order" in repo
    assert "INSERT INTO ref.setup_task_dependency" not in repo
    assert "UPDATE ref.setup_task_dependency" not in repo
    assert "DELETE FROM ref.setup_task_dependency" not in repo


def test_canonical_editor_replaces_duplicate_presentations_and_refreshes_from_db() -> None:
    js = read_app("setup_prerequisite_editor.js")
    html = read_app("production.html")

    assert "api/setup/dependencies/ordered" in js
    assert "renderCanonicalPrerequisites" in js
    assert "renderCanonicalDependencyEditor" in js
    assert "next-prerequisite-row" in js
    assert "next-dependency-up" in js
    assert "next-dependency-down" in js
    assert "next-dependency-delete" in js
    assert "dependencies/order" in js
    assert "prerequisite_setup_task_ids" in js
    assert "await reloadTasks(null)" in js
    assert "if (fresh) selectTask(taskId)" in js
    assert "!currentIds.has" in js
    assert "All available tasks are already prerequisites" in js
    assert "next-dependency-current" not in js
    assert "Manager prerequisite correction" not in js
    assert "All listed prerequisites must be complete before this task can start" in html
    assert "setup_prerequisite_editor.js" in html
    assert "setup_prerequisite_editor.css" in html


def test_prerequisite_order_is_explicitly_review_order_not_dependency_semantics() -> None:
    js = read_app("setup_prerequisite_editor.js")
    sql = (DB_DIR / "026_add_setup_dependency_order.sql").read_text(encoding="utf-8")
    semantic_sql = " ".join(sql.split())

    assert "Use ↑ / ↓ to change review order only" in js
    assert "Every listed prerequisite is still required" in js
    assert "sort_order is presentation order only" in semantic_sql
    assert "does not create precedence between prerequisite tasks" in semantic_sql


def test_prerequisite_editor_preserves_dirty_edit_guard_selector() -> None:
    js = read_app("setup_prerequisite_editor.js")
    dirty = read_app("setup_catalog_dirty_guard.js")

    assert ".next-dependency-remove" in dirty
    assert "next-dependency-up next-dependency-remove" in js
    assert "next-dependency-down next-dependency-remove" in js
    assert "next-dependency-delete next-dependency-remove" in js


def test_prerequisite_editor_css_uses_existing_palette_only() -> None:
    css = read_app("setup_prerequisite_editor.css")
    for token in ("var(--border)", "var(--muted)"):
        assert token in css
    assert re.search(r"#[0-9a-fA-F]{3,8}\b", css) is None


def test_production_registers_prerequisite_order_api_and_assets() -> None:
    backend = read_app("production_backend.py")
    html = read_app("production.html")

    assert "from setup_prerequisite_order_api import setup_prerequisite_order_api" in backend
    assert "app.register_blueprint(setup_prerequisite_order_api)" in backend
    for asset in ("setup_prerequisite_editor.css", "setup_prerequisite_editor.js"):
        assert f'"{asset}"' in backend
        assert asset in html
