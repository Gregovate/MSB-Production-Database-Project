"""Read LinkIQ SQLite evidence without modifying tests or source geography.

This read-only candidate is an import bridge to #230 reference editing, not a
replacement for permanent cable IDs. Tester UUID identifies a test record only.
"""
import argparse
from collections import defaultdict
import hashlib
import gzip
import json
import math
from pathlib import Path
import re
import sqlite3
import xml.etree.ElementTree as ET

from reconcile_drawio_map import build as drawio_build, geometry_matches, local_xy, waypoint_keys


def endpoint(value):
    """Normalize spacing in waypoint codes; retain the original in attributes."""
    value = ' '.join(value.upper().split())
    value = re.sub(r'^([A-Z]+) (\d+[A-Z]?)$', r'\1-\2', value)
    return {'GG-10': 'GG-11', 'SW': 'SW-01'}.get(value, value)


def parse_name(name):
    """Accept two explicit endpoints and a recognized network/spare suffix.

    Multiple TOs, missing networks and typos remain visible for reconciliation.
    Suffixes such as REPAIR/RET/1 are preserved; they do not create cable IDs.
    """
    match = re.fullmatch(r'(.+?)\s+TO\s+(.+?)\s+(AUX[- ][A-Z0-9]+|INET|E1\.31|REG|SPARE(?:[- ]\d+)?|WIFI|LINE-?\d+)(?:\s+(.*))?', name.strip(), re.I)
    if not match or re.search(r'\bTO\b', match[1] + ' ' + match[2], re.I):
        return None
    a, b, network, qualifier = match.groups()
    network = network.upper()
    if network == 'AUX I':
        network = 'AUX-I'
    return [endpoint(a), endpoint(b)], network, qualifier or ''


def lor_inventory(sql_path):
    """Read selected COPY fields only; never execute/restore the supplied dump.

    Expected LOR assignments and recorded controller programming stay separate.
    The snapshot date/run is shown because this is not a live database query.
    """
    tables = defaultdict(list)
    allowed = {'lor_snap.import_run', 'lor_snap.props', 'lor_snap.sub_props',
               'lor_snap.dmx_channels', 'ref.controller'}
    active = None
    with gzip.open(sql_path, 'rt', encoding='utf-8') as stream:
        for line in stream:
            if line.startswith('COPY '):
                match = re.match(r'COPY (\S+) \((.*?)\) FROM stdin;', line)
                active = match[1] if match and match[1] in allowed else None
                if active:
                    columns = match[2].split(', ')
            elif line.rstrip('\n') == r'\.':
                active = None
            elif active:
                values = [None if value == r'\N' else value for value in line.rstrip('\n').split('\t')]
                if len(values) != len(columns):
                    raise ValueError('Unexpected COPY field count')
                tables[active].append(dict(zip(columns, values)))
    runs = [r for r in tables['lor_snap.import_run'] if r['parser_validation_status'] == 'PASSED']
    latest = max(runs, key=lambda r: (r['run_ts'], int(r['import_run_id'])))
    networks = defaultdict(lambda: {'props': 0, 'sub_props': 0, 'dmx_channels': 0, 'uids': set(), 'universes': set()})
    for table in ('props', 'sub_props', 'dmx_channels'):
        for record in tables['lor_snap.' + table]:
            if record['import_run_id'] != latest['import_run_id'] or not record.get('network'):
                continue
            target = networks[record['network']]
            target[table] += 1
            if record.get('uid'):
                target['uids'].add(record['uid'])
            if record.get('start_universe'):
                target['universes'].add(record['start_universe'])
    return {'source_name': sql_path.name, 'import_run_id': latest['import_run_id'], 'run_ts': latest['run_ts'],
        'expected_networks': {n: {k: sorted(v) if isinstance(v, set) else v for k, v in values.items()} for n, values in sorted(networks.items())},
        'recorded_controllers': [{k: r[k] for k in ('controller_id', 'lor_network', 'lor_uid_start', 'lor_uid_count', 'programmed_config_verification_state')} for r in tables['ref.controller']]}


