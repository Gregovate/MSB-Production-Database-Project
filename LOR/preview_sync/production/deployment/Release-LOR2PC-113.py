"""Deploy verified updater 1.1.3 website files only; preserve all runtime services."""
import hashlib,json,os,re,subprocess,tempfile,uuid
from pathlib import Path
COMMIT='fc42101d21dde9f62dc3d5fb7fe56a74979c3707'
PREFIX='LOR2DB/Application/landing/'
ASSET='pc/downloads/MSB-PC-Preview-Updater-1.1.3-pilot.zip'
HASHES={
 ASSET:'0fa157ec2d0693c0c3084fb39b1a9d55ce64b86f6222301cab2b27a936733362',
 'pc/downloads/updater-release.json':'8d6197b677058f43b9dd378a8f390911829004e28a2714224649f0205549586a',
 'pc/handoff.js':'4cb0af81791ac55abb7a5e057153173385b260d0f66adc452df1d2640d4abdaa',
 'pc/index.html':'edea8e67454f8f920dfd3a748d46bba3016503889324a6212f333512ab41c3aa',
 'catalog.js':'45e255fd02a86ead8ad31bb6ad15fae6473ab544d94e12c62c578773e51b13f7'}
OLD={'pc/handoff.js':'92f20cdd9f55ed57238f0586910d4bd844f511ecc2bfa3f91d56ef7ad7a2935e','pc/index.html':'fd60eb5547272389d3786b5438402614dbd5d7270c27e8a9ff0d690439b2f77d','catalog.js':'da6ff01673b4d41b804179a8ade367426eea9005f9601c82b7ff85a5480dd3cb'}
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(data):return hashlib.sha256(data).hexdigest()
def atomic(path,data):
 fd,name=tempfile.mkstemp(dir=path.parent)
 try:
  with os.fdopen(fd,'wb') as f:f.write(data);f.flush();os.fsync(f.fileno())
  os.replace(name,path)
 finally:
  if os.path.exists(name):os.unlink(name)
def promote(web,backup,candidates):
 prior={}
 for name,h in HASHES.items():
  p=web/name
  require(not any(x.is_symlink() for x in [p,*p.parents]),'Redirected website path: '+name)
  require(sha(candidates[name])==h,'Candidate checksum mismatch: '+name)
  old=p.read_bytes() if p.exists() else None
  if name in OLD:require(old is not None and sha(old) in (OLD[name],h),'Unexpected live website: '+name)
  else:require(old is None or sha(old)==h,'Existing release metadata or immutable asset differs: '+name)
  prior[name]=old
 page=web/'index.html';require(not page.is_symlink(),'Redirected landing page');old=page.read_bytes()
 tags=re.findall(rb'catalog\.js\?v=[^"\s<>]+',old)
 require(len(tags)==1 and tags[0] in (b'catalog.js?v=4',b'catalog.js?v=20261101-presentation-v5',b'catalog.js?v=1.1.3'),'Unexpected catalog script reference')
 prior['index.html']=old;candidates['index.html']=old.replace(tags[0],b'catalog.js?v=1.1.3',1)
 release=json.loads(candidates['pc/downloads/updater-release.json'])
 require(release['installer_sha256']==HASHES[ASSET] and release['latest_version']=='1.1.3' and release['minimum_version']=='1.1.3','Release metadata mismatch')
 backup.mkdir(mode=0o700)
 for name,data in prior.items():
  if data is not None:
   p=backup/(name.replace('/','__')+'.before');p.write_bytes(data);p.chmod(0o600)
 print('Backup/report: '+str(backup),flush=True)
 changed=[]
 try:
  # Installer precedes metadata; browser code precedes pages that expose it.
  for name in [ASSET,'pc/downloads/updater-release.json','pc/handoff.js','catalog.js','pc/index.html','index.html']:
   p=web/name;now=p.read_bytes() if p.exists() else None
   require(now==prior[name],'Website changed during release: '+name)
   if now==candidates[name]:continue
   changed.append(name);atomic(p,candidates[name]);require(p.read_bytes()==candidates[name],'Installed verification failed: '+name)
 except Exception:
  for name in reversed(changed):
   p=web/name
   if p.exists() and p.read_bytes()==candidates[name]:
    if prior[name] is not None:atomic(p,prior[name])
    elif name!=ASSET:p.unlink()
  raise
 (backup/'receipt.json').write_text(json.dumps({'source_commit':COMMIT,'files':{n:sha((web/n).read_bytes()) for n in candidates}},indent=2))
 print('PASS: updater 1.1.3 download, startup version metadata and compact review pages installed. No restart, ingest, catalog publication or preview write.',flush=True)
def main():
 require(os.geteuid()==0,'Run through sudo')
 web=Path('/mnt/msb-web/my/lor2db')
 require(b'cifs' in subprocess.check_output(['findmnt','-T',str(web),'-n','-o','FSTYPE']).split(),'Website CIFS mount unavailable')
 candidates={n:subprocess.check_output(['git','-C','/opt/fieldwiring','show',COMMIT+':'+PREFIX+n]) for n in HASHES}
 parent=Path('/home/msbadmin/lor-catalog-source-releases');require(parent.is_dir() and not parent.is_symlink(),'Backup parent unavailable')
 promote(web,parent/('pc113-'+uuid.uuid4().hex),candidates)
if __name__=='__main__':
 try:main()
 except Exception as error:raise SystemExit('HOLD: '+str(error))
