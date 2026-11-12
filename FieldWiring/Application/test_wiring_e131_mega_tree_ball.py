from __future__ import annotations

from wiring_e131 import apply_reviewed_e131_mapping


def _row(display_name: str, universe: int, end_channel: int = 150) -> dict:
    return {
        "display_name": display_name,
        "presentation_family": "E131",
        "start_universe": universe,
        "start_channel": 1,
        "end_channel": end_channel,
        "controller_group": display_name,
        "controller_group_kind": "e131-display",
        "controller_model": "E1.31 controller mapping pending",
    }


def test_mega_tree_maps_48_universes_to_48_flex48_outputs():
    rows = [_row("TR-MegaTreeRGBTree", 1), _row("TR-MegaTreeRGBTree", 48)]
    apply_reviewed_e131_mapping(rows)

    assert [row["physical_output"] for row in rows] == [1, 48]
    assert all(row["controller_group"] == "Mega Tree Controller" for row in rows)
    assert all(row["controller_model"] == "AlphaPix / Flex48" for row in rows)
    assert all(row["controller_group_kind"] == "reviewed-temporary-e131-mapping" for row in rows)
    assert all(row["pixel_count"] == 50 for row in rows)


def test_mega_ball_maps_universes_49_through_64_to_pixcon16_outputs():
    rows = [_row("TR-MegaTreeRGBBall", 49), _row("TR-MegaTreeRGBBall", 64)]
    apply_reviewed_e131_mapping(rows)

    assert [row["physical_output"] for row in rows] == [1, 16]
    assert all(row["controller_group"] == "Mega Ball Controller" for row in rows)
    assert all(row["controller_model"] == "PixCon 16" for row in rows)
    assert all(row["controller_group_kind"] == "reviewed-temporary-e131-mapping" for row in rows)


def test_mega_tree_and_ball_outside_reviewed_universe_ranges_remain_unresolved():
    tree = _row("TR-MegaTreeRGBTree", 49)
    ball = _row("TR-MegaTreeRGBBall", 48)
    apply_reviewed_e131_mapping([tree, ball])

    assert tree.get("physical_output") is None
    assert ball.get("physical_output") is None
    assert tree["controller_model"] == "E1.31 controller mapping pending"
    assert ball["controller_model"] == "E1.31 controller mapping pending"
