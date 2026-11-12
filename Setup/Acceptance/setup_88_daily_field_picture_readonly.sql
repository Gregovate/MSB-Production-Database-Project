-- #88 / #122: reusable synced field picture. Run the WHOLE script in the
-- existing SQL client against msb. Change only report_day for another day.
-- Default is Oct 7, 2026 (America/Chicago), not the workstation/server UTC date.
-- This report DOES NOT know unrecorded work or unsynced tablet queues.
-- Recorded attachment counts are not physical Empty confirmations.
-- Four result sets: day summary, chronological evidence, current recorded
-- Container/Display picture, explicit review flags (no resolution UI exists yet).
-- Current picture is captured AT QUERY TIME, not reconstructed as of report_day.
-- One row per affected Display / current Display avoids truncated aggregate names.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';
SET LOCAL msb.report_day = '2026-10-07';

-- 1. Day summary. Distinguish observed that day from received that day; late
-- offline observations received today may describe an earlier physical day.
WITH scoped AS (
 SELECT e.*, ss.session_status,
        (e.occurred_at AT TIME ZONE 'America/Chicago')::date AS observed_day,
        (e.received_at AT TIME ZONE 'America/Chicago')::date AS received_day
 FROM ops.setup_movement_event e
 JOIN ops.setup_session ss USING (setup_session_id)
 WHERE ss.season_year = 2026
), selected AS (
 SELECT * FROM scoped
 WHERE observed_day = current_setting('msb.report_day')::date
    OR received_day = current_setting('msb.report_day')::date
)
SELECT current_database() AS database_name,
       current_setting('msb.report_day')::date AS report_day_chicago,
       transaction_timestamp() AT TIME ZONE 'America/Chicago' AS report_generated_chicago,
       setup_session_id, session_status, event_type,
       coalesce(nullif(captured_operator_email,''),'(not recorded)') AS recorded_operator,
       count(*) FILTER (WHERE observed_day = current_setting('msb.report_day')::date) AS observations_on_report_day,
       count(*) FILTER (WHERE received_day = current_setting('msb.report_day')::date) AS receipts_on_report_day,
       count(*) FILTER (WHERE received_day = current_setting('msb.report_day')::date
                          AND observed_day <> current_setting('msb.report_day')::date) AS other_day_observations_received,
       count(*) FILTER (WHERE offline_captured) AS offline_captured_events,
       count(*) FILTER (WHERE notes LIKE '%contents_review_required=true%') AS explicit_review_flags
FROM selected
GROUP BY setup_session_id, session_status, event_type, captured_operator_email
ORDER BY setup_session_id, recorded_operator, event_type;

-- 2. Timeline: one row per effect (or one row for a Container-only event).
-- A blank destination note with GPS is not missing location. UNLOADED means
-- recorded Display detachment; LOADED status does not implement reattachment.
SELECT e.setup_session_id, e.setup_movement_event_id, e.event_type,
       e.container_id, c.description AS container_name,
       e.occurred_at AT TIME ZONE 'America/Chicago' AS observed_time_chicago,
       e.received_at AT TIME ZONE 'America/Chicago' AS received_time_chicago,
       e.captured_operator_email, e.capture_method, e.offline_captured,
       e.destination_stage_id, s.stage_name AS destination_stage_name,
       e.destination_location_note,
       (e.gps_latitude IS NOT NULL AND e.gps_longitude IS NOT NULL) AS has_gps,
       round(e.gps_accuracy_m / 0.3048) AS gps_accuracy_feet,
       med.display_id, d.display_name, med.movement_effect,
       ds.position_mode AS current_recorded_display_mode,
       ds.last_movement_event_id AS current_display_last_event,
       (ds.last_movement_event_id = e.setup_movement_event_id) AS effect_still_latest_display_event,
       e.client_event_id, e.notes
FROM ops.setup_movement_event e
JOIN ops.setup_session ss USING (setup_session_id)
LEFT JOIN ref.container c ON c.container_id = e.container_id
LEFT JOIN ref.stage s ON s.stage_id = e.destination_stage_id
LEFT JOIN ops.setup_movement_event_display med USING (setup_movement_event_id)
LEFT JOIN ref.display d ON d.display_id = med.display_id
LEFT JOIN ops.setup_display_state ds ON ds.setup_session_id = e.setup_session_id AND ds.display_id = med.display_id
WHERE ss.season_year = 2026
  AND ((e.occurred_at AT TIME ZONE 'America/Chicago')::date = current_setting('msb.report_day')::date
    OR (e.received_at AT TIME ZONE 'America/Chicago')::date = current_setting('msb.report_day')::date)
ORDER BY e.occurred_at, e.setup_movement_event_id, d.display_name, med.display_id;

