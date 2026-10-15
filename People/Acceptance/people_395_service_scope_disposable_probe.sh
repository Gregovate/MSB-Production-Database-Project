#!/usr/bin/env bash
# Source only from the accepted #395 disposable harness. #49 non-admin service proof.
# Container name guards prevent accidental connection to Production.
run_people_395_service_scope_probe() {
    echo "--- Disposable Directus API-only service credential scope probe ---"
    [[ "$TEST_DB_CONTAINER" == msb-395-bootstrap-db-* ]] || { echo "STOP: wrong clone DB"; return 70; }
    [[ "$TEST_DIRECTUS_CONTAINER" == msb-395-bootstrap-directus-* ]] || { echo "STOP: wrong clone Directus"; return 70; }
    [[ -n "$BASELINE_ROLE_ID" && -n "$DIRECTUS_ADMIN_TOKEN" ]] || { echo "STOP: missing clone baseline"; return 71; }

    local role_id policy_id service_token service_email test_email manager_role
    role_id="$(psql_q -c "INSERT INTO public.directus_roles (id,name,icon,description)
         VALUES (gen_random_uuid(),'MSB #395 Disposable Service Scope','vpn_key','DISPOSABLE ONLY')
         RETURNING id;")"
    policy_id="$(psql_q -c "INSERT INTO public.directus_policies
         (id,name,icon,description,admin_access,app_access)
         VALUES (gen_random_uuid(),'MSB #395 Google Browser create only','vpn_key',
             'DISPOSABLE ONLY',false,false) RETURNING id;")"
    psql_q -c "INSERT INTO public.directus_access (role,policy)
         VALUES ('$role_id'::uuid,'$policy_id'::uuid);" >/dev/null
    psql_q -c "INSERT INTO public.directus_permissions
         (policy,collection,action,permissions,validation,presets,fields)
         VALUES ('$policy_id'::uuid,'directus_users','create',NULL,
             jsonb_build_object('_and',jsonb_build_array(
                 jsonb_build_object('role',jsonb_build_object('_eq','$BASELINE_ROLE_ID')),
                 jsonb_build_object('provider',jsonb_build_object('_eq','google')),
                 jsonb_build_object('status',jsonb_build_object('_eq','active'))
             )),NULL,
             'email,first_name,last_name,status,provider,external_identifier,role');" >/dev/null

    service_token="$(openssl rand -hex 32)"
    service_email="bootstrap-service-probe-$SHORT_STAMP-$$@sheboyganlights.org"
    test_email="bootstrap-person-probe-$SHORT_STAMP-$$@sheboyganlights.org"
    manager_role="$(psql_q -c "SELECT id FROM public.directus_roles WHERE name='Manager' ORDER BY id LIMIT 1;")"
    [[ -n "$manager_role" ]] || { echo "STOP: disposable Manager role missing"; return 72; }
    psql_q -c "INSERT INTO public.directus_users
        (id,email,first_name,last_name,status,provider,role,token)
        VALUES (gen_random_uuid(),'$service_email','MSB','Service Scope Probe',
        'active','default','$role_id'::uuid,'$service_token');" >/dev/null
    [[ "$(psql_q -c "SELECT count(*) FROM public.directus_access a
        JOIN public.directus_policies p ON p.id=a.policy
        WHERE a.role='$role_id'::uuid AND (p.admin_access OR p.app_access);")" == 0 ]] \
        || { echo "STOP: clone service policy unexpectedly gives admin or Studio"; return 73; }

    sudo docker exec -i \
        -e MSB395_TOKEN="$service_token" \
        -e MSB395_BROWSER_ROLE="$BASELINE_ROLE_ID" \
        -e MSB395_MANAGER_ROLE="$manager_role" \
        -e MSB395_EMAIL="$test_email" \
        "$TEST_DIRECTUS_CONTAINER" node - <<'NODE'
const base='http://127.0.0.1:8055';
const token=process.env.MSB395_TOKEN;
const browser=process.env.MSB395_BROWSER_ROLE;
const manager=process.env.MSB395_MANAGER_ROLE;
const email=process.env.MSB395_EMAIL;
async function call(method,path,body) {
  return fetch(base+path,{method,
    headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},
    ...(body===undefined?{}:{body:JSON.stringify(body)})});
}
function fail(phase,status){console.error('STOP: scoped Directus service '+phase+' HTTP '+status);process.exitCode=74;}
const self=await call('GET','/users/me?fields=id,status');
if(self.status!==200) fail('authentication',self.status);
else {
  const payload={email,first_name:'Scope',last_name:'Probe',status:'active',
     provider:'google',external_identifier:email,role:browser};
  const r=await call('POST','/users',payload);
  if(r.status!==200&&r.status!==201) fail('required Browser creation',r.status);
  else {
    const created=await r.json().catch(()=>null);
    if(!created||!created.data||!created.data.id) fail('missing creation identity',r.status);
    else {
      console.log('PASS: scoped service creates Google/MSB Browser');
      const elevated=await call('POST','/users',{
         ...payload,email:'elevated-'+email,external_identifier:'elevated-'+email,role:manager});
      if(elevated.status<400) fail('Manager elevation allowed',elevated.status);
      else console.log('PASS: Manager elevation denied');
      const updated=await call('PATCH','/users/'+created.data.id,{last_name:'Altered'});
      if(updated.status<400) fail('user update allowed',updated.status);
      else console.log('PASS: user update denied');
      const unrelated=await call('POST','/items/work_order_intake',{});
      if(unrelated.status<400) fail('unrelated Intake create allowed',unrelated.status);
      else console.log('PASS: unrelated Intake create denied');
      const all=await call('GET','/users');
      if(all.status<400) fail('broad user read allowed',all.status);
      else console.log('PASS: broad user list denied');
    }
  }
}
if(process.exitCode)process.exit(process.exitCode);
NODE
    [[ "$(psql_q -c "SELECT count(*) FROM public.directus_users
        WHERE lower(email)=lower('$test_email') AND provider='google'
        AND lower(external_identifier)=lower('$test_email')
        AND status='active' AND role='$BASELINE_ROLE_ID'::uuid;")" == 1 ]] \
        || { echo "STOP: resulting clone-only Google identity mismatch"; return 75; }
    [[ "$(psql_q -c "SELECT count(*) FROM ref.person WHERE lower(email)=lower('$test_email');")" == 0 ]] \
        || { echo "STOP: clone-only non-person source created ref.person"; return 76; }
    echo "PASS: Directus 11.17.1 scoped non-admin service credential proof"
}
