from pathlib import Path

from wiring_controller_inventory import match_row_controllers


BASE_DIR = Path(__file__).resolve().parent


def _candidate(
    controller_id: int,
    *,
    model: str = "CTB32",
    network: str | None = "Aux E",
    start: int | None = 0x80,
    end: int | None = 0x80,
) -> dict[str, object]:
    return {
        "controller_id": controller_id,
        "model_code": model,
        "controller_status_name": "DEPLOYED",
        "lor_network": network,
        "lor_uid_start": start,
        "lor_uid_end": end,
    }


def test_ac_row_resolves_permanent_controller_only_after_assignment_candidate_is_known() -> None:
    row = {
        "presentation_family": "AC",
        "network": "Aux E",
        "controller": "80",
    }

    controllers, basis = match_row_controllers(row, [_candidate(1001)])

    assert controllers == [
        {
            "controller_id": 1001,
            "model_code": "CTB32",
            "controller_status_name": "DEPLOYED",
        }
    ]
    assert basis == "PROGRAMMED_LOR_ADDRESS"


def test_intentional_duplicate_address_returns_both_physical_controllers() -> None:
    row = {
        "presentation_family": "AC",
        "network": "Regular",
        "controller": "22",
    }
    candidates = [
        _candidate(1112, network="Regular", start=0x22, end=0x22),
        _candidate(1113, network="Regular", start=0x22, end=0x22),
    ]

    controllers, basis = match_row_controllers(row, candidates)

    assert [item["controller_id"] for item in controllers] == [1112, 1113]
    assert basis == "PROGRAMMED_LOR_ADDRESS"


def test_pixie_row_matches_controller_contiguous_uid_range() -> None:
    row = {
        "presentation_family": "PIXIE",
        "network": "Aux A",
        "controller": "23",
    }
    controllers, basis = match_row_controllers(
        row,
        [_candidate(1134, model="Pixie4D", network="Aux A", start=0x21, end=0x24)],
    )

    assert [item["controller_id"] for item in controllers] == [1134]
    assert basis == "PROGRAMMED_LOR_ADDRESS"


def test_e131_multiple_assigned_controllers_are_not_claimed_as_exact_partition() -> None:
    row = {
        "presentation_family": "E131",
        "network": "Regular",
        "controller": "113",
    }
    controllers, basis = match_row_controllers(
        row,
        [
            _candidate(1143, model="PixCon16", network=None, start=None, end=None),
            _candidate(1144, model="PixCon16", network=None, start=None, end=None),
        ],
    )

    assert [item["controller_id"] for item in controllers] == [1143, 1144]
    assert basis == "DISPLAY_ASSIGNMENT"


def test_fieldwiring_loads_controller_crosslink_assets() -> None:
    html = (BASE_DIR / "wiring.html").read_text(encoding="utf-8")
    script = (BASE_DIR / "static" / "wiring_controller_links.js").read_text(encoding="utf-8")

    assert "static/wiring_controller_links.css" in html
    assert "static/wiring_controller_links.js" in html
    assert "controllers?controller_id=" in script
    assert "Assigned Controllers" in script
    assert "CTRL ${controller.controller_id}" in script


def test_controller_inventory_supports_exact_controller_deep_link_and_exposes_print_label() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")
    script = (BASE_DIR / "static" / "controllers_detail_extras.js").read_text(encoding="utf-8")

    assert "controllers_detail_extras.js" in html
    assert "get('controller_id')" in script
    assert "loadControllerDetail(controllerId)" in script
    assert "Print Label" in script
    assert "c.print_label" in script
    assert "label_print_count_cached" in script
