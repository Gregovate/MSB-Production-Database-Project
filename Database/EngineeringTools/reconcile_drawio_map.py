"""Build a read-only source cross-reference; never derive networks from GPX descriptions."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


def network_key(value):
    """Normalize case; only the operator-confirmed Aux-I/Aux I alias is collapsed."""
    key = value.strip().upper()
    return 'AUX-I' if key == 'AUX I' else key


def endpoint_key(value):
    """Keep source names intact, applying only the confirmed GG rename."""
    key = value.strip().upper()
    return 'GG-11' if key == 'GG-10' else key


def build(drawio_path, map_path):
    raw = drawio_path.read_bytes()
    root = ET.fromstring(raw)
    if any(d.find('mxGraphModel') is None for d in root.findall('diagram')):
        raise ValueError('Expected uncompressed draw.io XML; compressed pages need explicit decoding.')
    source = map_path.read_text(encoding='utf-8')
    data = json.loads(re.search(r'const data=(.*?);data.features.push', source).group(1))
    routes = [f['properties'] for f in data['features'] if f['properties'].get('class') == 'NET']
    records, legacy = [], []
    pairs = defaultdict(list)
    wrapped = {id(o.find('mxCell')) for o in root.findall('.//object')}
    for obj in root.findall('.//object'):
        cell = obj.find('mxCell')
        if cell is None or cell.get('edge') != '1':
            continue
        attrs = dict(obj.attrib)
        record = {'source_id': attrs['id'], 'attributes': attrs,
                  'source': cell.get('source'), 'target': cell.get('target'), 'route_ids': []}
        if not all(attrs.get(k, '').strip() for k in ('Cable_ID', 'Network', 'Waypoint_1', 'Waypoint_2')):
            legacy.append(record)
            continue
        record['network'] = network_key(attrs['Network'])
        record['endpoints'] = [endpoint_key(attrs[k]) for k in ('Waypoint_1', 'Waypoint_2')]
        record['status'] = 'NO_MATCHED_ROUTE'
        # A label/attribute disagreement is evidence needing review, not an automatic repair.
        label = re.fullmatch(r'(.+?)\s+to\s+(.+?)\s+' + re.escape(attrs['Network']), attrs['Cable_ID'], re.I)
        if label and sorted(endpoint_key(x) for x in label.groups()) != sorted(record['endpoints']):
            record['status'] = 'ENDPOINT_CONFLICT'
        records.append(record)
        if record['status'] != 'ENDPOINT_CONFLICT':
            pairs[tuple(sorted(record['endpoints']))].append(record)
    for cell in root.findall('.//mxCell'):
        if cell.get('edge') == '1' and id(cell) not in wrapped:
            legacy.append({'source_id': cell.get('id'), 'attributes': dict(cell.attrib)})
    mapped, unmatched = [], []
    # Only literal two-endpoint names are eligible. Historical narrative is never identity.
    for route in routes:
        match = re.fullmatch(r'NET\s+([A-Z]+-\d+[A-Z]?)\s+to\s+([A-Z]+-\d+[A-Z]?)', route['name'], re.I)
        candidates = pairs.get(tuple(sorted(endpoint_key(x) for x in match.groups())), []) if match else []
        if candidates:
            mapped.append({'route_id': route['id'], 'source_name': route['name'],
                           'cable_source_ids': [c['source_id'] for c in candidates],
                           'basis': 'Exact named endpoint pair; geographic correspondence requires operator review'})
            for c in candidates:
                c['route_ids'].append(route['id'])
                c['status'] = 'ENDPOINT_MATCH_REVIEW_REQUIRED'
        else:
            unmatched.append({'route_id': route['id'], 'source_name': route['name'], 'status': 'UNRESOLVED'})
    return {'format_version': 1, 'source_name': drawio_path.name,
            'source_sha256': hashlib.sha256(raw).hexdigest(),
            'gpx_snapshot': '743ead74d34767a9',
            'mapping_status': 'CANDIDATE — endpoint correspondence, not surveyed route verification',
            'network_aliases': {'Aux I': 'AUX-I', 'Aux-I': 'AUX-I'},
            'endpoint_aliases': {'GG-10': 'GG-11'},
            'cables': records, 'legacy_edges': legacy, 'mapped_routes': mapped,
            'unresolved_routes': unmatched}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('drawio', type=Path)
    parser.add_argument('map', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = build(args.drawio, args.map)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f"{len(result['cables'])} cables; {len(result['mapped_routes'])} matched routes; "
          f"{len(result['unresolved_routes'])} unresolved routes; {len(result['legacy_edges'])} legacy edges")
