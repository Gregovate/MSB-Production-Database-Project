from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
ROOT = BASE_DIR.parent
SQL_001 = (ROOT / "Database" / "001_create_people_manager_contract.sql").read_text(encoding="utf-8")
SQL_002 = (ROOT / "Database" / "002_harden_people_search_phone_filter.sql").read_text(encoding="utf-8")
SQL_003 = (ROOT / "Database" / "003_create_people_metadata_contract.sql").read_text(encoding="utf-8")
SQL = SQL_001 + "\n" + SQL_002 + "\n" + SQL_003
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
    assert "REVOKE ALL ON TABLE ref.person_capability FROM people_app" in SQL_003
    assert "REVOKE ALL ON TABLE ref.person_qualification FROM people_app" in SQL_003
    assert "REVOKE ALL ON TABLE ref.person_setup_role FROM people_app" in SQL_003
    assert "REVOKE ALL ON TABLE ref.setup_task_captain FROM people_app" in SQL_003
    assert "GRANT INSERT ON" not in SQL
    assert "GRANT UPDATE ON" not in SQL
    assert "GRANT DELETE ON" not in SQL


def test_database_contract_preserves_protected_identity_fields() -> None:
    create_section = SQL_001.split("CREATE OR REPLACE FUNCTION ref.create_person_from_people_manager", 1)[1]
    update_section = SQL_001.split("CREATE OR REPLACE FUNCTION ref.update_person_from_people_manager", 1)[1]
    for forbidden in ("directus_user_id =", "pg_login_name =", "is_manager =", "is_team =", "available_for_work_orders ="):
        assert forbidden not in create_section
        assert forbidden not in update_section
    assert "Directus-linked MSB email is protected" in update_section


def test_database_contract_has_no_person_delete_command() -> None:
    lowered = SQL.lower()
    assert "function ref.delete_person" not in lowered
    assert "function ref.people_delete_person" not in lowered
    assert "delete from ref.person" not in lowered


def test_manual_create_reserves_msb_identity() -> None:
    assert "@sheboyganlights.org" in SQL_001
    assert "left(v_first_slug, 1) || v_last_slug" in SQL_001
    assert "Non-standard MSB email requires explicit collision/exception review" in SQL_001
    assert "Reserved MSB email is already in use" in SQL_001


def test_duplicate_and_concurrency_guards_are_database_side() -> None:
    assert "ref.people_duplicate_candidates" in SQL_001
    assert "Potential duplicate person requires review before create" in SQL_001
    assert "Potential duplicate person requires review before save" in SQL_001
    assert "Person changed after this form was loaded" in SQL_001
    assert "FOR UPDATE" in SQL_001


def test_text_search_does_not_turn_empty_phone_token_into_match_all() -> None:
    assert "v_phone_query text := regexp_replace" in SQL_002
    assert "v_phone_query <> ''" in SQL_002
    assert "LIKE '%' || v_phone_query || '%'" in SQL_002


def test_metadata_model_separates_capability_qualification_setup_role_and_leadership() -> None:
    for table in (
        "ref.person_capability_type",
        "ref.person_capability",
        "ref.person_qualification_type",
        "ref.person_qualification",
        "ref.person_setup_role",
    ):
        assert f"CREATE TABLE IF NOT EXISTS {table}" in SQL_003

    assert "'TRADE', 'TECHNICAL', 'DISPLAY_BUILD_KNOWLEDGE', 'EQUIPMENT', 'OTHER'" in SQL_003
    for role in (
        "SETUP_VOLUNTEER",
        "TAKEDOWN_VOLUNTEER",
        "CAPTAIN_CANDIDATE",
        "ADVISOR_CANDIDATE",
    ):
        assert role in SQL_003

    assert "completed_on date" in SQL_003
    assert "valid_from date" in SQL_003
    assert "expires_on date" in SQL_003
    assert "certificate_number text" in SQL_003
    assert "evidence_reference text" in SQL_003
    assert "FROM ref.setup_task_captain c" in SQL_003
    assert "INSERT INTO ref.setup_task_captain" not in SQL_003
    assert "DELETE FROM ref.setup_task_captain" not in SQL_003


