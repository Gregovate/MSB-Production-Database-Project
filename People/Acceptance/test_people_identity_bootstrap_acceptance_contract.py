from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
SERVER = (BASE_DIR / "people_identity_bootstrap_disposable_server.sh").read_text(
    encoding="utf-8"
)
WRAPPER = (
    BASE_DIR / "run_people_identity_bootstrap_disposable_acceptance.ps1"
).read_text(encoding="utf-8")


def test_wrapper_requires_exact_clean_feature_branch() -> None:
    assert "$SourceBranch = 'issue-395-silent-human-identity-bootstrap'" in WRAPPER
    assert "git -C $RepoRoot status --porcelain" in WRAPPER
    assert "$CandidateSha -ne $RemoteSha" in WRAPPER
    assert "timeout --foreground --signal=TERM 1800s" in WRAPPER


def test_server_never_moves_live_checkout_or_restarts_production_services() -> None:
    assert 'worktree add --detach "$WORKTREE" "$CANDIDATE_SHA"' in SERVER
    assert "git checkout" not in SERVER
    assert "git reset" not in SERVER
    assert "docker restart msb-directus" not in SERVER
    assert "systemctl restart" not in SERVER
    assert "systemctl stop" not in SERVER


def test_production_database_access_is_dump_and_select_fingerprint_only() -> None:
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc' in SERVER
    assert "SELECT md5(coalesce(string_agg(row_to_json(p)::text" in SERVER
    assert "SELECT md5(coalesce(string_agg(row_to_json(u)::text" in SERVER
    assert 'psql_test()' in SERVER
    assert 'psql_q()' in SERVER
    assert '"$TEST_DB_CONTAINER"' in SERVER


def test_disposable_directus_uses_production_image_without_host_port() -> None:
    assert 'DIRECTUS_IMAGE="directus/directus:11.17.1"' in SERVER
    start = SERVER.split('sudo docker run -d --name "$TEST_DIRECTUS_CONTAINER"', 1)[1]
    start = start.split('directus_ready=0', 1)[0]
    assert "--network" in start
    assert "-p " not in start
    assert "--publish" not in start


def test_acceptance_exercises_real_directus_users_api_and_legacy_flow_guard() -> None:
    assert "Directus Users API" in SERVER
    assert "supported Directus Users API accepts provider/external_identifier + Browser role" in SERVER
    assert "legacy User Onboarding auto-created Person" in SERVER
    assert "non-null Browser role prevents legacy missing-Person auto-create branch" in SERVER


def test_cleanup_removes_only_disposable_containers_and_worktree() -> None:
    assert 'docker rm -f "$TEST_DIRECTUS_CONTAINER"' in SERVER
    assert 'docker rm -f "$TEST_DB_CONTAINER"' in SERVER
    assert 'worktree remove --force "$WORKTREE"' in SERVER
    assert 'docker rm -f "$PROD_DIRECTUS_CONTAINER"' not in SERVER
    assert 'docker rm -f "$PROD_DB_CONTAINER"' not in SERVER
