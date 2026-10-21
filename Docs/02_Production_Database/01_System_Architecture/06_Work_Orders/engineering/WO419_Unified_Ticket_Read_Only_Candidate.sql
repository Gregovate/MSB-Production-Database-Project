-- WO419-M01 | Unified Intake + Work Order ticket ledger | READ ONLY
-- #419 SOURCE-ONLY MODEL CANDIDATE; original version ran in Production DBeaver.
-- This amended person-scope/test-provenance revision has NOT been re-run.
-- PostgreSQL remains authoritative; this SELECT creates NO tables/views.
-- Query only with an authorized Manager/read-only identity.
--
-- Live-source evidence as of 2026-10-18:
--   ops.work_order (urgency_id, source_intake_id, completion fields)
--   ops.work_order_assignment (active_flag, person_id, role, history)
--   ops.work_order_status_history and ref.work_order_status
--   stage.work_order_intake (triage_dropdown, original free-form notes)
-- Intake triage process '3' promotes then DELETES Intake; '4' DELETES Intake.
-- Thus original promoted/denied Intake rows are NOT recoverable here.
-- Do not call promotion or reject paths merely to test this SELECT.
-- No Work Order outbound message or notification is sent by this query.
-- opened_at is native ops.work_order.created_at, never updated_at/assignment date.
-- Pending human Intake has opened_at NULL in this WO aging context.
--
-- This query is a backend read-model SPIKE for future protected app API.
-- NOT an application permission boundary: app must enforce the current
-- authenticated Person/Manager rights before serving ticket data.
-- No Production rollout or browser approval is implied.
-- App read-scope requirements:
--   My Work defaults to ACTIVE assignee person_id = signed-in ref.person,
--   is_active=true and date_completed IS NULL. Exact person IDs are mandatory;
--   do not filter by human name, reporter or created_by.
--   Selecting another person/All is explicit and reader-role-checked by API.
--   Show completed is an INDEPENDENT status filter.
-- Test repair origin: display_test_session_id, display_id; never fabricate
-- a human reporter or Intake merely because Testing generated a Work Order.