def test_metadata_commands_are_narrow_security_definer_functions() -> None:
    for function_name in (
        "people_capability_catalog",
        "people_qualification_catalog",
        "people_person_capabilities",
        "people_person_qualifications",
        "people_person_setup_roles",
        "people_person_task_leadership",
        "upsert_people_capability_type",
        "set_people_person_capability",
        "upsert_people_qualification_type",
        "upsert_people_person_qualification",
        "set_people_person_setup_role",
    ):
        assert f"FUNCTION ref.{function_name}" in SQL_003
        assert f"GRANT EXECUTE ON FUNCTION ref.{function_name}" in SQL_003

    assert "PERFORM pg_catalog.set_config('app.directus_user_uuid'" in SQL_003
    assert "ref.people_management_actor(p_operator_email)" in SQL_003


def test_backend_requires_cloudflare_and_command_guard() -> None:
    assert "Cf-Access-Authenticated-User-Email" in BACKEND
    assert "X-MSB-People-Command" in BACKEND
    assert "require_people_manager()" in BACKEND
    assert "require_command_request()" in BACKEND


def test_backend_exposes_no_person_delete_or_merge_route() -> None:
    assert "@app.delete" not in BACKEND
    assert "delete_exposed=False" in BACKEND
    assert "merge_exposed=False" in BACKEND


def test_backend_preserves_optimistic_lock_timestamp_precision() -> None:
    assert "from datetime import date, datetime" in BACKEND
    assert "def json_row(row: Any)" in BACKEND
    assert "isinstance(value, (datetime, date))" in BACKEND
    assert "item[key] = value.isoformat()" in BACKEND
    assert "return jsonify(person=json_row(row))" in BACKEND
    assert BACKEND.count("json_row(cur.fetchone())") >= 2


def test_backend_exposes_people_metadata_routes() -> None:
    for route_fragment in (
        '/api/catalogs/capabilities',
        '/api/catalogs/qualifications',
        '/capabilities/<int:capability_type_id>',
        '/qualifications/<int:qualification_id>',
        '/setup-roles/<string:role_code>',
        '/leadership',
    ):
        assert route_fragment in BACKEND
    assert "ref.people_person_task_leadership" in BACKEND
    assert "ref.set_people_person_setup_role" in BACKEND


def test_ui_loads_versioned_analytics_and_explains_reserved_email() -> None:
    assert "static/analytics.js?v=2026-09-09.1" in HTML
    assert "people.js?v=2026-09-09.2" in HTML
    assert "Reserving it does not create the Google Workspace account" in HTML
    assert "Potential duplicate review" in HTML
    assert "People Manager exposes no person delete action" in HTML


def test_ui_exposes_people_metadata_fields() -> None:
    for heading in (
        "Capabilities",
        "Qualifications",
        "Setup / Takedown participation & eligibility",
        "Reusable-task leadership",
    ):
        assert heading in HTML

    for field_id in (
        "capabilitySelect",
        "newCapabilityName",
        "qualificationSelect",
        "qualificationCompletedOn",
        "qualificationValidFrom",
        "qualificationExpiresOn",
        "qualificationCertificateNumber",
        "qualificationEvidenceReference",
        "setupRoleList",
        "leadershipList",
    ):
        assert f'id="{field_id}"' in HTML

    assert "These roles describe participation or leadership eligibility. They do not create Captain assignments." in HTML
    assert "Read-only current Captain, Alternate, and Advisor assignments" in HTML


def test_ui_wires_metadata_commands() -> None:
    assert "loadCatalogs()" in JS
    assert "setPersonCapability" in JS
    assert "createCapabilityType" in JS
    assert "persistQualification" in JS
    assert "createQualificationType" in JS
    assert "saveSetupRoles" in JS
    assert "renderLeadership" in JS
    assert "api/people/${state.selectedPersonId}/leadership" in JS


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
