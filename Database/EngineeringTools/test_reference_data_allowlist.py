"""#171/#230 reference-data allowlists: exact paths and default-deny policy.

These tests validate candidate policy documents, not Production privileges.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACCEPTANCE = ROOT / "Database" / "Acceptance"


def test_disposable_sql_allowlist_has_only_exact_owned_paths():
    path = ACCEPTANCE / "reference_data_disposable_allowlist.json"
    policy = json.loads(path.read_text(encoding="utf-8"))
    assert policy["schema_version"] == 1
    paths = policy["approved_migration_paths"] + policy["approved_validation_paths"]
    assert len(paths) == len(set(paths))
    assert paths, "An empty reference-data allowlist should be deliberate"
    for item in paths:
        assert isinstance(item, str)
        assert re.fullmatch(r"Database/[A-Za-z0-9_./-]+\.sql", item)
        assert ".." not in item and "*" not in item
        assert (ROOT / item).is_file(), f"Approved candidate path missing: {item}"


def test_manager_table_allowlist_is_default_deny_and_explicit():
    path = ACCEPTANCE / "reference_data_manager_table_allowlist.json"
    policy = json.loads(path.read_text(encoding="utf-8"))
    assert policy["schema_version"] == 1
    assert policy["status"] == "DESIGN_ONLY_NOT_ENFORCED"
    collections = policy["collections"]
    names = [entry["table"] for entry in collections]
    assert len(names) == len(set(names))
    assert {"ref.display", "ref.container", "ref.storage_location",
            "ref.site_waypoint", "ref.site_cable", "ref.site_network"} <= set(names)
    assert all(re.fullmatch(r"ref\.[a-z][a-z_0-9]*", name) for name in names)
    assert all(entry["protected_columns"] for entry in collections)
    assert all(entry["planned_actions"] for entry in collections)
    display = next(item for item in collections if item["table"] == "ref.display")
    assert {"display_id", "display_name", "lor_prop_id",
            "stage_id", "string_type"} <= set(display["protected_columns"])
    assert "ref.site_waypoint_source_binding" in policy["internal_only"]
    assert "ops.linkiq_test" in policy["internal_only"]


def test_shared_disposable_runner_uses_candidate_scoped_allowlist():
    wrapper = (ROOT / "Setup" / "Acceptance"
               / "run_setup_disposable_acceptance.ps1").read_text(encoding="utf-8")
    assert 'reference_data_disposable_allowlist.json' in wrapper
    assert '"${CandidateSha}:$referenceAllowlistPath"' in wrapper
    assert "$referenceMigrationPaths -ccontains $Path" in wrapper
    assert "if (@($referenceSqlPaths).Count -gt 0)" in wrapper
    assert "historical Setup-only previews" in wrapper
    # Historical Setup acceptance still owns these specific shared audit gates;
    # the reference-data extension must never erase their existing contract.
    assert "explicitly approved shared database repair" in wrapper
    assert "explicitly approved shared database validation" in wrapper


def test_disposable_runner_preserves_remote_ref_and_local_review_branch():
    wrapper = (ROOT / 'Setup' / 'Acceptance'
               / 'run_setup_disposable_acceptance.ps1').read_text(encoding='utf-8')
    assert "[string]$LocalReviewBranch = ''" in wrapper
    assert '$LocalReviewBranch = $TargetRef' in wrapper
    assert '$currentBranch -ne $LocalReviewBranch' in wrapper
    assert '"refs/remotes/origin/$TargetRef"' in wrapper
    assert '$remoteHead -ne $CandidateSha' in wrapper
    # Server receives both values through the acceptance manifest, not quoted
    # as standalone shell arguments in the remote command.
    assert '"candidate_sha`t$CandidateSha"' in wrapper
    assert '"target_ref`t$TargetRef"' in wrapper
    assert "'$remoteRunner' '$remoteManifest'" in wrapper
    assert "$referenceValidationPaths -ccontains $Path" in wrapper
    assert "171_site_infrastructure_schema_candidate.sql'" not in wrapper
    assert "171_site_infrastructure_disposable_validation.sql'" not in wrapper
