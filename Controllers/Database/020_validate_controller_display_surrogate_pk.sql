/* ============================================================================
Controller Inventory — validate Directus-compatible controller_display identity
Issue: #110

READ ONLY.
============================================================================ */

\echo '=== controller_display row identity ==='
SELECT
    count(*) AS assignment_rows,
    count(controller_display_id) AS surrogate_ids,
    count(DISTINCT controller_display_id) AS distinct_surrogate_ids,
    count(*) - count(DISTINCT (controller_id, display_id)) AS duplicate_business_pairs
FROM ref.controller_display;

\echo '=== controller_display key constraints ==='
SELECT
    c.conname,
    c.contype,
    pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.conrelid='ref.controller_display'::regclass
  AND c.contype IN ('p','u')
ORDER BY c.contype, c.conname;

\echo '=== Directus field metadata ==='
SELECT
    collection,
    field,
    interface,
    readonly,
    hidden,
    note
FROM public.directus_fields
WHERE collection='controller_display'
  AND field='controller_display_id';

\echo '=== Directus sequence permission ==='
SELECT
    has_sequence_privilege(
        'directus_app',
        'ref.controller_display_controller_display_id_seq',
        'USAGE'
    ) AS directus_sequence_usage,
    has_sequence_privilege(
        'directus_app',
        'ref.controller_display_controller_display_id_seq',
        'SELECT'
    ) AS directus_sequence_select;

\echo '=== Validation assertions ==='
DO $assertions$
DECLARE
    row_count bigint;
    id_count bigint;
    distinct_id_count bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ref'
          AND table_name='controller_display'
          AND column_name='controller_display_id'
    ) THEN
        RAISE EXCEPTION 'controller_display_id is missing';
    END IF;

    SELECT count(*), count(controller_display_id), count(DISTINCT controller_display_id)
      INTO row_count, id_count, distinct_id_count
    FROM ref.controller_display;

    IF row_count <> id_count OR row_count <> distinct_id_count THEN
        RAISE EXCEPTION 'controller_display surrogate IDs are incomplete or duplicated';
    END IF;

    IF EXISTS (
        SELECT controller_id, display_id
        FROM ref.controller_display
        GROUP BY controller_id, display_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'duplicate Controller/Display business pairs exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_attribute a
          ON a.attrelid=c.conrelid AND a.attnum = ANY(c.conkey)
        WHERE c.conrelid='ref.controller_display'::regclass
          AND c.contype='p'
          AND a.attname='controller_display_id'
    ) THEN
        RAISE EXCEPTION 'controller_display_id is not the primary key';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid='ref.controller_display'::regclass
          AND contype='u'
          AND conname='uq_controller_display_controller_display'
    ) THEN
        RAISE EXCEPTION 'Controller + Display UNIQUE business constraint is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller_display'
          AND field='controller_display_id'
          AND readonly=true
          AND hidden=true
    ) THEN
        RAISE EXCEPTION 'Directus controller_display_id metadata is missing or not hidden/read-only';
    END IF;

    IF NOT has_sequence_privilege(
        'directus_app',
        'ref.controller_display_controller_display_id_seq',
        'USAGE'
    ) THEN
        RAISE EXCEPTION 'directus_app lacks sequence USAGE';
    END IF;
END
$assertions$;

\echo 'CONTROLLER_DISPLAY SURROGATE PRIMARY KEY: PASS'
