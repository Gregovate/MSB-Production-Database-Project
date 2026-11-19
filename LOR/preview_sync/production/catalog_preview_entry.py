"""Disposable catalog browser review using copied master bytes; NEVER deploy.

Production DB access is performed by the parent clone launcher only for pg_dump.
This process uses clone SELECTs and isolated local evidence/export files only.
"""
import json
import hashlib
import html
import os
from pathlib import Path, PureWindowsPath
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
    proposed_raw=None; source_info=None
    with zipfile.ZipFile(archive) as source:
        if len(source.infolist())>502 or sum(i.file_size for i in source.infolist())>512*1024*1024:
            raise RuntimeError('Copied master archive exceeds review bounds')
        seen=set()
        for entry in source.infolist():
            name=entry.filename
            if name=='__review_input/proposed.lorprev':
                if proposed_raw is not None or entry.file_size>16*1024*1024: raise RuntimeError('Invalid proposed export entry')
                proposed_raw=source.read(entry);continue
            if name=='__review_input/source.json':
                if source_info is not None or entry.file_size>65536: raise RuntimeError('Invalid source metadata entry')
                source_info=json.loads(source.read(entry));continue
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
    if (proposed_raw is None)!=(source_info is None):
        raise RuntimeError('Proposed export and source metadata must both be present')
    if proposed_raw is not None:
        if not isinstance(source_info,dict) or source_info.get('sha256')!=hashlib.sha256(proposed_raw).hexdigest():
            raise RuntimeError('Selected export bytes do not match launcher evidence')
        (workspace/'selected-export.lorprev').write_bytes(proposed_raw)
        (workspace/'selected-source.json').write_text(json.dumps(source_info,indent=2),encoding='utf-8')
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
        banner='<aside style="padding:16px;background:#fff3cd;font-weight:bold">DISPOSABLE CATALOG REVIEW r3 — copied inputs only. <a href="/review/">Simulate exporting your changed preview</a></aside>'
        return Response(html.replace('<body>','<body>'+banner,1),mimetype='text/html')
    base.static.view_functions['landing']=catalog_landing

    def page(title,body,status=200):
        return Response('<!doctype html><meta charset="utf-8"><title>'+html.escape(title)+
            '</title><link rel="stylesheet" href="/lor2db/lor2db.css"><style>.review-copy-approval{display:flex;gap:10px;align-items:flex-start}.review-copy-approval input{width:auto;flex:none;margin-top:6px}dd,code{overflow-wrap:anywhere}</style><main class="shell"><section class="card">'+
            '<p class="eyebrow">DISPOSABLE COPY ONLY · review r3</p><h1>'+html.escape(title)+'</h1>'+body+
            '<p><a href="/review/">Source / destination confirmation</a> · <a href="/lor2db/">Return to catalog review</a></p></section></main>',
            status=status,mimetype='text/html')

    def target_for(raw):
        if not raw or len(raw)>16*1024*1024 or b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
            raise ValueError('Invalid review export size or XML declarations')
        root=ET.fromstring(raw)
        match=[p for p in doc['previews'] if p['preview_id']==root.get('id')]
        if root.tag!='PreviewClass' or len(match)!=1:
            raise ValueError('Export must have one existing controlled PreviewID')
        return root,match[0]

    def confirmation(root,target):
        source_path=source_info.get('source_path','Selected export (path unavailable)') if source_info else 'Request body (diagnostic fixture)'
        reference=accepted['source_folder'].rstrip('\\')+'\\'+target['filename']
        return '<dl><dt>Source file</dt><dd><code>'+html.escape(source_path)+            '</code></dd><dt>Destination for this review</dt><dd><strong>DISPOSABLE COPY of</strong> <code>'+html.escape(reference)+            '</code></dd><dt>Preview</dt><dd>'+html.escape(root.get('Name',''))+' — Revision '+html.escape(root.get('Revision',''))+            '</dd></dl><details><summary>Exact disposable destination</summary><code>'+html.escape(str(folder/target['filename']))+            '</code></details><p>The real master folder is not written. Keep the review PowerShell window open.</p>'

    @base.static.get('/review/')
    def copied_export_form():
        if proposed_raw is None:
            return page('Select the local export in the Windows launcher','<p>No export was selected. Use the revised launcher; its native picker opens C:\\LOR\\ImportExport.</p>',409)
        try: root,target=target_for(proposed_raw)
        except (ValueError,ET.ParseError) as error: return page('Invalid selected export','<p>'+html.escape(str(error))+'</p>',400)
        return page('Confirm source and destination',confirmation(root,target)+
            '<form action="/review/export" method="post"><label class="review-copy-approval"><input type="checkbox" name="confirm_copy" value="yes" required> I confirm this source and disposable destination.</label>'+
            '<button class="primary" type="submit">Copy selected export into disposable master</button></form>')

    @base.static.post('/review/export')
    def copied_export():
        native_form=request.mimetype=='application/x-www-form-urlencoded'
        if native_form:
            if request.form.get('confirm_copy')!='yes' or proposed_raw is None:
                return page('Copy not approved','<p>Confirm the source and destination first.</p>',400)
            raw=proposed_raw
        else:
            # Diagnostic fixture path only; normal UI submits the preselected
            # copied bytes with a native form, never JavaScript fetch/upload.
            raw=request.get_data(cache=False)
        try: root,target=target_for(raw)
        except (ValueError,ET.ParseError) as error: return page('Invalid export','<p>'+html.escape(str(error))+'</p>',400)
        if not (evidence/doc['evidence_id']/'baseline.json').is_file():
            return page('Register the unchanged baseline first','<p>Return to LOR2DB and review the unchanged catalog once.</p>',409)
        if not runner.operation_lock.acquire(blocking=False):
            return page('Catalog operation busy','<p>Another catalog operation is running. Nothing copied.</p>',409)
        try:
            temporary=workspace/'export-copy.writing'
            temporary.write_bytes(raw)
            os.replace(temporary,folder/target['filename'])
            (workspace/'export-copy.json').write_text(json.dumps(dict(filename=target['filename'],sha256=hashlib.sha256(raw).hexdigest(),source=source_info),indent=2),encoding='utf-8')
        finally: runner.operation_lock.release()
        return page('Copied into disposable master',confirmation(root,target)+
            '<p><strong>Copy complete.</strong> Return to LOR2DB and click <strong>Review and Update Official Catalog</strong> again. Publication has not occurred.</p>')

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
