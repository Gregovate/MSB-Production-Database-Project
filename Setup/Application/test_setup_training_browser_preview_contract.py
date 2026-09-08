from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPT = SETUP_DIR / "Acceptance"
ACCEPTED_CANDIDATE_SHA = "a10edf8618dfb944bde5558c3a9e88e2a1502173"


def read_acceptance(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_training_preview_reuses_hardened_disposable_clone_preview() -> None:
    launcher = read_acceptance("run_setup_training_browser_preview.ps1")
    base = read_acceptance("run_setup_source_only_browser_preview.ps1")
    server = read_acceptance("setup_source_only_browser_preview_server.sh")

    assert f"$AcceptedCandidateSha = '{ACCEPTED_CANDIDATE_SHA}'" in launcher
    assert "run_setup_source_only_browser_preview.ps1" in launcher
    assert "disposable current-Production clone" in launcher

    # The PowerShell base owns the local wrapper/SSH boundary, while the server
    # runner owns the database/read-only/live-checkout safety assertions.
    assert "Production Setup data and /opt/msb-setup remain unchanged" in base
    assert "Production DB: pg_dump + SELECT only" in server
    assert "Preview writes: disposable current-production clone only" in server
    assert "PASS: Production Setup fingerprint unchanged" in server
    assert "PASS: live Setup checkout unchanged" in server


def test_training_preview_installs_only_019_020_021_into_clone() -> None:
    launcher = read_acceptance("run_setup_training_browser_preview.ps1")

    for migration in (
        "019_add_reconstruction_safe_task_delete.sql",
        "020_add_setup_captain_management_commands.sql",
        "021_add_setup_assigned_reconciliation_state.sql",
    ):
        assert migration in launcher

    assert 'psql_test < "$M019"' in launcher
    assert 'psql_test < "$M020"' in launcher
    assert 'psql_test < "$M021"' in launcher
    assert "Disposable Setup training/reconstruction migrations 019-021: PASS" in launcher

    # Do not revive the older V0.3 browser-preview migration stack for this
    # current-Production-clone review.
    assert "008_create_setup_resource_management_commands.sql" not in launcher
    assert "012_seed_site_infrastructure_review_tasks.sql" not in launcher


def test_training_preview_keeps_exact_candidate_and_live_port_guards() -> None:
    launcher = read_acceptance("run_setup_training_browser_preview.ps1")
    base = read_acceptance("run_setup_source_only_browser_preview.ps1")

    assert "Current branch does not contain the accepted Setup repair candidate" in base
    assert "PreviewPort $PreviewPort conflicts with a Production listener" in base
    assert "@(8055, 8790, 8792, 8794)" in base
    assert "git -C $RepoRoot status --porcelain" in base
    assert "Production Setup data and /opt/msb-setup remain unchanged" in base

    # The training launcher must patch the base candidate in memory rather than
    # advancing or modifying the live /opt/msb-setup checkout.
    assert "[scriptblock]::Create($text)" in launcher
    assert "git -C" not in launcher
