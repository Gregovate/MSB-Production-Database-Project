"""Disposable catalog browser review using copied master bytes; NEVER deploy.

Production DB access is performed by the parent clone launcher only for pg_dump.
This process uses clone SELECTs and isolated local evidence/export files only.
"""
import io
import json
import os
from pathlib import Path
import secrets
import sys
import threading
from types import SimpleNamespace
import zipfile
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).parent))
import preview_entry as base  # Explicit disposable DSN/port guards execute first.
sys.path.insert(0, str(base.ROOT/'Docs/01_LOR_System/02_Data_Extraction/Parser'))
from preview_catalog import Catalog, digest
from lor_operator_runner import RequestHandler
from http.server import ThreadingHTTPServer
from flask import request
from werkzeug.wrappers import Response
import current_source


def configure(archive, workspace, accepted=None):
    archive, workspace = Path(archive), Path(workspace)
    if not workspace.is_dir() or workspace.is_symlink():
        raise RuntimeError('A private existing disposable workspace is required')
    if accepted is None:
        with base.backend.database() as conn:
            accepted = current_source.load_current_source(conn, base.backend.RealDictCursor)
    # Rebind only this disposable process to the isolated copy path. Retain the
    # actual captured-byte digest; it must match the copied files exactly.
    folder=workspace/('Database Previews V'+accepted['lor_version'])
    folder.mkdir()
    with zipfile.ZipFile(archive) as source:
        if len(source.infolist())>500 or sum(i.file_size for i in source.infolist())>512*1024*1024:
            raise RuntimeError('Copied master archive exceeds review bounds')
        seen=set()
        for entry in source.infolist():
            name=entry.filename
            if ('/' in name or '\\' in name or not name.lower().endswith('.lorprev')
                    or name.casefold() in seen or entry.file_size>16*1024*1024):
                raise RuntimeError('Only flat unique preview exports are allowed in review archive')
            seen.add(name.casefold())
            (folder/name).write_bytes(source.read(entry))
    doc=dict(accepted,source_folder=str(folder),disposable_original_evidence_id=accepted['evidence_id'])
    doc.pop('evidence_id');doc['evidence_id']=digest(doc)
    evidence=workspace/'catalog-evidence'
    # Verify exact copied source BEFORE serving, without registering the baseline.
    from preview_catalog import capture, source_digest
    files=capture(folder)
    observed=source_digest(files)
    expected=accepted['source_manifest_sha256']
    validation=dict(expected_digest=expected,observed_digest=observed,expected_count=accepted['preview_count'],
                    observed_count=len(files),copied_files=[{k:f[k] for k in ('filename','preview_id','revision','sha256')} for f in files])
    (workspace/'source-validation.json').write_text(json.dumps(validation,indent=2),encoding='utf-8')
    if observed!=expected:
        raise RuntimeError('Copied source validation failed: expected '+expected+'; observed '+observed+
                           '; files '+str(len(files))+'. Retained source-validation.json; no review started.')
    original_loader=current_source.load_current_source
    current_source.load_current_source=lambda conn, factory:dict(doc)
    token=secrets.token_hex(32)
    runner=SimpleNamespace(store=SimpleNamespace(read=lambda:{'current_preview_folder':str(folder),'current_lor_version':doc['lor_version']}),
                           operation_lock=threading.Lock(),public_state=lambda:{'current_lor_version':doc['lor_version'], 'current_preview_folder':'DISPOSABLE COPY ONLY'})
    service=ThreadingHTTPServer(('127.0.0.1',0),RequestHandler)
    service.runner=runner
    thread=threading.Thread(target=service.serve_forever,daemon=True);thread.start()
    os.environ.update(LOR_PREVIEW_CATALOG_ENABLED='true',LOR_CATALOG_PUBLISHERS=base.EMAIL,
                      LOR_CATALOG_ORIGIN='http://127.0.0.1:8898',LOR_CATALOG_ROOT=str(evidence),
                      LOR_RUNNER_URL='http://127.0.0.1:'+str(service.server_port),LOR_RUNNER_TOKEN=token,
                      LOR_PREFLIGHT_OPERATORS='catalog-review-no-parser@example.invalid')

    def catalog_landing():
        html=(base.ROOT/'LOR2DB/Application/landing/index.html').read_text(encoding='utf-8')
        banner='<aside style="padding:16px;background:#fff3cd;font-weight:bold">DISPOSABLE CATALOG REVIEW — copied inputs only. <a href="/review/">Simulate exporting your changed preview</a></aside>'
        return Response(html.replace('<body>','<body>'+banner,1),mimetype='text/html')
    base.static.view_functions['landing']=catalog_landing

    @base.static.get('/review/')
    def copied_export_form():
        return '''<!doctype html><title>Disposable export simulation</title>
        <h1>DISPOSABLE COPY ONLY</h1><p>First review the unchanged catalog on the LOR2DB page.
        Then upload your changed local .lorprev below to simulate exporting into the master folder.
        This replaces only the disposable copy. G: and Production are never written.</p>
        <input id="file" type="file" accept=".lorprev"><button id="upload">Copy export into disposable master</button>
        <pre id="status"></pre><a href="/lor2db/">Return to catalog review</a>
        <script>document.getElementById('upload').onclick=async()=>{const f=document.getElementById('file').files[0];if(!f)return;
        try{const r=await fetch('/review/export',{method:'POST',headers:{'Content-Type':'application/xml'},body:await f.text()});
        document.getElementById('status').textContent=await r.text();}catch(e){document.getElementById('status').textContent=e.message}};</script>'''

    @base.static.post('/review/export')
    def copied_export():
        raw=request.get_data(cache=False)
        if not raw or len(raw)>16*1024*1024 or b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
            return 'Invalid review export',400
        try: root=ET.fromstring(raw)
        except ET.ParseError: return 'Invalid XML',400
        match=[p for p in doc['previews'] if p['preview_id']==root.get('id')]
        if root.tag!='PreviewClass' or len(match)!=1:
            return 'Export must have exactly one existing controlled PreviewID',400
        # Do not simulate editing before registering known accepted source.
        if not (evidence/doc['evidence_id']/'baseline.json').is_file():
            return 'Review the unchanged catalog once before simulating the new export.',409
        if not runner.operation_lock.acquire(blocking=False):
            return 'A catalog operation is already running',409
        try: (folder/match[0]['filename']).write_bytes(raw)
        finally: runner.operation_lock.release()
        return 'Copied export changed the DISPOSABLE master only. Return to LOR2DB and review/publish the catalog.'

    def application(environ,start_response):
        method,path=environ.get('REQUEST_METHOD'),environ.get('PATH_INFO','')
        allowed_post=path in {'/lor2db/preflight/api/catalog/review','/lor2db/preflight/api/catalog/publish','/review/export'}
        if (environ.get('REMOTE_ADDR')!='127.0.0.1' or method not in {'GET','HEAD','POST'}
                or (method=='POST' and (not allowed_post or environ.get('HTTP_ORIGIN')!='http://127.0.0.1:8898'))):
            return Response('Disposable catalog review forbids this operation',403)(environ,start_response)
        if int(environ.get('CONTENT_LENGTH') or 0)>16*1024*1024:
            return Response('Review request too large',413)(environ,start_response)
        environ['HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL']=base.EMAIL
        def headers(status,values,exc_info=None):
            values += [('Cache-Control','no-store'),('X-MSB-Review','DISPOSABLE-COPIES-ONLY')]
            return start_response(status,values,exc_info)
        return base.routes(environ,headers)
    return application,service


if __name__=='__main__':
    from werkzeug.serving import run_simple
    app,service=configure(os.environ['LOR2PC_COPIED_MASTER_ZIP'],os.environ['LOR2PC_CATALOG_WORKSPACE'])
    try: run_simple('127.0.0.1',base.PORT,app,use_reloader=False)
    finally: service.shutdown();service.server_close()
