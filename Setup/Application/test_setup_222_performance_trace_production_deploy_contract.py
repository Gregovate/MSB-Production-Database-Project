from pathlib import Path

ROOT = Path(__file__).resolve().parent
ACCEPT = ROOT.parent / "Acceptance"


def read_accept(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_222_wrapper_is_source_only_and_pinned() -> None:
    wrapper = read_accept("run_setup_222_performance_trace_production_deploy.ps1")

    assert "$ExpectedBranch = 'main'" in wrapper
    assert "1b08bdd26156b67ba89ea484fdc035b0b09ffc28" in wrapper
    assert "64835504962247d7a09c1146e5e77d8e19948559" in wrapper
    assert "59a01d1cbd87f6044a7d2b3a3badcf728b4e38a2" in wrapper
    assert "merge-base --is-ancestor" in wrapper
    assert "hash-object $ServerScript" in wrapper
    assert "scp -r $localBundle" in wrapper
    assert "ssh -tt -o ServerAliveInterval=15" in wrapper
    assert "timeout --foreground --signal=TERM 3600s" in wrapper
    assert "Start-Process" not in wrapper
    assert "ssh -f" not in wrapper


def test_222_runner_obeys_source_only_runbook_and_mutates_no_database() -> None:
    server = read_accept("setup_222_performance_trace_production_deploy_server.sh")

    assert 'EXPECTED_LIVE_SHA="1b08bdd26156b67ba89ea484fdc035b0b09ffc28"' in server
    assert 'TARGET_SHA="64835504962247d7a09c1146e5e77d8e19948559"' in server
    assert 'EXPECTED_PRE_VERSION="V0.3.16-stale-ownership-cleanup"' in server
    assert 'EXPECTED_POST_VERSION="V0.3.17-performance-trace"' in server
    assert "Setup_Source_Only_Application_Deployment_Runbook.md" in server
    assert "Database mutation: NONE" in server
    assert "Environment/service-unit/proxy/firewall mutation: NONE" in server

    assert "pg_dump" not in server
    assert "pg_restore" not in server
    assert "psql_prod <" not in server
    assert "INSERT INTO " not in server
    assert "UPDATE ops." not in server
    assert "DELETE FROM " not in server
    assert "ALTER TABLE " not in server
    assert "CREATE TABLE " not in server


def test_222_runner_regresses_before_and_after_source_promotion() -> None:
    server = read_accept("setup_222_performance_trace_production_deploy_server.sh")

    detached = server.index("--- Detached exact-target regression in Production runtime ---")
    promote = server.index("This step: advance /opt/msb-setup")
    restart = server.index("--- Restart only msb-setup.service and verify V0.3.17 ---")
    trace = server.index("--- Validate trace headers and journal emission ---")
    live = server.index("--- Live Setup regression ---")

    assert detached < promote < restart < trace < live
    assert "worktree add --detach" in server
    assert "'$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application" in server
    assert "DETACHED EXACT-TARGET SETUP REGRESSION: PASS" in server
    assert "LIVE SETUP REGRESSION: PASS" in server


def test_222_runner_validates_real_journal_trace_without_operator_data_payloads() -> None:
    server = read_accept("setup_222_performance_trace_production_deploy_server.sh")

    assert "Server-Timing: app;dur=" in server
    assert "X-MSB-Request-ID" in server
    assert "performance-probe@invalid.local" in server
    assert "journalctl -u" in server
    assert "SETUP_PERF request_id=" in server
    assert "request.get_data" not in server
    assert "request.get_json" not in server


def test_222_runner_has_source_only_rollback() -> None:
    server = read_accept("setup_222_performance_trace_production_deploy_server.sh")

    assert 'checkout --detach "$TARGET_SHA"' in server
    assert 'checkout --detach "$OLD_HEAD"' in server
    assert 'sudo systemctl restart "$SETUP_SERVICE"' in server
    assert "SOURCE-ONLY FAIL-CLOSED ROLLBACK" in server
