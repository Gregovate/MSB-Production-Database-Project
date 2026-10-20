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


def test_clone_candidate_sha_verified_by_privileged_runner_not_service_git():
    """Retain root/service-account Git boundary and reject missing SHA proof."""
    shell = RUNNER.read_text(encoding="utf-8")
    validator = CLONE_CHECK.read_text(encoding="utf-8")
    assert 'VERIFIED_WORKTREE_SHA="$(sudo git -C "$WORKTREE" rev-parse HEAD)"' in shell
    assert '[[ "$VERIFIED_WORKTREE_SHA" == "$CANDIDATE_SHA" ]]' in shell
    assert 'WORK_MGMT_VERIFIED_CANDIDATE_SHA="$VERIFIED_WORKTREE_SHA"' in shell
    assert 'os.environ.get("WORK_MGMT_VERIFIED_CANDIDATE_SHA"' in validator
    assert 'subprocess.check_output(' not in validator


def test_work_orders_preview_transport_recovers_using_setup_contract():
    """Use the same protected resumable preview lifecycle already accepted for Setup."""
    shell = RUNNER.read_text(encoding="utf-8")
    wrapper = WRAPPER.read_text(encoding="utf-8")
    setup = (HERE.parent.parent / "Setup/Acceptance/setup_disposable_browser_preview_server.sh").read_text(encoding="utf-8")
    assert "PRESERVE_FOR_RECONNECT" in setup
    assert 'STATE_FILE="/tmp/msb-wo419-preview-state-' + '$' + '{PREVIEW_PORT}.env"' in shell
    assert 'trap cleanup EXIT' in shell
    assert "PRESERVE_FOR_RECONNECT=1" in shell
    assert "resume_existing_preview()" in shell
    assert '"$MODE" == "resume"' in shell
    assert "write_resume_state" in shell
    assert "WO419 DISPOSABLE BROWSER REVIEW RESUMED" in shell
    assert "if ! read -r -p" in shell
    assert "Same private clone" in shell
    assert "no new clone" in wrapper.lower()
    assert "$maxReconnectAttempts = 12" in wrapper
    assert "$mode = 'resume'" in wrapper
    assert '$remoteExit -notin @(75, 255)' in wrapper
    assert "Start-Sleep -Seconds 2" in wrapper
    assert "Get-NetTCPConnection" in wrapper
    assert "ssh -tt -o ServerAliveInterval=15" in wrapper
    assert " start; " in wrapper and " resume; " in wrapper
    assert 'if [ "$rc" -eq 0 ]; then rm -f' in wrapper
    assert "Stop-Process" not in wrapper
    assert "Start-Process" not in wrapper
    assert "git reset --hard" not in wrapper
    assert shell.index('if [[ "$MODE" == "resume" ]]') < shell.index('sudo git -C "$REPO_ROOT" fetch origin')
    for required in (
        'sudo ps -p "$pid" -o uid=',
        'id -u fieldwiring',
        'current="$(wo419_listener_pid)"',
        '.State.Running',
        'msb_wo419_preview',
        'git -C "$WORKTREE" rev-parse HEAD',
        '/api/work-orders/health',
        'saved_version',
        'expected_version',
        'PREVIEW_EMAIL',
        'VERIFIED_WORKTREE_SHA',
    ):
        assert required in shell, required


