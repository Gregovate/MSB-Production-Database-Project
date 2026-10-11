"""#171/#319 controlled PostgreSQL source-evidence writer and reference exporter.

Designed for a *disposable acceptance* database first. No Production runner is
included; #122 and Server Management retain Production deployment authority.
Requires psycopg v3 on the executing host.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
from decimal import Decimal

from site_source_sync import extract_flw, extract_gpx


def _jsonb(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))


def ingest_linkiq(conn, source: Path, actor: str) -> dict:
    """Append source appearances without duplicating the UUID or changing links.

    Each DB transaction is fully atomic. A source record's original tester data is
    stored once as immutable evidence, while corrected LinkWare labels live in
    per-file appearance rows, never overwrite ref.site_cable.
    """
    extracted = extract_flw(source, include_raw_json=True)
    with conn.transaction():
        with conn.cursor() as cursor:
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
    return {'sha256':extracted['sha256'],
            'source_rows':extracted['source_row_count'],
            'unique_uuid_tests':extracted['unique_test_count'],
            'project_appearance_duplicates':extracted['duplicate_project_appearances'],
            'measurement_conflicts':extracted['variant_measurement_conflicts']}


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


def export_waypoint_projection(conn, baseline_source_sha: str) -> dict:
    """Return current DB values for reviewed source bindings, ready for GPX export.

    For an approved GPX baseline, only write when last observed identity remains
    unambiguous. A real source file that changed since baseline is rejected by
    gpx_roundtrip before editing. The binding identity isn't a Garmin alias.
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
    return {'base_source_sha256':baseline_source_sha, 'approved_edits':edits}


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
    parser.add_argument('mode', choices=('stage-gpx','import-flw','export-gpx-projection','export-schematic-projection'))
    parser.add_argument('--dsn', required=True, help='Governed disposable database DSN')
    parser.add_argument('--source', type=Path)
    parser.add_argument('--actor')
    parser.add_argument('--baseline-sha')
    parser.add_argument('--drawing-name')
    parser.add_argument('--output', type=Path)
    args=parser.parse_args()
    if not args.output:
        parser.error('--output is required to write local receipt/projection')
    try:
        import psycopg
    except ImportError as exc:
        raise SystemExit('Install psycopg v3 on the accepted disposable runner; no fallback to another DB driver') from exc
    with psycopg.connect(args.dsn) as conn:
        if args.mode=='stage-gpx':
            if not args.actor or not args.source: parser.error('Source and actor required')
            result=stage_expertgps(conn,args.source,args.actor)
        elif args.mode=='import-flw':
            if not args.actor or not args.source: parser.error('Source and actor required')
            result=ingest_linkiq(conn,args.source,args.actor)
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
