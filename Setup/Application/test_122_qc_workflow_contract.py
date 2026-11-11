"""#122 QC 081 implementation contract; no server/Production access.

Behavioral DB acceptance is Setup/Acceptance/setup_122_qc_disposable_acceptance.sql
and must execute against the disposable current-Production PostgreSQL clone.
"""
from pathlib import Path
import ast
import shutil
import subprocess
import pytest

ROOT=Path(__file__).resolve().parent
SQL=(ROOT.parent/'Database/081_add_unscheduled_setup_qc_findings.sql').read_text()
JS=(ROOT/'setup_qc.js').read_text()
API=(ROOT/'setup_qc_api.py').read_text()
REPO=(ROOT/'setup_qc_repository.py').read_text()
BACK=(ROOT/'production_backend.py').read_text()
PREVIEW=(ROOT.parent/'Acceptance/run_485_qc_disposable_browser_review.ps1').read_text()


def test_qc_python_modules_parse_and_backend_is_registered():
    ast.parse(API)
    ast.parse(REPO)
    assert 'from setup_qc_api import setup_qc_api' in BACK
    assert 'app.register_blueprint(setup_qc_api)' in BACK


def test_qc_javascript_parses_where_node_is_available():
    if shutil.which('node') is None:
        pytest.skip('Node optional; Setup Production server does not require Node')
    result=subprocess.run(['node','--check',str(ROOT/'setup_qc.js')],
                          capture_output=True,text=True,check=False)
    assert result.returncode==0, result.stderr


def test_qc_command_enforces_identity_and_no_scheduling():
    assert 'ref.setup_execution_actor(p_email,v_reusable)' in SQL
    assert 'SECURITY DEFINER' in SQL
    assert "v_action='REPORT'" in SQL
    assert "v_action='CLAIM_AUDIT'" in SQL
    assert 'setup_session_task_id' in SQL
    assert 'INSERT INTO ops.setup_work_day_task' not in SQL
    assert 'UPDATE ops.setup_session_task SET execution_status' not in SQL
    assert "VALUES(p_finding,'INTAKE_LINK'" in SQL
    assert 'WHERE w.source_intake_id=p_intake_id' in SQL
    assert 'ON CONFLICT DO NOTHING' in SQL


def test_no_direct_qc_or_intake_table_grants():
    assert 'REVOKE ALL ON ops.setup_qc_auditor,ops.setup_qc_finding' in SQL
    assert 'CREATE FUNCTION ops.setup_qc_snapshot(' in SQL
    assert 'CREATE FUNCTION ops.setup_qc_intake_candidates(' in SQL
    assert 'GRANT EXECUTE ON FUNCTION ops.setup_qc_snapshot(' in SQL
    assert 'GRANT EXECUTE ON FUNCTION ops.setup_qc_intake_candidates(' in SQL
    assert 'GRANT SELECT ON stage.work_order_intake' not in SQL
    assert 'SELECT ops.setup_qc_snapshot(%s,%s)' in REPO
    assert 'SELECT ops.setup_qc_intake_candidates(%s,%s)' in REPO
    assert 'conn.set_session(readonly=False, autocommit=False)' in REPO


def test_original_intake_is_reviewed_and_never_auto_promoted():
    assert 'require_manager()' in API
    assert '/api/setup/qc/intake-candidates' in API
    assert 'setup_qc_intake_link' in SQL
    assert 'intake_id=p_intake_id' in SQL
    assert 'DELETE FROM stage.work_order_intake' not in SQL
    assert 'UPDATE stage.work_order_intake' not in SQL
    assert 'INSERT INTO ops.work_order' not in SQL
    assert 'LINK_INTAKE' in JS
    assert 'Original Intake remains unchanged' in JS


def test_two_minute_final_signoff_is_not_faked():
    assert 'AWAITING_RETEST' in SQL
    assert 'RETEST_FAIL' in SQL and 'RETEST_PASS' in SQL
    assert 'Final QC approval remains gated' in (ROOT/'setup_next_pass.js').read_text()
    assert 'COMPLETE_QC' not in SQL
    assert 'FINAL_QC_PASS' not in SQL


def test_disposable_preview_always_includes_081_and_rollback_validation():
    assert '-MigrationPaths @(' in PREVIEW
    assert 'Setup/Database/081_add_unscheduled_setup_qc_findings.sql' in PREVIEW
    assert '-ValidationPaths @(' in PREVIEW
    assert 'Setup/Acceptance/setup_122_qc_disposable_acceptance.sql' in PREVIEW
    validation=(ROOT.parent/'Acceptance/setup_122_qc_disposable_acceptance.sql').read_text()
    assert 'ROLLBACK;' in validation
    assert 'FROM ops.setup_work_day_task' in validation
    assert 'v_before<>v_after' in validation


def test_qc_modes_own_their_panel_and_do_not_fall_through_to_scheduled_work():
    """The operator saw Report Fixes with the Scheduled Work panel rendered below it."""
    ui=(ROOT/'setup_next_pass.js').read_text()
    assert "if (nextQcDiscovery.mode !== 'work') return;" in ui
    assert "if (nextQcDiscovery.mode === 'qc') return;" not in ui
    assert "window.setupQcRenderFixes?.();" in ui
    assert 'data-qc-detail="${id}"' in ui


def test_qc_entry_not_blocked_by_manager_intake_retrieval():
    """The problem-entry form must render even if manager-only Intake is slow."""
    view=JS.split("window.setupQcRenderCurrent=async function()",1)[1].split(
        "window.setupQcRenderFixes=async function()",1)[0]
    before_render=view.split("host.innerHTML=",1)[0]
    assert "await reviewIntake()" not in before_render
    assert "Loading QC findings and report controls" in view
    assert 'data-qc-action="REPORT"' in view
    assert 'data-qc-action="CLAIM_AUDIT"' in view
    assert 'data-qc-intake-items' in view
    assert "void reviewIntake().then" in view
    assert "if (!host.isConnected" in view


def test_qc_writes_share_exact_finding_and_annual_task():
    assert 'data-qc-action="CLAIM_REPAIR"' in JS
    assert 'data-qc-action="REPAIRED"' in JS
    assert 'data-qc-action="RETEST_PASS"' in JS
    assert 'data-qc-action="RETEST_FAIL"' in JS
    assert "setup_session_task_id:targetId" in JS
