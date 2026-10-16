from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPT = REPO_ROOT / "Controllers" / "Acceptance"


def test_preview_launcher_uses_operator_pinned_exact_sha() -> None:
    wrapper = (ACCEPT / "run_controller_setup_management_browser_preview.ps1").read_text(
        encoding="utf-8"
    )
    server = (ACCEPT / "controller_setup_management_browser_preview_server.sh").read_text(
        encoding="utf-8"
    )

    assert "[Parameter(Mandatory=$true)][string]$CandidateSha" in wrapper
    assert "[Parameter(Mandatory=$true)][string]$TargetRef" in wrapper
    assert 'cat-file -e "${CandidateSha}^{commit}"' in wrapper
    assert "$head -ne $CandidateSha" in wrapper
    assert 'TARGET_SHA="${4:?CandidateSha required}"' in server
    assert 'TARGET_REF="${3:?TargetRef required}"' in server
    assert "TemplateCandidateSha" not in wrapper


def test_preview_launcher_preserves_unrelated_listeners() -> None:
    wrapper = (ACCEPT / "run_controller_setup_management_browser_preview.ps1").read_text(
        encoding="utf-8"
    )
    server = (ACCEPT / "controller_setup_management_browser_preview_server.sh").read_text(
        encoding="utf-8"
    )

    assert "Get-NetTCPConnection -LocalPort $PreviewPort -State Listen" in wrapper
    assert 'workstation port $PreviewPort is listening' in wrapper
    assert "Stop-Process" not in wrapper
    assert 'preview port $PREVIEW_PORT is already listening' in server
    assert "preview_pid_matches()" in server
    assert "preview_port_listening()" in server
    assert "CLEANUP FAILED: do not declare CLEAN EXIT" in server


def test_preview_launcher_uses_one_foreground_ssh_and_waits_for_readiness() -> None:
    wrapper = (ACCEPT / "run_controller_setup_management_browser_preview.ps1").read_text(
        encoding="utf-8"
    )

    assert wrapper.count("& scp -r") == 1
    assert wrapper.count("& ssh -tt") == 1
    assert "ServerAliveInterval=30" in wrapper
    assert "Start-Process ssh" not in wrapper
    assert "Start-Process $browserUrl" not in wrapper
    assert "timeout --foreground --signal=TERM 28800s" in wrapper
    assert "Do not open the browser until the runner prints BROWSER REVIEW READY." in wrapper
    assert 'if ($PreviewPort -ne 8898)' in wrapper
