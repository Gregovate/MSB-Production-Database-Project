from __future__ import annotations

from wiring_presentation import apply_physical_presentation, group_rows, presentation_family


def row(
    display_id: int,
    display_name: str,
    controller: str,
    *,
    network: str = "Aux N",
    start_channel: int = 1,
    end_channel: int | None = None,
    device_type: str = "LOR",
    string_type: str = "RGB",
    channel_name: str | None = None,
) -> dict:
    return {
        "display_id": display_id,
        "display_name": display_name,
        "channel_name": channel_name or display_name,
        "network": network,
        "controller": controller,
        "start_channel": start_channel,
        "end_channel": end_channel if end_channel is not None else start_channel,
        "device_type": device_type,
        "string_type": string_type,
        "source": "PROP",
        "lor_tag": "",
        "connection_type": "FIELD",
        "cross_display": 0,
    }


def lor_rgb_rows(display_id: int, name: str, uids: list[str], network: str = "Aux N") -> list[dict]:
    return [row(display_id, name, uid, network=network) for uid in uids]


def test_presentation_family_uses_device_and_string_type_together():
    assert presentation_family(row(1, "AC", "01", device_type="LOR", string_type="Traditional")) == "AC"
    assert presentation_family(row(2, "Pixie", "30", device_type="LOR", string_type="RGB")) == "PIXIE"
    assert presentation_family(row(3, "Northern Lights", "145", device_type="DMX", string_type="DumbRGB")) == "DUMBRGB"
    assert presentation_family(row(4, "Mega Tree", "1", device_type="DMX", string_type="RGB")) == "E131"


def test_unreviewed_contiguous_rgb_block_fails_safe_instead_of_inventing_pixie():
    rows = lor_rgb_rows(50, "XX-Unreviewed-RGB", ["10", "11", "12", "13"])
    presented = apply_physical_presentation(rows, scene_name="99-Unreviewed-XX")

    assert all(r["presentation_family"] == "PIXIE" for r in presented)
    assert all(r["controller_group"] is None for r in presented)
    assert all(r["physical_output"] is None for r in presented)
    assert all(r["controller_model"] is None for r in presented)
    groups = group_rows(presented)
    assert len(groups) == 1
    assert groups[0]["name"] == "Pixie grouping review required"


def test_church_mixed_scene_preserves_separate_star_pixie16_pixie2_and_two_pixie4_groups():
    rows: list[dict] = []

    tree = lor_rgb_rows(100, "CH-RGBTree-16x100-180", [f"{uid:X}" for uid in range(0x30, 0x40)])
    rows.extend(tree)
    rows.append(row(
        101,
        "CH-RGBTree-Star",
        "40",
        network="Aux N",
        start_channel=1,
        end_channel=240,
        channel_name="CH RGB Star Nested",
    ))

    rows.extend(lor_rgb_rows(110, "CH-RGBCross-LH", ["42", "43"]))
    rows.extend(lor_rgb_rows(111, "CH-RGBCross-RH", ["44", "45"]))

    for index, uid in enumerate(["21", "22", "23", "24", "21", "22", "23", "24"], 1):
        rows.append(row(200 + index, f"CH-RGBCandyCane-{index:02d}", uid))

    rows.append(row(300, "CH-BridgeBell-01", "49", start_channel=1, device_type="LOR", string_type="Traditional", network="Aux N"))

    presented = apply_physical_presentation(rows, scene_name="15-Church-CH")

    tree_rows = [r for r in presented if r["display_name"] == "CH-RGBTree-16x100-180"]
    assert [r["physical_output"] for r in tree_rows] == list(range(1, 17))
    assert len({r["controller_group"] for r in tree_rows}) == 1
    assert all(r["controller_model"] == "Pixie 16" for r in tree_rows)

    star = next(r for r in presented if r["display_name"] == "CH-RGBTree-Star")
    assert star["controller_group"] == "CH-RGBTree-Star"
    assert star["controller_group"] != tree_rows[0]["controller_group"]
    assert star["controller_group_kind"] == "reviewed-separate-controller-context"
    assert star["controller_model"] == "Pixie controller"
    assert star["controller_uid_range"] == "40-41"
    assert star["physical_output"] is None

    for cross_name in ("CH-RGBCross-LH", "CH-RGBCross-RH"):
        cross_rows = [r for r in presented if r["display_name"] == cross_name]
        assert [r["physical_output"] for r in cross_rows] == [1, 2]
        assert len({r["controller_group"] for r in cross_rows}) == 1
        assert all(r["controller_model"] == "Pixie 2" for r in cross_rows)

    candy = [r for r in presented if r["display_name"].startswith("CH-RGBCandyCane-")]
    groups = group_rows(candy)
    assert [g["name"] for g in groups] == ["Pixie group 1", "Pixie group 2"]
    assert [[r["physical_output"] for r in g["rows"]] for g in groups] == [[1, 2, 3, 4], [1, 2, 3, 4]]
    assert all(g["controller_model"] == "Pixie 4" for g in groups)

    church_pixie_groups = [g for g in group_rows(presented) if g["family"] == "PIXIE"]
    assert any(g["name"] == "CH-RGBTree-Star" for g in church_pixie_groups)
    assert not any(g["name"] == "Pixie grouping review required" for g in church_pixie_groups)


