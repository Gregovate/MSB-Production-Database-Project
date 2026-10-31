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
                     dict(setup_movement_event_id=4,display_id=4,event_type='DISPLAY_MOVE',movement_effect='MOVED',occurred_at='2026-10-30',notes=''),
                     dict(setup_movement_event_id=5,display_id=5,event_type='TASK_UNLOAD',movement_effect='UNLOADED',occurred_at='2026-10-30',notes='inferred_unload=true')],
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
    containers = details['container_inventory_rows']; displays = details['display_rows']
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
    for r in displays:
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


def test_authoritative_pickup_request_is_not_actual_return_or_association_empty():
    source=picture()
    source['pickup_requests']=[dict(container_id=131,pickup_event_id=7,requested_at='2026-10-31',
                                    operator_email='crew@example.com',stage_name='Command Center',location_note='Gate')]
    source['containers'][0]['container_type_name']='Standalone Display'
    result=mail.movement_details(source,locate_assets(source))
    assert 'Integral show equipment' in result['container_inventory_rows'][0]['detail']
    row=result['container_inventory_rows'][2]
    assert 'Confirmed Ready for Pickup' in row['detail']
    assert 'Only Containers needing action' in mail.DEFAULT_TEMPLATE.read_text()
    assert 'Only Containers needing action' in mail.DEFAULT_HTML_TEMPLATE.read_text()
    assert 'request #7' in row['detail'] and 'crew@example.com' in row['detail']
    assert '/container-pickups/?asset=CONT%3A131' in row['url']
    assert 'Returned Home' in result['container_inventory_rows'][1]['detail']
    # Cancellation / later return are removed by existing #078 view, not inferred here.
    source['pickup_requests']=[]
    assert 'Confirmed Ready for Pickup' not in mail.movement_details(source,locate_assets(source))['container_detail_lines']


def test_readable_central_dates_completion_note_and_actual_update_only():
    assert mail.readable_date('2026-10-31T00:40:30.485476+00:00') == 'Oct 30, 2026 at 7:40 PM CDT'
    assert mail.readable_date('2026-11-02T00:40:30Z') == 'Nov 1, 2026 at 6:40 PM CST'
    assert mail.readable_date('2026-10-30') == 'Oct 30, 2026'
    assert mail.readable_date(None) == 'Not recorded'
    row = dict(id=422, name='Tree', percent='97', completion_note='Assembly done; <power> remains.', url=mail.record_url('planning',422))
    report = {'continuation_rows':[row]}
    evidence = {422:dict(setup_work_day_task_id=222, progress_note='Guy wire added', recorded_by='Tom', updated_by='Tom',
                        recorded_at='2026-10-31T00:40:30.485476+00:00', updated_at='2026-10-31T00:40:30.485476+00:00')}
    mail.enrich_continuations(report,evidence)
    assert 'Updated by' not in row['detail'] and 'Corrected by' not in row['detail']
    assert 'Task completion note: Assembly done; <power> remains.' in row['detail']
    assert row['url'] == mail.record_url('report',222)
    evidence[422]['updated_at'] = '2026-11-02T00:40:30Z'
    mail.enrich_continuations(report,evidence)
    assert 'Updated by: Tom' in row['detail'] and '6:40 PM CST' in row['detail']


def test_container_rows_do_not_repeat_event_evidence_or_shared_explanations():
    source = picture()
    source['effect_rows'][0]['recorded_by_name'] = 'Tom Shircel'
    result = mail.movement_details(source, locate_assets(source))
    row = result['container_inventory_rows'][0]
    assert row['detail'].count('Tom Shircel') == 1
    assert 'same event as last movement' in row['detail']
    assert '#1: Operator reported NOT_EMPTY without identifying remaining cargo' in row['detail']
    assert len(row['detail'].split()) < 110
    assert 'opening the link records nothing' not in row['detail']


