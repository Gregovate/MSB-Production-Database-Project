-- #175 / DBG-2026-001: inspect the Elf Choir examples without changing records.
-- Pick history proves a recorded action, not an unrecorded physical movement.
BEGIN READ ONLY;

-- Container state and recorded Pick history for this season.
SELECT c.container_id, c.description,
       cs.movement_status AS last_recorded_status,
       me.occurred_at AT TIME ZONE 'America/Chicago' AS recorded_local,
       EXISTS (
           SELECT 1 FROM ops.setup_movement_event p
           WHERE p.setup_session_id = ss.setup_session_id
             AND p.container_id = c.container_id AND p.event_type = 'PICKED'
       ) AS pick_recorded_this_session,
       s.stage_name AS recorded_stage, cs.current_location_note,
       me.gps_latitude, me.gps_longitude,
       me.source_location_code AS recorded_pick_source,
       c.location_code AS home_reference
FROM ref.container c
JOIN ops.setup_session ss ON ss.season_year = 2026
LEFT JOIN ops.setup_container_state cs
  ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = c.container_id
LEFT JOIN ops.setup_movement_event me
  ON me.setup_movement_event_id = cs.last_movement_event_id
 AND me.setup_session_id = ss.setup_session_id
LEFT JOIN ref.stage s ON s.stage_id = cs.current_stage_id
WHERE c.container_id IN (15, 60, 122)
ORDER BY c.container_id;

-- Display state may differ: detached Displays retain their own movement event.
SELECT d.display_id, d.display_name, d.container_id, ds.position_mode,
       CASE WHEN ds.position_mode = 'DETACHED' THEN ds.movement_status
            ELSE cs.movement_status END AS effective_recorded_status,
       me.occurred_at AT TIME ZONE 'America/Chicago' AS recorded_local,
       CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_location_note
            ELSE cs.current_location_note END AS current_location_note,
       me.gps_latitude, me.gps_longitude, me.source_location_code AS recorded_pick_source
FROM ref.display d
JOIN ops.setup_session ss ON ss.season_year = 2026
LEFT JOIN ops.setup_display_state ds
  ON ds.setup_session_id = ss.setup_session_id AND ds.display_id = d.display_id
LEFT JOIN ops.setup_container_state cs
  ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = d.container_id
LEFT JOIN ops.setup_movement_event me
  ON me.setup_movement_event_id = CASE WHEN ds.position_mode = 'DETACHED'
       THEN ds.last_movement_event_id ELSE cs.last_movement_event_id END
 AND me.setup_session_id = ss.setup_session_id
WHERE d.container_id = 15 OR d.display_id = 525
ORDER BY d.container_id, d.display_id;

COMMIT;
