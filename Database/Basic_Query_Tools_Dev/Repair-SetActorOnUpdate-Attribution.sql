/* ============================================================================
MSB Production Database — database-wide audit contract repair
Issue: #122 discovery / shared database authority
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE ACCEPTANCE REQUIRED
Revision: 2026-09-24 V0.3.0

Observed defects:
  1. ref.set_actor_on_update() and ref.set_updated_fields() used
     COALESCE(NEW.updated_by*, resolved_actor). On UPDATE, PostgreSQL NEW already
     carries OLD audit values, so the prior updater could remain forever.
  2. Newer Setup and Controller tables were audit-capable but were not enrolled
     in ref.audit_collection_policy, so the Directus actor hook skipped them.
  3. Three older mutable tables have incomplete standard audit columns:
       ops.work_order_status_history
       ref.task_type
       ref.work_area

Foundation contract:
  Mutable MSB business tables using the shared audit system carry:
    created_at
    created_by
    created_by_person_id
    updated_at
    updated_by
    updated_by_person_id

Forward-only correction:
  Existing historical audit values are not reconstructed or rewritten by this
  repair. Missing columns are added nullable with no default/backfill. Normal
  INSERT/UPDATE trigger behavior populates them on future writes.

Database-wide authority model:
  1. Governed application commands set transaction-local app.directus_user_uuid.
     ref.resolve_actor() maps that UUID to ref.person. A resolved person is the
     authoritative actor and MUST replace the prior updater.
  2. A mapped PostgreSQL login resolved by ref.resolve_actor() is likewise
     authoritative and MUST replace the prior updater.
  3. Native Directus writes run as directus_app. The Directus audit hook stamps
     updated_by / updated_by_person_id before the database trigger. When no
     person is resolved through app.directus_user_uuid or pg_login_name, only
     directus_app may supply that explicit person stamp.
  4. Other unmapped actors fail closed on person-aware UPDATE-audited tables.

INSERT behavior is intentionally not rewritten here. ref.set_actor_on_insert()
uses COALESCE correctly because INSERT has no OLD row whose updater can be
inherited.

Do not apply to Production without disposable current-Production validation
and a separate explicit database deployment gate.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.person') IS NULL
       OR to_regclass('ref.audit_collection_policy') IS NULL
       OR to_regclass('ref.task_type') IS NULL
       OR to_regclass('ref.work_area') IS NULL
       OR to_regclass('ops.work_order_status_history') IS NULL THEN
        RAISE EXCEPTION 'Required shared audit repair tables are missing';
    END IF;

    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL
       OR to_regprocedure('ref.set_updated_fields()') IS NULL
       OR to_regprocedure('ref.sync_audit_collection_policy()') IS NULL THEN
        RAISE EXCEPTION
            'Required shared audit functions are missing';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   Complete known legacy audit-column gaps without rewriting history.
   No DEFAULT and no historical UPDATE are intentional.
   -------------------------------------------------------------------------- */

ALTER TABLE ref.task_type
    ADD COLUMN IF NOT EXISTS created_by text,
    ADD COLUMN IF NOT EXISTS updated_by text;

ALTER TABLE ref.work_area
    ADD COLUMN IF NOT EXISTS created_by text,
    ADD COLUMN IF NOT EXISTS updated_by text;

ALTER TABLE ops.work_order_status_history
    ADD COLUMN IF NOT EXISTS created_at timestamptz,
    ADD COLUMN IF NOT EXISTS created_by text,
    ADD COLUMN IF NOT EXISTS created_by_person_id bigint,
    ADD COLUMN IF NOT EXISTS updated_at timestamptz,
    ADD COLUMN IF NOT EXISTS updated_by text,
    ADD COLUMN IF NOT EXISTS updated_by_person_id bigint;

DO $constraints$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'ops.work_order_status_history'::regclass
          AND conname = 'fk_wosh_created_by_person'
    ) THEN
        ALTER TABLE ops.work_order_status_history
            ADD CONSTRAINT fk_wosh_created_by_person
            FOREIGN KEY (created_by_person_id)
            REFERENCES ref.person(person_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'ops.work_order_status_history'::regclass
          AND conname = 'fk_wosh_updated_by_person'
    ) THEN
        ALTER TABLE ops.work_order_status_history
            ADD CONSTRAINT fk_wosh_updated_by_person
            FOREIGN KEY (updated_by_person_id)
            REFERENCES ref.person(person_id);
    END IF;
END
$constraints$;

DROP TRIGGER IF EXISTS trg_work_order_status_history_set_actor_insert
    ON ops.work_order_status_history;

CREATE TRIGGER trg_work_order_status_history_set_actor_insert
BEFORE INSERT ON ops.work_order_status_history
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_insert();

