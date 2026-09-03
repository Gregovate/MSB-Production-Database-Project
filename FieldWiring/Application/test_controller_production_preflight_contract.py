from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPT = REPO_ROOT / "Controllers" / "Acceptance"
CANDIDATE_SHA = "2fd2067958cc0a903260fe6f089f88ae63a857f1"


def test_production_preflight_is_pinned_and_stops_before_mutation() -> None:
    source = (
        ACCEPT / "controller_setup_management_production_preflight_server.sh"
    ).read_text(encoding="utf-8")

    assert f'TARGET_SHA="{CANDIDATE_SHA}"' in source
    assert "worktree add --detach" in source
    assert "python -m pytest" in source
    assert "pg_dump -U" in source
    assert "pg_restore --list" in source
    assert "DATABASE PREFLIGHT: PASS" in source
    assert "PRODUCTION PREFLIGHT STOP POINT REACHED" in source
    assert "No migrations applied. No checkout movement. No service restart." in source
    assert "production Controller fingerprint unchanged" in source

    assert '< "$MIGRATION_023"' not in source
    assert '< "$MIGRATION_024"' not in source
    assert "merge --ff-only" not in source
    assert "systemctl restart" not in source
    assert "CREATE FUNCTION" not in source
    assert "DROP FUNCTION" not in source


def test_production_preflight_wrapper_uses_foreground_single_ssh_shape() -> None:
    source = (
        ACCEPT / "run_controller_setup_management_production_preflight.ps1"
    ).read_text(encoding="utf-8")

    assert CANDIDATE_SHA in source
    assert "& scp -r" in source
    assert "& ssh -tt" in source
    assert "bash -n" in source
    assert "timeout --signal=TERM 1800s" in source
    assert "Start-Process" not in source
    assert "Tee-Object" not in source
