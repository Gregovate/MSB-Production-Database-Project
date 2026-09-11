/* ============================================================================
MSB Setup Session — persistent prerequisite review order
Issue: #151
Status: PRODUCTION CANDIDATE — REVIEW BEFORE APPLY
Revision: 2026-09-11 V0.3.9

Purpose:
  Give each reusable Setup task dependency a persistent display/review order so
  Managers can arrange multiple prerequisites without changing dependency
  meaning. All listed prerequisites remain required; sort_order is presentation
  order only and does not create precedence between prerequisite tasks.

Behavior:
  - existing dependencies are backfilled deterministically using the current
    prerequisite task Catalog display order;
  - new dependencies append to the dependent task's current prerequisite list;
  - the existing governed dependency command keeps its signature and cycle
    protection;
  - a new governed reorder command atomically renumbers the complete prerequisite
    set for one dependent task;
  - no broad table DML is granted to fieldwiring_app.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_dependency') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_task_dependency is required before migration 026';
    END IF;
    IF to_regprocedure('ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup prerequisite command is required before migration 026';
    END IF;
    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup management authorization function is required before migration 026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ref.setup_task_dependency
    ADD COLUMN IF NOT EXISTS sort_order integer;

WITH ranked AS (
    SELECT d.setup_task_id,
           d.prerequisite_setup_task_id,
           row_number() OVER (
               PARTITION BY d.setup_task_id
               ORDER BY pt.display_order, pt.setup_task_id
           ) * 10 AS desired_order
    FROM ref.setup_task_dependency d
    JOIN ref.setup_task pt
      ON pt.setup_task_id = d.prerequisite_setup_task_id
)
UPDATE ref.setup_task_dependency d
SET sort_order = ranked.desired_order
FROM ranked
WHERE d.setup_task_id = ranked.setup_task_id
  AND d.prerequisite_setup_task_id = ranked.prerequisite_setup_task_id
  AND d.sort_order IS NULL;

ALTER TABLE ref.setup_task_dependency
    ALTER COLUMN sort_order SET DEFAULT 100,
    ALTER COLUMN sort_order SET NOT NULL;

DO $constraint$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_setup_task_dependency_sort_order'
          AND conrelid = 'ref.setup_task_dependency'::regclass
    ) THEN
        ALTER TABLE ref.setup_task_dependency
            ADD CONSTRAINT ck_setup_task_dependency_sort_order
            CHECK (sort_order >= 0);
    END IF;
END
$constraint$;

CREATE INDEX IF NOT EXISTS ix_setup_task_dependency_order
    ON ref.setup_task_dependency(setup_task_id, sort_order, prerequisite_setup_task_id);

CREATE OR REPLACE FUNCTION ref.set_setup_task_dependency(
    p_email text,
    p_setup_task_id bigint,
    p_prerequisite_setup_task_id bigint,
    p_dependency_note text,
    p_active boolean DEFAULT true
)
RETURNS TABLE (
    setup_task_id bigint,
    prerequisite_setup_task_id bigint,
    active boolean,
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
    v_next_sort_order integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id = p_prerequisite_setup_task_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'A Setup task cannot depend on itself';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_prerequisite_setup_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup task or prerequisite was not found';
    END IF;

    IF coalesce(p_active, true) THEN
        IF EXISTS (
            WITH RECURSIVE prerequisite_chain(setup_task_id) AS (
                SELECT d.prerequisite_setup_task_id
                FROM ref.setup_task_dependency d
                WHERE d.setup_task_id = p_prerequisite_setup_task_id
                UNION
                SELECT d.prerequisite_setup_task_id
                FROM ref.setup_task_dependency d
                JOIN prerequisite_chain c
                  ON d.setup_task_id = c.setup_task_id
            )
            SELECT 1
            FROM prerequisite_chain c
            WHERE c.setup_task_id = p_setup_task_id
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                MESSAGE = 'Prerequisite would create a circular Setup dependency';
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF coalesce(p_active, true) THEN
        SELECT coalesce(max(d.sort_order), 0) + 10
          INTO v_next_sort_order
        FROM ref.setup_task_dependency d
        WHERE d.setup_task_id = p_setup_task_id;

        INSERT INTO ref.setup_task_dependency(
            setup_task_id,
            prerequisite_setup_task_id,
            dependency_note,
            sort_order
        ) VALUES (
            p_setup_task_id,
            p_prerequisite_setup_task_id,
            nullif(btrim(p_dependency_note), ''),
            v_next_sort_order
        )
        ON CONFLICT ON CONSTRAINT pk_setup_task_dependency
        DO UPDATE SET dependency_note = EXCLUDED.dependency_note;
    ELSE
        DELETE FROM ref.setup_task_dependency d
        WHERE d.setup_task_id = p_setup_task_id
          AND d.prerequisite_setup_task_id = p_prerequisite_setup_task_id;
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id,
           p_prerequisite_setup_task_id,
           coalesce(p_active, true),
           v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.reorder_setup_task_dependencies(
    p_email text,
    p_setup_task_id bigint,
    p_prerequisite_setup_task_ids bigint[]
)
RETURNS TABLE (
    setup_task_id bigint,
    prerequisite_setup_task_id bigint,
    sort_order integer,
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
    v_existing_count integer;
    v_requested_count integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    IF p_prerequisite_setup_task_ids IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Complete ordered prerequisite list is required';
    END IF;

    SELECT count(*) INTO v_existing_count
    FROM ref.setup_task_dependency d
    WHERE d.setup_task_id = p_setup_task_id;

    v_requested_count := cardinality(p_prerequisite_setup_task_ids);

    IF v_requested_count <> (
        SELECT count(DISTINCT x.id)
        FROM unnest(p_prerequisite_setup_task_ids) AS x(id)
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Prerequisite order contains duplicate task IDs';
    END IF;

    IF v_existing_count <> v_requested_count
       OR EXISTS (
            SELECT d.prerequisite_setup_task_id
            FROM ref.setup_task_dependency d
            WHERE d.setup_task_id = p_setup_task_id
            EXCEPT
            SELECT x.id FROM unnest(p_prerequisite_setup_task_ids) AS x(id)
       )
       OR EXISTS (
            SELECT x.id FROM unnest(p_prerequisite_setup_task_ids) AS x(id)
            EXCEPT
            SELECT d.prerequisite_setup_task_id
            FROM ref.setup_task_dependency d
            WHERE d.setup_task_id = p_setup_task_id
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Prerequisite order must contain the complete current prerequisite set';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.setup_task_dependency d
    SET sort_order = ordered.ordinality::integer * 10
    FROM unnest(p_prerequisite_setup_task_ids) WITH ORDINALITY AS ordered(prerequisite_id, ordinality)
    WHERE d.setup_task_id = p_setup_task_id
      AND d.prerequisite_setup_task_id = ordered.prerequisite_id;

    RETURN QUERY
    SELECT d.setup_task_id,
           d.prerequisite_setup_task_id,
           d.sort_order,
           v_display_name
    FROM ref.setup_task_dependency d
    WHERE d.setup_task_id = p_setup_task_id
    ORDER BY d.sort_order, d.prerequisite_setup_task_id;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_dependency(
    text,bigint,bigint,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_dependency(
    text,bigint,bigint,text,boolean
) TO fieldwiring_app;

REVOKE ALL ON FUNCTION ref.reorder_setup_task_dependencies(
    text,bigint,bigint[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.reorder_setup_task_dependencies(
    text,bigint,bigint[]
) TO fieldwiring_app;

COMMIT;
