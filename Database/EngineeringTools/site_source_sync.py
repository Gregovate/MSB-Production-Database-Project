"""MSB #171: source-preserving GPX, LinkIQ and draw.io interoperability.

No file is modified in place. This command never connects to Production.
GPX display identity is ExpertGPS Label on Map, NOT Garmin <name>.
"""
from __future__ import annotations

import argparse
import base64
from xml.dom import minidom, Node
from collections import Counter, defaultdict
import hashlib
import json
import math
from copy import deepcopy
from pathlib import Path
import sqlite3
import xml.etree.ElementTree as ET

GPX = '{http://www.topografix.com/GPX/1/1}'
OVERLAY = '{http://www.topografix.com/GPX/gpx_overlay/0/5}'
STYLE = '{http://www.topografix.com/GPX/gpx_style/0/2}'
PRIVATE = '{http://www.topografix.com/GPX/Private/TopoGrafix/0/5}'


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
    # Parse and fingerprint one immutable read; a second filesystem read could
    # otherwise attach the hash of a newer export to older parsed geometry.
    raw = path.read_bytes()
    if b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
        raise ValueError('GPX DTD/entity declarations are not supported')
    root = ET.fromstring(raw)
    if root.tag != GPX + 'gpx':
        raise ValueError('Expected GPX 1.1 document')
    for point in list(root.findall(GPX + 'wpt')) + list(root.iter(GPX + 'trkpt')):
        for name, limit in (('lat', 90), ('lon', 180)):
            value = float(point.attrib[name])
            if not math.isfinite(value) or abs(value) > limit:
                raise ValueError('GPX coordinate outside WGS84 bounds')
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
            'symbol': point.findtext(GPX + 'sym', default=''),
            'source_xml': ET.tostring(point, encoding='unicode'),
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
        map_label = track.findtext(GPX + 'extensions/' + OVERLAY + 'label/' + OVERLAY + 'label_text', default='').strip()
        line = track.find(GPX + 'extensions/' + STYLE + 'line')
        # Preserve source strings; the renderer validates before interpreting them.
        style = {} if line is None else {key: line.findtext(STYLE + key, default='')
                                         for key in ('color', 'opacity', 'width', 'pattern')}
        if line is not None:
            style['cased'] = line.findtext(STYLE + 'extensions/' + PRIVATE + 'cased', default='false')
        tracks.append({
            'map_label': map_label,
            'style': style,
            'ordinal': ordinal,
            'name': track.findtext(GPX + 'name', default=''),
            'source_xml': ET.tostring(track, encoding='unicode'),
            'type': track.findtext(GPX + 'type', default=''),
            'description': track.findtext(GPX + 'desc', default=''),
            'segments': segments,
        })
    return {'kind': 'EXPERTGPS_GPX', 'sha256': hashlib.sha256(raw).hexdigest(),
            'waypoints': waypoints, 'tracks': tracks,
            'document': {'encoding': 'base64', 'bytes': base64.b64encode(raw).decode('ascii')}}


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


def _dom_children(node, namespace, local):
    """Direct children only: unknown nested extensions must never be edited."""
    return [c for c in node.childNodes if c.nodeType == Node.ELEMENT_NODE
            and c.namespaceURI == namespace and c.localName == local]


def _dom_signature(node):
    """Whole-document equality including namespace bindings, comments and PIs."""
    attrs = tuple(sorted((node.attributes.item(i).name, node.attributes.item(i).value)
                         for i in range(node.attributes.length))) if node.attributes else ()
    return (node.nodeType, node.nodeName, node.nodeValue, attrs,
            tuple(_dom_signature(c) for c in node.childNodes))


def _set_dom_text(node, value):
    if any(c.nodeType == Node.ELEMENT_NODE for c in node.childNodes):
        raise ValueError('Reviewed text field contains unexpected nested XML')
    # Retain comments/PIs embedded in an edited text node.
    for child in list(node.childNodes):
        if child.nodeType in (Node.TEXT_NODE, Node.CDATA_SECTION_NODE):
            node.removeChild(child)
    node.appendChild(node.ownerDocument.createTextNode(value))


