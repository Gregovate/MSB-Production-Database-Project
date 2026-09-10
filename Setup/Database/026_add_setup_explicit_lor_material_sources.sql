/* ============================================================================
MSB Setup Session — Display Setup classification + explicit LOR material sources
Issue: #122
Related: #141
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-10 V0.3.5

Purpose:
  Keep Setup work scope and Display-material source selection independent.

  ref.setup_task.stage_id / lor_scene_id:
    work scope only; never imply Display material.

  ref.setup_task_material_source:
    zero or more explicit LOR-owned material sources per reusable Setup task.
    Supported source types:
      LOR_STAGE   -> current LOR props joined to permanent Displays in Stage
      LOR_PREVIEW -> current LOR props in selected Preview joined to Displays
      LOR_SCENE   -> current ref.lor_scene_display membership

  Zero rows = no Display material.
  Current Display membership is never copied into Setup.
  Containers are derived at read time from ref.display.container_id.

Boundary:
  - No task-name inference.
  - No STAGE_REMAINDER.
  - No Google Drive/folder/marker dependency.
  - No automatic material-source backfill from task stage_id/lor_scene_id.
  - ref.setup_task_display is not changed or repurposed.
  - Task-specific component/KIT timing remains deferred to Issue #141.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.stage') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ref.lor_scene_display') IS NULL
       OR to_regclass('lor_snap.v_current_props') IS NULL
       OR to_regclass('lor_snap.v_current_previews') IS NULL THEN
        RAISE EXCEPTION 'Required Setup/LOR source objects are missing before migration 026';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_management_actor(text,boolean) is required before migration 026';
    END IF;

    IF to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing MSB actor/audit trigger functions are required before migration 026';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ref.setup_task
    ADD COLUMN IF NOT EXISTS is_display_setup_step boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN ref.setup_task.is_display_setup_step IS
    'Reusable visual/operational classification for physical Display Setup work. It does not imply or select Display material.';

CREATE TABLE IF NOT EXISTS ref.setup_task_material_source (
    setup_task_material_source_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_task_id bigint NOT NULL,
    source_type text NOT NULL,
    stage_id integer,
    preview_uuid text,
    lor_scene_id bigint,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_task_material_source_task
        FOREIGN KEY (setup_task_id)
        REFERENCES ref.setup_task(setup_task_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_setup_task_material_source_stage
        FOREIGN KEY (stage_id)
        REFERENCES ref.stage(stage_id),
    CONSTRAINT fk_setup_task_material_source_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_material_source_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_material_source_shape CHECK (
        (source_type = 'LOR_STAGE'
            AND stage_id IS NOT NULL
            AND preview_uuid IS NULL
            AND lor_scene_id IS NULL)
        OR
        (source_type = 'LOR_PREVIEW'
            AND stage_id IS NULL
            AND nullif(btrim(preview_uuid), '') IS NOT NULL
            AND lor_scene_id IS NULL)
        OR
        (source_type = 'LOR_SCENE'
            AND stage_id IS NULL
            AND preview_uuid IS NULL
            AND lor_scene_id IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_setup_task_material_source_stage
    ON ref.setup_task_material_source (setup_task_id, stage_id)
    WHERE source_type = 'LOR_STAGE';

CREATE UNIQUE INDEX IF NOT EXISTS ux_setup_task_material_source_preview
    ON ref.setup_task_material_source (setup_task_id, preview_uuid)
    WHERE source_type = 'LOR_PREVIEW';

CREATE UNIQUE INDEX IF NOT EXISTS ux_setup_task_material_source_scene
    ON ref.setup_task_material_source (setup_task_id, lor_scene_id)
    WHERE source_type = 'LOR_SCENE';

COMMENT ON TABLE ref.setup_task_material_source IS
    'Reusable Setup selection of zero or more LOR-owned material sources. Stores source identity only; current Display membership is resolved dynamically from current LOR.';
COMMENT ON COLUMN ref.setup_task_material_source.source_type IS
    'LOR_STAGE, LOR_PREVIEW, or LOR_SCENE. Independent of Setup task work scope.';
COMMENT ON COLUMN ref.setup_task_material_source.stage_id IS
    'Selected permanent Stage identity for LOR_STAGE material resolution.';
COMMENT ON COLUMN ref.setup_task_material_source.preview_uuid IS
    'Selected current LOR Preview UUID for LOR_PREVIEW material resolution. Not a foreign key because LOR snapshots are replaceable; stale selection is surfaced at read time.';
COMMENT ON COLUMN ref.setup_task_material_source.lor_scene_id IS
    'Selected current reconciled LOR Scene/programming-group identity. Not a foreign key so LOR reconciliation is not blocked by a stale Setup selection; stale selection is surfaced at read time.';

DROP TRIGGER IF EXISTS trg_setup_task_material_source_actor_insert
    ON ref.setup_task_material_source;
CREATE TRIGGER trg_setup_task_material_source_actor_insert
BEFORE INSERT ON ref.setup_task_material_source
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_task_material_source_actor_update
    ON ref.setup_task_material_source;
CREATE TRIGGER trg_setup_task_material_source_actor_update
BEFORE UPDATE ON ref.setup_task_material_source
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

CREATE OR REPLACE FUNCTION ref.set_setup_task_display_setup_step(
    p_email text,
    p_setup_task_id bigint,
    p_is_display_setup_step boolean
)
RETURNS TABLE (
    setup_task_id bigint,
    is_display_setup_step boolean,
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
    v_value boolean := coalesce(p_is_display_setup_step, false);
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.setup_task AS t
       SET is_display_setup_step = v_value
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, v_value, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_setup_task_material_source(
    p_email text,
    p_setup_task_id bigint,
    p_source_type text,
    p_source_key text,
    p_active boolean
)
RETURNS TABLE (
    setup_task_id bigint,
    source_type text,
    source_key text,
    active boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref, lor_snap
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_source_type text := upper(btrim(coalesce(p_source_type, '')));
    v_source_key text := btrim(coalesce(p_source_key, ''));
    v_active boolean := coalesce(p_active, false);
    v_stage_id integer;
    v_scene_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task AS t
        WHERE t.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    IF v_source_type NOT IN ('LOR_STAGE', 'LOR_PREVIEW', 'LOR_SCENE') THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Setup material source_type must be LOR_STAGE, LOR_PREVIEW, or LOR_SCENE';
    END IF;

    IF v_source_key = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Setup material source_key is required';
    END IF;

    IF v_source_type = 'LOR_STAGE' THEN
        IF v_source_key !~ '^[0-9]+$' THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'LOR_STAGE source_key must be a numeric stage_id';
        END IF;
        v_stage_id := v_source_key::integer;
        IF v_active AND NOT EXISTS (SELECT 1 FROM ref.stage AS s WHERE s.stage_id = v_stage_id) THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Selected Stage material source does not exist';
        END IF;
        IF v_active THEN
            INSERT INTO ref.setup_task_material_source (setup_task_id, source_type, stage_id)
            SELECT p_setup_task_id, v_source_type, v_stage_id
            WHERE NOT EXISTS (
                SELECT 1 FROM ref.setup_task_material_source AS ms
                WHERE ms.setup_task_id = p_setup_task_id
                  AND ms.source_type = v_source_type
                  AND ms.stage_id = v_stage_id
            );
        ELSE
            DELETE FROM ref.setup_task_material_source AS ms
             WHERE ms.setup_task_id = p_setup_task_id
               AND ms.source_type = v_source_type
               AND ms.stage_id = v_stage_id;
        END IF;
    ELSIF v_source_type = 'LOR_PREVIEW' THEN
        IF v_active AND NOT EXISTS (SELECT 1 FROM lor_snap.v_current_previews AS p WHERE p.id = v_source_key) THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Selected LOR Preview material source is not current';
        END IF;
        IF v_active THEN
            INSERT INTO ref.setup_task_material_source (setup_task_id, source_type, preview_uuid)
            SELECT p_setup_task_id, v_source_type, v_source_key
            WHERE NOT EXISTS (
                SELECT 1 FROM ref.setup_task_material_source AS ms
                WHERE ms.setup_task_id = p_setup_task_id
                  AND ms.source_type = v_source_type
                  AND ms.preview_uuid = v_source_key
            );
        ELSE
            DELETE FROM ref.setup_task_material_source AS ms
             WHERE ms.setup_task_id = p_setup_task_id
               AND ms.source_type = v_source_type
               AND ms.preview_uuid = v_source_key;
        END IF;
    ELSE
        IF v_source_key !~ '^[0-9]+$' THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'LOR_SCENE source_key must be a numeric lor_scene_id';
        END IF;
        v_scene_id := v_source_key::bigint;
        IF v_active AND NOT EXISTS (SELECT 1 FROM ref.lor_scene AS ls WHERE ls.lor_scene_id = v_scene_id) THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Selected LOR Scene/group material source is not current';
        END IF;
        IF v_active THEN
            INSERT INTO ref.setup_task_material_source (setup_task_id, source_type, lor_scene_id)
            SELECT p_setup_task_id, v_source_type, v_scene_id
            WHERE NOT EXISTS (
                SELECT 1 FROM ref.setup_task_material_source AS ms
                WHERE ms.setup_task_id = p_setup_task_id
                  AND ms.source_type = v_source_type
                  AND ms.lor_scene_id = v_scene_id
            );
        ELSE
            DELETE FROM ref.setup_task_material_source AS ms
             WHERE ms.setup_task_id = p_setup_task_id
               AND ms.source_type = v_source_type
               AND ms.lor_scene_id = v_scene_id;
        END IF;
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, v_source_type, v_source_key, v_active, v_display_name;
END;
$function$;

REVOKE ALL ON TABLE ref.setup_task_material_source FROM PUBLIC;
GRANT SELECT ON TABLE ref.setup_task_material_source TO fieldwiring_app;

REVOKE ALL ON FUNCTION ref.set_setup_task_display_setup_step(text, bigint, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_setup_step(text, bigint, boolean) TO fieldwiring_app;

REVOKE ALL ON FUNCTION ref.set_setup_task_material_source(text, bigint, text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_material_source(text, bigint, text, text, boolean) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-10-add-setup-explicit-lor-material-sources-v0.3.5' AS applied_revision,
    current_user AS applied_by;
