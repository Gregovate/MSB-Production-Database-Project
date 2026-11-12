"""#205/#395 reusable preview profile manifest regression.

Execute the REAL Bash manifest parsers only up to the first runtime action:
never call sudo, SSH, Docker, pg_dump, worktree commands or launch a server.
The original failure was the default Setup PowerShell wrapper emitting a
People-only preview_profile key, which the Setup parser correctly rejected.
"""
from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1] / "Acceptance"
WRAPPER = ROOT / "run_setup_disposable_browser_preview.ps1"
SETUP_RUNNER = ROOT / "setup_disposable_browser_preview_server.sh"
PEOPLE_RUNNER = ROOT / "people_identity_bootstrap_disposable_browser_preview_server.sh"


def test_launcher_emits_profile_key_only_for_people() -> None:
    source = WRAPPER.read_text(encoding="utf-8")
    common_start = source.index("    $manifestLines = @(")
    common_end = source.index("\n    )", common_start)
    common = source[common_start:common_end]
    assert "candidate_sha`t$CandidateSha" in common
    assert "target_ref`t$TargetRef" in common
    assert "preview_port`t$PreviewPort" in common
    assert "preview_email`t$PreviewEmail" in common
    assert "preview_profile" not in common, (
        "Default Setup runner does not accept the People-only profile field"
    )
    after = source[common_end:]
    people_block = re.search(
        r"if \(\$PreviewProfile -eq 'PeopleIdentityBootstrap'\) \{"
        r"(?P<body>[^{}]*?\$manifestLines \+= \"external_apps_blob`t\$ExternalAppsBlob\"[^{}]*?)\}",
        after,
        flags=re.S,
    )
    assert people_block is not None, "People-only manifest block must be present"
    assert '$manifestLines += "preview_profile`t$PreviewProfile"' in people_block["body"]
    assert '$manifestLines += "external_apps_sha`t$ExternalAppsSha"' in people_block["body"]
    assert '$manifestLines += "external_apps_blob`t$ExternalAppsBlob"' in people_block["body"]
    assert "setup_disposable_browser_preview_server.sh" in source
    assert "people_identity_bootstrap_disposable_browser_preview_server.sh" in source


def _parser_only(runner: Path, *, stop_before: str, manifest: Path) -> subprocess.CompletedProcess:
    if not shutil.which("bash"):
        pytest.skip("Bash runtime required for executable parser acceptance")
    source = runner.read_text(encoding="utf-8")
    assert stop_before in source
    # stop BEFORE temp files, sudo, Docker, port inspection, cleanup or pg_dump
    shell = source.split(stop_before, 1)[0] + "\necho MANIFEST_PARSER_ACCEPTED\n"
    script = manifest.parent / (runner.stem + "-parser-only.sh")
    script.write_text(shell, encoding="utf-8")
    return subprocess.run(
        ["bash", str(script), str(manifest)],
        capture_output=True, text=True, timeout=5, check=False,
    )


def _manifest(tmp_path: Path, entries: list[str]) -> Path:
    dest = tmp_path / "preview_manifest.tsv"
    dest.write_text("\n".join(entries) + "\n", encoding="utf-8")
    return dest


BASE = [
    "candidate_sha\te4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa",
    "target_ref\tfix/205-setup-deadline-kpis-20261015",
    "preview_port\t8898",
    "preview_email\tgliebig@sheboyganlights.org",
    "allow_concurrent_production_writes\tfalse",
    "expected_version\tV0.3.66-setup-action-center",
]


def test_default_setup_manifest_passes_actual_shell_parser(tmp_path: Path) -> None:
    result = _parser_only(
        SETUP_RUNNER, stop_before='STAMP="$(date +%Y%m%dT%H%M%S)"',
        manifest=_manifest(tmp_path, BASE),
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "MANIFEST_PARSER_ACCEPTED" in result.stdout


def test_setup_parser_fails_closed_on_people_profile_key(tmp_path: Path) -> None:
    manifest = _manifest(tmp_path, BASE + ["preview_profile\tSetup"])
    result = _parser_only(
        SETUP_RUNNER, stop_before='STAMP="$(date +%Y%m%dT%H%M%S)"', manifest=manifest,
    )
    assert result.returncode == 3
    assert "unsupported manifest key: preview_profile" in result.stdout
    assert "MANIFEST_PARSER_ACCEPTED" not in result.stdout


def test_people_profile_manifest_passes_its_actual_shell_parser(tmp_path: Path) -> None:
    manifest = _manifest(tmp_path, BASE + [
        "preview_profile\tPeopleIdentityBootstrap",
        "external_apps_sha\t" + "a" * 40,
        "external_apps_blob\t" + "b" * 40,
    ])
    result = _parser_only(PEOPLE_RUNNER, stop_before='REPO_ROOT="/opt/fieldwiring"',
                          manifest=manifest)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "MANIFEST_PARSER_ACCEPTED" in result.stdout


def test_people_parser_rejects_wrong_profile(tmp_path: Path) -> None:
    manifest = _manifest(tmp_path, BASE + [
        "preview_profile\tSetup",
        "external_apps_sha\t" + "a" * 40,
        "external_apps_blob\t" + "b" * 40,
    ])
    result = _parser_only(PEOPLE_RUNNER, stop_before='REPO_ROOT="/opt/fieldwiring"',
                          manifest=manifest)
    assert result.returncode == 3
    assert "wrong preview profile: Setup" in result.stdout
