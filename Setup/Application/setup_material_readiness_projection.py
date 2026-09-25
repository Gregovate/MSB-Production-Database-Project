"""Pure projection helpers for Setup #206 material readiness.

These helpers intentionally know nothing about PostgreSQL or Flask.  They turn
already-authoritative physical-demand rows into the deduplicated operator view
used by the read-only material-readiness endpoint.
"""
from __future__ import annotations

from datetime import date, timedelta
from typing import Any, Iterable


def reachable_material_targets(
    start_session_task_id: int,
    tasks_by_session_id: dict[int, dict[str, Any]],
    downstream_by_prerequisite: dict[int, list[int]],
) -> list[dict[str, Any]]:
    """Return every incomplete material-bearing reusable task downstream.

    The scheduled task is included when it is itself material-bearing.  A
    completed task does not create new demand, but traversal continues through
    it so later downstream material is still surfaced.  A DEFERRED task stops
    that branch because the operator has explicitly postponed that work.
    """
    start_id = int(start_session_task_id)
    queue = [start_id]
    visited: set[int] = set()
    found: dict[int, dict[str, Any]] = {}

    while queue:
        current_id = int(queue.pop(0))
        if current_id in visited:
            continue
        visited.add(current_id)

        task = tasks_by_session_id.get(current_id)
        if task is None:
            continue
        if str(task.get("execution_status") or "").upper() == "DEFERRED":
            continue

        if bool(task.get("material_bearing")) and not bool(task.get("effective_complete")):
            found[current_id] = task

        for downstream_id in downstream_by_prerequisite.get(current_id, []):
            downstream_id = int(downstream_id)
            if downstream_id not in visited:
                queue.append(downstream_id)

    return sorted(
        found.values(),
        key=lambda task: (
            int(task.get("planned_order") or 10**9),
            int(task.get("display_order") or 10**9),
            int(task.get("setup_session_task_id") or 0),
        ),
    )


def target_staged_by(work_date: str) -> str:
    """Return the normal D-1 staging target for an ISO work date."""
    return (date.fromisoformat(work_date) - timedelta(days=1)).isoformat()


def project_physical_demand(rows: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    """Deduplicate physical items while preserving every scheduled reason."""
    items: dict[tuple[str, int], dict[str, Any]] = {}

    for source in rows:
        row = dict(source)
        physical_type = str(row["physical_type"]).upper()
        physical_id = int(row["physical_id"])
        key = (physical_type, physical_id)
        work_date = str(row["work_date"])
        staged_by = target_staged_by(work_date)

        item = items.setdefault(
            key,
            {
                "physical_type": physical_type,
                "physical_id": physical_id,
                "identity": str(row["identity"]),
                "label": row.get("label"),
                "home_location_code": row.get("home_location_code"),
                "earliest_needed_for_work": work_date,
                "target_staged_by": staged_by,
                "reasons": [],
            },
        )

        if work_date < item["earliest_needed_for_work"]:
            item["earliest_needed_for_work"] = work_date
        if staged_by < item["target_staged_by"]:
            item["target_staged_by"] = staged_by

        reason = {
            "setup_work_day_task_id": row.get("setup_work_day_task_id"),
            "setup_session_task_id": row.get("setup_session_task_id"),
            "setup_task_id": row.get("setup_task_id"),
            "task_name": row.get("task_name"),
            "setup_day_number": row.get("setup_day_number"),
            "work_date": work_date,
            "target_staged_by": staged_by,
            "shift_code": row.get("shift_code"),
            "crew_lane": row.get("crew_lane"),
            "stage_id": row.get("stage_id"),
            "stage_key": row.get("stage_key"),
            "stage_name": row.get("stage_name"),
            "lor_scene_id": row.get("lor_scene_id"),
            "scene_name": row.get("scene_name"),
            "reason_type": row.get("reason_type"),
            "reason_label": row.get("reason_label"),
            "reason_detail": row.get("reason_detail"),
            "display_ids": list(row.get("display_ids") or []),
            "display_names": list(row.get("display_names") or []),
            "extra_material_id": row.get("extra_material_id"),
            "extra_material_name": row.get("extra_material_name"),
            "quantity_required": row.get("quantity_required"),
            "quantity_uom": row.get("quantity_uom"),
            "quantity_qualifier": row.get("quantity_qualifier"),
            "size_text": row.get("size_text"),
            "length_value": row.get("length_value"),
            "length_unit": row.get("length_unit"),
            "color": row.get("color"),
            "requirement_notes": row.get("requirement_notes"),
            "source_expected_quantity": row.get("source_expected_quantity"),
            "source_verification_state": row.get("source_verification_state"),
            "demand_origin": row.get("demand_origin") or "DIRECT_SCHEDULE",
            "scheduled_trigger_setup_work_day_task_id": row.get("scheduled_trigger_setup_work_day_task_id"),
            "scheduled_trigger_setup_session_task_id": row.get("scheduled_trigger_setup_session_task_id"),
            "scheduled_trigger_setup_task_id": row.get("scheduled_trigger_setup_task_id"),
            "scheduled_trigger_task_name": row.get("scheduled_trigger_task_name"),
        }
        item["reasons"].append(reason)

    projected = list(items.values())
    projected.sort(
        key=lambda item: (
            item["target_staged_by"],
            item["earliest_needed_for_work"],
            0 if item["physical_type"] == "CONTAINER" else 1,
            item["physical_id"],
        )
    )
    return projected