def gpx_roundtrip(source_path: Path, projection: dict, output_path: Path) -> dict:
    """Patch only reviewed fields; retain complete GPX and refuse output clobber.

    Original bytes are read once. No-op is byte-identical; edited output keeps
    source prefixes/unknown XML and must pass whole-document comparison before
    exclusive creation. GPX application acceptance remains a separate gate.
    """
    if source_path.resolve() == output_path.resolve():
        raise ValueError('Refusing to overwrite original GPX')
    if output_path.exists():
        raise ValueError('Refusing to overwrite existing GPX output')
    if set(projection) - {'base_source_sha256', 'approved_edits', 'approved_track_edits'}:
        raise ValueError('Unsupported GPX projection field')
    raw = source_path.read_bytes()
    current_hash = hashlib.sha256(raw).hexdigest()
    if projection.get('base_source_sha256') != current_hash:
        raise ValueError('GPX changed after DB baseline: conflict review required')
    # Use a single captured document for fingerprint, validation and edits.
    if b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
        raise ValueError('GPX DTD/entity declarations are not supported')
    doc = minidom.parseString(raw)
    if doc.doctype is not None:
        raise ValueError('GPX DTD/entity declarations are not supported')
    root = doc.documentElement
    namespace, overlay = GPX[1:-1], OVERLAY[1:-1]
    if root.namespaceURI != namespace or root.localName != 'gpx':
        raise ValueError('Expected GPX 1.1 document')
    nodes = {}
    for wpt in _dom_children(root, namespace, 'wpt'):
        labels = [text for ext in _dom_children(wpt, namespace, 'extensions')
                  for label in _dom_children(ext, overlay, 'label')
                  for text in _dom_children(label, overlay, 'label_text')]
        if len(labels) != 1:
            raise ValueError('GPX has waypoint lacking unambiguous Label on Map')
        label = labels[0]
        text = ''.join(c.data for c in label.childNodes
                       if c.nodeType in (Node.TEXT_NODE, Node.CDATA_SECTION_NODE))
        key = (text.strip(), wpt.getAttribute('lat'), wpt.getAttribute('lon'))
        if not key[0] or key in nodes:
            raise ValueError(f'Nonunique GPX waypoint lookup: {key}')
        nodes[key] = (wpt, label)
    edits = projection.get('approved_edits', [])
    for entry in edits:
        if set(entry) - {'previous_map_label', 'previous_latitude', 'previous_longitude',
                         'map_label', 'latitude', 'longitude'}:
            raise ValueError('Unsupported GPX waypoint edit field')
        key = (entry['previous_map_label'], entry['previous_latitude'], entry['previous_longitude'])
        if key not in nodes:
            raise ValueError(f'No unambiguous source waypoint: {key}')
        node, label = nodes.pop(key)
        if 'map_label' in entry:
            if not isinstance(entry['map_label'], str) or not entry['map_label'].strip():
                raise ValueError('Reviewed map label must be nonblank text')
            _set_dom_text(label, entry['map_label'])
        for field, attribute, limit in [('latitude', 'lat', 90), ('longitude', 'lon', 180)]:
            if field in entry:
                value = float(entry[field])
                if not math.isfinite(value) or abs(value) > limit:
                    raise ValueError('GPX coordinate outside WGS84 bounds')
                node.setAttribute(attribute, str(entry[field]))
    tracks = _dom_children(root, namespace, 'trk')
    track_edits = projection.get('approved_track_edits', [])
    used = set()
    for entry in track_edits:
        if set(entry) - {'source_ordinal', 'previous_track_name', 'track_name', 'previous_track_map_label', 'track_map_label'}:
            raise ValueError('Unsupported GPX track edit field')
        is_map = 'track_map_label' in entry
        if is_map and ('track_name' in entry or 'previous_track_name' in entry):
            raise ValueError('Track name and map-label edits must be separate')
        ordinal = entry.get('source_ordinal')
        old = entry.get('previous_track_map_label' if is_map else 'previous_track_name')
        new = entry.get('track_map_label' if is_map else 'track_name')
        if type(ordinal) is not int or not 1 <= ordinal <= len(tracks) or ordinal in used:
            raise ValueError('Track source ordinal missing, duplicate or outside accepted GPX')
        if not isinstance(old, str) or not isinstance(new, str) or not new.strip() or old == new.strip():
            raise ValueError('Track edit requires a changed, nonblank reviewed label')
        names = ([text for ext in _dom_children(tracks[ordinal - 1], namespace, 'extensions')
                  for label in _dom_children(ext, overlay, 'label')
                  for text in _dom_children(label, overlay, 'label_text')] if is_map
                 else _dom_children(tracks[ordinal - 1], namespace, 'name'))
        if len(names) != 1 or ''.join(c.data for c in names[0].childNodes
                if c.nodeType in (Node.TEXT_NODE, Node.CDATA_SECTION_NODE)) != old:
            raise ValueError('GPX source track name changed: conflict review required')
        used.add(ordinal)
        _set_dom_text(names[0], new.strip())
    output = doc.toxml(encoding='utf-8') if edits or track_edits else raw
    if _dom_signature(doc) != _dom_signature(minidom.parseString(output)):
        raise ValueError('GPX whole-document conservation validation failed')
    # Reuse the full extractor validation without publishing an invalid file.
    import tempfile
    with tempfile.TemporaryDirectory() as directory:
        check = Path(directory) / 'check.gpx'
        check.write_bytes(output)
        extract_gpx(check)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open('xb') as handle:
        handle.write(output)
    return {'updated': len(edits), 'updated_tracks': len(track_edits),
            'source_sha256': current_hash, 'output_sha256': hashlib.sha256(output).hexdigest(),
            'whole_document_preserved': True, 'byte_identical': output == raw}


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
    preview = sub.add_parser('gpx-preview')
    preview.add_argument('source', type=Path)
    preview.add_argument('--baseline', type=Path, required=True)
    preview.add_argument('--maintained', type=Path, required=True)
    preview.add_argument('--decisions', type=Path, required=True)
    preview.add_argument('--expected-sha', required=True)
    preview.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'gpx-preview':
        inputs = (args.source, args.baseline, args.maintained, args.decisions)
        if args.output.exists() or args.output.resolve() in {p.resolve() for p in inputs}:
            raise ValueError('Preview output must be a new file, never a source overwrite')
        value = preview_gpx_revision(
            extract_gpx(args.baseline), extract_gpx(args.source),
            json.loads(args.maintained.read_text(encoding='utf-8')),
            json.loads(args.decisions.read_text(encoding='utf-8')),
            expected_sha=args.expected_sha)
        with args.output.open('x', encoding='utf-8') as output:
            json.dump(value, output, indent=2, ensure_ascii=False)
        return 2 if value['status'] == 'HOLD' else 0
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


