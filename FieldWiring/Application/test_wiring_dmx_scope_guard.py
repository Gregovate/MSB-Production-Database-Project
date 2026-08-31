from __future__ import annotations

import wiring_dmx_source as dmx_source


def _legacy_dmx(display_id: int, name: str) -> dict[str, object]:
    return {
        "display_id": display_id,
        "display_name": name,
        "channel_name": "legacy",
        "network": "Regular",
        "controller": "145",
        "start_channel": 1,
        "end_channel": 3,
        "device_type": "DMX",
        "string_type": "DumbRGB",
        "source": "DMX",
        "lor_tag": "TEST",
        "connection_type": "FIELD",
        "cross_display": 0,
    }


def _source_dmx(display_id: int, name: str, row_number: int = 1) -> dict[str, object]:
    return {
        "display_id": display_id,
        "display_name": name,
        "channel_name": f"{name} RGB",
        "network": "Regular",
        "controller": "145",
        "start_universe": 145,
        "start_channel": 1,
        "end_channel": 3,
        "device_type": "DMX",
        "string_type": "DumbRGB",
        "source": "DMX_SOURCE",
        "lor_tag": "TEST",
        "connection_type": "FIELD",
        "cross_display": 0,
        "canonical_prop_id": f"prop-{display_id}",
        "canonical_raw_prop_id": f"raw-{display_id}",
        "source_raw_prop_id": f"source-{display_id}",
        "channel_grid_row_number": row_number,
    }


def test_context_without_dmx_never_acquires_preview_dmx(monkeypatch) -> None:
    non_dmx = {
        "display_id": 500,
        "display_name": "RA-Arch-01Wrap",
        "device_type": "LOR",
    }

    def should_not_load(*args, **kwargs):
        raise AssertionError("atomic DMX loader must not run when resolved context has no DMX")

    monkeypatch.setattr(dmx_source, "load_dmx_source_rows", should_not_load)

    rows = dmx_source.replace_legacy_dmx_rows(
        object(),
        [non_dmx],
        preview_uuid="master-preview",
        scene_uuid=None,
        scene_scope=False,
        parser_version="V7.0.11",
    )

    assert rows == [non_dmx]


def test_atomic_dmx_cannot_introduce_foreign_display_into_context(monkeypatch) -> None:
    in_scope = _legacy_dmx(956, "NL-Downspots")

    def preview_wide_source_rows(*args, **kwargs):
        return [
            _source_dmx(956, "NL-Downspots"),
            _source_dmx(869, "FT-MegaStar"),
            _source_dmx(1200, "WA-MegaCube"),
        ]

    monkeypatch.setattr(dmx_source, "load_dmx_source_rows", preview_wide_source_rows)

    rows = dmx_source.replace_legacy_dmx_rows(
        object(),
        [in_scope],
        preview_uuid="master-preview",
        scene_uuid=None,
        scene_scope=False,
        parser_version="V7.0.11",
    )

    assert {row["display_id"] for row in rows} == {956}
    assert rows[0]["source"] == "DMX_SOURCE"
