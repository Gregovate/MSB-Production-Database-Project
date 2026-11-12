-- #88 / DBG-2026-007/009/010: C216 contents discrepancy, reported 2026-10-07.
-- Greg confirms only Peace on Earth was intended to leave C216 on October 6;
-- Mt. Crumpit panels remain physically loaded. Read evidence before any repair.
-- Safe for Production or its disposable clone: SELECT only inside READ ONLY.
-- Execute the whole script; retain all three result sets with database identity.
-- America/Chicago timestamps distinguish observation time from receipt time.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';

-- 1. Container/session identity and current Container observation.
SELECT current_database() AS database_name,
       ss.setup_session_id, ss.season_year, ss.session_status,
       c.container_id, c.description, c.location_code AS permanent_home,
       cs.movement_status, cs.last_movement_event_id,
       cs.last_movement_at AT TIME ZONE 'America/Chicago' AS movement_time_chicago,
       cs.current_stage_id, cs.current_location_note
FROM ref.container c
JOIN ops.setup_session ss ON ss.season_year = 2026
LEFT JOIN ops.setup_container_state cs
  ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = c.container_id
WHERE c.container_id = 216
ORDER BY ss.setup_session_id;

-- 2. Permanent assignment versus current attachment for every relevant Display.
-- Include inactive and differently assigned panels so API filtering is visible.
SELECT ss.setup_session_id, ss.session_status,
       d.display_id, d.display_name, d.container_id AS permanent_container,
       status.display_status_name AS display_status,
       ds.position_mode AS explicit_position_mode,
       coalesce(ds.position_mode, 'WITH_CONTAINER') AS effective_position_mode,
       (d.container_id = 216 AND upper(status.display_status_name) = 'ACTIVE'
         AND coalesce(ds.position_mode, 'WITH_CONTAINER') = 'WITH_CONTAINER'
         AND ss.session_status NOT IN ('COMPLETE', 'HISTORICAL_VERIFICATION'))
         AS included_in_c216_contents_api,
       ds.movement_status, ds.last_movement_event_id,
       ds.last_movement_at AT TIME ZONE 'America/Chicago' AS display_movement_time_chicago,
       ds.current_stage_id, ds.current_location_note,
       e.event_type AS last_display_event_type,
       e.container_id AS last_event_container,
       e.occurred_at AT TIME ZONE 'America/Chicago' AS last_observation_time_chicago,
       e.received_at AT TIME ZONE 'America/Chicago' AS last_receipt_time_chicago,
       e.notes AS last_event_notes
FROM ref.display d
LEFT JOIN ref.display_status status USING (display_status_id)
JOIN ops.setup_session ss ON ss.season_year = 2026
LEFT JOIN ops.setup_display_state ds
  ON ds.setup_session_id = ss.setup_session_id AND ds.display_id = d.display_id
LEFT JOIN ops.setup_movement_event e
  ON e.setup_movement_event_id = ds.last_movement_event_id
 AND e.setup_session_id = ss.setup_session_id
WHERE d.container_id = 216
   OR d.display_name ILIKE '%Mt%Crumpit%Panel%'
   OR d.display_name ILIKE '%Peace%On%Earth%'
ORDER BY ss.setup_session_id, d.display_name, d.display_id;

-- 3. Complete 2026 relevant event history, not just yesterday: retain earlier
-- attachment changes and late receipt of an October 6 offline observation.
-- DISPLAY_MOVE uses MOVED while detaching one Display; UNLOADED alone is not
-- the total detached count. Full names/effects show the actual command scope.
SELECT e.setup_session_id, e.setup_movement_event_id, e.event_type,
       e.occurred_at AT TIME ZONE 'America/Chicago' AS observed_time_chicago,
       e.received_at AT TIME ZONE 'America/Chicago' AS received_time_chicago,
       e.container_id, e.destination_stage_id, e.destination_location_note,
       e.capture_method, e.offline_captured, e.captured_operator_email,
       e.client_event_id, e.notes,
       count(med.display_id) AS affected_display_count,
       count(med.display_id) FILTER (WHERE med.movement_effect = 'UNLOADED')
         AS explicit_unloaded_effect_count,
       string_agg(d.display_name || ' [' || med.movement_effect || ']', E'\n'
         ORDER BY d.display_name, med.display_id) AS affected_display_names_and_effects
FROM ops.setup_movement_event e
JOIN ops.setup_session ss
  ON ss.setup_session_id = e.setup_session_id AND ss.season_year = 2026
LEFT JOIN ops.setup_movement_event_display med USING (setup_movement_event_id)
LEFT JOIN ref.display d ON d.display_id = med.display_id
WHERE e.container_id = 216
   OR EXISTS (
       SELECT 1 FROM ops.setup_movement_event_display relevant
       JOIN ref.display rd ON rd.display_id = relevant.display_id
       WHERE relevant.setup_movement_event_id = e.setup_movement_event_id
         AND (rd.container_id = 216
           OR rd.display_name ILIKE '%Mt%Crumpit%Panel%'
           OR rd.display_name ILIKE '%Peace%On%Earth%')
   )
GROUP BY e.setup_session_id, e.setup_movement_event_id, e.event_type,
         e.occurred_at, e.received_at, e.container_id, e.destination_stage_id,
         e.destination_location_note, e.capture_method, e.offline_captured,
         e.captured_operator_email, e.client_event_id, e.notes
ORDER BY e.occurred_at, e.setup_movement_event_id;

ROLLBACK;
