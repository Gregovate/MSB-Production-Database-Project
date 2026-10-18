"""#419 disposable profile source/runbook safety contract.

No SSH, Docker, Production DB, port, or external email is accessed here.
"""
from __future__ import annotations

from pathlib import Path
import shutil
import subprocess

import pytest

HERE = Path(__file__).resolve().parent
APP = HERE.parent / "Application"
RUNNER = HERE / "work_management_disposable_browser_preview_server.sh"
WRAPPER = HERE / "run_work_management_disposable_browser_preview.ps1"
GRANTS = HERE / "wo419_preview_clone_read_grants.sql"
CLONE_CHECK = HERE / "validate_work_management_clone.py"
ENTRY = APP / "preview_entry.py"


def test_server_runner_bash_parses_without_running():
    if not shutil.which("bash"):
        pytest.skip("Bash is only present on Linux/server or WSL")
    result = subprocess.run(["bash", "-n", str(RUNNER)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr


def test_exact_preview_profile_is_explicit_and_no_production_mutations():
    shell = RUNNER.read_text(encoding="utf-8")
    wrapper = WRAPPER.read_text(encoding="utf-8")
    assert 'PREVIEW_PORT" != "8898"' in shell
    assert '$PreviewPort -ne 8898' in wrapper
    assert 'ApprovedReviewProfile' in wrapper
    assert "Get-NetTCPConnection" in wrapper
    assert "sha256sum" in wrapper
    assert "timeout --foreground" in wrapper
    assert "ssh -tt" in wrapper
    assert "sudo -v" in shell
    assert 'set -Eeuo pipefail' in shell
    assert 'worktree add --detach' in shell
    assert '"$CANDIDATE_SHA"' in shell
    assert 'pg_dump' in shell and 'pg_restore' in shell
    assert '--network "$NETWORK"' in shell
    assert 'WORK_MGMT_PREVIEW_MODE=disposable' in shell
    assert 'WORK_MGMT_PREVIEW_EMAIL="$PREVIEW_EMAIL"' in shell
    assert 'WO419 BROWSER REVIEW READY' in shell
    assert 'WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT' in shell
    assert 'read -r -p' in shell
    for dangerous in (
        'systemctl restart',
        'systemctl stop',
        'docker rm -f "$PRODUCTION_CONTAINER"',
        'docker restart "$PRODUCTION_CONTAINER"',
        'git checkout main',
        'docker exec "$PRODUCTION_CONTAINER" psql -f',
    ):
        assert dangerous not in shell


def test_role_grants_cannot_run_on_production():
    sql = GRANTS.read_text(encoding="utf-8")
    assert "current_database() = 'msb'" in sql
    assert "msb.wo419_preview_authorized" in sql
    assert "IS DISTINCT FROM 'approved_disposable_clone'" in sql
    assert "GRANT SELECT ON" in sql
    for key in (
        "ops.work_order",
        "ops.work_order_assignment",
        "stage.work_order_intake",
        "ref.setup_task_container_support",
        "ref.lor_scene_display",
    ):
        assert key in sql
    assert "INSERT INTO" not in sql and "DELETE FROM" not in sql


def test_preview_header_is_replaced_with_pinned_reviewer():
    entry = ENTRY.read_text(encoding="utf-8")
    assert "WORK_MGMT_PREVIEW_MODE" in entry
    assert "WORK_MGMT_PREVIEW_EMAIL" in entry
    assert "request.environ.pop(EMAIL_HEADER, None)" in entry
    assert "request.environ[EMAIL_HEADER] = PREVIEW_EMAIL" in entry
    assert 'run_simple("127.0.0.1"' in entry


def test_clone_read_checker_validates_exact_sha_and_original_cases():
    s = CLONE_CHECK.read_text(encoding="utf-8")
    for required in (
        "checked_sha(args.candidate_sha)",
        "WORK_MGMT_PREVIEW_MODE",
        "current_database()",
        "readonly",
        "WO-372",
        "INTAKE-60",
        "person_id",
        "related_information",
        "not browser or P0 acceptance",
    ):
        assert required in s
