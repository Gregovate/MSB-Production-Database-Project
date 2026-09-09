from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
ROOT = BASE_DIR.parent
SQL_001 = (ROOT / "Database" / "001_create_people_manager_contract.sql").read_text(encoding="utf-8")
SQL_002 = (ROOT / "Database" / "002_harden_people_search_phone_filter.sql").read_text(encoding="utf-8")
SQL = SQL_001 + "\n" + SQL_002
BACKEND = (BASE_DIR / "backend.py").read_text(encoding="utf-8")
HTML = (BASE_DIR / "index.html").read_text(encoding="utf-8")
JS = (BASE_DIR / "people.js").read_text(encoding="utf-8")
ANALYTICS = (BASE_DIR / "static" / "analytics.js").read_text(encoding="utf-8")


def test_database_contract_is_least_privilege() -> None:
    assert "SECURITY DEFINER" in SQL
    assert "GRANT EXECUTE ON FUNCTION ref.people_search" in SQL
    assert "GRANT EXECUTE ON FUNCTION ref.create_person_from_people_manager" in SQL
    assert "GRANT EXECUTE ON FUNCTION ref.update_person_from_people_manager" in SQL
    assert "REVOKE ALL ON TABLE ref.person FROM people_app" in SQL
    assert "GRANT INSERT ON" not in SQL
    assert "GRANT UPDATE ON" not in SQL
    assert "GRANT DELETE ON" not in SQL


def test_database_contract_preserves_protected_identity_fields() -> None:
    create_section = SQL.split("CREATE OR REPLACE FUNCTION ref.create_person_from_people_manager", 1)[1]
    update_section = SQL.split("CREATE OR REPLACE FUNCTION ref.update_person_from_people_manager", 1)[1]
    for forbidden in ("directus_user_id =", "pg_login_name =", "is_manager =", "is_team =", "available_for_work_orders ="):
        assert forbidden not in create_section
        assert forbidden not in update_section
    assert "Directus-linked MSB email is protected" in update_section


def test_database_contract_has_no_person_delete_command() -> None:
    lowered = SQL.lower()
    assert "function ref.delete_person" not in lowered
    assert "delete from ref.person" not in lowered


def test_manual_create_reserves_msb_identity() -> None:
    assert "@sheboyganlights.org" in SQL
    assert "left(v_first_slug, 1) || v_last_slug" in SQL
    assert "Non-standard MSB email requires explicit collision/exception review" in SQL
    assert "Reserved MSB email is already in use" in SQL


def test_duplicate_and_concurrency_guards_are_database_side() -> None:
    assert "ref.people_duplicate_candidates" in SQL
    assert "Potential duplicate person requires review before create" in SQL
    assert "Potential duplicate person requires review before save" in SQL
    assert "Person changed after this form was loaded" in SQL
    assert "FOR UPDATE" in SQL


def test_text_search_does_not_turn_empty_phone_token_into_match_all() -> None:
    assert "v_phone_query text := regexp_replace" in SQL_002
    assert "v_phone_query <> ''" in SQL_002
    assert "LIKE '%' || v_phone_query || '%'" in SQL_002


def test_backend_requires_cloudflare_and_command_guard() -> None:
    assert "Cf-Access-Authenticated-User-Email" in BACKEND
    assert "X-MSB-People-Command" in BACKEND
    assert "require_people_manager()" in BACKEND
    assert "require_command_request()" in BACKEND


def test_backend_exposes_no_delete_route() -> None:
    assert "@app.delete" not in BACKEND
    assert "delete_exposed=False" in BACKEND


def test_ui_loads_versioned_analytics_and_explains_reserved_email() -> None:
    assert "static/analytics.js?v=2026-09-09.1" in HTML
    assert "Reserving it does not create the Google Workspace account" in HTML
    assert "Potential duplicate review" in HTML
    assert "People Manager exposes no delete action" in HTML


def test_ui_sends_duplicate_ack_and_optimistic_lock() -> None:
    assert "duplicate_review_ack" in JS
    assert "email_exception_ack" in JS
    assert "expected_updated_at" in JS
    assert "duplicateFingerprint" in JS
    duplicate_payload = JS.split("function duplicatePayload()", 1)[1].split("async function checkDuplicates", 1)[0]
    assert "duplicate_review_ack" not in duplicate_payload
    assert "email_exception_ack" not in duplicate_payload


def test_analytics_contract_blocks_people_pii() -> None:
    assert "G-X08ZTSY0VV" in ANALYTICS
    assert "allow_google_signals: false" in ANALYTICS
    assert "allow_ad_personalization_signals: false" in ANALYTICS
    for forbidden in (
        "person_id",
        "first_name",
        "last_name",
        "preferred_name",
        "email",
        "personal_email",
        "cell_phone",
        "query",
        "search",
        "directus_user_id",
        "pg_login_name",
    ):
        assert f"'{forbidden}'" in ANALYTICS
