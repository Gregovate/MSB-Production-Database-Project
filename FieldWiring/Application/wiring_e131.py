"""Reviewed temporary E1.31 physical-controller resolver for FieldWiring.

This is deliberately not a permanent controller-inventory substitute.  It
contains only operator-reviewed mappings already accepted in the FieldWiring
E1.31 presentation contract.  Universe values are used only inside those
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


def _apply_mega_star(row: dict[str, Any]) -> bool:
    if str(row.get("display_name") or "").strip() != "FT-MegaStar":
        return False
    try:
        universe = int(row.get("start_universe"))
    except (TypeError, ValueError):
        return False

    if 113 <= universe <= 128:
        row["controller_group"] = "Mega Star Controller 1"
        row["physical_output"] = universe - 112
        row["controller_model"] = "PixCon 16"
    elif 129 <= universe <= 140:
        row["controller_group"] = "Mega Star Controller 2"
        row["physical_output"] = universe - 128
        row["controller_model"] = "PixCon 16"
    else:
        return False

    row["controller_group_kind"] = "reviewed-temporary-e131-mapping"
    row["e131_mapping_basis"] = "accepted Mega Star universe/output map"
    row["pixel_count"] = rgb_pixel_count(row.get("start_channel"), row.get("end_channel"))
    return True


def apply_reviewed_e131_mapping(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Apply only explicit reviewed E1.31 mappings and preserve unresolved rows."""
    for row in rows:
        if str(row.get("presentation_family") or "").strip().upper() != "E131":
            continue
        row["pixel_count"] = rgb_pixel_count(row.get("start_channel"), row.get("end_channel"))
        if _apply_mega_star(row):
            continue
        # Keep the existing presentation fallback for unreviewed E1.31 cases.
        row["controller_group_kind"] = row.get("controller_group_kind") or "e131-display"
    return rows
