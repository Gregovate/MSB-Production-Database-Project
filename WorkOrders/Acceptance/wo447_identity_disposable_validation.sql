-- #447: rollback-only identity regression on the existing private #419 clone.
-- Never use a repaired Production identity as proof of first-login behavior.
\set ON_ERROR_STOP on
BEGIN;
DO $identity_test$
DECLARE
  v_email text := current_setting('msb.wo419_v1_reviewer_email',true);
  v_person integer;
  v_user uuid;
  v_other_person integer;
  v_role uuid;
  v_role_name text;
  v_case text;
  v_actor record;
  v_before jsonb;
  v_after jsonb;
  v_user_before jsonb;
  v_denied boolean;
BEGIN
  IF current_database() <> 'msb_wo419_preview' OR
     current_setting('msb.wo419_preview_authorized',true)
       IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'WO447: private disposable clone required';
  END IF;
  SELECT p.person_id,u.id INTO STRICT v_person,v_user
    FROM ref.person p JOIN public.directus_users u ON lower(u.email)=lower(p.email)
    WHERE lower(p.email)=lower(v_email) AND p.active_flag AND u.status='active'
      AND u.provider='google' AND lower(u.external_identifier)=lower(v_email);
  IF has_table_privilege('work_management_app','ref.person','UPDATE') OR
     has_table_privilege('work_management_app','public.directus_users','UPDATE') OR
     has_function_privilege('work_management_app',
       'ref.reconcile_directus_person_identity(text)','EXECUTE') OR
     NOT has_function_privilege('work_management_app',
       'ops.work_management_reconcile_actor(text)','EXECUTE') THEN
    RAISE EXCEPTION 'WO447: narrow entry privilege boundary violated';
  END IF;

  -- Use the existing reviewer only inside rollback subtransactions. Nothing
  -- survives this file; existing human roles and Person records are preserved.
  FOREACH v_role_name IN ARRAY ARRAY['Production Crew','Manager'] LOOP
    BEGIN
      SELECT id INTO STRICT v_role FROM public.directus_roles WHERE name=v_role_name;
      UPDATE public.directus_users SET role=v_role WHERE id=v_user;
      DELETE FROM public.directus_access WHERE "user"=v_user;
      UPDATE ref.person SET directus_user_id=NULL WHERE person_id=v_person;
      SELECT to_jsonb(u) INTO v_user_before FROM public.directus_users u WHERE id=v_user;
      SET LOCAL ROLE work_management_app;
      SELECT * INTO STRICT v_actor FROM ops.work_management_reconcile_actor(v_email);
      RESET ROLE;
      IF v_actor.person_id <> v_person OR v_actor.directus_user_id <> v_user OR
         v_actor.can_manage IS DISTINCT FROM (v_role_name='Manager') OR
         NOT EXISTS (SELECT 1 FROM ref.person WHERE person_id=v_person
           AND directus_user_id=v_user AND updated_by_person_id=v_person) OR
         (SELECT to_jsonb(u) FROM public.directus_users u WHERE id=v_user)
           IS DISTINCT FROM v_user_before THEN
        RAISE EXCEPTION 'WO447: repair/role preservation/audit failed';
      END IF;
      SELECT to_jsonb(p) INTO v_before FROM ref.person p WHERE person_id=v_person;
      SET LOCAL ROLE work_management_app;
      PERFORM ops.work_management_reconcile_actor(v_email);
      RESET ROLE;
      SELECT to_jsonb(p) INTO v_after FROM ref.person p WHERE person_id=v_person;
      IF v_after IS DISTINCT FROM v_before THEN
        RAISE EXCEPTION 'WO447: repeat entry changed Person/audit';
      END IF;
      -- A subsequent authorization revocation is effective immediately.
      UPDATE public.directus_users SET status='suspended' WHERE id=v_user;
      v_denied:=false;
      BEGIN
        SET LOCAL ROLE work_management_app;
        PERFORM ops.work_management_reconcile_actor(v_email);
      EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
      END;
      RESET ROLE;
      IF NOT v_denied THEN RAISE EXCEPTION 'WO447: revocation ignored'; END IF;
      RAISE EXCEPTION 'rollback fixture' USING ERRCODE='P4470';
    EXCEPTION WHEN SQLSTATE 'P4470' THEN
      RAISE NOTICE 'WO447 % unlinked repair/audit/idempotence/revocation PASS',v_role_name;
    END;
  END LOOP;

  FOREACH v_case IN ARRAY ARRAY['provider','external_identifier','inactive_person',
                               'missing_person','conflicting_link','inactive_user',
                               'no_role','uuid_owned_elsewhere'] LOOP
    BEGIN
      UPDATE ref.person SET directus_user_id=NULL WHERE person_id=v_person;
      CASE v_case
        WHEN 'provider' THEN UPDATE public.directus_users SET provider='default' WHERE id=v_user;
        WHEN 'external_identifier' THEN UPDATE public.directus_users SET external_identifier='wrong@sheboyganlights.org' WHERE id=v_user;
        WHEN 'inactive_person' THEN UPDATE ref.person SET active_flag=false WHERE person_id=v_person;
        WHEN 'missing_person' THEN UPDATE ref.person SET email=NULL WHERE person_id=v_person;
        WHEN 'conflicting_link' THEN
          SELECT u.id INTO STRICT v_role FROM public.directus_users u
          WHERE u.id<>v_user ORDER BY u.id LIMIT 1;
          UPDATE ref.person SET directus_user_id=NULL WHERE directus_user_id=v_role;
          UPDATE ref.person SET directus_user_id=v_role WHERE person_id=v_person;
        WHEN 'uuid_owned_elsewhere' THEN
          SELECT person_id INTO STRICT v_other_person FROM ref.person
            WHERE person_id<>v_person ORDER BY person_id LIMIT 1;
          UPDATE ref.person SET directus_user_id=v_user WHERE person_id=v_other_person;
        WHEN 'inactive_user' THEN UPDATE public.directus_users SET status='suspended' WHERE id=v_user;
        WHEN 'no_role' THEN
          UPDATE public.directus_users SET role=NULL WHERE id=v_user;
          DELETE FROM public.directus_access WHERE "user"=v_user;
      END CASE;
      SELECT to_jsonb(p) INTO v_before FROM ref.person p WHERE person_id=v_person;
      v_denied:=false;
      BEGIN
        SET LOCAL ROLE work_management_app;
        PERFORM ops.work_management_reconcile_actor(v_email);
      EXCEPTION WHEN insufficient_privilege OR unique_violation THEN v_denied:=true;
      END;
      RESET ROLE;
      SELECT to_jsonb(p) INTO v_after FROM ref.person p WHERE person_id=v_person;
      IF NOT v_denied OR v_after IS DISTINCT FROM v_before THEN
        RAISE EXCEPTION 'WO447: negative case % accepted or mutated Person',v_case;
      END IF;
      RAISE EXCEPTION 'rollback fixture' USING ERRCODE='P4470';
    EXCEPTION WHEN SQLSTATE 'P4470' THEN RAISE NOTICE 'WO447 % denied PASS',v_case;
    END;
  END LOOP;
  -- Invalid/missing and known nonhuman identities must never become actors.
  FOREACH v_case IN ARRAY ARRAY['', 'nobody@invalid.example',
      'wo447-no-such-user@sheboyganlights.org',
      'printservice@sheboyganlights.org', 'production-1@sheboyganlights.org',
      'tablet-wo447@sheboyganlights.org'] LOOP
    v_denied:=false;
    BEGIN
      SET LOCAL ROLE work_management_app;
      PERFORM ops.work_management_reconcile_actor(v_case);
    EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
    END;
    RESET ROLE;
    IF NOT v_denied THEN RAISE EXCEPTION 'WO447: invalid/nonhuman actor accepted'; END IF;
  END LOOP;
END $identity_test$;
ROLLBACK;
