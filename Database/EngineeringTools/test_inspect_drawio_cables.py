from inspect_drawio_cables import inventory


def test_source_preservation_rename_and_duplicate_review():
    raw = b'''<mxfile><diagram id="page"><mxGraphModel><root>
      <object id="one" Cable_ID="Cable GG-10" Network="Aux I" Waypoint_1="GG-10" Waypoint_2="PO"><mxCell edge="1"/></object>
      <object id="two" Cable_ID="Cable GG-10" Network="Aux-I"><mxCell edge="1"/></object>
      <object id="node" node_id="GG-10"><mxCell vertex="1"/></object>
    </root></mxGraphModel></diagram></mxfile>'''
    result = inventory(raw)
    first = result['cables'][0]
    assert first['source_key'] == ['page', 'one']
    assert first['source_attributes']['Waypoint_1'] == 'GG-10'
    assert first['endpoint_1'] == 'GG-11'
    assert first['network_alias_candidate'] == 'Aux-I'
    assert first['warnings']
    assert result['cables'][1]['warnings']
    assert result['nodes'][0]['current_name'] == 'GG-11'
    assert result['ready_for_database_import'] is False