def test_wo419_resume_state_is_valid_private_bash_and_has_no_credentials(tmp_path):
    """Execute Bash metadata writer and re-source the result in a separate shell."""
    if not shutil.which("bash"):
        pytest.skip("Bash required for server state fixture")
    shell = RUNNER.read_text(encoding="utf-8")
    start = shell.index("write_resume_state() {")
    end = shell.index("\n\nresume_existing_preview() {", start)
    function = shell[start:end]
    state = tmp_path / "wo419-state.env"
    script = "\n".join([
        "set -euo pipefail",
        "STATE_FILE=$1",
        "CANDIDATE_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "CANDIDATE_REF=issue-419-unified-ticket-read-model-20261018",
        "PREVIEW_EMAIL=reviewer@sheboyganlights.org",
        "PREVIEW_PORT=8898",
        "CLONE_CONTAINER=msb-wo419-preview-77",
        "CLONE_DATABASE=msb_wo419_preview",
        "CLONE_OWNED=1",
        "WORKTREE=/tmp/msb-wo419-preview-candidate-fixture-77",
        "DUMP=/tmp/msb-wo419-preview-fixture-77.dump",
        "REPORT=/tmp/WO419-fixture-report.txt",
        "APP_LOG=/tmp/WO419-fixture-app.log",
        "PREVIEW_PID=177",
        "PROD_BEFORE=0123456789abcdef",
        "LIVE_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "VERIFIED_WORKTREE_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        function,
        "write_resume_state",
        "bash -c 'set -euo pipefail; source \"$1\"; "
        "test \"$PREVIEW_PORT\" = 8898; "
        "test \"$PREVIEW_PID\" = 177; "
        "test \"$CLONE_DATABASE\" = msb_wo419_preview; "
        "test \"$PREVIEW_EMAIL\" = reviewer@sheboyganlights.org' bash \"$STATE_FILE\"",
    ])
    first = subprocess.run(
        ["bash", "-c", script, "bash", str(state)],
        capture_output=True, text=True,
    )
    assert first.returncode == 0, first.stderr
    content = state.read_text(encoding="utf-8")
    for token in ("CANDIDATE_SHA=", "PREVIEW_PID=177\n", "PROD_BEFORE=",
                  "VERIFIED_WORKTREE_SHA="):
        assert token in content, token
    assert state.stat().st_mode & 0o777 == 0o600
    for forbidden in ("WRITE_TOKEN", "PASSWORD", "CSRF", "DSN"):
        assert forbidden not in content
    again = subprocess.run(
        ["bash", "-c", script, "bash", str(state)],
        capture_output=True, text=True,
    )
    assert again.returncode != 0
    assert "state already exists" in again.stdout


def test_wo419_runner_start_resume_argument_gate_before_any_server_actions():
    """Five-argument start/resume entry must not be mistaken for four-only."""
    shell = RUNNER.read_text(encoding="utf-8")
    assert 'if [[ $# -lt 4 || $# -gt 5 ]]; then' in shell
    assert 'MODE="' + '$' + '{5:-start}"' in shell
    if not shutil.which("bash"):
        pytest.skip("Bash required for early-argument regression")
    for args, expected in (
        (["short"], "optional start/resume mode required"),
        (["badsha", "8898", "reviewer@sheboyganlights.org",
          "issue-419-unified-ticket-read-model-20261018", "resume"], "exact 40-hex"),
        (["badsha", "8898", "reviewer@sheboyganlights.org",
          "issue-419-unified-ticket-read-model-20261018", "resume", "extra"],
         "optional start/resume mode required"),
    ):
        result = subprocess.run(["bash", str(RUNNER), *args],
                                capture_output=True, text=True)
        assert result.returncode == 2, result.stderr
        assert expected in result.stdout, result.stdout
    wrapper = WRAPPER.read_text(encoding="utf-8")
    assert '$StartCommand = $RemotePrefix + ((' in wrapper
    assert '$ResumeCommand = $RemotePrefix + ((' in wrapper
    assert 'rc=$?; if [ "$rc" -eq 0 ]; then rm -f' in wrapper


