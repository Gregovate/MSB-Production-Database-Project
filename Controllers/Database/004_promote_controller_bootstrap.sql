/* ============================================================================
Controller Inventory initial bootstrap promotion
Issue: #110

SAFETY:
  - This is the first permanent controller-ID allocation only.
  - Requires every staging candidate to be READY or SKIPPED.
  - Requires ref.controller and ref.controller_display to be empty.
  - Restarts controller identity at 1001 only because the table is empty.
  - Inserts READY rows in reviewed bootstrap_order.
  - Verifies every generated ID equals 1000 + bootstrap_order.
  - Any mismatch/error aborts the entire transaction.
============================================================================ */

BEGIN;

LOCK TABLE ref.controller IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ref.controller_display IN ACCESS EXCLUSIVE MODE;
LOCK TABLE stage.controller_bootstrap IN SHARE MODE;
LOCK TABLE stage.controller_bootstrap_display IN SHARE MODE;

DO $preflight$
DECLARE
    v_count integer;
    v_ready integer;
BEGIN
    SELECT count(*) INTO v_count FROM ref.controller;
    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Initial Controller promotion requires empty ref.controller; found % rows',
            v_count;
    END IF;

    SELECT count(*) INTO v_count FROM ref.controller_display;
    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Initial Controller promotion requires empty ref.controller_display; found % rows',
            v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM stage.controller_bootstrap
    WHERE review_state = 'REVIEW_REQUIRED';
    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Controller bootstrap still has % REVIEW_REQUIRED rows', v_count;
    END IF;

    SELECT count(*) INTO v_ready
    FROM stage.controller_bootstrap
    WHERE review_state = 'READY';
    IF v_ready = 0 THEN
        RAISE EXCEPTION 'Controller bootstrap has no READY rows';
    END IF;

    SELECT count(*) INTO v_count
    FROM stage.controller_bootstrap
    WHERE review_state = 'READY'
      AND bootstrap_order IS NULL;
    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Controller bootstrap has % READY rows without bootstrap_order', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM stage.v_controller_bootstrap_review
    WHERE review_state = 'READY'
      AND cardinality(blockers) > 0;
    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Controller bootstrap has % READY rows with unresolved blockers', v_count;
    END IF;

    IF (SELECT min(bootstrap_order) FROM stage.controller_bootstrap WHERE review_state='READY') <> 1
       OR (SELECT max(bootstrap_order) FROM stage.controller_bootstrap WHERE review_state='READY') <> v_ready
       OR (SELECT count(DISTINCT bootstrap_order) FROM stage.controller_bootstrap WHERE review_state='READY') <> v_ready THEN
        RAISE EXCEPTION
            'Controller bootstrap_order must be contiguous 1..%', v_ready;
    END IF;

    SELECT count(*) INTO v_count
    FROM (
        SELECT controller_bootstrap_id
        FROM stage.controller_bootstrap_display
        WHERE relationship_type = 'WIRING_SOURCE'
        GROUP BY controller_bootstrap_id
        HAVING count(*) > 1
    ) AS x;
    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Controller bootstrap has % candidates with multiple WIRING_SOURCE rows', v_count;
    END IF;
END
$preflight$;

-- Safe here only because preflight proved ref.controller is empty.
ALTER TABLE ref.controller ALTER COLUMN controller_id RESTART WITH 1001;

CREATE TEMP TABLE pg_temp.controller_bootstrap_promoted (
    controller_bootstrap_id bigint PRIMARY KEY,
    controller_id bigint NOT NULL UNIQUE
) ON COMMIT DROP;

DO $promotion$
DECLARE
    r record;
    v_controller_id bigint;
    v_expected_id bigint;
    v_status_id integer;
    v_firmware_id integer;
