from pathlib import Path

SQL_005 = (
    Path(__file__).resolve().parent.parent
    / "Database"
    / "005_reconcile_directus_person_identity.sql"
).read_text(encoding="utf-8")


def test_shared_tablet_accounts_are_not_human_identity_reconciliation_targets() -> None:
    assert "tablet-%@sheboyganlights.org" in SQL_005
    assert "Shared device/service accounts are non-human identities" in SQL_005
    assert "printservice@sheboyganlights.org" in SQL_005
    assert "production-1@sheboyganlights.org" in SQL_005
    assert "SHARED_TABLET_ACCOUNT" in SQL_005
    assert "NONHUMAN_SERVICE_ACCOUNT" in SQL_005
