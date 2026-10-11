-- #88 / DBG-2026-007/009/010, 2026-10-07: broad Container-drop/unload review.
-- Greg reports that "unload Container" was interpreted as taking the loaded
-- Container off the truck at park staging; many scans detached Displays that
-- physically remained loaded. C216 event 122 is one established example.
-- Report ALL 2026 grouped Container unloads, with actor/date/scope visible.
-- A listed event is a review candidate, not proof of an incorrect physical unload.
-- Execute against Production msb. SELECT only; no corrections or migrations.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';

-- 1. Scope by actor and Chicago observation date. This avoids silently choosing
-- between two Tom actors seen in C216's history, or missing other affected scans.
SELECT current_database() AS database_name,
       ss.setup_session_id, ss.session_status,
       coalesce(nullif(e.captured_operator_email, ''), '(not recorded)') AS recorded_operator,
       (e.occurred_at AT TIME ZONE 'America/Chicago')::date AS observed_date_chicago,
       count(DISTINCT e.setup_movement_event_id) AS container_scan_events_with_detach,
       count(DISTINCT e.container_id) AS containers_to_review,
       count(med.display_id) AS unloaded_display_effects,
       count(med.display_id) FILTER (
         WHERE ds.position_mode = 'DETACHED'
           AND ds.last_movement_event_id = e.setup_movement_event_id
       ) AS displays_still_detached_by_these_events
FROM ops.setup_movement_event e
JOIN ops.setup_session ss
  ON ss.setup_session_id = e.setup_session_id AND ss.season_year = 2026
JOIN ops.setup_movement_event_display med
  ON med.setup_movement_event_id = e.setup_movement_event_id AND med.movement_effect = 'UNLOADED'
LEFT JOIN ops.setup_display_state ds
  ON ds.setup_session_id = e.setup_session_id AND ds.display_id = med.display_id
WHERE e.event_type = 'CONTAINER_MOVE'
GROUP BY ss.setup_session_id, ss.session_status, e.captured_operator_email,
         (e.occurred_at AT TIME ZONE 'America/Chicago')::date
ORDER BY observed_date_chicago, recorded_operator, ss.setup_session_id;

-- 2. Exact event/Container/Display scope and present state. Preserve even those
-- whose current state has since changed. Names support captain/physical review.
SELECT e.setup_session_id, e.setup_movement_event_id, e.container_id,
       c.description AS container_name, ct.container_type_name,
       e.occurred_at AT TIME ZONE 'America/Chicago' AS observed_time_chicago,
       e.received_at AT TIME ZONE 'America/Chicago' AS received_time_chicago,
       e.captured_operator_email, e.capture_method, e.offline_captured,
       e.destination_location_note,
       (e.gps_latitude IS NOT NULL AND e.gps_longitude IS NOT NULL) AS has_gps,
       round(e.gps_accuracy_m / 0.3048) AS gps_accuracy_feet,
       e.client_event_id, e.notes,
       count(med.display_id) AS unloaded_display_count,
       count(med.display_id) FILTER (
         WHERE ds.position_mode = 'DETACHED'
           AND ds.last_movement_event_id = e.setup_movement_event_id
       ) AS still_detached_by_this_event,
       string_agg(d.display_name || ' [current ' || coalesce(ds.position_mode, 'NO STATE')
         || '; last event ' || coalesce(ds.last_movement_event_id::text, 'none')
         || '; permanent C' || coalesce(d.container_id::text, 'none') || ']', E'\n'
         ORDER BY d.display_name, med.display_id) AS display_names_and_current_state
FROM ops.setup_movement_event e
JOIN ops.setup_session ss
  ON ss.setup_session_id = e.setup_session_id AND ss.season_year = 2026
JOIN ops.setup_movement_event_display med
  ON med.setup_movement_event_id = e.setup_movement_event_id AND med.movement_effect = 'UNLOADED'
JOIN ref.display d ON d.display_id = med.display_id
LEFT JOIN ref.container c ON c.container_id = e.container_id
LEFT JOIN ref.container_type ct USING (container_type_id)
LEFT JOIN ops.setup_display_state ds
  ON ds.setup_session_id = e.setup_session_id AND ds.display_id = med.display_id
WHERE e.event_type = 'CONTAINER_MOVE'
GROUP BY e.setup_session_id, e.setup_movement_event_id, e.container_id,
         c.description, ct.container_type_name, e.occurred_at, e.received_at,
         e.captured_operator_email, e.capture_method, e.offline_captured,
         e.destination_location_note, e.gps_latitude, e.gps_longitude,
         e.gps_accuracy_m, e.client_event_id, e.notes
ORDER BY e.occurred_at, e.setup_movement_event_id;

ROLLBACK;
