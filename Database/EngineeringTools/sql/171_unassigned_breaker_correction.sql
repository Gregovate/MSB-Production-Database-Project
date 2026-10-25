-- Incremental unassigned-breaker correction. No row deletion or source imports.
-- Preserve authorization, revision locking, exact retries and the existing audit ledger.
BEGIN;
DO $migration$
DECLARE definition text; original text; replacement text; addition text;
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) <> '7c1ff2630aefda0a7e46c0ef4672714e' THEN
  RAISE EXCEPTION 'Unexpected breaker command baseline; reconcile concurrent migrations before applying';
 END IF;
 SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
 original:=$original$  IF EXISTS(SELECT 1 FROM ref.site_power_circuit c WHERE c.site_power_breaker_id=p_id AND c.active
     AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'legs') l WHERE (l->>'pole')::integer=c.breaker_pole)) THEN
   RAISE EXCEPTION 'Existing circuit legs cannot be omitted; reconcile their relationships before changing pole count' USING ERRCODE='23514'; END IF;
$original$;
 replacement:=$replacement$  -- Dependency preflight above covers every leg before any retirement.
  FOR old_leg IN SELECT * FROM ref.site_power_circuit c WHERE c.site_power_breaker_id=p_id AND c.active
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'legs') l WHERE (l->>'pole')::integer=c.breaker_pole) LOOP
   child_no:=child_no+1;
   child:=ref.site_power_command(p_email,md5(p_request::text||':unused-leg:'||child_no)::uuid,rev,'circuit',old_leg.site_power_circuit_id,
    jsonb_build_object('active',false));
   rev:=(child->>'revision')::bigint;
  END LOOP;
$replacement$;
 IF length(definition)-length(replace(definition,original,''))<>length(original) THEN RAISE EXCEPTION 'Correction anchor not unique'; END IF;
 definition:=replace(definition,original,replacement);
 addition:=$addition$
 -- Unassigned correction: preflight the complete breaker before changing its topology.
 IF p_kind='breaker_remove' OR (p_kind='breaker_schedule' AND p_id IS NOT NULL AND
   EXISTS(SELECT 1 FROM ref.site_power_circuit c WHERE c.site_power_breaker_id=p_id AND c.active
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'legs') l WHERE (l->>'pole')::integer=c.breaker_pole))) THEN
  DECLARE blockers text; b ref.site_power_breaker%ROWTYPE;
  BEGIN
   SELECT * INTO b FROM ref.site_power_breaker WHERE site_power_breaker_id=p_id AND active;
   IF NOT FOUND OR b.breaker_role<>'BRANCH' THEN
    RAISE EXCEPTION 'Select an active branch breaker to correct or remove' USING ERRCODE='22023'; END IF;
   IF p_kind='breaker_remove' AND p_data<>'{}'::jsonb THEN
    RAISE EXCEPTION 'Remove breaker does not accept replacement fields' USING ERRCODE='22023'; END IF;
   SELECT string_agg(label,', ' ORDER BY label) INTO blockers FROM (
    SELECT 'feed '||f.site_power_feed_id label FROM ref.site_power_feed f JOIN ref.site_power_circuit c ON c.site_power_circuit_id=f.source_circuit_id WHERE f.active AND c.site_power_breaker_id=p_id
    UNION ALL SELECT 'controller '||cp.controller_id FROM ref.site_controller_power_connection cp JOIN ref.site_power_circuit c USING(site_power_circuit_id) WHERE cp.active AND c.site_power_breaker_id=p_id
    UNION ALL SELECT 'conductor membership '||m.site_power_conductor_circuit_id FROM ref.site_power_conductor_circuit m JOIN ref.site_power_circuit c USING(site_power_circuit_id) WHERE m.active AND c.site_power_breaker_id=p_id
    UNION ALL SELECT 'remote panel '||p.panel_name FROM ref.site_panel p WHERE p.active AND p.supply_breaker_id=p_id
    UNION ALL SELECT 'activity '||a.action_name FROM ref.site_power_action a LEFT JOIN ref.site_power_circuit c USING(site_power_circuit_id)
     WHERE a.active AND (a.site_power_breaker_id=p_id OR c.site_power_breaker_id=p_id)
      AND NOT (a.site_power_breaker_id=p_id AND a.action_name='Breaker switch observation' AND a.action_kind='OTHER'
       AND a.instructions='Record physical switch position; not a remote command or isolation verification.')
    UNION ALL SELECT 'dependent activity '||dependent.action_name FROM ref.site_power_action a JOIN ref.site_power_action dependent ON a.site_power_action_id=ANY(dependent.prerequisite_action_ids)
     WHERE p_kind='breaker_remove' AND a.site_power_breaker_id=p_id AND dependent.active
   ) dependencies;
   IF blockers IS NOT NULL THEN
    RAISE EXCEPTION 'Breaker has active connections: %. Disconnect or reassign these before reducing poles or removing it.',blockers USING ERRCODE='23514'; END IF;
   IF p_kind='breaker_remove' THEN
    before_row:=to_jsonb(b);
    -- Retire automatic observation definitions, preserving immutable event history.
    FOR action_row IN SELECT * FROM ref.site_power_action WHERE site_power_breaker_id=p_id AND active LOOP
     child:=ref.site_power_command(p_email,md5(p_request::text||':action:'||action_row.site_power_action_id)::uuid,rev,'action',action_row.site_power_action_id,'{"active":false}'::jsonb);
     rev:=(child->>'revision')::bigint;
    END LOOP;
    FOR old_leg IN SELECT * FROM ref.site_power_circuit WHERE site_power_breaker_id=p_id AND active LOOP
     child:=ref.site_power_command(p_email,md5(p_request::text||':leg:'||old_leg.site_power_circuit_id)::uuid,rev,'circuit',old_leg.site_power_circuit_id,'{"active":false}'::jsonb);
     rev:=(child->>'revision')::bigint;
    END LOOP;
    child:=ref.site_power_command(p_email,md5(p_request::text||':breaker')::uuid,rev,'breaker',p_id,'{"active":false}'::jsonb);
    SELECT to_jsonb(x) INTO after_row FROM ref.site_power_breaker x WHERE site_power_breaker_id=p_id;
    UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
    INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
     VALUES(rev,p_request,p_kind,p_id,jsonb_build_object('id',p_id,'fields',request_fields),before_row,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
    RETURN jsonb_build_object('revision',rev,'target_id',p_id,'replayed',false);
   END IF;
  END;
 END IF;
$addition$;
 original:=' IF p_kind=''breaker_schedule'' THEN';
 IF length(definition)-length(replace(definition,original,''))<>length(original) THEN RAISE EXCEPTION 'Schedule anchor not unique'; END IF;
 EXECUTE replace(definition,original,addition||original);
END $migration$;
-- Retired circuit identities and history remain intact; only active names occupy a panel.
DROP INDEX ref.site_power_circuit_panel_code_uq;
CREATE UNIQUE INDEX site_power_circuit_panel_code_uq ON ref.site_power_circuit(site_panel_id,lower(btrim(circuit_code))) WHERE active;
COMMIT;
