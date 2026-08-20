"""Accepted FieldWiring physical presentation rules."""
from __future__ import annotations

from collections import defaultdict
from typing import Any

from wiring_common import controller_sort, natural_key


def presentation_family(row: dict[str, Any]) -> str:
    device = (row.get("device_type") or "").casefold()
    string_type = (row.get("string_type") or "").casefold()
    if device == "lor" and string_type == "traditional":
        return "AC"
    if device == "lor" and string_type == "rgb":
        return "PIXIE"
    if device == "dmx":
        return "DMX"
    if string_type == "dumbrgb":
        return "DUMBRGB"
    return "OTHER"


def apply_physical_presentation(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Apply only already-reviewed physical-output rules.

    Traditional LOR uses StartChannel as Output. RGB multi-row Displays use
    ordered logical rows as Outputs 1..N. Separate one-row RGB Displays are
    grouped only when a clean repeated address block is actually present.
    """
    for row in rows:
        row["presentation_family"] = presentation_family(row)
        row["physical_output"] = None
        row["controller_group"] = None
        row["controller_group_kind"] = None

    ac_groups: dict[tuple[str, str], int] = {}
    for row in rows:
        if row["presentation_family"] != "AC":
            continue
        key = (str(row.get("network") or ""), str(row.get("controller") or ""))
        if key not in ac_groups:
            ac_groups[key] = len(ac_groups) + 1
        row["physical_output"] = row.get("start_channel")
        row["controller_group"] = f"A/C controller group {ac_groups[key]}"
        row["controller_group_kind"] = "temporary"

    rgb_by_display: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row["presentation_family"] == "PIXIE" and row.get("display_id") is not None:
            rgb_by_display[int(row["display_id"])].append(row)

    one_row_rgb: list[dict[str, Any]] = []
    for display_id, display_rows in rgb_by_display.items():
        display_rows.sort(key=lambda r: (controller_sort(r.get("controller")), r.get("start_channel") or 0))
        if len(display_rows) > 1:
            for index, row in enumerate(display_rows, 1):
                row["physical_output"] = index
                row["controller_group"] = row.get("display_name") or f"Display {display_id}"
                row["controller_group_kind"] = "validated-display-pattern"
        else:
            one_row_rgb.extend(display_rows)

    one_row_rgb.sort(key=lambda r: natural_key(r.get("display_name")))
    sequence = [str(r.get("controller") or "") for r in one_row_rgb]
    period: int | None = None
    if len(sequence) >= 4:
        for candidate in range(2, (len(sequence) // 2) + 1):
            first = sequence[:candidate]
            if len(set(first)) != candidate:
                continue
            repeats = len(sequence) // candidate
            if repeats < 2 or len(sequence) % candidate:
                continue
            if all(sequence[g*candidate:(g+1)*candidate] == first for g in range(repeats)):
                period = candidate
                break
    if period:
        for index, row in enumerate(one_row_rgb):
            row["physical_output"] = (index % period) + 1
            row["controller_group"] = f"Pixie group {(index // period) + 1}"
            row["controller_group_kind"] = "temporary-repeated-address-pattern"

    return rows


def group_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    order: list[tuple[str, str]] = []
    for row in rows:
        family = row.get("presentation_family") or "OTHER"
        group = row.get("controller_group")
        if not group:
            if family == "DMX":
                group = f"DMX · Universe {row.get('controller') or '—'}"
            elif family == "DUMBRGB":
                group = "DumbRGB hookup"
            else:
                group = "Other hookup"
        key = (family, str(group))
        if key not in grouped:
            order.append(key)
        grouped[key].append(row)

    family_order = {"AC": 0, "PIXIE": 1, "DMX": 2, "DUMBRGB": 3, "OTHER": 4}
    order.sort(key=lambda key: (family_order.get(key[0], 99), natural_key(key[1])))
    result: list[dict[str, Any]] = []
    for family, name in order:
        items = grouped[(family, name)]
        items.sort(key=lambda r: (
            r.get("physical_output") if r.get("physical_output") is not None else 9999,
            controller_sort(r.get("controller")),
            r.get("start_channel") or 0,
            natural_key(r.get("display_name")),
        ))
        result.append({"family": family, "name": name, "rows": items})
    return result
