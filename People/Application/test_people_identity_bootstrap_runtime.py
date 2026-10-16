import json

import backend
import directus_identity_bootstrap as dib


class FakeHttpResponse:
    status = 200

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self):
        return b'{"data":{"id":"11111111-1111-1111-1111-111111111111"}}'


class FakeOpener:
    def __init__(self):
        self.request = None
        self.timeout = None

    def open(self, request, timeout):
        self.request = request
        self.timeout = timeout
        return FakeHttpResponse()


def test_directus_client_posts_exact_google_browser_payload(monkeypatch):
    opener = FakeOpener()
    monkeypatch.setattr(dib, "DIRECT_OPENER", opener)

    client = dib.DirectusIdentityBootstrapClient(
        base_url="http://127.0.0.1:8055",
        token="runtime-secret",
    )
    result = client.create_google_browser_user(
        email="Human@SheboyganLights.org",
        first_name="Human",
        last_name="Tester",
        baseline_role_id="0ce54f42-8438-4eb6-8081-4303612c9da1",
    )

    assert result["id"] == "11111111-1111-1111-1111-111111111111"
    assert opener.request.full_url == "http://127.0.0.1:8055/users"
    assert opener.timeout == 15
    assert opener.request.get_header("Authorization") == "Bearer runtime-secret"

    payload = json.loads(opener.request.data.decode("utf-8"))
    assert payload == {
        "email": "human@sheboyganlights.org",
        "first_name": "Human",
        "last_name": "Tester",
        "status": "active",
        "provider": "google",
        "external_identifier": "human@sheboyganlights.org",
        "role": "0ce54f42-8438-4eb6-8081-4303612c9da1",
    }


def bootstrap_post(client, email="human@sheboyganlights.org"):
    return client.post(
        "/api/identity/bootstrap",
        json={},
        headers={
            "Cf-Access-Authenticated-User-Email": email,
            "X-MSB-Identity-Bootstrap": "1",
        },
    )


def test_ready_create_uses_directus_then_exact_reconcile(monkeypatch):
    statuses = iter(
        [
            {
                "disposition": "READY_CREATE",
                "first_name": "Human",
                "last_name": "Tester",
                "baseline_role_id": "0ce54f42-8438-4eb6-8081-4303612c9da1",
            },
            {
                "disposition": "SAFE_EXISTING_LINK",
                "role_name": "MSB Browser",
            },
            {
                "disposition": "EXISTING_OK",
                "role_name": "MSB Browser",
            },
        ]
    )
    monkeypatch.setattr(backend, "identity_bootstrap_status", lambda email: next(statuses))

    reconciled = []
    monkeypatch.setattr(
        backend,
        "identity_bootstrap_reconcile",
        lambda email: reconciled.append(email) or {"link_reconciled": True},
    )

    created = []

    class FakeClient:
        def create_google_browser_user(self, **kwargs):
            created.append(kwargs)
            return {"id": "11111111-1111-1111-1111-111111111111"}

    monkeypatch.setattr(backend, "DirectusIdentityBootstrapClient", FakeClient)

    client = backend.app.test_client()
    response = bootstrap_post(client)

    assert response.status_code == 201
    assert response.get_json()["identity"] == {
        "state": "ready",
        "created": True,
        "linked": True,
        "role_name": "MSB Browser",
    }
    assert created == [
        {
            "email": "human@sheboyganlights.org",
            "first_name": "Human",
            "last_name": "Tester",
            "baseline_role_id": "0ce54f42-8438-4eb6-8081-4303612c9da1",
        }
    ]
    assert reconciled == ["human@sheboyganlights.org"]


def test_existing_manager_is_idempotent_and_role_preserved(monkeypatch):
    monkeypatch.setattr(
        backend,
        "identity_bootstrap_status",
        lambda email: {"disposition": "EXISTING_OK", "role_name": "Manager"},
    )

    class ShouldNotCreate:
        def __init__(self):
            raise AssertionError("existing identity must not create a Directus user")

    monkeypatch.setattr(backend, "DirectusIdentityBootstrapClient", ShouldNotCreate)

    client = backend.app.test_client()
    response = bootstrap_post(client)

    assert response.status_code == 200
    assert response.get_json()["identity"]["role_name"] == "Manager"
    assert response.get_json()["identity"]["created"] is False


def test_existing_safe_link_reconciles_without_role_change(monkeypatch):
    statuses = iter(
        [
            {"disposition": "SAFE_EXISTING_LINK", "role_name": "Production Crew"},
            {"disposition": "EXISTING_OK", "role_name": "Production Crew"},
        ]
    )
    monkeypatch.setattr(backend, "identity_bootstrap_status", lambda email: next(statuses))
    reconciled = []
    monkeypatch.setattr(
        backend,
        "identity_bootstrap_reconcile",
        lambda email: reconciled.append(email) or {"link_reconciled": True},
    )

    class ShouldNotCreate:
        def __init__(self):
            raise AssertionError("existing identity must not create a Directus user")

    monkeypatch.setattr(backend, "DirectusIdentityBootstrapClient", ShouldNotCreate)

    client = backend.app.test_client()
    response = bootstrap_post(client)

    assert response.status_code == 200
    assert response.get_json()["identity"]["role_name"] == "Production Crew"
    assert reconciled == ["human@sheboyganlights.org"]


def test_missing_person_fails_before_directus_create(monkeypatch):
    monkeypatch.setattr(
        backend,
        "identity_bootstrap_status",
        lambda email: {"disposition": "NO_PERSON"},
    )

    class ShouldNotCreate:
        def __init__(self):
            raise AssertionError("missing Person must not create a Directus user")

    monkeypatch.setattr(backend, "DirectusIdentityBootstrapClient", ShouldNotCreate)

    client = backend.app.test_client()
    response = bootstrap_post(client)

    assert response.status_code == 403
    assert "no active People record" in response.get_json()["error"]


def test_nonhuman_account_is_noop_and_never_person_bootstrapped(monkeypatch):
    monkeypatch.setattr(
        backend,
        "identity_bootstrap_status",
        lambda email: {"disposition": "NONHUMAN_ACCOUNT", "role_name": "MSB Browser"},
    )

    class ShouldNotCreate:
        def __init__(self):
            raise AssertionError("nonhuman identity must not create a Directus user")

    monkeypatch.setattr(backend, "DirectusIdentityBootstrapClient", ShouldNotCreate)

    client = backend.app.test_client()
    response = bootstrap_post(client, "tablet-99@sheboyganlights.org")

    assert response.status_code == 200
    assert response.get_json()["identity"] == {
        "state": "nonhuman",
        "created": False,
        "linked": False,
        "role_name": "MSB Browser",
    }


def test_bootstrap_requires_cloudflare_identity_and_command_guard():
    client = backend.app.test_client()

    missing_identity = client.post(
        "/api/identity/bootstrap",
        json={},
        headers={"X-MSB-Identity-Bootstrap": "1"},
    )
    assert missing_identity.status_code == 401

    missing_guard = client.post(
        "/api/identity/bootstrap",
        json={},
        headers={"Cf-Access-Authenticated-User-Email": "human@sheboyganlights.org"},
    )
    assert missing_guard.status_code == 403
