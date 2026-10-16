"""#205 browser runbook: don't declare READY when live-clone Setup Board is HTTP 500."""
from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import pytest


RUNNER = Path(__file__).resolve().parents[1] / "Acceptance" / "setup_disposable_browser_preview_server.sh"


def test_setup_browser_readiness_includes_real_cloned_scheduling_board_get():
    script = RUNNER.read_text(encoding="utf-8")
    smoke = 'http://127.0.0.1:$PREVIEW_PORT/api/setup/scheduling-board?season_year=2026'
    ready = "SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY"
    assert smoke in script
    assert script.index(smoke) > script.index("Preview authorization: PASS")
    assert script.index(smoke) < script.index("write_resume_state\necho") if "write_resume_state\necho" in script else script.index(smoke) < script.index("write_resume_state\ncat <<CHECKLIST")
    assert script.index(smoke) < script.index(ready)
    assert "curl -fsS --max-time 60" in script
    assert "Scheduling Board disposable API failed before operator browser review" in script
    assert 'tail -n 75 "$PREVIEW_LOG"' in script
    assert "exit 25" in script
    assert 'http://127.0.0.1:$PREVIEW_PORT/api/setup/scheduling-board?season_year=2026' in script
    assert "POST /api/setup/scheduling-board" not in script


def test_shell_parser_accepts_preview_runner_after_preflight():
    if not shutil.which("bash"):
        pytest.skip("Bash is unavailable")
    result = subprocess.run(
        ["bash", "-n", str(RUNNER)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
