"""Accepted FieldWiring physical presentation rules.

This module translates current LOR/V7 topology into the already-reviewed field
presentation families.  It intentionally does not invent permanent controller
asset identities; Controller Inventory will replace temporary/reviewed grouping
labels when that subsystem is authoritative.
"""
from __future__ import annotations

import re
from collections import defaultdict
from typing import Any

from wiring_common import controller_sort, natural_key

PIXIE_SIZES = (2, 4, 8, 16)

# Operator-reviewed temporary physical grouping preserved from the pre-browser
# FieldWiring engineering work.  This is topology/presentation evidence only,
# not permanent Controller Inventory identity.
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


def presentation_family(row: dict[str, Any]) -> str:
    """Choose the reviewed field family from both DeviceType and StringType."""
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


def _pixie_model(output_count: int) -> str | None:
    return f"Pixie {output_count}" if output_count in PIXIE_SIZES else None


def _series_key(display_name: Any) -> str | None:
    """Return a conservative numbered-Display series key.

    This is used only for temporary repeated-address inference.  A rename that
    no longer forms a clean series fails safe to unresolved rather than
    fabricating a controller group.
    """
    name = str(display_name or "").strip()
    match = re.match(r"^(.*?)-(\d+)$", name)
    return match.group(1) if match else None


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


def _apply_candyland_lollipop_pattern(rows: list[dict[str, Any]], scene_name: str | None) -> None:
    """Restore the reviewed Candyland RGB Lollipop Pixie 16 context.

    The authoritative Preview uses one contiguous Aux C block 50-5B across
    eight RGB Displays.  Only Outputs 1-12 are currently used.
    """
    if (scene_name or "").strip().casefold() != "17-candyland-cl":
        return

    candidates = [r for r in rows if r.get("display_name") in _CANDYLAND_LOLLIPOP_UIDS]
    if not candidates:
        return

    by_display: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in candidates:
        by_display[str(row.get("display_name"))].append(row)

    # Fail safe unless every reviewed Display is present with exactly the
    # expected current LOR Unit-ID set.  Do not repair topology in FieldWiring.
    if set(by_display) != set(_CANDYLAND_LOLLIPOP_UIDS):
        return
    for display_name, expected in _CANDYLAND_LOLLIPOP_UIDS.items():
        actual = tuple(
            str(r.get("controller") or "").upper()
            for r in sorted(by_display[display_name], key=lambda r: controller_sort(r.get("controller")))
        )
        if actual != expected:
            for row in by_display[display_name]:
                row["controller_group_kind"] = "address-pattern-review"
            return
        if any((r.get("network") or "").strip().casefold() != "aux c" for r in by_display[display_name]):
            return

    base = 0x50
    for row in candidates:
        uid = _hex_int(row.get("controller"))
        if uid is None:
            continue
        _set_pixie_group(
            row,
            group="RGB Lollipops",
            output=(uid - base) + 1,
            model="Pixie 16",
            kind="reviewed-multi-display-pattern",
            uid_range="50-5B",
        )


