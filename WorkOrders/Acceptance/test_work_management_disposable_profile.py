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



def test_clone_sql_is_streamed_from_host_file_with_real_newline():
    """Host-side worktree paths are not mounted into the disposable DB container."""
    runner = RUNNER.read_text(encoding="utf-8")
    assert 'printf \'%s\\n\' "SET msb.wo419_preview_authorized=' in runner
    assert '} | psql_clone' in runner
    assert 'cat "$WORKTREE/WorkOrders/Acceptance/wo419_preview_clone_read_grants.sql"' in runner
    assert 'psql_clone -c "SET msb.wo419_preview_authorized=' not in runner
    assert '  -f "$WORKTREE/WorkOrders/Acceptance/wo419_preview_clone_read_grants.sql"' not in runner


def test_postgis_clone_waits_for_final_pid1_not_temporary_init_server():
    """Prevent the documented PostGIS temporary-server pg_isready restore race."""
    runner = RUNNER.read_text(encoding="utf-8")
    assert "PostgreSQL_Disposable_Acceptance_Standard.md" in runner
    assert "pid1=" in runner
    assert "sudo docker inspect" in runner
    assert "'{{.State.Running}}'" in runner
    assert "sh -c 'cat /proc/1/comm'" in runner
    assert '[[ "$pid1" == "postgres" ]]' in runner
    assert "pg_isready" in runner
    assert "PASS: disposable PostgreSQL final post-init PID1=postgres" in runner
    assert "sudo docker logs --tail 40" in runner
    assert "oom_killed={{.State.OOMKilled}}" in runner
    assert "HOLD: disposable PostgreSQL restore failed" in runner
    assert runner.index("cat /proc/1/comm") < runner.index("createdb -U")
    assert runner.index('[[ "$pid1" == "postgres" ]]') < runner.index("pg_restore -U")
    assert "PASS: disposable database restore finished" in runner


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
        "transaction_read_only",
        "WO-372",
        "INTAKE-60",
        "person_id",
        "related_information",
        "not browser or P0 acceptance",
    ):
        assert required in s


def test_disposable_preview_runs_full_established_application_regressions():
    """#419 feature tests must not replace the established Setup/FieldWiring gates."""
    runner = RUNNER.read_text(encoding="utf-8")
    assert "Setup/Application Setup/Acceptance/test_setup_gis_preview.py" in runner
    assert "FieldWiring/Application" in runner
    assert "WorkOrders/Application/test_work_management_preview.py" in runner
    assert "WorkOrders/Acceptance/test_work_management_disposable_profile.py" in runner
    assert runner.index("Setup/Application Setup/Acceptance/test_setup_gis_preview.py") < runner.index('sudo docker exec "$PRODUCTION_CONTAINER" pg_dump')
    assert runner.index("FieldWiring/Application") < runner.index('sudo docker exec "$PRODUCTION_CONTAINER" pg_dump')


def test_clone_read_failure_reports_safe_validation_stage():
    """Next real clone HOLD must identify which query/authorization stage failed."""
    source = CLONE_CHECK.read_text(encoding="utf-8")
    for stage in (
        "clone_connection", "read_only_transaction", "clone_identity",
        "unified_ledger_query", "reviewer_authorization", "my_work_query",
        "all_tickets_query", "assignee_selector_query",
        "intake_60_detail_query", "intake_60_related_information",
    ):
        assert f'phase("{stage}")' in source
    assert "phase={CURRENT_PHASE}" in source
    assert "exception_class={type(exc).__name__}" in source
    assert "traceback.print_exc" not in source
    assert "print(exc)" not in source
