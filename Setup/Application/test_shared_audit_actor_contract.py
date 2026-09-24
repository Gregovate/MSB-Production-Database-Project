from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPAIR = ROOT / "Database" / "Basic_Query_Tools_Dev" / "Repair-SetActorOnUpdate-Attribution.sql"
VALIDATION = ROOT / "Setup" / "Acceptance" / "setup_122_shared_audit_actor_disposable_validation.sql"


def test_shared_update_actor_repair_distinguishes_old_values_from_explicit_stamps() -> None:
    sql = REPAIR.read_text(encoding="utf-8")

    assert "CREATE OR REPLACE FUNCTION ref.set_actor_on_update()" in sql
    assert "NEW.updated_at := now();" in sql
    assert "NEW.updated_by IS NOT DISTINCT FROM OLD.updated_by" in sql
    assert "NEW.updated_by := v_actor_name;" in sql
    assert "NEW.updated_by_person_id IS NOT DISTINCT FROM OLD.updated_by_person_id" in sql
    assert "NEW.updated_by_person_id := v_person_id;" in sql
    assert "Audit actor resolution failed for %.% during update" in sql

    # The regression was caused by treating inherited OLD values as if the
    # caller had explicitly stamped them.
    assert "COALESCE(NEW.updated_by, v_actor_name)" not in sql
    assert "COALESCE(NEW.updated_by_person_id, v_person_id)" not in sql


def test_shared_update_actor_disposable_validation_covers_actor_change_and_directus_stamp() -> None:
    sql = VALIDATION.read_text(encoding="utf-8")

    assert "v_person_1" in sql
    assert "v_person_2" in sql
    assert "Second actor did not replace prior updater" in sql
    assert "Explicit Directus-style audit stamp was not preserved" in sql
    assert "ROLLBACK;" in sql
    assert "SETUP_122_SHARED_AUDIT_ACTOR_DISPOSABLE_VALIDATION_PASS" in sql
