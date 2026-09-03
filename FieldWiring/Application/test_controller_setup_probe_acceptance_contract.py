from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPT = REPO_ROOT / "Controllers" / "Acceptance"


def test_setup_probe_wrapper_pins_exact_candidate_and_bundles_023_024() -> None:
    source = (ACCEPT / "run_controller_setup_probe_disposable_acceptance.ps1").read_text(
        encoding="utf-8"
    )

    assert "1eea0ba437f7e4337e075b769c137ffe032dc27b" in source
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

    assert "& scp -r" in source
    assert "& ssh -tt" in source
    assert "timeout --signal=TERM 1800s" in source
    assert "Tee-Object" not in source
    assert "Start-Process" not in source
    assert "ssh -f" not in source
    assert "ssh -N" not in source


def test_server_gate_is_exact_candidate_read_probe_then_disposable_writes() -> None:
    source = (ACCEPT / "controller_setup_probe_disposable_server.sh").read_text(
        encoding="utf-8"
    )

    assert 'TARGET_SHA="1eea0ba437f7e4337e075b769c137ffe032dc27b"' in source
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
