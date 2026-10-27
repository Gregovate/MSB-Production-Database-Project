"""Server-side Directus Users API client for #395 human identity bootstrap.

This client is intentionally narrow:
- it is never imported by browser JavaScript;
- its bearer credential is runtime-only;
- it can create only a Google-backed active user with the exact Cloudflare/
  Person email and the database-resolved MSB Browser role;
- it never updates an existing Directus user.

Directus 11.x requires administrator accountability to set provider and
external_identifier through UsersService. The runtime credential therefore
must be protected as an internal server-side secret and used only by this
narrow endpoint.
"""

from __future__ import annotations

import json
import os
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import ProxyHandler, Request, build_opener


class DirectusIdentityBootstrapError(RuntimeError):
    pass


DIRECT_OPENER = build_opener(ProxyHandler({}))


def directus_base_url() -> str:
    return (
        os.environ.get("PEOPLE_DIRECTUS_URL", "http://127.0.0.1:8055").strip().rstrip("/")
        or "http://127.0.0.1:8055"
    )


def directus_identity_token() -> str:
    token = os.environ.get("PEOPLE_DIRECTUS_IDENTITY_TOKEN", "").strip()
    if not token:
        raise DirectusIdentityBootstrapError(
            "MSB application identity initialization is temporarily unavailable."
        )
    return token


class DirectusIdentityBootstrapClient:
    def __init__(self, *, base_url: str | None = None, token: str | None = None):
        self.base_url = (base_url or directus_base_url()).rstrip("/")
        self.token = token or directus_identity_token()

    def create_google_browser_user(
        self,
        *,
        email: str,
        first_name: str,
        last_name: str,
        baseline_role_id: str,
    ) -> dict[str, Any]:
        normalized_email = (email or "").strip().lower()
        normalized_first = (first_name or "").strip()
        normalized_last = (last_name or "").strip()
        normalized_role = (baseline_role_id or "").strip()

        if not normalized_email.endswith("@sheboyganlights.org"):
            raise DirectusIdentityBootstrapError("MSB application identity email is invalid.")
        if not normalized_first or not normalized_last:
            raise DirectusIdentityBootstrapError(
                "MSB application identity requires an existing named Person record."
            )
        if not normalized_role:
            raise DirectusIdentityBootstrapError(
                "MSB Browser baseline role is not configured."
            )

        payload = {
            "email": normalized_email,
            "first_name": normalized_first,
            "last_name": normalized_last,
            "status": "active",
            "provider": "google",
            "external_identifier": normalized_email,
            "role": normalized_role,
        }
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        request_object = Request(
            f"{self.base_url}/users",
            data=body,
            method="POST",
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
        )

        try:
            with DIRECT_OPENER.open(request_object, timeout=15) as response:
                parsed = json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            message = f"Directus rejected identity initialization (HTTP {exc.code})"
            try:
                error_payload = json.loads(exc.read().decode("utf-8"))
                errors = error_payload.get("errors") or []
                if errors and isinstance(errors[0], dict):
                    safe_detail = str(errors[0].get("message") or "").strip()
                    if safe_detail:
                        message = safe_detail
            except Exception:
                pass
            raise DirectusIdentityBootstrapError(message) from exc
        except (URLError, TimeoutError) as exc:
            raise DirectusIdentityBootstrapError(
                "Directus identity service is unavailable."
            ) from exc
        except (ValueError, json.JSONDecodeError) as exc:
            raise DirectusIdentityBootstrapError(
                "Directus identity service returned invalid data."
            ) from exc

        data = parsed.get("data") if isinstance(parsed, dict) else None
        if not isinstance(data, dict) or not data.get("id"):
            raise DirectusIdentityBootstrapError(
                "Directus identity initialization returned no user identity."
            )
        return data
