/* #175 / DBG-2026-001: read-only evidence gate on the disposable current clone.
   No migration, fixture writes, historical event rewrites, or reference cleanup.
   Browser review must exercise the actual field-context API and material panel. */
\set ON_ERROR_STOP on

BEGIN READ ONLY;
SET LOCAL ROLE fieldwiring_app;

DO $validation$
BEGIN
    IF NOT has_table_privilege(current_user, 'ops.setup_movement_event', 'SELECT')
       OR NOT has_table_privilege(current_user, 'ops.setup_display_state', 'SELECT')
       OR NOT has_table_privilege(current_user, 'ops.setup_container_state', 'SELECT') THEN
        RAISE EXCEPTION 'Application role lacks current movement read privileges';
    END IF;
    IF (SELECT count(*) FROM ref.display
        WHERE (container_id = 177 AND display_id IN (853,860,861))
           OR (container_id = 178 AND display_id IN (834,840,848))) <> 6 THEN
        RAISE EXCEPTION 'Steeple acceptance identities changed: inspect clone before review';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2026) THEN
        RAISE EXCEPTION 'Current clone has no 2026 annual Session';
    END IF;
    IF (SELECT count(DISTINCT cs.container_id)
        FROM ops.setup_container_state cs
        JOIN ops.setup_session ss USING (setup_session_id)
        JOIN ops.setup_movement_event me
          ON me.setup_movement_event_id = cs.last_movement_event_id
         AND me.setup_session_id = ss.setup_session_id
        WHERE ss.season_year = 2026 AND cs.container_id IN (177,178)) <> 2 THEN
        RAISE EXCEPTION 'C177/C178 current movement evidence missing: inspect clone before review';
    END IF;
END
$validation$;

-- Read the existing movement evidence as the actual application role. Do not
-- restrict an unload event to asset_type DISPLAY: its parent event can be Container.
SELECT d.display_id, d.display_name, d.container_id, ds.position_mode,
       CASE WHEN ds.position_mode = 'DETACHED' THEN ds.movement_status
            ELSE cs.movement_status END AS effective_movement_status,
       CASE WHEN ds.position_mode = 'DETACHED' THEN ds.last_movement_event_id
            ELSE cs.last_movement_event_id END AS effective_event_id,
       me.occurred_at, me.gps_latitude, me.gps_longitude, me.gps_accuracy_m,
       me.gps_fix_age_ms, me.gps_quality, me.capture_method,
       c.location_code AS home_location_code
FROM ref.display d
JOIN ref.container c ON c.container_id = d.container_id
JOIN ops.setup_session ss ON ss.season_year = 2026
LEFT JOIN ops.setup_display_state ds
  ON ds.setup_session_id = ss.setup_session_id AND ds.display_id = d.display_id
LEFT JOIN ops.setup_container_state cs
  ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = d.container_id
LEFT JOIN ops.setup_movement_event me
  ON me.setup_movement_event_id = CASE
      WHEN ds.position_mode = 'DETACHED' THEN ds.last_movement_event_id
      ELSE cs.last_movement_event_id END
 AND me.setup_session_id = ss.setup_session_id
WHERE d.display_id IN (834,840,848,853,860,861)
ORDER BY d.container_id, d.display_id;

ROLLBACK;
\echo SETUP_175_CURRENT_LOCATION_READONLY_VALIDATION_PASS
