from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPTANCE = APP_DIR.parent / "Acceptance"
CANDIDATE_SHA = "2eee967b6c5359c0e2e2d876a2fe44af8359315c"
CANDIDATE_REF = "agent/setup-task-detail-layout-153"


def read_acceptance(name: str) -> str:
    return (ACCEPTANCE / name).read_text(encoding="utf-8")


def test_task_detail_preview_pins_exact_candidate_and_ref() -> None:
    launcher = read_acceptance("run_setup_task_detail_compact_browser_preview.ps1")
    server = read_acceptance("setup_source_only_browser_preview_server.sh")
    assert f"$AcceptedCandidateSha = '{CANDIDATE_SHA}'" in launcher
    assert f"$AcceptedBranch = '{CANDIDATE_REF}'" in launcher
    assert "run_setup_source_only_browser_preview.ps1" in launcher
    assert 'APPROVED_REF="${4:?approved Git ref required}"' in server
    assert 'fetch origin "$APPROVED_REF"' in server


def test_task_detail_preview_runs_layout_and_existing_safety_contracts() -> None:
    launcher = read_acceptance("run_setup_task_detail_compact_browser_preview.ps1")
    for contract in (
        "test_setup_stage_order_contract.py",
        "test_setup_dirty_edit_guard_contract.py",
        "test_setup_task_detail_compact_contract.py",
    ):
        assert contract in launcher
    assert "Client V0.3.8" in launcher
    assert "LEFT rail" in launcher
    assert "Reusable Task Definition followed immediately by compact Material / Logistics" in launcher
    assert "RIGHT rail" in launcher
    assert "Annual Historical Actual followed by Captains / Knowledge Owners" in launcher
    assert "View Material Details" in launcher
    assert "responsive-layout proxy" in launcher
    assert "Physical mobile-device acceptance is not claimed" in launcher
    assert "#159" in launcher


def test_base_source_only_launcher_still_passes_explicit_ref() -> None:
    base = read_acceptance("run_setup_source_only_browser_preview.ps1")
    assert "$ApprovedRef = $ExpectedBranch" in base
    assert "'$CandidateSha' '$PreviewPort' '$PreviewEmail' '$ApprovedRef'" in base
