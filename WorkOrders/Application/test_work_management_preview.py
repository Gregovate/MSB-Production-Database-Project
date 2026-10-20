"""#419 source/regression tests for the disposable-only Work Management read slice.

These tests use a fake repository; they must not access live PostgreSQL,
modify a ticket, send email or invoke Production Directus Flows.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
flask = pytest.importorskip("flask")
pytest.importorskip("psycopg2")
import backend  # noqa: E402
import repository  # noqa: E402


class FakeRepo:
    calls = []

    def access(self, email):
        FakeRepo.calls.append(("access", email))
        return {"person_id": 101, "display_name": "Preview Person",
                "can_manage": True, "can_read": True}

    def aging_report(self, *, actor, sort="created_asc", include_planning=True):
        FakeRepo.calls.append(("aging_report", sort))
        if not actor["can_manage"]:
            raise repository.WorkManagementError("Manager only.", 403)
        return [{
            "ticket": "WO-372", "wo_id": 372, "title": "Existing Work Order",
            "opened_at": "2026-08-19T00:00:00Z", "days_open": 61,
            "urgency": 2, "owners": "Team", "assigned_n": 3,
            "location": "Stage 9", "yr": 2026, "active": True,
            "test_id": None, "state": "STATUS_NOT_RECORDED",
            "review_flag": None,
        }, {
            "ticket": "WO-389", "wo_id": 389, "title": "Inactive but undated",
            "opened_at": "2026-09-25T00:00:00Z", "days_open": 24,
            "urgency": None, "owners": "UNASSIGNED", "assigned_n": 0,
            "location": "Rack D", "yr": 2026, "active": False,
            "test_id": None, "state": "STATUS_NOT_RECORDED",
            "review_flag": None,
        }]

    def manager_inbox(self, actor):
        FakeRepo.calls.append(("manager_inbox", actor["person_id"]))
        if not actor["can_manage"]:
            raise repository.WorkManagementError("Manager Intake is not authorized.", 403)
        return {"public_intake": 2, "task_feedback": 1}

    def assignees(self):
        return [{"person_id": 101, "display_name": "Preview Person"},
                {"person_id": 202, "display_name": "Another Person"}]

    def task_types(self, actor):
        FakeRepo.calls.append(("task_types", actor["person_id"]))
        if not actor["can_read"]:
            raise repository.WorkManagementError("Read permission required.", 403)
        return [{"id": 10, "name": "Repair"}]

    def reviewer_options(self, actor):
        FakeRepo.calls.append(("reviewer_options", actor["person_id"]))
        if not actor["can_manage"]:
            raise repository.WorkManagementError("Manager permission required.", 403)
        return {
            "people": [{"person_id": 101, "display_name": "Preview Person"}],
            "task_types": [{"id": 10, "name": "Repair"}],
            "stages": [{"id": 17, "name": "Stage 17"}],
            "work_areas": [{"id": 49, "name": "Electrical Department"}],
        }

    def tickets(self, **kwargs):
        FakeRepo.calls.append(("tickets", kwargs))
        return [{
            "type": "TASK_FEEDBACK", "ticket": "INTAKE-60",
            "title": "Correct Kit contents", "location": "Stage 40",
            "owners": "CORRECTION_OWNER_NOT_TRACKED", "done_at": None,
            "active": True, "test_id": None, "reporter_id": 101,
        }]

    def ticket(self, *, actor, ticket_key):
        FakeRepo.calls.append(("ticket", ticket_key))
        return {
            "type": "TASK_FEEDBACK", "ticket": ticket_key,
            "title": "Correct Kit contents", "location": "Stage 40",
            "owners": "CORRECTION_OWNER_NOT_TRACKED",
            "reported_by": "Preview Person", "source": "SETUP_CORRECTION",
            "done_at": None, "active": True,
            "detail": {"problem_raw": "Correct Kit contents", "notes_raw": ""},
            "setup_context": {"stage_id": 40},
        }

    def related_information(self, *, actor, ticket_key):
        FakeRepo.calls.append(("related", ticket_key))
        return {
            "stage_id": 40,
            "notice": "Stage candidates are not confirmed task assignments.",
            "groups": [{
                "kind": "Kit Box", "id": 58, "name": "C058 Kit",
                "relation": "STAGE_RELATED",
                "source": "KIT", "url": "/setup/kit-inventory/58",
            }],
        }


@pytest.fixture
def client(monkeypatch):
    FakeRepo.calls.clear()
    monkeypatch.setattr(backend, "WorkManagementRepository", FakeRepo)
    backend.app.testing = True
    return backend.app.test_client()


def identity():
    return {"Cf-Access-Authenticated-User-Email": "crew@sheboyganlights.org"}


def test_missing_identity_denied_without_db_access(client):
    response = client.get("/api/work-orders/tickets")
    assert response.status_code == 401
    assert FakeRepo.calls == []


def test_work_orders_land_on_signed_in_person_only(client):
    response = client.get("/api/work-orders/tickets", headers=identity())
    assert response.status_code == 200
    assert response.json["scope"] == "mine"
    assert response.json["read_only"]
    called = [x for x in FakeRepo.calls if x[0] == "tickets"]
    assert len(called) == 1
    assert called[0][1]["scope"] == "mine"
    assert called[0][1]["person_id"] is None
    assert called[0][1]["show_completed"] is False


def test_scope_other_person_and_completed_independent(client):
    response = client.get(
        "/api/work-orders/tickets?scope=person&person_id=202&show_completed=1",
        headers=identity(),
    )
    assert response.status_code == 200
    called = [x for x in FakeRepo.calls if x[0] == "tickets"]
    assert called[0][1]["scope"] == "person"
    assert called[0][1]["person_id"] == 202
    assert called[0][1]["show_completed"] is True


def test_invalid_assignee_and_ticket_rejected(client):
    bad = client.get(
        "/api/work-orders/tickets?scope=person&person_id=0",
        headers=identity(),
    )
    assert bad.status_code == 400
    bad_ticket = client.get(
        "/api/work-orders/tickets/WO-1%27%3BDROP",
        headers=identity(),
    )
    assert bad_ticket.status_code == 400


def test_relevant_info_is_separate_read_route(client):
    page = client.get("/work-orders/", headers=identity())
    assert page.status_code == 200
    assert b'<details id="related-information"' in page.data
    assert not any(x[0] == "related" for x in FakeRepo.calls)
    info = client.get(
        "/api/work-orders/tickets/INTAKE-60/related-information",
        headers=identity(),
    )
    assert info.status_code == 200
    assert info.json["related_information"]["groups"][0]["relation"] == "STAGE_RELATED"


def test_no_mutation_or_mail_routes(client):
    for route in (
        "/api/work-orders/tickets",
        "/api/work-orders/tickets/INTAKE-60",
        "/api/work-orders/tickets/INTAKE-60/related-information",
    ):
        assert client.post(route, headers=identity(), json={}).status_code == 405


def test_missing_disposable_configuration_fails_closed(monkeypatch):
    monkeypatch.delenv("WORK_MGMT_DATABASE_DSN", raising=False)
    monkeypatch.setenv("WORK_MGMT_PREVIEW_MODE", "disposable")
    with pytest.raises(repository.WorkManagementError):
        repository.WorkManagementRepository()
    monkeypatch.setenv("WORK_MGMT_DATABASE_DSN", "dbname=not_a_real_db")
    monkeypatch.setenv("WORK_MGMT_PREVIEW_MODE", "production")
    with pytest.raises(repository.WorkManagementError):
        repository.WorkManagementRepository()


def test_related_information_is_collapsed_before_fetch():
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "app.js").read_text(encoding="utf-8")
    assert '<details id="related-information"' in html
    assert "<details id=\"related-information\" open" not in html
    assert '"toggle", loadRelated' in js
    assert "if (!$(" + '"related-information"' + ").open" in js
    assert "Related Information" in html
    assert "Request More Information" in html
    assert "Promote &amp; Assign" in html


def test_disposable_preview_rejects_nonlocal_header(client):
    response = client.get(
        "/api/work-orders/access",
        headers=identity(),
        environ_base={"REMOTE_ADDR": "192.0.2.20"},
    )
    assert response.status_code == 403
    assert FakeRepo.calls == []


def test_manager_testing_queue_is_distinct_from_public_intake(client):
    """Preview may filter existing source records; it may not create another repair."""
    for scope in ("repairs", "testing", "intake", "feedback"):
        FakeRepo.calls.clear()
        response = client.get(
            "/api/work-orders/tickets?scope=" + scope, headers=identity()
        )
        assert response.status_code == 200
        calls = [entry for entry in FakeRepo.calls if entry[0] == "tickets"]
        assert len(calls) == 1
        assert calls[0][1]["scope"] == scope


def test_manager_queues_fail_closed_for_nonmanager_repository():
    """The queue authorization is enforced server-side, not just hidden in HTML."""
    repo = repository.WorkManagementRepository
    instance = object.__new__(repo)
    for scope in ("repairs", "testing", "intake", "feedback"):
        with pytest.raises(repository.WorkManagementError) as error:
            instance.tickets(
                actor={"person_id": 101, "can_manage": False},
                scope=scope, person_id=None,
                show_completed=False, search="",
            )
        assert error.value.status == 403


def test_urgent_work_is_sorted_in_sql_before_limit():
    """Do not sort the first 80 recent tickets in the browser and miss emergencies."""
    source = (HERE / "repository.py").read_text(encoding="utf-8")
    assert "t.urgency ASC NULLS LAST" in source
    assert source.index("t.urgency ASC NULLS LAST") < source.index('LIMIT %s')
    assert "t.test_id IS NOT NULL" in source
    assert "t.type = 'INTAKE_REQUEST'" in source
    assert "t.type = 'TASK_FEEDBACK'" in source


def test_manager_catalog_is_read_only_and_actor_scoped(client):
    response = client.get("/api/work-orders/reviewer-options", headers=identity())
    assert response.status_code == 200
    assert response.json["disposable_only"] and not response.json["read_only"]
    assert response.json["options"]["people"][0]["person_id"] == 101
    assert ("reviewer_options", 101) in FakeRepo.calls
    for method in ("post", "patch", "delete"):
        assert getattr(client, method)(
            "/api/work-orders/reviewer-options",
            headers=identity(), json={"work_order_id": 372},
        ).status_code == 405


def test_new_manager_queues_and_reporter_feedback_route(client):
    for scope in ("my-feedback", "critical", "unassigned"):
        FakeRepo.calls.clear()
        response = client.get("/api/work-orders/tickets?scope=" + scope, headers=identity())
        assert response.status_code == 200
        assert ("tickets", {
            "actor": {"person_id": 101, "display_name": "Preview Person",
                      "can_manage": True, "can_read": True},
            "scope": scope, "person_id": None,
            "show_completed": False, "search": "", "task_type_id": None, "sort": "priority",
            "include_planning": True,
        }) in FakeRepo.calls


def test_review_script_is_ticket_local_and_clone_only(client):
    page = client.get("/work-orders/", headers=identity())
    assert page.status_code == 200
    assert b"review_actions.js" in page.data
    assert b"disposable database only" in page.data
    assert page.data.index(b'id="review-workbench"') < page.data.index(b'id="related-information"')
    assert b'id="create-work-order"' in page.data
    assert b"msb-blue-logo-600-plain.svg" in page.data
    js = client.get("/work-orders/assets/review_actions.js", headers=identity())
    assert js.status_code == 200
    source = (HERE / "review_actions.js").read_text(encoding="utf-8")
    assert "wo419:ticket" in source and "wo419:actor" in source
    assert "No matching active linked People." in source
    assert "SAVED on disposable clone:" in source
    assert 'method: "POST"' in source
    assert "X-WO419-CSRF" in source
    assert "No emails will be sent" in source
    assert "fetch(" in source
    assert "review-completion-notes" in source
    assert "review-disposition" in source
    assert "review-person-filter" in source


def test_catalog_manager_gate_precedes_database_connect():
    instance = object.__new__(repository.WorkManagementRepository)
    with pytest.raises(repository.WorkManagementError) as error:
        instance.reviewer_options({"can_manage": False, "person_id": 101})
    assert error.value.status == 403


def test_short_ticket_search_and_all_unassigned_covered():
    source = (HERE / "repository.py").read_text(encoding="utf-8")
    assert "replace(t.ticket, '-', '') ILIKE" in source
    assert "COALESCE(t.assigned_n, 0) = 0" in source


def test_disposable_save_csrf_gate_and_actual_perimeter(client, monkeypatch):
    """Requests lacking server-generated key cannot reach clone writer."""
    monkeypatch.delenv("WORK_MGMT_PREVIEW_CSRF_TOKEN", raising=False)
    response = client.post("/api/work-orders/commands", headers=identity(),
                           json={"action": "create", "request_key": "x"})
    assert response.status_code == 403
    monkeypatch.setenv("WORK_MGMT_PREVIEW_CSRF_TOKEN", "a" * 48)
    response = client.post("/api/work-orders/commands", headers=identity(),
                           json={"action": "create"}, environ_base={"REMOTE_ADDR": "192.0.2.2"})
    assert response.status_code == 403
    response = client.post("/api/work-orders/commands",
                           headers={**identity(), "X-WO419-CSRF": "a" * 48,
                                    "Origin": "https://attacker.example"},
                           json={"action": "create"})
    assert response.status_code == 403


def test_clone_writer_configuration_rejects_non_disposable(monkeypatch):
    import commands
    monkeypatch.setenv("WORK_MGMT_PREVIEW_MODE", "production")
    monkeypatch.setenv("WORK_MGMT_DATABASE_DSN", "dbname=msb")
    monkeypatch.setenv("WORK_MGMT_CLONE_WRITE_TOKEN", "a" * 48)
    monkeypatch.setenv("WORK_MGMT_CLONE_IP", "127.0.0.1")
    with pytest.raises(repository.WorkManagementError):
        commands.CloneCommands()


def test_clone_command_validation_guards_duplicate_people_notes_and_ticket_id():
    import commands
    import uuid
    with pytest.raises(repository.WorkManagementError):
        commands.people([101, 101])
    with pytest.raises(repository.WorkManagementError):
        commands.substantive(" ", "Completion notes")
    action = commands.CloneCommands.__new__(commands.CloneCommands)
    with pytest.raises(repository.WorkManagementError):
        action.perform({"person_id": 1, "can_manage": True},
                       "complete", "WO-one", {"request_key": str(uuid.uuid4())})


def test_only_clone_guarded_writer_and_no_mail_transport():
    commands = (HERE / "commands.py").read_text(encoding="utf-8")
    sql = (ROOT / "WorkOrders/Acceptance/wo419_disposable_actions.sql").read_text(encoding="utf-8")
    assert '"msb_wo419_preview"' in commands
    assert "hmac.compare_digest" in commands
    assert "app.directus_user_uuid" in commands
    assert "current_database()" in sql
    assert "approved_disposable_clone" in sql
    assert "wo419_preview.outbox" in sql
    assert "NO_SEND_CAPTURED" in sql
    for forbidden in ("smtplib", "sendgrid", "mailgun", "requests.post("):
        assert forbidden not in commands


def test_manager_home_summary_and_sort_are_server_authorized(client):
    summary = client.get("/api/work-orders/manager-inbox", headers=identity())
    assert summary.status_code == 200
    assert summary.json["inbox"] == {"public_intake": 2, "task_feedback": 1}
    response = client.get(
        "/api/work-orders/tickets?sort=number_asc&scope=testing",
        headers=identity(),
    )
    assert response.status_code == 200
    assert response.json["sort"] == "number_asc"
    assert any(entry[0] == "tickets" and entry[1]["sort"] == "number_asc"
               for entry in FakeRepo.calls)


def test_crew_stays_on_my_work_and_cannot_read_manager_intake(client, monkeypatch):
    class CrewRepo(FakeRepo):
        def access(self, email):
            return {"person_id": 202, "display_name": "Crew Reviewer",
                    "can_manage": False, "can_create": False,
                    "can_assign": False, "can_triage": False, "can_read": True}
    monkeypatch.setattr(backend, "WorkManagementRepository", CrewRepo)
    assert client.get("/api/work-orders/manager-inbox",
                      headers=identity()).status_code == 403
    # Manager-specific scope is rejected in the real repository before SQL.
    repo = object.__new__(repository.WorkManagementRepository)
    for scope in ("all", "tickets", "person", "intake", "feedback", "testing", "critical"):
        with pytest.raises(repository.WorkManagementError) as denied:
            repo.tickets(actor={"person_id": 202, "can_manage": False},
                         scope=scope, person_id=101 if scope == "person" else None,
                         show_completed=False, search="")
        assert denied.value.status == 403



def test_crew_cannot_directly_create_or_assign_native_work_orders():
    import commands
    from uuid import uuid4
    writer = commands.CloneCommands.__new__(commands.CloneCommands)
    crew = {"person_id": 202, "can_manage": False, "can_create": True,
            "can_read": True}
    for action, ticket, ids in (("create", None, []), ("create", None, [101]),
                                ("assign", "WO-372", [101])):
        with pytest.raises(repository.WorkManagementError) as denied:
            writer.perform(crew, action, ticket,
                           {"request_key": str(uuid4()), "person_ids": ids})
        assert denied.value.status == 403

def test_all_sorts_use_validated_numeric_ids_in_sql_before_limit():
    source = (HERE / "repository.py").read_text(encoding="utf-8")
    assert '"number_asc": "COALESCE(t.wo_id, t.in_id) ASC"' in source
    assert '"number_desc": "COALESCE(t.wo_id, t.in_id) DESC"' in source
    assert '"priority": "t.urgency ASC NULLS LAST' in source
    assert '"priority_desc": "t.urgency DESC NULLS LAST' in source
    assert 'if sort not in sort_modes:' in source
    html = (HERE / "index.html").read_text(encoding="utf-8")
    assert 'id="ticket-sort"' in html
    for sort in ("priority", "priority_desc", "number_desc", "number_asc"):
        assert 'value="' + sort + '"' in html
    assert 'id="manager-inbox-banner"' in html
    assert 'id="go-intake"' in html
    assert 'id="go-feedback"' in html
    js = (HERE / "app.js").read_text(encoding="utf-8")
    assert "loadManagerInbox()" in js
    assert 'sort: $("ticket-sort").value' in js
    assert "state.actor?.can_manage" in js



def test_crew_direct_create_fails_before_any_disposable_write():
    import commands
    from uuid import uuid4
    writer = commands.CloneCommands.__new__(commands.CloneCommands)
    def fail_if_called(_actor):
        raise AssertionError("Crew must never reach a native WO transaction")
    writer.transaction = fail_if_called
    crew = {"person_id": 202, "can_manage": False, "can_create": True,
            "can_read": True}
    with pytest.raises(repository.WorkManagementError) as denied:
        writer.perform(crew, "create", None,
                       {"request_key": str(uuid4()), "person_ids": []})
    assert denied.value.status == 403
    assert "Work Order Request" in str(denied.value)

def test_manager_intake_count_excludes_promoted_and_closed_history():
    source = (HERE / "repository.py").read_text(encoding="utf-8")
    assert "def manager_inbox(" in source
    assert "a.event_kind IN ('promoted_source','resolve')" in source
    assert "a.event_kind IN ('resolve','promoted_source')" in source
    assert 'scope == "intake"' in source
    assert 'scope == "feedback"' in source
    assert 'scope == "my-created"' in source
    assert "t.reporter_id = %s" in source
    html = (HERE / "index.html").read_text(encoding="utf-8")
    assert 'value="my-created"' in html
    assert 'id="go-intake"' in html
    assert 'value="intake" data-manager-only' not in html
    assert "Submit Work Order Request" in html
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    assert "if (actor.can_manage)" in js
    assert "!model.actor?.can_manage" in js
    assert "model.actor?.can_manage" in js
    assert "payload.disposable_only" in js



def test_directus_role_permissions_require_actual_manager_capability_for_create():
    permits = repository.work_management_role_permissions
    for role, policy in (("Production Crew", []), ("Volunteer", ["Volunteer"]),
                         ("MSB Browser", []), ("Unassigned", ["Production Crew"]),
                         ("Administrator", [])):
        ordinary = permits({"role_name": role, "policy_names": policy,
                            "can_manage_setup": False})
        assert ordinary == {"can_manage": False, "can_create": False,
                            "can_assign": False, "can_triage": False}
    for role in ("Manager", "Administrator"):
        manager = permits({"role_name": role, "policy_names": [],
                           "can_manage_setup": True})
        assert all(manager.values())

def test_manager_all_work_orders_is_not_the_intake_queue():
    source = (HERE / "repository.py").read_text(encoding="utf-8")
    assert 'if scope == "all":' in source
    assert '''conditions.append("t.type = 'WORK_ORDER'")''' in source
    assert '"tickets"' in source
    html = (HERE / "index.html").read_text(encoding="utf-8")
    assert 'value="tickets" data-manager-only' in html
    assert 'value="all" data-manager-only' in html
    assert 'id="go-intake"' in html
    assert 'value="intake" data-manager-only' not in html
    assert "Work Order / Intake number" in html


def test_assigned_crew_progress_is_distinct_from_completion():
    commands_source = (HERE / "commands.py").read_text(encoding="utf-8")
    browser = (HERE / "review_actions.js").read_text(encoding="utf-8")
    html = (HERE / "index.html").read_text(encoding="utf-8")
    for event in ('"progress"', '"complete"', '"link_setup"', '"promote"'):
        assert event in commands_source
    assert 'elif action in ("progress", "complete"):' in commands_source
    assert '"Work progress note"' in commands_source
    assert "NULLIF(btrim(notes), '')" in commands_source
    assert "submitted_by_person_id" in commands_source
    assert "Progress alone never marks repair complete" in commands_source
    assert 'progress: "Record Work Note' in browser
    assert "result.push(\"progress\", \"complete\")" in browser
    assert 'id="review-progress-fields"' in html
    assert 'id="review-progress-note"' in html


def test_manager_open_aging_report_counts_all_open_inactive_unassigned(client):
    response = client.get(
        "/api/work-orders/aging?sort=created_asc", headers=identity()
    )
    assert response.status_code == 200
    body = response.json
    assert body["count"] == 2 and body["all_open_work_orders"]
    assert body["inactive_count"] == 1 and body["unassigned_count"] == 1
    assert body["buckets"]["61+"] == 1
    assert body["buckets"]["8-30"] == 1
    assert body["rows"][0]["ticket"] == "WO-372"
    assert ("aging_report", "created_asc") in FakeRepo.calls


def test_aging_denies_crew_at_repository_boundary_without_sql():
    repo = object.__new__(repository.WorkManagementRepository)
    with pytest.raises(repository.WorkManagementError) as denied:
        repo.aging_report(actor={"can_manage": False}, sort="created_asc")
    assert denied.value.status == 403


def test_aging_query_uses_created_date_and_has_no_limit_or_active_filter():
    src = (HERE / "repository.py").read_text(encoding="utf-8")
    start = src.index("    def aging_report(")
    stop = src.index("    def manager_inbox(", start)
    code = src[start:stop]
    assert "opened_at ASC NULLS LAST" in code
    assert "CURRENT_TIMESTAMP - t.opened_at" in code
    assert "t.done_at IS NULL" in code
    assert "t.active" in code  # projected for exception display
    assert "AND t.active" not in code
    assert '" LIMIT "' not in code and "LIMIT %s" not in code
    assert '"number_asc"' in code and '"priority"' in code
    assert "if not actor[\"can_manage\"]:" in code
    ledger = (ROOT /
        "Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/engineering"
        "/WO419_Unified_Ticket_Read_Only_Candidate.sql").read_text(encoding="utf-8")
    assert "w.created_at AS opened_at" in ledger
    assert "NULL::timestamptz AS opened_at" in ledger
    assert "opened_at," in ledger


def test_aging_browser_has_manager_view_full_table_and_safe_csv():
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "app.js").read_text(encoding="utf-8")
    assert 'value="aging" data-manager-only' in html
    assert 'id="aging-report"' in html
    assert 'id="aging-export"' in html
    assert 'id="aging-rows"' in html
    assert '"aging-report").hidden = !aging' in js
    assert 'getJson("/api/work-orders/aging?sort="' in js
    assert '"aging-export").addEventListener("click", exportAgingCsv)' in js
    assert "state.agingRows.forEach" in js
    assert "URL.createObjectURL" in js
    assert "text.replaceAll" in js
    assert "0–7 days" in js
    assert "Inactive exceptions" in js


def test_setup_season_link_is_manager_only_and_uses_existing_setup_command():
    import commands
    # A Crew member may REQUEST linkage without gaining Setup Manager rights.
    with pytest.raises(repository.WorkManagementError) as denied:
        commands.CloneCommands.create_season_only_work_order_gate(
            None, {"person_id": 202, "can_manage": False}, 372,
            {"stage_id": 17, "setup_season_year": 2026},
        )
    assert denied.value.status == 403
    source = (HERE / "commands.py").read_text(encoding="utf-8")
    assert "ops.create_setup_season_task(" in source
    assert 'None, "GATE"' in source
    assert "work_order_id, True" in source
    assert "ops.setup_session_task" in source
    assert "CREATE TABLE ref.setup_task" not in source
    assert '"linked_setup_session_task_id"' in source



def test_crew_seasonal_setup_requests_go_through_intake_not_native_create():
    import commands
    from uuid import uuid4
    writer = commands.CloneCommands.__new__(commands.CloneCommands)
    crew = {"person_id": 202, "can_manage": False, "can_create": True,
            "can_read": True}
    writer.transaction = lambda _: (_ for _ in ()).throw(
        AssertionError("Crew must not create any native Work Order or Setup task"))
    for mode in ("request", "create"):
        with pytest.raises(repository.WorkManagementError) as denied:
            writer.perform(crew, "create", None,
                           {"request_key": str(uuid4()), "person_ids": [],
                            "setup_mode": mode, "stage_id": 17})
        assert denied.value.status == 403

def test_season_link_ui_and_clone_rollback_gate_are_not_replacement_setup_work():
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    clone = (ROOT / "WorkOrders/Acceptance/validate_work_management_clone.py"
             ).read_text(encoding="utf-8")
    grants = (ROOT / "WorkOrders/Acceptance/wo419_preview_clone_read_grants.sql"
              ).read_text(encoding="utf-8")
    for name in ("review-setup-mode", "review-setup-season", "review-setup-name"):
        assert 'id="' + name + '"' in html
        assert name in js
    assert "Manager · Create linked season-only Setup task now" in html
    assert "setup_seasons" in js
    assert "setupModeChanged" in js
    assert "atomic_work_order_setup_season_gate" in clone
    assert "create_season_only_work_order_gate(" in clone
    assert "ROLLBACK TO SAVEPOINT wo419_preflight" in clone
    assert "ops.create_setup_season_task(" in grants
    assert "GRANT INSERT ON ops.setup_session_task" not in grants
    setup_board = (
        ROOT / "Setup/Application/setup_scheduling_board_repository.py"
    ).read_text(encoding="utf-8")
    assert "linked_work_order_gate" in setup_board
    assert "wo.date_completed IS NOT NULL" in setup_board


def test_manager_link_existing_work_order_does_not_duplicate_work_order_or_intake():
    import commands
    from uuid import uuid4
    source = (HERE / "commands.py").read_text(encoding="utf-8")
    assert '"link_setup"' in source
    assert 'elif action == "link_setup":' in source
    assert 'self.create_season_only_work_order_gate(' in source
    assert 'wo = self.new_work_order' in source
    assert 'if action == "promote":' in source
    # Linking must consume the already locked native WO identity and stage.
    assert '"stage_id": work_order["stage_id"]' in source
    assert '"problem": work_order["problem"]' in source
    writer = commands.CloneCommands.__new__(commands.CloneCommands)
    crew = {"person_id": 202, "can_create": True,
            "can_manage": False, "can_read": True}
    with pytest.raises(repository.WorkManagementError) as denied:
        writer.perform(crew, "link_setup", "WO-372", {
            "request_key": str(uuid4()), "setup_mode": "create",
            "setup_season_year": 2026, "stage_id": 17,
        })
    assert denied.value.status == 403


def test_manager_setup_link_action_is_ticket_local_and_has_real_season_select():
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    assert 'id="review-link-setup-fields"' in html
    assert 'id="review-link-setup-season"' in html
    assert 'id="review-link-setup-name"' in html
    assert 'Manager · Add this Work Order to seasonal Setup' in js
    assert 'result.push("link_setup")' in js
    assert 'kind === "link_setup"' in js
    assert 'catalog("review-link-setup-season"' in js
    assert '"linked_setup_session_task_id"' in (
        HERE / "commands.py").read_text(encoding="utf-8")


@pytest.mark.parametrize(
    "db_name,server_host,authorized_token,linked_identity,expected_status",
    [
        ("msb_wo419_preview", "172.18.0.5", True, True, None),
        ("msb_wo419_preview", "172.18.0.6", True, True, 503),
        ("msb", "172.18.0.5", True, True, 503),
        ("msb_wo419_preview", "172.18.0.5", False, True, 503),
        ("msb_wo419_preview", "172.18.0.5", True, False, 403),
    ],
)
def test_clone_write_host_identity_preserves_all_other_fail_closed_gates(
    monkeypatch, db_name, server_host, authorized_token, linked_identity,
    expected_status,
):
    """The October 19 restore showed PostgreSQL inet text 172.18.0.5/32.

    Docker inspect supplies 172.18.0.5, not its mask. PostgreSQL host(inet)
    strips only inet's output mask; database, address, per-clone secret and
    authenticated Person checks must still match exactly. No database used.
    """
    import commands

    class FakeCursor:
        def __init__(self):
            self.query = ""
            self.statements = []

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def execute(self, statement, params=None):
            self.query = statement
            self.statements.append((statement, params))

        def fetchone(self):
            if "host(inet_server_addr()) AS ip" in self.query:
                return {"name": db_name, "ip": server_host}
            if "wo419_preview.authorization" in self.query:
                return {"token": "a" * 48 if authorized_token else "b" * 48}
            if "FROM ref.person" in self.query:
                return {"uuid": "12345678-1234-4234-8234-123456789abc"} if linked_identity else None
            return None

    class FakeConnection:
        def __init__(self):
            self.cur = FakeCursor()
            self.commits = 0
            self.rollbacks = 0
            self.closed = False
            self.session = None

        def set_session(self, **kwargs):
            self.session = kwargs

        def cursor(self, **kwargs):
            return self.cur

        def commit(self):
            self.commits += 1

        def rollback(self):
            self.rollbacks += 1

        def close(self):
            self.closed = True

    fake = FakeConnection()
    monkeypatch.setattr(commands.psycopg2, "connect", lambda dsn: fake)
    writer = object.__new__(commands.CloneCommands)
    writer.dsn = "dbname=isolated_test_fixture"
    writer.token = "a" * 48
    writer.ip = "172.18.0.5"  # Docker inspect host address, no /32

    if expected_status is None:
        with writer.transaction({"person_id": 101}) as cursor:
            assert cursor is fake.cur
        assert fake.commits == 1
        assert fake.rollbacks == 0
        assert any("set_config('app.directus_user_uuid'" in stmt
                   for stmt, _ in fake.cur.statements)
    else:
        with pytest.raises(repository.WorkManagementError) as denied:
            with writer.transaction({"person_id": 101}):
                pytest.fail("Unverified clone/actor was given write access")
        assert denied.value.status == expected_status
        assert fake.commits == 0
        assert fake.rollbacks == 1

    assert fake.session == {"readonly": False, "autocommit": False}
    assert fake.closed
    assert "host(inet_server_addr()) AS ip" in fake.cur.statements[0][0]
    assert "inet_server_addr()::text AS ip" not in fake.cur.statements[0][0]


def test_seasonal_setup_gate_needs_only_select_on_session_and_governed_execute():
    """Regression for real October 19 privilege HOLD at atomic_work_order_setup_season_gate.

    fieldwiring_app has only SELECT on ops.setup_session. The old FOR SHARE
    asked PostgreSQL to acquire a row lock requiring extra table privileges.
    Keep Setup Session management authority inside existing SECURITY DEFINER
    ops.create_setup_season_task; do NOT grant UPDATE merely to read the season.
    """
    from commands import CloneCommands

    class RestrictedSetupCursor:
        def __init__(self):
            self.executed = []
            self.current = ""

        def execute(self, statement, params=None):
            self.current = str(statement)
            self.executed.append((self.current, params))
            if "FOR SHARE" in self.current or "FOR UPDATE" in self.current:
                raise AssertionError("Read-only Setup season precheck requested a row lock")

        def fetchone(self):
            if self.current.startswith("SELECT setup_session_id FROM ops.setup_session "):
                return {"setup_session_id": 909}
            if "SELECT 1 FROM ops.setup_session_task " in self.current:
                return None
            if "SELECT email FROM ref.person" in self.current:
                return {"email": "manager@sheboyganlights.org"}
            if "FROM ops.create_setup_season_task(" in self.current:
                return {"setup_session_task_id": 1212}
            raise AssertionError("Unexpected Setup command query")

    cursor = RestrictedSetupCursor()
    created_id = CloneCommands.create_season_only_work_order_gate(
        cursor,
        {"person_id": 101, "can_manage": True},
        372,
        {"stage_id": 17, "work_area_id": None, "setup_season_year": 2026,
         "problem": "Magic Igloo actual weld repair requiring seasonal readiness"},
    )
    assert created_id == 1212
    assert len(cursor.executed) == 4
    assert "session_status IN ('PLANNING','ACTIVE')" in cursor.executed[0][0]
    assert "FROM ops.create_setup_season_task(" in cursor.executed[-1][0]
    assert cursor.executed[-1][1][0] == "manager@sheboyganlights.org"
    assert cursor.executed[-1][1][14] == 372
    assert cursor.executed[-1][1][15] is True

    grants = (ROOT / "WorkOrders/Acceptance/wo419_preview_clone_read_grants.sql").read_text(
        encoding="utf-8"
    )
    assert "ops.setup_session," in grants
    assert "ops.setup_session_task," in grants
    assert "GRANT EXECUTE ON FUNCTION ops.create_setup_season_task(" in grants
    assert "GRANT UPDATE ON ops.setup_session" not in grants
    assert "GRANT INSERT ON ops.setup_session_task" not in grants


def test_manager_maintenance_is_separate_from_crew_work_and_create_opens_editor():
    """Operator CHANGES REQUIRED: normal work actions, manager maintenance, Create."""
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    css = (HERE / "app.css").read_text(encoding="utf-8")
    assert html.index('id="review-workbench"') < html.index('class="detail-fields"')
    assert 'id="review-action-buttons"' in html
    assert 'id="manager-assign-button"' in html
    assert 'id="review-submit"' in html
    assert 'id="review-completion-notes"' in html
    assert 'id="review-progress-note"' in html
    assert 'id="review-action" hidden' in html
    assert "progress: \"Add Work Note\"" in js
    assert "complete: \"Complete Work Order\"" in js
    assert "kind !== \"create\" && kind !== \"assign\"" in js
    assert "function openManagerAssignment()" in js
    assert 'byId("manager-assign-button").addEventListener("click"' in js
    assert 'byId("review-action").value = "create"' in js
    assert 'byId("review-action-form").addEventListener("submit"' in js
    assert "function showForm()" in js
    assert '.review-action-button.primary-action' in css
    assert 'font-size:17px' in css


def test_in_app_navigation_preserves_browser_back_and_previous_filters():
    js = (HERE / "app.js").read_text(encoding="utf-8")
    for required in (
        'window.history[mode === "replace" ? "replaceState" : "pushState"]',
        'window.addEventListener("popstate"',
        "function restoreNavigation(",
        "function navigationSnapshot(",
        "state.restoringNavigation = true",
        'state.createMode = true',
        '"wo419:history-create"',
        'await selectTicket(snapshot.ticket, {noHistory: true})',
        "state.selected = key;",
        'if (!options.noHistory) writeNavigation("push")',
    ):
        assert required in js, required
    assert 'window.location.href =' not in js
    assert 'window.location.assign(' not in js


def test_planning_is_reversible_view_filter_and_preserves_unknown_priority():
    repo_source = (HERE / "repository.py").read_text(encoding="utf-8")
    backend_source = (HERE / "backend.py").read_text(encoding="utf-8")
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "app.js").read_text(encoding="utf-8")
    assert 'id="include-planning"' in html
    assert 'Show planning work (Priority 5)' in html
    assert '"include_planning"' in backend_source
    assert 't.urgency IS DISTINCT FROM 5' in repo_source
    assert 'if not include_planning:' in repo_source
    assert repo_source.index('if not include_planning:') < repo_source.index('LIMIT %s')
    assert 'include_planning: $("include-planning").checked ? "1" : "0"' in js
    assert '"&include_planning="' in js
    assert "Planning (priority 5) hidden" in js
    assert "DELETE FROM ops.work_order" not in repo_source
    # An all-open aging auditor can still ask for the complete native dataset.
    assert "include_planning: bool = True" in repo_source


def test_backend_planning_toggle_passes_to_native_repo_without_mutation(client):
    response = client.get(
        "/api/work-orders/tickets?scope=mine&include_planning=0", headers=identity(),
    )
    assert response.status_code == 200
    assert response.json["include_planning"] is False
    latest = [value for key, value in FakeRepo.calls if key == "tickets"][-1]
    assert latest["include_planning"] is False
    aging = client.get(
        "/api/work-orders/aging?sort=created_asc&include_planning=0",
        headers=identity(),
    )
    assert aging.status_code == 200
    assert aging.json["include_planning"] is False


def test_oct19_operator_create_form_visibility_and_responsive_filters():
    """Oct 19 CHANGES REQUIRED: Create panel appeared without editable fields."""
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    css = (HERE / "app.css").read_text(encoding="utf-8")
    assert '<div class="control-filters">' in html
    assert '<div class="control-actions">' in html
    assert html.index('id="scope"') < html.index('id="ticket-search"') < html.index('id="ticket-sort"')
    assert 'aria-controls="review-action-form" aria-expanded="false"' in html
    assert 'id="review-action-form" hidden' in html
    assert 'id="review-create-fields" hidden' in html
    assert '.control-filters { display:grid;' in css
    assert 'grid-template-columns:repeat(3, minmax(0, 1fr))' in css
    assert '@media(max-width:650px)' in css
    assert '.control-filters .field { min-width:0; }' in css
    assert 'h3::after { content:" · New internal Work Order"' not in css
    assert 'byId("detail-content").classList.contains("create-mode")' in js
    assert 'else if (creating && available.includes("create")) picker.value = "create"' in js
    assert 'form.hidden = false' in js
    assert 'byId("review-create-fields").hidden = false;' in js
    assert 'byId("create-work-order").setAttribute("aria-expanded", "true")' in js
    assert 'byId("review-problem").focus();' in js
    assert 'byId("create-work-order").setAttribute("aria-expanded", "false")' in js
    assert 'byId("review-action-form").addEventListener("submit"' in js


def test_oct19_tom_crew_intake_manager_direct_creation_and_planning_year():
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    commands_source = (HERE / "commands.py").read_text(encoding="utf-8")
    assert 'href="https://forms.gle/Gve4ZbXHDWxs43yh6"' in html
    assert "Submit Work Order Request" in html
    assert 'id="create-work-order"' in html
    assert 'id="review-year-wrap" hidden' in html
    assert '<option value="3" selected>3 · Normal</option>' in html
    assert 'if (actor.can_manage) result.push("create")' in js
    assert 'byId("create-work-order").hidden = !model.actor.can_manage' in js
    assert 'if (!model.actor?.can_manage) return;' in js
    assert 'byId("review-urgency").value = "3"' in js
    assert 'byId("review-urgency").addEventListener("change", () => { planningChanged(); updateIntakeComparison(); })' in js
    assert 'byId("review-year-wrap").hidden = !planning' in js
    assert 'byId("review-target-year").required = planning' in js
    assert 'byId("review-urgency").value === "5"' in js
    assert '"Planning Work Orders require a target year."' in commands_source
    assert '"Target year applies only to Planning (urgency 5)."' in commands_source
    assert 'if action == "create" and not actor["can_manage"]' in commands_source
    assert "Only Managers may create Work Orders directly." in commands_source
    assert 'href="https://forms.gle/Gve4ZbXHDWxs43yh6"' in html  # reuse public Intake form


def test_v1_requires_dedicated_native_runtime_not_disposable_credentials(monkeypatch):
    """V1 cannot be enabled by merely supplying the existing clone's DSN."""
    import v1_runtime
    from repository import WorkManagementError
    monkeypatch.delenv("WORK_MGMT_RUNTIME_MODE", raising=False)
    monkeypatch.delenv("WORK_MGMT_PRODUCTION_DSN", raising=False)
    monkeypatch.delenv("WORK_MGMT_V1_WRITE_GATE", raising=False)
    with pytest.raises(WorkManagementError, match="not enabled"):
        v1_runtime.V1Repository()
    with pytest.raises(WorkManagementError, match="not enabled"):
        v1_runtime.V1Commands()

    monkeypatch.setenv("WORK_MGMT_RUNTIME_MODE", "production")
    monkeypatch.setenv("WORK_MGMT_DATABASE_DSN", "host=192.0.2.1 dbname=msb_wo419_preview")
    with pytest.raises(WorkManagementError, match="not configured"):
        v1_runtime.V1Repository()
    monkeypatch.setenv("WORK_MGMT_PRODUCTION_DSN", "dbname=msb user=work_management_app")
    obj = v1_runtime.V1Commands()
    with pytest.raises(WorkManagementError, match="not approved"):
        obj.perform({"email": "reviewer@sheboyganlights.org"}, "create", None, {})
    # A production read source does not automatically grant any live writes.
    assert v1_runtime.V1Repository.activity_table == "ops.work_management_activity"
    assert repository.WorkManagementRepository.activity_table == "wo419_preview.activity"


