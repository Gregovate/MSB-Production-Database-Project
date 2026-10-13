from pathlib import Path

SQL_005 = (
    Path(__file__).resolve().parent.parent
    / "Database"
    / "005_reconcile_directus_person_identity.sql"
).read_text(encoding="utf-8")


def test_shared_tablet_accounts_are_not_human_identity_reconciliation_targets() -> None:
    assert "tablet-%@sheboyganlights.org" in SQL_005
    assert "Shared tablet accounts are Browser-only device identities" in SQL_005
    assert "SHARED_TABLET_ACCOUNT" in SQL_005