WITH assignment_rollup AS (
    SELECT
        a.work_order_id,
        count(*) FILTER (WHERE a.active_flag) AS active_assignee_count,
        string_agg(
            DISTINCT CASE WHEN a.active_flag THEN
                COALESCE(
                    NULLIF(
                        btrim(concat_ws(' ',
                            COALESCE(
                                NULLIF(btrim(p.preferred_name), ''),
                                NULLIF(btrim(p.first_name), '')
                            ),
                            NULLIF(btrim(p.last_name), '')
                        )),
                        ''
                    ),
                    'Person #' || a.person_id::text
                )
            ELSE NULL END,
            ', '
        ) AS active_assignees,
        array_agg(DISTINCT a.person_id ORDER BY a.person_id)
            FILTER (WHERE a.active_flag) AS active_assignee_person_ids,
        max(a.updated_at) AS latest_assignment_change
    FROM ops.work_order_assignment a
    LEFT JOIN ref.person p ON p.person_id = a.person_id
    GROUP BY a.work_order_id
),
latest_wo_status AS (
    SELECT DISTINCT ON (h.work_order_id)
        h.work_order_id,
        s.status_key,
        s.status_name,
        s.is_terminal,
        h.changed_at AS status_at
    FROM ops.work_order_status_history h
    JOIN ref.work_order_status s
      ON s.work_order_status_id = h.work_order_status_id
    ORDER BY h.work_order_id,
             h.changed_at DESC,
             h.work_order_status_history_id DESC
),
all_tickets AS (
    SELECT
        'WORK_ORDER'::text AS ticket_type,
        ('WO-' || w.work_order_id::text) AS ticket_key,
        w.work_order_id,
        w.source_intake_id AS intake_id,
        w.display_test_session_id AS test_detail_id,
        w.display_id AS display_id,
        COALESCE(source_intake.submitter_person_id,w.submitted_by_person_id) AS reporter_person_id,
        w.problem::text AS summary,
        COALESCE(w.source_form_name, w.source_system,
                 'NOT_RECORDED')::text AS source_name,
        CASE
            WHEN st.status_key IS NOT NULL THEN st.status_key
            WHEN w.date_completed IS NOT NULL THEN 'DONE_DATE_ONLY'
            ELSE 'STATUS_NOT_RECORDED'
        END::text AS current_state,
        CASE
            WHEN st.status_key IS NOT NULL THEN 'WORK_ORDER_STATUS_HISTORY'
            WHEN w.date_completed IS NOT NULL THEN 'DATE_COMPLETED'
            ELSE 'NO_STATUS_RECORD'
        END::text AS state_source,
        w.urgency_id,
        w.target_year,
        COALESCE(
            CASE WHEN w.stage_id IS NOT NULL
                 THEN concat_ws(' — ',
                        'Stage ' || s.stage_key,
                        s.stage_name)
            END,
            wa.work_area_name,
            'LOCATION_NOT_RECORDED'
        )::text AS place,
        COALESCE(ar.active_assignees, 'UNASSIGNED')::text AS assigned_to,
        ar.active_assignee_count,
        ar.active_assignee_person_ids,
        COALESCE(
            NULLIF(btrim(concat_ws(' ',
                COALESCE(NULLIF(btrim(sub.preferred_name), ''),
                         NULLIF(btrim(sub.first_name), '')),
                NULLIF(btrim(sub.last_name), '')
            )), ''),
            CASE WHEN w.submitted_by_person_id IS NOT NULL
                 THEN 'Person #' || w.submitted_by_person_id::text
                 ELSE 'NOT_RECORDED'
            END
        )::text AS reporter,
        GREATEST(w.updated_at,
                 ar.latest_assignment_change,
                 st.status_at) AS latest_activity_at,
        w.created_at AS opened_at,
        w.date_completed AS done_at,
        w.is_active,
        CASE
            WHEN st.status_key = 'DONE' AND w.date_completed IS NULL
                 THEN 'DONE_STATUS_WITHOUT_COMPLETION_DATE'
            WHEN w.date_completed IS NOT NULL
                 AND st.status_key IS NOT NULL
                 AND st.status_key NOT IN ('DONE')
                 THEN 'COMPLETION_DATE_DIFFERS_FROM_STATUS_HISTORY'
            ELSE NULL
        END::text AS integrity_note
    FROM ops.work_order w
    LEFT JOIN ref.stage s ON s.stage_id = w.stage_id
    LEFT JOIN ref.work_area wa ON wa.work_area_id = w.work_area_id
    LEFT JOIN stage.work_order_intake source_intake ON source_intake.intake_id=w.source_intake_id
    LEFT JOIN ref.person sub ON sub.person_id = COALESCE(source_intake.submitter_person_id,w.submitted_by_person_id)
    LEFT JOIN assignment_rollup ar ON ar.work_order_id = w.work_order_id
    LEFT JOIN latest_wo_status st ON st.work_order_id = w.work_order_id

    UNION ALL

    SELECT
        CASE WHEN i.source_form_name = 'SETUP_CORRECTION'
             THEN 'TASK_FEEDBACK' ELSE 'INTAKE_REQUEST'
        END::text AS ticket_type,
        ('INTAKE-' || i.intake_id::text) AS ticket_key,
        NULL::bigint AS work_order_id,
        i.intake_id,
        NULL::bigint AS test_detail_id,
        NULL::bigint AS display_id,
        i.submitter_person_id AS reporter_person_id,
        i.problem_raw::text AS summary,
        COALESCE(i.source_form_name, i.source_system)::text AS source_name,
        CASE
            WHEN i.triage_dropdown = '1' THEN 'SUBMITTED'
            WHEN i.triage_dropdown IS NULL THEN 'TRIAGE_UNSET'
            ELSE 'INTAKE_VALUE_' || i.triage_dropdown
        END::text AS current_state,
        'INTAKE_TRIAGE_DROPDOWN'::text AS state_source,
        i.urgency_id,
        i.target_year,
        COALESCE(
            CASE WHEN i.stage_id IS NOT NULL
                 THEN concat_ws(' — ',
                        'Stage ' || s.stage_key,
                        s.stage_name)
            END,
            wa.work_area_name,
            NULLIF(btrim(i.stage_raw), ''),
            NULLIF(btrim(i.work_area_raw), ''),
            'LOCATION_NOT_RECORDED'
        )::text AS place,
        'CORRECTION_OWNER_NOT_TRACKED'::text AS assigned_to,
        NULL::bigint AS active_assignee_count,
        NULL::integer[] AS active_assignee_person_ids,
        COALESCE(
            NULLIF(btrim(concat_ws(' ',
                COALESCE(NULLIF(btrim(sub.preferred_name), ''),
                         NULLIF(btrim(sub.first_name), '')),
                NULLIF(btrim(sub.last_name), '')
            )), ''),
            NULLIF(btrim(i.submitter_name_raw), ''),
            CASE WHEN i.submitter_person_id IS NOT NULL
                 THEN 'Person #' || i.submitter_person_id::text
                 ELSE 'NOT_RECORDED'
            END
        )::text AS reporter,
        i.updated_at AS latest_activity_at,
        NULL::timestamptz AS opened_at,
        NULL::timestamptz AS done_at,
        true AS is_active,
        NULL::text AS integrity_note
    FROM stage.work_order_intake i
    LEFT JOIN ref.stage s ON s.stage_id = i.stage_id
    LEFT JOIN ref.work_area wa ON wa.work_area_id = i.work_area_id
    LEFT JOIN ref.person sub ON sub.person_id = i.submitter_person_id
)
SELECT
    ticket_type AS type,
    ticket_key AS ticket,
    work_order_id AS wo_id,
    intake_id AS in_id,
    test_detail_id AS test_id,
    display_id AS disp_id,
    reporter_person_id AS reporter_id,
    summary AS title,
    current_state AS state,
    state_source AS state_from,
    source_name AS source,
    urgency_id AS urgency,
    target_year AS yr,
    place AS location,
    assigned_to AS owners,
    active_assignee_count AS assigned_n,
    active_assignee_person_ids AS assignee_ids,
    reporter AS reported_by,
    latest_activity_at AS last_at,
    opened_at,
    done_at,
    is_active AS active,
    integrity_note AS review_flag
FROM all_tickets
ORDER BY latest_activity_at DESC NULLS LAST,
         ticket_key;