def test_shared_gps_does_not_certify_final_positions_or_fabricate_scans():
    source = picture()
    source['displays'] = [dict(display_id=i, container_id=9, position_mode='DETACHED', last_movement_event_id=10+i)
                          for i in range(1,4)]
    events = {10+i:dict(event_type='DISPLAY_MOVE', gps_latitude=43.7, gps_longitude=-87.7,
                       notes='inferred_unload=true') for i in range(1,4)}
    text = mail.container_display_evidence(9, source, events, {})
    assert '3 inferred unload' in text and '3/3 share recorded GPS — placement review required' in text
    assert 'Final positions unconfirmed' in text and 'Display observation' not in text
    events[11]['notes'] = ''
    text = mail.container_display_evidence(9, source, events, {})
    assert '1 Display observation' in text and '2 inferred unload' in text
    assert 'Final positions unconfirmed' in text


def test_blocked_next_task_evidence_uses_real_edges_and_preserves_counts_and_notes():
    from setup_scheduling_board_repository import attach_blocked_successors
    tasks = [dict(setup_session_task_id=1, task_name='Setup tree', execution_status='IN_PROGRESS',
                  percent_complete=97, completion_note='Assembly finished; power is separate.'),
             dict(setup_session_task_id=2, task_name='Power <tree>', execution_status='NOT_STARTED'),
             dict(setup_session_task_id=3, task_name='Completed successor', effective_complete=True),
             dict(setup_session_task_id=4, task_name='Deferred successor', execution_status='DEFERRED'),
             dict(setup_session_task_id=5, task_name='Unrelated task', execution_status='NOT_STARTED')]
    original = deepcopy(tasks)
    edge = dict(prerequisite_setup_session_task_id=1, setup_session_task_id=2, prerequisite_complete=False)
    deps = [edge, dict(edge), {**edge, 'setup_session_task_id':3}, {**edge, 'setup_session_task_id':4},
            {**edge, 'setup_session_task_id':5, 'prerequisite_complete':True},
            {**edge, 'setup_session_task_id':99}]
    board = dict(session={'season_year':2026}, tasks=tasks, dependencies=deps)
    before = mail.summarize(board, date(2026,10,31))
    attach_blocked_successors(tasks, deps)
    assert tasks[0]['blocked_next_tasks'] == [{'id':2, 'name':'Power <tree>'}]
    assert [{k:v for k,v in t.items() if k != 'blocked_next_tasks'} for t in tasks] == original
    report = mail.summarize(board, date(2026,10,31))
    for key in ('total_tasks','completed_tasks','remaining_tasks','continuation_needed','blocked_tasks'):
        assert report[key] == before[key]
    mail.enrich_continuations(report, {1:{'progress_note':'Guy wire done; power remains.'}})
    report.update(fixture_containers())
    text = mail.render(mail.DEFAULT_TEMPLATE.read_text(), {'display_name':'Greg'}, report)
    html = mail.render_html(mail.DEFAULT_HTML_TEMPLATE.read_text(), {'display_name':'Greg'}, report)
    phrase = 'Next task: Power <tree> — blocked because this task is incomplete.'
    assert phrase in text and phrase in unescape(re.sub('<[^>]*>', '', html))
    assert 'Assembly finished; power is separate.' in text and 'Guy wire done; power remains.' in text
    url = mail.record_url('planning',2)
    assert url in text and f'href="{url.replace("&", "&amp;")}"' in html
    assert 'Power &lt;tree&gt;' in html and '<tree>' not in html
    tasks[0]['effective_complete'] = True
    attach_blocked_successors(tasks, deps)
    assert not tasks[0]['blocked_next_tasks']


