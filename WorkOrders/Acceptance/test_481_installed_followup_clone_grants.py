"""#481: Production-derived clone already includes migration005.

The disposable runner must NEVER replay CREATE FUNCTION/CREATE TABLE statements
from migration005 into the restored snapshot. Only narrowly scoped grants
are reconstructed on the disposable clone and verified as clone-only.
"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
runner = (HERE / "work_management_disposable_browser_preview_server.sh").read_text()
grants = (HERE / "wo481_installed_followup_clone_grants.sql").read_text()


def test_both_native_browser_and_sql_validation_reuse_installed_005():
    assert runner.count('cat "$WORKTREE/WorkOrders/Acceptance/wo481_installed_followup_clone_grants.sql"') == 2
    assert 'cat "$WORKTREE/WorkOrders/Database/005_work_management_wo_followup.sql"' not in runner
    assert "start_v1_manager" in runner
    assert "validate_v1" in runner


def test_005_role_rebuild_requires_private_clone_and_complete_installed_schema():
    assert "msb_wo419_preview" in grants
    assert "approved_disposable_clone" in grants
    assert "installed migration005 objects missing" in grants
    for obj in (
        "ops.work_management_wo_followup(text,text,text,jsonb,uuid)",
        "ops.work_management_duplicate(text,text,text,jsonb,uuid)",
        "ops.work_management_duplicate_link",
        "ops.work_management_capture_mail()",
        "ops.work_management_v1_activity(text,text)",
    ):
        assert obj in grants
    assert "GRANT EXECUTE ON FUNCTION ops.work_management_duplicate" in grants
    assert "GRANT SELECT ON TABLE ops.work_management_duplicate_link" in grants
    assert "GRANT EXECUTE ON FUNCTION ops.work_management_wo_followup" in grants
    assert "TO work_management_app" in grants
    assert "CREATE FUNCTION" not in grants
    assert "CREATE TABLE" not in grants
    assert "INSERT INTO" not in grants
    assert "UPDATE ops." not in grants
    assert "DELETE FROM" not in grants