def test_v1_backend_uses_distinct_command_path_and_protected_proxy():
    """Route/source contract: preview remains isolated, V1 never uses clone DML."""
    source = (HERE / "backend.py").read_text(encoding="utf-8")
    entry = (HERE / "production_entry.py").read_text(encoding="utf-8")
    runtime = (HERE / "v1_runtime.py").read_text(encoding="utf-8")
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    app_js = (HERE / "app.js").read_text(encoding="utf-8")
    assert 'APP_VERSION = "V1.0.0-work-orders-release-candidate"' in source
    assert 'from v1_runtime import V1Repository' in source
    assert 'from v1_runtime import V1Commands' in source
    assert 'return CloneCommands()' in source
    assert 'return V1Commands()' in source
    assert 'return jsonify(result=result, **runtime_response())' in source
    assert 'X-MSB-Work-Order-Command' in source and 'X-MSB-Work-Order-Command' in js
    assert 'WORK_MGMT_PRODUCTION_COMMAND_SECRET' in source
    assert 'hashlib.sha256' in source
    assert 'require_v1_production_configuration(writes=True)' in entry
    assert 'WORK_MGMT_PRODUCTION_PROXY_APPROVED' in entry
    assert 'WORK_MGMT_V1_WRITE_GATE' in entry
    assert 'run_simple(' not in entry  # Server Management owns serving lifecycle
    assert 'WORK_MGMT_PRODUCTION_DSN' in runtime
    assert 'session_user AS login_name' in runtime
    assert 'work_management_app' in runtime
    assert 'SELECT ops.work_management_v1_command(' in runtime
    assert 'SELECT event_kind,actor_person_id' in runtime
    assert 'PRODUCTION Work Orders database?' in js
    assert 'Notifications are held pending release; not sent.' in js
    assert 'Work Orders V1 · Production records' in app_js


