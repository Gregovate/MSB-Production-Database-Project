/* ============================================================================
Validation: Distinct substages and protected display-stage assignments

Safety: Read-only.  This script changes no production or audit data.
============================================================================ */

DO $validation$
DECLARE
    v_stage_05 integer;
    v_stage_05a integer;
    v_p2_definition text;
BEGIN
    SELECT s.stage_id INTO STRICT v_stage_05
    FROM ref.stage AS s
    WHERE s.stage_key = '05'
      AND s.stage_name = 'RGB Plus Stage 05 Festive Trees Traditional'
      AND s.folder_name = '05-RGB Plus Stage 05 Festive Trees Traditional'
      AND s.park_order = 5
      AND s.sub_order = 0;

    SELECT s.stage_id INTO STRICT v_stage_05a
    FROM ref.stage AS s
    WHERE s.stage_key = '05a'
      AND s.stage_name = 'RGB Plus Stage 05a Mega Star'
      AND s.folder_name = '05a-RGB Plus Stage 05a Mega Star'
      AND s.park_order = 5
      AND s.sub_order = 1;

    IF v_stage_05 = v_stage_05a OR v_stage_05 <> 35 THEN
        RAISE EXCEPTION 'Stage 05 and 05a do not have distinct permanent identities';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_stage_candidate AS c
        WHERE c.lor_reconciliation_run_id = 8
          AND c.source_stage_key = '05'
    ) OR NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_stage_candidate AS c
        WHERE c.lor_reconciliation_run_id = 8
          AND c.source_stage_key = '05a'
    ) THEN
        RAISE EXCEPTION 'Frozen snapshot evidence no longer retains both source keys 05 and 05a';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.stage_lor_binding AS b
        WHERE b.stage_lor_binding_id = 142
          AND b.stage_id = v_stage_05
          AND b.accepted_source_stage_key = '05'
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.stage_lor_binding AS b
        WHERE b.stage_lor_binding_id = 143
          AND b.stage_id = v_stage_05a
          AND b.accepted_source_stage_key = '05a'
    ) THEN
        RAISE EXCEPTION 'Stage 05/05a stable bindings are not separated';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_display_candidate AS c
        JOIN ref.display AS d ON d.display_id = c.display_id
        WHERE c.lor_reconciliation_run_id = 8
          AND c.current_stage_id = 35
          AND c.proposed_stage_id IS NULL
          AND 'stage_id' = ANY(c.changed_fields)
          AND d.stage_id IS DISTINCT FROM v_stage_05
    ) THEN
        RAISE EXCEPTION 'At least one run 8 Stage 05 display was not restored';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.display AS d
        WHERE d.display_id = 869
          AND d.display_name = 'FT-MegaStar'
          AND d.stage_id = v_stage_05a
    ) THEN
        RAISE EXCEPTION 'FT-MegaStar is not assigned to permanent Stage 05a';
    END IF;

    IF ops.f_stage_group_can_approve_change(14721) THEN
        RAISE EXCEPTION 'Mixed 05/05a evidence is still incorrectly approvable as a rename';
    END IF;

    SELECT pg_get_functiondef(
        'ref.p2_promote_display_from_reconciliation(bigint)'::regprocedure
    ) INTO v_p2_definition;

    IF v_p2_definition NOT ILIKE '%effective_stage_id%'
       OR v_p2_definition NOT ILIKE '%cannot resolve one or more approved source StageIDs%'
       OR v_p2_definition ILIKE '%stage_id = v_row.proposed_stage_id%' THEN
        RAISE EXCEPTION 'P2 stage-assignment protection is not installed';
    END IF;
END;
$validation$;

SELECT
    'PASS'::text AS validation_status,
    'Stage 05 and 05a are distinct, exact affected displays are repaired, and P2 cannot clear unresolved stage assignments.'::text
        AS validation_detail;
