"""DMX / DumbRGB fixture presentation metadata for FieldWiring.

The authoritative V7.0.11 DMX source rows remain atomic.  This module annotates
those rows so the browser can present one CR50 fixture instruction per source
PropClass without synthesizing the two intentionally omitted function channels.

Universe values remain DMX addressing context, never physical controller
identity.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Any


def _positive_int(value: Any) -> int | None:
    try:
        result = int(value)
    except (TypeError, ValueError):
        return None
    return result if result > 0 else None


def _compact_channels(channels: list[int]) -> str:
    if not channels:
        return ""
    if channels == list(range(channels[0], channels[0] + len(channels))):
        return str(channels[0]) if len(channels) == 1 else f"{channels[0]}-{channels[-1]}"
    return ",".join(str(channel) for channel in channels)


def apply_dumbrgb_fixture_presentation(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Annotate DumbRGB atomic rows with CR50 fixture-level presentation data.

    Within one resolved Preview package, ``source_raw_prop_id`` is the source
    fixture identity.  A normal CR50 fixture is represented by three one-channel
    rows with Channel Grid Row Numbers 1, 2, and 3.  The fixture occupies five
    DMX addresses physically, but FieldWiring never invents the omitted function
    channels 4-5 of each five-channel block.
    """
    fixture_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for row in rows:
        if str(row.get("presentation_family") or "").strip().upper() != "DUMBRGB":
            continue
        source_id = str(row.get("source_raw_prop_id") or "").strip()
        if source_id:
            fixture_rows[source_id].append(row)
        else:
            # Preserve an explicit review state if source identity is absent.
            row["dmx_fixture_key"] = None
            row["dmx_fixture_valid"] = False
            row["dmx_fixture_label"] = row.get("channel_name") or row.get("display_name")
            row["dmx_fixture_start"] = _positive_int(row.get("start_channel"))
            row["dmx_rgb_channels"] = ""
            row["controller_group"] = "DMX fixture review required"
            row["controller_group_kind"] = "dmx-fixture-review"
            row["controller_model"] = None
            row["physical_output"] = None

    for source_id, source_rows in fixture_rows.items():
        ordered = sorted(
            source_rows,
            key=lambda row: (
                _positive_int(row.get("channel_grid_row_number")) or 9999,
                _positive_int(row.get("start_channel")) or 9999,
            ),
        )
        grid_rows = [_positive_int(row.get("channel_grid_row_number")) for row in ordered]
        universes = {
            universe
            for universe in (_positive_int(row.get("start_universe")) for row in ordered)
            if universe is not None
        }
        channels = [_positive_int(row.get("start_channel")) for row in ordered]
        one_channel_rows = all(
            _positive_int(row.get("start_channel")) is not None
            and _positive_int(row.get("start_channel")) == _positive_int(row.get("end_channel"))
            for row in ordered
        )
        valid = (
            len(ordered) == 3
            and grid_rows == [1, 2, 3]
            and len(universes) == 1
            and all(channel is not None for channel in channels)
            and one_channel_rows
        )
        represented = [channel for channel in channels if channel is not None]
        universe = next(iter(universes)) if len(universes) == 1 else None
        labels = [str(row.get("channel_name") or "").strip() for row in ordered]
        label = next((value for value in labels if value), "") or str(ordered[0].get("display_name") or "")
        fixture_start = represented[0] if grid_rows and grid_rows[0] == 1 and represented else (min(represented) if represented else None)
        rgb_text = _compact_channels(represented)

        for row in ordered:
            row["dmx_fixture_key"] = source_id
            row["dmx_fixture_valid"] = valid
            row["dmx_fixture_label"] = label
            row["dmx_fixture_start"] = fixture_start
            row["dmx_rgb_channels"] = rgb_text
            row["dmx_fixture_footprint"] = 5
            row["controller_group"] = (
                f"DMX Universe {universe}" if universe is not None else "DMX fixture review required"
            )
            row["controller_group_kind"] = (
                "dmx-cr50-universe-presentation" if valid else "dmx-fixture-review"
            )
            row["controller_model"] = None
            row["physical_output"] = None

    return rows