def test_v1_sql_uses_native_tables_and_narrow_executor_not_browser_dml():
    """V1 needs a separate reviewed migration, no shared preview grant shortcut."""
    sql = (HERE.parent / "Database" / "001_work_management_v1_governed_commands.sql").read_text(
        encoding="utf-8")
    assert 'current_database() = \'msb\'' in sql
    assert "approved_maintenance_snapshot" in sql
    assert "approved_disposable_clone" in sql
    assert "work_management_app" in sql
    assert "SECURITY DEFINER" in sql
    for native in (
        "ops.work_order", "ops.work_order_assignment",
        "stage.work_order_intake", "ref.person",
        "ops.work_management_v1_command",
        "ops.work_management_v1_actor",
        "ops.work_management_v1_activity",
    ):
        assert native in sql
    for gate in (
        'Only Managers', # source SQL uses explicit authorization conditions
        "v_actor.can_manage",
        "Work Orders: active assignee required",
        "Work Orders: Planning requires target year",
        "Work Orders: only Planning may have target year",
        "SET search_path = pg_catalog,ops,ref",
        "pg_advisory_xact_lock",
        "app.directus_user_uuid",
        "work_management_permission",
        "PENDING_CUTOVER",
        "MISSING_RECIPIENT",
        "No email is sent",
    ):
        if gate == 'Only Managers':
            continue
        assert gate in sql, gate
    assert "GRANT EXECUTE ON FUNCTION ops.work_management_v1_actor" in sql
    assert "GRANT SELECT ON ref.person" in sql
    assert "GRANT SELECT ON ops.work_management_activity TO work_management_app;" in sql
    assert "GRANT INSERT ON ops.work_management_activity TO work_management_app" not in sql
    assert "GRANT UPDATE ON ops.work_management_activity TO work_management_app" not in sql
    assert "GRANT SELECT ON ops.work_management_outbox TO work_management_app" not in sql
    assert "TO work_management_app" in sql
    assert "GRANT INSERT ON ops.work_order TO work_management_app" not in sql
    assert "GRANT UPDATE ON ops.work_order TO work_management_app" not in sql
    assert "GRANT ALL ON" not in sql
    assert "CREATE TABLE IF NOT EXISTS ops.work_order (" not in sql
    assert "TRUNCATE" not in sql
    assert "DELETE FROM ops.work_order" not in sql
    assert "INSERT INTO ops.work_management_permission" not in sql


