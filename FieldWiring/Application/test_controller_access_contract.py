from pathlib import Path

import pytest

from controller_access import (
    CLOUDFLARE_EMAIL_HEADER,
    ControllerAuthenticationError,
    cloudflare_operator_email,
)


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent


def test_cloudflare_access_email_is_the_controller_browser_identity() -> None:
    email = cloudflare_operator_email(
        {CLOUDFLARE_EMAIL_HEADER: "  GLiebig@SheboyganLights.org  "}
    )

    assert email == "gliebig@sheboyganlights.org"


def test_controller_management_rejects_missing_cloudflare_identity() -> None:
    with pytest.raises(ControllerAuthenticationError):
        cloudflare_operator_email({})


def test_authorization_function_preserves_fieldwiring_read_only_table_boundary() -> None:
    sql = (
        REPO_ROOT
        / "Controllers"
        / "Database"
        / "021_create_controller_browser_authorization_contract.sql"
    ).read_text(encoding="utf-8")

    assert "SECURITY DEFINER" in sql
    assert "ref.controller_browser_capabilities" in sql
    assert "GRANT EXECUTE ON FUNCTION" in sql
    assert "TO fieldwiring_app" in sql
    assert "fieldwiring_controller_update" in sql
    assert "GRANT SELECT ON public.directus_users" not in sql
    assert "GRANT UPDATE ON ref.controller" not in sql


def test_backend_exposes_capability_endpoint_without_directus_cookie_flow() -> None:
    source = (BASE_DIR / "backend.py").read_text(encoding="utf-8")

    assert '@app.get("/api/controller-access")' in source
    assert "cloudflare_operator_email(request.headers)" in source
    assert "controller_browser_access(repository(), email)" in source
    assert "directus_session" not in source
    assert "db.sheboyganlights.org" not in source
