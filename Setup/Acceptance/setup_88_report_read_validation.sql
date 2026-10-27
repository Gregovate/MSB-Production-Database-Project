-- #88 READ ONLY validation. Exact SELECTs must match movement_picture source.
BEGIN READ ONLY;
DO $$ BEGIN
 IF NOT has_column_privilege('fieldwiring_app','ref.container_type','container_type_id','SELECT')
 OR NOT has_column_privilege('fieldwiring_app','ref.container_type','container_type_name','SELECT')
 OR has_table_privilege('fieldwiring_app','ref.container_type','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
 OR EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid='ref.container_type'::regclass AND attnum>0 AND NOT attisdropped
   AND attname NOT IN ('container_type_id','container_type_name')
   AND has_column_privilege('fieldwiring_app','ref.container_type',attname,'SELECT'))
 OR EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid='ref.container_type'::regclass AND attnum>0 AND NOT attisdropped
   AND has_column_privilege('fieldwiring_app','ref.container_type',attname,'INSERT,UPDATE,REFERENCES'))
 THEN RAISE EXCEPTION 'Container type two-column read boundary failed'; END IF;
END $$;
SET LOCAL ROLE fieldwiring_app;
SELECT setup_session_id AS report_session_id FROM ops.setup_session WHERE season_year=2026 ORDER BY setup_session_id DESC LIMIT 1;\gset
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';
SELECT count(*) FROM (
                SELECT current_database() AS database_name,
                       transaction_timestamp() AS generated_at,
                       coalesce(max(setup_movement_event_id),0) AS through_event_id
                FROM ops.setup_movement_event WHERE setup_session_id = :report_session_id
            ) AS report_probe;
SELECT count(*) FROM (
                SELECT e.setup_movement_event_id, e.event_type, e.container_id,
                       c.description AS container_name, e.occurred_at, e.received_at,
                       e.destination_stage_id, s.stage_key, s.stage_name,
                       e.destination_location_note, e.gps_latitude, e.gps_longitude,
                       e.gps_accuracy_m, e.gps_quality, e.gps_fix_age_ms,
                       e.capture_method, e.offline_captured,
                       e.captured_operator_email, e.notes,
                       med.display_id, d.display_name, med.movement_effect
                FROM ops.setup_movement_event e
                LEFT JOIN ref.container c ON c.container_id=e.container_id
                LEFT JOIN ref.stage s ON s.stage_id=e.destination_stage_id
                LEFT JOIN ops.setup_movement_event_display med USING (setup_movement_event_id)
                LEFT JOIN ref.display d ON d.display_id=med.display_id
                WHERE e.setup_session_id=:report_session_id
                ORDER BY e.occurred_at,e.setup_movement_event_id,med.display_id
            ) AS report_probe;
SELECT count(*) FROM (
                SELECT cs.container_id, c.description AS container_name,
                       ct.container_type_name, c.location_code AS home_location_code,
                       cs.last_movement_event_id, cs.movement_status,
                       cs.current_stage_id, s.stage_key, s.stage_name,
                       cs.current_location_note
                FROM ops.setup_container_state cs
                JOIN ref.container c USING (container_id)
                LEFT JOIN ref.container_type ct USING (container_type_id)
                LEFT JOIN ref.stage s ON s.stage_id=cs.current_stage_id
                WHERE cs.setup_session_id=:report_session_id ORDER BY cs.container_id
            ) AS report_probe;
SELECT count(*) FROM (
                SELECT d.display_id, d.display_name, d.container_id,
                       coalesce(ds.position_mode,CASE WHEN d.container_id IS NULL
                         THEN 'NO_ASSIGNED_CONTAINER' ELSE 'WITH_CONTAINER' END) AS position_mode,
                       ds.last_movement_event_id, ds.current_stage_id,
                       s.stage_key, s.stage_name, ds.current_location_note
                FROM ref.display d
                JOIN ref.display_status st USING (display_status_id)
                LEFT JOIN ops.setup_display_state ds
                  ON ds.display_id=d.display_id AND ds.setup_session_id=:report_session_id
                LEFT JOIN ref.stage s ON s.stage_id=ds.current_stage_id
                WHERE upper(st.display_status_name)='ACTIVE'
                ORDER BY d.display_name,d.display_id
            ) AS report_probe;
ROLLBACK;
SELECT 'Container Movement exact application-role reads: PASS';