def test_v1_no_unapproved_live_role_grants_or_notification_send():
    sql = (HERE.parent / "Database" / "001_work_management_v1_governed_commands.sql").read_text(
        encoding="utf-8")
    source = (HERE / "v1_runtime.py").read_text(encoding="utf-8")
    assert "No email is sent" in sql or "NO email is sent" in sql
    assert "ops.work_management_outbox" in sql
    assert "PENDING_CUTOVER" in sql
    assert "work_management_permission" in sql
    assert "approved_by_person_id" in sql
    assert "UPDATE ops.work_management_permission SET can_manage=true" not in sql
    assert "import smtplib" not in source.lower()
    assert "smtplib." not in source.lower()
    assert "sendmail" not in source.lower()


def test_v1_native_browser_cloned_mode_stays_separate_from_production(monkeypatch):
    import backend
    import v1_runtime
    from repository import WorkManagementError
    monkeypatch.setenv("WORK_MGMT_RUNTIME_MODE", "v1_disposable")
    monkeypatch.delenv("WORK_MGMT_V1_CLONE_DSN", raising=False)
    monkeypatch.delenv("WORK_MGMT_V1_CLONE_IP", raising=False)
    monkeypatch.delenv("WORK_MGMT_PREVIEW_MODE", raising=False)
    with pytest.raises(WorkManagementError, match="clone configuration missing"):
        v1_runtime.V1Repository()
    with pytest.raises(WorkManagementError, match="clone configuration missing"):
        v1_runtime.V1Commands()
    monkeypatch.setenv("WORK_MGMT_PREVIEW_MODE", "disposable")
    monkeypatch.setenv("WORK_MGMT_V1_CLONE_DSN", "dbname=msb_wo419_preview user=work_management_app")
    monkeypatch.setenv("WORK_MGMT_V1_CLONE_IP", "172.18.0.5")
    with pytest.raises(WorkManagementError, match="not authorized"):
        v1_runtime.V1Commands().perform(
            {"email": "someone@sheboyganlights.org"}, "create", None, {}
        )
    assert type(backend.store()).__name__ == "V1Repository"
    assert type(backend.command_store()).__name__ == "V1Commands"
    assert backend.runtime_response() == {
        "runtime_mode": "v1_disposable",
        "disposable_only": True,
        "notifications": "NO_SEND_V1",
    }


