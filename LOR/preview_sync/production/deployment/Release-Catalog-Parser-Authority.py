"""Update parser-authority catalog wording and cache tag only."""
import hashlib,os,re,subprocess,tempfile,uuid
from pathlib import Path
COMMIT='f414b7626c0e4da7065442a284dd35c94030c556'
OLD='45e255fd02a86ead8ad31bb6ad15fae6473ab544d94e12c62c578773e51b13f7'
NEW='c3b66e259d3177866eef9d69eeb376b08bf75842267d4398a0fb130fe3396fac'
def sha(b):return hashlib.sha256(b).hexdigest()
def atomic(p,b):
 fd,n=tempfile.mkstemp(dir=p.parent)
 try:
  with os.fdopen(fd,'wb') as f:f.write(b);f.flush();os.fsync(f.fileno())
  os.replace(n,p)
 finally:
  if os.path.exists(n):os.unlink(n)
def main():
 if os.geteuid()!=0:raise ValueError('Run through sudo')
 web=Path('/mnt/msb-web/my/lor2db')
 if b'cifs' not in subprocess.check_output(['findmnt','-T',str(web),'-n','-o','FSTYPE']).split():raise ValueError('Website mount unavailable')
 page,js=web/'index.html',web/'catalog.js'
 if any(p.is_symlink() for p in [page,js,*web.parents,web]):raise ValueError('Redirected website path')
 before={page:page.read_bytes(),js:js.read_bytes()}
 if sha(before[js]) not in (OLD,NEW):raise ValueError('Unexpected live catalog.js')
 candidate=subprocess.check_output(['git','-C','/opt/fieldwiring','show',COMMIT+':LOR2DB/Application/landing/catalog.js'])
 if sha(candidate)!=NEW:raise ValueError('Candidate hash mismatch')
 tags=re.findall(rb'catalog\.js\?v=[^"\s<>]+',before[page])
 if len(tags)!=1 or tags[0] not in (b'catalog.js?v=1.1.3',b'catalog.js?v=parser-authority-1'):raise ValueError('Unexpected page script tag')
 after={js:candidate,page:before[page].replace(tags[0],b'catalog.js?v=parser-authority-1',1)}
 parent=Path('/home/msbadmin/lor-catalog-source-releases')
 if not parent.is_dir() or parent.is_symlink():raise ValueError('Backup parent unavailable')
 backup=parent/('parser-authority-'+uuid.uuid4().hex);backup.mkdir(mode=0o700)
 for p,b in before.items():
  saved=backup/(p.name+'.before');saved.write_bytes(b);saved.chmod(0o600)
 changed=[]
 try:
  for p,b in after.items():
   if p.read_bytes()!=before[p]:raise ValueError('Page changed during release')
   changed.append(p);atomic(p,b)
   if p.read_bytes()!=b:raise ValueError('Static verification failed')
 except Exception:
  for p in reversed(changed):
   if p.read_bytes()==after[p]:atomic(p,before[p])
  raise
 print('PASS: parser-controlled catalog wording installed. No restart, ingest or publication. Report: '+str(backup))
if __name__=='__main__':
 try:main()
 except Exception as e:raise SystemExit('HOLD: '+str(e))
