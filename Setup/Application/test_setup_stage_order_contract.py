from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent


def test_stage_order_extension_is_view_only() -> None:
    text = (APP_DIR / "setup_stage_order.js").read_text(encoding="utf-8")
    assert "View order" in text
    assert '<option value="STAGE">Stage</option>' in text
    assert '<option value="PLANNED">Planned order</option>' in text
    assert "planned order is unchanged" in text
    assert "row.draggable = false" in text
    assert "setupStageOrderedTasks" in text
    assert "sortedStages()" in text
    assert "commandOptions" not in text
    assert "/api/setup/" not in text


def test_stage_order_applies_to_plan_schedule_and_perform() -> None:
    text = (APP_DIR / "setup_stage_order.js").read_text(encoding="utf-8")
    assert "next-plan-order-mode" in text
    assert "next-perform-order-mode" in text
    assert "next-schedule-task" in text
    assert "renderPlanningBacklogWithStageOrder" in text
    assert "renderNextExecutionWithStageOrder" in text
    assert "loadNextScheduleWithStageOrder" in text
    assert "setup-stage-order-heading" in text
    assert "setup-stage-scope-heading" in text
    assert "Stage-level / General" in text
    assert "Scene —" in text


def test_production_loads_stage_order_assets() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    backend = (APP_DIR / "production_backend.py").read_text(encoding="utf-8")
    assert "setup_stage_order.css" in html
    assert "setup_stage_order.js" in html
    assert "setup_stage_order.css" in backend
    assert "setup_stage_order.js" in backend
