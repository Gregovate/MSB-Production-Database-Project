/* ============================================================================
Object: Rollback-only validation of reconciliation-safe P2
Filename: 13_reconciliation_safe_p2_display_validation.sql

Safety:
  This entire script is one transaction ending in ROLLBACK. It temporarily
  records the confirmed Welcome reassociation, calls P2 twice, and verifies
  production-owned ref.display fields remain unchanged. No test action, result,
  or ref.display change survives.
============================================================================ */

BEGIN;

DO $validation$
DECLARE
    v_run_id bigint := 1;
    v_group_id bigint;
    v_map jsonb;
BEGIN
    SELECT g.lor_reconciliation_group_id
      INTO STRICT v_group_id
    FROM ops.lor_reconciliation_group AS g
    WHERE g.lor_reconciliation_run_id = v_run_id
      AND g.entity_type = 'DISPLAY'
      AND g.logical_group_key = 'DISPLAY_IDENTITY:920';

    SELECT jsonb_object_agg(
               c.lor_reconciliation_display_candidate_id::text,
               c.display_id
           )
      INTO v_map
    FROM ops.lor_reconciliation_display_candidate AS c
    WHERE c.lor_reconciliation_group_id = v_group_id;

    IF (SELECT count(*) FROM jsonb_object_keys(COALESCE(v_map, '{}'::jsonb))) <> 2 THEN
        RAISE EXCEPTION 'Welcome validation requires exactly two frozen members';
    END IF;

    PERFORM ops.f_record_lor_reconciliation_action(
        v_run_id,
        v_group_id,
        'REASSOCIATE_DISPLAY',
        'Rollback validation only: confirmed Welcome chained rename.',
        v_map,
        'rollback-validation-13'
    );
END;
$validation$;

CREATE TEMP TABLE pg_temp._p2_before ON COMMIT DROP AS
SELECT d.*
FROM ref.display AS d
WHERE d.display_id IN (920, 976);

CALL ref.p2_promote_display_from_reconciliation(1);

SELECT
    d.display_id,
    b.display_name AS before_display_name,
    d.display_name AS after_display_name,
    b.lor_prop_id AS before_lor_prop_id,
    d.lor_prop_id AS after_lor_prop_id,
    d.stage_id AS after_stage_id,
    d.string_type AS after_string_type
FROM ref.display AS d
JOIN pg_temp._p2_before AS b USING (display_id)
ORDER BY d.display_id;

SELECT
    count(*) FILTER (
        WHERE d.display_id = 920
          AND d.display_name = 'WA-WelcomeTo-01'
    ) AS display_920_correct,
    count(*) FILTER (
        WHERE d.display_id = 976
          AND d.display_name = 'QV-WelcomeTo-02'
    ) AS display_976_correct,
    count(*) FILTER (
        WHERE d.inventory_type IS DISTINCT FROM b.inventory_type
           OR d.designer_id IS DISTINCT FROM b.designer_id
           OR d.theme_id IS DISTINCT FROM b.theme_id
           OR d.frame_id IS DISTINCT FROM b.frame_id
           OR d.container_id IS DISTINCT FROM b.container_id
           OR d.year_built IS DISTINCT FROM b.year_built
           OR d.amps_measured IS DISTINCT FROM b.amps_measured
           OR d.est_light_count IS DISTINCT FROM b.est_light_count
           OR d.dumb_controller IS DISTINCT FROM b.dumb_controller
           OR d.notes IS DISTINCT FROM b.notes
           OR d.color IS DISTINCT FROM b.color
           OR d.display_status_id IS DISTINCT FROM b.display_status_id
           OR d.label_required IS DISTINCT FROM b.label_required
           OR d.print_label IS DISTINCT FROM b.print_label
    ) AS unauthorized_field_change_count,
    CASE
        WHEN count(*) FILTER (
                 WHERE d.display_id = 920
                   AND d.display_name = 'WA-WelcomeTo-01'
             ) = 1
         AND count(*) FILTER (
                 WHERE d.display_id = 976
                   AND d.display_name = 'QV-WelcomeTo-02'
             ) = 1
         AND count(*) FILTER (
                 WHERE d.inventory_type IS DISTINCT FROM b.inventory_type
                    OR d.designer_id IS DISTINCT FROM b.designer_id
                    OR d.theme_id IS DISTINCT FROM b.theme_id
                    OR d.frame_id IS DISTINCT FROM b.frame_id
                    OR d.container_id IS DISTINCT FROM b.container_id
                    OR d.color IS DISTINCT FROM b.color
                    OR d.display_status_id IS DISTINCT FROM b.display_status_id
             ) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS p2_atomic_reassociation_validation
FROM ref.display AS d
JOIN pg_temp._p2_before AS b USING (display_id);

/* A second call must produce no additional committed display result rows. */
CREATE TEMP TABLE pg_temp._p2_result_count ON COMMIT DROP AS
SELECT count(*) AS result_count
FROM ops.lor_reconciliation_result
WHERE lor_reconciliation_run_id = 1
  AND entity_type = 'DISPLAY'
  AND committed;

CALL ref.p2_promote_display_from_reconciliation(1);

SELECT
    before_count.result_count AS first_call_result_count,
    count(*) AS second_call_result_count,
    CASE WHEN count(*) = before_count.result_count THEN 'PASS' ELSE 'FAIL' END
        AS p2_same_transaction_idempotency_validation
FROM ops.lor_reconciliation_result AS r
CROSS JOIN pg_temp._p2_result_count AS before_count
WHERE r.lor_reconciliation_run_id = 1
  AND r.entity_type = 'DISPLAY'
  AND r.committed
GROUP BY before_count.result_count;

SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.unresolved_count,
    r.deferred_count,
    r.blocked_count,
    count(rr.*) FILTER (
        WHERE rr.entity_type = 'DISPLAY' AND rr.committed
    ) AS rollback_test_display_result_count
FROM ops.lor_reconciliation_run AS r
LEFT JOIN ops.lor_reconciliation_result AS rr
  ON rr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
WHERE r.lor_reconciliation_run_id = 1
GROUP BY r.lor_reconciliation_run_id;

ROLLBACK;
