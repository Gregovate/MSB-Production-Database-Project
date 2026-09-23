from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
LAUNCHER = REPO_ROOT / "run_folder_check.ps1"


def test_folder_alignment_launcher_does_not_test_null_default_output_directory() -> None:
    launcher = LAUNCHER.read_text(encoding="utf-8")

    assert "$DefaultOutputDir" not in launcher
    assert "$OutputDir = if ($env:MSB_FOLDER_ALIGNMENT_OUTPUT_DIR)" in launcher
    assert "else {\n    $null\n}" in launcher


def test_folder_alignment_launcher_opens_exact_paths_emitted_by_python() -> None:
    launcher = LAUNCHER.read_text(encoding="utf-8")

    assert "$RunOutput = [System.Collections.Generic.List[string]]::new()" in launcher
    assert "Procedure Inventory HTML" in launcher
    assert "$HtmlPaths" in launcher
    assert "Test-Path -LiteralPath $HtmlPath -PathType Leaf" in launcher
    assert "Start-Process $HtmlPath" in launcher
