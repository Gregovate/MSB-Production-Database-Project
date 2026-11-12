"""Narrow source-only correction under the existing Setup deployment runbook."""
import base64
import zlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from datetime import datetime, timezone

REPO='/opt/fieldwiring'
SETUP='/opt/msb-setup'
OLD='e2f58d016f015f1ac695940e9ab67c61c04a8a8a'
SHARED='6dd05c4aa5ef8f50fe172145c3ae281cc245a101'
VERSION='V0.3.38-setup-day-milestones'
SERVER_TARGET='8ddc11a4b8cf056d3d6e03de3f9b158e21529645'
# Immutable transport bundle of the merged Server Management file; no second repository login.
ADMIN_PACKAGE='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'
ADMIN_BLOB='08394cc176b0534bebe17c01d30e4cfb66da7b56'
CONTROL=['sudo','python3','/opt/msb-maintenance/msb_maintenance_controller.py','--config','/etc/msb-maintenance/config.json']
PYTHON='/opt/fieldwiring/.venv/bin/python'
target=sys.argv[1]
root=Path('/home/msbadmin/setup-deployment-reports')/('PR293-presentation-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
root.mkdir(parents=True)
log=(root/'report.txt').open('w',buffering=1)
lock=open('/home/msbadmin/.msb-production-deploy.lock','a')
fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
candidate='/tmp/'+root.name
advanced=False
installed=False
admin='/opt/msb-maintenance/msb_maintenance_admin.py'
backup=str(root/'msb_maintenance_admin.previous.py')

def run(argv, input=None, timeout=300, record=True):
    if record: log.write(repr(argv)+'\n')
    r=subprocess.run(argv,input=input,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    if record: log.write(r.stdout+'\n')
    if r.returncode: raise RuntimeError('Command failed; inspect report')
    return r.stdout.strip()
def git(*args, root=REPO): return run(['sudo','env','GIT_TERMINAL_PROMPT=0','git','-C',root,*args])
def require(value,message):
    if not value: raise RuntimeError(message)
def online():
    s=json.loads(run(CONTROL+['status']))
    require(s['state']=='ONLINE' and not s.get('last_error') and s['live']['database_fenced'] is False,'Maintenance status not healthy ONLINE')
def health():
    for _ in range(30):
        try:
            s=json.loads(run(['curl','-fsS','--max-time','3','http://192.168.5.9:8794/api/health']))
            require(s['status']=='ok' and s['version']==VERSION and s['data_mode']=='postgres','Setup identity differs')
            return
        except Exception: time.sleep(1)
    raise RuntimeError('Setup health timed out')
def fingerprint():
    sql="BEGIN READ ONLY; SELECT md5(string_agg(v::text,'' ORDER BY name)) FROM (SELECT 'task' name,jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) v FROM ref.setup_task t UNION ALL SELECT 'resource',jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) FROM ref.setup_resource t UNION ALL SELECT 'task_resource',jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) FROM ref.setup_task_resource t UNION ALL SELECT 'session',jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) FROM ops.setup_session t UNION ALL SELECT 'session_task',jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) FROM ops.setup_session_task t UNION ALL SELECT 'work_day',jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) FROM ops.setup_work_day t) q; COMMIT;"
    return run(['sudo','docker','exec','-i','msb-postgres','psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','msbadmin','-d','msb'],input=sql)
try:
    require(git('rev-parse','HEAD',root=SETUP)==OLD,'Live Setup changed: STOP')
    require(git('rev-parse','HEAD')==SHARED,'Shared checkout changed: STOP')
    require(not git('status','--porcelain',root=SETUP) and not git('status','--porcelain'),'Dirty checkout: STOP')
    online(); health()
    git('fetch','origin','+refs/heads/main:refs/remotes/origin/main')
    git('merge-base','--is-ancestor',target,'origin/main')
    git('merge-base','--is-ancestor',OLD,target)
    changed=set(git('diff','--name-only',OLD,target,'--','Setup/Application',':(exclude)Setup/Application/*.md').splitlines())
    require(changed=={'Setup/Application/production.html','Setup/Application/test_setup_internal_analytics_contract.py','Setup/Application/test_setup_production_contract.py'},'Unexpected application change: STOP')
    require(git('show',target+':Setup/Application/production.html')==git('show',OLD+':Setup/Application/production.html').replace('Updated 2026-10-02','Updated 2026-10-04'),'Footer correction scope differs: STOP')
    require(not git('diff','--name-only',OLD,target,'--',':(glob)**/*.sql'),'SQL changed: STOP')
    packed=zlib.decompress(base64.b64decode(ADMIN_PACKAGE))
    packed_blob=hashlib.sha1(b'blob '+str(len(packed)).encode()+b'\0'+packed).hexdigest()
    require(packed_blob==ADMIN_BLOB,'Packaged dashboard source differs')
    source=packed.decode('utf-8')
    compile(source,admin,'exec')
    (root/'msb_maintenance_admin.accepted.py').write_bytes(packed)
    git('worktree','add','--detach',candidate,target)
    run(['sudo','python3',candidate+'/Setup/Acceptance/check_setup_ui_update_date.py','--repository',REPO,'--target',target])
    run(['sudo','-u','fieldwiring','-H','env','PYTHONDONTWRITEBYTECODE=1','bash','-c','cd '+candidate+' && '+PYTHON+' -m pytest -q -p no:cacheprovider Setup/Application'])
    before=fingerprint(); online()
    require(git('rev-parse','HEAD',root=SETUP)==OLD and not git('status','--porcelain',root=SETUP),'Setup drift during checks')
    run(['sudo','cp','-p',admin,backup])
    owner,group,mode=run(['sudo','stat','-c','%u %g %a',admin]).split()
    git('checkout','--detach',target,root=SETUP); advanced=True
    run(['sudo','systemctl','restart','msb-setup.service']); health()
    run(['sudo','install','-o',owner,'-g',group,'-m',mode,str(root/'msb_maintenance_admin.accepted.py'),admin]); installed=True
    require(git('hash-object',admin)==ADMIN_BLOB,'Installed dashboard differs from accepted source')
    run(['sudo','systemctl','restart','msb-maintenance-admin.service'])
    for _ in range(30):
        try:
            code=run(['curl','-s','--max-time','3','-o','/dev/null','-w','%{http_code}','http://192.168.5.9:8799/'])
            if code=='401': break
        except Exception: pass
        time.sleep(1)
    else: raise RuntimeError('Dashboard authenticated listener not ready')
    run(['sudo','-u','fieldwiring','-H','env','PYTHONDONTWRITEBYTECODE=1','bash','-c','cd '+SETUP+' && '+PYTHON+' -m pytest -q -p no:cacheprovider Setup/Application/test_setup_internal_analytics_contract.py Setup/Application/test_setup_production_contract.py'])
    require(git('rev-parse','HEAD',root=SETUP)==target and not git('status','--porcelain',root=SETUP),'Final Setup identity differs')
    require(git('rev-parse','HEAD')==SHARED,'Shared checkout moved')
    require(fingerprint()==before,'Data changed during source-only deployment; inspect report')
    online()
    run(CONTROL+['stage','PR293 migration 069 PASS; presentation corrected; browser closeout pending'])
    (root/'result.json').write_text(json.dumps(dict(result='PASS',old_setup=OLD,target=target,server_source=SERVER_TARGET,admin_blob=ADMIN_BLOB,version=VERSION,ui_date='2026-10-04',fingerprint=before),indent=2)+'\n')
    print('PASS: footer and dashboard installed; browser check pending; report: '+str(root))
except Exception as exc:
    log.write('STOP '+repr(exc)+'\n')
    try:
        if installed:
            run(['sudo','cp','-p',backup,admin]); run(['sudo','systemctl','restart','msb-maintenance-admin.service'])
        if advanced:
            git('checkout','--detach',OLD,root=SETUP); run(['sudo','systemctl','restart','msb-setup.service']); health()
    except Exception as recovery: log.write('Recovery failed '+repr(recovery)+'\n')
    print('STOP: '+str(exc)+'; report: '+str(root)); sys.exit(1)
finally:
    try: git('worktree','remove','--force',candidate)
    except Exception: pass
    log.close()

