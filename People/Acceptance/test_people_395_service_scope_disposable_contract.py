"""Source guard for #49/#395 disposable Directus service permission proof.

The original People runtime is frozen. Production is read-only throughout
this acceptance; all extra service identities are disposable-only fixtures.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RUNNER = (ROOT / "people_identity_bootstrap_disposable_server.sh").read_text(
    encoding="utf-8"
)
WRAPPER = (ROOT / "run_people_identity_bootstrap_disposable_acceptance.ps1").read_text(
    encoding="utf-8"
)
PROBE = (ROOT / "people_395_service_scope_disposable_probe.sh").read_text(
    encoding="utf-8"
)


def test_existing_acceptance_remains_default_without_new_profile():
    assert "$SourceBranch = 'issue-395-silent-human-identity-bootstrap'" in WRAPPER
    assert "[switch]$ServiceScopeProbe" in WRAPPER
    assert "if ($ServiceScopeProbe)" in WRAPPER
    assert 'SERVICE_SCOPE_PROBE="${3:-false}"' in RUNNER
    assert 'if [[ "$SERVICE_SCOPE_PROBE" == "true" ]]' in RUNNER
    assert "issue-395-production-deployment-readiness" in RUNNER


def test_exact_accepted_people_runtime_cannot_change_in_permission_probe():
    accepted = "dcc8f25f07a74e19ce3de3aae2d9d137b5411815"
    assert accepted in RUNNER and accepted in WRAPPER
    assert 'git -C "$REPO_ROOT" diff --quiet' in RUNNER
    assert 'People/Application People/Database' in RUNNER
    assert 'diff --name-only "$acceptedRuntimeSha..$CandidateSha"' in WRAPPER


def test_probe_shares_existing_disposable_clone_not_new_runtime():
    assert 'source "$SCRIPT_DIR/people_395_service_scope_disposable_probe.sh"' in RUNNER
    assert 'run_people_395_service_scope_probe' in RUNNER
    assert "msb-395-bootstrap-db-" in PROBE
    assert "msb-395-bootstrap-directus-" in PROBE
    assert "TEST_DB_CONTAINER" in PROBE
    assert "TEST_DIRECTUS_CONTAINER" in PROBE
    assert "psql_q -c" in PROBE
    assert '"$TEST_DIRECTUS_CONTAINER" node -' in PROBE
    assert "gen_random_uuid()" in PROBE
    assert "SERVICE_SCOPE_PROBE" in RUNNER
    for phrase in ("msb-postgres", "msb-directus", "systemctl restart", "controller on",
                   "controller off", "git merge", "ssh -f", "docker run",
                   "pg_dump", "rm -rf /opt", "sudo git -C /opt/fieldwiring"):
        assert phrase not in PROBE


def test_directus_access_join_has_explicit_disposable_uuid_id():
    # Real Directus 11.17.1 disposable attempt 2026-10-15 stopped
    # on NOT NULL directus_access.id when role/policy-only INSERT was used.
    assert "INSERT INTO public.directus_access (id,role,policy)" in PROBE
    assert "VALUES (gen_random_uuid(),'$role_id'::uuid,'$policy_id'::uuid)" in PROBE
    assert "INSERT INTO public.directus_access (role,policy)" not in PROBE


def test_scoped_policy_no_admin_and_only_user_create_fields():
    assert "admin_access,app_access" in PROBE
    assert "false,false" in PROBE
    assert "'directus_users','create'" in PROBE
    assert "'email,first_name,last_name,status,provider,external_identifier,role'" in PROBE
    assert "jsonb_build_object('role'" in PROBE
    assert "jsonb_build_object('provider'" in PROBE
    assert "jsonb_build_object('status'" in PROBE
    assert "p.admin_access OR p.app_access" in PROBE
    assert "Manager elevation denied" in PROBE
    assert "user update denied" in PROBE
    assert "unrelated Intake create denied" in PROBE
    assert "user listing constrained to self" in PROBE
    assert "GET','/permissions/me" in PROBE
    assert "Directus user update permission unexpectedly assigned" in PROBE
    assert "Intake create permission unexpectedly assigned" in PROBE
    assert "process.exit(74)" in PROBE
    assert 'sudo docker restart "$TEST_DIRECTUS_CONTAINER"' in PROBE
    assert "SELECT count(*) FROM ref.person" in PROBE


def test_token_never_printed_and_report_is_compact():
    assert "openssl rand -hex 32" in PROBE
    assert "MSB395_TOKEN" in PROBE
    assert "console.log(token)" not in PROBE
    assert "echo $service_token" not in PROBE
    assert "BEGIN #395 RESULT" in RUNNER
    assert "END #395 RESULT" in RUNNER
    assert 'echo "Scope stage:      $SCOPE_STAGE"' in RUNNER
    for stage in (
        "CREATE_ROLE", "CREATE_POLICY", "LINK_ROLE_POLICY",
        "CREATE_PERMISSION", "CREATE_SERVICE_TOKEN_AND_USER",
        "REFRESH_DISPOSABLE_DIRECTUS", "VERIFY_SERVICE_API_PERMISSIONS",
        "VERIFY_CREATED_DISPOSABLE_USER", "PASS",
    ):
        assert f'SCOPE_STAGE="{stage}"' in PROBE
    assert "Production writes: NONE" in RUNNER
    assert 'echo "Person after:     $person_after_result"' in RUNNER
    assert 'echo "Directus after:   $directus_after_result"' in RUNNER
    assert "people_395_service_scope_disposable_probe.sh" in WRAPPER
    assert "bash -n '$remoteProbe'" in WRAPPER
    assert "timeout --foreground --signal=TERM 1800s" in WRAPPER
