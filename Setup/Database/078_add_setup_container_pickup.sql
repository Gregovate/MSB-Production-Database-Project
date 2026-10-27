-- #88 bounded collection requests; no contents or physical movement mutation.
BEGIN;
CREATE TABLE ops.setup_container_pickup_event (
 pickup_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 setup_session_id bigint NOT NULL REFERENCES ops.setup_session(setup_session_id),
 container_id integer NOT NULL REFERENCES ref.container(container_id),
 action text NOT NULL CHECK(action IN ('REQUEST','CANCEL')),
 stage_id integer REFERENCES ref.stage(stage_id),
 location_note text,
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 operator_email text NOT NULL,
 client_event_id uuid NOT NULL UNIQUE,
 request_data jsonb NOT NULL,
 CHECK(action='CANCEL' OR (stage_id IS NOT NULL AND length(btrim(location_note)) BETWEEN 1 AND 240))
);
CREATE INDEX ix_setup_container_pickup_latest ON ops.setup_container_pickup_event
 (setup_session_id,container_id,pickup_event_id DESC);
REVOKE ALL ON ops.setup_container_pickup_event FROM PUBLIC,fieldwiring_app;
GRANT SELECT ON ops.setup_container_pickup_event TO fieldwiring_app;
CREATE FUNCTION ops.record_setup_container_pickup(p_email text,p_year integer,p_uuid uuid,
 p_container integer,p_action text,p_stage integer,p_location text,p_empty boolean)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ops,ref AS $$
DECLARE actor record; sid bigint; old ops.setup_container_pickup_event%ROWTYPE; data jsonb; eid bigint;
BEGIN
 SELECT * INTO STRICT actor FROM ref.setup_movement_actor(p_email);
 IF p_uuid IS NULL OR p_action IS NULL OR p_action NOT IN ('REQUEST','CANCEL') THEN
  RAISE EXCEPTION 'Invalid pickup command' USING ERRCODE='22023';
 END IF;
 IF p_action='REQUEST' AND (p_empty IS DISTINCT FROM true OR p_stage IS NULL OR
   coalesce(length(btrim(p_location)),0) NOT BETWEEN 1 AND 240) THEN
  RAISE EXCEPTION 'Confirm empty container, Stage and pickup location' USING ERRCODE='22023';
 END IF;
 SELECT setup_session_id INTO STRICT sid FROM ops.setup_session
 WHERE season_year=p_year AND session_status NOT IN ('COMPLETE','HISTORICAL_VERIFICATION');
 data=jsonb_build_array(lower(btrim(p_email)),p_year,p_container,p_action,p_stage,p_location,p_empty);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_uuid::text,88078));
 SELECT * INTO old FROM ops.setup_container_pickup_event WHERE client_event_id=p_uuid;
 IF FOUND THEN
  IF old.request_data IS DISTINCT FROM data THEN
   RAISE EXCEPTION 'Pickup retry has different data' USING ERRCODE='23505';
  END IF;
  RETURN old.pickup_event_id;
 END IF;
 INSERT INTO ops.setup_container_pickup_event(setup_session_id,container_id,action,stage_id,
 location_note,operator_email,client_event_id,request_data)
 VALUES(sid,p_container,p_action,p_stage,nullif(btrim(p_location),''),lower(btrim(p_email)),p_uuid,data)
 RETURNING pickup_event_id INTO eid;
 RETURN eid;
END $$;
REVOKE ALL ON FUNCTION ops.record_setup_container_pickup(text,integer,uuid,integer,text,integer,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_container_pickup(text,integer,uuid,integer,text,integer,text,boolean) TO fieldwiring_app;
CREATE VIEW ops.setup_container_pickup_list AS
WITH latest AS (
 SELECT DISTINCT ON (setup_session_id,container_id) * FROM ops.setup_container_pickup_event
 ORDER BY setup_session_id,container_id,pickup_event_id DESC
)
SELECT p.pickup_event_id,p.setup_session_id,ss.season_year,p.container_id,
 coalesce(m.destination_stage_id,p.stage_id) AS stage_id,
 s.stage_key,s.stage_name,coalesce(nullif(btrim(m.destination_location_note),''),p.location_note) AS location_note,
 p.requested_at,p.operator_email
FROM latest p JOIN ops.setup_session ss USING(setup_session_id)
LEFT JOIN LATERAL (
 SELECT e.destination_stage_id,e.destination_location_note FROM ops.setup_movement_event e
 WHERE e.setup_session_id=p.setup_session_id AND e.container_id=p.container_id
 AND e.occurred_at>=p.requested_at
 AND (e.destination_stage_id IS NOT NULL OR nullif(btrim(e.destination_location_note),'') IS NOT NULL)
 ORDER BY e.occurred_at DESC,e.setup_movement_event_id DESC LIMIT 1
) m ON true
JOIN ref.stage s ON s.stage_id=coalesce(m.destination_stage_id,p.stage_id)
WHERE p.action='REQUEST' AND NOT EXISTS (
 SELECT 1 FROM ops.setup_movement_event e WHERE e.setup_session_id=p.setup_session_id
 AND e.container_id=p.container_id AND e.event_type='RETURNED' AND e.occurred_at>=p.requested_at
);
GRANT SELECT ON ops.setup_container_pickup_list TO fieldwiring_app;
COMMIT;
