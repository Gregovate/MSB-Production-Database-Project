from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_readiness_api_is_read_only_and_reader_authorized() -> None:
    api = read("setup_material_readiness_api.py")
    repo = read("setup_material_readiness_repository.py")
    assert "/api/setup/material-readiness" in api
    assert "require_reader()" in api
    assert "require_manager()" not in api
    assert "write_connect" not in repo
    for forbidden in (
        "INSERT INTO ops.setup_movement_event",
        "UPDATE ops.setup_container_state",
        "UPDATE ops.setup_display_state",
        "DELETE FROM ops.setup_movement_event",
    ):
        assert forbidden not in repo


def test_readiness_consumes_current_authorities() -> None:
    repo = read("setup_material_readiness_repository.py")
    for token in (
        "ops.setup_work_day_task",
        "SetupNextRepository(self.dsn)",
        "field_context",
        "ref.setup_task_extra_material",
        "ref.setup_task_extra_material_source",
        "ops.setup_container_state",
        "ops.setup_display_state",
        "ops.setup_movement_event",
    ):
        assert token in repo


def test_readiness_preserves_detached_display_semantics() -> None:
    repo = read("setup_material_readiness_repository.py")
    assert 'position_mode == "DETACHED" or container_id is None' in repo
    assert 'key = ("DISPLAY", int(display["display_id"]))' in repo
    assert 'key = ("CONTAINER", int(container_id))' in repo


def test_readiness_keeps_unverified_or_unsourced_extra_material_visible() -> None:
    repo = read("setup_material_readiness_repository.py")
    assert "Required Extra Material has no active expected-source Container." in repo
    assert "Extra Material requirement is not VERIFIED for Pick List use." in repo


def test_projection_implements_d_minus_one_and_reason_preservation() -> None:
    projection = read("setup_material_readiness_projection.py")
    assert "timedelta(days=1)" in projection
    assert 'item["reasons"].append(reason)' in projection
    assert 'item["target_staged_by"]' in projection


def test_production_host_registers_material_readiness_blueprint() -> None:
    host = read("production_backend.py")
    assert "from setup_material_readiness_api import setup_material_readiness_api" in host
    assert "app.register_blueprint(setup_material_readiness_api)" in host
