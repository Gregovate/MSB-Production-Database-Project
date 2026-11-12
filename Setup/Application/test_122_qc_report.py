"""Report keeps completed evidence and escapes hostile free text without writes."""
from setup_qc_report import render_qc_report


def test_completed_evidence_identity_escaping_and_outstanding_filter():
    snapshot = {'findings': [dict(qc_finding_id=12, setup_session_task_id=598,
        status='VERIFIED', stage_name='Racing Arches', scene_name=None,
        title='Short title', reporter='Tom', repair_owner='Rich',
        created_at='2026-11-12T12:00:00+00:00', events=[
            dict(id=2, type='REPAIRED', note='New lights', person='Rich', at='2026-11-12T13:00:00Z'),
            dict(id=1, type='REPORTED', note='<script>alert(1)</script> full report', person='Tom', at='2026-11-12T12:00:00Z')])],
        'auditors':[dict(setup_session_task_id=598,person_id=3,auditor='Greg')],
        'signoffs':[dict(setup_session_task_id=598,auditor_person_id=3,signed_at='2026-11-12T14:00:00Z',test_evidence='Observed full two-minute test')]}
    report=render_qc_report(snapshot,2026)
    for value in ['Racing Arches','QC #598','Issue #12','Tom','Rich','Greg','Observed full two-minute test','06:00 AM CST','Print / Save PDF']:
        assert value in report
    assert '<script>' not in report and '&lt;script&gt;' in report
    assert report.index('REPORTED') < report.index('REPAIRED')
    assert 'Issue #12' not in render_qc_report(snapshot,2026,'outstanding')


def test_area_header_and_signoff_once_with_all_finding_histories():
    # Input order must not duplicate headers or mix similarly named task identities.
    def finding(issue, task, note):
        return dict(qc_finding_id=issue, setup_session_task_id=task,
                    stage_key='25', stage_name='Racing Arches', scene_name=None,
                    status='VERIFIED', title=note, reporter='Tom',
                    repair_owner='Rich', events=[
                        dict(id=issue, type='REPAIRED', note=note, person='Rich')])
    snapshot = dict(findings=[finding(3, 598, 'Arch 4 repaired'),
                              finding(4, 599, 'Separate task history'),
                              finding(2, 598, 'Arch 3 repaired')],
                    auditors=[dict(setup_session_task_id=598, person_id=3,
                                   auditor='Greg')],
                    signoffs=[dict(setup_session_task_id=598, auditor_person_id=3,
                                   test_evidence='Observed entire area')])
    report = render_qc_report(snapshot, 2026)
    assert report.count('QC #598</h2>') == 1
    assert report.count('QC #599</h2>') == 1
    assert report.count('<b>QC auditors:</b>') == 2
    assert report.count('<b>Ready for Production:</b>') == 1
    assert report.count('Observed entire area') == 1
    assert report.count('<b>Repair claimed by:</b> Rich') == 3
    assert report.index('Issue #2') < report.index('Issue #3') < report.index('QC #599')
    for note in ['Arch 3 repaired', 'Arch 4 repaired', 'Separate task history']:
        assert note in report
    assert report.count('<section') == report.count('</section>') == 2
