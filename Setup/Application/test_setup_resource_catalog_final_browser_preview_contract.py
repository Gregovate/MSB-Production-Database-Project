from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]
FINAL_WRAPPER = REPO_ROOT / "Setup" / "Acceptance" / "run_setup_resource_catalog_final_browser_preview.ps1"


def test_final_resource_catalog_preview_pins_exact_runtime_candidate() -> None:
    text = FINAL_WRAPPER.read_text(encoding="utf-8")
    assert "d74202002e6845b291dc937697f4589d3f4be6c3" in text
    assert "17590dc3a3e81dd67e38fcb42ba38e69beeea089" in text
    assert "run_setup_resource_catalog_browser_preview.ps1" in text


def test_final_resource_catalog_preview_rewrites_nested_psscriptroot_paths() -> None:
    text = FINAL_WRAPPER.read_text(encoding="utf-8")
    assert "$acceptanceDirLiteral = $PSScriptRoot.Replace" in text
    assert "$nestedBaseNeedle" in text
    assert "run_setup_source_only_browser_preview.ps1" in text
    assert "$nestedCleanupNeedle" in text
    assert "setup_session_browser_preview_cleanup_server.sh" in text
    assert "Final #152 preview could not find exactly one $description." in text


def test_final_resource_catalog_preview_preserves_save_then_close_acceptance() -> None:
    text = FINAL_WRAPPER.read_text(encoding="utf-8")
    assert "colored Close Resource Catalog button sits directly beside Save Catalog Resource" in text
    assert "Save an edit, then close the catalog" in text
    assert "FINAL browser acceptance checklist" in text
