"""Real API-to-runner HTTP catalog flow against copied fixtures; no real DB/PC."""
import os
from pathlib import Path
import subprocess
import sys
import unittest

class CatalogPreviewTests(unittest.TestCase):
    def test_copy_review_export_publish_current_and_write_boundaries(self):
        script=r'''
from pathlib import Path
import tempfile,zipfile,sys
from contextlib import contextmanager
from unittest.mock import MagicMock
from werkzeug.test import Client
from werkzeug.wrappers import Response
sys.path.insert(0,str(Path('LOR/preview_sync/production').resolve()))
import catalog_preview_entry as preview
from preview_catalog import capture,source_digest
raw='<PreviewClass id="p" Name="Show Background Stage 00 Test" Revision="57" Brightness="20"><PropClass id="prop" Name="Channel" Comment="HW-Flood-01" MasterDimmable="True" ChannelGrid="Regular,1C,1,3"/></PreviewClass>'
with tempfile.TemporaryDirectory() as temp:
    root=Path(temp);original=root/'original';original.mkdir();(original/'Test.lorprev').write_text(raw)
    files=capture(original)
    accepted=dict(schema_version=1,status='COMPLETED',validation='PASSED',lor_version='6.6.12',
        source_folder=r'G:\Shared drives\MSB Database\Database Previews V6.6.12',evidence_id='a'*64,
        source_manifest_sha256=source_digest(files),previews=[{k:files[0][k] for k in ('filename','preview_id','name','revision')}],
        run_id=32,import_run_id=74,preview_count=1,source_sqlite_sha256='b'*64,report_sha256='c'*64,report_url='report')
    archive=root/'master.zip'
    with zipfile.ZipFile(archive,'w') as out:out.write(original/'Test.lorprev','Test.lorprev')
    workspace=root/'workspace';workspace.mkdir()
    app,service=preview.configure(archive,workspace,accepted)
    conn=MagicMock();conn.cursor.return_value.__enter__.return_value.fetchone.return_value={'role_name':'Production Crew'}
    @contextmanager
    def database():yield conn
    preview.base.backend.database=database
    client=Client(app,Response);origin={'Origin':'http://127.0.0.1:8898'};local={'REMOTE_ADDR':'127.0.0.1'}
    def post(path,**kwargs):return client.post(path,headers=origin,environ_overrides=local,**kwargs)
    try:
        assert client.get('/lor2db/catalog.js',environ_overrides=local).status_code==200
        assert client.get('/review/',environ_overrides=local).status_code==200
        assert post('/lor2db/preflight/api/parser/run',json={}).status_code==403
        assert post('/lor2db/preflight/api/runs/32/finish',json={}).status_code==403
        assert client.post('/lor2db/preflight/api/catalog/review',json={},environ_overrides=local).status_code==403
        assert client.get('/review/',environ_overrides={'REMOTE_ADDR':'192.168.5.4'}).status_code==403
        assert post('/review/export',data=raw,content_type='application/xml').status_code==409
        first=post('/lor2db/preflight/api/catalog/review',json={})
        assert first.status_code==200,first.text
        assert first.json['can_publish']
        changed=raw.replace('MasterDimmable="True"','MasterDimmable="False"').replace('Revision="57"','Revision="58"')
        assert post('/review/export',data=changed,content_type='application/xml').status_code==200
        stale=post('/lor2db/preflight/api/catalog/publish',json={'review_id':first.json['review_id'],'confirm_publish':True})
        assert stale.status_code==409,stale.text
        second=post('/lor2db/preflight/api/catalog/review',json={})
        assert second.status_code==200,second.text
        assert second.json['changes'][0]['metadata_changes'][0]['field']=='MasterDimmable'
        published=post('/lor2db/preflight/api/catalog/publish',json={'review_id':second.json['review_id'],'confirm_publish':True})
        assert published.status_code==200,published.text
        current=client.get('/lor2db/preflight/api/current-source',environ_overrides=local)
        assert current.status_code==200,current.text
        assert current.json['schema_version']==2 and current.json['status']=='ACCEPTED'
        assert current.json['evidence_id']==published.json['source']['evidence_id']
        assert (original/'Test.lorprev').read_text()==raw
        conn.commit.assert_not_called()
    finally:service.shutdown();service.server_close()
print('PASS real HTTP catalog fixture: original inputs/DB unchanged, stale review blocked, new catalog consumed')
'''
        env=dict(os.environ,LOR2PC_PREVIEW_MODE='disposable',LOR2PC_PREVIEW_PORT='8898',
                 LOR2PC_PREVIEW_EMAIL='fixture@example.org',LOR2PC_PREVIEW_DSN='host=127.0.0.1 port=15433 dbname=lor2pc_disposable user=lor_preflight_app password=fixture')
        result=subprocess.run([sys.executable,'-c',script],env=env,capture_output=True,text=True,timeout=30)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

if __name__=='__main__':unittest.main()
