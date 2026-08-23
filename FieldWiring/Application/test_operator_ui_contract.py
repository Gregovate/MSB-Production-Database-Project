from pathlib import Path

from backend import operator_config_error, operator_wiring_error
from repository import ConfigError
from wiring import WiringError


def test_config_error_hides_runtime_configuration_detail():
    internal = ConfigError(
        "Configure FIELDWIRING_DATABASE_DSN for PostgreSQL or FIELDWIRING_DEV_SNAPSHOT"
    )

    message = operator_config_error(internal)

    assert "FIELDWIRING_DATABASE_DSN" not in message
    assert "FIELDWIRING_DEV_SNAPSHOT" not in message
    assert "temporarily unavailable" in message


def test_invalid_link_error_is_actionable_not_parameter_oriented():
    message = operator_wiring_error(WiringError("Invalid stage_id"))

    assert message == (
        "This Field Wiring link is invalid. Return to lookup and select the Display or Stage again."
    )
    assert "stage_id" not in message


def test_dmx_engineering_failure_does_not_leak_parser_internals():
    internal = WiringError(
        "Current V7.0.11+ DMX source-detail rows are incomplete: display=1 source=blank"
    )

    message = operator_wiring_error(internal)

    assert "V7.0.11" not in message
    assert "source-detail" not in message
    assert "engineering" in message.lower()


def test_stale_context_error_tells_operator_to_reselect():
    message = operator_wiring_error(
        WiringError("Resolved Scene is not present in the current LOR snapshot")
    )

    assert "current approved data" in message
    assert "Return to lookup" in message
    assert "LOR snapshot" not in message


def test_browser_primary_warning_path_never_reads_raw_image_warnings():
    app_dir = Path(__file__).resolve().parent
    js = (app_dir / "wiring.js").read_text(encoding="utf-8")

    assert "packageData.images?.operator_warnings" in js
    assert "packageData.images.warnings?.length" not in js


def test_http_handlers_keep_engineering_detail_separate_from_operator_error():
    source = (Path(__file__).resolve().parent / "backend.py").read_text(encoding="utf-8")

    assert "error=operator_config_error(exc)" in source
    assert "error=operator_wiring_error(exc)" in source
    assert "engineering_error=str(exc)" in source
