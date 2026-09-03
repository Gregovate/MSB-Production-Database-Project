from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPT = REPO_ROOT / "Controllers" / "Acceptance"
GREEN_CANDIDATE = "63be47f40be78f608416935ed0583287da9d90e6"
TEMPLATE_CANDIDATE = "2fd2067958cc0a903260fe6f089f88ae63a857f1"


def test_preview_launcher_pins_exact_green_candidate_at_upload_time() -> None:
    wrapper = (ACCEPT / "run_controller_setup_management_browser_preview.ps1").read_text(
        encoding="utf-8"
    )

    assert f"$TemplateCandidateSha = '{TEMPLATE_CANDIDATE}'" in wrapper
    assert f"$CandidateSha = '{GREEN_CANDIDATE}'" in wrapper
    assert "$serverText.Replace($TemplateCandidateSha, $CandidateSha)" in wrapper
    assert 'cat-file -e "${CandidateSha}^{commit}"' in wrapper


def test_preview_launcher_cleans_only_stale_preview_resources_before_start() -> None:
    wrapper = (ACCEPT / "run_controller_setup_management_browser_preview.ps1").read_text(
        encoding="utf-8"
    )

    assert "controller_setup_management_browser_preview_cleanup_server.sh" in wrapper
    assert "Get-NetTCPConnection -LocalPort $PreviewPort -State Listen" in wrapper
    assert "$owner.ProcessName -ne 'ssh'" in wrapper
    assert "Stop-Process -Id $owner.Id -Force" in wrapper
    assert 'bash -n \'$uploadCleanup\' && bash \'$uploadCleanup\' \'$PreviewPort\'' in wrapper
    assert "msb-controller-preview-session-$stamp" in wrapper
    assert "msb-controller-browser-preview-$stamp" in wrapper
    assert "mv '$uploadRoot' '$remoteRoot'" in wrapper


def test_preview_launcher_keeps_one_upload_and_one_foreground_ssh_session() -> None:
    wrapper = (ACCEPT / "run_controller_setup_management_browser_preview.ps1").read_text(
        encoding="utf-8"
    )

    assert wrapper.count("& scp -r") == 1
    assert wrapper.count("& ssh -tt -L") == 1
    assert "Start-Process ssh" not in wrapper
    assert "timeout --signal=TERM 7200s" in wrapper