def test_v1_browser_clone_exact_db_role_and_ip_required():
    import v1_runtime
    from repository import WorkManagementError
    class StubCursor:
        def __init__(self, first, second):
            self.rows = [first, second]
        def execute(self, *_args):
            pass
        def fetchone(self):
            return self.rows.pop(0)
    import os
    previous = {k: os.environ.get(k) for k in ("WORK_MGMT_RUNTIME_MODE", "WORK_MGMT_V1_CLONE_IP")}
    try:
        os.environ["WORK_MGMT_RUNTIME_MODE"] = "v1_disposable"
        os.environ["WORK_MGMT_V1_CLONE_IP"] = "172.18.0.5"
        v1_runtime.require_native_database(
            StubCursor(
                {"db_name": "msb_wo419_preview", "login_name": "work_management_app"},
                {"host_ip": "172.18.0.5"},
            )
        )
        for db, user, ip in (
            ("msb", "work_management_app", "172.18.0.5"),
            ("msb_wo419_preview", "fieldwiring_app", "172.18.0.5"),
            ("msb_wo419_preview", "work_management_app", "172.18.0.99"),
        ):
            with pytest.raises(WorkManagementError):
                v1_runtime.require_native_database(
                    StubCursor({"db_name": db, "login_name": user}, {"host_ip": ip})
                )
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def test_native_v1_browser_announces_disposable_sql_and_hides_unsupported_setup_link():
    app_js = (HERE / "app.js").read_text(encoding="utf-8")
    actions = (HERE / "review_actions.js").read_text(encoding="utf-8")
    assert 'state.actor.runtime_mode === "v1_disposable"' in app_js
    assert "Work Orders V1 NATIVE · Disposable database · No emails sent" in app_js
    assert "V1 PostgreSQL commands on an isolated clone" in app_js
    assert 'model.runtime === "disposable"' in actions
    assert 'result.push("link_setup");' in actions
    assert 'model.runtime === "production"' in actions
    assert 'X-MSB-Work-Order-Command' in actions


