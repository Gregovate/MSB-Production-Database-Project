"""Route candidates distinguish waypoint identities from their lookup aliases."""
import copy
import pytest
from reconcile_drawio_map import geometry_matches, local_xy


def fixture():
    coords = [[-87.73, 43.78], [-87.729, 43.78]]
    points = {'PANEL 09': {'id': 'w1', 'xy': local_xy(coords[0])},
              'PANEL-09': {'id': 'w1', 'xy': local_xy(coords[0])},
              'FC-00A': {'id': 'w2', 'xy': local_xy(coords[1])}}
    records = [{'source_id': 'test-1', 'status': 'NO_MATCHED_ROUTE',
                'network': 'INET', 'endpoints': ['PANEL-09', 'FC-00A']}]
    return {'geometry': {'type': 'LineString', 'coordinates': coords}}, points, records


def test_aliases_of_one_identity_do_not_create_false_ambiguity():
    feature, points, records = fixture()
    before = copy.deepcopy((feature, points, records))
    result = geometry_matches(feature, points, records)
    assert result['INET'][0]['start_waypoint_id'] == 'w1'
    assert result['INET'][0]['end_waypoint_id'] == 'w2'
    assert result['INET'][0]['cable_source_ids'] == ['test-1']
    assert (feature, points, records) == before


def test_distinct_coincident_identities_remain_ambiguous():
    feature, points, records = fixture()
    points['OTHER'] = dict(points['PANEL 09'], id='different-identity')
    assert geometry_matches(feature, points, records) == {}


def test_inconsistent_alias_coordinates_fail_closed():
    feature, points, records = fixture()
    points['PANEL-09']['xy'] = (0, 0)
    with pytest.raises(ValueError, match='aliases disagree'):
        geometry_matches(feature, points, records)


def test_alias_resolution_does_not_invent_missing_endpoint():
    feature, points, records = fixture()
    records[0]['endpoints'][0] = 'UNKNOWN'
    assert geometry_matches(feature, points, records) == {}
