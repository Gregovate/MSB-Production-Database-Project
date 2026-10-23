"""Real-source integration gate called only by the governed disposable runner."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

from site_source_db import (bootstrap_expertgps, ingest_linkiq,
                            export_map_projection, export_waypoint_projection, restore_gpx_source)
from site_source_sync import sha256, extract_gpx, gpx_roundtrip


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def validate_shared_consumers(conn, email):
    """Exercise real command boundaries on imported IDs; roll back fixtures only.

    Never invent a preview role. The existing Directus operator must authorize
    both consumers. This is acceptance against one clone, not a second importer.
    """
    import uuid
    with conn.cursor() as cur:
        cur.execute('SAVEPOINT shared_consumers')
        try:
            cur.execute('SELECT ref.site_power_snapshot(%s)', (email,))
            power = cur.fetchone()[0]
            cur.execute('SELECT ref.site_reference_snapshot()')
            gis = cur.fetchone()[0]
            require({w['id']: w['name'] for w in power['waypoints']} ==
                    {w['id']: w['label'] for w in gis['waypoints']},
                    'FieldWiring and GIS disagree on current waypoint identities/names')
            require(power['waypoints'], 'Imported waypoint picker is empty')
            waypoint = power['waypoints'][0]['id']
            revision = power['revision']
            def command(kind, fields):
                nonlocal revision
                fields = dict(source_evidence='Disposable combined acceptance fixture',
                              verification_status='UNVERIFIED', **fields)
                cur.execute('SELECT ref.site_power_command(%s,%s::uuid,%s,%s,NULL,%s::jsonb)',
                            (email, str(uuid.uuid4()), revision, kind, json.dumps(fields)))
                result = cur.fetchone()[0]
                revision = result['revision']
                return result['target_id']
            panel = command('panel', dict(panel_name='DISPOSABLE '+str(uuid.uuid4())))
            breaker = command('breaker', dict(site_panel_id=panel,breaker_name='DISPOSABLE 18/20',rated_amps=20,pole_count=2))
            circuits = []
            for pole in (1, 2):
                circuit = command('circuit',dict(site_panel_id=panel,circuit_code=str(pole),site_power_breaker_id=breaker,breaker_pole=pole))
                circuits.append(circuit)
                device = command('device',dict(device_name='DISPOSABLE receptacle '+str(pole),device_kind='OUTLET',site_waypoint_id=waypoint))
                command('feed',dict(source_circuit_id=circuit,destination_device_id=device))
            cur.execute('SELECT ref.site_power_breaker_impact(%s,%s)', (email,breaker))
            impact = cur.fetchone()[0]
            require(len(impact['paths']) == 2 and all(p['waypoint_id'] == waypoint for p in impact['paths']),
                    'Grouped breaker lost a receptacle or imported waypoint')
            cur.execute('SELECT ref.site_reference_snapshot()')
            mapped = cur.fetchone()[0]['destinations']
            require(all(any(d['site_power_circuit_id']==c and d['site_waypoint_id']==waypoint for d in mapped) for c in circuits),
                    'GIS consumer lost a FieldWiring circuit/receptacle relationship')
            return {'status':'PASS', 'waypoint_count':len(power['waypoints']),
                    'shared_waypoint_id':waypoint, 'fixture_changes':'ROLLED_BACK'}
        finally:
            cur.execute('ROLLBACK TO SAVEPOINT shared_consumers')
            cur.execute('RELEASE SAVEPOINT shared_consumers')


def main():
    from site_db_connection import connect
    p = argparse.ArgumentParser(__doc__)
    for name in ('gpx', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    for name in ('gpx-sha', 'actor'):
        p.add_argument('--' + name, required=True)
    p.add_argument('--operator-email', required=True)
    p.add_argument('--flw', type=Path)
    p.add_argument('--flw-sha')
    args = p.parse_args()
    require(bool(args.flw) == bool(args.flw_sha), 'FLW path and hash must be supplied together')
    require(sha256(args.gpx) == args.gpx_sha, 'GPX hash mismatch')
    if args.flw:
        require(sha256(args.flw) == args.flw_sha, 'FLW hash mismatch')
    baseline = extract_gpx(args.gpx)
    args.output.mkdir(parents=True, exist_ok=False)
    with connect('') as conn:
        require(conn.info.dbname == 'msb_setup_browser_preview',
                'Real-source gate requires the governed disposable database')
        accepted = bootstrap_expertgps(conn, args.gpx, args.actor, args.gpx_sha)
        replay = bootstrap_expertgps(conn, args.gpx, args.actor, args.gpx_sha)
        require(replay['status'] == 'ALREADY_ACCEPTED', 'GPX replay failed')
        first = second = {'status': 'NOT_REQUESTED', 'counts': {}}
        if args.flw:
            first = ingest_linkiq(conn, args.flw, args.actor)
            with conn.cursor() as cur:
                cur.execute('SELECT test_uuid::text, original_result, physical_site_cable_id FROM ops.linkiq_test ORDER BY test_uuid')
                before = cur.fetchall()
            second = ingest_linkiq(conn, args.flw, args.actor)
            require(second['counts']['new_tests'] == 0 and second['counts']['new_appearances'] == 0,
                    'FLW replay duplicated evidence')
            with conn.cursor() as cur:
                cur.execute('SELECT test_uuid::text, original_result, physical_site_cable_id FROM ops.linkiq_test ORDER BY test_uuid')
                require(cur.fetchall() == before, 'Replay changed original evidence or cable identities')
                cur.execute('SELECT count(*) FROM ops.linkiq_test_appearance WHERE source_sha256=%s', (args.flw_sha,))
                require(cur.fetchone()[0] == first['source_rows'], 'Source appearances lost')
                cur.execute('SELECT count(*) FROM ops.linkiq_intake_review WHERE source_sha256=%s', (args.flw_sha,))
                require(cur.fetchone()[0] == first['unique_uuid_tests'], 'Reconciliation proposal missing')
        dataset = export_map_projection(conn)
        for kind, source_key in [('waypoint', 'waypoints'), ('source_track', 'tracks')]:
            require(sum(f['properties']['kind'] == kind for f in dataset['features']) == len(baseline[source_key]),
                    f'Map projection lost {kind} records')
        projection = export_waypoint_projection(conn, args.gpx_sha)
        restored_path = args.output / 'archived-source.gpx'
        restored = restore_gpx_source(conn, args.gpx_sha, restored_path)
        require(restored_path.read_bytes() == args.gpx.read_bytes(), 'Database GPX archive lost source bytes')
        exported = gpx_roundtrip(restored_path, projection, args.output / 'database-export.gpx')
        consumers = validate_shared_consumers(conn, args.operator_email)
        report = dict(shared_consumers=consumers, gpx=accepted, gpx_replay=replay, gpx_archive=restored,
                      first_import=first, replay_import=second, gpx_export=exported,
                      map_revision=dataset['revision'])
        (args.output / 'acceptance.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        (args.output / 'map.geojson').write_text(json.dumps(dataset), encoding='utf-8')
    require(sha256(args.gpx) == args.gpx_sha and
            (not args.flw or sha256(args.flw) == args.flw_sha),
            'Original source bytes changed')
    print(json.dumps(dict(gpx=accepted, first_import=first['counts'], replay=second['counts'])))
    print(f'GIS_SOURCE_ACCEPTANCE_PASS: {args.output}')


if __name__ == '__main__':
    main()
