from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
SERVER = (BASE_DIR / "people_manager_nullable_email_production_deploy_server.sh").read_text(
    encoding="utf-8"
)
WRAPPER = (BASE_DIR / "run_people_manager_nullable_email_production_deploy.ps1").read_text(
    encoding="utf-8"
)


def test_server_refreshes_origin_main_explicitly_for_narrow_production_refspec() -> None:
    assert '+refs/heads/main:refs/remotes/origin/main' in SERVER
    assert 'rev-parse origin/main' in SERVER
    assert 'requested deployment SHA is not current origin/main after explicit refresh' in SERVER


def test_deploy_stays_bounded_to_merged_main_and_migration_004() -> None:
    assert 'TARGET_REF="main"' in SERVER
    assert 'ACCEPTED_RUNTIME_SHA="953f2b71487de80519f4fc2f8005467ca41983e9"' in SERVER
    assert '004_stop_automatic_msb_email_generation.sql' in SERVER
    assert 'psql_prod < "$MIGRATION_004"' in SERVER
    assert '001_create_people_manager_contract.sql' not in SERVER
    assert '002_harden_people_search_phone_filter.sql' not in SERVER
    assert '003_create_people_metadata_contract.sql' not in SERVER


def test_wrapper_requires_main_and_exact_target_sha() -> None:
    assert "$ExpectedBranch = 'main'" in WRAPPER
    assert "[string]$TargetSha" in WRAPPER
    assert 'origin/main' in WRAPPER
