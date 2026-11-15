"""Management labor uses annual tasks and report evidence, not schedule copies."""
from setup_management_metrics import management_metrics


def test_mixed_qc_work_missing_evidence_and_completed_comparison():
    work = dict(setup_session_task_id=1, normal_crew_min=2,
                expected_duration_minutes=60, progress_entries=2,
                reported_person_minutes=150, effective_complete=True)
    result = management_metrics([
        work, dict(work),  # repeated board rows must not double the estimate
        dict(setup_session_task_id=2, normal_crew_min=3,
             expected_duration_minutes=30, progress_entries=1,
             reported_person_minutes=30),
        dict(setup_session_task_id=3, effective_complete=True),
        dict(setup_session_task_id=4, qc_check_flag=True, effective_complete=True,
             normal_crew_min=100, expected_duration_minutes=100,
             reported_person_minutes=9999),
        dict(setup_session_task_id=5, qc_check_flag=True, effective_complete=False),
    ])
    assert result['qc_total'] == 2
    assert result['qc_ready'] == result['qc_pending'] == 1
    assert result['planned_person_hours'] == 3.5
    assert result['reported_person_hours'] == 3
    assert result['matched_completed_tasks'] == 1
    assert result['matched_planned_hours'] == 2
    assert result['matched_reported_hours'] == 2.5
    assert result['matched_variance_hours'] == .5
    assert result['estimate_missing_tasks'] == result['unreported_tasks'] == 1


def test_incomplete_labor_evidence_excluded_from_variance_not_recorded_total():
    result = management_metrics([dict(setup_session_task_id=1,
        effective_complete=True, normal_crew_min=2, expected_duration_minutes=60,
        progress_entries=2, reported_person_minutes=60, labor_missing_reports=1)])
    assert result['reported_person_hours'] == 1
    assert result['labor_missing_reports'] == 1
    assert result['matched_completed_tasks'] == 0
