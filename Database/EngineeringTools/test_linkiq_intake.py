"""Recurring intake regression: identity ambiguity, evidence changes and replay."""
from copy import deepcopy
from decimal import Decimal
from contextlib import nullcontext
from unittest.mock import patch

import pytest

from linkiq_intake import propose_test, waypoint_lookup
from site_source_db import ingest_linkiq

UID = '68b4579b-2116-4140-8f24-e7a0d170b8be'


def sample():
    return {'test_uuid': UID, 'source_appearances': [{
        'source_row': 1, 'display_cable_name': 'A TO B REG', 'deleted': 'NO',
        'payload_sha256': 'a'*64, 'test_status_code': 1,
        'test_standard': '1000BASE-T', 'length_ft': 12.0, 'record_time_span': 1,
        'original_test_id': 'old tester name', 'tested_at_local': '2026-10-12',
        'nvp': 0.68, 'tester_serial': '123', 'raw_payload': {'preserve': 'yes'},
        'project': 'MSB-Park-Network'}]}


def existing():
    return dict(evidence_sha256='a'*64, physical_site_cable_id=7,
                identity_review_status='REVIEWED', test_status_code=1,
                test_standard='1000BASE-T', length_ft=Decimal('12.00'))


def cables():
    return [dict(id=7, a=1, b=2, designation='REG', reviewed=True)]


def lookup():
    return waypoint_lookup([(1, 'A'), (2, 'B')], [])


def test_new_test_is_candidate_not_automatic_new_cable_or_retest_link():
    proposal = propose_test(sample(), lookup(), cables())
    assert proposal['cable_candidates'] == [7]
    assert proposal['status'] == 'REVIEW_REQUIRED'
    assert proposal['retained_cable_id'] is None


def test_known_reviewed_identity_retained_and_numeric_length_equal():
    assert propose_test(sample(), lookup(), cables(), existing())['status'] == 'RETAINED_REVIEWED'


def test_shared_endpoint_and_parallel_cables_remain_distinct():
    parallel = cables() + [dict(id=8, a=2, b=1, designation='REG', reviewed=True)]
    p = propose_test(sample(), lookup(), parallel, existing())
    assert p['cable_candidates'] == [7, 8]
    assert p['retained_cable_id'] == 7
    assert 'PARALLEL_CABLES_REQUIRE_REVIEW' in p['reasons']


def test_aliases_of_one_waypoint_collapse_but_other_identity_is_ambiguous():
    keys = waypoint_lookup([(1, 'A'), (2, 'B')], [(1, ' a ')])
    assert propose_test(sample(), keys, cables())['endpoint_candidates'] == [[1], [2]]
    keys['A'].add(3)
    assert 'ENDPOINT_UNRESOLVED_OR_AMBIGUOUS' in propose_test(sample(), keys, cables())['reasons']


def test_changed_evidence_and_labels_never_reassign_reviewed_cable():
    test = sample(); test['source_appearances'][0]['payload_sha256'] = 'b'*64
    p = propose_test(test, lookup(), cables(), existing(), ['OLD TO B REG'])
    assert p['retained_cable_id'] == 7
    assert {'EXISTING_TEST_PAYLOAD_CHANGED','DISPLAY_LABEL_CHANGED'} <= set(p['reasons'])


def test_metadata_only_measurement_change_requires_review():
    test = sample(); test['source_appearances'][0]['length_ft'] = 25
    p = propose_test(test, lookup(), cables(), existing())
    assert 'EXISTING_TEST_MEASUREMENT_CHANGED' in p['reasons']


def test_deleted_and_unparseable_sources_are_retained_for_review():
    test = sample(); test['source_appearances'][0].update(deleted='YES', display_cable_name='unknown')
    p = propose_test(test, lookup(), cables(), existing())
    assert {'SOURCE_DELETED','NAME_REQUIRES_REVIEW'} <= set(p['reasons'])
    assert p['retained_cable_id'] == 7


def test_project_payload_variants_not_silently_preferred():
    test = sample(); other = deepcopy(test['source_appearances'][0]); other['payload_sha256']='b'*64
    test['source_appearances'].append(other)
    assert 'SOURCE_PAYLOAD_VARIANTS' in propose_test(test, lookup(), cables())['reasons']


