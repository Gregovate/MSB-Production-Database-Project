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

    def assignees(self):
        return [{"person_id": 101, "display_name": "Preview Person"},
                {"person_id": 202, "display_name": "Another Person"}]

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