def _apply_multirow_pixie_anchors(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Create reviewed-shape Pixie anchors from one Display spanning 2/4/8/16 UIDs."""
    by_display: dict[Any, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row.get("presentation_family") != "PIXIE" or row.get("controller_group"):
            continue
        key = row.get("display_id") if row.get("display_id") is not None else row.get("display_name")
        by_display[key].append(row)

    anchors: list[dict[str, Any]] = []
    for display_rows in by_display.values():
        uid_values = [_hex_int(r.get("controller")) for r in display_rows]
        if any(value is None for value in uid_values):
            continue
        unique_uids = sorted(set(value for value in uid_values if value is not None))
        count = len(unique_uids)
        model = _pixie_model(count)
        if not model or count != len(display_rows):
            continue
        if unique_uids != list(range(unique_uids[0], unique_uids[0] + count)):
            continue
        networks = {str(r.get("network") or "").strip().casefold() for r in display_rows}
        if len(networks) != 1:
            continue

        base = unique_uids[0]
        end = unique_uids[-1]
        group = str(display_rows[0].get("display_name") or "Pixie controller")
        uid_range = f"{_uid_text(base)}-{_uid_text(end)}"
        for row in display_rows:
            uid = _hex_int(row.get("controller"))
            assert uid is not None
            _set_pixie_group(
                row,
                group=group,
                output=(uid - base) + 1,
                model=model,
                kind="validated-display-pattern",
                uid_range=uid_range,
            )
        anchors.append(
            {
                "network": next(iter(networks)),
                "base": base,
                "end": end,
                "group": group,
                "model": model,
                "uid_range": uid_range,
            }
        )
    return anchors


def _attach_rows_to_unique_pixie_anchor(rows: list[dict[str, Any]], anchors: list[dict[str, Any]]) -> None:
    """Attach companion RGB rows that fall inside exactly one validated Pixie block.

    This preserves cases such as Who Forest Tree Stars and the Church Tree Star:
    their StartChannel can be 151/301 while the physical plug remains the
    output selected by the shared Unit ID.
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
            kind="validated-shared-controller-address",
            uid_range=anchor["uid_range"],
        )


def _apply_repeated_pixie_series(rows: list[dict[str, Any]]) -> None:
    """Derive temporary Pixie groups from clean repeated numbered-Display blocks.

    The detector operates per numbered Display series instead of across every
    one-row RGB Display in the Scene.  This is the key mixed-Scene recovery.
    Only complete blocks matching the first confirmed repeated block are
    grouped.  A later inconsistent block is left unresolved and flagged for
    review; FieldWiring never rewrites its Unit ID.
    """
    series: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row.get("presentation_family") != "PIXIE" or row.get("controller_group"):
            continue
        key = _series_key(row.get("display_name"))
        if not key:
            continue
        network = str(row.get("network") or "").strip().casefold()
        series[(network, key)].append(row)

    for series_rows in series.values():
        series_rows.sort(key=lambda r: natural_key(r.get("display_name")))
        sequence = [str(r.get("controller") or "").upper() for r in series_rows]
        if len(sequence) < 4:
            continue

        period: int | None = None
        for candidate in PIXIE_SIZES:
            if len(sequence) < candidate * 2:
                continue
            first = sequence[:candidate]
            second = sequence[candidate:candidate * 2]
            if len(set(first)) != candidate:
                continue
            if second == first:
                period = candidate
                break
        if period is None:
            continue

        expected = sequence[:period]
        model = f"Pixie {period}"
        group_number = 0
        for start in range(0, len(series_rows), period):
            block_rows = series_rows[start:start + period]
            block_values = sequence[start:start + period]
            if len(block_rows) != period:
                for row in block_rows:
                    row["controller_group_kind"] = "address-pattern-review"
                continue
            if block_values != expected:
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
    """Apply the already-reviewed physical-output rules without changing topology."""
    for row in rows:
        row["presentation_family"] = presentation_family(row)
        row["physical_output"] = None
        row["controller_group"] = None
        row["controller_group_kind"] = None
        row["controller_model"] = None
        row["controller_uid_range"] = None

    # Conventional A/C: one physical controller per Network + Unit ID;
    # StartChannel is the physical Output/Plug.  Multiple atomic Display rows
    # on that same Output remain separate rows for grouped presentation later.
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

    # Display-oriented families remain separate from physical Pixie inference.
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

    # Apply explicitly reviewed multi-Display physical contexts first.
    _apply_candyland_lollipop_pattern(pixie_rows, scene_name)

    # Then establish controller blocks directly proven by one Display spanning
    # a complete Pixie 2/4/8/16 address range.
    anchors = _apply_multirow_pixie_anchors(pixie_rows)

    # Companion rows sharing a Unit ID inside one unambiguous anchor belong to
    # that same physical output even when their StartChannel is 151/301.
    _attach_rows_to_unique_pixie_anchor(pixie_rows, anchors)

    # Finally infer operator-confirmed repeated-address controllers per Display
    # series, not across unrelated RGB Displays in the Scene.
    _apply_repeated_pixie_series(pixie_rows)

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
