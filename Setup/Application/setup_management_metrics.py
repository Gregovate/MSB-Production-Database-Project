"""Shared read-only management totals for the board and Manager Brief.

Annual estimates are counted once per task, never once per assignment. Actual
labor comes from task-level progress aggregates, including unscheduled reports.
Missing estimates/reports remain explicit; QC labor is outside setup totals.
"""
from math import isfinite


def management_metrics(tasks):
    tasks = list({int(t["setup_session_task_id"]): t for t in tasks}.values())
    qc = [t for t in tasks if t.get("qc_check_flag")]
    work = [t for t in tasks if not t.get("qc_check_flag")]
    def estimate(t):
        try:
            crew = float(t.get("normal_crew_min"))
            minutes = float(t.get("expected_duration_minutes"))
            return crew * minutes / 60 if isfinite(crew * minutes) and crew > 0 and minutes > 0 else None
        except (TypeError, ValueError):
            return None
    planned = actual = matched_planned = matched_actual = 0.0
    unknown = unreported = missing_labor = matched = 0
    for t in work:
        hours = estimate(t)
        if hours is None:
            unknown += 1
        else:
            planned += hours
        reports = int(t.get("progress_entries") or 0)
        missing = int(t.get("labor_missing_reports") or 0)
        recorded = float(t.get("reported_person_minutes") or 0) / 60
        actual += recorded
        missing_labor += missing
        unreported += not reports
        # Only compare the same completed tasks with known estimates and reports.
        if t.get("effective_complete") and hours is not None and reports and not missing:
            matched += 1
            matched_planned += hours
            matched_actual += recorded
    return {
        "qc_total": len(qc),
        "qc_ready": sum(bool(t.get("effective_complete")) for t in qc),
        "qc_pending": sum(not t.get("effective_complete") for t in qc),
        "planned_person_hours": round(planned, 2),
        "reported_person_hours": round(actual, 2),
        "estimate_missing_tasks": unknown,
        "unreported_tasks": unreported,
        "labor_missing_reports": missing_labor,
        "matched_completed_tasks": matched,
        "matched_planned_hours": round(matched_planned, 2),
        "matched_reported_hours": round(matched_actual, 2),
        "matched_variance_hours": round(matched_actual - matched_planned, 2),
    }
