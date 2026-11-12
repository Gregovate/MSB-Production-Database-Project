from __future__ import annotations

from wiring_dumbrgb import apply_dumbrgb_fixture_presentation
from wiring_presentation import apply_physical_presentation, group_rows


def source_row(source_id: str, label: str, universe: int, grid_row: int, channel: int) -> dict:
    return {
        "display_id": 1600,
        "display_name": "NL-NorthernLights",
        "channel_name": label,
        "network": "Regular",
        "controller": str(universe),
        "start_universe": universe,
        "start_channel": channel,
        "end_channel": channel,
        "device_type": "DMX",
        "string_type": "DumbRGB",
        "source": "DMX_SOURCE",
        "lor_tag": "",
        "connection_type": "FIELD",
        "cross_display": 0,
        "source_raw_prop_id": source_id,
        "channel_grid_row_number": grid_row,
    }


def test_cr50_three_source_rows_become_one_fixture_instruction_without_synthesizing_channels():
    rows = [
        source_row("fixture-1", "NL DS RGB 01", 145, 1, 1),
        source_row("fixture-1", "NL DS RGB 01", 145, 2, 2),
        source_row("fixture-1", "NL DS RGB 01", 145, 3, 3),
        source_row("fixture-2", "NL DS RGB 02", 145, 1, 6),
        source_row("fixture-2", "NL DS RGB 02", 145, 2, 7),
        source_row("fixture-2", "NL DS RGB 02", 145, 3, 8),
    ]

    presented = apply_physical_presentation(rows, scene_name="16-Northern Lights-NL")
    presented = apply_dumbrgb_fixture_presentation(presented)

    assert all(row["presentation_family"] == "DUMBRGB" for row in presented)
    assert len(presented) == 6  # atomic source rows remain intact
    assert {row["dmx_fixture_key"] for row in presented} == {"fixture-1", "fixture-2"}

    fixture1 = [row for row in presented if row["dmx_fixture_key"] == "fixture-1"]
    fixture2 = [row for row in presented if row["dmx_fixture_key"] == "fixture-2"]

    assert all(row["dmx_fixture_valid"] for row in presented)
    assert {row["dmx_fixture_start"] for row in fixture1} == {1}
    assert {row["dmx_rgb_channels"] for row in fixture1} == {"1-3"}
    assert {row["dmx_fixture_start"] for row in fixture2} == {6}
    assert {row["dmx_rgb_channels"] for row in fixture2} == {"6-8"}
    assert all(row["dmx_fixture_footprint"] == 5 for row in presented)

    # Intentional CR50 function-channel gaps remain absent; nothing creates 4-5.
    assert {row["start_channel"] for row in presented} == {1, 2, 3, 6, 7, 8}
    assert not any("pixel_count" in row for row in presented)


def test_cr50_groups_by_universe_as_addressing_context_not_physical_controller():
    rows = [
        source_row("ds-01", "NL DS RGB 01", 145, 1, 1),
        source_row("ds-01", "NL DS RGB 01", 145, 2, 2),
        source_row("ds-01", "NL DS RGB 01", 145, 3, 3),
        source_row("ps-01", "NL PS RGB 01", 146, 1, 1),
        source_row("ps-01", "NL PS RGB 01", 146, 2, 2),
        source_row("ps-01", "NL PS RGB 01", 146, 3, 3),
    ]

    presented = apply_dumbrgb_fixture_presentation(
        apply_physical_presentation(rows, scene_name="16-Northern Lights-NL")
    )
    groups = group_rows(presented)

    assert [group["name"] for group in groups] == ["Universe 145", "Universe 146"]
    assert all(group["family"] == "DUMBRGB" for group in groups)
    assert all(group["controller_model"] is None for group in groups)
    assert all(row["physical_output"] is None for row in presented)
    assert all(row["controller_group_kind"] == "dmx-cr50-universe-presentation" for row in presented)


def test_cr50_nonconsecutive_rgb_channels_are_preserved_as_actual_values():
    rows = [
        source_row("fixture-review", "NL TEST RGB", 145, 1, 11),
        source_row("fixture-review", "NL TEST RGB", 145, 2, 13),
        source_row("fixture-review", "NL TEST RGB", 145, 3, 14),
    ]

    presented = apply_dumbrgb_fixture_presentation(
        apply_physical_presentation(rows, scene_name="16-Northern Lights-NL")
    )

    assert {row["dmx_fixture_start"] for row in presented} == {11}
    assert {row["dmx_rgb_channels"] for row in presented} == {"11,13,14"}
    assert {row["start_channel"] for row in presented} == {11, 13, 14}