def independently_scanned_picture():
    # Reconstruct Greg's supplied examples; this is not a live database check.
    source = picture()
    source['displays'] = []
    source['effect_rows'] = []
    examples = [(72,603,43.776852,-87.747217,'Greg Liebig',9),
                (88,604,43.776865,-87.747208,'Greg Liebig',9),
                (630,508,43.775758,-87.743643,'Rich Neerhof',52),
                (620,525,43.775782,-87.743801,'Rich Neerhof',52)]
    for ident, event_id, lat, lon, actor, container in examples:
        source['displays'].append(dict(display_id=ident, display_name=f'Display {ident}',
            container_id=container, position_mode='DETACHED', last_movement_event_id=event_id))
        source['effect_rows'].append(dict(setup_movement_event_id=event_id, display_id=ident,
            event_type='DISPLAY_MOVE', movement_effect='MOVED', capture_method='CAMERA_SCAN',
            gps_latitude=lat, gps_longitude=lon, recorded_by_name=actor, notes=''))
    return source


def test_independent_bench_and_emoji_scans_are_in_position_not_exceptions():
    source = independently_scanned_picture()
    before = deepcopy(source)
    projected = locate_assets(source)
    counts = mail.summarize_container_snapshot(projected['containers'], source['generated_at'])
    result = mail.movement_details(source, projected)
    assert result['display_in_position_ids'] == [72,88,620,630]
    assert result['display_rows'] == []
    assert '2 In position' in result['container_inventory_rows'][0]['detail']
    assert 'Final positions unconfirmed' not in result['container_inventory_rows'][0]['detail']
    assert source == before
    assert counts == mail.summarize_container_snapshot(projected['containers'], source['generated_at'])
    report = mail.summarize(dict(session={'season_year':2026}, tasks=[dict(setup_session_task_id=1)]), date(2026,10,31))
    report.update(fixture_containers()); report.update(result)
    text = mail.render(mail.DEFAULT_TEMPLATE.read_text(), {'display_name':'Greg'}, report)
    html = mail.render_html(mail.DEFAULT_HTML_TEMPLATE.read_text(), {'display_name':'Greg'}, report)
    for ident in (72,88,620,630):
        assert f'Display {ident}' not in text and f'Display {ident}' not in html


def test_inferred_grouped_conflicting_and_shared_locations_stay_reviewable():
    source = independently_scanned_picture()
    source['effect_rows'][0]['notes'] = 'inferred_unload=true'
    source['effect_rows'][1]['movement_effect'] = 'ATTACHED'
    # Explicit mismatched effect must never certify placement.
    result = mail.movement_details(source, locate_assets(source))
    assert result['display_in_position_ids'] == [620,630]
    assert len(result['display_rows']) == 2
    source = independently_scanned_picture()
    source['effect_rows'][1]['gps_latitude'] = source['effect_rows'][0]['gps_latitude']
    source['effect_rows'][1]['gps_longitude'] = source['effect_rows'][0]['gps_longitude']
    result = mail.movement_details(source, locate_assets(source))
    assert result['display_in_position_ids'] == [620,630]
    assert all('Shared GPS' in row['detail'] for row in result['display_rows'])
    source = independently_scanned_picture()
    source['effect_rows'][0].update(gps_latitude=None, gps_longitude=None)
    result = mail.movement_details(source, locate_assets(source))
    assert 72 in result['display_in_position_ids']  # Greg's independent-scan rule.
    source['effect_rows'].append({**source['effect_rows'][0], 'display_id':999})
    result = mail.movement_details(source, locate_assets(source))
    assert 72 not in result['display_in_position_ids']  # Group event is not independent.


def test_scan_fixture_uses_actual_migration070_effect_contract():
    sql = (Path(__file__).resolve().parents[1] / 'Database/070_reconcile_setup_container_contents.sql').read_text()
    assert "CASE WHEN v_action='TASK_UNLOAD' THEN 'UNLOADED' ELSE 'MOVED' END" in sql
    assert "position_mode = 'DETACHED'" in sql
    assert {e['movement_effect'] for e in independently_scanned_picture()['effect_rows']} == {'MOVED'}


