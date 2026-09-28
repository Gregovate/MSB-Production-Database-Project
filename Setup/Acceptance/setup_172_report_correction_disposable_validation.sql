/* ============================================================================
MSB Setup #172 — Report Correction -> Work Order Intake disposable validation
Issues: #172, #122
Scope: DISPOSABLE CURRENT-PRODUCTION CLONE ONLY

Proves:
  exact scheduled assignment -> authorized Directus Intake payload
  -> full Setup/Captain/Procedure/reporter provenance
  -> existing Directus items.create manager-notification flow present
  -> no active Work Order creation
  -> invalid assignment fails closed
  -> application role has narrow EXECUTE but no direct Intake INSERT
============================================================================ */

\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_reporter_email text;
    v_assignment_id bigint;
    v_session_task_id bigint;
    v_setup_task_id bigint;
    v_captain_person_id integer;
    v_work_orders_before bigint;
    v_work_orders_after bigint;
    v_started_at timestamptz := clock_timestamp();
    v_bad_assignment_blocked boolean := false;
    v_intake_payload jsonb;
    v_payload jsonb;
    v_notes text;
BEGIN
    SELECT lower(u.email)
      INTO v_reporter_email
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND u.email IS NOT NULL
      AND (
          c.role_name = 'Production Crew'
          OR 'Production Crew' = ANY(coalesce(c.policy_names, ARRAY[]::text[]))
      )
    ORDER BY u.id
    LIMIT 1;

    IF v_reporter_email IS NULL THEN
        RAISE EXCEPTION
            'Disposable validation could not find an active Production Crew reporter';
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

    SELECT intake_payload
      INTO v_intake_payload
    FROM ops.prepare_setup_work_order_intake(
        v_reporter_email,
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

    IF v_intake_payload IS NULL THEN
        RAISE EXCEPTION 'Report Correction preparation did not return an Intake payload';
    END IF;

    v_payload := v_intake_payload -> 'source_payload';
    v_notes := v_intake_payload ->> 'notes_raw';

    IF v_payload IS NULL THEN
        RAISE EXCEPTION 'Prepared Intake source payload was not returned';
    END IF;

    IF (v_payload ->> 'setup_session_task_id')::bigint <> v_session_task_id
       OR (v_payload ->> 'setup_work_day_task_id')::bigint <> v_assignment_id
       OR (v_payload ->> 'season_year')::integer <> 2026
       OR v_payload ->> 'suggested_correction_evidence'
            <> 'Disposable #172 validation evidence'
       OR v_payload #>> '{procedure_context,summary}'
            <> 'Disposable #172 Procedure.pdf' THEN
        RAISE EXCEPTION 'Prepared Intake did not preserve required Setup/procedure context: %', v_payload;
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
       OR (v_payload ->> 'reporter_email') <> v_reporter_email
       OR (v_payload ->> 'submitted_at')::timestamptz < v_started_at THEN
        RAISE EXCEPTION 'Reporter/timestamp provenance was not preserved: %', v_payload;
    END IF;

    IF v_notes NOT LIKE ('%annual_task_id=' || v_session_task_id::text || '%')
       OR v_notes NOT LIKE ('%assignment_id=' || v_assignment_id::text || '%')
       OR v_notes NOT LIKE '%Procedure: Disposable #172 Procedure.pdf%' THEN
        RAISE EXCEPTION 'Promotion-surviving Setup provenance is incomplete: %', v_notes;
    END IF;

    SELECT count(*) INTO v_work_orders_after FROM ops.work_order;
    IF v_work_orders_after <> v_work_orders_before THEN
        RAISE EXCEPTION 'Report Correction preparation created an active Work Order';
    END IF;

    IF v_intake_payload ->> 'source_system' <> 'SETUP'
       OR v_intake_payload ->> 'source_form_name' <> 'SETUP_CORRECTION'
       OR v_intake_payload ->> 'triage_dropdown' <> '1'
       OR v_intake_payload ->> 'problem_raw' <> 'Disposable #172 validation finding' THEN
        RAISE EXCEPTION 'Prepared Directus Intake payload has incorrect lifecycle fields: %', v_intake_payload;
    END IF;

    BEGIN
        PERFORM *
        FROM ops.prepare_setup_work_order_intake(
            v_reporter_email,
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
        'ops.prepare_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)',
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

    IF NOT EXISTS (
        SELECT 1
        FROM public.directus_flows f
        WHERE f.name = 'WOI Request Triage Email'
          AND f.status = 'active'
          AND f.trigger = 'event'
          AND (f.options::jsonb ->> 'type') = 'action'
          AND (f.options::jsonb -> 'scope') ? 'items.create'
          AND (f.options::jsonb -> 'collections') ? 'work_order_intake'
    ) THEN
        RAISE EXCEPTION
            'Existing Directus WOI Request Triage Email items.create flow is missing/inactive';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.directus_operations o
        JOIN public.directus_flows f ON f.id = o.flow
        WHERE f.name = 'WOI Request Triage Email'
          AND o.type = 'mail'
    ) THEN
        RAISE EXCEPTION
            'Existing Directus WOI Request Triage Email flow has no mail operation';
    END IF;
END
$validation$;

ROLLBACK;