def build(flw, drawio, page):
    comparison = drawio_build(drawio, page)
    data = json.loads(re.search(r'const data=(.*?);data.features.push', page.read_text()).group(1))
    records, rejected = [], []
    # URI read-only prevents even accidental changes to the tester database.
    with sqlite3.connect(flw.resolve().as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        for row in db.execute('SELECT UUID,CableId,LengthF,TimeSpan,TestStatus,Deleted,Notes,Faceplate,OutletId FROM Records ORDER BY UUID'):
            raw = dict(row)
            parsed = parse_name(raw['CableId'])
            if str(raw['Deleted']).upper() == 'YES' or not parsed:
                rejected.append({'attributes': raw, 'reason': 'SOURCE_DELETED' if str(raw['Deleted']).upper() == 'YES' else 'NAME_REQUIRES_REVIEW'})
                continue
            endpoints, network, qualifier = parsed
            records.append({'source_id': raw['UUID'], 'network': network, 'endpoints': endpoints,
                'status': 'NO_MATCHED_ROUTE', 'route_ids': [], 'test': raw,
                'attributes': {'Cable_ID': raw['CableId'], 'Network': network,
                    'Waypoint_1': endpoints[0], 'Waypoint_2': endpoints[1], 'Feet': raw['LengthF'], 'Qualifier': qualifier}})
    candidates = defaultdict(list)
    for feature in data['features']:
        if feature.get('geometry', {}).get('type') != 'Point':
            continue
        for key in waypoint_keys(feature['properties']['name']):
            candidates[key].append({'id': feature['properties']['id'], 'source_name': feature['properties']['name'],
                'xy': local_xy(feature['geometry']['coordinates'])})
    points = {k: v[0] for k, v in candidates.items() if len(v) == 1}
    # Screen all geographic line classes: network cables can share an HV trench.
    routes = [f for f in data['features'] if f.get('geometry', {}).get('type') in ('LineString', 'MultiLineString')]
    endpoint_keys = {k for r in records for k in r['endpoints']}
    route_points = {k: v for k, v in points.items() if k in endpoint_keys}
    mapped, unresolved = [], []
    for feature in routes:
        evidence = geometry_matches(feature, route_points, records)
        ids = {sid for paths in evidence.values() for p in paths for sid in p['cable_source_ids']}
        route = {'route_id': feature['properties']['id'], 'source_name': feature['properties']['name'],
                 'layer': feature['properties'].get('class'), 'source_properties': feature['properties'],
                 'geometry_length_ft': round(sum(math.dist(local_xy(a), local_xy(b))
                    for line in ([feature['geometry']['coordinates']] if feature['geometry']['type'] == 'LineString' else feature['geometry']['coordinates'])
                    for a, b in zip(line, line[1:])), 1)}
        if ids:
            route.update(cable_source_ids=sorted(ids), network_evidence=evidence,
                basis='LinkIQ endpoints/network and GPX waypoint proximity; geographic review required')
            mapped.append(route)
            for record in records:
                if record['source_id'] in ids:
                    record['route_ids'].append(route['route_id'])
                    record['status'] = 'ROUTE_CANDIDATE_REVIEW_REQUIRED'
        else:
            unresolved.append(route)
    # Keep conflicting schematic entries available for correction, never as the
    # authority that overwrites a tester endpoint or assigns a cable network.
    for record in records:
        record['drawio_matches'] = [c for c in comparison['cables'] if c['network'] == record['network'] and
            (sorted(c['endpoints']) == sorted(record['endpoints']) or
             (parse_name(c['attributes']['Cable_ID']) or (None,))[0] == record['endpoints'])]
    devices = []
    for obj in ET.parse(drawio).findall('.//object'):
        cell = obj.find('mxCell')
        if cell is None or cell.get('vertex') != '1':
            continue
        attrs = dict(obj.attrib)
        point = points.get(endpoint(attrs.get('node_id', '')))
        devices.append({'source_id': attrs['id'], 'attributes': attrs,
            'waypoint_id': point['id'] if point else None,
            'connections': [c['source_id'] for c in comparison['cables'] + comparison['legacy_edges']
                if attrs['id'] in (c.get('source'), c.get('target'))]})
    return {'format_version': 1, 'source_kind': 'LinkIQ', 'source_name': flw.name,
        'source_sha256': hashlib.sha256(flw.read_bytes()).hexdigest(), 'gpx_snapshot': comparison['gpx_snapshot'],
        'screen_radius_ft': comparison['screen_radius_ft'], 'cables': records,
        'mapped_routes': mapped, 'unresolved_routes': unresolved, 'legacy_edges': comparison['legacy_edges'],
        'devices': devices, 'review_records': rejected, 'drawio_cables': comparison['cables'],
        'waypoint_lookup': {k: {a: b for a, b in v.items() if a != 'xy'} for k, v in points.items()}}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('flw', 'drawio', 'map', 'output'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--lor-sql', type=Path)
    args = parser.parse_args()
    result = build(args.flw, args.drawio, args.map)
    if args.lor_sql:
        result['lor_inventory'] = lor_inventory(args.lor_sql)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: len(result[k]) for k in ('cables', 'mapped_routes', 'unresolved_routes', 'review_records')}))
