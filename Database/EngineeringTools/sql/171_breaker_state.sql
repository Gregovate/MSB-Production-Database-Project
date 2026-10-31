-- Incremental PR457 correction; initial GIS and panel-slot migrations are already deployed.
-- Reuse the existing revision lock, audited command and append-only activity ledger.
BEGIN;
DO $migration$
DECLARE definition text; anchor text := ' IF p_kind=''breaker_schedule'' THEN'; addition text;
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=
  'ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) <> '9f54909d2ce75cd0425cdf6338268f88' THEN
  RAISE EXCEPTION 'Unexpected site_power_command baseline; reconcile before migration';
 END IF;
 addition := $branch$
 IF p_kind='breaker_state' THEN
  DECLARE state_action bigint; matches integer; breaker_row ref.site_power_breaker%ROWTYPE;
  BEGIN
   IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN
     ('season_year','phase','condition','observed_at'))
     OR coalesce(p_data->>'phase','') NOT IN ('SETUP','RESTORATION')
     OR coalesce(p_data->>'condition','') NOT IN ('ON','OFF')
     OR p_data->>'observed_at' IS NULL OR p_data->>'season_year' IS NULL THEN
    RAISE EXCEPTION 'Season, phase and ON/OFF observation required' USING ERRCODE='22023';
   END IF;
   SELECT * INTO breaker_row FROM ref.site_power_breaker WHERE site_power_breaker_id=p_id AND active;
   IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM ref.site_panel WHERE site_panel_id=breaker_row.site_panel_id AND active) THEN
    RAISE EXCEPTION 'Active panel and breaker required' USING ERRCODE='22023';
   END IF;
   SELECT count(*),min(site_power_action_id) INTO matches,state_action FROM ref.site_power_action
    WHERE site_power_breaker_id=p_id AND phase=p_data->>'phase' AND active
     AND action_name='Breaker switch observation' AND action_kind='OTHER'
     AND instructions='Record physical switch position; not a remote command or isolation verification.';
   IF matches>1 THEN RAISE EXCEPTION 'Duplicate breaker observation activities; reconcile before recording' USING ERRCODE='23514'; END IF;
   IF state_action IS NULL THEN
    child:=ref.site_power_command(p_email,md5(p_request::text||':state-action')::uuid,rev,'action',NULL,
     jsonb_build_object('site_power_breaker_id',p_id,'phase',p_data->>'phase',
      'action_name','Breaker switch observation','action_kind','OTHER','desired_state','UNKNOWN',
      'instructions','Record physical switch position; not a remote command or isolation verification.',
      'source_evidence','Created by the breaker state recorder','verification_status','UNVERIFIED'));
    rev:=(child->>'revision')::bigint; state_action:=(child->>'target_id')::bigint;
   END IF;
   IF (p_data->>'observed_at')::timestamptz>clock_timestamp()+interval '5 minutes' THEN
    RAISE EXCEPTION 'Observation time is in the future' USING ERRCODE='22023';
   END IF;
   SELECT * INTO STRICT action_row FROM ref.site_power_action WHERE site_power_action_id=state_action;
   -- A direct position observation is not an impact-review attestation. Retain
   -- the grouped snapshot and actor without inventing an acknowledgment.
   INSERT INTO ops.setup_power_activity_event(request_id,site_power_action_id,season_year,event_kind,condition,observed_at,evidence,
    definition_snapshot,directus_user_id,person_id,operator_email)
   VALUES(md5(p_request::text||':state-event')::uuid,state_action,(p_data->>'season_year')::integer,'REPORTED',p_data->>'condition',
    (p_data->>'observed_at')::timestamptz,'Operator recorded physical breaker position.',
    to_jsonb(action_row)||jsonb_build_object('impact',ref.site_power_breaker_impact(p_email,p_id)),
    actor.directus_user_id,actor.person_id,lower(btrim(p_email))) RETURNING event_id,to_jsonb(setup_power_activity_event) INTO target,after_row;
   UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
   INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
    VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',request_fields),NULL,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
   RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
  END;
 END IF;
$branch$;
 SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
 IF length(definition)-length(replace(definition,anchor,'')) <> length(anchor) THEN
  RAISE EXCEPTION 'Breaker command insertion point not unique';
 END IF;
 EXECUTE replace(definition,anchor,addition||anchor);
END $migration$;
-- Resolve canonical Directus names for display without rewriting event identity.
DO $names$
DECLARE definition text; original text; replacement text;
BEGIN
 SELECT pg_get_functiondef('ref.site_power_snapshot(text)'::regprocedure) INTO definition;
 original := 'to_jsonb(e) ORDER BY event_id DESC) FROM ops.setup_power_activity_event e';
 replacement := 'to_jsonb(e)||jsonb_build_object(''operator_name'',coalesce(nullif(btrim(concat_ws('' '',u.first_name,u.last_name)),''''),''Name unavailable'')) ORDER BY e.event_id DESC) FROM ops.setup_power_activity_event e LEFT JOIN public.directus_users u ON u.id=e.directus_user_id';
 IF length(definition)-length(replace(definition,original,'')) <> length(original) THEN
  RAISE EXCEPTION 'Unexpected event snapshot baseline';
 END IF;
 definition:=replace(definition,original,replacement);
 original := 'to_jsonb(h) ORDER BY event_id DESC) FROM ops.site_power_edit_log h';
 replacement := 'to_jsonb(h)||jsonb_build_object(''operator_name'',coalesce(nullif(btrim(concat_ws('' '',u.first_name,u.last_name)),''''),''Name unavailable'')) ORDER BY h.event_id DESC) FROM ops.site_power_edit_log h LEFT JOIN public.directus_users u ON u.id=h.directus_user_id';
 IF length(definition)-length(replace(definition,original,'')) <> length(original) THEN
  RAISE EXCEPTION 'Unexpected audit snapshot baseline';
 END IF;
 EXECUTE replace(definition,original,replacement);
END $names$;
COMMIT;
