/* ============================================================================
Controller Inventory — Directus-compatible controller_display row identity
Issue: #110

Purpose:
  Directus 11.17.1 cannot operate an O2M management relation whose related
  collection has only a composite primary key. ref.controller_display was
  originally keyed by (controller_id, display_id), causing the Controller
  item-detail request to fail while expanding display_assignments.

Permanent shape:
  - controller_display_id: surrogate PostgreSQL identity PRIMARY KEY used only
    as row identity / Directus compatibility;
  - (controller_id, display_id): UNIQUE business constraint preserving the
    permanent Controller-to-Display relationship semantics;
  - all existing FKs and assignment rows remain unchanged;
  - directus_app receives identity-sequence usage so Manager assignment CREATE
    can allocate relationship row IDs.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    pk_cols text[];
    inbound_fk_count integer;
BEGIN
    IF to_regclass('ref.controller_display') IS NULL THEN
        RAISE EXCEPTION 'ref.controller_display is missing';
    END IF;

    SELECT count(*) INTO inbound_fk_count
    FROM pg_constraint
    WHERE contype='f'
      AND confrelid='ref.controller_display'::regclass;

    IF inbound_fk_count <> 0 THEN
        RAISE EXCEPTION 'controller_display has % inbound FK(s); review before changing PK', inbound_fk_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ref'
          AND table_name='controller_display'
          AND column_name='controller_display_id'
    ) THEN
        SELECT array_agg(a.attname ORDER BY x.ord)
          INTO pk_cols
        FROM pg_constraint c
        CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS x(attnum, ord)
        JOIN pg_attribute a
          ON a.attrelid=c.conrelid AND a.attnum=x.attnum
        WHERE c.conrelid='ref.controller_display'::regclass
          AND c.contype='p';

        IF pk_cols IS DISTINCT FROM ARRAY['controller_id','display_id']::text[] THEN
            RAISE EXCEPTION 'Expected composite PK (controller_id, display_id), found %', pk_cols;
        END IF;
    END IF;
END
$preflight$;

DO $migrate$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ref'
          AND table_name='controller_display'
          AND column_name='controller_display_id'
    ) THEN
        ALTER TABLE ref.controller_display
            DROP CONSTRAINT pk_controller_display;

        ALTER TABLE ref.controller_display
            ADD COLUMN controller_display_id bigint GENERATED ALWAYS AS IDENTITY;

        ALTER TABLE ref.controller_display
            ADD CONSTRAINT pk_controller_display PRIMARY KEY (controller_display_id);

        ALTER TABLE ref.controller_display
            ADD CONSTRAINT uq_controller_display_controller_display
            UNIQUE (controller_id, display_id);
    END IF;
END
$migrate$;

INSERT INTO public.directus_fields
    (collection, field, interface, readonly, hidden, sort, width, note, required, searchable)
SELECT
    'controller_display',
    'controller_display_id',
    'input',
    true,
    true,
    0,
    'half',
    'Directus row identity for Controller-to-Display assignment. Assignment business identity remains Controller + Display.',
    false,
    true
WHERE NOT EXISTS (
    SELECT 1 FROM public.directus_fields
    WHERE collection='controller_display'
      AND field='controller_display_id'
);

-- Directus must be able to allocate the surrogate relationship identity when
-- a Manager creates a Controller-to-Display assignment through the O2M form.
GRANT USAGE, SELECT ON SEQUENCE
    ref.controller_display_controller_display_id_seq
TO directus_app;

DO $assertions$
DECLARE
    row_count bigint;
    id_count bigint;
    distinct_id_count bigint;
BEGIN
    SELECT count(*), count(controller_display_id), count(DISTINCT controller_display_id)
      INTO row_count, id_count, distinct_id_count
    FROM ref.controller_display;

    IF row_count <> id_count OR row_count <> distinct_id_count THEN
        RAISE EXCEPTION 'Surrogate IDs were not populated uniquely for all assignment rows';
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
        RAISE EXCEPTION 'Controller + Display uniqueness was not preserved';
    END IF;

    IF EXISTS (
        SELECT controller_id, display_id
        FROM ref.controller_display
        GROUP BY controller_id, display_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate Controller/Display relationships exist';
    END IF;

    IF NOT has_sequence_privilege(
        'directus_app',
        'ref.controller_display_controller_display_id_seq',
        'USAGE'
    ) THEN
        RAISE EXCEPTION 'directus_app lacks controller_display identity-sequence USAGE';
    END IF;
END
$assertions$;

COMMIT;

SELECT
    count(*) AS assignment_rows,
    count(controller_display_id) AS surrogate_ids,
    count(DISTINCT controller_display_id) AS distinct_surrogate_ids,
    count(*) - count(DISTINCT (controller_id, display_id)) AS duplicate_business_pairs
FROM ref.controller_display;

SELECT
    c.conname,
    c.contype,
    pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.conrelid='ref.controller_display'::regclass
  AND c.contype IN ('p','u')
ORDER BY c.contype, c.conname;