def test_wo419_cleanup_uses_real_listener_and_preserves_unknown_owners(tmp_path):
    """Exercise the exact Bash cleanup with disposable local socket processes.

    No Docker, SSH, Production database, server users or privileged operations.
    This reproduces the setsid $! versus bound-PID mismatch and unknown owner.
    """
    import os
    import re
    import signal
    import socket
    import sys
    import time

    runner = RUNNER.read_text(encoding="utf-8")
    assert 'LAUNCH_PID="$(' in runner
    assert 'PREVIEW_PID="$(wo419_listener_pid)"' in runner
    assert 'if ! wo419_verified_listener "$PREVIEW_PID"' in runner
    assert 'sudo -u fieldwiring -H kill -TERM -- "$listener"' in runner
    assert 'sudo -u fieldwiring -H kill -- -"$PREVIEW_PID"' not in runner
    assert runner.index('echo "PASS: verified Work Orders listener stopped') < runner.index(
        'sudo docker rm -f "$CLONE_CONTAINER"'
    )
    for safeguard in (
        "PASS: owned disposable clone removed",
        "HOLD: owned disposable clone still exists after teardown",
        "PASS: disposable candidate worktree unregistered",
        "HOLD: disposable candidate worktree still registered",
        "HOLD: private preview resume state remained after teardown",
        "WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT",
    ):
        assert safeguard in runner, safeguard
    assert 'if [[ -e "$STATE_FILE" || -L "$STATE_FILE" ]]; then' in runner
    if not all(shutil.which(exe) for exe in ("bash", "setsid", "ss")):
        pytest.skip("Linux Bash, setsid and ss required for live process test")

    helper = runner[runner.index("wo419_listener_pid() {"):
                    runner.index("\ncleanup() {")]
    cleanup = runner[runner.index("cleanup() {"):
                     runner.index("\ntrap cleanup EXIT")]
    root = tmp_path / "owned-candidate"
    entry = root / "WorkOrders" / "Application" / "preview_entry.py"
    entry.parent.mkdir(parents=True)
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    entry.write_text(
        "import socket,time\ns=socket.socket()\n"
        "s.bind(('127.0.0.1'," + str(port) + "))\n"
        "s.listen(5)\ntime.sleep(50)\n", encoding="utf-8",
    )
    launched = subprocess.run(
        ["bash", "-c", 'setsid "$1" "$2" > "$3" 2>&1 & echo $!',
         "bash", sys.executable, str(entry), str(tmp_path / "app.log")],
        capture_output=True, text=True, timeout=8,
    )
    assert launched.returncode == 0, launched.stderr
    launch_pid = int(launched.stdout.strip())
    live_pid = None
    try:
        deadline = time.monotonic() + 7
        while time.monotonic() < deadline:
            found = subprocess.run(
                ["ss", "-ltnp", "sport = :" + str(port)],
                capture_output=True, text=True,
            )
            matches = re.findall(r"pid=(\d+),", found.stdout)
            if matches:
                live_pid = int(matches[0])
                break
            time.sleep(.15)
        assert live_pid is not None, "Local socket fixture did not start"

        def exercise(expected_root, saved_pid, marker):
            script = "\n".join([
                "set -Eeuo pipefail",
                'PYTHON="$1"; WORKTREE="$2"; PREVIEW_PORT="$3"; PREVIEW_PID="$4"',
                'STATE_FILE="$5"; CLONE_OWNED=0; CLONE_CONTAINER=""; DUMP=""',
                'PROD_BEFORE=""; LIVE_HEAD=""; REPORT="fixture"; REPO_ROOT=""',
                'PRESERVE_FOR_RECONNECT=0',
                'sudo() { if [[ "$1" == "-u" ]]; then shift 3; fi; "$@"; }',
                'id() { if [[ "$1" == "-u" && "$2" == "fieldwiring" ]]; then command id -u; else command id "$@"; fi; }',
                helper, cleanup,
                'trap cleanup EXIT',
                'exit 0',
            ])
            return subprocess.run(
                ["bash", "-c", script, "bash", sys.executable,
                 str(expected_root), str(port), str(saved_pid), str(marker)],
                capture_output=True, text=True, timeout=15,
            )

        marker = tmp_path / "owner-state"
        marker.write_text("RETAIN\n", encoding="utf-8")
        foreign = exercise(tmp_path / "wrong-worktree", "", marker)
        assert foreign.returncode == 83, foreign.stdout + foreign.stderr
        assert "no kill or clone removal" in foreign.stdout
        assert marker.read_text(encoding="utf-8") == "RETAIN\n"
        assert subprocess.run(
            ["ss", "-ltnH", "sport = :" + str(port)],
            capture_output=True, text=True,
        ).stdout.strip(), "Unknown listener must remain running"

        owned = exercise(root, live_pid, marker)
        assert owned.returncode == 0, owned.stdout + owned.stderr
        assert "PASS: verified Work Orders listener stopped" in owned.stdout
        assert "WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT" in owned.stdout
        assert not marker.exists(), "Successful owned teardown removes resume state"
        assert not subprocess.run(
            ["ss", "-ltnH", "sport = :" + str(port)],
            capture_output=True, text=True,
        ).stdout.strip(), "Port must be released before declaring clean exit"
        assert launch_pid > 0
    finally:
        for pid in {launch_pid, live_pid}:
            if pid:
                try:
                    os.kill(pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass


def test_v1_acceptance_reuses_original_disposable_runner_and_rolls_back():
    """V1 is validated inside the existing 8898 clone; no new runner/port."""
    shell = RUNNER.read_text(encoding="utf-8")
    wrapper = WRAPPER.read_text(encoding="utf-8")
    acceptance = (HERE / "wo419_v1_disposable_validation.sql").read_text(encoding="utf-8")
    migration = (HERE.parent / "Database" /
                 "001_work_management_v1_governed_commands.sql").read_text(encoding="utf-8")
    assert "validate_v1" in shell
    assert 'if [[ "$MODE" == "validate_v1" ]]; then' in shell
    assert 'CREATE ROLE work_management_app NOLOGIN' in shell
    assert 'SET msb.wo419_preview_authorized=' in shell
    assert 'WorkOrders/Database/001_work_management_v1_governed_commands.sql' in shell
    assert 'WorkOrders/Acceptance/wo419_v1_disposable_validation.sql' in shell
    assert 'WO419 V1 DISPOSABLE SQL VALIDATION PASS' in shell
    assert shell.index('pg_restore -U') < shell.index('CREATE ROLE work_management_app NOLOGIN')
    assert shell.index('WO419 V1 DISPOSABLE SQL VALIDATION PASS') < shell.index(
        'Start pinned Work Management reviewer'
    )
    assert "  exit 0\nfi\n\necho \"--- Start pinned Work Management reviewer" in shell
    assert '[switch]$V1Validation' in wrapper
    assert '$ValidationCommand' in wrapper
    assert 'validate_v1; ' in wrapper
    assert 'if ($V1Validation)' in wrapper
    assert 'WO419 V1 disposable SQL validation: CLEAN EXIT' in wrapper
    assert 'do not start a browser' in wrapper.lower()
    assert "current_database() NOT IN ('msb', 'msb_wo419_preview')" in migration
    assert "msb.wo419_preview_authorized" in migration
    assert "work_management_app" in migration
    assert "BEGIN;\nDO $v1test$" in acceptance
    assert acceptance.rstrip().endswith(
        "-- survives even inside this disposable database."
    )
    assert "\nROLLBACK;" in acceptance
    assert "native Manager Create" in acceptance
    assert "non-Manager native create accepted" in acceptance
    assert "actual progress notes" in acceptance or "progress unexpectedly closed" in acceptance
    assert "Intake provenance not retained" in acceptance
    assert "unsanctioned mail SENT state" in acceptance
    assert "DELETE FROM ops.work_order" not in acceptance
    assert "UPDATE stage.work_order_intake" not in acceptance
    assert "TRUNCATE" not in acceptance


def test_oct19_v1_clone_preflight_respects_tom_approved_year_and_intake_rules():
    """Prevent V1 SQL validation being blocked by outdated clone fixtures.

    Regression for retained report:
    WO419_Disposable_Browser_Preview_20261020T004438.txt
    phase=clone_write_transaction_rollback; non-Planning target year rejected.
    """
    validator = CLONE_CHECK.read_text(encoding="utf-8")
    source = (APP / "commands.py").read_text(encoding="utf-8")
    repository = (APP / "repository.py").read_text(encoding="utf-8")
    assert 'phase("clone_write_transaction_rollback")' in validator
    assert '"urgency": 3,' in validator
    assert '"target_year": None,  # Priority 3: Tom-approved Planning-only year' in validator
    assert '"target_year": 2026' not in validator
    assert 'phase("crew_direct_create_denied")' in validator
    assert 'phase("crew_direct_create_rollback")' not in validator
    assert 'writer.perform(access, "create", None' in validator
    assert 'if denied.status != 403' in validator
    assert 'Crew direct native Create denied before write PASS' in validator
    assert 'Crew direct-create preflight' not in validator
    assert 'if urgency == 5:' in source
    assert 'Target year applies only to Planning (urgency 5).' in source
    assert 'return {"can_manage": can_manage, "can_create": can_manage' in repository


def test_v1_sql_quoted_literals_and_function_structure():
    migration = (HERE.parent / "Database" / "001_work_management_v1_governed_commands.sql").read_text(encoding="utf-8")
    assert migration.count("CREATE OR REPLACE FUNCTION ops.work_management_v1_command(") == 1
    assert migration.count("CREATE OR REPLACE FUNCTION ops.work_management_v1_activity(") == 1
    assert migration.count("COMMIT;") == 1
    for tag in ("$preflight$", "$func$", "$cmd$", "$activity$"):
        assert migration.count(tag) == 2
    assert "WHERE item.value ~ '^[1-9][0-9]{0,9}$';" in migration
    for line_number, line in enumerate(migration.splitlines(), 1):
        assert line.split("--", 1)[0].count("'") % 2 == 0, line_number


def test_v1_browser_reuses_same_preview_runner_with_native_sql_not_clonecommands():
    runner = RUNNER.read_text(encoding="utf-8")
    wrapper = WRAPPER.read_text(encoding="utf-8")
    entry = ENTRY.read_text(encoding="utf-8")
    backend = (APP / "backend.py").read_text(encoding="utf-8")
    assert 'start_v1_manager' in runner
    assert 'start_v1_crew' in runner
    assert 'CREATE ROLE work_management_app LOGIN PASSWORD' in runner
    assert 'WORK_MGMT_RUNTIME_MODE="$APP_RUNTIME"' in runner
    assert 'WORK_MGMT_V1_CLONE_DSN="$V1_DSN"' in runner
    assert 'WORK_MGMT_V1_CLONE_IP="$HOST_IP"' in runner
    assert 'WORK_MGMT_V1_CLONE_WRITE_GATE="approved_private_clone"' in runner
    assert 'WO419 V1 NATIVE BROWSER REVIEW READY' in runner
    assert "PASS: exact reviewer temporarily receives V1 Manager permission in clone" in runner
    assert "PASS: V1 Crew review retains no Manager permissions in clone" in runner
    assert 'WO419 BROWSER REVIEW READY' in runner
    assert "if [[ \"$MODE\" == \"validate_v1\" ]]; then" in runner
    assert 'printf \'%s\\n\' "SET msb.wo419_preview_authorized=' in runner
    assert '[switch]$V1Browser' in wrapper
    assert "$V1RoleMode" in wrapper
    assert "$V1BrowserCommand" in wrapper
    assert "WO419 V1 native browser tunnel: CLEAN EXIT" in wrapper
    assert "WORK_MGMT_RUNTIME_MODE" in backend
    assert '("production", "v1_disposable")' in backend
    assert 'from v1_runtime import V1Repository' in backend
    assert 'from v1_runtime import V1Commands' in backend
    assert 'V1Repository().access(email)' in entry
    assert runner.index('echo "PASS: V1 native SQL installed') < runner.index(
        '--- Start pinned Work Management reviewer'
    )
