"""Build a read-only source cross-reference; never derive networks from GPX descriptions."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
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


# This radius screens possible source correspondences only. It is NOT a survey
# accuracy, clearance, locate threshold, or an authorization to alter geometry.
SCREEN_RADIUS_FT = 30.0


def local_xy(coordinates):
    """Approximate local feet for screening WGS84 browser geometry, never storage."""
    lon, lat = coordinates[:2]
    return lon * math.cos(math.radians(43.78)) * 364000, lat * 364000


def line_position(point, line):
    """Return shortest screen distance and distance along existing source line."""
    best = (math.inf, 0.0)
    start = 0.0
    for a, b in zip(line, line[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        fraction = max(0, min(1, ((point[0]-a[0])*dx + (point[1]-a[1])*dy) / length**2)) if length else 0
        distance = math.dist(point, (a[0]+fraction*dx, a[1]+fraction*dy))
        if distance < best[0]:
            best = (distance, start + fraction*length)
        start += length
    return best


def waypoint_keys(name):
    """Expose literal panel/code spellings; these are source lookup candidates."""
    key = endpoint_key(name)
    keys = {key}
    if re.fullmatch(r'PANEL \d+', key):
        keys.add(key.replace(' ', '-'))
    if key.startswith('PANEL '):
        match = re.search(r'\b([A-Z]+-\d+[A-Z]?)$', key)
        if match:
            keys.add(match[1])
    return keys


def geometry_matches(feature, points, records):
    """Require a source cable chain across every segment, with named anchors.

    Network membership comes exclusively from draw.io. Spatial screening makes
    review candidates, not physical connectivity or verified geographic truth.
    Ambiguous waypoint identities and multiple node paths are left unresolved.
    """
    geometry = feature.get('geometry', {})
    coordinates = geometry.get('coordinates', [])
    segments = [coordinates] if geometry.get('type') == 'LineString' else coordinates
    if not segments:
        return {}
    usable = [c for c in records if c['status'] not in ('ENDPOINT_CONFLICT', 'NETWORK_CONFLICT')]
    by_network = defaultdict(list)
    for cable in usable:
        by_network[cable['network']].append(cable)
    segment_matches = []
    for coords in segments:
        if len(coords) < 2:
            return {}
        line = [local_xy(c) for c in coords]
        ends = []
        for endpoint in (line[0], line[-1]):
            ranked = sorted((math.dist(p['xy'], endpoint), k) for k, p in points.items())
            if not ranked or ranked[0][0] > SCREEN_RADIUS_FT:
                return {}
            # Do not silently choose between essentially coincident source nodes.
            if len(ranked) > 1 and ranked[1][0] - ranked[0][0] < 1.0:
                return {}
            ends.append(ranked[0])
        (start_error, start), (end_error, end) = ends
        if start == end:
            return {}
        positions = {k: line_position(p['xy'], line) for k, p in points.items()}
        eligible = {k: v[1] for k, v in positions.items() if v[0] <= SCREEN_RADIUS_FT}
        matches = {}
        for network, cables in by_network.items():
            graph = defaultdict(set)
            edge_records = defaultdict(list)
            for cable in cables:
                a, b = cable['endpoints']
                if a not in eligible or b not in eligible:
                    continue
                if eligible[a] > eligible[b]:
                    a, b = b, a
                if eligible[b] - eligible[a] > 1.0:
                    graph[a].add(b)
                    edge_records[(a, b)].append(cable['source_id'])
            paths, queue = [], [(start, [start])]
            while queue and len(paths) < 2:
                node, path = queue.pop()
                if node == end:
                    paths.append(path)
                    continue
                queue.extend((next_node, path + [next_node]) for next_node in sorted(graph[node]))
            if len(paths) != 1:
                continue
            path = paths[0]
            ids = [sid for a, b in zip(path, path[1:]) for sid in edge_records[(a, b)]]
            matches[network] = {'cable_source_ids': ids, 'waypoint_path': path,
                'start_waypoint_id': points[start]['id'], 'end_waypoint_id': points[end]['id'],
                'start_distance_ft': round(start_error, 1), 'end_distance_ft': round(end_error, 1)}
        segment_matches.append(matches)
    # A whole source feature is highlighted only if every segment has support.
    common = set.intersection(*(set(m) for m in segment_matches))
    return {network: [m[network] for m in segment_matches] for network in sorted(common)}


def build(drawio_path, map_path):
    raw = drawio_path.read_bytes()
    root = ET.fromstring(raw)
    if any(d.find('mxGraphModel') is None for d in root.findall('diagram')):
        raise ValueError('Expected uncompressed draw.io XML; compressed pages need explicit decoding.')
    source = map_path.read_text(encoding='utf-8')
    data = json.loads(re.search(r'const data=(.*?);data.features.push', source).group(1))
    routes = [f for f in data['features'] if f['properties'].get('class') == 'NET']
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
        network_label = re.search(r'\s+(REG|REGULAR|INET|E1\.31|AUX[- ]?[A-Z])$', attrs['Cable_ID'], re.I)
        if network_label and network_key(network_label[1]) != record['network']:
            record['status'] = 'NETWORK_CONFLICT'
        records.append(record)
        if record['status'] not in ('ENDPOINT_CONFLICT', 'NETWORK_CONFLICT'):
            pairs[tuple(sorted(record['endpoints']))].append(record)
    for cell in root.findall('.//mxCell'):
        if cell.get('edge') == '1' and id(cell) not in wrapped:
            legacy.append({'source_id': cell.get('id'), 'attributes': dict(cell.attrib)})
    keys = {key for c in records for key in c['endpoints']}
    point_candidates = defaultdict(list)
    for feature in data['features']:
        if feature.get('geometry', {}).get('type') != 'Point':
            continue
        for key in waypoint_keys(feature['properties']['name']) & keys:
            point_candidates[key].append({'id': feature['properties']['id'],
                'source_name': feature['properties']['name'],
                'xy': local_xy(feature['geometry']['coordinates'])})
    points = {key: values[0] for key, values in point_candidates.items() if len(values) == 1}
    mapped, unmatched = [], []
    for feature in routes:
        route = feature['properties']
        evidence = geometry_matches(feature, points, records)
        ids = {sid for paths in evidence.values() for path in paths for sid in path['cable_source_ids']}
        # Legacy test/input without geometry can only use literal source names.
        # Actual geographic input never falls back after a failed geometry check.
        if 'geometry' not in feature:
            match = re.fullmatch(r'NET\s+([A-Z]+-\d+[A-Z]?)\s+to\s+([A-Z]+-\d+[A-Z]?)', route['name'], re.I)
            ids = {c['source_id'] for c in pairs.get(tuple(sorted(endpoint_key(x) for x in match.groups())), [])} if match else set()
        candidates = [c for c in records if c['source_id'] in ids]
        if candidates:
            mapped.append({'route_id': route['id'], 'source_name': route['name'],
                           'cable_source_ids': [c['source_id'] for c in candidates],
                           'basis': 'Named waypoint anchors plus draw.io cable chain; geographic review required',
                           'network_evidence': evidence})
            for c in candidates:
                c['route_ids'].append(route['id'])
                c['status'] = 'ROUTE_CANDIDATE_REVIEW_REQUIRED'
        else:
            unmatched.append({'route_id': route['id'], 'source_name': route['name'], 'status': 'UNRESOLVED'})
    return {'format_version': 1, 'source_name': drawio_path.name,
            'source_sha256': hashlib.sha256(raw).hexdigest(),
            'gpx_snapshot': '743ead74d34767a9',
            'mapping_status': 'CANDIDATE — waypoint and cable-chain correspondence, not surveyed route verification',
            'screen_radius_ft': SCREEN_RADIUS_FT,
            'waypoint_lookup': {key: {k: v for k, v in p.items() if k != 'xy'} for key, p in sorted(points.items())},
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
