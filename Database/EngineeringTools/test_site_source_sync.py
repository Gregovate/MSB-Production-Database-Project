"""#171 regression: FLW readonly, GPX Label on Map, diagram source conservation."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from site_source_sync import (GPX, OVERLAY, sha256, extract_flw, extract_gpx,
                              gpx_roundtrip, drawio_from_database)


@pytest.fixture
def sample_gpx(tmp_path):
    p = tmp_path / 'expert.gpx'
    p.write_text('''<?xml version="1.0" encoding="utf-8"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1"
 xmlns:o="http://www.topografix.com/GPX/gpx_overlay/0/5"
 xmlns:x="urn:expertgps-specific">
 <wpt lat="43.1" lon="-87.1"><name>A5-Church</name><type>OUT-Combo</type>
  <extensions><o:label><o:label_text>A5-07/09</o:label_text><o:extensions><x:symbol>keep</x:symbol></o:extensions></o:label></extensions>
 </wpt>
 <trk><name>NET Example</name><type>Network</type><trkseg>
  <trkpt lat="43.1" lon="-87.1"/><trkpt lat="43.2" lon="-87.2"/>
 </trkseg></trk>
</gpx>''', encoding='utf-8')
    return p


def test_gpx_prefers_expertgps_map_label(sample_gpx):
    output = extract_gpx(sample_gpx)
    assert output['waypoints'][0]['map_label'] == 'A5-07/09'
    assert output['waypoints'][0]['garmin_name'] == 'A5-Church'
    assert output['tracks'][0]['segments'][0][1]['lon'] == '-87.2'


def test_gpx_roundtrip_preserves_garmin_name_other_extensions_and_tracks(sample_gpx, tmp_path):
    output_path = tmp_path / 'new.gpx'
    output = gpx_roundtrip(sample_gpx, {
        'base_source_sha256': sha256(sample_gpx),
        'approved_edits': [{ 'previous_map_label': 'A5-07/09',
                             'previous_latitude': '43.1', 'previous_longitude': '-87.1',
                             'map_label': 'A5-07/09-FIELD'}],
    }, output_path)
    assert output['updated'] == 1
    assert extract_gpx(sample_gpx)['waypoints'][0]['map_label'] == 'A5-07/09'
    assert extract_gpx(output_path)['waypoints'][0]['map_label'] == 'A5-07/09-FIELD'
    assert extract_gpx(output_path)['waypoints'][0]['garmin_name'] == 'A5-Church'
    assert extract_gpx(output_path)['tracks'] == extract_gpx(sample_gpx)['tracks']
    assert 'keep' in output_path.read_text()


def test_gpx_refuses_conflicting_source(sample_gpx, tmp_path):
    with pytest.raises(ValueError, match='conflict review required'):
        gpx_roundtrip(sample_gpx, {'base_source_sha256': '0' * 64}, tmp_path / 'new.gpx')
    assert not (tmp_path / 'new.gpx').exists()


def test_reviewed_lp08_cl00_track_name_roundtrips_without_moving_survey_points(sample_gpx, tmp_path):
    """Track 103 in the actual map is source evidence, not a cable count."""
    source = tmp_path / 'two-tracks.gpx'
    old = 'NET FT-SS Reg, Spare, Aux-A, Aux-B, '
    source.write_text(sample_gpx.read_text(encoding='utf-8').replace(
        '</gpx>', '''<trk><name>NET FT-SS Reg, Spare, Aux-A, Aux-B, </name>
        <type>Network</type><desc>TBD 7 Cables</desc><trkseg>
        <trkpt lat="43.77693051" lon="-87.74624455"/>
        <trkpt lat="43.77678431" lon="-87.74701645"/>
        </trkseg></trk></gpx>'''), encoding='utf-8')
    before = extract_gpx(source)
    source_hash = sha256(source)
    out = tmp_path / 'maintained.gpx'
    receipt = gpx_roundtrip(source, {
        'base_source_sha256': source_hash,
        'approved_edits': [],
        'approved_track_edits': [{
            'source_ordinal': 2, 'previous_track_name': old,
            'track_name': 'NET LP-08 to CL-00',
        }],
    }, out)
    after = extract_gpx(out)
    assert receipt['updated_tracks'] == 1
    assert receipt['updated'] == 0
    assert before['tracks'][1]['name'] == old
    assert after['tracks'][1]['name'] == 'NET LP-08 to CL-00'
    assert after['tracks'][0] == before['tracks'][0]
    assert after['tracks'][1]['segments'] == before['tracks'][1]['segments']
    assert after['tracks'][1]['description'] == 'TBD 7 Cables'
    assert after['tracks'][1]['type'] == 'Network'
    assert source_hash == sha256(source)
    assert 'TBD 7 Cables' in out.read_text(encoding='utf-8')
    assert 'NET FT-SS Reg, Spare, Aux-A, Aux-B, ' in source.read_text(encoding='utf-8')


@pytest.mark.parametrize('ordinal,prior', [
    (1, 'NET FT-SS Reg, Spare, Aux-A, Aux-B, '),
    (2, 'NET FT-SS Reg, Spare, Aux-A, Aux-B, '),
])
def test_wrong_track_binding_fails_without_writing_any_output(sample_gpx, tmp_path, ordinal, prior):
    # The one-track fixture is NET Example, so both old-name/ordinal
    # mismatches must be rejected without writing any GPX.
    result = tmp_path / f'bad-track-{ordinal}.gpx'
    with pytest.raises(ValueError, match='source ordinal|name changed'):
        gpx_roundtrip(sample_gpx, {
            'base_source_sha256': sha256(sample_gpx),
            'approved_edits': [],
            'approved_track_edits': [{
                'source_ordinal': ordinal,
                'previous_track_name': prior,
                'track_name': 'NET LP-08 to CL-00',
            }],
        }, result)
    assert not result.exists()


def test_gpx_duplicate_labels_fail(tmp_path, sample_gpx):
    content = sample_gpx.read_text()
    # Use two identically-labelled points; never collapse co-located equipment.
    content = content.replace('</wpt>', '</wpt><wpt lat="43.2" lon="-87.2"><extensions><o:label><o:label_text>A5-07/09</o:label_text></o:label></extensions></wpt>')
    p = tmp_path / 'dupe.gpx'; p.write_text(content)
    with pytest.raises(ValueError, match='Ambiguous GPX map labels'):
        extract_gpx(p)


def test_drawio_patch_only_bound_attributes(tmp_path):
    p = tmp_path / 'drawio.xml'; dest = tmp_path / 'out.drawio'
    p.write_text('''<mxfile><diagram><mxGraphModel><root>
<object id="cable-a" Cable_ID="OLD" Waypoint_1="A" Waypoint_2="B" Network="REG" Feet="110" Speed="1000"><mxCell edge="1" style="red"><mxGeometry as="geometry"/></mxCell></object>
</root></mxGraphModel></diagram></mxfile>''')
    result = drawio_from_database(p, {'base_source_sha256': sha256(p),
        'cables': [{'drawio_object_id': 'cable-a', 'fields': {
            'Cable_ID': 'A to B REG', 'Feet': 112}}]}, dest)
    obj = ET.parse(dest).getroot().find('.//object')
    assert obj.get('Cable_ID') == 'A to B REG'
    assert obj.get('Feet') == '112'
    assert obj.get('Network') == 'REG'
    assert obj.find('mxCell').get('style') == 'red'
    assert p.read_text().find('Cable_ID="OLD"') > 0
    assert result['updated_cable_objects'] == 1


def test_drawio_stops_on_unknown_cable(tmp_path):
    p = tmp_path / 'f'; p.write_text('<mxfile/>')
    with pytest.raises(ValueError, match='Missing or duplicate'):
        drawio_from_database(p, {'base_source_sha256': sha256(p), 'cables': [{'drawio_object_id': 'X', 'fields': {'Feet': 10}}]}, tmp_path / 'other')


def test_linkiq_uuid_and_original_name_are_distinct(tmp_path):
    p = tmp_path / 'mini.flw'
    conn = sqlite3.connect(p)
    conn.executescript('''CREATE TABLE Records (UUID TEXT, Hash INT, CableId TEXT, Project TEXT, Deleted TEXT, TimeSpan REAL, TestStatus INT, Standard TEXT, LengthF REAL, LengthM REAL, TesterType TEXT, Operator TEXT);
CREATE TABLE RecordData (Hash INT, BinRec BLOB);''')
    uuid1 = '68b4579b-2116-4140-8f24-e7a0d170b8be'
    data = json.dumps({'metadata': {'uuid': uuid1, 'testId': 'FCLP3 to FC-00 Reg', 'timestamp': '2023-11-01T07:03:42'}, 'settings': {'nvp': 0.68}, 'sysinfo': {'serialNumber': '123'}}).encode()
    conn.executemany('INSERT INTO Records VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', [
        (uuid1, 1, 'LPFC-03 TO FC-00 REG', 'MSB-Park-Network', 'NO', 1, 1, '1000BASE-T', 120, 36.5, 'LinkIQ', 'Rich'),
        (uuid1, 2, 'FCLP3 to FC-00 Reg', 'Park Network', 'NO', 1, 1, '1000BASE-T', 120, 36.5, 'LinkIQ', 'Rich')])
    conn.executemany('INSERT INTO RecordData VALUES (?,?)', [(1,data),(2,data)])
    # LinkWare operator fields are real evidence and must not disappear from
    # the refreshed browser map. Synthetic older schemas without the columns
    # are handled separately by the fail-closed extractor tests.
    conn.executescript("""ALTER TABLE Records ADD COLUMN Notes TEXT;
