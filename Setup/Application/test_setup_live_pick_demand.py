"""A focused-mapping miss must not contradict the live physical Pick List."""
import pytest
from setup_material_readiness_repository import SetupMaterialReadinessRepository


def test_stage_scope_container_missing_explicit_mapping_is_pickable():
    repo = SetupMaterialReadinessRepository.__new__(SetupMaterialReadinessRepository)
    item = {"physical_type": "CONTAINER", "physical_id": 12,
            "reasons": [{"demand_origin": "DIRECT_SCHEDULE"}],
            "pick_delayed": False, "current_observation": None}
    repo.material_readiness = lambda year: {"physical_items": [item]}
    status = repo._reconcile_pick_demand(season_year=2026, asset_type="CONTAINER",
                                       asset_id=12, status={"demanded": False})
    assert status == {"demanded": True, "pick_delayed": False,
                      "demand_origins": ["DIRECT_SCHEDULE"], "current_observation": None}


@pytest.mark.parametrize("delayed", [True, False])
def test_fallback_preserves_delay_and_real_movement(delayed):
    repo = SetupMaterialReadinessRepository.__new__(SetupMaterialReadinessRepository)
    observation = {"movement_status": "PICKED", "last_movement_event_id": 71}
    repo.material_readiness = lambda year: {"physical_items": [
        {"physical_type": "CONTAINER", "physical_id": 12,
         "pick_delayed": delayed, "current_observation": observation}]}
    status = repo._reconcile_pick_demand(season_year=2026, asset_type="CONTAINER",
                                       asset_id=12, status={"demanded": False})
    assert status["pick_delayed"] is delayed
    assert status["current_observation"] == observation


def test_matching_fast_path_does_not_build_full_projection():
    repo = SetupMaterialReadinessRepository.__new__(SetupMaterialReadinessRepository)
    def unexpected(_year):
        pytest.fail("ordinary demanded scan built full material projection")
    repo.material_readiness = unexpected
    original = {"demanded": True, "pick_delayed": True}
    assert repo._reconcile_pick_demand(season_year=2026, asset_type="CONTAINER",
                                     asset_id=12, status=original) is original


def test_wrong_identity_remains_rejected():
    repo = SetupMaterialReadinessRepository.__new__(SetupMaterialReadinessRepository)
    repo.material_readiness = lambda year: {"physical_items": [
        {"physical_type": "DISPLAY", "physical_id": 12},
        {"physical_type": "CONTAINER", "physical_id": 122}]}
    original = {"demanded": False}
    assert repo._reconcile_pick_demand(season_year=2026, asset_type="CONTAINER",
                                     asset_id=12, status=original) is original
