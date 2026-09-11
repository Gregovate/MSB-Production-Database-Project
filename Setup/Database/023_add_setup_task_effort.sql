/* ============================================================================
MSB Setup Session — reusable task effort metadata
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-09 V0.1.0

Purpose:
  Add the small reusable physical-effort hint accepted for Setup planning:
  LIGHT / MODERATE / HEAVY.

Boundaries:
  - This is reusable task knowledge, not an annual schedule decision.
  - NULL means not yet reviewed/known.
  - No planning-role/trailer-specific classification is introduced.
  - Scheduler ordering already exists through baseline_plan_order/planned_order.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup reusable task and management authority are required before migration 023';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task'
          AND column_name = 'baseline_plan_order'
    ) THEN
        RAISE EXCEPTION 'Migration 011 planning order must be installed before migration 023';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ref.setup_task
    ADD COLUMN IF NOT EXISTS effort_level text;

ALTER TABLE ref.setup_task
    DROP CONSTRAINT IF EXISTS ck_setup_task_effort_level;
ALTER TABLE ref.setup_task
    ADD CONSTRAINT ck_setup_task_effort_level CHECK (
        effort_level IS NULL
        OR effort_level IN ('LIGHT', 'MODERATE', 'HEAVY')
    );

CREATE OR REPLACE FUNCTION ref.set_setup_task_effort(
    p_email text,
    p_setup_task_id bigint,
    p_effort_level text
)
RETURNS TABLE (
    setup_task_id bigint,
    effort_level text,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_effort text := upper(nullif(btrim(p_effort_level), ''));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_effort IS NOT NULL
       AND v_effort NOT IN ('LIGHT', 'MODERATE', 'HEAVY') THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Setup effort must be LIGHT, MODERATE, HEAVY, or blank';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.setup_task t
       SET effort_level = v_effort
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, v_effort, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_effort(text,bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_effort(text,bigint,text) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-09-setup-task-effort-v0.1.0' AS applied_revision,
    current_user AS applied_by;
