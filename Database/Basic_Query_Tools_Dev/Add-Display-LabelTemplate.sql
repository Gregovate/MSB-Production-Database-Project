/* ======================================================================
   Add optional ref.display -> ref.label_template relationship

   Status: REVIEWED CANDIDATE — NOT YET APPLIED TO PRODUCTION
   Subsystem: Labeling and Scanning
   Schema basis:
     Database/Schema_Snapshots/msb_production_schema-2026-08-08.sql

   Purpose:
     Allow an individual Display to select a governed non-default identity
     label format without storing Brother template paths or printer details
     on ref.display.

   Default compatibility rule:
     NULL label_template_id means use the current standard Display identity
     format (DISPLAY_36MM). Existing Displays therefore require no mass update
     and retain current 36 mm behavior.

   This script must run only after Create-LabelTemplate.sql has been accepted
   and ref.label_template exists.
   ====================================================================== */

BEGIN;

DO $$
BEGIN
    IF to_regclass('ref.display') IS NULL THEN
        RAISE EXCEPTION 'Required table ref.display does not exist';
    END IF;

    IF to_regclass('ref.label_template') IS NULL THEN
        RAISE EXCEPTION 'Required table ref.label_template does not exist; install/review Create-LabelTemplate.sql first';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'display'
          AND column_name = 'label_template_id'
    ) THEN
        RAISE EXCEPTION 'ref.display.label_template_id already exists; stop and inspect the existing implementation';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'ref'
          AND c.relname = 'display'
          AND t.tgname = 'trg_display_set_actor_update'
          AND NOT t.tgisinternal
    ) THEN
        RAISE EXCEPTION 'Expected ref.display update-audit trigger trg_display_set_actor_update is missing';
    END IF;
END
$$;

ALTER TABLE ref.display
    ADD COLUMN label_template_id integer;

COMMENT ON COLUMN ref.display.label_template_id IS
'Optional governed Display identity-label template. NULL preserves the current standard 36 mm Display-label behavior. Non-NULL values select an approved ref.label_template row; runtime Brother paths/printer details remain owned by LabelPrintService.';

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_label_template
    FOREIGN KEY (label_template_id)
    REFERENCES ref.label_template(label_template_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

COMMIT;

/* ----------------------------------------------------------------------
   Post-install verification — run after COMMIT.
   Existing rows should all remain NULL until deliberately assigned.
   ---------------------------------------------------------------------- */
SELECT
    COUNT(*) AS display_count,
    COUNT(label_template_id) AS explicitly_assigned_template_count,
    COUNT(*) FILTER (WHERE label_template_id IS NULL) AS default_36mm_display_count
FROM ref.display;

SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_schema AS referenced_schema,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name
 AND kcu.constraint_schema = tc.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.constraint_schema = tc.constraint_schema
WHERE tc.constraint_schema = 'ref'
  AND tc.table_name = 'display'
  AND tc.constraint_name = 'fk_display_label_template';
