from setup_material_readiness_projection import (
    downstream_material_frontier,
    project_physical_demand,
    target_staged_by,
)


def row(**updates):
    base = {
        "physical_type": "CONTAINER",
        "physical_id": 34,
        "identity": "CONT:34",
        "label": "Arch Trailer",
        "home_location_code": "SHOP-A",
        "setup_work_day_task_id": 1,
        "setup_session_task_id": 10,
        "setup_task_id": 100,
        "task_name": "Stars",
        "setup_day_number": 3,
        "work_date": "2026-10-06",
        "shift_code": "MORNING",
        "crew_lane": "A",
        "stage_id": 10,
        "stage_key": "10",
        "stage_name": "Stars",
        "lor_scene_id": None,
        "scene_name": None,
        "reason_type": "DISPLAY_MATERIAL",
        "reason_label": "24 required Displays",
        "reason_detail": "Stars",
        "display_ids": [1, 2],
        "display_names": ["A", "B"],
    }
    base.update(updates)
    return base


def test_d_minus_one_target():
    assert target_staged_by("2026-10-06") == "2026-10-05"


def test_shared_container_is_deduplicated_and_keeps_all_reasons():
    items = project_physical_demand([
        row(),
        row(
            setup_work_day_task_id=2,
            setup_session_task_id=11,
            setup_task_id=101,
            task_name="Candyland",
            work_date="2026-10-08",
            stage_id=17,
            stage_key="17",
            stage_name="Candyland",
            reason_label="2 required Displays",
        ),
    ])
    assert len(items) == 1
    assert items[0]["identity"] == "CONT:34"
    assert items[0]["earliest_needed_for_work"] == "2026-10-06"
    assert items[0]["target_staged_by"] == "2026-10-05"
    assert [reason["task_name"] for reason in items[0]["reasons"]] == ["Stars", "Candyland"]


def test_detached_display_remains_independent_physical_item():
    items = project_physical_demand([
        row(
            physical_type="DISPLAY",
            physical_id=456,
            identity="DISP:456",
            label="Detached Display",
            home_location_code="SHOP-B",
        )
    ])
    assert items[0]["physical_type"] == "DISPLAY"
    assert items[0]["identity"] == "DISP:456"


def test_extra_material_source_allocation_and_spec_are_preserved():
    items = project_physical_demand([
        row(
            reason_type="EXTRA_MATERIAL_SOURCE",
            reason_label="T-Post",
            reason_detail="VERIFIED",
            display_ids=[],
            display_names=[],
            extra_material_id=7,
            extra_material_name="T-Post",
            quantity_required="9.000",
            quantity_uom="EA",
            quantity_qualifier="EXACT",
            size_text="heavy duty",
            length_value="6.000",
            length_unit="FT",
            color=None,
            requirement_notes="Elf Choir requirement",
            source_expected_quantity="5.000",
            source_verification_state="VERIFIED",
        )
    ])
    reason = items[0]["reasons"][0]
    assert reason["quantity_required"] == "9.000"
    assert reason["source_expected_quantity"] == "5.000"
    assert reason["length_value"] == "6.000"
    assert reason["length_unit"] == "FT"
    assert reason["source_verification_state"] == "VERIFIED"



def demand_task(session_id, *, material=False, status="NOT_STARTED", order=1):
    return {
        "setup_session_task_id": session_id,
        "material_bearing": material,
        "execution_status": status,
        "planned_order": order,
    }


def test_precursor_chain_surfaces_downstream_material_frontier():
    tasks = {
        1: demand_task(1, order=1),       # Locate
        2: demand_task(2, order=2),       # Layout
        3: demand_task(3, material=True, order=3),  # Setup
    }
    found = downstream_material_frontier(1, tasks, {1: [2], 2: [3]})
    assert [task["setup_session_task_id"] for task in found] == [3]


def test_material_frontier_includes_parallel_and_contiguous_material_work():
    tasks = {
        1: demand_task(1, order=1),
        2: demand_task(2, order=2),
        3: demand_task(3, material=True, order=3),
        4: demand_task(4, material=True, order=4),
        5: demand_task(5, material=True, order=5),
    }
    found = downstream_material_frontier(
        1, tasks, {1: [2], 2: [3, 4], 3: [5]}
    )
    assert [task["setup_session_task_id"] for task in found] == [3, 4, 5]


def test_material_frontier_does_not_cross_into_later_non_material_phase():
    tasks = {
        1: demand_task(1, order=1),
        2: demand_task(2, material=True, order=2),
        3: demand_task(3, order=3),
        4: demand_task(4, material=True, order=4),
    }
    found = downstream_material_frontier(1, tasks, {1: [2], 2: [3], 3: [4]})
    assert [task["setup_session_task_id"] for task in found] == [2]


def test_deferred_branch_does_not_create_early_material_demand():
    tasks = {
        1: demand_task(1, order=1),
        2: demand_task(2, status="DEFERRED", order=2),
        3: demand_task(3, material=True, order=3),
    }
    assert downstream_material_frontier(1, tasks, {1: [2], 2: [3]}) == []


def test_expanded_reason_preserves_scheduled_trigger_identity():
    items = project_physical_demand([
        row(
            task_name="Setup Panels",
            demand_origin="DOWNSTREAM_FROM_SCHEDULE",
            scheduled_trigger_setup_work_day_task_id=71,
            scheduled_trigger_setup_session_task_id=81,
            scheduled_trigger_setup_task_id=91,
            scheduled_trigger_task_name="Locate Power & Network",
        )
    ])
    reason = items[0]["reasons"][0]
    assert reason["demand_origin"] == "DOWNSTREAM_FROM_SCHEDULE"
    assert reason["scheduled_trigger_task_name"] == "Locate Power & Network"
    assert reason["scheduled_trigger_setup_work_day_task_id"] == 71



def test_direct_material_schedule_does_not_cross_later_non_material_phase():
    tasks = {
        1: demand_task(1, material=True, order=1),
        2: demand_task(2, order=2),
        3: demand_task(3, material=True, order=3),
    }
    assert downstream_material_frontier(1, tasks, {1: [2], 2: [3]}) == []


def test_direct_material_schedule_does_not_expand_to_later_material_tasks():
    tasks = {
        1: demand_task(1, material=True, order=1),   # Setup Mt Crumpit Scaffold
        2: demand_task(2, material=True, order=2),   # Setup Mt Crumpit Panels
        3: demand_task(3, material=True, order=3),   # Setup Who House & Who People
    }
    assert downstream_material_frontier(1, tasks, {1: [2], 2: [3]}) == []


def test_complete_material_target_is_not_demand_but_wave_remains_bounded():
    tasks = {
        1: demand_task(1, order=1),
        2: demand_task(2, material=True, status="COMPLETE", order=2),
        3: demand_task(3, material=True, order=3),
        4: demand_task(4, order=4),
        5: demand_task(5, material=True, order=5),
    }
    found = downstream_material_frontier(
        1, tasks, {1: [2], 2: [3], 3: [4], 4: [5]}
    )
    assert [task["setup_session_task_id"] for task in found] == [3]
