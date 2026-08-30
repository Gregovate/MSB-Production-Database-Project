/* ======================================================================
   Add ref.display -> ref.label_template relationship

   Status: REVIEWED CANDIDATE — NOT YET APPLIED TO PRODUCTION
   Subsystem: Labeling and Scanning
   Schema basis:
     Database/Schema_Snapshots/msb_production_schema-2026-08-08.sql

   Purpose:
     Give each Display an explicit governed physical label format without
     storing Brother template paths or printer details on ref.display.

   Key decision:
     ref.display stores label_template_id as an integer foreign key to
     ref.label_template(label_template_id).

   Initial assignment rule:
     Every existing Display is assigned the row whose stable code is
     DISPLAY_36MM_HORIZONTAL. Displays requiring the narrower format can then
     be deliberately changed to the DISPLAY_24MM_HORIZONTAL row.

   IMPORTANT:
     - This migration is intentionally separate from Create-LabelTemplate.sql.
     - Do not apply it merely because ref.label_template has been created.
     - Directus relationship/form/bookmark behavior and automated Display
       creation paths must be reviewed before production acceptance.
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
        FROM ref.label_template
        WHERE label_template_code = 'DISPLAY_36MM_HORIZONTAL'
          AND active_flag = true
    ) THEN
        RAISE EXCEPTION 'Required active template DISPLAY_36MM_HORIZONTAL is missing from ref.label_template';
    END IF;
END
$$;

ALTER TABLE ref.display
    ADD COLUMN label_template_id integer;

UPDATE ref.display d
SET label_template_id = lt.label_template_id
FROM ref.label_template lt
WHERE lt.label_template_code = 'DISPLAY_36MM_HORIZONTAL'
  AND d.label_template_id IS NULL;

ALTER TABLE ref.display
    ALTER COLUMN label_template_id SET NOT NULL;

COMMENT ON COLUMN ref.display.label_template_id IS
'Integer foreign key to the governed physical Display label format in ref.label_template. Existing Displays are initially assigned the DISPLAY_36MM_HORIZONTAL template.';

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_label_template
    FOREIGN KEY (label_template_id)
    REFERENCES ref.label_template(label_template_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

COMMIT;

SELECT
    d.label_template_id,
    lt.label_template_code,
    lt.label_template_name,
    COUNT(*) AS display_count
FROM ref.display d
JOIN ref.label_template lt
  ON lt.label_template_id = d.label_template_id
GROUP BY d.label_template_id, lt.label_template_code, lt.label_template_name
ORDER BY d.label_template_id;