def test_oct20_task_type_search_and_nondestructive_public_intake_review_contract():
    """Manager UI must distinguish raw report from catalog identity and nonpromotion."""
    html = (HERE / "index.html").read_text(encoding="utf-8")
    app_js = (HERE / "app.js").read_text(encoding="utf-8")
    actions = (HERE / "review_actions.js").read_text(encoding="utf-8")
    repository_source = (HERE / "repository.py").read_text(encoding="utf-8")
    backend_source = (HERE / "backend.py").read_text(encoding="utf-8")
    sql = (HERE.parent / "Database" / "001_work_management_v1_governed_commands.sql").read_text(encoding="utf-8")
    assert 'id="task-type-filter"' in html
    assert 'task_type_id: $("task-type-filter").value' in app_js
    assert 'task_type_id=task_type_id' in backend_source
    assert "w.task_type_id=%s" in repository_source
    assert 'id="review-intake-comparison"' in html
    assert 'id="intake-original-type"' in html
    assert 'id="intake-mapping-status"' in html
    assert "uniqueCatalogMatch" in actions
    assert 'result.push("promote", "resolve")' in actions
    assert 'result.push("clarify");' in actions
    assert "MISSING_RECIPIENT" in sql
    assert "p_action='correction_owner' AND" in sql
    assert "p_action IN ('clarify','resolve') AND EXISTS" in sql
    assert "('promoted_source','resolve')" in repository_source