def preview_gpx_revision(baseline: dict, incoming: dict, maintained: dict,
                         decisions: dict, *, expected_sha: str) -> dict:
    """Review a recurring source against explicitly bound permanent identities.

    Pure comparison only: no file/database writes and no automatic identity
    matching. Each maintained item has id, baseline_ordinal and current fields.
    decisions[kind][incoming ordinal] is a permanent ID or the literal NEW.
    The caller obtains maintained rows and revision from one coherent DB read.
    """
    if incoming['sha256'] != expected_sha:
        raise ValueError('Incoming master differs from expected SHA256')
    if maintained.get('baseline_sha256') != baseline['sha256']:
        raise ValueError('Accepted baseline binding differs from supplied source')
    revision = maintained.get('revision')
    if type(revision) is not int or revision < 0:
        raise ValueError('Expected database revision required')
    if set(decisions) - {'waypoints', 'tracks'}:
        raise ValueError('Unknown identity decision kind')
    changes, conflicts, retained = [], [], []
    for kind, fields in (
        ('waypoints', ('map_label', 'garmin_name', 'symbol', 'latitude', 'longitude', 'type',
                       'description', 'comment', 'source_time')),
        ('tracks', ('name', 'map_label', 'style', 'type', 'description', 'segments')),
    ):
        old = {x['ordinal']: x for x in baseline[kind]}
        current = {x['id']: x for x in maintained[kind]}
        if len(old) != len(baseline[kind]) or len(current) != len(maintained[kind]):
            raise ValueError('Duplicate baseline ordinal or maintained identity')
        bindings = [x['baseline_ordinal'] for x in current.values()]
        if len(set(bindings)) != len(bindings) or any(x not in old for x in bindings):
            raise ValueError('Ambiguous or missing accepted source binding')
        incoming_rows = {str(x['ordinal']): x for x in incoming[kind]}
        if len(incoming_rows) != len(incoming[kind]):
            raise ValueError('Duplicate incoming source ordinal')
        selected = decisions.get(kind, {})
        if set(selected) - set(incoming_rows):
            raise ValueError('Decision refers to absent incoming source row')
        used = set()
        for row, source in incoming_rows.items():
            target = selected.get(row)
            entry = {'kind': kind, 'source_ordinal': source['ordinal'], 'target_id': target}
            if target is None:
                conflicts.append(dict(entry, reason='IDENTITY_REVIEW_REQUIRED'))
                continue
            if target == 'NEW':
                changes.append(dict(entry, action='ADD', after=deepcopy(source)))
                continue
            if type(target) is not int or target not in current or target in used:
                conflicts.append(dict(entry, reason='UNKNOWN_OR_REUSED_IDENTITY'))
                continue
            used.add(target)
            before = current[target]
            base = old[before['baseline_ordinal']]
            # Missing fields in a DB snapshot must never be filled from the GPX
            # silently: that would conceal maintained corrections from review.
            if any(f not in before for f in fields):
                raise ValueError('Incomplete maintained snapshot')
            comparison = compare_three_way(base, source, before, fields)
            if comparison['conflicts']:
                conflicts.append(dict(entry, reason='CONCURRENT_EDIT', details=comparison['conflicts']))
                continue
            after = comparison['merged']
            changed = any(after[f] != before[f] for f in fields)
            changes.append(dict(entry, action='UPDATE' if changed else 'UNCHANGED',
                                before={f: deepcopy(before[f]) for f in fields},
                                after=deepcopy(after), preserved_database_fields=comparison['db_only']))
        # Removed/split features cannot silently delete or retire reference data.
        retained.extend({'kind': kind, 'id': i, 'reason': 'UNMAPPED_EXISTING_RETAINED'}
                        for i in current if i not in used)
    # Canonical labels and retained aliases share an identity namespace. Include
    # unchanged/unmapped DB rows, so NEW cannot steal an existing spelling.
    labels = {}
    for item in maintained['waypoints']:
        for label in [item['map_label']] + item.get('aliases', []):
            labels.setdefault(label.strip().casefold(), set()).add(item['id'])
    for index, item in enumerate(changes):
        if item['kind'] != 'waypoints':
            continue
        label = item['after']['map_label'].strip().casefold()
        owner = ('NEW', index) if item['target_id'] == 'NEW' else item['target_id']
        if not label or labels.get(label, set()) - {owner}:
            conflicts.append(dict(kind='waypoints', source_ordinal=item['source_ordinal'],
                                  reason='LABEL_OR_ALIAS_COLLISION', label=label))
        labels.setdefault(label, set()).add(owner)
        if item['action'] == 'UPDATE' and item['before']['map_label'] != item['after']['map_label']:
            item['retain_alias'] = item['before']['map_label']
    # Operator review categories are descriptive, never automatic write approval.
    # Keep old/new values in changes; summaries must not conceal a single rename.
    review_items = []
    categories = {
        'waypoints': {'map_label': 'WAYPOINT_MAP_RENAME', 'garmin_name': 'GPS_NAME_CHANGE',
                      'symbol': 'SYMBOL_CHANGE', 'type': 'WAYPOINT_TYPE_CHANGE',
                      'latitude': 'WAYPOINT_COORDINATES_CHANGE', 'longitude': 'WAYPOINT_COORDINATES_CHANGE'},
        'tracks': {'name': 'TRACK_GPS_NAME_CHANGE', 'map_label': 'TRACK_MAP_RENAME',
                   'segments': 'TRACK_GEOMETRY_CHANGE', 'style': 'TRACK_STYLE_CHANGE',
                   'type': 'TRACK_TYPE_CHANGE'},
    }
    summary = {}
    for kind in ('waypoints', 'tracks'):
        actions = Counter(c['action'] for c in changes if c['kind'] == kind)
        summary[kind] = dict(baseline=len(baseline[kind]), incoming=len(incoming[kind]),
            maintained=len(maintained[kind]), added=actions['ADD'], updated=actions['UPDATE'],
            unchanged=actions['UNCHANGED'], retained=sum(r['kind'] == kind for r in retained),
            conflicts=sum(c['kind'] == kind for c in conflicts))
    for change in changes:
        if change['action'] == 'UNCHANGED':
            continue
        fields = sorted(k for k in change['after'] if change['action'] == 'UPDATE'
                        and change['before'].get(k) != change['after'][k])
        reasons = (['NEW_IDENTITY'] if change['action'] == 'ADD' else
                   sorted({categories[change['kind']].get(k, 'SOURCE_METADATA_CHANGE') for k in fields}))
        review_items.append(dict(kind=change['kind'], target_id=change['target_id'],
            source_ordinal=change['source_ordinal'], changed_fields=fields,
            reasons=reasons, explicit_review_required=True))
    result = {'status': 'HOLD' if conflicts or retained else 'REVIEW_REQUIRED',
              'baseline_sha256': baseline['sha256'], 'incoming_sha256': incoming['sha256'],
              'expected_revision': revision, 'changes': changes, 'conflicts': conflicts,
              'retained': retained, 'writes_performed': False,
              'summary': summary, 'review_items': review_items,
              'promotion_ready': False,
              'dependency_analysis': {'status': 'NOT_IMPLEMENTED',
                  'message': 'Consumer dependency capture is required before approval/apply; no impact-free claim.'}}

    # Bind source, DB snapshot and decisions; never accept this digest as approval.
    bound = {'preview': result, 'maintained': maintained, 'decisions': decisions}
    result['preview_sha256'] = hashlib.sha256(json.dumps(
        bound, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
    return result


if __name__ == '__main__':
    raise SystemExit(main())