/* --------------------------------------------------------------------------
   Make the existing policy synchronizer enforce the complete Foundation audit
   shape. It remains insert-only for missing policy rows and does not override
   an existing policy decision.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.sync_audit_collection_policy()
RETURNS TABLE (
    action_taken text,
    schema_name text,
    collection_name text,
    checked_actor_enabled boolean
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH base_tables AS (
        SELECT
            t.table_schema,
            t.table_name
        FROM information_schema.tables AS t
        WHERE t.table_type = 'BASE TABLE'
          AND t.table_schema IN ('ref', 'ops', 'stage')
    ),
    audit_columns AS (
        SELECT
            c.table_schema,
            c.table_name,
            bool_or(c.column_name = 'created_at')            AS has_created_at,
            bool_or(c.column_name = 'created_by')            AS has_created_by,
            bool_or(c.column_name = 'created_by_person_id')  AS has_created_by_person_id,
            bool_or(c.column_name = 'updated_at')            AS has_updated_at,
            bool_or(c.column_name = 'updated_by')            AS has_updated_by,
            bool_or(c.column_name = 'updated_by_person_id')  AS has_updated_by_person_id,
            bool_or(c.column_name = 'checked_by')            AS has_checked_by,
            bool_or(c.column_name = 'checked_by_person_id')  AS has_checked_by_person_id
        FROM information_schema.columns AS c
        WHERE c.table_schema IN ('ref', 'ops', 'stage')
        GROUP BY c.table_schema, c.table_name
    ),
    eligible_tables AS (
        SELECT
            bt.table_schema,
            bt.table_name,
            ac.has_checked_by,
            ac.has_checked_by_person_id
        FROM base_tables AS bt
        JOIN audit_columns AS ac
          ON ac.table_schema = bt.table_schema
         AND ac.table_name = bt.table_name
        WHERE ac.has_created_at
          AND ac.has_created_by
          AND ac.has_created_by_person_id
          AND ac.has_updated_at
          AND ac.has_updated_by
          AND ac.has_updated_by_person_id
    ),
    inserted_rows AS (
        INSERT INTO ref.audit_collection_policy (
            schema_name,
            collection_name,
            insert_actor_enabled,
            update_actor_enabled,
            checked_actor_enabled,
            active_flag,
            notes
        )
        SELECT
            e.table_schema,
            e.table_name,
            true,
            true,
            (e.has_checked_by AND e.has_checked_by_person_id),
            true,
            'Auto-added by ref.sync_audit_collection_policy()'
        FROM eligible_tables AS e
        WHERE NOT EXISTS (
            SELECT 1
            FROM ref.audit_collection_policy AS p
            WHERE p.schema_name = e.table_schema
              AND p.collection_name = e.table_name
        )
        RETURNING
            'INSERTED'::text,
            ref.audit_collection_policy.schema_name,
            ref.audit_collection_policy.collection_name,
            ref.audit_collection_policy.checked_actor_enabled
    )
    SELECT *
    FROM inserted_rows
    ORDER BY 2, 3;
END;
$function$;

COMMENT ON FUNCTION ref.sync_audit_collection_policy() IS
'Database Foundation audit-policy synchronizer. Missing policy rows are added only for ref/ops/stage base tables that contain the complete standard audit contract: created_at, created_by, created_by_person_id, updated_at, updated_by, updated_by_person_id. Existing policy rows are not overwritten.';

/* --------------------------------------------------------------------------
   Correct shared UPDATE attribution.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.set_actor_on_update()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id integer;
    v_actor_name text;
    v_has_person_id boolean;
BEGIN
    SELECT person_id, actor_name
      INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.updated_at := now();
    v_has_person_id := to_jsonb(NEW) ? 'updated_by_person_id';

    IF v_person_id IS NOT NULL THEN
        NEW.updated_by := v_actor_name;

        IF v_has_person_id THEN
            NEW.updated_by_person_id := v_person_id;
        END IF;

    ELSIF current_user = 'directus_app' THEN
        /*
          Native Directus writes are stamped by the Directus actor hook before
          this trigger. Preserve that explicit payload stamp, including a repeat
          update by the same person where the new actor equals OLD.
        */
        IF nullif(btrim(NEW.updated_by), '') IS NULL THEN
            RAISE EXCEPTION
                'Directus audit actor text was not stamped for %.% during update',
                TG_TABLE_SCHEMA,
                TG_TABLE_NAME;
        END IF;

        IF v_has_person_id THEN
            IF NEW.updated_by_person_id IS NULL
               OR NOT EXISTS (
                    SELECT 1
                    FROM ref.person AS p
                    WHERE p.person_id = NEW.updated_by_person_id
               ) THEN
                RAISE EXCEPTION
                    'Directus audit person was not validly stamped for %.% during update',
                    TG_TABLE_SCHEMA,
                    TG_TABLE_NAME;
            END IF;
        END IF;

    ELSE
        NEW.updated_by := v_actor_name;

        IF v_has_person_id THEN
            RAISE EXCEPTION
                'Audit actor resolution failed for %.% during update',
                TG_TABLE_SCHEMA,
                TG_TABLE_NAME;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_updated_fields()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    SELECT person_id, actor_name
      INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.updated_at := now();

    IF v_person_id IS NOT NULL THEN
        NEW.updated_by := v_actor_name;
        NEW.updated_by_person_id := v_person_id;

    ELSIF current_user = 'directus_app' THEN
        IF nullif(btrim(NEW.updated_by), '') IS NULL
           OR NEW.updated_by_person_id IS NULL
           OR NOT EXISTS (
                SELECT 1
                FROM ref.person AS p
                WHERE p.person_id = NEW.updated_by_person_id
           ) THEN
            RAISE EXCEPTION
                'Directus audit actor was not validly stamped for %.% during update',
                TG_TABLE_SCHEMA,
                TG_TABLE_NAME;
        END IF;

    ELSE
        RAISE EXCEPTION
            'Audit actor resolution failed for %.% during update',
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$function$;

/* Enroll every newly audit-capable table through the existing shared registry. */
SELECT *
FROM ref.sync_audit_collection_policy();

COMMIT;

SELECT
    '2026-09-24-database-wide-audit-contract-v0.3.0' AS applied_revision,
    current_user AS applied_by;
