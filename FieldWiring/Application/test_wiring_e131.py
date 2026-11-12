from __future__ import annotations

from wiring_e131 import apply_reviewed_e131_mapping, rgb_pixel_count


def _row(universe: int, start: int = 1, end: int = 450) -> dict:
    return {
        "display_name": "FT-MegaStar",
        "presentation_family": "E131",
        "start_universe": universe,
        "start_channel": start,
        "end_channel": end,
        "controller_group": "FT-MegaStar",
        "controller_group_kind": "e131-display",
        "controller_model": "E1.31 controller mapping pending",
    }


def test_rgb_pixel_count_uses_exact_span_and_requires_clean_rgb_division():
    assert rgb_pixel_count(1, 450) == 150
    assert rgb_pixel_count(1, 342) == 114
    assert rgb_pixel_count(10, 159) == 50
    assert rgb_pixel_count(1, 451) is None
    assert rgb_pixel_count(0, 450) is None


def test_mega_star_controller_one_mapping_is_explicit_and_output_aligned():
    rows = [_row(113), _row(128)]
    apply_reviewed_e131_mapping(rows)
    assert rows[0]["controller_group"] == "Mega Star Controller 1"
    assert rows[0]["physical_output"] == 1
    assert rows[1]["physical_output"] == 16
    assert all(row["controller_model"] == "PixCon 16" for row in rows)
    assert all(row["controller_group_kind"] == "reviewed-temporary-e131-mapping" for row in rows)


def test_mega_star_controller_two_mapping_is_explicit_and_output_aligned():
    rows = [_row(129), _row(140)]
    apply_reviewed_e131_mapping(rows)
    assert rows[0]["controller_group"] == "Mega Star Controller 2"
    assert rows[0]["physical_output"] == 1
    assert rows[1]["physical_output"] == 12


def test_mega_star_unreviewed_universe_stays_unresolved():
    row = _row(141)
    apply_reviewed_e131_mapping([row])
    assert row["controller_group"] == "FT-MegaStar"
    assert row.get("physical_output") is None
    assert row["controller_model"] == "E1.31 controller mapping pending"
    assert row["pixel_count"] == 150
