/* ============================================================================
Object group: True no-op reconciliation promotion
Repository:   Postgres_sql/Upsert Procedures/reconciliation/
Filename:     0029_enforce_true_noop_reconciliation_writes.sql
Revision:     2026-08-05-true-noop-reconciliation-writes-v2

Purpose:
  Enforce the established rule that a new ingest ID is not a production-data
  change. Unchanged stage bindings, scenes, and scene/display memberships must
  not execute UPDATE, alter audit timestamps, or create change results.

Safety boundary:
  - Installation changes procedure and trigger definitions only.
  - Installation does not call Finish, P1, P2, P3, or P4.
  - Installation does not modify existing production rows or Run 4 evidence.
  - Provenance advances only when meaningful production content changes.

Revision history:
  2026-08-05  GAL / OpenAI  Replaced indentation-sensitive function-definition
                            substitutions with verified clause-level patterns.
  2026-08-05  GAL / OpenAI  Initial correction after Run 4 exposed ingest-ID-
                            only updates to otherwise unchanged production rows.
============================================================================ */

BEGIN;

/*
  Patch only the installed procedure text known to contain the defect. Each
  guard raises if the expected definition is absent, preventing a silent or
  partial installation against an unknown database version.
*/
DO $migration$
DECLARE
    v_definition text;
    v_corrected text;
BEGIN
    SELECT pg_get_functiondef(
        'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
    ) INTO v_definition;

    v_corrected := regexp_replace(
        v_definition,
        '[[:space:]]+OR b\.last_seen_import_run_id IS DISTINCT FROM v_import_run_id',
        '',
        'g'
    );

    IF v_corrected = v_definition
       OR v_corrected LIKE '%OR b.last_seen_import_run_id IS DISTINCT FROM v_import_run_id%'
       OR v_corrected NOT LIKE '%b.source_name IS DISTINCT FROM v_binding.source_name%' THEN
        RAISE EXCEPTION '0029: expected P1 ingest-only update predicate was not found';
    END IF;

    EXECUTE v_corrected;
END;
$migration$;

DO $migration$
DECLARE
    v_definition text;
    v_corrected text;
BEGIN
    SELECT pg_get_functiondef(
        'ref.p3_promote_scene_from_reconciliation(bigint)'::regprocedure
    ) INTO v_definition;

    v_corrected := regexp_replace(
        v_definition,
        '[[:space:]]+OR ref\.lor_scene\.source_import_run_id IS DISTINCT FROM EXCLUDED\.source_import_run_id',
        '',
        'g'
    );

    IF v_corrected = v_definition
       OR v_corrected LIKE '%OR ref.lor_scene.source_import_run_id IS DISTINCT FROM EXCLUDED.source_import_run_id%'
       OR v_corrected NOT LIKE '%ref.lor_scene.create_grid_view IS DISTINCT FROM EXCLUDED.create_grid_view%' THEN
        RAISE EXCEPTION '0029: expected P3 ingest-only update predicate was not found';
    END IF;

    EXECUTE v_corrected;
END;
$migration$;

DO $migration$
DECLARE
    v_definition text;
    v_corrected text;
BEGIN
    SELECT pg_get_functiondef(
        'ref.p4_promote_scene_display_from_reconciliation(bigint)'::regprocedure
    ) INTO v_definition;

    v_corrected := regexp_replace(
        v_definition,
        '[[:space:]]+OR ref\.lor_scene_display\.source_import_run_id IS DISTINCT FROM EXCLUDED\.source_import_run_id',
        '',
        'g'
    );

    IF v_corrected = v_definition
       OR v_corrected LIKE '%OR ref.lor_scene_display.source_import_run_id IS DISTINCT FROM EXCLUDED.source_import_run_id%'
       OR v_corrected NOT LIKE '%ref.lor_scene_display.source_name IS DISTINCT FROM EXCLUDED.source_name%' THEN
        RAISE EXCEPTION '0029: expected P4 ingest-only update predicate was not found';
    END IF;

    EXECUTE v_corrected;
END;
$migration$;

DO $migration$
DECLARE
    v_definition text;
    v_corrected text;
BEGIN
    SELECT pg_get_functiondef(
        'ops.p_finish_lor_reconciliation(bigint,text)'::regprocedure
    ) INTO v_definition;

    v_corrected := regexp_replace(
        v_definition,
        '[[:space:]]+OR s\.source_import_run_id <> v_import_run_id',
        '',
        'g'
    );

    IF v_corrected = v_definition
       OR v_corrected LIKE '%OR s.source_import_run_id <> v_import_run_id%' THEN
        RAISE EXCEPTION '0029: expected Finish provenance validation was not found';
    END IF;

    EXECUTE v_corrected;
