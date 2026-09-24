/* ============================================================================
MSB Production Database — shared audit actor update repair
Issue: #122 discovery / shared database authority
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE ACCEPTANCE REQUIRED
Revision: 2026-09-24 V0.1.0

Observed defect:
  ref.set_actor_on_update() used COALESCE(NEW.updated_by*, resolved_actor).
  On UPDATE, PostgreSQL NEW begins with the OLD row values, so the previous
  updater is already non-null and is preserved forever.

Required behavior:
  - updated_at always reflects the current UPDATE;
  - if an upstream system such as Directus explicitly changed updated_by /
    updated_by_person_id for this UPDATE, preserve those changed values;
  - otherwise stamp the actor returned by ref.resolve_actor();
  - fail closed when a table has updated_by_person_id and no person can be
    resolved/stamped.

This is a shared audit function used by multiple subsystems. Do not apply to
Production without disposable validation and explicit deployment approval.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION
            'Existing ref.resolve_actor() / ref.set_actor_on_update() are required';
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

    /*
      PostgreSQL NEW inherits OLD values before a BEFORE UPDATE trigger runs.
      Preserve updated_by only when the caller actually changed it during this
      UPDATE; otherwise stamp the currently resolved actor.
    */
    IF NEW.updated_by IS NOT DISTINCT FROM OLD.updated_by THEN
        NEW.updated_by := v_actor_name;
    END IF;

    v_has_person_id := to_jsonb(NEW) ? 'updated_by_person_id';

    IF v_has_person_id THEN
        /*
          Directus explicitly stamps this field when it owns the actor context.
          Preserve an actually changed value; do not mistake OLD's carried value
          for an explicit stamp.
        */
        IF NEW.updated_by_person_id IS NOT DISTINCT FROM OLD.updated_by_person_id THEN
            NEW.updated_by_person_id := v_person_id;
        END IF;

        IF NEW.updated_by_person_id IS NULL THEN
            RAISE EXCEPTION
                'Audit actor resolution failed for %.% during update',
                TG_TABLE_SCHEMA,
                TG_TABLE_NAME;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

COMMIT;

SELECT
    '2026-09-24-shared-audit-update-attribution-v0.1.0' AS applied_revision,
    current_user AS applied_by;
