"""Synthetic evidence tests; never claim these are the 23 Production tasks."""
from copy import deepcopy
from datetime import date
from html import unescape
from pathlib import Path
import re

from test_205_manager_mail_pilot import mail, fixture_containers
from setup_locate_assets import locate_assets


def test_23_selected_tasks_keep_notes_and_counts_without_semantic_reclassification():
    tasks = [dict(setup_session_task_id=i, task_name=f'Task {i}', execution_status='IN_PROGRESS',
                  percent_complete=50, future_assignment_count=0) for i in range(1,24)]
    tasks += [dict(setup_session_task_id=99, task_name='Complete wiring', effective_complete=True)]
    board = dict(session={'season_year':2026},tasks=tasks)
    original = deepcopy(board)
    report = mail.summarize(board,date(2026,10,31))
    before = {k:v for k,v in report.items() if isinstance(v,(int,float))}
    evidence = {i:dict(setup_task_progress_id=100+i, performed_on='2026-10-30', percent_complete=45,
                      progress_note=f'Original note {i}\nOther crew must wire <Display> & test.',
                      recorded_by='Captain A', recorded_at='2026-10-30T12:00:00-05:00') for i in range(1,24)}
    mail.enrich_continuations(report,evidence)
    assert before == {k:v for k,v in report.items() if isinstance(v,(int,float))}
    assert board == original
    assert report['continuation_needed'] == len(report['continuation_rows']) == 23
    assert [r['id'] for r in report['continuation_rows']] == list(range(1,24))
    report.update(fixture_containers())
    text = mail.render(mail.DEFAULT_TEMPLATE.read_text(),{'display_name':'Greg'},report)
    html = mail.render_html(mail.DEFAULT_HTML_TEMPLATE.read_text(),{'display_name':'Greg'},report)
    for r in report['continuation_rows']:
        assert r['note'] == evidence[r['id']]['progress_note']
        assert r['detail'] in text
        assert r['detail'] in unescape(re.sub('<[^>]*>','',html))
        assert r['url'] in unescape(html) and r['url'] in text
    assert '&lt;Display&gt;' in html and '<Display>' not in html
    assert 'Complete wiring' not in text


def picture():
    return dict(generated_at='2026-10-31',through_event_id=5,
        containers=[dict(container_id=9,container_name='Gingerbread base',last_movement_event_id=1,movement_status='CONTAINER_MOVE'),
                    dict(container_id=52,container_name='Wrap transport',last_movement_event_id=2,movement_status='RETURNED'),
                    dict(container_id=131,container_name='Antenna trailer',last_movement_event_id=3,movement_status='CONTAINER_MOVE')],
        effect_rows=[dict(setup_movement_event_id=1,container_id=9,event_type='CONTAINER_MOVE',occurred_at='2026-10-29',
                          notes='contents_reconciliation={"decision":"NOT_EMPTY", "identify_remaining":false}; contents_review_required=true'),
                     dict(setup_movement_event_id=2,container_id=52,event_type='RETURNED',occurred_at='2026-10-30',notes=''),
                     dict(setup_movement_event_id=3,container_id=131,event_type='CONTAINER_MOVE',occurred_at='2026-10-30',
                          notes='contents_reconciliation={"decision":"EMPTY"}'),
                     dict(setup_movement_event_id=4,display_id=4,event_type='DISPLAY_MOVE',movement_effect='DETACHED',occurred_at='2026-10-30',notes=''),
                     dict(setup_movement_event_id=5,display_id=5,event_type='TASK_UNLOAD',movement_effect='DETACHED',occurred_at='2026-10-30',notes='inferred_unload=true')],
        displays=[dict(display_id=1,display_name='Integral identity unverified',container_id=9,position_mode='WITH_CONTAINER'),
                  dict(display_id=2,display_name='Stale returned association',container_id=52,position_mode='WITH_CONTAINER'),
                  dict(display_id=3,display_name='No scan',container_id=None,position_mode='NO_ASSIGNED_CONTAINER'),
                  dict(display_id=4,display_name='Independent scan',container_id=None,position_mode='DETACHED',last_movement_event_id=4),
                  dict(display_id=5,display_name='Prior inferred unload',container_id=None,position_mode='DETACHED',last_movement_event_id=5)])


def test_movement_details_do_not_promote_associations_or_scans_to_physical_completion():
    source = picture(); before = deepcopy(source)
    projected = locate_assets(source)
    counts = mail.summarize_container_snapshot(projected['containers'], source['generated_at'])
    details = mail.movement_details(source,projected)
    assert source == before
    assert counts == mail.summarize_container_snapshot(projected['containers'], source['generated_at'])
    containers = details['container_rows']; displays = details['display_rows']
    assert 'Recorded cargo remains' in containers[0]['detail']
    assert 'NOT_EMPTY without identifying remaining cargo' in containers[0]['detail']
    assert 'resolution unverified' in containers[0]['detail']
    assert 'Returned Home — actual RETURNED record' in containers[1]['detail']
    assert 'Recorded physical EMPTY observation' in containers[2]['detail']
    assert 'Pickup readiness unverified' in containers[2]['detail']
    assert 'Last location inferred from a Container' in displays[0]['detail']
    assert 'Conflicting observations' in displays[1]['detail']
    assert 'No usable placement evidence' in displays[2]['detail']
    assert 'final position unconfirmed' in displays[3]['detail']
    assert 'not a physical Display scan' in displays[4]['detail']
    for r in containers + displays:
        assert mail.PENDING in r['detail']
        assert '/record-location/?asset=' in r['url']
    assert 'Confirmed final' not in details['display_detail_lines']


def test_empty_observation_is_not_taken_from_malformed_or_absent_json():
    assert mail.contents_observation({'notes':'EMPTY in note'}) == {}
    assert mail.contents_observation({'notes':'contents_reconciliation={oops}'}) == {}
    assert mail.contents_observation({'notes':'contents_reconciliation={"decision":"NOT_SURE"}; other'})['decision']=='NOT_SURE'


def test_missing_attribution_and_note_are_explicit():
    report = {'continuation_rows':[{'id':1,'name':'Task','percent':'10','url':mail.record_url('planning',1)}]}
    mail.enrich_continuations(report,{})
    assert 'Attribution not recorded' in report['continuation_lines']
    assert 'No Report Work note recorded' in report['continuation_lines']
