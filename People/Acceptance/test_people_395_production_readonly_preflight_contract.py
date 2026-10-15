"""#395 Production preflight contract: read-only, interactive, fail-closed.

This is intentionally separate from the actual database-changing deployment.
The accepted V0.2.3 runtime and migration 006 remain frozen.
"""
from pathlib import Path

BASE = Path(__file__).resolve().parent
WINDOWS = (BASE / "run_people_395_production_readonly_preflight.ps1").read_text(
    encoding="utf-8"
)
SERVER = (BASE / "people_395_production_readonly_preflight.sh").read_text(
    encoding="utf-8"
)


def test_only_read_only_production_probes_and_no_maintenance_transition():
    assert 'controller is not healthy ONLINE' in SERVER
    assert 'database_fenced' in SERVER
    assert 'status_json=' in SERVER
    assert 'psql_read()' in SERVER
    assert 'psql -X -qAt -v ON_ERROR_STOP=1' in SERVER
    assert 'to_regprocedure(' in SERVER
    assert 'people_identity_bootstrap_status(text)' in SERVER
    assert 'people_identity_bootstrap_reconcile(text)' in SERVER
    assert 'Don' in SERVER
    assert 'fingerprint' in SERVER.lower()
    for prohibited in (
        'controller on',
        'controller off',
        'controller snapshot',
        'CREATE FUNCTION',
        'ALTER TABLE',
        'INSERT INTO ',
        'UPDATE public.directus_users',
        'docker run',
        'docker rm',
        'git merge',
        'git checkout',
        'systemctl restart',
        'psql_prod',
        'psql -f',
        'rm -rf /opt',
    ):
        assert prohibited not in SERVER


def test_exact_live_and_merged_source_are_pinned_and_checked():
    assert 'bb8dfa498c5b4bbecfc3693f68c4066c1e08242e' in SERVER
    assert 'EXPECTED_MAIN_SHA' in SERVER
    assert 'git -C "$REPO" rev-parse HEAD' in SERVER
    assert 'git -C "$REPO" status --porcelain' in SERVER
    assert 'git -C "$REPO" ls-remote origin refs/heads/main' in SERVER
    assert 'V0.2.2' in SERVER
    assert 'msb-people.service' in SERVER
    assert 'msb-directus' in SERVER


def test_directus_credential_is_checked_without_disclosure_or_mutation():
    assert '/etc/msb-people/people.env' in SERVER
    assert 'PEOPLE_DIRECTUS_IDENTITY_TOKEN' in SERVER
    assert 'ProxyHandler({})' in SERVER
    assert '"/users/me?fields=id,status"' in SERVER
    assert 'Authorization' in SERVER
    assert 'print("STOP: protected Directus credential missing, invalid or unusable")' in SERVER
    assert 'print("PASS: protected credential present and authenticated for read")' in SERVER
    assert 'print(token)' not in SERVER
    assert '"POST"' not in SERVER
    assert 'Request(url+"/users", ' not in SERVER


def test_wrapper_uses_one_bundle_foreground_ssh_and_bounded_results():
    assert '[string]$TargetSha' in WINDOWS
    assert '6122d7923c2a07eb6b278225cf71cafc4704d349' in WINDOWS
    assert 'git -C $repo fetch origin main $expectedBranch' in WINDOWS
    assert '$expectedBranch = ' in WINDOWS
    assert '$dirty' in WINDOWS
    assert 'ReadAllText($source)' in WINDOWS
    assert 'UTF8Encoding' in WINDOWS
    assert 'scp -r $localBundle' in WINDOWS
    assert 'ssh -tt -o ServerAliveInterval=15' in WINDOWS
    assert 'timeout --foreground --signal=TERM 1200s' in WINDOWS
    assert 'bash -n' in WINDOWS
    assert 'Remove-Item -LiteralPath $localBundle' in WINDOWS
    assert 'finally {' in WINDOWS
    assert 'BEGIN #395 RESULT' in SERVER
    assert 'END #395 RESULT' in SERVER
    assert 'Production writes:  NONE' in SERVER
    for prohibited in ('Start-Process', 'ssh -N', 'ssh -f', 'Tee-Object', 'Reset-Hard'):
        assert prohibited not in WINDOWS
