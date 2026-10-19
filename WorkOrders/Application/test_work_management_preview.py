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

    def manager_inbox(self, actor):
        FakeRepo.calls.append(("manager_inbox", actor["person_id"]))
        if not actor["can_manage"]:
            raise repository.WorkManagementError("Manager Intake is not authorized.", 403)
        return {"public_intake": 2, "task_feedback": 1}

    def assignees(self):
        return [{"person_id": 101, "display_name": "Preview Person"},
                {"person_id": 202, "display_name": "Another Person"}]

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
            "show_completed": False, "search": "", "sort": "priority",
        }) in FakeRepo.calls


def test_review_script_is_ticket_local_and_clone_only(client):
    page = client.get("/work-orders/", headers=identity())
    assert page.status_code == 200
    assert b"review_actions.js" in page.data
    assert b"Disposable database only." in page.data
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
                    "can_manage": False, "can_create": True,
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


def test_create_is_allowed_for_crew_without_assignment_but_triage_is_not():
    import commands
    from uuid import uuid4
    writer = commands.CloneCommands.__new__(commands.CloneCommands)
    crew = {"person_id": 202, "can_manage": False, "can_read": True}
    with pytest.raises(repository.WorkManagementError) as denied:
        writer.perform(crew, "create", None,
                       {"request_key": str(uuid4()), "person_ids": [101]})
    assert denied.value.status == 403
    with pytest.raises(repository.WorkManagementError) as denied:
        writer.perform(crew, "assign", "WO-372",
                       {"request_key": str(uuid4()), "person_ids": [101]})
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


def test_crew_direct_create_reaches_clone_command_without_manager_privilege():
    import commands
    from uuid import uuid4
    writer = commands.CloneCommands.__new__(commands.CloneCommands)
    sentinel = "Crew permission passed; clone transaction required"
    class TransactionReached(RuntimeError):
        pass
    def fake_transaction(_actor):
        raise TransactionReached(sentinel)
    writer.transaction = fake_transaction
    crew = {"person_id": 202, "can_manage": False, "can_create": True,
            "can_read": True}
    with pytest.raises(TransactionReached, match=sentinel):
        writer.perform(crew, "create", None, {
            "request_key": str(uuid4()), "person_ids": [],
        })


def test_manager_intake_count_excludes_promoted_and_closed_history():
    source = (HERE / "repository.py").read_text(encoding="utf-8")
    assert "def manager_inbox(" in source
    assert "a.event_kind = 'promoted_source'" in source
    assert "a.event_kind IN ('resolve','promoted_source')" in source
    assert 'scope == "intake"' in source
    assert 'scope == "feedback"' in source
    assert 'scope == "my-created"' in source
    assert "t.reporter_id = %s" in source
    html = (HERE / "index.html").read_text(encoding="utf-8")
    assert 'value="my-created"' in html
    assert 'value="intake" data-manager-only' in html
    assert "Public Work Order Request" in html
    js = (HERE / "review_actions.js").read_text(encoding="utf-8")
    assert "if (actor.can_create)" in js
    assert "!model.actor?.can_manage" in js or "!model.actor?.can_create" in js
    assert "model.actor?.can_manage" in js
    assert "payload.disposable_only" in js


def test_directus_role_permissions_do_not_promote_generic_volunteer_or_browser():
    permits = repository.work_management_role_permissions
    crew = permits({"role_name": "Production Crew", "policy_names": [],
                    "can_manage_setup": False})
    assert crew == {"can_manage": False, "can_create": True,
                    "can_assign": False, "can_triage": False}
    manager = permits({"role_name": "Manager", "policy_names": [],
                       "can_manage_setup": True})
    assert all(manager.values())
    admin = permits({"role_name": "Administrator", "policy_names": [],
                     "can_manage_setup": True})
    assert all(admin.values())
    delegated = permits({"role_name": "Unassigned", "policy_names": ["Production Crew"],
                         "can_manage_setup": False})
    assert delegated["can_create"] and not delegated["can_assign"]
    for role, policy in (("Volunteer", ["Volunteer"]), ("MSB Browser", []),
                         ("Unassigned", [])):
        ordinary = permits({"role_name": role, "policy_names": policy,
                            "can_manage_setup": False})
        assert not ordinary["can_create"]
        assert not ordinary["can_assign"]
        assert not ordinary["can_triage"]


def test_manager_all_work_orders_is_not_the_intake_queue():
    source = (HERE / "repository.py").read_text(encoding="utf-8")
    assert 'if scope == "all":' in source
    assert '''conditions.append("t.type = 'WORK_ORDER'")''' in source
    assert '"tickets"' in source
    html = (HERE / "index.html").read_text(encoding="utf-8")
    assert 'value="tickets" data-manager-only' in html
    assert 'value="all" data-manager-only' in html
    assert 'value="intake" data-manager-only' in html
    assert "Number (WO / Intake)" in html
