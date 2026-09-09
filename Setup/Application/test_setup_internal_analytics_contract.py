from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
ANALYTICS_VERSION = "2026-09-07.1"
MEASUREMENT_ID = "G-X08ZTSY0VV"
VISIBLE_UPDATE = "Updated 2026-09-09"


def test_setup_page_loads_versioned_analytics_asset_and_visible_update() -> None:
    source = (BASE_DIR / "production.html").read_text(encoding="utf-8")
    assert f"setup_analytics.js?v={ANALYTICS_VERSION}" in source
    assert VISIBLE_UPDATE in source


def test_setup_analytics_asset_is_served() -> None:
    from production_backend import app

    app.config.update(TESTING=True)
    with app.test_client() as client:
        response = client.get("/setup_analytics.js")
    assert response.status_code == 200
    assert response.mimetype == "application/javascript"
    text = response.get_data(as_text=True)
    assert MEASUREMENT_ID in text


def test_setup_analytics_uses_approved_privacy_configuration() -> None:
    source = (BASE_DIR / "setup_analytics.js").read_text(encoding="utf-8")
    assert MEASUREMENT_ID in source
    assert f"const analyticsVersion = '{ANALYTICS_VERSION}'" in source
    assert "allow_google_signals: false" in source
    assert "allow_ad_personalization_signals: false" in source


def test_setup_page_view_never_sends_query_string_or_raw_url() -> None:
    source = (BASE_DIR / "setup_analytics.js").read_text(encoding="utf-8")
    assert "const path = window.location.pathname" in source
    assert "page_location: window.location.origin + pagePath" in source
    assert "page_path: pagePath" in source
    assert "window.location.search" not in source
    assert "window.location.href" not in source


def test_setup_event_helper_strips_identity_and_record_values() -> None:
    source = (BASE_DIR / "setup_analytics.js").read_text(encoding="utf-8")
    for forbidden_parameter in (
        "setup_session_id",
        "setup_session_task_id",
        "setup_task_id",
        "setup_resource_id",
        "setup_work_day_id",
        "display_id",
        "container_id",
        "location_id",
        "location_code",
        "stage_id",
        "stage_key",
        "scene_id",
        "preview_uuid",
        "scene_uuid",
        "email",
        "identity",
        "qr_url",
        "task_name",
        "name",
        "path",
        "url",
        "document_id",
    ):
        assert f"delete safeParameters.{forbidden_parameter};" in source
