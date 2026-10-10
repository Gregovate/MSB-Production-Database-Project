"""Inventory structured draw.io identities without modifying source or database."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def endpoint_name(value):
    """Apply only the operator-confirmed waypoint rename; retain raw attributes."""
    return 'GG-11' if value.strip().upper() == 'GG-10' else value.strip()


def inventory(raw):
    root = ET.fromstring(raw)
    cables, nodes, issues = [], [], []
    for page in root.findall('diagram'):
        page_id = page.get('id')
        if page.find('mxGraphModel') is None:
            raise ValueError('Compressed diagram requires a reviewed decoding adapter')
        for obj in page.findall('.//object'):
            attrs = dict(obj.attrib)
            cell = obj.find('mxCell')
            if cell is None:
                continue
            identity = [page_id, obj.get('id')]
            if 'Cable_ID' in attrs and attrs['Cable_ID'].strip():
                record = dict(source_key=identity, source_attributes=attrs,
                    cable_label=attrs['Cable_ID'], network_name=attrs.get('Network'),
                    endpoint_1=endpoint_name(attrs.get('Waypoint_1', '')),
                    endpoint_2=endpoint_name(attrs.get('Waypoint_2', '')),
                    diagram_source=cell.get('source'), diagram_target=cell.get('target'),
                    length_feet_source=attrs.get('Feet'), speed_source=attrs.get('Speed'),
                    warnings=[])
                if not record['endpoint_1'] or not record['endpoint_2']:
                    record['warnings'].append('Missing endpoint name')
                if not record['network_name']:
                    record['warnings'].append('Missing network name')
                # Candidate alias is deliberately not an approved network identity.
                name = (record['network_name'] or '').strip()
                match = re.fullmatch(r'Aux[\s-]*([A-Z])', name, re.I)
                record['network_alias_candidate'] = 'Aux-' + match[1].upper() if match else name
                cables.append(record)
            if attrs.get('node_id'):
                nodes.append(dict(source_key=identity, source_attributes=attrs,
                    current_name=endpoint_name(attrs['node_id'])))
    counts = Counter(c['cable_label'] for c in cables)
    for c in cables:
        if counts[c['cable_label']] > 1:
            c['warnings'].append('Repeated cable label; review source objects before merging')
    keys = Counter(tuple(c['source_key']) for c in cables + nodes)
    issues.extend('Repeated source key: ' + repr(k) for k, n in keys.items() if n > 1)
    return dict(source_sha256=hashlib.sha256(raw).hexdigest(), cables=cables,
        nodes=nodes, issues=issues, ready_for_database_import=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    result = inventory(args.source.read_bytes())
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(f"{len(result['cables'])} cable objects; {len(result['nodes'])} node objects; "
          f"{sum(bool(c['warnings']) for c in result['cables'])} cables require review")


if __name__ == '__main__':
    main()
