/* ============================================================================
Object group: Current installed reconciliation promotion procedures
Repository:   Postgres_sql/Upsert Procedures/reconciliation/current_procedures/
Filename:     P2_display_promotion.sql
Revision:     2026-08-03-reconciliation-safe-p2-v1

Purpose:
  Canonical standalone definition of the P2 procedure currently installed in
  production from migration 0017. This file is the inspection and repair
  source for P2; the numbered migration remains installation history.

Safety:
  Installing this file replaces the P2 procedure definition only. It does not
  call P2, start or finish reconciliation, or modify production rows.
============================================================================ */

BEGIN;

CREATE OR REPLACE PROCEDURE ref.p2_promote_display_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_active_status_id integer;
    v_retired_status_id integer;
    v_recycled_status_id integer;
    v_bad_source integer;
    v_row record;
    v_display_id bigint;
    v_old_name text;
    v_old_uuid text;
    v_old_stage integer;
    v_old_string_type text;
    v_old_status integer;
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_status NOT IN ('READY_TO_FINISH', 'PROMOTING') THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P2',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT ds.display_status_id INTO v_active_status_id
    FROM ref.display_status AS ds
    WHERE upper(btrim(ds.display_status_name)) = 'ACTIVE';
    SELECT ds.display_status_id INTO v_retired_status_id
    FROM ref.display_status AS ds
    WHERE upper(btrim(ds.display_status_name)) = 'RETIRED';
    SELECT ds.display_status_id INTO v_recycled_status_id
    FROM ref.display_status AS ds
    WHERE upper(btrim(ds.display_status_name)) = 'RECYCLED';

    IF v_active_status_id IS NULL OR v_retired_status_id IS NULL
       OR v_recycled_status_id IS NULL THEN
        RAISE EXCEPTION 'ACTIVE, RETIRED, and RECYCLED display statuses are required';
    END IF;

    /* Permit idempotency validation to call P2 twice in one transaction. */
    DROP TABLE IF EXISTS pg_temp._lor_p2_plan;

    /* Build the complete effective write plan once from frozen state. */
    CREATE TEMP TABLE pg_temp._lor_p2_plan ON COMMIT DROP AS
    WITH latest_action AS (
        SELECT DISTINCT ON (a.lor_reconciliation_group_id)
            a.lor_reconciliation_group_id,
            a.lor_reconciliation_action_id,
            a.action_type
        FROM ops.lor_reconciliation_action AS a
        WHERE a.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND a.lor_reconciliation_group_id IS NOT NULL
        ORDER BY a.lor_reconciliation_group_id,
                 a.acted_at DESC,
                 a.lor_reconciliation_action_id DESC
    )
    SELECT
        c.*,
        la.lor_reconciliation_action_id,
        la.action_type,
        CASE
            WHEN la.action_type = 'REASSOCIATE_DISPLAY' THEN aa.target_display_id
            ELSE c.display_id
        END AS target_display_id
    FROM ops.lor_reconciliation_display_candidate AS c
    JOIN ops.lor_reconciliation_group AS g
      ON g.lor_reconciliation_group_id = c.lor_reconciliation_group_id
    LEFT JOIN latest_action AS la
      ON la.lor_reconciliation_group_id = c.lor_reconciliation_group_id
    LEFT JOIN ops.lor_reconciliation_action_assignment AS aa
      ON aa.lor_reconciliation_action_id = la.lor_reconciliation_action_id
     AND aa.lor_reconciliation_display_candidate_id =
            c.lor_reconciliation_display_candidate_id
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND c.candidate_class = 'PHYSICAL_DISPLAY'
      AND (
          (NOT g.decision_required AND c.initial_resolution_state = 'AUTO_APPROVED')
          OR la.action_type IN (
              'RENAME_DISPLAY', 'UPDATE_LOR_LINK', 'REASSOCIATE_DISPLAY',
              'ADD_NEW_DISPLAY', 'SET_RETIRED', 'SET_RECYCLED'
          )
      );

    IF EXISTS (
        SELECT 1 FROM pg_temp._lor_p2_plan AS p
        WHERE p.action_type = 'REASSOCIATE_DISPLAY'
          AND p.target_display_id IS NULL
    ) THEN
        RAISE EXCEPTION 'An approved reassociation is missing a frozen target mapping';
    END IF;

    /* Final write guard: every source-backed plan row must still match Run N. */
    SELECT count(*) INTO v_bad_source
    FROM pg_temp._lor_p2_plan AS p
    WHERE p.source_prop_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM lor_snap.props AS raw
          WHERE raw.import_run_id = v_import_run_id
            AND raw.prop_id = p.source_prop_id
            AND raw.raw_prop_id = p.lor_prop_id
            AND nullif(btrim(raw.lor_comment), '') IS NOT NULL
            AND btrim(raw.lor_comment) = p.proposed_display_name
            AND raw.string_type IS NOT DISTINCT FROM p.proposed_string_type
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% P2 candidates fail the captured raw-source guard for import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_temp._lor_p2_plan AS p
        WHERE p.source_prop_id IS NOT NULL
          AND (
              p.proposed_display_name IS NULL
              OR upper(btrim(p.proposed_display_name)) LIKE '%SPARE%'
              OR upper(btrim(p.proposed_display_name)) LIKE '%PHANTOM%'
          )
    ) THEN
        RAISE EXCEPTION 'P2 plan contains a blank, SPARE, or PHANTOM display';
    END IF;

    /*
      Immediate unique indexes make a chained rename/UUID swap impossible in
      one direct update. Vacate only the approved reassociation targets inside
      this transaction, then assign all final values below. A failure rolls the
      complete group and its temporary values back.
    */
    UPDATE ref.display AS d
       SET display_name = format('__LOR_RECON_%s_%s__',
                                 p_lor_reconciliation_run_id, d.display_id),
           lor_prop_id = format('__LOR_RECON_UUID_%s_%s__',
                                p_lor_reconciliation_run_id, d.display_id)
    WHERE EXISTS (
        SELECT 1
        FROM pg_temp._lor_p2_plan AS p
        WHERE p.action_type = 'REASSOCIATE_DISPLAY'
          AND p.target_display_id = d.display_id
          AND (
              d.display_name IS DISTINCT FROM p.proposed_display_name
              OR d.lor_prop_id IS DISTINCT FROM p.lor_prop_id
          )
    );

    FOR v_row IN
        SELECT * FROM pg_temp._lor_p2_plan
        ORDER BY lor_reconciliation_display_candidate_id
    LOOP
        IF v_row.action_type = 'ADD_NEW_DISPLAY' THEN
            INSERT INTO ref.display (
                lor_prop_id, display_name, inventory_type, display_status_id,
                stage_id, string_type
            ) VALUES (
                v_row.lor_prop_id, v_row.proposed_display_name, 'LOR',
                v_active_status_id, v_row.proposed_stage_id,
                v_row.proposed_string_type
            ) RETURNING display_id INTO v_display_id;

            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'DISPLAY',
                v_display_id::text, 'ADDED', 'P2_ADD_NEW_DISPLAY',
                format('ADDED: display_id %s as %s.',
                       v_display_id, v_row.proposed_display_name), true
            );
            CONTINUE;
        END IF;

        v_display_id := v_row.target_display_id;
        SELECT d.display_name, d.lor_prop_id, d.stage_id, d.string_type,
               d.display_status_id
          INTO v_old_name, v_old_uuid, v_old_stage, v_old_string_type,
               v_old_status
        FROM ref.display AS d
        WHERE d.display_id = v_display_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'P2 target display_id % does not exist', v_display_id;
        END IF;

        IF v_row.action_type = 'SET_RETIRED' THEN
            UPDATE ref.display SET display_status_id = v_retired_status_id
            WHERE display_id = v_display_id
              AND display_status_id IS DISTINCT FROM v_retired_status_id;
        ELSIF v_row.action_type = 'SET_RECYCLED' THEN
            UPDATE ref.display SET display_status_id = v_recycled_status_id
            WHERE display_id = v_display_id
              AND display_status_id IS DISTINCT FROM v_recycled_status_id;
        ELSE
            UPDATE ref.display AS d
               SET lor_prop_id = v_row.lor_prop_id,
                   display_name = v_row.proposed_display_name,
                   stage_id = v_row.proposed_stage_id,
                   string_type = v_row.proposed_string_type
             WHERE d.display_id = v_display_id
               AND (
                   d.lor_prop_id IS DISTINCT FROM v_row.lor_prop_id
                   OR d.display_name IS DISTINCT FROM v_row.proposed_display_name
                   OR d.stage_id IS DISTINCT FROM v_row.proposed_stage_id
                   OR d.string_type IS DISTINCT FROM v_row.proposed_string_type
               );
        END IF;

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'DISPLAY',
                v_display_id::text,
                CASE
                    WHEN v_row.action_type = 'REASSOCIATE_DISPLAY' THEN 'REASSOCIATED'
                    WHEN v_row.action_type IN ('SET_RETIRED', 'SET_RECYCLED')
                        THEN 'STATUS_CHANGED'
                    ELSE 'UPDATED'
                END,
                'P2_' || coalesce(v_row.action_type, 'AUTO_APPROVED'),
                format('P2 applied approved fields to display_id %s (%s).',
                       v_display_id,
                       coalesce(v_row.proposed_display_name, v_old_name)),
                true
            );
        END IF;
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p2_promote_display_from_reconciliation(bigint) IS
'Internal reconciliation-gated P2. Revalidates exact raw source rows, rejects nonphysical names, preserves display_id and production-owned metadata, and applies only approved atomic groups. Canonical revision 2026-08-03-reconciliation-safe-p2-v1.';

REVOKE EXECUTE ON PROCEDURE
    ref.p2_promote_display_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
