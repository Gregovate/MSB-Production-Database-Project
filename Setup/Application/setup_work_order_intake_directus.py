"""Directus Items API client for Setup Report Correction Intake creation.

The existing Work Order Intake manager-notification flow is a Directus
items.create event. Setup therefore prepares/authorizes the Intake payload in
PostgreSQL, then creates the Intake item through Directus so that existing
Work Order Intake automation remains authoritative.
"""
from __future__ import annotations

import json
import os
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import ProxyHandler, Request, build_opener


class SetupDirectusIntakeError(RuntimeError):
    pass


DIRECT_OPENER = build_opener(ProxyHandler({}))


def directus_base_url() -> str:
    return (
        os.environ.get("SETUP_DIRECTUS_URL", "http://127.0.0.1:8055").strip().rstrip("/")
        or "http://127.0.0.1:8055"
    )


def directus_intake_token() -> str:
    token = os.environ.get("SETUP_DIRECTUS_INTAKE_TOKEN", "").strip()
    if not token:
        raise SetupDirectusIntakeError(
            "Setup Directus Work Order Intake service credential is not configured"
        )
    return token


class SetupDirectusIntakeClient:
    def __init__(self, *, base_url: str | None = None, token: str | None = None):
        self.base_url = (base_url or directus_base_url()).rstrip("/")
        self.token = token or directus_intake_token()

    def create_intake(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise SetupDirectusIntakeError("Prepared Work Order Intake payload is invalid")
        if payload.get("source_system") != "SETUP":
            raise SetupDirectusIntakeError("Prepared Intake source_system is not SETUP")
        if payload.get("source_form_name") != "SETUP_CORRECTION":
            raise SetupDirectusIntakeError(
                "Prepared Intake source_form_name is not SETUP_CORRECTION"
            )
        if str(payload.get("triage_dropdown") or "") != "1":
            raise SetupDirectusIntakeError(
                "Prepared Intake must enter manager triage as Submitted"
            )

        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        request_object = Request(
            f"{self.base_url}/items/work_order_intake",
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
            message = f"Directus rejected Work Order Intake creation (HTTP {exc.code})"
            try:
                error_payload = json.loads(exc.read().decode("utf-8"))
                errors = error_payload.get("errors") or []
                if errors and isinstance(errors[0], dict):
                    safe_detail = str(errors[0].get("message") or "").strip()
                    if safe_detail:
                        message = safe_detail
            except Exception:
                pass
            raise SetupDirectusIntakeError(message) from exc
        except (URLError, TimeoutError) as exc:
            raise SetupDirectusIntakeError(
                "Directus Work Order Intake service is unavailable"
            ) from exc
        except (ValueError, json.JSONDecodeError) as exc:
            raise SetupDirectusIntakeError(
                "Directus Work Order Intake service returned invalid JSON"
            ) from exc

        data = parsed.get("data") if isinstance(parsed, dict) else None
        if not isinstance(data, dict) or data.get("intake_id") is None:
            raise SetupDirectusIntakeError(
                "Directus Work Order Intake creation returned no Intake identity"
            )
        return data
