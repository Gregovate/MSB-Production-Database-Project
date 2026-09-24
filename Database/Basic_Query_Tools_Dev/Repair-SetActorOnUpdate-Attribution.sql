/* ============================================================================
MSB Production Database — database-wide shared UPDATE audit actor repair
Issue: #122 discovery / shared database authority
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE ACCEPTANCE REQUIRED
Revision: 2026-09-24 V0.2.0

Observed defect:
  ref.set_actor_on_update() and ref.set_updated_fields() used
  COALESCE(NEW.updated_by*, resolved_actor).

  On UPDATE, PostgreSQL NEW begins with the OLD row values. The previous updater
  is therefore already non-null and COALESCE preserves that prior actor instead
  of stamping the person performing the current update.

Database-wide authority model:
  1. Governed application commands set transaction-local app.directus_user_uuid.
     ref.resolve_actor() maps that UUID to ref.person. A resolved person is the
     authoritative actor and MUST replace the prior updater.
  2. A mapped PostgreSQL login resolved by ref.resolve_actor() is likewise
     authoritative and MUST replace the prior updater.
  3. Native Directus writes run as directus_app. The Directus audit hook stamps
     updated_by / updated_by_person_id in the payload before the database
     trigger. When no person is resolved through app.directus_user_uuid or
     pg_login_name, only directus_app may supply that explicit person stamp.
  4. Other unmapped actors fail closed on person-aware audited tables.

INSERT behavior is intentionally unchanged. ref.set_actor_on_insert() uses
COALESCE correctly because INSERT has no OLD row whose updater can be inherited.

This changes shared database audit behavior across all tables using these
functions. Do not apply to Production without disposable current-Production
validation and a separate explicit database deployment gate.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL
       OR to_regprocedure('ref.set_updated_fields()') IS NULL THEN
        RAISE EXCEPTION
            'Existing ref.resolve_actor(), ref.set_actor_on_update(), and ref.set_updated_fields() are required';
    END IF;
END
$preflight$;

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
        /*
          Governed browser commands and mapped PostgreSQL operators resolve a
          real ref.person. That current actor is authoritative and must replace
          any updater inherited from OLD.
        */
        NEW.updated_by := v_actor_name;
        IF v_has_person_id THEN
            NEW.updated_by_person_id := v_person_id;
        END IF;

    ELSIF current_user = 'directus_app' THEN
        /*
          Native Directus writes are stamped by the Directus audit hook before
          this trigger. Preserve that explicit payload stamp. This also handles
          the legitimate case where the same Directus user updates the row twice
          and the newly stamped values equal OLD.
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
        /*
          Non-person-aware legacy tables may retain a PostgreSQL actor name.
          Person-aware governed tables fail closed instead of silently carrying
          the previous updater.
        */
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

COMMIT;

SELECT
    '2026-09-24-database-wide-update-audit-attribution-v0.2.0' AS applied_revision,
    current_user AS applied_by;
