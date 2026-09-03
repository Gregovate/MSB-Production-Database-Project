from __future__ import annotations

from typing import Any

from controller_inventory import controller_list
from repository import PostgresRepository


class _FakeCursor:
    def __init__(self) -> None:
        self.executions: list[tuple[str, list[Any]]] = []
        self._step = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, sql: str, params: list[Any] | tuple[Any, ...] | None = None) -> None:
        self.executions.append((sql, list(params or [])))
        self._step += 1

    def fetchall(self):
        if self._step == 1:
            return [
                {
                    "controller_id": 1141,
                    "model_code": "Pixie4D",
                    "manufacturer": "Light-O-Rama",
                    "model_name": "Pixie4D Controller Board",
                    "device_family": "PIXIE",
                    "controller_status_name": "DEPLOYED",
                    "hardware_revision": None,
                    "serial_number": None,
                    "year_deployed": 2023,
                    "current_location_code": None,
                    "firmware_verification_state": "RECORDED_UNVERIFIED",
                    "installed_firmware": "1.12",
                    "verification_state": "ENGINEERING_ACCEPTED",
                    "label_required": True,
                    "print_label": False,
                    "assignment_count": 4,
                    "display_names": "CH-RGBCandyCane-01, CH-RGBCandyCane-02, CH-RGBCandyCane-03, CH-RGBCandyCane-04",
                    "stage_names": "15 · Church",
                }
            ]
        if self._step == 3:
            return [{"controller_status_name": "DEPLOYED"}]
        if self._step == 4:
            return [{"model_code": "Pixie4D", "model_name": "Pixie4D Controller Board"}]
        if self._step == 5:
            return [{"stage_id": 45, "stage_key": "15", "stage_name": "Church"}]
        raise AssertionError(f"Unexpected fetchall step {self._step}")

    def fetchone(self):
        if self._step == 2:
            return {
                "total": 177,
                "assigned": 176,
                "unassigned": 1,
                "firmware_pending": 177,
            }
        raise AssertionError(f"Unexpected fetchone step {self._step}")


class _FakeConnection:
    def __init__(self, cursor: _FakeCursor) -> None:
        self._cursor = cursor

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def cursor(self, **_: Any):
        return self._cursor


class _FakePostgresRepository(PostgresRepository):
    def __init__(self) -> None:
        self.fake_cursor = _FakeCursor()

    def connect(self):
        return _FakeConnection(self.fake_cursor)


def test_stage_filter_uses_current_display_relationship_not_controller_stage_column() -> None:
    repo = _FakePostgresRepository()

    payload = controller_list(repo, stage_id=45)

    first_sql, first_params = repo.fake_cursor.executions[0]
    assert "FROM ref.controller_display scd" in first_sql
    assert "JOIN ref.display sd" in first_sql
    assert "sd.stage_id = %s" in first_sql
    assert first_params == [45]
    assert "c.stage_id" not in first_sql

    assert payload["controllers"][0]["controller_id"] == 1141
    assert payload["controllers"][0]["assignment_count"] == 4
    assert payload["controllers"][0]["stage_names"] == "15 · Church"
    assert payload["stages"] == [
        {"stage_id": 45, "stage_key": "15", "stage_name": "Church"}
    ]


def test_text_search_includes_stage_key_and_stage_name() -> None:
    repo = _FakePostgresRepository()

    controller_list(repo, query="Church")

    first_sql, first_params = repo.fake_cursor.executions[0]
    assert "LEFT JOIN ref.stage qst" in first_sql
    assert "qst.stage_key" in first_sql
    assert "qst.stage_name" in first_sql
    # Controller text search now also covers LOR Network, management IP, and
    # programmed first UID in addition to the original Controller/Display/Stage fields.
    assert first_params == ["%Church%"] * 11
