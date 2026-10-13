"""MSB #171: source-preserving GPX, LinkIQ and draw.io interoperability.

No file is modified in place. This command never connects to Production.
GPX display identity is ExpertGPS Label on Map, NOT Garmin <name>.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import sqlite3
import xml.etree.ElementTree as ET

GPX = '{http://www.topografix.com/GPX/1/1}'
OVERLAY = '{http://www.topografix.com/GPX/gpx_overlay/0/5}'


def sha256(path: Path) -> str:
    """Hash large files without loading all bytes into memory."""
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def local_name(tag: str) -> str:
    return tag.rsplit('}', 1)[-1]


def extract_gpx(path: Path) -> dict:
    """Do not treat legacy Garmin names as the user-facing waypoint name."""
    root = ET.parse(path).getroot()
    waypoints = []
    for ordinal, point in enumerate(root.findall(GPX + 'wpt'), 1):
        label_node = point.find(GPX + 'extensions/' + OVERLAY + 'label/' + OVERLAY + 'label_text')
        if label_node is None or not (label_node.text or '').strip():
            raise ValueError(f'Waypoint {ordinal}: missing ExpertGPS Label on Map')
        garmin_name = point.findtext(GPX + 'name', default='')
        waypoints.append({
            'ordinal': ordinal,
            'map_label': label_node.text.strip(),
            'garmin_name': garmin_name,
            'latitude': point.attrib['lat'],
            'longitude': point.attrib['lon'],
            'type': point.findtext(GPX + 'type', default=''),
            'description': point.findtext(GPX + 'desc', default=''),
            'comment': point.findtext(GPX + 'cmt', default=''),
            'source_time': point.findtext(GPX + 'time', default=''),
        })
    duplicates = {v: n for v, n in Counter(w['map_label'].casefold() for w in waypoints).items() if n > 1}
    if duplicates:
        raise ValueError(f'Ambiguous GPX map labels (not unique): {duplicates}')
    tracks = []
    for ordinal, track in enumerate(root.findall(GPX + 'trk'), 1):
        segments = [[{'lat': p.attrib['lat'], 'lon': p.attrib['lon'],
                      'ele': p.findtext(GPX + 'ele', default='')}
                     for p in seg.findall(GPX + 'trkpt')]
                    for seg in track.findall(GPX + 'trkseg')]
        tracks.append({
            'ordinal': ordinal,
            'name': track.findtext(GPX + 'name', default=''),
            'type': track.findtext(GPX + 'type', default=''),
            'description': track.findtext(GPX + 'desc', default=''),
            'segments': segments,
        })
    return {'kind': 'EXPERTGPS_GPX', 'sha256': sha256(path),
            'waypoints': waypoints, 'tracks': tracks}


def _open_flw(path: Path) -> sqlite3.Connection:
    """Never let sqlite create sidecar files or write into proprietary FLW."""
    # URI makes access read-only and immutable. Source must not be changing meanwhile.
    connection = sqlite3.connect(path.resolve().as_uri() + '?mode=ro&immutable=1', uri=True)
    connection.row_factory = sqlite3.Row
    connection.execute('PRAGMA query_only=ON')
    if connection.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
        connection.close()
        raise ValueError('FLW SQLite integrity check failed')
    return connection


def extract_flw(path: Path, *, include_raw_json: bool = False) -> dict:
    """Deduplicate *test UUIDs*, never physical cables, retaining every project copy.

    Optional raw payload capture is for an authorized PostgreSQL evidence importer.
    Readable user-edited names live in Records; original tester names in BinRec.
    """
    conn = _open_flw(path)
    try:
        # Older synthetic and historical FLW schemas may omit the optional
        # operator notes/Faceplate/Outlet fields present in the actual LinkIQ
        # file. Do not drop available evidence just because a fixture omits it.
        columns = {col[1] for col in conn.execute('PRAGMA table_info(Records)')}
        optional = ', '.join(
            'r.' + name + ' AS ' + name if name in columns
            else 'NULL AS ' + name
            for name in ('Notes', 'Faceplate', 'OutletId')
        )
        rows = conn.execute(f'''
            SELECT r.rowid AS source_row, r.UUID, r.Project, r.CableId, r.Deleted,
                   r.TimeSpan, r.TestStatus, r.Standard, r.LengthF, r.LengthM,
                   r.TesterType, r.Operator, r.Hash, d.BinRec, {optional}
              FROM Records AS r
              LEFT JOIN RecordData AS d ON d.Hash = r.Hash
             ORDER BY r.rowid
        ''').fetchall()
        if len(rows) != conn.execute('SELECT count(*) FROM Records').fetchone()[0]:
            raise ValueError('Non-unique RecordData.Hash join: refusing ambiguous test associations')
        by_uuid = defaultdict(list)
        for r in rows:
            if not r['BinRec']:
                raise ValueError(f'Missing BinRec for Records row {r["source_row"]}')
            try:
                blob = json.loads(r['BinRec'])
            except (ValueError, UnicodeDecodeError) as exc:
                raise ValueError(f'Unparseable BinRec row {r["source_row"]}') from exc
            metadata = blob.get('metadata', {})
            uid = (r['UUID'] or '').lower()
            if not uid or metadata.get('uuid', '').lower() != uid:
                raise ValueError(f'Test UUID mismatch at source row {r["source_row"]}')
            item = {
                'source_row': r['source_row'], 'test_uuid': uid,
                'project': r['Project'], 'display_cable_name': r['CableId'],
                'original_test_id': metadata.get('testId'),
                'deleted': r['Deleted'], 'tested_at_local': metadata.get('timestamp'),
                'record_time_span': r['TimeSpan'], 'test_status_code': r['TestStatus'],
                'test_standard': r['Standard'], 'length_ft': r['LengthF'],
                'length_m_source': r['LengthM'], 'tester_type': r['TesterType'],
                'tester_serial': blob.get('sysinfo', {}).get('serialNumber'),
                'operator': r['Operator'], 'source_hash': r['Hash'],
                'payload_sha256': hashlib.sha256(r['BinRec']).hexdigest(),
                'nvp': blob.get('settings', {}).get('nvp'),
                'notes': r['Notes'] or '',
                'faceplate': r['Faceplate'] or '',
                'outlet_id': r['OutletId'] or '',
            }
            if include_raw_json:
                item['raw_payload'] = blob
            by_uuid[uid].append(item)
        tests, conflicts = [], []
        for uid, variants in sorted(by_uuid.items()):
            # The corrected project is preferred for *display name* only. Never
            # infer the identity of a physical cable from a test display label.
            preference = {'MSB-Park-Network': 0, 'Command Trailer': 1, 'Park Network': 2}
            variants.sort(key=lambda item: (preference.get(item['project'], 10), item['source_row']))
            representative = variants[0]
            semantic_fields = ('record_time_span', 'test_status_code', 'test_standard', 'length_ft', 'tester_type')
            differing = [key for key in semantic_fields
                         if len({str(v[key]) for v in variants}) > 1]
            if differing:
                conflicts.append({'test_uuid': uid, 'differing_fields': differing})
            tests.append({'test_uuid': uid,
                          'preferred_display_cable_name': representative['display_cable_name'],
                          'preferred_project': representative['project'],
                          'cable_identity': None, 'cable_identity_status': 'UNMATCHED',
                          'source_appearances': variants})
        return {'kind': 'LINKIQ_FLW', 'sha256': sha256(path),
                'source_row_count': len(rows), 'unique_test_count': len(tests),
                'duplicate_project_appearances': len(rows)-len(tests),
                'variant_measurement_conflicts': conflicts, 'tests': tests}
    finally:
        conn.close()


def gpx_roundtrip(source_path: Path, projection: dict, output_path: Path) -> dict:
    """Export reviewed waypoint AND track-label changes, fail-closed on drift.

    Waypoints use ExpertGPS map-label/lat/lon baseline identity; tracks use the
    accepted GPX source ordinal and exact original name, NOT a guessed label
    match. Surveyed track points, types, descriptions and GPX extensions stay
    untouched. Never overwrite the baseline. ExpertGPS review remains required.
    """
    if source_path.resolve() == output_path.resolve():
        raise ValueError('Refusing to overwrite original GPX')
    current_hash = sha256(source_path)
    if projection.get('base_source_sha256') != current_hash:
        raise ValueError('GPX changed after DB baseline: conflict review required')
    root = ET.parse(source_path).getroot()
    nodes = {}
    for wpt in root.findall(GPX + 'wpt'):
        label = wpt.find(GPX + 'extensions/' + OVERLAY + 'label/' + OVERLAY + 'label_text')
        if label is None or not (label.text or '').strip():
            raise ValueError('GPX has waypoint lacking Label on Map')
        key = (label.text.strip(), wpt.get('lat'), wpt.get('lon'))
        if key in nodes:
            raise ValueError(f'Nonunique GPX waypoint lookup: {key}')
        nodes[key] = (wpt, label)
    updated = 0
    for entry in projection.get('approved_edits', []):
        key = (entry['previous_map_label'], entry['previous_latitude'], entry['previous_longitude'])
        if key not in nodes:
            raise ValueError(f'No unambiguous source waypoint: {key}')
        node, label = nodes.pop(key)
        if 'map_label' in entry:
            label.text = entry['map_label']
        if 'latitude' in entry:
            node.set('lat', str(entry['latitude']))
        if 'longitude' in entry:
            node.set('lon', str(entry['longitude']))
        updated += 1
    # Position is stable within the SHA-pinned source. Never locate a track
    # solely by its wrong/historical label: duplicates and renames are allowed.
    source_tracks = root.findall(GPX + 'trk')
    edits_by_ordinal = {}
    for entry in projection.get('approved_track_edits', []):
        ordinal = entry.get('source_ordinal')
        old_name = entry.get('previous_track_name')
        new_name = entry.get('track_name')
        if (isinstance(ordinal, bool) or not isinstance(ordinal, int)
                or not 1 <= ordinal <= len(source_tracks)
                or ordinal in edits_by_ordinal):
            raise ValueError('Track source ordinal missing, duplicate or outside accepted GPX')
        if (not isinstance(old_name, str) or not isinstance(new_name, str)
                or not new_name.strip() or old_name == new_name.strip()):
            raise ValueError('Track edit requires a changed, nonblank reviewed label')
        name_node = source_tracks[ordinal - 1].find(GPX + 'name')
        if name_node is None or (name_node.text or '') != old_name:
            raise ValueError('GPX source track name changed: conflict review required')
        edits_by_ordinal[ordinal] = new_name.strip()
        name_node.text = new_name.strip()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    tree = ET.ElementTree(root)
    tree.write(output_path, encoding='utf-8', xml_declaration=True)
    # Verify all non-edited tracks, track geometry/types/descriptions and
    # waypoint identities are conserved. Source extensions stay in the XML.
    after = extract_gpx(output_path)
    before = extract_gpx(source_path)
    expected_tracks = [dict(track) for track in before['tracks']]
    for ordinal, name in edits_by_ordinal.items():
        expected_tracks[ordinal - 1]['name'] = name
    if (len(after['waypoints']) != len(before['waypoints'])
            or after['tracks'] != expected_tracks):
        output_path.unlink(missing_ok=True)
        raise ValueError('GPX waypoint/track conservation validation failed')
    return {'updated': updated, 'updated_tracks': len(edits_by_ordinal),
            'source_sha256': current_hash, 'output_sha256': after['sha256']}


def drawio_from_database(template: Path, bindings: dict, output_path: Path) -> dict:
    """Refresh maintained cable attributes using stable draw.io object IDs.

    Reuses the existing manually legible 19x13 schematic geometry. No automatic
    route or physical-connectivity inference and no mutation of its source file.
    """
    if template.resolve() == output_path.resolve():
        raise ValueError('Refusing to overwrite source diagram')
    if sha256(template) != bindings.get('base_source_sha256'):
        raise ValueError('Diagram changed since binding baseline: review required')
    tree = ET.parse(template)
    root = tree.getroot()
    objects = defaultdict(list)
    for obj in root.iter('object'):
        if obj.get('id'):
            objects[obj.get('id')].append(obj)
    edited = 0
    allowed_fields = {'Cable_ID', 'Waypoint_1', 'Waypoint_2', 'Network', 'Feet', 'Speed'}
    for entry in bindings.get('cables', []):
        oid = entry['drawio_object_id']
        if len(objects[oid]) != 1:
            raise ValueError(f'Missing or duplicate diagram object id: {oid}')
        obj = objects[oid][0]
        if obj.find('mxCell') is None or obj.find('mxCell').get('edge') != '1':
            raise ValueError(f'Binding does not point to a cable edge: {oid}')
        updates = entry['fields']
        if not set(updates).issubset(allowed_fields):
            raise ValueError(f'Unsupported drawing fields: {set(updates)-allowed_fields}')
        for field, value in updates.items():
            obj.set(field, str(value))
        edited += 1
    output_path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output_path, encoding='utf-8', xml_declaration=True)
    after = ET.parse(output_path).getroot()
    if len(list(after.iter('object'))) != len(list(root.iter('object'))):
        output_path.unlink(missing_ok=True)
        raise ValueError('Diagram object conservation failed')
    return {'updated_cable_objects': edited, 'output_sha256': sha256(output_path)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for command in ('gpx-inspect', 'flw-inspect'):
        s = sub.add_parser(command)
        s.add_argument('source', type=Path)
        s.add_argument('--output', type=Path, required=True)
    for command in ('gpx-export', 'schematic-export'):
        s = sub.add_parser(command)
        s.add_argument('source', type=Path)
        s.add_argument('approved_projection', type=Path)
        s.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'gpx-inspect':
        value = extract_gpx(args.source)
    elif args.command == 'flw-inspect':
        value = extract_flw(args.source)
    else:
        projection = json.loads(args.approved_projection.read_text(encoding='utf-8'))
        if args.command == 'gpx-export':
            value = gpx_roundtrip(args.source, projection, args.output)
        else:
            value = drawio_from_database(args.source, projection, args.output)
    if args.command.endswith('-inspect'):
        if args.source.resolve() == args.output.resolve():
            raise ValueError('Refusing to replace original source')
        args.output.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf-8')
    else:
        print(json.dumps(value, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())


def compare_three_way(base: dict, from_gpx: dict, from_database: dict,
                      fields=('map_label', 'latitude', 'longitude', 'type')) -> dict:
    """Detect ExpertGPS/DB edit collisions field-by-field, no last-write-wins.

    The caller must have already resolved one stable physical waypoint identity.
    If identity cannot be resolved, use REVIEW_REQUIRED instead of this merge.
    """
    merged, conflicts, from_gpx_only, from_db_only = {}, {}, [], []
    for field in fields:
        original = base.get(field)
        incoming = from_gpx.get(field, original)
        current = from_database.get(field, original)
        if incoming == current:
            merged[field] = incoming
        elif incoming == original:
            merged[field] = current
            from_db_only.append(field)
        elif current == original:
            merged[field] = incoming
            from_gpx_only.append(field)
        else:
            conflicts[field] = {'baseline': original, 'gpx': incoming, 'database': current}
    return {'status': 'CONFLICT' if conflicts else 'MERGEABLE',
            'merged': merged if not conflicts else None,
            'conflicts': conflicts, 'gpx_only': from_gpx_only,
            'db_only': from_db_only}
