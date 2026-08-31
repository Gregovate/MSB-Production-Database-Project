/* ============================================================================
Controller Inventory EXPERIMENTAL reset
Issue: #110

PRE-ACCEPTANCE ONLY.

Purpose:
  Clear only Controller-owned experimental data so the bootstrap can be rebuilt
  and controller IDs can again begin at 1001.

The script refuses to run if any Controller label print evidence exists.
It does not touch ref.display, ref.stage, ref.location, ref.label_template,
lor_snap.*, P1/P2, FieldWiring, or any other production-owned record.
============================================================================ */

BEGIN;

LOCK TABLE ref.controller IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ref.controller_display IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ref.controller_firmware_history IN ACCESS EXCLUSIVE MODE;

DO $guard$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM ref.controller
    WHERE print_label
       OR label_print_count_cached <> 0
       OR label_print_last_at_cached IS NOT NULL
       OR label_print_last_by_cached_id IS NOT NULL;

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Experimental Controller reset blocked: % controller rows contain label request/print evidence',
            v_count;
    END IF;

    -- No table outside the isolated Controller subsystem may reference
    -- ref.controller during the experimental phase.
    SELECT count(*) INTO v_count
    FROM pg_constraint AS con
    JOIN pg_class AS child ON child.oid = con.conrelid
    JOIN pg_namespace AS n ON n.oid = child.relnamespace
    WHERE con.contype = 'f'
      AND con.confrelid = 'ref.controller'::regclass
      AND NOT (n.nspname = 'ref' AND child.relname IN (
          'controller_display', 'controller_firmware_history'
      ));

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Experimental Controller reset blocked: % external FK dependencies now reference ref.controller',
            v_count;
    END IF;
END
$guard$;

TRUNCATE TABLE
    ref.controller_firmware_history,
    ref.controller_display,
    ref.controller
RESTART IDENTITY;

ALTER TABLE ref.controller ALTER COLUMN controller_id RESTART WITH 1001;

-- Preserve model/status/firmware catalogs and stage bootstrap evidence.
-- They are reusable across bootstrap iterations.

COMMIT;

SELECT
    (SELECT count(*) FROM ref.controller) AS controller_rows_after_reset,
    (SELECT count(*)
       FROM stage.controller_bootstrap
      WHERE bootstrap_order IS NOT NULL) AS staged_ordered_rows;
