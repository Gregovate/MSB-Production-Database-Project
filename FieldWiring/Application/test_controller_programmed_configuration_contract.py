from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent


def test_controller_api_exposes_programmed_configuration_fields():
    source = (BASE_DIR / "controller_inventory.py").read_text(encoding="utf-8")

    for token in (
        "m.lor_uid_capacity",
        "c.lor_network",
        "c.lor_uid_start",
        "c.lor_uid_count",
        "c.lor_uid_end",
        "host(c.management_ip) AS management_ip",
        "c.programmed_config_verification_state",
    ):
        assert token in source

    # PostgreSQL has overloaded to_hex signatures; always cast explicitly.
    assert "to_hex(c.lor_uid_start::integer)" in source


def test_controller_browser_uses_operator_friendly_uid_presentation():
    source = (BASE_DIR / "controllers.js").read_text(encoding="utf-8")

    assert "function hexUid(value)" in source
    assert "UID Count" in source
    assert "UID Range" in source
    assert "First UID" in source
    assert "Programmed Config State" in source
    assert "Management IP" in source


def test_controller_browser_search_includes_programmed_configuration():
    source = (BASE_DIR / "controller_inventory.py").read_text(encoding="utf-8")

    assert "coalesce(c.lor_network, '') ILIKE %s" in source
    assert "coalesce(host(c.management_ip), '') ILIKE %s" in source
    assert "lpad(to_hex(c.lor_uid_start::integer), 2, '0')" in source