ALTER TABLE Records ADD COLUMN Faceplate TEXT;
ALTER TABLE Records ADD COLUMN OutletId TEXT;
UPDATE Records SET Notes='Operator verified', Faceplate='FC-00',
                   OutletId='2' WHERE Project='MSB-Park-Network';""")
    conn.commit();conn.close()
    baseline = sha256(p)
    result = extract_flw(p)
    assert result['source_row_count'] == 2
    assert result['unique_test_count'] == 1
    assert result['duplicate_project_appearances'] == 1
    test = result['tests'][0]
    assert test['preferred_display_cable_name'] == 'LPFC-03 TO FC-00 REG'
    assert all(v['original_test_id'] == 'FCLP3 to FC-00 Reg' for v in test['source_appearances'])
    assert test['cable_identity_status'] == 'UNMATCHED'
    assert test['source_appearances'][0]['notes'] == 'Operator verified'
    assert test['source_appearances'][0]['faceplate'] == 'FC-00'
    assert test['source_appearances'][0]['outlet_id'] == '2'
    assert sha256(p) == baseline


def test_linkiq_fails_closed_on_mismatched_uuid(tmp_path):
    p = tmp_path / 'bad.flw'; conn = sqlite3.connect(p)
    conn.executescript('''CREATE TABLE Records (UUID TEXT, Hash INT, CableId TEXT, Project TEXT, Deleted TEXT, TimeSpan REAL, TestStatus INT, Standard TEXT, LengthF REAL, LengthM REAL, TesterType TEXT, Operator TEXT);
CREATE TABLE RecordData (Hash INT, BinRec BLOB);''')
    conn.execute('INSERT INTO Records VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', ('wrong',1,'a','MSB','NO',0,1,'',10,3,'',''))
    conn.execute('INSERT INTO RecordData VALUES (?,?)', (1,json.dumps({'metadata':{'uuid':'other'}}).encode()))
    conn.commit();conn.close()
    with pytest.raises(ValueError, match='Test UUID mismatch'):
        extract_flw(p)


def test_actual_uploaded_sources_if_present():
    base=Path('/mnt/data')
    gps=base/'2026_msb_FRESH_START_CLEANED_2026-10-06(20261011-023933).gpx'
    flw=base/'LinkIQ Data Import for DB with corrected names(5).flw'
    if not (gps.exists() and flw.exists()):
        pytest.skip('operator source files not in test environment')
    gp=extract_gpx(gps)
    assert len(gp['waypoints']) == 233
    assert len(gp['tracks']) == 181
    assert next(w for w in gp['waypoints'] if w['map_label']=='A5-07/09')['garmin_name']
    source_hash = sha256(flw)
    x=extract_flw(flw)
    assert x['source_row_count']==684
    assert x['unique_test_count']==476
    assert x['duplicate_project_appearances']==208
    assert not x['variant_measurement_conflicts']
    assert sha256(flw) == source_hash

from site_source_sync import compare_three_way

def test_three_way_merges_non_overlapping_edits():
    base = {'map_label':'WV-04', 'latitude':'43.2', 'longitude':'-87.2','type':'OUT-Combo'}
    gpx = {**base, 'latitude':'43.200001'}
    db = {**base,'map_label':'WV-04-NEW'}
    result=compare_three_way(base,gpx,db)
    assert result['status']=='MERGEABLE'
    assert result['merged']['map_label']=='WV-04-NEW'
    assert result['merged']['latitude']=='43.200001'

def test_three_way_conflicting_rename_fails_closed():
    base = {'map_label':'A5-CHURCH'}
    result=compare_three_way(base,{'map_label':'A5-07/09'},{'map_label':'A5-09/07'},fields=('map_label',))
    assert result['status']=='CONFLICT'
    assert result['merged'] is None

from site_source_db import export_waypoint_projection, export_schematic_projection

class FakeCursor:
    def __init__(self, rows, track_rows=None):
        self.rows=rows
        self.track_rows=track_rows or []
        self.statements=[]
        self.reads=0
    def __enter__(self): return self
    def __exit__(self,*args): pass
    def execute(self, statement,params): self.statements.append((statement,params))
    def fetchall(self):
        self.reads+=1
        return self.rows if self.reads==1 else self.track_rows

class FakeConnection:
    def __init__(self, rows, track_rows=None): self.cur=FakeCursor(rows, track_rows)
    def cursor(self): return self.cur

def test_db_gpx_projection_does_not_reserialize_unchanged_coordinates():
    baseline='9'*64
    conn=FakeConnection([('A5-07/09','43.77795200','-87.74913300',
                          'A5-07/09','43.777952','-87.749133'),
                         ('WW-15','43.1','-87.1','WW-15-REVIEWED','43.1','-87.1')])
    result=export_waypoint_projection(conn,baseline)
    assert len(result['approved_edits'])==1
    assert result['approved_edits'][0]['map_label']=='WW-15-REVIEWED'
    assert 'latitude' not in result['approved_edits'][0]

def test_db_track_name_projection_uses_original_ordinal_and_preserves_source_text():
    baseline='9'*64
    old='NET FT-SS Reg, Spare, Aux-A, Aux-B, '
    db=FakeConnection([], track_rows=[(102, 'NET same label', 'NET same label'),
                                      (103, old, 'NET LP-08 to CL-00')])
    result=export_waypoint_projection(db,baseline)
    assert result['approved_edits'] == []
    assert result['approved_track_edits'] == [{
        'source_ordinal': 103,
        'previous_track_name': old,
        'track_name': 'NET LP-08 to CL-00',
    }]
    assert len(db.cur.statements)==2
    assert db.cur.statements[1][1]==(baseline,)
    assert 'ops.site_source_observation' in db.cur.statements[1][0]


def test_db_track_export_refuses_missing_original_observation():
    db=FakeConnection([],track_rows=[(103,None,'NET LP-08 to CL-00')])
    with pytest.raises(ValueError, match='lacks its original GPX source observation'):
        export_waypoint_projection(db,'9'*64)


def test_db_schematic_export_does_not_assign_speed_from_test_standard():
    conn=FakeConnection([('Cable_WV-10','WW-10','WW-15','REG',None,140,'1000BASE-T')])
    result=export_schematic_projection(conn,'Park-SuperB','a'*64)
    fields=result['cables'][0]['fields']
    assert fields['Cable_ID']=='WW-10 TO WW-15 REG'
    assert fields['Feet']=='140'
    assert 'Speed' not in fields

from site_source_db import stage_expertgps, ingest_linkiq

class RecordingCursor:
    def __init__(self): self.executions=[]
    def __enter__(self): return self
    def __exit__(self,*args): pass
    def execute(self, sql, args=None):
        self.executions.append((sql,args)); self.sql=sql; self.rowcount=1
    def fetchall(self): return []
    def fetchone(self):
        if 'SELECT EXISTS' in self.sql: return (False,)
        if 'RETURNING import_receipt_id' in self.sql: return (1,)
        return None

class RecordingConnection:
    def __init__(self): self.cursor_object=RecordingCursor(); self.transactions=0
    def cursor(self): return self.cursor_object
    def transaction(self):
        class Tx:
            def __init__(self, connection): self.connection=connection
            def __enter__(self): self.connection.transactions+=1;return self
            def __exit__(self,*args): pass
        return Tx(self)


def test_gpx_writer_stages_without_mutating_reference(sample_gpx):
    conn=RecordingConnection()
    result=stage_expertgps(conn,sample_gpx,'msb-reviewer')
    assert result['waypoints']==1 and result['tracks']==1
    assert conn.transactions==1
    statements=[s for s,_ in conn.cursor_object.executions]
    assert len(statements)==4
    assert all('ON CONFLICT' in s for s in statements)
    assert not any('UPDATE ref.site_waypoint' in s for s in statements)


def test_linkiq_writer_keeps_one_test_and_two_project_appearances(tmp_path):
    db=tmp_path/'import.flw';c=sqlite3.connect(db)
    c.executescript('''CREATE TABLE Records (UUID TEXT, Hash INT, CableId TEXT, Project TEXT, Deleted TEXT, TimeSpan REAL, TestStatus INT, Standard TEXT, LengthF REAL, LengthM REAL, TesterType TEXT, Operator TEXT);
CREATE TABLE RecordData (Hash INT, BinRec BLOB);''')
    uid='68b4579b-2116-4140-8f24-e7a0d170b8be'
    payload=json.dumps({'metadata':{'uuid':uid,'testId':'FCLP3 to FC-00 Reg'},'settings':{'nvp':0.68}}).encode()
    c.executemany('INSERT INTO Records VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',[
        (uid,1,'LPFC-03 TO FC-00 REG','MSB-Park-Network','NO',1,1,'1000BASE-T',120,36.5,'LinkIQ','Rich'),
        (uid,2,'FCLP3 to FC-00 Reg','Park Network','NO',1,1,'1000BASE-T',120,36.5,'LinkIQ','Rich')])
    c.executemany('INSERT INTO RecordData VALUES (?,?)',[(1,payload),(2,payload)])
    c.commit();c.close(); original_sha=sha256(db)
    conn=RecordingConnection()
    result=ingest_linkiq(conn,db,'msb-reviewer')
    assert conn.transactions==1
    assert result['unique_uuid_tests']==1
    assert result['project_appearance_duplicates']==1
    statements=[s for s,_ in conn.cursor_object.executions]
    assert sum('INSERT INTO ops.linkiq_test\n' in s for s in statements)==1
    assert sum('INSERT INTO ops.linkiq_test_appearance' in s for s in statements)==2
    assert result['counts']['new_tests']==1
    assert result['counts']['new_appearances']==2
    assert not any('UPDATE ops.linkiq_test' in s or 'UPDATE ref.site_cable' in s for s in statements)
    assert sha256(db)==original_sha


@pytest.fixture
def revision_case(sample_gpx):
    from copy import deepcopy
    base = extract_gpx(sample_gpx)
    incoming = deepcopy(base)
    incoming['sha256'] = 'f' * 64
    maintained = {'baseline_sha256': base['sha256'], 'revision': 12,
                  'waypoints': [dict(base['waypoints'][0], id=41, baseline_ordinal=1, aliases=[])],
                  'tracks': [dict(base['tracks'][0], id=51, baseline_ordinal=1)]}
    return base, incoming, maintained, {'waypoints': {'1': 41}, 'tracks': {'1': 51}}


def run_preview(case):
    from site_source_sync import preview_gpx_revision
    return preview_gpx_revision(*case, expected_sha='f' * 64)


def test_revision_preview_preserves_db_edits_and_retains_rename_alias(revision_case):
    base, incoming, db, decisions = revision_case
    incoming['waypoints'][0]['map_label'] = 'Corrected label'
    db['waypoints'][0]['comment'] = 'Reviewed in database'
    result = run_preview(revision_case)
    point = result['changes'][0]
    assert result['status'] == 'REVIEW_REQUIRED'
    assert point['retain_alias'] == 'A5-07/09'
    assert point['after']['comment'] == 'Reviewed in database'
    assert point['after']['map_label'] == 'Corrected label'
    assert point['preserved_database_fields'] == ['comment']
    assert result == run_preview(revision_case)
    assert db['waypoints'][0]['map_label'] == 'A5-07/09'


def test_revision_preview_reports_concurrent_coordinates(revision_case):
    revision_case[1]['waypoints'][0]['latitude'] = '43.3'
    revision_case[2]['waypoints'][0]['latitude'] = '43.4'
    result = run_preview(revision_case)
    assert result['status'] == 'HOLD'
    assert result['conflicts'][0]['details']['latitude']['database'] == '43.4'


def test_track_replacement_keeps_identity_and_before_geometry(revision_case):
    from copy import deepcopy
    original = deepcopy(revision_case[0]['tracks'][0]['segments'])
    revision_case[1]['tracks'][0]['segments'][0][0]['lat'] = '43.11'
    result = run_preview(revision_case)
    track = result['changes'][1]
    assert track['target_id'] == 51
    assert track['action'] == 'UPDATE'
    assert track['before']['segments'] == original
    assert track['after']['segments'] != original
    assert revision_case[0]['tracks'][0]['segments'] == original


def test_missing_track_retained_never_deleted(revision_case):
    revision_case[1]['tracks'] = []
    revision_case[3]['tracks'] = {}
    result = run_preview(revision_case)
    assert result['status'] == 'HOLD'
    assert result['retained'] == [{'kind': 'tracks', 'id': 51, 'reason': 'UNMAPPED_EXISTING_RETAINED'}]


def test_new_waypoint_collides_with_historical_alias(revision_case):
    from copy import deepcopy
    new = deepcopy(revision_case[1]['waypoints'][0])
    new.update(ordinal=2, map_label='old label')
    revision_case[1]['waypoints'].append(new)
    revision_case[2]['waypoints'][0]['aliases'] = ['Old Label']
    revision_case[3]['waypoints']['2'] = 'NEW'
    result = run_preview(revision_case)
    assert result['status'] == 'HOLD'
    assert result['conflicts'][0]['reason'] == 'LABEL_OR_ALIAS_COLLISION'


def test_source_reorder_without_decisions_never_guesses_identity(revision_case):
    revision_case[1]['waypoints'][0]['ordinal'] = 9
    revision_case[3]['waypoints'] = {}
    result = run_preview(revision_case)
    assert result['conflicts'][0]['reason'] == 'IDENTITY_REVIEW_REQUIRED'
    assert result['retained'][0]['id'] == 41


def test_repeated_preview_unchanged_and_revision_bound(revision_case):
    first = run_preview(revision_case)
    assert all(c['action'] == 'UNCHANGED' for c in first['changes'])
    revision_case[2]['revision'] += 1
    assert run_preview(revision_case)['preview_sha256'] != first['preview_sha256']


def test_wrong_approved_hash_rejected(revision_case):
    revision_case[1]['sha256'] = 'a' * 64
    with pytest.raises(ValueError, match='expected SHA256'):
        run_preview(revision_case)


def test_extractor_retains_symbols_and_unknown_extensions(sample_gpx):
    sample_gpx.write_text(sample_gpx.read_text().replace('<type>OUT-Combo</type>',
                         '<type>OUT-Combo</type><sym>msb/outlet</sym>'))
    point = extract_gpx(sample_gpx)['waypoints'][0]
    assert point['symbol'] == 'msb/outlet'
    assert 'urn:expertgps-specific' in point['source_xml']
    assert 'keep' in point['source_xml']


def test_extractor_hash_is_of_parsed_bytes(sample_gpx, monkeypatch):
    import site_source_sync
    expected = hashlib.sha256(sample_gpx.read_bytes()).hexdigest()
    monkeypatch.setattr(site_source_sync, 'sha256', lambda p: 'wrong second read')
    assert extract_gpx(sample_gpx)['sha256'] == expected


@pytest.mark.parametrize('value', ['nan', '91', '-91', 'inf'])
def test_extractor_rejects_invalid_waypoints(sample_gpx, value):
    sample_gpx.write_text(sample_gpx.read_text().replace('lat="43.1"', f'lat="{value}"'))
    with pytest.raises(ValueError, match='WGS84'):
        extract_gpx(sample_gpx)


def test_complete_document_roundtrip_including_unprojected_content(sample_gpx, tmp_path):
    """Routes, root metadata, namespace-valued attrs, comments and PIs survive."""
    raw = sample_gpx.read_text().replace('<wpt ', '''<!--source comment--><?expertgps preserve?>
 <metadata><link href="https://example.test/a"><text>metadata</text></link></metadata>
 <rte><name>unprojected route</name><rtept lat="43" lon="-87"><ele>123</ele></rtept></rte>
 <extensions><x:unknown xmlns:q="urn:custom" kind="q:Thing"><![CDATA[raw <value>]]></x:unknown></extensions>
 <wpt ''')
    sample_gpx.write_text(raw)
    no_op = tmp_path / 'unchanged.gpx'
    receipt = gpx_roundtrip(sample_gpx, {'base_source_sha256': sha256(sample_gpx)}, no_op)
    assert receipt['byte_identical'] and no_op.read_bytes() == sample_gpx.read_bytes()
    out = tmp_path / 'edited.gpx'
    receipt = gpx_roundtrip(sample_gpx, {
        'base_source_sha256': sha256(sample_gpx),
        'approved_edits': [{'previous_map_label': 'A5-07/09', 'previous_latitude': '43.1',
                            'previous_longitude': '-87.1', 'map_label': 'Corrected'}]}, out)
    from xml.dom import minidom
    from site_source_sync import _dom_signature
    expected = minidom.parseString(raw)
    label = expected.getElementsByTagNameNS(OVERLAY[1:-1], 'label_text')[0]
    label.firstChild.data = 'Corrected'
    assert _dom_signature(expected) == _dom_signature(minidom.parseString(out.read_bytes()))
    assert receipt['whole_document_preserved']
    assert sample_gpx.read_text() == raw


def test_export_refuses_existing_output_and_unsupported_edit(sample_gpx, tmp_path):
    out = tmp_path / 'reviewed.gpx'; out.write_bytes(b'keep reviewed result')
    projection = {'base_source_sha256': sha256(sample_gpx)}
    with pytest.raises(ValueError, match='existing GPX output'):
        gpx_roundtrip(sample_gpx, projection, out)
    assert out.read_bytes() == b'keep reviewed result'
    projection['approved_track_edits'] = [{'segments': []}]
    with pytest.raises(ValueError, match='Unsupported GPX track'):
        gpx_roundtrip(sample_gpx, projection, tmp_path / 'bad.gpx')
    assert not (tmp_path / 'bad.gpx').exists()


def test_invalid_export_coordinate_does_not_leave_output(sample_gpx, tmp_path):
    output = tmp_path / 'invalid.gpx'
    with pytest.raises(ValueError, match='WGS84'):
        gpx_roundtrip(sample_gpx, {'base_source_sha256': sha256(sample_gpx),
            'approved_edits': [{'previous_map_label': 'A5-07/09', 'previous_latitude': '43.1',
                               'previous_longitude': '-87.1', 'latitude': 'nan'}]}, output)
    assert not output.exists()