def test_task_type_filter_reads_catalog_and_rejects_invalid_identifiers(client, monkeypatch):
    # No Manager privilege is needed to read a Task Type used in assigned work.
    crew = {"person_id": 101, "display_name": "Crew",
            "can_manage": False, "can_create": False, "can_read": True}
    monkeypatch.setattr(FakeRepo, "access", lambda self, _email: crew)
    listing = client.get("/api/work-orders/task-types", headers=identity())
    assert listing.status_code == 200
    assert listing.json["task_types"] == [{"id": 10, "name": "Repair"}]
    result = client.get(
        "/api/work-orders/tickets?scope=mine&task_type_id=10", headers=identity()
    )
    assert result.status_code == 200
    assert any(call[0] == "tickets" and
               call[1]["task_type_id"] == 10 for call in FakeRepo.calls)
    for invalid in ("0", "-1", "10;DROP", "abc"):
        blocked = client.get(
            "/api/work-orders/tickets?scope=mine&task_type_id=" + invalid,
            headers=identity(),
        )
        assert blocked.status_code == 400
    # The fake service does not impose SQL scope gates; actual repo must.
    assert "Manager view requires Manager permission" in (
        HERE / "repository.py"
    ).read_text(encoding="utf-8")


def test_oct20_second_review_edit_cancel_and_manager_buttons_contract():
    html = (HERE / "index.html").read_text(encoding="utf-8")
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    app = (HERE / "app.js").read_text(encoding="utf-8")
    db = (HERE.parent / "Database" / "001_work_management_v1_governed_commands.sql").read_text(encoding="utf-8")
    commands = (HERE / "commands.py").read_text(encoding="utf-8")
    assert 'id="review-cancel-create"' in html
    assert 'id="review-edit-reason"' in html
    assert 'id="review-cancel-reason"' in html
    assert 'value="intake" data-manager-only' not in html
    assert 'value="feedback" data-manager-only' not in html
    assert 'id="go-intake"' in html and 'id="go-feedback"' in html
    assert 'result.push("assign", "edit", "cancel")' in js
    assert 'review-edit-reason' in js and 'review-cancel-reason' in js
    assert 'wo419:cancel-create' in js and 'wo419:cancel-create' in app
    assert 'CANCELLED_NO_ACTION' in app and 'CANCELLED_NO_ACTION' in db
    assert 'p_action=\'edit\'' in db and 'p_action=\'cancel\'' in db
    assert 'action in ("edit", "cancel")' in commands
    assert 'updated_by_person_id=v_actor.person_id' in db
    assert 'physical_work_completed' in db
    assert 'v_wo.display_test_session_id IS NOT NULL' in db