def test_candyland_mixed_scene_has_one_pixie16_lollipop_context_and_three_pixie4_candy_cane_groups():
    rows: list[dict] = []

    lollipop_map = [
        (401, "CL-Lollipop-Small-01", ["50"]),
        (402, "CL-Lollipop-Large-02", ["51", "52"]),
        (403, "CL-Lollipop-Large-03", ["53", "54"]),
        (404, "CL-Lollipop-Large-04", ["55", "56"]),
        (405, "CL-Lollipop-Small-05", ["57"]),
        (406, "CL-Lollipop-Large-06", ["58", "59"]),
        (407, "CL-Lollipop-Small-07", ["5A"]),
        (408, "CL-Lollipop-Small-08", ["5B"]),
    ]
    for display_id, name, uids in lollipop_map:
        rows.extend(lor_rgb_rows(display_id, name, uids, network="Aux C"))

    candy_uids = ["21", "22", "23", "24"] * 3
    for index, uid in enumerate(candy_uids, 1):
        rows.append(row(500 + index, f"CL-RGBCandyCane-{index:02d}", uid, network="Aux C"))

    rows.append(row(600, "CL-LollipopStick-01", "62", network="Aux C", start_channel=1, device_type="LOR", string_type="Traditional"))

    presented = apply_physical_presentation(rows, scene_name="17-Candyland-CL")

    lollipops = [r for r in presented if r["display_name"].startswith("CL-Lollipop-")]
    assert len({r["controller_group"] for r in lollipops}) == 1
    assert [r["physical_output"] for r in lollipops] == list(range(1, 13))
    assert all(r["controller_model"] == "Pixie 16" for r in lollipops)

    candy = [r for r in presented if r["display_name"].startswith("CL-RGBCandyCane-")]
    groups = group_rows(candy)
    assert [g["name"] for g in groups] == ["Pixie group 1", "Pixie group 2", "Pixie group 3"]
    assert [[r["physical_output"] for r in g["rows"]] for g in groups] == [
        [1, 2, 3, 4],
        [1, 2, 3, 4],
        [1, 2, 3, 4],
    ]
    assert all(g["controller_model"] == "Pixie 4" for g in groups)

    stick = next(r for r in presented if r["display_name"] == "CL-LollipopStick-01")
    assert stick["presentation_family"] == "AC"


