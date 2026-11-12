from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
ANALYTICS_VERSION = "2026-08-31.1"
MEASUREMENT_ID = "G-X08ZTSY0VV"


def test_fieldwiring_pages_load_versioned_analytics_asset() -> None:
    expected = f"static/analytics.js?v={ANALYTICS_VERSION}"
    for name in ("index.html", "controllers.html", "wiring.html"):
        source = (BASE_DIR / name).read_text(encoding="utf-8")
        assert expected in source


def test_analytics_uses_approved_internal_ga4_property() -> None:
    source = (BASE_DIR / "static" / "analytics.js").read_text(encoding="utf-8")
    assert MEASUREMENT_ID in source
    assert f"const analyticsVersion = '{ANALYTICS_VERSION}'" in source
    assert "allow_google_signals: false" in source
    assert "allow_ad_personalization_signals: false" in source


def test_analytics_page_view_never_sends_fieldwiring_query_string() -> None:
    source = (BASE_DIR / "static" / "analytics.js").read_text(encoding="utf-8")

    # FieldWiring query strings contain record-specific IDs/UUIDs. Page analytics
    # must use the sanitized pathname only.
    assert "const path = window.location.pathname" in source
    assert "page_location: window.location.origin + pagePath" in source
    assert "page_path: pagePath" in source
    assert "window.location.search" not in source
    assert "window.location.href" not in source


def test_bounded_event_helper_strips_record_and_identity_parameters() -> None:
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
    ):
        assert f"delete safeParameters.{forbidden_parameter};" in source
