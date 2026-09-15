/* MSB Setup #167 — prevent duplicate active Extra Material/spec relationships.
   REVIEW BEFORE PRODUCTION. */
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Migration 032 Extra Material schema is required first';
    END IF;
END
$preflight$;

/* Multiple variants of one catalog family are allowed, but the same normalized
   material/specification may appear only once as an active requirement on one
   reusable Setup task. */
CREATE UNIQUE INDEX IF NOT EXISTS uq_setup_task_extra_material_active_spec
ON ref.setup_task_extra_material(
    setup_task_id,
    setup_extra_material_id,
    quantity_uom,
    coalesce(lower(btrim(size_text)), ''),
    coalesce(length_value, -1::numeric),
    coalesce(length_unit, ''),
    coalesce(lower(btrim(color)), '')
)
WHERE active_flag;

/* One active allocation from one requirement to one physical Container. */
CREATE UNIQUE INDEX IF NOT EXISTS uq_setup_task_extra_material_source_active
ON ref.setup_task_extra_material_source(
    setup_task_extra_material_id,
    container_id
)
WHERE active_flag;

/* A Container may carry several variants of the same family, but an identical
   active material/specification row may not be duplicated and double-counted. */
CREATE UNIQUE INDEX IF NOT EXISTS uq_setup_container_extra_material_active_spec
ON ref.setup_container_extra_material(
    container_id,
    setup_extra_material_id,
    quantity_uom,
    coalesce(lower(btrim(size_text)), ''),
    coalesce(length_value, -1::numeric),
    coalesce(length_unit, ''),
    coalesce(lower(btrim(color)), '')
)
WHERE active_flag;

COMMIT;

SELECT
    to_regclass('ref.uq_setup_task_extra_material_active_spec') IS NOT NULL
        AS task_spec_unique_exists,
    to_regclass('ref.uq_setup_task_extra_material_source_active') IS NOT NULL
        AS source_unique_exists,
    to_regclass('ref.uq_setup_container_extra_material_active_spec') IS NOT NULL
        AS container_spec_unique_exists;