def test_only_current_container_actions_render_and_history_counts_are_preserved():
    source = dict(generated_at='2026-10-31', through_event_id=200, containers=[], displays=[], effect_rows=[], pickup_requests=[])
    def add(ident, status=None, decision=None, kind='Display Pallet', flag=False):
        source['containers'].append(dict(container_id=ident, container_name=f'Container {ident}',
            container_type_name=kind, movement_status=status, last_movement_event_id=ident if status else None))
        if status:
            note = '' if decision is None else 'contents_reconciliation=' + __import__('json').dumps({'decision':decision})
            if flag: note += '; contents_review_required=true'
            source['effect_rows'].append(dict(setup_movement_event_id=ident, container_id=ident,
                event_type=status, occurred_at='2026-10-31', notes=note, stage_name='Park',
                gps_latitude=43.7, gps_longitude=-87.7))
    add(1)  # No movement is not a fault.
    add(2, 'RETURNED', 'EMPTY')
    source['effect_rows'].insert(0, dict(setup_movement_event_id=100, container_id=2, event_type='CONTAINER_MOVE',
        occurred_at='2026-10-29', notes='contents_reconciliation={"decision":"NOT_SURE"}; contents_review_required=true'))
    add(3, 'CONTAINER_MOVE', 'NOT_EMPTY', kind='Standalone Display')
    add(4, 'CONTAINER_MOVE', 'NOT_SURE', flag=True)
    add(5, 'CONTAINER_MOVE', 'EMPTY')
    source['pickup_requests'] = [dict(container_id=5, pickup_event_id=200, requested_at='2026-10-31',operator_email='crew@example.com')]
    add(6, 'CONTAINER_MOVE', 'EMPTY')
    add(7, 'CONTAINER_MOVE')  # No physical observation alone is not an exception.
    add(8, 'CONTAINER_MOVE', 'NOT_EMPTY')
    # Display verification is separate and must not turn the returned Container into a problem.
    source['displays'] = [dict(display_id=50, display_name='Unverified Display', container_id=2, position_mode='WITH_CONTAINER')]
    before = deepcopy(source)
    projected = locate_assets(source)
    counts = mail.summarize_container_snapshot(projected['containers'], source['generated_at'])
    result = mail.movement_details(source, projected)
    assert [r['name'].split(' — ')[0] for r in result['container_rows']] == ['C004','C005','C006','C008']
    assert len(result['container_inventory_rows']) == 8
    assert counts['containers_contents_review_history'] == 2
    assert counts == mail.summarize_container_snapshot(projected['containers'], source['generated_at'])
    assert source == before
    assert 'Manager correction workflow pending' not in result['container_rows'][1]['detail']
    assert 'Arrange pickup' in result['container_rows'][1]['detail']
    assert 'Review pickup readiness' in result['container_rows'][2]['detail']
    assert 'Operator selected NOT_SURE' in result['container_rows'][0]['detail']
    assert 'contents-review' not in result['container_inventory_rows'][1]['detail']
    report = mail.summarize(dict(session={'season_year':2026}, tasks=[dict(setup_session_task_id=1)]), date(2026,10,31))
    report.update(fixture_containers()); report.update(result)
    text = mail.render(mail.DEFAULT_TEMPLATE.read_text(), {'display_name':'Greg'}, report)
    html = mail.render_html(mail.DEFAULT_HTML_TEMPLATE.read_text(), {'display_name':'Greg'}, report)
    for ident in (1,2,3,7):
        assert f'C{ident:03d} — Container' not in text.split('DISPLAY LOCATION REVIEW BY CONTAINER')[0]
        assert f'C{ident:03d} — Container' not in html.split('Display location review by Container')[0]
    for ident in (4,5,6,8):
        assert f'C{ident:03d} — Container' in text and f'C{ident:03d} — Container' in html


