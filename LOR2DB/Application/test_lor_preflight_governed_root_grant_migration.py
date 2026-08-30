from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIGRATION = (
    ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "migrations"
    / "0041_grant_lor_preflight_governed_root.sql"
)
VALIDATION = (
    ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "validation"
    / "36_lor_preflight_governed_root_grant_validation.sql"
)


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_migration_grants_only_lor_preflight_role():
    sql = text(MIGRATION)
    assert "GRANT EXECUTE ON FUNCTION" in sql
    assert "ops.f_lor_governed_stage_roots(bigint, text)" in sql
    assert "TO lor_preflight_app" in sql
    assert "TO PUBLIC" not in sql


def test_migration_requires_existing_login_role():
    sql = text(MIGRATION)
    assert "rolname = 'lor_preflight_app'" in sql
    assert "rolcanlogin" in sql


def test_validation_checks_application_execute_privilege():
    sql = text(VALIDATION)
    assert "has_function_privilege" in sql
    assert "'lor_preflight_app'" in sql
    assert "'ops.f_lor_governed_stage_roots(bigint,text)'" in sql


def test_validation_proves_public_execute_remains_revoked():
    sql = text(VALIDATION)
    assert "aclexplode" in sql
    assert "a.grantee = 0" in sql
    assert "a.privilege_type = 'EXECUTE'" in sql


def test_validation_exercises_exact_browser_stage_review_boundary():
    sql = text(VALIDATION)
    assert "SET LOCAL ROLE lor_preflight_app" in sql
    assert "FROM ops.v_lor_reconciliation_operator_stage_review" in sql
