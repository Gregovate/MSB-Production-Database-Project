from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPTANCE = APP_DIR.parent / "Acceptance"
CANDIDATE_SHA = "08758645b8c2226e732254ddc88faed4eda3f4b3"
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
    assert "Reusable Task Definition should be materially shorter" in launcher
    assert "Captains / Knowledge Owners appear beneath it" in launcher
    assert "Material / Logistics shows the four essential counts" in launcher
    assert "View Material Details" in launcher
    assert "stacks cleanly" in launcher
    assert "#159" in launcher


def test_base_source_only_launcher_still_passes_explicit_ref() -> None:
    base = read_acceptance("run_setup_source_only_browser_preview.ps1")
    assert "$ApprovedRef = $ExpectedBranch" in base
    assert "'$CandidateSha' '$PreviewPort' '$PreviewEmail' '$ApprovedRef'" in base
