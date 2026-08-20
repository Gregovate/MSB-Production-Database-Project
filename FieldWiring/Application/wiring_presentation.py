"""Accepted FieldWiring physical presentation rules.

This module translates current LOR/V7 topology into the already-reviewed field
presentation families. It intentionally does not invent permanent controller
asset identities; Controller Inventory will replace temporary/reviewed grouping
labels when that subsystem is authoritative.
"""
from __future__ import annotations

import re
from collections import defaultdict
from typing import Any

from wiring_common import controller_sort, natural_key

_CANDYLAND_LOLLIPOP_UIDS: dict[str, tuple[str, ...]] = {
    "CL-Lollipop-Small-01": ("50",),
    "CL-Lollipop-Large-02": ("51", "52"),
    "CL-Lollipop-Large-03": ("53", "54"),
    "CL-Lollipop-Large-04": ("55", "56"),
    "CL-Lollipop-Small-05": ("57",),
    "CL-Lollipop-Large-06": ("58", "59"),
    "CL-Lollipop-Small-07": ("5A",),
    "CL-Lollipop-Small-08": ("5B",),
}

_ACCEPTED_REPEATED_SERIES: dict[str, int] = {
    "CH-RGBCandyCane": 4,
    "CL-RGBCandyCane": 4,
}


def presentation_family(row: dict[str, Any]) -> str:
    device = (row.get("device_type") or "").strip().casefold()
    string_type = (row.get("string_type") or "").strip().casefold()
    if device == "lor" and string_type == "traditional":
        return "AC"
    if device == "lor" and string_type == "rgb":
        return "PIXIE"
    if device == "dmx" and string_type == "dumbrgb":
        return "DUMBRGB"
    if device == "dmx" and string_type == "rgb":
        return "E131"
    if device == "dmx":
        return "DMX"
    if string_type == "dumbrgb":
        return "DUMBRGB"
    return "OTHER"


def _hex_int(value: Any) -> int | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return int(text, 16)
    except ValueError:
        return None


def _uid_text(value: int) -> str:
    return f"{value:X}"


def _series_key(display_name: Any) -> str | None:
    name = str(display_name or "").strip()
    match = re.match(r"^(.*?)-(\d+)$", name)
    return match.group(1) if match else None


def _accepted_anchor_size(display_name: Any) -> int | None:
    name = str(display_name or "").strip()
    if name == "CH-RGBTree-16x100-180":
        return 16
    if name in {"CH-RGBCross-LH", "CH-RGBCross-RH"}:
        return 2
    if re.fullmatch(r"WF-Tree-\d{2}", name):
        return 8
    if name in {"SW-TreeRGB-LH", "SW-TreeRGB-RH"}:
        return 8
    return None


def _set_pixie_group(
    row: dict[str, Any],
    *,
    group: str,
    output: int,
    model: str,
    kind: str,
    uid_range: str | None = None,
) -> None:
    row["physical_output"] = output
    row["controller_group"] = group
    row["controller_group_kind"] = kind
    row["controller_model"] = model
    row["controller_uid_range"] = uid_range


def _apply_church_star_context(rows: list[dict[str, Any]], scene_name: str | None) -> None:
    """Keep the Church RGB Tree Star as its own known Pixie context.

    Operator inspection of the LOR Prop Definition establishes:
      - Display/comment: CH-RGBTree-Star
      - Network: Aux N
      - LOR address span: 40-41
      - Separate Unit ID for each RGB string: unchecked

    That proves a controller context separate from the Church Tree Pixie 16 at
    30-3F. It does not by itself prove a Pixie model or physical output count,
    so those fields intentionally remain unresolved.
    """
    if (scene_name or "").strip().casefold() != "15-church-ch":
        return

    candidates = [r for r in rows if r.get("display_name") == "CH-RGBTree-Star"]
    if not candidates:
        return

    valid = all(
        (r.get("network") or "").strip().casefold() == "aux n"
        and str(r.get("controller") or "").strip().upper() in {"40", "41"}
        for r in candidates
    )
    if not valid:
        for row in candidates:
            row["controller_group_kind"] = "address-pattern-review"
        return

    for row in candidates:
        row["physical_output"] = None
        row["controller_group"] = "CH-RGBTree-Star"
        row["controller_group_kind"] = "reviewed-separate-controller-context"
        row["controller_model"] = "Pixie controller"
        row["controller_uid_range"] = "40-41"


