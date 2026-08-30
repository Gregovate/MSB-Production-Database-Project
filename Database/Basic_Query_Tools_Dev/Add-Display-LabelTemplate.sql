/* ======================================================================
   Add ref.display -> ref.label_template relationship

   Status: REVIEWED CANDIDATE — NOT YET APPLIED TO PRODUCTION
   Subsystem: Labeling and Scanning
   Schema basis:
     Database/Schema_Snapshots/msb_production_schema-2026-08-08.sql

   Purpose:
     Give every Display an explicit governed physical label format without
     storing Brother template paths or printer details on ref.display.

   Directus compatibility decision:
     ref.display stores label_template_code directly and references the text
     PRIMARY KEY on ref.label_template. If Directus exposes the raw relation
     value, the operator sees a meaningful value such as
     DISPLAY_36MM_HORIZONTAL rather than an opaque numeric ID.

   Initial assignment rule:
     Every existing Display is assigned DISPLAY_36MM_HORIZONTAL.
     Displays requiring the narrower format can then be deliberately changed
     to DISPLAY_24MM_HORIZONTAL.

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
          AND column_name = 'label_template_code'
    ) THEN
        RAISE EXCEPTION 'ref.display.label_template_code already exists; stop and inspect the existing implementation';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.label_template
        WHERE label_template_code = 'DISPLAY_36MM_HORIZONTAL'
          AND active_flag = true
    ) THEN
        RAISE EXCEPTION 'Required active template DISPLAY_36MM_HORIZONTAL is missing from ref.label_template';
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
    ADD COLUMN label_template_code text
    DEFAULT 'DISPLAY_36MM_HORIZONTAL'::text
    NOT NULL;

COMMENT ON COLUMN ref.display.label_template_code IS
'Governed physical Display label format. Existing and new Displays default to DISPLAY_36MM_HORIZONTAL; approved exceptions may use another active DISPLAY template such as DISPLAY_24MM_HORIZONTAL. PRINT-SERVER paths and printer details remain owned by LabelPrintService.';

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_label_template
    FOREIGN KEY (label_template_code)
    REFERENCES ref.label_template(label_template_code)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

COMMIT;

/* ----------------------------------------------------------------------
   Post-install verification — run after COMMIT.
   ---------------------------------------------------------------------- */
SELECT
    label_template_code,
    COUNT(*) AS display_count
FROM ref.display
GROUP BY label_template_code
ORDER BY label_template_code;

SELECT
    d.display_id,
    d.display_name,
    d.label_template_code,
    lt.label_template_name,
    lt.media_width_mm,
    lt.label_orientation,
    lt.template_relative_path
FROM ref.display d
JOIN ref.label_template lt
  ON lt.label_template_code = d.label_template_code
ORDER BY d.display_id
LIMIT 25;

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
