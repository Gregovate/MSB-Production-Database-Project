"""Approved initial GIS release profile of the existing maintenance orchestrator."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import tempfile
import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, REPO, SETUP, PYTHON

APP = '439ab237beaae4ac648e7590f824a774969cd84f'
OLD_SHARED = '17c522c4f8ec06549bf7a6d9e8530c61276203f7'
OLD_SETUP = 'e3c39f2781b5a97648dce1f00965110becd2edd6'
GPX = '9001dab9a2218a933c857e0d3a05b34184efc6daf0e5b92f06db84928b5c4611'
FLW = 'de23ad7a096e8118366d82d0524879372a9780834d8c3ce8d5ec91628317403e'
MIGRATIONS = tuple('Database/EngineeringTools/sql/'+n for n in (
    '171_site_infrastructure_schema_candidate.sql',
    '171_panel_circuit_capture_candidate.sql',
    '171_site_reference_operations_candidate.sql'))
EMAIL = 'gliebig@sheboyganlights.org'
CACHE = Path('/home/msbadmin/setup-source-cache')


class SiteDeploy(Deploy):
    def sources(self):
        for digest, ext in ((GPX,'gpx'),(FLW,'flw')):
            path = CACHE / (digest+'.'+ext)
            require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==digest,
                    'Accepted cached source missing or changed: '+ext)

    def health(self, new=False):
        for port, version in (
            (8790,'V0.4.20-picker-sort' if new else 'V0.4.2-controller-uid-explorer'),
            (8794,'V0.3.91-integrated-power' if new else 'V0.3.87-catalog-scene-refresh-r3'),
            (8792,'V0.1.0')):
            h=json.loads(self.run(['curl','-fsS','--max-time','15',f'http://192.168.5.9:{port}/api/health']))
            require(h.get('status')=='ok' and h.get('data_mode')=='postgres' and h.get('version')==version,
                    'Unexpected health on '+str(port))

    def online(self):
        state=self.controller('status'); live=state.get('live',{})
        require(state.get('state')=='ONLINE' and not state.get('last_error')
                and live.get('mode')=='real' and live.get('database_fenced') is False,
                'Healthy real ONLINE required')
        require(all(live.get('services',{}).get(s)=='active' for s in (
            'fieldwiring.service','msb-setup.service','msb-procedures.service',
            'msb-people.service','lor-preflight-api.service','msb-work-management.service'))
            and live.get('services',{}).get('container:msb-directus')=='running','Services unhealthy')
        b=live.get('backups',{})
        require(b.get('nas_mounted') is True and b.get('replication',{}).get('current_run_ok') is True,
                'Backup replication unhealthy')

    def baseline(self):
        for root, sha in ((REPO,OLD_SHARED),(SETUP,OLD_SETUP)):
            require(self.git('rev-parse','HEAD',root=root)==sha and
                    not self.git('status','--porcelain',root=root),'Source baseline drift: '+root)

    def database_preflight(self):
        # Catalog discovery already showed only this existing table; refuse replay,
        # conflicting schemas and any newly discovered installation.
        value=json.loads(self.sql("""BEGIN READ ONLY;
          SELECT json_build_object('tables',(SELECT json_agg(n.nspname||'.'||c.relname ORDER BY n.nspname,c.relname)
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p','v')
              AND c.relname ~ '^(site_|linkiq_)'),
            'functions',(SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
              WHERE n.nspname='ref' AND p.proname ~ '^site_'),
            'networks',(SELECT count(*) FROM ref.site_network),
            'manager',(SELECT can_manage_setup FROM ref.setup_browser_capabilities('gliebig@sheboyganlights.org')),
            'postgis',(SELECT extversion FROM pg_extension WHERE extname='postgis'));
          ROLLBACK;"""))
        require(value==dict(tables=['ref.site_network'],functions=0,networks=27,manager=True,postgis='3.5.2'),
                'Initial database baseline differs; do not overwrite or replay')

    def source_command(self, probe=False):
        # No TCP whitelist: use the container's already existing local socket.
        pid=self.run(['sudo','docker','inspect','--format','{{.State.Pid}}','msb-postgres'])
        require(pid.isdigit() and int(pid)>1,'Invalid PostgreSQL container PID')
        directory=self.sql('SHOW unix_socket_directories;')
        require(directory=='/var/run/postgresql','Unreviewed Unix socket directory')
        command=['sudo','env','PYTHONDONTWRITEBYTECODE=1',PYTHON,str(Path(__file__).with_name('site_171_source_install.py')),
                 '--root',self.worktree,'--socket',f'/proc/{pid}/root{directory}',
                 '--gpx',str(CACHE/(GPX+'.gpx')),'--flw',str(CACHE/(FLW+'.flw')),
                 '--gpx-sha',GPX,'--flw-sha',FLW]
        if probe: command.append('--probe')
        return command

    def preflight(self):
        require(self.m==json.loads(Path(__file__).with_name('setup_171_release.json').read_text()),
                'Unreviewed release manifest')
        require(self.m['target']==APP and self.m['candidate']==APP
                and self.m['shared']==OLD_SHARED and self.m['old_setup']==OLD_SETUP,
                'Release identities differ')
        for name,digest in self.m['helpers'].items():
            require(hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()==digest,
                    'Transported helper differs: '+name)
        self.mark('ONLINE initial GIS release preflight')
        self.online(); self.baseline(); self.health()
        require(not self.run(['ss','-ltnH','sport = :8898']),'Preview port occupied')
        # Hold the same source lock through preparation, maintenance and cleanup.
        self.source_lock=(CACHE/'.preview-source.lock').open('r')
        fcntl.flock(self.source_lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        self.sources(); self.database_preflight()
        self.git('fetch','origin','+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base','--is-ancestor',APP,'origin/main')
        for old in (OLD_SHARED,OLD_SETUP): self.git('merge-base','--is-ancestor',old,APP)
        require(self.git('rev-parse',APP+'^{tree}')==self.m['tree'],'Approved tree differs')
        for path,blob in self.m['migration_blobs'].items():
            require(self.git('rev-parse',APP+':'+path)==blob,'Migration blob differs')
        self.new_tables=[]
        for path in MIGRATIONS:
            sql=self.git('show',APP+':'+path)
            self.new_tables += re.findall(r'CREATE TABLE (?:IF NOT EXISTS )?((?:ref|ops)\.\w+)',sql)
        self.new_tables=sorted(set(self.new_tables)-{'ref.site_network'})
        require(self.new_tables==self.m['new_tables'],'Reviewed table set differs')
        self.worktree=tempfile.mkdtemp(prefix='msb-171-release-',dir='/tmp')
        os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,APP)
        for suite in ('Setup/Application','FieldWiring/Application','Procedures/Application'):
            self.run(['sudo','-u','fieldwiring','-H','env','PYTHONDONTWRITEBYTECODE=1',
                      'bash','-c','cd '+self.worktree+' && '+PYTHON+
                      ' -m pytest -q -p no:cacheprovider '+suite],timeout=300)
        self.run(self.source_command(probe=True))
        self.capture()  # Read/syntax proof only; no equality across ONLINE edits.
        self.baseline(); self.online(); self.database_preflight()
        self.mark('preflight PASS')

    def capture(self):
        # Preserve pre-existing business data and Directus authority. Only the
        # fixed, initially absent table set is excluded from frozen comparison.
        excluded=','.join("'"+x+"'" for x in self.new_tables)
        return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format($q$SELECT json_build_object('table',%L,'digest',md5(coalesce(string_agg(to_jsonb(t)::text,'' ORDER BY to_jsonb(t)::text),''))) FROM %I.%I t;$q$,
            n.nspname||'.'||c.relname,n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE c.relkind IN ('r','p') AND (n.nspname IN ('ref','ops')
            OR (n.nspname='public' AND c.relname IN
              ('directus_users','directus_roles','directus_policies','directus_permissions','directus_access')))
            AND n.nspname||'.'||c.relname NOT IN (""" + excluded + r""")
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def apply_migrations(self):
        self.baseline(); self.sources(); self.database_preflight()
        for path in MIGRATIONS:
            self.frozen(self.controller('status'))
            self.mark('applying '+path)
            self.sql(self.git('show',APP+':'+path))
        self.frozen(self.controller('status'))
        self.mark('initial accepted GPX FLW source load')
        receipt=self.run(self.source_command(),timeout=900)
        (self.root/'source-install.json').write_text(receipt+'\n')
        self.sources()

    def validate(self):
        result=json.loads(self.sql("""BEGIN READ ONLY;
          SELECT json_build_object(
            'waypoints',(SELECT count(*) FROM ref.site_waypoint),
            'tracks',(SELECT count(*) FROM ref.site_track),
            'gpx_bindings',(SELECT count(*) FROM ref.site_waypoint_source_binding WHERE source_sha256='""" + GPX + """'),
            'flw_appearances',(SELECT count(*) FROM ops.linkiq_test_appearance WHERE source_sha256='""" + FLW + """'),
            'manager',ref.site_power_access('""" + EMAIL + """')->'can_edit',
            'shared_ids',(SELECT ref.site_power_snapshot('""" + EMAIL + """')->'waypoints' IS NOT NULL),
            'references',(SELECT ref.site_reference_snapshot()->'waypoints' IS NOT NULL));
          ROLLBACK;"""))
        require(result['waypoints']==240 and result['tracks']==220 and result['gpx_bindings']==240
                and result['flw_appearances']>0 and result['manager'] is True
                and result['shared_ids'] and result['references'],'Imported model validation failed')
        self.sql("""BEGIN READ ONLY; DO $gate$ BEGIN
          IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname IN ('ref','ops') AND c.relkind='r'
              AND c.relname ~ '^(site_|linkiq_)'
              AND has_table_privilege('fieldwiring_app',c.oid,'INSERT,UPDATE,DELETE,TRUNCATE'))
          THEN RAISE EXCEPTION 'Broad direct site DML'; END IF;
          IF NOT has_function_privilege('fieldwiring_app',
            'ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)','EXECUTE')
            OR NOT has_function_privilege('fieldwiring_app','ref.site_reference_snapshot()','EXECUTE')
          THEN RAISE EXCEPTION 'Required command/read EXECUTE absent'; END IF;
          END $gate$; ROLLBACK;""")

    def promote_source(self, baseline):
        self.baseline()
        self.git('checkout','--detach',APP,root=SETUP)
        self.git('merge','--ff-only',APP)
        for root in (SETUP,REPO):
            require(self.git('rev-parse','HEAD',root=root)==APP
                    and not self.git('status','--porcelain',root=root),'Promoted source differs')

    def before_reopen(self, baseline):
        self.sources(); self.validate(); self.frozen(self.controller('status'))
        require(self.capture()==baseline,'Existing data changed before reopening')

    def live_validation(self):
        self.health(new=True); self.validate()
        code=self.run(['curl','-sS','--max-time','15','-o','/dev/null','-w','%{http_code}',
                       'http://192.168.5.9:8790/api/power'])
        require(code in ('401','403'),'Unidentified power request was not denied')

    def cleanup(self):
        super().cleanup()
        if getattr(self,'source_lock',None):
            self.source_lock.close()


if __name__=='__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Deployment signal '+str(signum))
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGHUP,interrupted)
    orchestrator.Deploy=SiteDeploy
    raise SystemExit(orchestrator.main())