def _apply_candyland_lollipop_pattern(rows: list[dict[str, Any]], scene_name: str | None) -> None:
    if (scene_name or "").strip().casefold() != "17-candyland-cl":
        return

    candidates = [r for r in rows if r.get("display_name") in _CANDYLAND_LOLLIPOP_UIDS]
    if not candidates:
        return

    by_display: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in candidates:
        by_display[str(row.get("display_name"))].append(row)

    if set(by_display) != set(_CANDYLAND_LOLLIPOP_UIDS):
        for row in candidates:
            row["controller_group_kind"] = "address-pattern-review"
        return

    for display_name, expected in _CANDYLAND_LOLLIPOP_UIDS.items():
        actual = tuple(
            str(r.get("controller") or "").upper()
            for r in sorted(by_display[display_name], key=lambda r: controller_sort(r.get("controller")))
        )
        if actual != expected or any(
            (r.get("network") or "").strip().casefold() != "aux c"
            for r in by_display[display_name]
        ):
            for row in candidates:
                row["controller_group_kind"] = "address-pattern-review"
            return

    base = 0x50
    for row in candidates:
        uid = _hex_int(row.get("controller"))
        if uid is not None:
            _set_pixie_group(
                row,
                group="RGB Lollipops",
                output=(uid - base) + 1,
                model="Pixie 16",
                kind="reviewed-multi-display-pattern",
                uid_range="50-5B",
            )


