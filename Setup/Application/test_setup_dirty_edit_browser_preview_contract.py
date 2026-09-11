from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPTANCE = APP_DIR.parent / "Acceptance"
CANDIDATE_SHA = "9d0c31421ce7cbd1b1cbcf733b06198ace418e9d"
CANDIDATE_REF = "agent/setup-dirty-edit-followup-154"


def read_acceptance(name: str) -> str:
    return (ACCEPTANCE / name).read_text(encoding="utf-8")


def test_dirty_edit_preview_pins_exact_candidate_and_ref() -> None:
    launcher = read_acceptance("run_setup_catalog_dirty_edit_browser_preview.ps1")
    server = read_acceptance("setup_source_only_browser_preview_server.sh")

    assert f"$AcceptedCandidateSha = '{CANDIDATE_SHA}'" in launcher
    assert f"$AcceptedBranch = '{CANDIDATE_REF}'" in launcher
    assert "run_setup_source_only_browser_preview.ps1" in launcher
    assert 'APPROVED_REF="${4:?approved Git ref required}"' in server
    assert 'fetch origin "$APPROVED_REF"' in server
    assert "agent/setup-session-production-foundation" not in server


def test_source_only_preview_recreates_current_setup_write_boundary() -> None:
    server = read_acceptance("setup_source_only_browser_preview_server.sh")

    for signature in (
        "ref.delete_setup_reconstruction_task(text,bigint)",
        "ref.setup_task_captain_list(bigint)",
        "ref.setup_captain_person_list()",
        "ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean)",
        "ref.set_setup_task_effort(text,bigint,text)",
        "ref.set_setup_task_display_material_requirement(text,bigint,boolean)",
    ):
        assert f"GRANT EXECUTE ON FUNCTION {signature} TO fieldwiring_app;" in server

    assert "GRANT SELECT ON ALL TABLES IN SCHEMA ref, ops, lor_snap TO fieldwiring_app;" in server
    assert "Preview role default_transaction_read_only=on: PASS" in server
    assert "Preview least-privilege table boundary: PASS" in server


def test_dirty_edit_preview_runs_focused_contract_and_prints_manual_matrix() -> None:
    launcher = read_acceptance("run_setup_catalog_dirty_edit_browser_preview.ps1")

    assert "test_setup_dirty_edit_guard_contract.py" in launcher
    assert "test_setup_stage_order_contract.py" in launcher
    assert "confirm the header visibly shows Client V0.3.7" in launcher
    assert "do not write" in launcher
    assert "Mark Verified" in launcher
    assert "verification does NOT change" in launcher
    assert "Save + continue, Discard + continue, and Stay" in launcher
    assert "annual draft remains present" in launcher
    assert "independent Effort or Material save" in launcher


def test_base_source_only_launcher_passes_explicit_ref_to_server() -> None:
    base = read_acceptance("run_setup_source_only_browser_preview.ps1")
    assert "$ApprovedRef = $ExpectedBranch" in base
    assert "Approved ref:  $ApprovedRef" in base
    assert "'$CandidateSha' '$PreviewPort' '$PreviewEmail' '$ApprovedRef'" in base
