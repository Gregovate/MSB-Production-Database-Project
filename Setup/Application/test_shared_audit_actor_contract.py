from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPAIR = ROOT / "Database" / "Basic_Query_Tools_Dev" / "Repair-SetActorOnUpdate-Attribution.sql"
DB_VALIDATION = (
    ROOT / "Database" / "Acceptance" / "database_shared_audit_actor_disposable_validation.sql"
)
SETUP_VALIDATION = (
    ROOT / "Setup" / "Acceptance" / "setup_122_shared_audit_actor_disposable_validation.sql"
)


def test_database_wide_update_actor_repair_covers_both_shared_update_functions() -> None:
    sql = REPAIR.read_text(encoding="utf-8")

    assert "CREATE OR REPLACE FUNCTION ref.set_actor_on_update()" in sql
    assert "CREATE OR REPLACE FUNCTION ref.set_updated_fields()" in sql
    assert "NEW.updated_at := now();" in sql
    assert "current_user = 'directus_app'" in sql
    assert "NEW.updated_by := v_actor_name;" in sql
    assert "NEW.updated_by_person_id := v_person_id;" in sql
    assert "Audit actor resolution failed for %.% during update" in sql

    # UPDATE must never decide attribution by COALESCE against NEW because NEW
    # already contains OLD's audit values before the trigger runs.
    assert "COALESCE(NEW.updated_by, v_actor_name)" not in sql
    assert "COALESCE(NEW.updated_by_person_id, v_person_id)" not in sql


def test_database_wide_disposable_validation_covers_actor_replacement_and_directus() -> None:
    sql = DB_VALIDATION.read_text(encoding="utf-8")

    assert "Stale UPDATE audit COALESCE pattern remains in %" in sql
    assert "set_actor_on_update failed to replace prior updater" in sql
    assert "set_updated_fields failed to replace prior updater" in sql
    assert "SET LOCAL ROLE directus_app;" in sql
    assert "same-directus-actor" in sql
    assert "Native Directus same-actor payload was not preserved" in sql
    assert "ROLLBACK;" in sql
    assert "DATABASE_SHARED_AUDIT_ACTOR_DISPOSABLE_VALIDATION_PASS" in sql


def test_setup_consumer_validation_uses_browser_command_actor_path_only() -> None:
    sql = SETUP_VALIDATION.read_text(encoding="utf-8")

    assert "v_person_1" in sql
    assert "v_person_2" in sql
    assert "Second actor did not replace prior updater" in sql
    assert "Database/Acceptance/database_shared_audit_actor_disposable_validation.sql" in sql
    assert "SETUP_122_SHARED_AUDIT_BROWSER_COMMAND_VALIDATION_PASS" in sql
    assert "Explicit Directus-style audit stamp was not preserved" not in sql
