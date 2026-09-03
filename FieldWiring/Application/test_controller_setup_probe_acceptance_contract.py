from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPT = REPO_ROOT / "Controllers" / "Acceptance"
CANDIDATE_SHA = "2fd2067958cc0a903260fe6f089f88ae63a857f1"


def _powershell_code_lines(source: str) -> str:
    """Return executable-looking PowerShell lines, excluding comments.

    Safety comments intentionally name forbidden patterns such as Tee-Object so
    operators know what not to do. Contract assertions must inspect code rather
    than fail merely because a prohibited command is mentioned in documentation.
    """
    return "\n".join(
        line
        for line in source.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )


def test_setup_probe_wrapper_pins_exact_candidate_and_bundles_023_024() -> None:
    source = (ACCEPT / "run_controller_setup_probe_disposable_acceptance.ps1").read_text(
        encoding="utf-8"
    )

    assert CANDIDATE_SHA in source
    assert "023_create_controller_management_commands.sql" in source
    assert "024_harden_controller_assignment_capability.sql" in source
    assert "$sql023Text.TrimEnd()" in source
    assert "$sql024Text.TrimStart()" in source
    assert "controller_setup_probe_disposable_server.sh" in source
    assert "controller_management_disposable_server.sh" in source
    assert ".Replace(\"`r`n\", \"`n\")" in source


def test_setup_probe_wrapper_uses_foreground_native_ssh_contract() -> None:
    source = (ACCEPT / "run_controller_setup_probe_disposable_acceptance.ps1").read_text(
        encoding="utf-8"
    )
    code = _powershell_code_lines(source)

    assert "& scp -r" in code
    assert "& ssh -tt" in code
    assert "timeout --signal=TERM 1800s" in code
    assert "Tee-Object" not in code
    assert "Start-Process" not in code
    assert "ssh -f" not in code
    assert "ssh -N" not in code


def test_wrapper_patches_disposable_postgres_init_race_before_restore() -> None:
    source = (ACCEPT / "run_controller_setup_probe_disposable_acceptance.ps1").read_text(
        encoding="utf-8"
    )

    assert "Write-PatchedManagementServer" in source
    assert "PostgreSQL init process complete; ready for start up" in source
    assert 'pg_isready -U "$DB_ACTOR" -d postgres' in source
    assert "disposable PostgreSQL final server did not become ready" in source
    assert "Disposable PostgreSQL logs (failure evidence)" in source
    assert "$text.Contains($oldReady)" in source
    assert "$text.Replace($oldReady, $newReady)" in source


def test_server_gate_is_exact_candidate_read_probe_then_disposable_writes() -> None:
    source = (ACCEPT / "controller_setup_probe_disposable_server.sh").read_text(
        encoding="utf-8"
    )

    assert f'TARGET_SHA="{CANDIDATE_SHA}"' in source
    assert "worktree add --detach" in source
    assert "python -m pytest" in source
    assert "SET LOCAL ROLE fieldwiring_app" in source
    assert "lor_snap.preview_wiring_fieldlead_v6" in source
    assert "direct_stage_spare_rows=" in source
    assert 'bash "$CORE_DIR/controller_management_disposable_server.sh"' in source

    # The parent probe never applies SQL or performs production Controller DML.
    assert "UPDATE ref.controller" not in source
    assert "INSERT INTO ref.controller" not in source
    assert "DELETE FROM ref.controller" not in source
    assert "psql_prod" not in source
