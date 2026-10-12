"""#171/#319 controlled PostgreSQL source-evidence writer and reference exporter.

Designed for a *disposable acceptance* database first. No Production runner is
included; #122 and Server Management retain Production deployment authority.
Uses the existing governed psycopg2 runtime through site_db_connection.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
from decimal import Decimal
import math
import hashlib

from site_source_sync import extract_flw, extract_gpx, sha256
from linkiq_intake import waypoint_lookup, propose_test


def _jsonb(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))


def ingest_linkiq(conn, source: Path, actor: str) -> dict:
    """Append source appearances without duplicating the UUID or changing links.

    Each DB transaction is fully atomic. A source record's original tester data is
    stored once as immutable evidence, while corrected LinkWare labels live in
    per-file appearance rows, never overwrite ref.site_cable.
    """
    if not actor or not actor.strip():
        raise ValueError('An import actor is required')
    before_sha = sha256(source)
    extracted = extract_flw(source, include_raw_json=True)
    if extracted['sha256'] != before_sha or sha256(source) != before_sha:
        raise ValueError('FLW changed during extraction; retry with a stable export')
    counts = dict(new_tests=0, known_tests=0, new_appearances=0,
                  retained_reviewed=0, review_required=0)
    proposals = []
    with conn.transaction():
        with conn.cursor() as cursor:
            # Serialize intake receipts and comparisons with other intake runs.
            cursor.execute("SELECT pg_advisory_xact_lock(hashtext('MSB:#171:linkiq-intake'))")
            # Keep proposals internally consistent while reference editors run.
            cursor.execute('''LOCK TABLE ref.site_waypoint,ref.site_waypoint_alias,
                ref.site_cable,ref.site_network IN SHARE MODE''')
            cursor.execute('SELECT site_waypoint_id, canonical_label FROM ref.site_waypoint')
            waypoints = cursor.fetchall()
            cursor.execute('''SELECT site_waypoint_id, alias_text FROM ref.site_waypoint_alias
                              WHERE accepted_by IS NOT NULL AND accepted_at IS NOT NULL''')
            lookup = waypoint_lookup(waypoints, cursor.fetchall())
            cursor.execute('''SELECT c.site_cable_id,c.endpoint_a_waypoint_id,
                c.endpoint_b_waypoint_id,COALESCE(c.spare_designation,n.network_code),
                (c.reviewed_by IS NOT NULL AND c.reviewed_at IS NOT NULL)
                FROM ref.site_cable c LEFT JOIN ref.site_network n USING(site_network_id)
                WHERE c.lifecycle_status NOT IN ('DESTROYED','RETIRED','REPLACED','ABANDONED')''')
            cables = [dict(zip(('id','a','b','designation','reviewed'), row))
                      for row in cursor.fetchall()]
            cursor.execute('SELECT EXISTS(SELECT 1 FROM ops.site_source_batch WHERE source_sha256=%s)',
                           (extracted['sha256'],))
            replay = cursor.fetchone()[0]
            cursor.execute('''
                INSERT INTO ops.site_source_batch
                    (source_sha256, source_kind, original_filename, actor, source_metadata)
                VALUES (%s, 'LINKIQ_FLW', %s, %s, %s::jsonb)
                ON CONFLICT (source_sha256) DO NOTHING
            ''', (extracted['sha256'], source.name, actor,
                  _jsonb({'stored_rows':extracted['source_row_count'],
                          'unique_test_uuids':extracted['unique_test_count']})))
            for test in extracted['tests']:
                first = test['source_appearances'][0]
                cursor.execute('''SELECT evidence_sha256,physical_site_cable_id,
                    identity_review_status,test_status_code,test_standard,length_ft
                    FROM ops.linkiq_test WHERE test_uuid=%s::uuid FOR UPDATE''', (test['test_uuid'],))
                row = cursor.fetchone()
                existing = dict(zip(('evidence_sha256','physical_site_cable_id',
                    'identity_review_status','test_status_code','test_standard','length_ft'), row)) if row else None
                counts['known_tests' if existing else 'new_tests'] += 1
                cursor.execute('''SELECT DISTINCT display_cable_name FROM ops.linkiq_test_appearance
                    WHERE test_uuid=%s::uuid AND source_sha256<>%s''',
                    (test['test_uuid'], extracted['sha256']))
                previous_labels = [r[0] for r in cursor.fetchall()]
                proposal = propose_test(test, lookup, cables, existing, previous_labels)
                proposals.append(proposal)
                counts['retained_reviewed' if proposal['status']=='RETAINED_REVIEWED' else 'review_required'] += 1
                cursor.execute('''
                    INSERT INTO ops.linkiq_test
                        (test_uuid, first_seen_source_sha256, tester_original_name,
                         test_time_local, test_status_code, test_standard,
                         length_ft, nvp, tester_serial, evidence_sha256, original_result)
                    VALUES (%s::uuid,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s::jsonb)
                    ON CONFLICT (test_uuid) DO NOTHING
                ''', (test['test_uuid'], extracted['sha256'], first['original_test_id'] or '',
                      first['tested_at_local'], first['test_status_code'],
                      first['test_standard'], first['length_ft'], first['nvp'],
                      first['tester_serial'], first['payload_sha256'],
                      _jsonb(first['raw_payload'])))
                for appearance in test['source_appearances']:
                    cursor.execute('''
                        INSERT INTO ops.linkiq_test_appearance
                            (source_sha256, source_row, test_uuid, linkware_project,
                             display_cable_name, deleted_in_project, original_test_name,
                             measured_ft, status_code, record_payload_sha256)
                        VALUES (%s, %s, %s::uuid, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (source_sha256, source_row) DO NOTHING
                    ''', (extracted['sha256'], appearance['source_row'], test['test_uuid'],
                          appearance['project'], appearance['display_cable_name'],
                          appearance['deleted'], appearance['original_test_id'],
                          appearance['length_ft'], appearance['test_status_code'],
                          appearance['payload_sha256']))
                    counts['new_appearances'] += cursor.rowcount
                    # Retain the full per-file payload/metadata even if a known
                    # UUID's source changes. The first-seen test is never replaced.
                    cursor.execute('''INSERT INTO ops.site_source_observation
                        (source_sha256,source_row,item_kind,source_document)
                        VALUES (%s,%s,'LINKIQ_APPEARANCE',%s::jsonb)
                        ON CONFLICT (source_sha256,source_row,item_kind) DO NOTHING''',
                        (extracted['sha256'], str(appearance['source_row']), _jsonb(appearance)))
                cursor.execute('''INSERT INTO ops.linkiq_intake_review
                    (source_sha256,test_uuid,proposal,actor)
                    VALUES (%s,%s::uuid,%s::jsonb,%s)
                    ON CONFLICT(source_sha256,test_uuid) DO NOTHING''',
                    (extracted['sha256'], test['test_uuid'], _jsonb(proposal), actor))
            # Each successful invocation has its own immutable receipt, even replay.
            cursor.execute('''INSERT INTO ops.linkiq_import_receipt
                (source_sha256,actor,summary) VALUES (%s,%s,%s::jsonb)
                RETURNING import_receipt_id''',
                (extracted['sha256'], actor, _jsonb(dict(counts, replay=replay))))
            receipt_id = cursor.fetchone()[0]
    return {'sha256':extracted['sha256'], 'import_receipt_id':receipt_id,
            'replay':replay, 'counts':counts, 'reconciliation':proposals,
            'source_rows':extracted['source_row_count'],
            'unique_uuid_tests':extracted['unique_test_count'],
            'project_appearance_duplicates':extracted['duplicate_project_appearances'],
            'measurement_conflicts':extracted['variant_measurement_conflicts']}


def review_linkiq_identity(conn, source_sha: str, test_uuid: str, cable_id: int,
                           actor: str, notes: str, expected_cable_id=None) -> dict:
    """Engineering review command; callers must enforce #230 authorization.

    Link only an existing reviewed physical cable. Require the prior binding as
    an optimistic guard, record an immutable decision, and never alter test data.
    This command does not create cables or grant an application role.
    """
    if not actor or not actor.strip() or not notes or not notes.strip():
        raise ValueError('Review actor and evidence notes are required')
    with conn.transaction():
        with conn.cursor() as cursor:
            cursor.execute("SELECT pg_advisory_xact_lock(hashtext('MSB:#171:linkiq-intake'))")
            cursor.execute('''SELECT t.physical_site_cable_id
                FROM ops.linkiq_test t JOIN ops.linkiq_intake_review r USING(test_uuid)
                WHERE r.source_sha256=%s AND t.test_uuid=%s::uuid FOR UPDATE OF t''',
                (source_sha, test_uuid))
            row = cursor.fetchone()
            if row is None:
                raise ValueError('Source/test reconciliation record not found')
            if row[0] != expected_cable_id:
                raise ValueError('Cable binding changed; refresh before review')
            cursor.execute('''SELECT site_cable_id FROM ref.site_cable
                WHERE site_cable_id=%s AND reviewed_by IS NOT NULL
                  AND reviewed_at IS NOT NULL
                  AND endpoint_a_waypoint_id IS NOT NULL
                  AND endpoint_b_waypoint_id IS NOT NULL
                  AND lifecycle_status NOT IN ('DESTROYED','RETIRED','REPLACED','ABANDONED')
                FOR SHARE''', (cable_id,))
            if cursor.fetchone() is None:
                raise ValueError('Select an existing reviewed cable with defined endpoints')
            cursor.execute('''INSERT INTO ops.linkiq_identity_decision
                (source_sha256,test_uuid,previous_cable_id,site_cable_id,actor,evidence_notes)
                VALUES (%s,%s::uuid,%s,%s,%s,%s) RETURNING decision_id''',
                (source_sha,test_uuid,expected_cable_id,cable_id,actor,notes))
            decision_id = cursor.fetchone()[0]
            cursor.execute('''UPDATE ops.linkiq_test SET physical_site_cable_id=%s,
                identity_review_status='REVIEWED',reviewed_by=%s,reviewed_at=clock_timestamp()
                WHERE test_uuid=%s::uuid''', (cable_id,actor,test_uuid))
    return {'decision_id':decision_id,'test_uuid':test_uuid,'site_cable_id':cable_id}


def stage_expertgps(conn, source: Path, actor: str) -> dict:
    """Append a GPX source snapshot for review; do not overwrite curated coords."""
    extracted = extract_gpx(source)
    with conn.transaction():
        with conn.cursor() as cursor:
            cursor.execute('''
                INSERT INTO ops.site_source_batch
                    (source_sha256,source_kind,original_filename,actor,source_metadata)
                VALUES (%s,'EXPERTGPS_GPX',%s,%s,%s::jsonb)
                ON CONFLICT (source_sha256) DO NOTHING
            ''', (extracted['sha256'], source.name, actor,
                  _jsonb({'waypoints':len(extracted['waypoints']),
                          'tracks':len(extracted['tracks'])})))
            for kind, items in [('WAYPOINT',extracted['waypoints']), ('TRACK',extracted['tracks'])]:
                for obj in items:
                    cursor.execute('''
                        INSERT INTO ops.site_source_observation
                            (source_sha256,source_row,item_kind,source_document)
                        VALUES (%s,%s,%s,%s::jsonb)
                        ON CONFLICT (source_sha256,source_row,item_kind) DO NOTHING
                    ''', (extracted['sha256'], str(obj['ordinal']), kind, _jsonb(obj)))
    return {'sha256':extracted['sha256'], 'waypoints':len(extracted['waypoints']),
            'tracks':len(extracted['tracks'])}


def _coordinate(value, limit: int) -> float:
    result = float(value)
    if not math.isfinite(result) or abs(result) > limit:
        raise ValueError('GPX coordinate outside WGS84 bounds')
    return result


def _track_geometry(track: dict) -> dict:
    """Incomplete traces keep source evidence but have no invented linework."""
    segments = track['segments']
    coordinates = [
        [[_coordinate(p['lon'], 180), _coordinate(p['lat'], 90)] for p in segment]
        for segment in segments]
    if not coordinates or any(len(segment) < 2 for segment in coordinates):
        coordinates = []  # Entire original track remains in source_document.
    return {'type': 'MultiLineString', 'coordinates': coordinates}


def bootstrap_expertgps(conn, source: Path, actor: str, expected_sha: str) -> dict:
    """Accept one reviewed baseline into empty reference tables, atomically.

    Same-source replay retains IDs and subsequent reference edits. A different
    baseline requires reviewed reconciliation, never matching by mutable names.
    This is an engineering acceptance operation, not a public authorization API.
    """
    if not actor or not actor.strip():
        raise ValueError('A review actor is required')
    extracted = extract_gpx(source)
    if extracted['sha256'] != expected_sha:
        raise ValueError('GPX source changed from the reviewed SHA256')
    points = [(_coordinate(w['longitude'], 180), _coordinate(w['latitude'], 90))
              for w in extracted['waypoints']]
    lines = [_track_geometry(t) for t in extracted['tracks']]
    incomplete = [t['ordinal'] for t, g in zip(extracted['tracks'], lines) if not g['coordinates']]
    with conn.transaction():
        with conn.cursor() as cursor:
            cursor.execute("SELECT pg_advisory_xact_lock(hashtext('MSB:#171:gpx-bootstrap'))")
            # Serialize against reference edits/imports, including writers which
            # do not take the bootstrap advisory lock.
            cursor.execute('''LOCK TABLE ref.site_waypoint, ref.site_track,
                ref.site_waypoint_source_binding, ref.site_track_source_binding
                IN SHARE ROW EXCLUSIVE MODE''')
            cursor.execute('''SELECT
                (SELECT count(*) FROM ref.site_waypoint),
                (SELECT count(*) FROM ref.site_track),
                (SELECT count(*) FROM ref.site_waypoint_source_binding WHERE source_sha256=%s),
                (SELECT count(*) FROM ref.site_track_source_binding WHERE source_sha256=%s)''',
                (expected_sha, expected_sha))
            nw, nt, bw, bt = cursor.fetchone()
            if nw or nt:
                if (bw, bt) == (len(points), len(lines)) and (bw or bt):
                    return {'sha256': expected_sha, 'status': 'ALREADY_ACCEPTED',
                            'waypoints': bw, 'tracks': bt, 'incomplete_track_ordinals': incomplete}
                raise ValueError('Reference data exists: explicit source reconciliation required')
            # Stage the already parsed snapshot so no second filesystem read can
            # insert a different source between hash verification and acceptance.
            cursor.execute('''INSERT INTO ops.site_source_batch
                (source_sha256,source_kind,original_filename,actor,source_metadata)
                VALUES (%s,'EXPERTGPS_GPX',%s,%s,%s::jsonb)
                ON CONFLICT (source_sha256) DO NOTHING''',
                (expected_sha, source.name, actor,
                 _jsonb({'waypoints': len(points), 'tracks': len(lines)})))
            for kind, items in [('WAYPOINT', extracted['waypoints']), ('TRACK', extracted['tracks'])]:
                for item in items:
                    cursor.execute('''INSERT INTO ops.site_source_observation
                        (source_sha256,source_row,item_kind,source_document)
                        VALUES (%s,%s,%s,%s::jsonb)
                        ON CONFLICT (source_sha256,source_row,item_kind) DO NOTHING''',
                        (expected_sha, str(item['ordinal']), kind, _jsonb(item)))
            for w, (lon, lat) in zip(extracted['waypoints'], points):
                cursor.execute('''INSERT INTO ref.site_waypoint
                    (canonical_label,source_garmin_name,waypoint_type,current_point,
                     source_wgs84,source_comment,source_description,source_time,verified_by,verified_at)
                    VALUES (%s,%s,%s,ST_Transform(ST_SetSRID(ST_MakePoint(%s,%s),4326),8158),
                            ST_SetSRID(ST_MakePoint(%s,%s),4326),%s,%s,%s,%s,clock_timestamp())
                    RETURNING site_waypoint_id''',
                    (w['map_label'], w['garmin_name'], w['type'], lon, lat, lon, lat,
                     w['comment'], w['description'], w['source_time'], actor))
                waypoint_id = cursor.fetchone()[0]
                cursor.execute('''INSERT INTO ref.site_waypoint_source_binding
                    (site_waypoint_id,source_sha256,baseline_map_label,baseline_latitude,
                     baseline_longitude,accepted_by,accepted_at)
                    VALUES (%s,%s,%s,%s,%s,%s,clock_timestamp())''',
                    (waypoint_id, expected_sha, w['map_label'], w['latitude'], w['longitude'], actor))
            for track, geometry in zip(extracted['tracks'], lines):
                cursor.execute('''INSERT INTO ref.site_track
                    (track_label,source_type,reference_line,source_wgs84,description)
                    VALUES (%s,%s,ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(%s),4326),8158),
                            ST_SetSRID(ST_GeomFromGeoJSON(%s),4326),%s)
                    RETURNING site_track_id''',
                    (track['name'], track['type'], _jsonb(geometry), _jsonb(geometry), track['description']))
                track_id = cursor.fetchone()[0]
                cursor.execute('''INSERT INTO ref.site_track_source_binding
                    (site_track_id,source_sha256,source_ordinal,accepted_by)
                    VALUES (%s,%s,%s,%s)''', (track_id, expected_sha, track['ordinal'], actor))
    return {'sha256': expected_sha, 'status': 'ACCEPTED',
            'waypoints': len(points), 'tracks': len(lines), 'incomplete_track_ordinals': incomplete}


def export_waypoint_projection(conn, baseline_source_sha: str) -> dict:
    """Export accepted waypoint edits AND reviewed GPX track-name corrections.

    The stable source bindings identify track observations by SHA256 and source
    ordinal, never by a potentially wrong or duplicated source track label.
    A changed source GPX is rejected by gpx_roundtrip before any file output.
    """
    with conn.cursor() as cursor:
        cursor.execute('''
            SELECT b.baseline_map_label, b.baseline_latitude, b.baseline_longitude,
                   w.canonical_label,
                   ST_Y(COALESCE(w.source_wgs84, ST_Transform(w.current_point,4326)))::text,
                   ST_X(COALESCE(w.source_wgs84, ST_Transform(w.current_point,4326)))::text
              FROM ref.site_waypoint_source_binding b
              JOIN ref.site_waypoint w USING (site_waypoint_id)
             WHERE b.source_sha256 = %s AND b.accepted_at IS NOT NULL
             ORDER BY b.site_waypoint_id
        ''', (baseline_source_sha,))
        rows = cursor.fetchall()
    edits=[]
    for source_label,source_lat,source_lon,current_label,current_lat,current_lon in rows:
        entry={'previous_map_label':source_label,
               'previous_latitude':source_lat, 'previous_longitude':source_lon}
        if source_label != current_label:
            entry['map_label']=current_label
        # Avoid reformatting unchanged surveyed coordinates during export.
        if Decimal(source_lat) != Decimal(current_lat):
            entry['latitude']=current_lat
        if Decimal(source_lon) != Decimal(current_lon):
            entry['longitude']=current_lon
        if len(entry)>3:
            edits.append(entry)
    # Original track names remain immutable source observations. Each reviewed
    # ref.site_track rename is exported against its accepted GPX ordinal, not
    # against the stale label or a guessed map feature/database primary key.
    with conn.cursor() as cursor:
        cursor.execute('''
            SELECT b.source_ordinal, obs.source_document->>'name', t.track_label
              FROM ref.site_track_source_binding b
              JOIN ref.site_track t USING (site_track_id)
              LEFT JOIN ops.site_source_observation obs
                ON obs.source_sha256=b.source_sha256
               AND obs.source_row=b.source_ordinal::text
               AND obs.item_kind='TRACK'
             WHERE b.source_sha256=%s AND b.accepted_at IS NOT NULL
             ORDER BY b.source_ordinal
        ''', (baseline_source_sha,))
        bound_tracks = cursor.fetchall()
    track_edits = []
    for ordinal, source_name, approved_name in bound_tracks:
        if source_name is None:
            raise ValueError(f'Accepted track {ordinal} lacks its original GPX source observation')
        if approved_name != source_name:
            track_edits.append({'source_ordinal': ordinal,
                                'previous_track_name': source_name,
                                'track_name': approved_name})
    return {'base_source_sha256':baseline_source_sha, 'approved_edits':edits,
            'approved_track_edits':track_edits}


def export_map_projection(conn) -> dict:
    """One consistent offline dataset; one feature per reviewed shared route.

    Source tracks remain separately available as evidence. Only NET/PRI/HV
    tracks explicitly associated with a reviewed route are hidden by default.
    This read surface does not authorize unreviewed automatic cable matching.
    """
    with conn.transaction():
        with conn.cursor() as cursor:
            # Read locks keep all three projections at the same revision even
            # when invoked inside an existing READ COMMITTED transaction.
            cursor.execute('''LOCK TABLE ref.site_waypoint,ref.site_track,
                ref.site_route_segment,ref.site_route_source_track,
                ref.site_cable_route_segment IN SHARE MODE''')
            cursor.execute('''SELECT site_waypoint_id,canonical_label,waypoint_type,
                ST_AsGeoJSON(ST_Transform(current_point,4326))::jsonb
                FROM ref.site_waypoint ORDER BY site_waypoint_id''')
            waypoints = [{'type': 'Feature', 'id': f'waypoint:{i}', 'geometry': g,
                          'properties': {'kind': 'waypoint', 'waypoint_id': i,
                                         'label': label, 'waypoint_type': typ}}
                         for i, label, typ, g in cursor.fetchall()]
            cursor.execute('''SELECT r.site_route_segment_id,r.route_label,
                r.endpoint_a_waypoint_id,r.endpoint_b_waypoint_id,
                ST_AsGeoJSON(ST_Transform(r.reference_line,4326))::jsonb,
                COALESCE((SELECT jsonb_agg(x.site_cable_id ORDER BY x.site_cable_id)
                    FROM (SELECT DISTINCT c.site_cable_id FROM ref.site_cable_route_segment c
                          WHERE c.site_route_segment_id=r.site_route_segment_id) x),'[]'::jsonb),
                COALESCE((SELECT jsonb_agg(s.site_track_id ORDER BY s.site_track_id)
                    FROM ref.site_route_source_track s
                    WHERE s.site_route_segment_id=r.site_route_segment_id),'[]'::jsonb)
                FROM ref.site_route_segment r WHERE r.review_status='REVIEWED'
                ORDER BY r.site_route_segment_id''')
            routes = [{'type': 'Feature', 'id': f'route:{i}', 'geometry': g,
                       'properties': {'kind': 'shared_route', 'route_id': i, 'label': label,
                                      'endpoint_a': a, 'endpoint_b': b,
                                      'cable_ids': cables, 'source_track_ids': tracks}}
                      for i, label, a, b, g, cables, tracks in cursor.fetchall()]
            cursor.execute('''SELECT t.site_track_id,t.track_label,t.source_type,
                CASE WHEN ST_IsEmpty(t.reference_line) THEN NULL ELSE
                    ST_AsGeoJSON(COALESCE(t.source_wgs84,
                        ST_Transform(t.reference_line,4326)))::jsonb END,
                EXISTS(SELECT 1 FROM ref.site_route_source_track s
                    JOIN ref.site_route_segment r USING(site_route_segment_id)
                    WHERE s.site_track_id=t.site_track_id AND r.review_status='REVIEWED')
                FROM ref.site_track t ORDER BY t.site_track_id''')
            traces = []
            for i, label, typ, geometry, associated in cursor.fetchall():
                priority = next((p for p in ('NET', 'PRI', 'HV')
                                 if label.strip().upper().startswith(p)), None)
                traces.append({'type': 'Feature', 'id': f'track:{i}', 'geometry': geometry,
                               'properties': {'kind': 'source_track', 'track_id': i,
                                              'label': label, 'source_type': typ,
                                              'priority_class': priority,
                                              'geometry_status': 'COMPLETE' if geometry else 'INCOMPLETE',
                                              'visible_by_default': not (priority and associated)}})
    dataset = {'type': 'FeatureCollection', 'schema_version': 1,
               'features': waypoints + routes + traces}
    dataset['revision'] = hashlib.sha256(_jsonb(dataset).encode('utf-8')).hexdigest()
    return dataset


def export_schematic_projection(conn, drawing_name: str, source_sha: str) -> dict:
    """Refresh bound cables only: geometry stays in manually legible drawing."""
    with conn.cursor() as cursor:
        cursor.execute('''
            SELECT b.drawio_object_id, a.canonical_label, z.canonical_label,
                   n.network_code, c.spare_designation,
                   t.length_ft, t.test_standard
              FROM ref.site_schematic_binding b
              JOIN ref.site_cable c USING (site_cable_id)
              LEFT JOIN ref.site_waypoint a ON a.site_waypoint_id=c.endpoint_a_waypoint_id
              LEFT JOIN ref.site_waypoint z ON z.site_waypoint_id=c.endpoint_b_waypoint_id
              LEFT JOIN ref.site_network n USING (site_network_id)
              LEFT JOIN LATERAL (
                SELECT q.length_ft, q.test_standard
                  FROM ops.linkiq_test q
                 WHERE q.physical_site_cable_id=c.site_cable_id
                 ORDER BY q.test_time_local DESC NULLS LAST, q.test_uuid DESC LIMIT 1
              ) t ON true
             WHERE b.drawing_name=%s
             ORDER BY b.drawio_object_id
        ''', (drawing_name,))
        rows=cursor.fetchall()
    cables=[]
    for oid,a,z,net,spare,length_ft,test_standard in rows:
        if not a or not z:
            continue  # Never invent an endpoint for an incomplete cable.
        designation=spare or net
        fields={'Waypoint_1':a,'Waypoint_2':z}
        if designation:
            fields['Cable_ID']=f'{a} TO {z} {designation}'
            fields['Network']=designation
        if length_ft is not None:
            fields['Feet']=str(length_ft)
        # A test standard alone does not establish a successful speed qualification.
        # Preserve existing Speed text until explicit per-application test decoding.
        cables.append({'drawio_object_id':oid,'fields':fields})
    return {'base_source_sha256':source_sha,'cables':cables}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('stage-gpx','bootstrap-gpx','import-flw','export-map','export-gpx-projection','export-schematic-projection','review-linkiq'))
    parser.add_argument('--dsn', required=True, help='Governed disposable database DSN')
    parser.add_argument('--source', type=Path)
    parser.add_argument('--actor')
    parser.add_argument('--baseline-sha')
    parser.add_argument('--drawing-name')
    parser.add_argument('--test-uuid')
    parser.add_argument('--cable-id', type=int)
    parser.add_argument('--expected-cable-id', type=int)
    parser.add_argument('--review-notes')
    parser.add_argument('--output', type=Path)
    args=parser.parse_args()
    if not args.output:
        parser.error('--output is required to write local receipt/projection')
    from site_db_connection import connect
    with connect(args.dsn) as conn:
        if args.mode=='stage-gpx':
            if not args.actor or not args.source: parser.error('Source and actor required')
            result=stage_expertgps(conn,args.source,args.actor)
        elif args.mode=='bootstrap-gpx':
            if not args.actor or not args.source or not args.baseline_sha:
                parser.error('--source, --actor and --baseline-sha required')
            result=bootstrap_expertgps(conn,args.source,args.actor,args.baseline_sha)
        elif args.mode=='import-flw':
            if not args.actor or not args.source: parser.error('Source and actor required')
            result=ingest_linkiq(conn,args.source,args.actor)
        elif args.mode=='review-linkiq':
            if not args.baseline_sha or not args.test_uuid or not args.cable_id:
                parser.error('--baseline-sha, --test-uuid and --cable-id required')
            result=review_linkiq_identity(conn,args.baseline_sha,args.test_uuid,
                args.cable_id,args.actor,args.review_notes,args.expected_cable_id)
        elif args.mode=='export-map':
            result=export_map_projection(conn)
        elif args.mode=='export-gpx-projection':
            if not args.baseline_sha: parser.error('--baseline-sha required')
            result=export_waypoint_projection(conn,args.baseline_sha)
        else:
            if not args.baseline_sha or not args.drawing_name:
                parser.error('--baseline-sha and --drawing-name required')
            result=export_schematic_projection(conn,args.drawing_name,args.baseline_sha)
    args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
    return 0


if __name__=='__main__':
    raise SystemExit(main())