BEGIN
    SELECT controller_status_id INTO v_status_id
    FROM ref.controller_status
    WHERE controller_status_name = 'DEPLOYED';

    IF v_status_id IS NULL THEN
        RAISE EXCEPTION 'DEPLOYED controller status is missing';
    END IF;

    FOR r IN
        SELECT *
        FROM stage.controller_bootstrap
        WHERE review_state = 'READY'
        ORDER BY bootstrap_order
    LOOP
        v_expected_id := 1000 + r.bootstrap_order;
        v_firmware_id := NULL;

        IF nullif(btrim(coalesce(r.firmware_evidence, '')), '') IS NOT NULL THEN
            SELECT controller_firmware_version_id
              INTO v_firmware_id
            FROM ref.controller_firmware_version
            WHERE controller_model_id = r.controller_model_id
              AND firmware_version = btrim(r.firmware_evidence);

            IF v_firmware_id IS NULL THEN
                RAISE EXCEPTION
                    'Firmware % for model id % is unresolved for bootstrap row %',
                    r.firmware_evidence, r.controller_model_id, r.source_row_num;
            END IF;
        END IF;

        INSERT INTO ref.controller (
            controller_model_id,
            controller_status_id,
            installed_firmware_version_id,
            year_deployed,
            verification_state,
            notes,
            label_required,
            print_label
        )
        VALUES (
            r.controller_model_id,
            v_status_id,
            v_firmware_id,
            r.year_deployed,
            'ENGINEERING_ACCEPTED',
            r.review_notes,
            true,
            false
        )
        RETURNING controller_id INTO v_controller_id;

        IF v_controller_id <> v_expected_id THEN
            RAISE EXCEPTION
                'Controller ID mismatch for bootstrap row %: expected %, PostgreSQL generated %',
                r.source_row_num, v_expected_id, v_controller_id;
        END IF;

        INSERT INTO pg_temp.controller_bootstrap_promoted (
            controller_bootstrap_id, controller_id
        ) VALUES (r.controller_bootstrap_id, v_controller_id);
    END LOOP;
END
$promotion$;

-- Permanent M:N Display relationships.
INSERT INTO ref.controller_display (
    controller_id,
    display_id,
    wiring_source_display_id
)
SELECT
    p.controller_id,
    bd.display_id,
    ws.wiring_source_display_id
FROM pg_temp.controller_bootstrap_promoted AS p
JOIN stage.controller_bootstrap_display AS bd
  ON bd.controller_bootstrap_id = p.controller_bootstrap_id
 AND bd.relationship_type = 'SERVES'
LEFT JOIN LATERAL (
    SELECT min(x.display_id) AS wiring_source_display_id
    FROM stage.controller_bootstrap_display AS x
    WHERE x.controller_bootstrap_id = p.controller_bootstrap_id
      AND x.relationship_type = 'WIRING_SOURCE'
) AS ws ON true;

-- Initial firmware evidence becomes both current installed firmware and history.
INSERT INTO ref.controller_firmware_history (
    controller_id,
    controller_firmware_version_id,
    notes
)
SELECT
    p.controller_id,
    fv.controller_firmware_version_id,
    'Initial Controller Inventory bootstrap evidence'
FROM pg_temp.controller_bootstrap_promoted AS p
JOIN stage.controller_bootstrap AS b
  ON b.controller_bootstrap_id = p.controller_bootstrap_id
JOIN ref.controller_firmware_version AS fv
  ON fv.controller_model_id = b.controller_model_id
 AND fv.firmware_version = btrim(b.firmware_evidence)
WHERE nullif(btrim(coalesce(b.firmware_evidence, '')), '') IS NOT NULL;

-- Final transactional assertions.
DO $assertions$
DECLARE
    v_expected integer;
    v_actual integer;
BEGIN
    SELECT count(*) INTO v_expected
    FROM stage.controller_bootstrap
    WHERE review_state = 'READY';

    SELECT count(*) INTO v_actual FROM ref.controller;
    IF v_actual <> v_expected THEN
        RAISE EXCEPTION
            'Controller promotion row-count mismatch: expected %, actual %',
            v_expected, v_actual;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_temp.controller_bootstrap_promoted AS p
        JOIN stage.controller_bootstrap AS b
          ON b.controller_bootstrap_id = p.controller_bootstrap_id
        WHERE p.controller_id <> 1000 + b.bootstrap_order
    ) THEN
        RAISE EXCEPTION 'Controller promotion ID/order verification failed';
    END IF;
END
$assertions$;

COMMIT;

SELECT
    count(*) AS controller_count,
    min(controller_id) AS first_controller_id,
    max(controller_id) AS last_controller_id
FROM ref.controller;
