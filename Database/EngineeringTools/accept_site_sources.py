"""Real-source integration gate called only by the governed disposable runner."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

from site_source_db import (bootstrap_expertgps, ingest_linkiq,
                            export_map_projection, export_waypoint_projection)
from site_source_sync import sha256, extract_gpx, gpx_roundtrip


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    import psycopg
    p = argparse.ArgumentParser(__doc__)
    for name in ('gpx', 'flw', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    for name in ('gpx-sha', 'flw-sha', 'actor'):
        p.add_argument('--' + name, required=True)
    args = p.parse_args()
    require(sha256(args.gpx) == args.gpx_sha, 'GPX hash mismatch')
    require(sha256(args.flw) == args.flw_sha, 'FLW hash mismatch')
    baseline = extract_gpx(args.gpx)
    args.output.mkdir(parents=True, exist_ok=False)
    with psycopg.connect('', autocommit=True) as conn:
        require(conn.info.dbname == 'msb_setup_browser_preview',
                'Real-source gate requires the governed disposable database')
        accepted = bootstrap_expertgps(conn, args.gpx, args.actor, args.gpx_sha)
        replay = bootstrap_expertgps(conn, args.gpx, args.actor, args.gpx_sha)
        require(replay['status'] == 'ALREADY_ACCEPTED', 'GPX replay failed')
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
        exported = gpx_roundtrip(args.gpx, projection, args.output / 'database-export.gpx')
        report = dict(gpx=accepted, gpx_replay=replay,
                      first_import=first, replay_import=second, gpx_export=exported,
                      map_revision=dataset['revision'])
        (args.output / 'acceptance.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        (args.output / 'map.geojson').write_text(json.dumps(dataset), encoding='utf-8')
    require(sha256(args.gpx) == args.gpx_sha and sha256(args.flw) == args.flw_sha,
            'Original source bytes changed')
    print(json.dumps(dict(gpx=accepted, first_import=first['counts'], replay=second['counts'])))
    print(f'GIS_SOURCE_ACCEPTANCE_PASS: {args.output}')


if __name__ == '__main__':
    main()