def test_candyland_stale_third_candy_cane_block_preserves_group_and_snapshot_outputs():
    rows: list[dict] = []
    stale = ["21", "22", "23", "24", "21", "22", "23", "24", "21", "22", "23", "22"]
    for index, uid in enumerate(stale, 1):
        rows.append(row(700 + index, f"CL-RGBCandyCane-{index:02d}", uid, network="Aux C"))

    presented = apply_physical_presentation(rows, scene_name="17-Candyland-CL")
    groups = group_rows(presented)

    assert [g["name"] for g in groups] == ["Pixie group 1", "Pixie group 2", "Pixie group 3"]
    assert [[r["physical_output"] for r in g["rows"]] for g in groups[:2]] == [
        [1, 2, 3, 4],
        [1, 2, 3, 4],
    ]

    third = groups[2]["rows"]
    by_name = {r["display_name"]: r for r in third}
    assert {name: r["physical_output"] for name, r in by_name.items()} == {
        "CL-RGBCandyCane-09": 1,
        "CL-RGBCandyCane-10": 2,
        "CL-RGBCandyCane-11": 3,
        "CL-RGBCandyCane-12": 2,
    }
    assert {name: r["controller"] for name, r in by_name.items()} == {
        "CL-RGBCandyCane-09": "21",
        "CL-RGBCandyCane-10": "22",
        "CL-RGBCandyCane-11": "23",
        "CL-RGBCandyCane-12": "22",
    }
    assert all(r["controller_model"] == "Pixie 4" for r in third)
    assert all(r["controller_uid_range"] == "21-24" for r in third)
    assert all(r["controller_group_kind"] == "temporary-repeated-address-pattern-stale-source" for r in third)
    assert not any(g["name"] == "Pixie grouping review required" for g in groups)


def test_who_forest_has_eight_pixie8_groups_and_each_star_shares_output_8():
    rows: list[dict] = []
    base_uids = [0x50, 0x58, 0x60, 0x68, 0x70, 0x78, 0x80, 0x88]

    for tree_index, base in enumerate(base_uids, 1):
        tree_name = f"WF-Tree-{tree_index:02d}"
        star_name = f"WF-TreeStar-{tree_index:02d}"
        rows.extend(lor_rgb_rows(800 + tree_index, tree_name, [f"{base + offset:X}" for offset in range(8)], network="Aux I"))
        rows.append(row(900 + tree_index, star_name, f"{base + 7:X}", network="Aux I", start_channel=151, end_channel=300))

    presented = apply_physical_presentation(rows, scene_name="07a-Who Forest-WF")
    groups = [g for g in group_rows(presented) if g["family"] == "PIXIE"]

    assert len(groups) == 8
    assert all(g["controller_model"] == "Pixie 8" for g in groups)

    for index, group in enumerate(groups, 1):
        tree_rows = [r for r in group["rows"] if r["display_name"] == f"WF-Tree-{index:02d}"]
        star = next(r for r in group["rows"] if r["display_name"] == f"WF-TreeStar-{index:02d}")
        assert [r["physical_output"] for r in tree_rows] == list(range(1, 9))
        assert star["physical_output"] == 8


def test_ac_shared_output_keeps_atomic_connections_on_one_physical_output():
    rows = [
        row(1001, "CH-Steeple-LH-Base", "41", network="Regular", start_channel=1, device_type="LOR", string_type="Traditional", channel_name="CH 41-01 Steeple LH"),
        row(1002, "CH-Steeple-LH-Top", "41", network="Regular", start_channel=1, device_type="LOR", string_type="Traditional", channel_name="CH 41-01 Steeple LH-Top"),
        row(1003, "CH-Steeple-RH-Base", "41", network="Regular", start_channel=1, device_type="LOR", string_type="Traditional", channel_name="CH 41-01 Steeple RH"),
        row(1004, "CH-Steeple-RH-Top", "41", network="Regular", start_channel=1, device_type="LOR", string_type="Traditional", channel_name="CH 41-01 Steeple RH-Top"),
    ]

    presented = apply_physical_presentation(rows, scene_name="15-Church-CH")
    groups = group_rows(presented)

    assert len(groups) == 1
    assert groups[0]["family"] == "AC"
    assert {r["physical_output"] for r in groups[0]["rows"]} == {1}
    assert len(groups[0]["rows"]) == 4
    assert {r["channel_name"] for r in groups[0]["rows"]} == {
        "CH 41-01 Steeple LH",
        "CH 41-01 Steeple LH-Top",
        "CH 41-01 Steeple RH",
        "CH 41-01 Steeple RH-Top",
    }