-- 3. Current recorded picture, including zero-assignment Containers and Displays
-- with no permanent Container. Permanent assignment is NOT proof of actual load.
-- Prior named context is shown separately with provenance (C095-style continuity).
WITH active_displays AS (
 SELECT d.* FROM ref.display d JOIN ref.display_status st USING (display_status_id)
 WHERE upper(st.display_status_name) = 'ACTIVE'
), picture AS (
 SELECT ss.setup_session_id, ss.session_status,
        c.container_id, c.description AS container_name, ct.container_type_name,
        cs.movement_status AS container_movement_status,
        cs.last_movement_event_id AS container_last_event,
        e.occurred_at AT TIME ZONE 'America/Chicago' AS container_last_observed_chicago,
        e.received_at AT TIME ZONE 'America/Chicago' AS container_last_received_chicago,
        cs.current_stage_id AS container_recorded_stage_id,
        cs.current_location_note AS container_recorded_location_note,
        n.destination_location_note AS prior_named_context,
        n.setup_movement_event_id AS prior_named_context_event,
        (e.gps_latitude IS NOT NULL AND e.gps_longitude IS NOT NULL) AS container_has_gps,
        round(e.gps_accuracy_m / 0.3048) AS container_gps_accuracy_feet,
        d.display_id, d.display_name,
        CASE WHEN ds.position_mode IS NOT NULL THEN ds.position_mode
             WHEN c.container_id IS NOT NULL AND d.display_id IS NOT NULL THEN 'WITH_CONTAINER'
             WHEN d.display_id IS NOT NULL THEN 'NO_ASSIGNED_CONTAINER'
             ELSE 'NO_ACTIVE_ASSIGNMENT' END AS recorded_position_mode,
        ds.last_movement_event_id AS display_last_event,
        ds.current_stage_id AS display_recorded_stage_id,
        ds.current_location_note AS display_recorded_location_note,
        flags.explicit_review_flag_count
 FROM ref.container c FULL JOIN active_displays d ON d.container_id = c.container_id
 CROSS JOIN ops.setup_session ss
 LEFT JOIN ref.container_type ct ON ct.container_type_id = c.container_type_id
 LEFT JOIN ops.setup_container_state cs ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = c.container_id
 LEFT JOIN ops.setup_movement_event e ON e.setup_movement_event_id = cs.last_movement_event_id
 LEFT JOIN ops.setup_display_state ds ON ds.setup_session_id = ss.setup_session_id AND ds.display_id = d.display_id
 LEFT JOIN LATERAL (
   SELECT h.destination_location_note, h.setup_movement_event_id
   FROM ops.setup_movement_event h
   WHERE h.setup_session_id = ss.setup_session_id AND h.container_id = c.container_id
     AND (h.occurred_at,h.setup_movement_event_id) <= (e.occurred_at,e.setup_movement_event_id)
     AND nullif(btrim(h.destination_location_note),'') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM ops.setup_movement_event r
                     WHERE r.setup_session_id = h.setup_session_id AND r.container_id = h.container_id
                       AND r.event_type = 'RETURNED' AND r.occurred_at >= h.occurred_at AND r.occurred_at <= e.occurred_at)
   ORDER BY h.occurred_at DESC,h.setup_movement_event_id DESC LIMIT 1
 ) n ON true
 LEFT JOIN LATERAL (
   SELECT count(*) AS explicit_review_flag_count FROM ops.setup_movement_event f
   WHERE f.setup_session_id = ss.setup_session_id AND f.container_id = c.container_id
     AND f.notes LIKE '%contents_review_required=true%'
 ) flags ON true
 WHERE ss.season_year = 2026 AND ss.session_status NOT IN ('COMPLETE','HISTORICAL_VERIFICATION')
), counted AS (
 SELECT picture.*,
        count(display_id) OVER w AS expected_active_assignment_count,
        count(display_id) FILTER (WHERE recorded_position_mode = 'WITH_CONTAINER') OVER w AS tracked_attached_count,
        count(display_id) FILTER (WHERE recorded_position_mode = 'DETACHED') OVER w AS tracked_detached_count
 FROM picture
 WINDOW w AS (PARTITION BY setup_session_id,container_id)
)
SELECT counted.*,
       CASE WHEN container_id IS NULL THEN 'No permanent Container; counts for this NULL group are not a physical load'
            WHEN container_type_name = 'Standalone Display' AND tracked_detached_count > 0 THEN 'REVIEW: Standalone Display recorded detached'
            WHEN container_type_name IN ('Display Pallet','Display-Pallet') AND expected_active_assignment_count = 1 AND tracked_detached_count > 0 THEN 'REVIEW: singular Display Pallet recorded detached'
            WHEN explicit_review_flag_count > 0 THEN 'Review flag exists; no resolution tool is implemented'
            ELSE 'Recorded state only; no physical verification inferred by this report' END AS review_basis
FROM counted
ORDER BY setup_session_id,container_id NULLS LAST,display_name,display_id;

-- 4. Explicit review flags at ANY earlier stop: retained even if the Container
-- moved later. Zero flags is NOT proof of verified contents (legacy scans lack
-- this new marker). No resolution/closed-state consumer is implemented yet.
SELECT e.setup_session_id, e.setup_movement_event_id AS flagged_event,
       e.container_id, c.description AS container_name,
       e.occurred_at AT TIME ZONE 'America/Chicago' AS flagged_observed_chicago,
       e.received_at AT TIME ZONE 'America/Chicago' AS flagged_received_chicago,
       e.captured_operator_email, e.destination_location_note AS flagged_named_location,
       round(e.gps_accuracy_m / 0.3048) AS flagged_gps_accuracy_feet,
       cs.last_movement_event_id AS current_container_event,
       (SELECT count(*) FROM ops.setup_movement_event later
        WHERE later.setup_session_id = e.setup_session_id AND later.container_id = e.container_id
          AND (later.occurred_at,later.setup_movement_event_id) > (e.occurred_at,e.setup_movement_event_id)) AS later_container_events,
       e.notes, 'Flag evidence only; physical resolution may require a reliable report or visit' AS review_limitation
FROM ops.setup_movement_event e
JOIN ops.setup_session ss USING (setup_session_id)
LEFT JOIN ref.container c ON c.container_id = e.container_id
LEFT JOIN ops.setup_container_state cs ON cs.setup_session_id = e.setup_session_id AND cs.container_id = e.container_id
WHERE ss.season_year = 2026 AND e.notes LIKE '%contents_review_required=true%'
ORDER BY e.occurred_at,e.setup_movement_event_id;

ROLLBACK;
