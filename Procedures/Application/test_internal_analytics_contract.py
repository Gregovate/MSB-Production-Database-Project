from pathlib import Path

from Procedures.Application import browser


BASE_DIR = Path(__file__).resolve().parent
ANALYTICS_VERSION = "2026-08-31.1"
MEASUREMENT_ID = "G-X08ZTSY0VV"


def test_procedure_page_loads_versioned_analytics_asset() -> None:
    source = (BASE_DIR / "index.html").read_text(encoding="utf-8")
    assert f"static/analytics.js?v={ANALYTICS_VERSION}" in source


def test_procedure_analytics_asset_is_served() -> None:
    browser.app.config.update(TESTING=True)
    with browser.app.test_client() as client:
        response = client.get("/static/analytics.js")
    assert response.status_code == 200
    assert response.mimetype == "application/javascript"
    text = response.get_data(as_text=True)
    assert MEASUREMENT_ID in text


def test_procedure_analytics_uses_approved_privacy_configuration() -> None:
    source = (BASE_DIR / "static" / "analytics.js").read_text(encoding="utf-8")
    assert MEASUREMENT_ID in source
    assert f"const analyticsVersion = '{ANALYTICS_VERSION}'" in source
    assert "allow_google_signals: false" in source
    assert "allow_ad_personalization_signals: false" in source


def test_procedure_page_view_never_sends_query_string_or_raw_url() -> None:
    source = (BASE_DIR / "static" / "analytics.js").read_text(encoding="utf-8")
    assert "const path = window.location.pathname" in source
    assert "page_location: window.location.origin + pagePath" in source
    assert "page_path: pagePath" in source
    assert "window.location.search" not in source
    assert "window.location.href" not in source


def test_procedure_event_helper_strips_identity_and_record_values() -> None:
    source = (BASE_DIR / "static" / "analytics.js").read_text(encoding="utf-8")
    for forbidden_parameter in (
        "controller_id",
        "display_id",
        "container_id",
        "location_id",
        "location_code",
        "preview_uuid",
        "scene_uuid",
        "email",
        "identity",
        "qr_url",
        "name",
        "path",
        "url",
    ):
        assert f"delete safeParameters.{forbidden_parameter};" in source