def _apply_reviewed_pixie_anchors(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_display: dict[Any, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row.get("presentation_family") != "PIXIE" or row.get("controller_group"):
            continue
        key = row.get("display_id") if row.get("display_id") is not None else row.get("display_name")
        by_display[key].append(row)

    anchors: list[dict[str, Any]] = []
    for display_rows in by_display.values():
        display_name = display_rows[0].get("display_name")
        expected_count = _accepted_anchor_size(display_name)
        if expected_count is None:
            continue

        uid_values = [_hex_int(r.get("controller")) for r in display_rows]
        if any(value is None for value in uid_values):
            continue
        unique_uids = sorted(set(value for value in uid_values if value is not None))
        if len(display_rows) != expected_count or len(unique_uids) != expected_count:
            continue
        if unique_uids != list(range(unique_uids[0], unique_uids[0] + expected_count)):
            continue
        networks = {str(r.get("network") or "").strip().casefold() for r in display_rows}
        if len(networks) != 1:
            continue

        base = unique_uids[0]
        end = unique_uids[-1]
        group = str(display_name or "Pixie controller")
        model = f"Pixie {expected_count}"
        uid_range = f"{_uid_text(base)}-{_uid_text(end)}"
        for row in display_rows:
            uid = _hex_int(row.get("controller"))
            assert uid is not None
            _set_pixie_group(
                row,
                group=group,
                output=(uid - base) + 1,
                model=model,
                kind="reviewed-display-pattern",
                uid_range=uid_range,
            )
        anchors.append({
            "network": next(iter(networks)),
            "base": base,
            "end": end,
            "group": group,
            "model": model,
            "uid_range": uid_range,
        })
    return anchors


def _attach_rows_to_unique_pixie_anchor(rows: list[dict[str, Any]], anchors: list[dict[str, Any]]) -> None:
    """Attach companion RGB rows inside exactly one reviewed Pixie block.

    This is used for reviewed shared-controller cases such as Who Forest Tree
    Stars. Church CH-RGBTree-Star is explicitly handled as its own controller
    context before this step and must never be attached to the Tree Pixie 16.
    """
    for row in rows:
        if row.get("presentation_family") != "PIXIE" or row.get("controller_group"):
            continue
        uid = _hex_int(row.get("controller"))
        network = str(row.get("network") or "").strip().casefold()
        if uid is None:
            continue
        matches = [a for a in anchors if a["network"] == network and a["base"] <= uid <= a["end"]]
        if len(matches) != 1:
            continue
        anchor = matches[0]
        _set_pixie_group(
            row,
            group=anchor["group"],
            output=(uid - anchor["base"]) + 1,
            model=anchor["model"],
            kind="reviewed-shared-controller-address",
            uid_range=anchor["uid_range"],
        )


def _apply_reviewed_repeated_pixie_series(rows: list[dict[str, Any]]) -> None:
    series: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row.get("presentation_family") != "PIXIE" or row.get("controller_group"):
            continue
        key = _series_key(row.get("display_name"))
        if key not in _ACCEPTED_REPEATED_SERIES:
            continue
        network = str(row.get("network") or "").strip().casefold()
        series[(network, key)].append(row)

    for (_, key), series_rows in series.items():
        period = _ACCEPTED_REPEATED_SERIES[key]
        series_rows.sort(key=lambda r: natural_key(r.get("display_name")))
        sequence = [str(r.get("controller") or "").upper() for r in series_rows]
        if len(sequence) < period * 2:
            for row in series_rows:
                row["controller_group_kind"] = "address-pattern-review"
            continue

        expected = sequence[:period]
        if len(set(expected)) != period or sequence[period:period * 2] != expected:
            for row in series_rows:
                row["controller_group_kind"] = "address-pattern-review"
            continue

        model = f"Pixie {period}"
        group_number = 0
        for start in range(0, len(series_rows), period):
            block_rows = series_rows[start:start + period]
            block_values = sequence[start:start + period]
            if len(block_rows) != period or block_values != expected:
                for row in block_rows:
                    row["controller_group_kind"] = "address-pattern-review"
                continue
            group_number += 1
            group = f"Pixie group {group_number}"
            uid_range = f"{expected[0]}-{expected[-1]}"
            for output, row in enumerate(block_rows, 1):
                _set_pixie_group(
                    row,
                    group=group,
                    output=output,
                    model=model,
                    kind="temporary-repeated-address-pattern",
                    uid_range=uid_range,
                )


def apply_physical_presentation(
    rows: list[dict[str, Any]],
    *,
    scene_name: str | None = None,
) -> list[dict[str, Any]]:
    for row in rows:
        row["presentation_family"] = presentation_family(row)
        row["physical_output"] = None
        row["controller_group"] = None
        row["controller_group_kind"] = None
        row["controller_model"] = None
        row["controller_uid_range"] = None

    ac_groups: dict[tuple[str, str], int] = {}
    for row in rows:
        if row["presentation_family"] != "AC":
            continue
        key = (str(row.get("network") or ""), str(row.get("controller") or ""))
        if key not in ac_groups:
            ac_groups[key] = len(ac_groups) + 1
        row["physical_output"] = row.get("start_channel")
        row["controller_group"] = f"A/C controller group {ac_groups[key]}"
        row["controller_group_kind"] = "lor-ac-addressed-controller"
        row["controller_model"] = "A/C controller"
        row["controller_uid_range"] = str(row.get("controller") or "") or None

    for row in rows:
        family = row["presentation_family"]
        if family == "DUMBRGB":
            row["controller_group"] = row.get("display_name") or "DMX / DumbRGB fixture"
            row["controller_group_kind"] = "dmx-fixture"
        elif family == "E131":
            row["controller_group"] = row.get("display_name") or "E1.31 Display"
            row["controller_group_kind"] = "e131-display"
            row["controller_model"] = "E1.31 controller mapping pending"

    pixie_rows = [r for r in rows if r["presentation_family"] == "PIXIE"]

    _apply_church_star_context(pixie_rows, scene_name)
    _apply_candyland_lollipop_pattern(pixie_rows, scene_name)
    anchors = _apply_reviewed_pixie_anchors(pixie_rows)
    _attach_rows_to_unique_pixie_anchor(pixie_rows, anchors)
    _apply_reviewed_repeated_pixie_series(pixie_rows)

    return rows


def group_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    order: list[tuple[str, str]] = []
    for row in rows:
        family = row.get("presentation_family") or "OTHER"
        group = row.get("controller_group")
        if not group:
            if family == "PIXIE":
                group = "Pixie grouping review required"
            elif family == "DMX":
                group = f"DMX · Universe {row.get('controller') or '—'}"
            elif family == "DUMBRGB":
                group = row.get("display_name") or "DMX / DumbRGB hookup"
            elif family == "E131":
                group = row.get("display_name") or "E1.31 hookup"
            else:
                group = "Other hookup"
        key = (family, str(group))
        if key not in grouped:
            order.append(key)
        grouped[key].append(row)

    family_order = {"AC": 0, "PIXIE": 1, "DUMBRGB": 2, "E131": 3, "DMX": 4, "OTHER": 5}
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
        models = {r.get("controller_model") for r in items if r.get("controller_model")}
        ranges = {r.get("controller_uid_range") for r in items if r.get("controller_uid_range")}
        result.append({
            "family": family,
            "name": name,
            "controller_model": next(iter(models)) if len(models) == 1 else None,
            "controller_uid_range": next(iter(ranges)) if len(ranges) == 1 else None,
            "rows": items,
        })
    return result
