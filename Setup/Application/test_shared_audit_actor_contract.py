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
DB_SERVER = (
    ROOT / "Database" / "Acceptance" / "database_shared_audit_actor_disposable_server.sh"
)
DB_WRAPPER = (
    ROOT / "Database" / "Acceptance" / "run_database_shared_audit_actor_disposable_acceptance.ps1"
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


def test_database_wide_repair_completes_known_legacy_audit_schema_without_backfill() -> None:
    sql = REPAIR.read_text(encoding="utf-8")

    assert "ALTER TABLE ref.task_type" in sql
    assert "ALTER TABLE ref.work_area" in sql
    assert "ALTER TABLE ops.work_order_status_history" in sql
    assert "ADD COLUMN IF NOT EXISTS created_by text" in sql
    assert "ADD COLUMN IF NOT EXISTS updated_by text" in sql
    assert "ADD COLUMN IF NOT EXISTS created_at timestamptz" in sql
    assert "ADD COLUMN IF NOT EXISTS created_by_person_id bigint" in sql
    assert "ADD COLUMN IF NOT EXISTS updated_at timestamptz" in sql
    assert "ADD COLUMN IF NOT EXISTS updated_by_person_id bigint" in sql
    assert "fk_wosh_created_by_person" in sql
    assert "fk_wosh_updated_by_person" in sql
    assert "trg_work_order_status_history_set_actor_insert" in sql

    # The approved scope is forward-only. Do not fabricate historical actors or
    # timestamps simply to fill newly added columns.
    assert "UPDATE ref.task_type" not in sql
    assert "UPDATE ref.work_area" not in sql
    assert "UPDATE ops.work_order_status_history" not in sql
    assert "No DEFAULT and no historical UPDATE are intentional" in sql


def test_policy_synchronizer_requires_complete_six_field_foundation_contract() -> None:
    sql = REPAIR.read_text(encoding="utf-8")

    assert "CREATE OR REPLACE FUNCTION ref.sync_audit_collection_policy()" in sql
    assert "has_created_at" in sql
    assert "has_created_by" in sql
    assert "has_created_by_person_id" in sql
    assert "has_updated_at" in sql
    assert "has_updated_by" in sql
    assert "has_updated_by_person_id" in sql
    assert "SELECT *" in sql
    assert "FROM ref.sync_audit_collection_policy();" in sql
    assert "Existing policy rows are not overwritten" in sql


def test_database_wide_disposable_validation_covers_contract_and_actor_replacement() -> None:
    sql = DB_VALIDATION.read_text(encoding="utf-8")

    assert "Stale UPDATE audit COALESCE pattern remains in %" in sql
    assert "p.prosrc ~* 'COALESCE[[:space:]]*[(][[:space:]]*NEW[.]updated_by'" in sql
    assert "\\\\([[:space:]]*NEW\\\\.updated_by" not in sql
    assert "Shared audit table lacks complete six-field Foundation contract" in sql
    assert "Shared UPDATE audit table lacks active update-actor policy" in sql
    assert "ops.work_order_status_history is missing shared INSERT actor trigger" in sql
    assert "ops.work_order_status_history is missing audit-person foreign keys" in sql
    assert "Audit policy synchronizer does not enforce complete six-field contract" in sql
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


def test_database_wide_disposable_runner_tests_repair_against_known_production_gaps() -> None:
    server = DB_SERVER.read_text(encoding="utf-8")
    wrapper = DB_WRAPPER.read_text(encoding="utf-8")

    assert 'PROD_CONTAINER="msb-postgres"' in server
    assert 'IMAGE="postgis/postgis:16-3.5"' in server
    assert 'NETWORK="msb-stack_default"' in server
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"' in server
    assert 'pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"' in server
    assert "cat /proc/1/comm" in server
    assert '[[ "$pid1" == "postgres" ]]' in server
    assert 'psql_test < "$CANDIDATE_WORKTREE/$MIGRATION_REL"' in server
    assert 'psql_test < "$CANDIDATE_WORKTREE/$VALIDATION_REL"' in server
    assert "fieldwiring_app" not in server
    assert "GRANTS_FILE" not in server

    # Production may contain the exact gaps this candidate is intended to
    # repair. Observe them read-only; do not fail before the disposable clone
    # receives the candidate.
    assert "Observe current Production Directus/shared-audit gaps" in server
    assert "known Directus/shared-audit gaps that this candidate must close" in server
    assert "exit 20" not in server

    assert "has_table_privilege('directus_app', s.table_oid, 'UPDATE')" in server
    assert "ref.audit_collection_policy" in server
    assert "created_by_person_id" in server
    assert "updated_by_person_id" in server
    assert "Production shared audit contract unchanged" in server
    assert "prod_audit_fingerprint" in server
    assert 'rm -rf "$SCRIPT_DIR"' in server

    assert "ssh -tt" in wrapper
    assert "ServerAliveInterval=15" in wrapper
    assert "Start-Process" not in wrapper
    assert "Tee-Object" not in wrapper
    assert "ssh -f" not in wrapper
    assert "Production access: pg_dump + SELECT only." in wrapper
