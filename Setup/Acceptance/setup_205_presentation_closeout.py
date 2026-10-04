"""Narrow source-only correction under the existing Setup deployment runbook."""
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
SERVER_TARGET='0bd8cc70b798cbcc0c095991d6630661decaf34d'
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
def git(*args, root=REPO): return run(['sudo','git','-C',root,*args])
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
    origin=run(['sudo','git','-C',REPO,'remote','get-url','origin'],record=False)
    require('MSB-Production-Database-Project' in origin,'Unexpected origin')
    server_origin=origin.replace('MSB-Production-Database-Project','MSB-Server-Management')
    run(['sudo','git','-C',REPO,'fetch',server_origin,SERVER_TARGET],record=False)
    require(git('rev-parse',SERVER_TARGET+':scripts/msb_maintenance_admin.py')==ADMIN_BLOB,'Dashboard source differs')
    source=subprocess.check_output(['sudo','git','-C',REPO,'show',SERVER_TARGET+':scripts/msb_maintenance_admin.py'],text=True)
    compile(source,admin,'exec')
    (root/'msb_maintenance_admin.accepted.py').write_text(source)
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

