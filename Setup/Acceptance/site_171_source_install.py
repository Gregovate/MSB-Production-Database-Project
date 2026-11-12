"""Initial approved #171 source load through the existing local admin socket.
No public importer, TCP maintenance bypass, fixtures or dependency installation.
"""
import argparse
import json
from pathlib import Path
import sys
import tempfile


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def execute(root, socket, gpx, flw, gpx_sha, flw_sha, probe=False):
    gpx, flw = Path(gpx), Path(flw)
    sys.path.insert(0, str(Path(root) / 'Database/EngineeringTools'))
    from site_db_connection import connect
    from site_source_sync import sha256
    from site_source_db import bootstrap_expertgps, seed_gpx_panels, ingest_linkiq, restore_gpx_source
    require(str(socket).startswith('/proc/') and '/root/' in str(socket),
            'Only discovered container filesystem socket is allowed')
    with connect('host=' + str(socket) + ' dbname=msb user=msbadmin') as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT current_database(),current_user,inet_client_addr()')
            require(cur.fetchone() == ('msb', 'msbadmin', None), 'Local admin boundary differs')
        if probe:
            print('LOCAL_ADMIN_SOCKET_PASS')
            return
        require(sha256(gpx) == gpx_sha and sha256(flw) == flw_sha, 'Source hash differs')
        # The orchestrator owns the fence; this independently rejects normal
        # client sessions immediately before invoking the established importers.
        with conn.cursor() as cur:
            cur.execute("""SELECT count(*) FROM pg_stat_activity
                WHERE datname=current_database() AND backend_type='client backend'
                AND NOT (usename='msbadmin' AND client_addr IS NULL)""")
            require(cur.fetchone()[0] == 0, 'Normal Production clients remain')
        actor = 'gliebig@sheboyganlights.org'
        gpx_result = bootstrap_expertgps(conn, Path(gpx), actor, gpx_sha)
        require(gpx_result['status'] == 'ACCEPTED', 'Initial GPX load already present')
        panels = seed_gpx_panels(conn, gpx_sha, actor)
        flw_result = ingest_linkiq(conn, Path(flw), actor)
        with tempfile.TemporaryDirectory(prefix='msb-171-archive-check-') as directory:
            restored=Path(directory)/'source.gpx'
            restore_gpx_source(conn,gpx_sha,restored)
            require(restored.read_bytes()==Path(gpx).read_bytes(),'GPX archive differs')
        with conn.cursor() as cur:
            cur.execute('SELECT count(*) FROM ops.linkiq_test')
            require(cur.fetchone()[0]==flw_result['unique_uuid_tests'],'FLW UUID count differs')
            cur.execute('SELECT count(*) FROM ops.linkiq_test_appearance WHERE source_sha256=%s',(flw_sha,))
            require(cur.fetchone()[0]==flw_result['source_rows'],'FLW appearances incomplete')
        require(not flw_result['replay'] and flw_result['counts']['known_tests'] == 0,
                'FLW baseline changed; stop without replay')
        require(sha256(gpx) == gpx_sha and sha256(flw) == flw_sha, 'Source bytes changed')
        print(json.dumps({'gpx': gpx_result, 'panels': panels,
                          'flw': {k:v for k,v in flw_result.items() if k!='reconciliation'}}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    for name in ('root','socket','gpx','flw','gpx-sha','flw-sha'):
        parser.add_argument('--'+name, required=True)
    parser.add_argument('--probe', action='store_true')
    args = parser.parse_args()
    execute(args.root,args.socket,args.gpx,args.flw,args.gpx_sha,args.flw_sha,args.probe)
