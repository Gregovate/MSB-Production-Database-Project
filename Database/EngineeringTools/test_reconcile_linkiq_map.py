"""Test tester evidence preservation and authority over schematic mistakes."""
import importlib.util
import json
from pathlib import Path
import sqlite3
import sys

TOOLS = Path(__file__).parent
sys.path.insert(0, str(TOOLS))
from reconcile_linkiq_map import build, parse_name


def test_name_parser_preserves_qualifiers_and_rejects_ambiguous_endpoints():
    assert parse_name('WV 00 to WV 03 AUX-I') == (['WV-00', 'WV-03'], 'AUX-I', '')
    assert parse_name('CL-05 TO CL-07 REG RET') == (['CL-05', 'CL-07'], 'REG', 'RET')
    assert parse_name('TC-01 TO RA-08 TO RA-06 INET') is None
    assert parse_name('WV 04 TO WV-00') is None
    assert parse_name('LPFT-PS T0 WV-02 AUX-I') is None


def test_read_only_import_keeps_tests_and_uses_linkiq_for_shared_hv_track(tmp_path):
    flw = tmp_path / 'tests.flw'
    with sqlite3.connect(flw) as db:
        db.execute('CREATE TABLE Records(UUID TEXT,CableId TEXT,LengthF REAL,TimeSpan REAL,TestStatus INTEGER,Deleted TEXT,Notes TEXT,Faceplate TEXT,OutletId TEXT)')
        db.executemany('INSERT INTO Records VALUES(?,?,?,?,?,?,?,?,?)', [
            ('first','WV 00 to WV 03 AUX-I',110,1,1,'','note','WV-00',''),
            ('retest','WV 00 to WV 03 AUX-I',111,2,2,'','','',''),
            ('deleted','WV 00 to WV 03 AUX-I',112,3,1,'YES','','',''),
            ('unknown','stray cable',10,4,1,'','','','')])
    before = flw.read_bytes()
    drawio = tmp_path / 'schematic.drawio'
    drawio.write_text('<mxfile><diagram><mxGraphModel><root><object id="wrong" Cable_ID="WV-00 to WV-03 Aux I" Network="Aux I" Waypoint_1="WV-00" Waypoint_2="WV-04"><mxCell edge="1"/></object></root></mxGraphModel></diagram></mxfile>')
    coords = [[-87,43.78],[-86.9996,43.78]]
    features = [{'properties': {'id':key,'name':key},'geometry': {'type':'Point','coordinates':xy}} for key,xy in zip(['WV-00','WV-03'],coords)]
    features.append({'properties': {'id':'hv','name':'HV trench','class':'HV','desc':'Installed 2021'},'geometry':{'type':'LineString','coordinates':coords}})
    page = tmp_path / 'map.html'
    page.write_text('const data=' + json.dumps({'features':features}) + ';data.features.push')
    result = build(flw, drawio, page)
    assert flw.read_bytes() == before
    assert len(result['cables']) == 2  # Retest is evidence, not silently discarded.
    assert len(result['review_records']) == 2
    assert result['cables'][0]['test']['Notes'] == 'note'
    assert all(c['route_ids'] == ['hv'] for c in result['cables'])
    assert result['cables'][0]['drawio_matches'][0]['status'] == 'ENDPOINT_CONFLICT'
    assert result['mapped_routes'][0]['source_properties']['desc'] == 'Installed 2021'


def test_lor_snapshot_uses_latest_validated_run_and_separates_programming(tmp_path):
    import gzip
    from reconcile_linkiq_map import lor_inventory
    dump = tmp_path / 'snapshot.sql.gz'
    with gzip.open(dump, 'wt') as stream:
        stream.write('COPY lor_snap.import_run (import_run_id, run_ts, parser_validation_status) FROM stdin;\n2\t2026-10-02\tPASSED\n1\t2026-10-01\tPASSED\n3\t2026-10-03\tFAILED\n\\.\n')
        stream.write('COPY lor_snap.props (import_run_id, network, uid) FROM stdin;\n1\tAux I\tOLD\n2\tAux I\t10\n3\tAux I\tBAD\n\\.\n')
        stream.write('COPY ref.controller (controller_id, lor_network, lor_uid_start, lor_uid_count, programmed_config_verification_state, notes) FROM stdin;\n42\tRegular\t20\t1\tUNVERIFIED\tprivate note\n\\.\n')
    result = lor_inventory(dump)
    assert result['import_run_id'] == '2'
    assert result['expected_networks']['Aux I']['uids'] == ['10']
    assert result['recorded_controllers'][0]['lor_network'] == 'Regular'
    assert 'private note' not in json.dumps(result)