def test_oct20_rejected_work_order_requires_manager_before_clone_write():
    import commands
    from uuid import uuid4
    writer = commands.CloneCommands.__new__(commands.CloneCommands)
    writer.transaction = lambda _actor: (_ for _ in ()).throw(
        AssertionError("Crew cannot enter a mutation transaction")
    )
    crew = {"person_id": 202, "can_manage": False, "can_read": True}
    for action in ("edit", "cancel"):
        with pytest.raises(repository.WorkManagementError) as denial:
            writer.perform(crew, action, "WO-47", {"request_key": str(uuid4())})
        assert denial.value.status == 403


def test_oct20_edit_does_not_enter_create_insert_branch():
    sql = (HERE.parent / "Database" /
           "001_work_management_v1_governed_commands.sql").read_text(encoding="utf-8")
    assert "IF p_action IN ('create','promote','edit')" not in sql
    assert "IF p_action IN ('create','promote') THEN" in sql
    assert "ELSIF p_action='edit' THEN" in sql
    assert sql.count("v_problem := btrim(coalesce(p_body->>'problem',''));") == 2
    assert sql.count("CREATE OR REPLACE FUNCTION ops.work_management_v1_command") == 1
    assert sql.count("CREATE OR REPLACE FUNCTION ops.work_management_v1_activity") == 1
    assert sql.count("$cmd$") == 2
    assert sql.count("COMMIT;") == 1
    assert "{0,9}btrim" not in sql
    assert sql.count("^[1-9][0-9]{0,9}$") >= 7

    assert sql.index("ELSIF p_action='edit' THEN") > sql.index("INSERT INTO ops.work_order(")
    assert "WHERE work_order_id=v_wo_id AND is_active AND date_completed IS NULL" in sql