END;
$migration$;

/*
  Defense in depth: cancel an UPDATE if only mutable provenance/audit fields
  differ. Returning NULL from a BEFORE UPDATE trigger makes PostgreSQL perform
  no row update, so timestamps, row versions, and downstream audit triggers are
  untouched even if a future procedure accidentally reintroduces the defect.
*/
CREATE OR REPLACE FUNCTION ref.trg_stage_lor_binding_require_change()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.stage_id IS NOT DISTINCT FROM OLD.stage_id
       AND NEW.binding_type IS NOT DISTINCT FROM OLD.binding_type
       AND NEW.preview_id IS NOT DISTINCT FROM OLD.preview_id
       AND NEW.scene_id IS NOT DISTINCT FROM OLD.scene_id
       AND NEW.source_name IS NOT DISTINCT FROM OLD.source_name THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_stage_lor_binding_require_change
    ON ref.stage_lor_binding;
CREATE TRIGGER trg_stage_lor_binding_require_change
BEFORE UPDATE ON ref.stage_lor_binding
FOR EACH ROW EXECUTE FUNCTION ref.trg_stage_lor_binding_require_change();

CREATE OR REPLACE FUNCTION ref.trg_lor_scene_require_change()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.preview_uuid IS NOT DISTINCT FROM OLD.preview_uuid
       AND NEW.scene_uuid IS NOT DISTINCT FROM OLD.scene_uuid
       AND NEW.stage_id IS NOT DISTINCT FROM OLD.stage_id
       AND NEW.scene_name IS NOT DISTINCT FROM OLD.scene_name
       AND NEW.scene_section IS NOT DISTINCT FROM OLD.scene_section
       AND NEW.background_file IS NOT DISTINCT FROM OLD.background_file
       AND NEW.h_scroll IS NOT DISTINCT FROM OLD.h_scroll
       AND NEW.v_scroll IS NOT DISTINCT FROM OLD.v_scroll
       AND NEW.zoom IS NOT DISTINCT FROM OLD.zoom
       AND NEW.create_grid_view IS NOT DISTINCT FROM OLD.create_grid_view THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_lor_scene_require_change ON ref.lor_scene;
CREATE TRIGGER trg_lor_scene_require_change
BEFORE UPDATE ON ref.lor_scene
FOR EACH ROW EXECUTE FUNCTION ref.trg_lor_scene_require_change();

CREATE OR REPLACE FUNCTION ref.trg_lor_scene_display_require_change()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.lor_scene_id IS NOT DISTINCT FROM OLD.lor_scene_id
       AND NEW.preview_uuid IS NOT DISTINCT FROM OLD.preview_uuid
       AND NEW.display_id IS NOT DISTINCT FROM OLD.display_id
       AND NEW.scene_prop_ordinal IS NOT DISTINCT FROM OLD.scene_prop_ordinal
       AND NEW.scene_role IS NOT DISTINCT FROM OLD.scene_role
       AND NEW.source IS NOT DISTINCT FROM OLD.source THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_lor_scene_display_require_change
    ON ref.lor_scene_display;
CREATE TRIGGER trg_lor_scene_display_require_change
BEFORE UPDATE ON ref.lor_scene_display
FOR EACH ROW EXECUTE FUNCTION ref.trg_lor_scene_display_require_change();

COMMENT ON FUNCTION ref.trg_stage_lor_binding_require_change() IS
'Cancels stage/LOR binding updates when only provenance or audit fields differ.';
COMMENT ON FUNCTION ref.trg_lor_scene_require_change() IS
'Cancels LOR scene updates when only provenance or audit fields differ.';
COMMENT ON FUNCTION ref.trg_lor_scene_display_require_change() IS
'Cancels scene/display membership updates when only provenance or audit fields differ.';

COMMIT;

SELECT
    '2026-08-05-true-noop-reconciliation-writes-v2'::text
        AS installed_revision,
    to_regprocedure('ref.trg_stage_lor_binding_require_change()') IS NOT NULL
        AS has_stage_binding_noop_guard,
    to_regprocedure('ref.trg_lor_scene_require_change()') IS NOT NULL
        AS has_scene_noop_guard,
    to_regprocedure('ref.trg_lor_scene_display_require_change()') IS NOT NULL
        AS has_membership_noop_guard;
