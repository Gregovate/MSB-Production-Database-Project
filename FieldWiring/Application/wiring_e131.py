"""Reviewed temporary E1.31 physical-controller resolver for FieldWiring.

This is deliberately not a permanent controller-inventory substitute. It
contains only operator-reviewed mappings already accepted in the FieldWiring
E1.31 presentation contract. Universe values are used only inside those
explicit mappings; they are never treated as permanent controller identity.
"""
from __future__ import annotations

from typing import Any


def rgb_pixel_count(start_channel: Any, end_channel: Any) -> int | None:
    """Derive RGB pixel count only from a valid clean three-channel span."""
    try:
        start = int(start_channel)
        end = int(end_channel)
    except (TypeError, ValueError):
        return None
    if start <= 0 or end < start:
        return None
    channel_count = end - start + 1
    if channel_count % 3:
        return None
    return channel_count // 3


def _universe(row: dict[str, Any]) -> int | None:
    try:
        return int(row.get("start_universe"))
    except (TypeError, ValueError):
        return None


def _set_reviewed_mapping(
    row: dict[str, Any],
    *,
    group: str,
    output: int,
    model: str,
    basis: str,
) -> None:
    row["controller_group"] = group
    row["physical_output"] = output
    row["controller_model"] = model
    row["controller_group_kind"] = "reviewed-temporary-e131-mapping"
    row["e131_mapping_basis"] = basis
    row["pixel_count"] = rgb_pixel_count(row.get("start_channel"), row.get("end_channel"))


def _apply_mega_tree(row: dict[str, Any]) -> bool:
    if str(row.get("display_name") or "").strip() != "TR-MegaTreeRGBTree":
        return False
    universe = _universe(row)
    if universe is None or not 1 <= universe <= 48:
        return False
    _set_reviewed_mapping(
        row,
        group="Mega Tree Controller",
        output=universe,
        model="AlphaPix / Flex48",
        basis="accepted Mega Tree 48-output universe/output map",
    )
    return True


def _apply_mega_ball(row: dict[str, Any]) -> bool:
    if str(row.get("display_name") or "").strip() != "TR-MegaTreeRGBBall":
        return False
    universe = _universe(row)
    if universe is None or not 49 <= universe <= 64:
        return False
    _set_reviewed_mapping(
        row,
        group="Mega Ball Controller",
        output=universe - 48,
        model="PixCon 16",
        basis="accepted Mega Ball 16-output universe/output map",
    )
    return True


def _apply_mega_star(row: dict[str, Any]) -> bool:
    if str(row.get("display_name") or "").strip() != "FT-MegaStar":
        return False
    universe = _universe(row)
    if universe is None:
        return False

    if 113 <= universe <= 128:
        group = "Mega Star Controller 1"
        output = universe - 112
    elif 129 <= universe <= 140:
        group = "Mega Star Controller 2"
        output = universe - 128
    else:
        return False

    _set_reviewed_mapping(
        row,
        group=group,
        output=output,
        model="PixCon 16",
        basis="accepted Mega Star universe/output map",
    )
    return True


def apply_reviewed_e131_mapping(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Apply only explicit reviewed E1.31 mappings and preserve unresolved rows."""
    for row in rows:
        if str(row.get("presentation_family") or "").strip().upper() != "E131":
            continue
        row["pixel_count"] = rgb_pixel_count(row.get("start_channel"), row.get("end_channel"))
        if _apply_mega_tree(row):
            continue
        if _apply_mega_ball(row):
            continue
        if _apply_mega_star(row):
            continue
        # Keep the existing presentation fallback for unreviewed E1.31 cases.
        row["controller_group_kind"] = row.get("controller_group_kind") or "e131-display"
    return rows