class IntakeConnection:
    """SQL call boundary fixture; does not claim PostgreSQL execution coverage."""
    def __init__(self, known=False):
        self.known = known
        self.statements = []
        self.rowcount = 0
    def transaction(self): return nullcontext()
    def cursor(self): return nullcontext(self)
    def execute(self, sql, params=None):
        self.statements.append((sql,params)); self.sql=sql
        self.rowcount = 0 if self.known else 1
    def fetchall(self):
        if 'canonical_label' in self.sql: return [(1,'A'),(2,'B')]
        if 'site_cable c' in self.sql: return [(7,1,2,'REG',True)]
        if 'display_cable_name' in self.sql: return [('A TO B REG',)] if self.known else []
        return []
    def fetchone(self):
        if 'SELECT EXISTS' in self.sql: return (self.known,)
        if 'evidence_sha256' in self.sql:
            return ('a'*64,7,'REVIEWED',1,'1000BASE-T',Decimal('12')) if self.known else None
        if 'RETURNING import_receipt_id' in self.sql: return (42,)
        raise AssertionError(self.sql)


@pytest.mark.parametrize('known', [False, True])
def test_import_receipt_counts_replay_and_preserves_original_evidence(tmp_path, known):
    source=tmp_path/'input.flw'; source.write_bytes(b'fixture')
    extracted=dict(sha256='a'*64, tests=[sample()], source_row_count=1,
                   unique_test_count=1, duplicate_project_appearances=0,
                   variant_measurement_conflicts=[])
    conn=IntakeConnection(known)
    with patch('site_source_db.sha256',return_value='a'*64), patch('site_source_db.extract_flw',return_value=extracted):
        result=ingest_linkiq(conn,source,'manager')
    assert result['replay'] == known
    assert result['counts']['new_tests'] == int(not known)
    assert result['counts']['known_tests'] == int(known)
    assert result['counts']['new_appearances'] == int(not known)
    assert result['counts']['retained_reviewed'] == int(known)
    assert result['import_receipt_id'] == 42
    assert any('LINKIQ_APPEARANCE' in sql and 'preserve' in params[-1] for sql,params in conn.statements)
    assert not any('UPDATE ops.linkiq_test' in sql or 'INSERT INTO ref.site_cable' in sql for sql,_ in conn.statements)


def test_source_drift_and_blank_actor_fail_before_writes(tmp_path):
    conn=IntakeConnection(); p=tmp_path/'x'
    with pytest.raises(ValueError,match='actor'): ingest_linkiq(conn,p,' ')
    with patch('site_source_db.sha256',return_value='a'*64), patch('site_source_db.extract_flw',return_value={'sha256':'b'*64}):
        with pytest.raises(ValueError,match='changed'): ingest_linkiq(conn,p,'manager')
    assert not conn.statements

from site_source_db import review_linkiq_identity
from test_site_source_db import RecordingConnection


def test_review_links_existing_cable_with_attributed_decision_only():
    conn=RecordingConnection([(None,), (7,), (52,)])
    result=review_linkiq_identity(conn,'a'*64,UID,7,'manager','Physical tag inspected')
    assert result['decision_id']==52
    updates=[sql for sql,_ in conn.statements if 'UPDATE' in sql and 'SET' in sql]
    assert len(updates)==1
    assert 'original_result' not in updates[0]
    assert any('linkiq_identity_decision' in sql and params[-1]=='Physical tag inspected'
               for sql,params in conn.statements)


@pytest.mark.parametrize('responses,error', [([(8,)],'changed'), ([(None,),None],'existing reviewed')])
def test_review_rejects_stale_binding_or_unreviewed_target(responses,error):
    conn=RecordingConnection(responses)
    with pytest.raises(ValueError,match=error):
        review_linkiq_identity(conn,'a'*64,UID,7,'manager','review')
    assert not any('INSERT' in sql or ' SET ' in sql for sql,_ in conn.statements)


def test_panel_shorthand_gps_names_and_collisions_preserve_identity():
    keys = waypoint_lookup([(1, 'PANEL A5-00'), (2, 'PANEL 10 WV-00'),
                            (3, 'Different map name'), (4, 'A5-00')],
                           [], [(3, 'GPS-NAME'), (1, '')])
    assert keys['A5-00'] == {1, 4}  # Never prefer inferred alias over real point.
    assert keys['WV-00'] == {2}
    assert keys['GPS-NAME'] == {3}
    assert keys['DIFFERENT MAP NAME'] == {3}
    assert '' not in keys
    assert 'COMMAND CENTER' not in keys  # Trailer is not an area-name alias.
