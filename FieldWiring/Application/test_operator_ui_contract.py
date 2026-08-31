from pathlib import Path

import backend
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


def test_stage_api_uses_shared_fast_hierarchy(monkeypatch):
    class FakeRepository:
        def shared_stages(self):
            return [
                {
                    "stage": {
                        "stage_id": 51,
                        "stage_key": "21",
                        "stage_name": "Show Background Stage 21 Polar Bears",
                        "folder_path": (
                            r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB"
                        ),
                    },
                    "contexts": [],
                }
            ]

    monkeypatch.setattr(backend, "repository", lambda: FakeRepository())

    response = backend.app.test_client().get("/api/stages")
    payload = response.get_json()

    assert response.status_code == 200
    assert payload["review_required"] == []
    assert payload["stages"][0]["label"] == "21-Polar Bear Playground-PB"
    assert payload["stages"][0]["scope_type"] == "STAGE"


def test_fieldwiring_browser_consumes_shared_hierarchy_shape():
    source = (Path(__file__).resolve().parent / "fieldwiring.js").read_text(encoding="utf-8")

    assert "stage.sub_stages || []" in source
    assert "node.scenes || []" in source
    assert "item.node.label" in source
    assert "stage.stage_name" not in source


def test_wiring_detail_links_back_to_controller_inventory():
    source = (Path(__file__).resolve().parent / "wiring.html").read_text(encoding="utf-8")

    assert 'href="controllers"' in source
    assert ">Controller Inventory</a>" in source
