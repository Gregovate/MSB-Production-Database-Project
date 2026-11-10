"""PR478 governed release profile contracts; no host contact or Production writes."""
import ast
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / "Acceptance"
RUNNER = (BASE / "setup_478_local_calendar_release.py").read_text(encoding="utf-8")
WRAPPER = (BASE / "run_setup_478_local_calendar_release.ps1").read_text(encoding="utf-8")
MANIFEST = json.loads((BASE / "setup_478_local_calendar_release.json").read_text(encoding="utf-8"))


def test_release_runner_parses_and_reuses_existing_controller():
    ast.parse(RUNNER)
    assert "from setup_maintenance_deploy import Deploy" in RUNNER
    assert "orchestrator.Deploy = CalendarRelease" in RUNNER
    assert "super().deploy()" not in RUNNER  # inherited orchestrator deployment
    assert "self.controller(\"on\")" not in RUNNER
    assert "self.controller(\"off\")" not in RUNNER
    assert "self.controller(\"snapshot\")" not in RUNNER


def test_exact_browser_accepted_candidate_and_one_migration():
    assert MANIFEST["candidate"] == "df5aedd897aa967e1c567dd9d53e40da1712f308"
    assert MANIFEST["target"] == "e1d5c9d9d5ef5a8c59f0381ea559d240aed1c30b"
    assert MANIFEST["old_setup"] == "85769c951429cec6faa1ed8ae627501bb8ba028b"
    assert MANIFEST["migration"] == "Setup/Database/079_fix_setup_local_calendar_boundaries.sql"
    assert MANIFEST["version"] == "V0.3.106-local-calendar"
    assert "self.function_gate(installed=False)" in RUNNER
    assert "self.function_gate(installed=True)" in RUNNER
    assert "self.capture() == baseline" in RUNNER
    assert "self.online()" in RUNNER
    assert "self.regression(self.worktree)" in RUNNER


def test_workstation_handoff_is_isolated_and_current_directory_independent():
    assert "C:\\lor\\ImportExport\\MSB-Main" in WRAPPER
    assert "git rev-parse --show-toplevel" not in WRAPPER
    assert "worktree add --detach" in WRAPPER
    assert "git -C $Primary worktree remove" in WRAPPER
    assert "setup_478_transport.py" in WRAPPER
    assert "& ssh -tt" in WRAPPER
    assert "-Deploy" not in WRAPPER or "[switch]$Deploy" in WRAPPER
    assert "node" not in WRAPPER.lower()


def test_no_broad_database_date_or_replay_action():
    sql = (BASE.parent / "Database" / "079_fix_setup_local_calendar_boundaries.sql").read_text()
    assert sql.count("SET TimeZone TO 'America/Chicago'") == 4
    for denied in ("ALTER DATABASE", "ALTER ROLE", "UPDATE ", "DELETE ", "INSERT "):
        assert denied not in sql
