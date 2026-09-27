/* ============================================================================
MSB Setup #172 — Report Correction -> Work Order Intake disposable validation
Issues: #172, #122
Scope: DISPOSABLE CURRENT-PRODUCTION CLONE ONLY

Proves:
  exact scheduled assignment -> one Submitted Intake request
  -> full Setup/Captain/Procedure/reporter provenance
  -> no active Work Order creation
  -> invalid assignment fails closed
  -> application role has narrow EXECUTE but no direct Intake INSERT
============================================================================ */

\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_assignment_id bigint;
    v_session_task_id bigint;
    v_setup_task_id bigint;
    v_captain_person_id integer;
    v_intake_id bigint;
    v_work_orders_before bigint;
    v_work_orders_after bigint;
    v_started_at timestamptz := clock_timestamp();
    v_bad_assignment_blocked boolean := false;
    v_payload jsonb;
    v_notes text;
BEGIN
    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND u.email IS NOT NULL
      AND c.can_manage_setup
    ORDER BY u.id
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'Disposable validation could not find an active Setup Manager';
    END IF;

    SELECT
        wdt.setup_work_day_task_id,
        wdt.setup_session_task_id,
        st.setup_task_id,
        c.captain_person_id
      INTO
        v_assignment_id,
        v_session_task_id,
        v_setup_task_id,
        v_captain_person_id
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_session_task st
      ON st.setup_session_task_id = wdt.setup_session_task_id
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
    JOIN ops.setup_session ss
      ON ss.setup_session_id = wd.setup_session_id
    LEFT JOIN ops.setup_work_day_crew c
      ON c.setup_work_day_crew_id = wdt.setup_work_day_crew_id
    WHERE ss.season_year = 2026
      AND wd.day_status <> 'CANCELLED'
    ORDER BY
        (c.captain_person_id IS NOT NULL) DESC,
        wd.work_date,
        wdt.setup_work_day_task_id
    LIMIT 1;

    IF v_assignment_id IS NULL THEN
        RAISE EXCEPTION 'Disposable validation could not find a real 2026 scheduled assignment';
    END IF;

    SELECT count(*) INTO v_work_orders_before FROM ops.work_order;

    SELECT intake_id
      INTO v_intake_id
    FROM ops.submit_setup_work_order_intake(
        v_manager_email,
        v_session_task_id,
        v_assignment_id,
        'Disposable #172 validation finding',
        'Disposable #172 validation evidence',
        jsonb_build_object(
            'status', 'VALIDATION',
            'scope_type', 'DISPOSABLE',
            'documents', jsonb_build_array(
                jsonb_build_object('name', 'Disposable #172 Procedure.pdf')
            ),
            'summary', 'Disposable #172 Procedure.pdf'
        )
    );

    IF v_intake_id IS NULL THEN
        RAISE EXCEPTION 'Report Correction did not return an Intake identity';
    END IF;

    SELECT source_payload, notes_raw
      INTO v_payload, v_notes
    FROM stage.work_order_intake
    WHERE intake_id = v_intake_id
      AND triage_dropdown = '1'
      AND source_system = 'SETUP'
      AND source_form_name = 'SETUP_CORRECTION'
      AND problem_raw = 'Disposable #172 validation finding';

    IF v_payload IS NULL THEN
        RAISE EXCEPTION 'Submitted Intake row was not found';
    END IF;

    IF (v_payload ->> 'setup_session_task_id')::bigint <> v_session_task_id
       OR (v_payload ->> 'setup_work_day_task_id')::bigint <> v_assignment_id
       OR (v_payload ->> 'season_year')::integer <> 2026
       OR v_payload ->> 'suggested_correction_evidence'
            <> 'Disposable #172 validation evidence'
       OR v_payload #>> '{procedure_context,summary}'
            <> 'Disposable #172 Procedure.pdf' THEN
        RAISE EXCEPTION 'Submitted Intake did not preserve required Setup/procedure context: %', v_payload;
    END IF;

    IF v_setup_task_id IS NULL THEN
        IF v_payload ? 'setup_task_id' THEN
            RAISE EXCEPTION 'Season-only assignment unexpectedly gained reusable task identity';
        END IF;
    ELSIF (v_payload ->> 'setup_task_id')::bigint <> v_setup_task_id THEN
        RAISE EXCEPTION 'Reusable Setup task identity was not preserved';
    END IF;

    IF v_captain_person_id IS NULL THEN
        IF v_payload ? 'captain_person_id' THEN
            RAISE EXCEPTION 'NULL Captain should remain absent from stripped payload';
        END IF;
    ELSIF (v_payload ->> 'captain_person_id')::integer <> v_captain_person_id THEN
        RAISE EXCEPTION 'Scheduled Captain identity was not preserved';
    END IF;

    IF (v_payload ->> 'reporter_person_id') IS NULL
       OR (v_payload ->> 'reporter_email') <> v_manager_email
       OR (v_payload ->> 'submitted_at')::timestamptz < v_started_at THEN
        RAISE EXCEPTION 'Reporter/timestamp provenance was not preserved: %', v_payload;
    END IF;

    IF v_notes NOT LIKE '%annual_task_id=' || v_session_task_id::text || '%'
       OR v_notes NOT LIKE '%assignment_id=' || v_assignment_id::text || '%'
       OR v_notes NOT LIKE '%Procedure: Disposable #172 Procedure.pdf%' THEN
        RAISE EXCEPTION 'Promotion-surviving Setup provenance is incomplete: %', v_notes;
    END IF;

    SELECT count(*) INTO v_work_orders_after FROM ops.work_order;
    IF v_work_orders_after <> v_work_orders_before THEN
        RAISE EXCEPTION 'Report Correction created an active Work Order directly';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.work_order
        WHERE source_intake_id = v_intake_id
    ) THEN
        RAISE EXCEPTION 'Submitted Intake unexpectedly promoted itself';
    END IF;

    BEGIN
        PERFORM *
        FROM ops.submit_setup_work_order_intake(
            v_manager_email,
            v_session_task_id,
            v_assignment_id + 999999999,
            'Disposable invalid-assignment validation',
            NULL,
            '{}'::jsonb
        );
    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            v_bad_assignment_blocked := true;
    END;

    IF NOT v_bad_assignment_blocked THEN
        RAISE EXCEPTION 'Invalid/mismatched scheduled assignment did not fail closed';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.submit_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks governed Report Correction command EXECUTE';
    END IF;

    IF has_table_privilege(
        'fieldwiring_app',
        'stage.work_order_intake',
        'INSERT'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app has forbidden direct Work Order Intake INSERT';
    END IF;
END
$validation$;

ROLLBACK;
