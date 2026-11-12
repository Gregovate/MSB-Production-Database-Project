"""Actual adapter proof in the workflow's disposable PostGIS service only."""
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile

def main():
    assert os.environ.get('GITHUB_ACTIONS') == 'true'
    container=os.environ['MSB_GIS_CI_CONTAINER']
    assert len(container)==64 and all(c in '0123456789abcdef' for c in container)
    def sql(db,query):
        subprocess.run(['docker','exec','-i',container,'psql','-X','-v','ON_ERROR_STOP=1',
                        '-U','postgres','-d',db],input=query,text=True,check=True)
    # Clone the workflow fixture, not any remote database or source cache.
    sql('site_acceptance','CREATE ROLE msbadmin LOGIN SUPERUSER;')
    sql('site_acceptance','CREATE DATABASE msb TEMPLATE site_acceptance;')
    sql('msb',"""CREATE OR REPLACE FUNCTION ref.setup_browser_capabilities(text)
      RETURNS TABLE(can_read_setup boolean,can_manage_setup boolean,role_name text,policy_names text[],display_name text)
      LANGUAGE sql AS $$SELECT true,true,'Manager'::text,ARRAY[]::text[],'CI'::text$$;
      CREATE OR REPLACE FUNCTION ref.setup_inventory_actor(text,boolean)
      RETURNS TABLE(directus_user_id uuid,person_id integer)
      LANGUAGE sql AS $$SELECT '00000000-0000-0000-0000-000000000001'::uuid,1$$;""")
    pid=subprocess.check_output(['docker','inspect','--format','{{.State.Pid}}',container],text=True).strip()
    root=Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory() as directory:
        temp=Path(directory);temp.chmod(0o755)
        gpx=temp/'source.gpx';flw=temp/'source.flw'
        gpx.write_text('<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:o="http://www.topografix.com/GPX/gpx_overlay/0/5"><wpt lat="43.1" lon="-87.1"><name>RA-00</name><type>PANEL</type><extensions><o:label><o:label_text>RA-00</o:label_text></o:label></extensions></wpt><wpt lat="43.2" lon="-87.2"><name>RA-01</name><type>OUT-Combo</type><extensions><o:label><o:label_text>RA-01</o:label_text></o:label></extensions></wpt></gpx>')
        with sqlite3.connect(flw) as c:
            c.executescript('CREATE TABLE Records (UUID TEXT, Hash INT, CableId TEXT, Project TEXT, Deleted TEXT, TimeSpan REAL, TestStatus INT, Standard TEXT, LengthF REAL, LengthM REAL, TesterType TEXT, Operator TEXT); CREATE TABLE RecordData (Hash INT, BinRec BLOB);')
            uuid='68b4579b-2116-4140-8f24-e7a0d170b8be'
            c.execute('INSERT INTO Records VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',(uuid,1,'RA-00 TO RA-01 REG','CI','NO',1,1,'1000BASE-T',120,36.5,'LinkIQ','CI'))
            c.execute('INSERT INTO RecordData VALUES (?,?)',(1,json.dumps({'metadata':{'uuid':uuid,'testId':'RA-00 TO RA-01 REG','timestamp':'2023-11-01T07:03:42'},'settings':{},'sysinfo':{}}).encode()))
        command=['sudo','env','PYTHONDONTWRITEBYTECODE=1',sys.executable,
                 str(root/'Setup/Acceptance/site_171_source_install.py'),
                 '--root',str(root),'--socket',f'/proc/{pid}/root/run/postgresql',
                 '--gpx',str(gpx),'--flw',str(flw),
                 '--gpx-sha',hashlib.sha256(gpx.read_bytes()).hexdigest(),
                 '--flw-sha',hashlib.sha256(flw.read_bytes()).hexdigest()]
        subprocess.run(command+['--probe'],check=True)
        subprocess.run(command,check=True)
        sql('msb',"""DO $$ BEGIN
          IF (SELECT count(*) FROM ref.site_waypoint)<>2
            OR (SELECT count(*) FROM ops.linkiq_test)<>1
          THEN RAISE EXCEPTION 'Initial adapter load incomplete'; END IF;
          END $$;""")
        # A second invocation must stop, rather than create another intake receipt.
        assert subprocess.run(command).returncode != 0
    print('PASS: actual container-local socket, initial source load, replay refusal')


if __name__=='__main__':
    main()