def test_return_alone_does_not_clear_cargo_or_uncertain_contents():
    source = picture()
    source['effect_rows'][0]['notes'] = 'contents_reconciliation={"decision":"NOT_EMPTY","identify_remaining":true}'
    source['effect_rows'].append(dict(setup_movement_event_id=900, container_id=9,
        event_type='RETURNED',occurred_at='2026-10-31',notes=''))
    source['containers'][0].update(last_movement_event_id=900,movement_status='RETURNED')
    result = mail.movement_details(source,locate_assets(source))
    row = next(r for r in result['container_rows'] if r['name'].startswith('C009'))
    assert 'Returned to shop; cargo last reported — verify contents' in row['detail']
    assert 'Recorded cargo remains' in row['detail']
    source['effect_rows'][0]['notes'] = 'contents_reconciliation={"decision":"NOT_SURE"}; contents_review_required=true'
    result = mail.movement_details(source,locate_assets(source))
    assert any(r['name'].startswith('C009') and 'Operator selected NOT_SURE' in r['detail'] for r in result['container_rows'])
    source['effect_rows'][-1]['notes'] = 'contents_reconciliation={"decision":"EMPTY"}'
    result = mail.movement_details(source,locate_assets(source))
    assert not any(r['name'].startswith('C009') for r in result['container_rows'])


def test_newer_pickup_empty_confirmation_supersedes_old_cargo_but_not_later_conflict():
    source = picture()
    source['pickup_requests'] = [dict(container_id=9, pickup_event_id=11, requested_at='2026-10-30T10:00:00-05:00',
        operator_email='rhoffmann@sheboyganlights.org', stage_name='Polar Bear Playground', location_note='Polar Bear Playground')]
    result = mail.movement_details(source, locate_assets(source))
    row = next(r for r in result['container_rows'] if r['name'].startswith('C009'))
    assert 'Arrange pickup' in row['detail']
    assert 'Empty confirmed for pickup' in row['detail']
    assert 'Review remaining cargo' not in row['detail'] and 'Recorded cargo remains' not in row['detail']
    assert 'NOT_EMPTY without identifying' not in row['detail']
    assert len(row['detail'].splitlines()) <= 4
    source['effect_rows'][0]['occurred_at'] = '2026-10-31T11:00:00-05:00'
    result = mail.movement_details(source, locate_assets(source))
    row = next(r for r in result['container_rows'] if r['name'].startswith('C009'))
    assert 'contents conflict' in row['detail'] and 'Arrange pickup' not in row['detail']


def test_display_brief_groups_all_1014_gaps_without_silently_dropping_records():
    containers = {i:dict(container_name=f'Container {i}') for i in range(1,11)}
    rows = [dict(display_id=i, container_id=(i%10)+1, name=f'Display {i}', detail='Long original source detail',
                 review_reason='inferred unload — placement unverified', url=mail.record_url('DISP',i)) for i in range(1,1015)]
    original = deepcopy(rows)
    grouped = mail.grouped_display_reviews(rows,containers)
    assert len(grouped) == 10
    assert sum(r['count'] for r in grouped) == 1014
    assert sorted(i for row in grouped for i in row['display_ids']) == list(range(1,1015))
    assert rows == original
    for row in grouped:
        assert 'locate/?container_id=' in row['url']
        assert len(row['detail'].splitlines()) == 1
    route_source = (Path(__file__).resolve().parent / 'setup_locate_assets.js').read_text()
    assert ".get('container_id')" in route_source and 'Assigned displays' in route_source
    assert len(mail.rows_text(grouped)) < len(mail.rows_text(rows)) / 15
    no_parent = dict(display_id=9999,container_id=None,name='Loose Display',detail='Original',review_reason='no placement observation',url=mail.record_url('DISP',9999))
    single = mail.grouped_display_reviews([no_parent],containers)
    assert single[0]['url'] == mail.record_url('DISP',9999) and single[0]['count'] == 1
