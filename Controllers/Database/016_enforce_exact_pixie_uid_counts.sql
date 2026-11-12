/* ============================================================================
Controller Inventory: enforce exact LOR UID counts for fixed-range models
Issue: #110

Operator rule accepted 2026-08-31:
  - CCB100 uses exactly 2 contiguous Unit IDs.
  - Pixie4D uses exactly 4 contiguous Unit IDs.
  - Pixie8D uses exactly 8 contiguous Unit IDs.
  - Pixie16D uses exactly 16 contiguous Unit IDs.

The existing generic capacity guard remains useful for other models, but these
fixed-range families must not accept a lower count merely because it is below
capacity.
============================================================================ */

BEGIN;

ALTER TABLE ref.controller_model
    ADD COLUMN IF NOT EXISTS lor_uid_requires_full_capacity boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN ref.controller_model.lor_uid_requires_full_capacity IS
    'When true, configured LOR UID Count must equal lor_uid_capacity exactly.';

UPDATE ref.controller_model
SET lor_uid_requires_full_capacity = true
WHERE model_code IN ('CCB100','Pixie4D','Pixie8D','Pixie16D');

CREATE OR REPLACE FUNCTION ref.validate_controller_lor_configuration()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_capacity smallint;
    v_requires_full boolean;
BEGIN
    IF NEW.lor_uid_start IS NULL AND NEW.lor_uid_count IS NULL AND NEW.lor_network IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.lor_uid_start IS NULL OR NEW.lor_uid_count IS NULL
       OR nullif(btrim(NEW.lor_network), '') IS NULL THEN
        RAISE EXCEPTION 'LOR Network, First UID, and UID Count must be supplied together';
    END IF;

    IF NEW.lor_uid_start < 1 OR NEW.lor_uid_start > 240 THEN
        RAISE EXCEPTION 'LOR First UID must be between hex 01 and F0';
    END IF;

    IF NEW.lor_uid_count < 1 THEN
        RAISE EXCEPTION 'LOR UID Count must be at least 1';
    END IF;

    IF NEW.lor_uid_start + NEW.lor_uid_count - 1 > 240 THEN
        RAISE EXCEPTION 'LOR UID range exceeds hex F0';
    END IF;

    SELECT lor_uid_capacity, lor_uid_requires_full_capacity
      INTO v_capacity, v_requires_full
    FROM ref.controller_model
    WHERE controller_model_id = NEW.controller_model_id;

    IF v_capacity IS NULL THEN
        RAISE EXCEPTION 'Selected controller model has no LOR UID capacity';
    END IF;

    IF NEW.lor_uid_count > v_capacity THEN
        RAISE EXCEPTION 'LOR UID Count % exceeds selected model capacity %',
            NEW.lor_uid_count, v_capacity;
    END IF;

    IF v_requires_full AND NEW.lor_uid_count <> v_capacity THEN
        RAISE EXCEPTION 'Selected controller model requires exactly % contiguous LOR Unit IDs; received %',
            v_capacity, NEW.lor_uid_count;
    END IF;

    RETURN NEW;
END
$$;

-- Existing production rows must already satisfy the new exact rule.
DO $preflight$
DECLARE v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM ref.controller c
    JOIN ref.controller_model m
      ON m.controller_model_id = c.controller_model_id
    WHERE m.lor_uid_requires_full_capacity
      AND c.lor_uid_count IS DISTINCT FROM m.lor_uid_capacity;

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Found % fixed-range controllers not using full model UID capacity', v_count;
    END IF;
END
$preflight$;

-- Prove the trigger rejects under-sized configurations without leaving any
-- production change behind.
DO $guard_test$
DECLARE
    v_rejected boolean := false;
BEGIN
    BEGIN
        UPDATE ref.controller
        SET lor_uid_count = 3
        WHERE controller_id = 1134;
    EXCEPTION WHEN OTHERS THEN
        v_rejected := true;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Guard test failed: Pixie4D accepted UID Count 3';
    END IF;

    IF (SELECT lor_uid_count FROM ref.controller WHERE controller_id = 1134) <> 4 THEN
        RAISE EXCEPTION 'Guard test altered controller 1134 unexpectedly';
    END IF;

    v_rejected := false;
    BEGIN
        UPDATE ref.controller
        SET lor_uid_count = 1
        WHERE controller_id = 1120;
    EXCEPTION WHEN OTHERS THEN
        v_rejected := true;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Guard test failed: CCB100 accepted UID Count 1';
    END IF;

    IF (SELECT lor_uid_count FROM ref.controller WHERE controller_id = 1120) <> 2 THEN
        RAISE EXCEPTION 'Guard test altered controller 1120 unexpectedly';
    END IF;
END
$guard_test$;

COMMIT;

SELECT
    m.model_code,
    m.lor_uid_capacity,
    m.lor_uid_requires_full_capacity,
    count(c.controller_id) AS controller_count,
    min(c.lor_uid_count) AS min_uid_count,
    max(c.lor_uid_count) AS max_uid_count
FROM ref.controller_model m
JOIN ref.controller c
  ON c.controller_model_id = m.controller_model_id
WHERE m.model_code IN ('CCB100','Pixie4D','Pixie8D','Pixie16D')
GROUP BY m.controller_model_id, m.model_code, m.lor_uid_capacity,
         m.lor_uid_requires_full_capacity
ORDER BY m.lor_uid_capacity, m.model_code;
