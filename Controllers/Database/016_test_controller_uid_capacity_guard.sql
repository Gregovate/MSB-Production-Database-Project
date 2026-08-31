/* ============================================================================
Controller Inventory: rollback-only programmed UID validation test
Issue: #110

Purpose:
  Prove PostgreSQL rejects impossible LOR UID configurations independently of
  the browser/Directus UI. This script leaves production data unchanged.
============================================================================ */

BEGIN;

DO $guard_test$
DECLARE
    v_failed_as_expected boolean := false;
BEGIN
    BEGIN
        UPDATE ref.controller
        SET lor_uid_count = 8
        WHERE controller_id = 1015; -- Pixie2D, capacity = 2
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE 'LOR UID Count % exceeds selected model capacity %' THEN
                v_failed_as_expected := true;
                RAISE NOTICE 'PASS: Pixie2D UID Count 8 rejected: %', SQLERRM;
            ELSE
                RAISE;
            END IF;
    END;

    IF NOT v_failed_as_expected THEN
        RAISE EXCEPTION 'FAIL: Pixie2D accepted impossible UID Count 8';
    END IF;
END
$guard_test$;

DO $range_test$
DECLARE
    v_failed_as_expected boolean := false;
BEGIN
    BEGIN
        UPDATE ref.controller
        SET lor_uid_start = 240,
            lor_uid_count = 2
        WHERE controller_id = 1015;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM = 'LOR UID range exceeds hex F0' THEN
                v_failed_as_expected := true;
                RAISE NOTICE 'PASS: UID range above F0 rejected: %', SQLERRM;
            ELSE
                RAISE;
            END IF;
    END;

    IF NOT v_failed_as_expected THEN
        RAISE EXCEPTION 'FAIL: invalid UID range above F0 was accepted';
    END IF;
END
$range_test$;

ROLLBACK;

SELECT
    controller_id,
    lor_network,
    upper(lpad(to_hex(lor_uid_start::integer), 2, '0')) AS first_uid,
    lor_uid_count,
    upper(lpad(to_hex(lor_uid_end::integer), 2, '0')) AS last_uid
FROM ref.controller
WHERE controller_id = 1015;
