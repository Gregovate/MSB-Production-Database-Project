"""Exact-candidate, GET-only local browser review against a disposable clone.

The owning launcher proves clone identity and port availability. This entry
refuses Production database names and never configures the real Windows runner.
"""
import os
from pathlib import Path
import sys

from flask import Flask, redirect, send_from_directory
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from werkzeug.wrappers import Response
import psycopg2
from psycopg2.extensions import parse_dsn

ROOT = Path(__file__).resolve().parents[3]
DSN = os.environ.get('LOR2PC_PREVIEW_DSN', '')
EMAIL = os.environ.get('LOR2PC_PREVIEW_EMAIL', '').strip().lower()
PORT = int(os.environ.get('LOR2PC_PREVIEW_PORT', '0'))
config = parse_dsn(DSN)
if (os.environ.get('LOR2PC_PREVIEW_MODE') != 'disposable' or PORT != 8898 or '@' not in EMAIL
        or config.get('dbname') != 'lor2pc_disposable' or config.get('host') != '127.0.0.1'
        or config.get('user') != 'lor_preflight_app' or config.get('port') == '5432'):
    raise RuntimeError('Explicit isolated LOR2PC preview configuration required')
os.environ['LOR_PREFLIGHT_DATABASE_URL'] = DSN
os.environ['LOR_PREFLIGHT_OPERATORS'] = EMAIL
os.environ.pop('LOR_RUNNER_URL', None)
os.environ.pop('LOR_RUNNER_TOKEN', None)
sys.path.insert(0, str(ROOT/'LOR2DB/Application'))
import backend  # noqa: E402

static = Flask('lor2pc_disposable_static', static_folder=None)
@static.get('/')
def home(): return redirect('/lor2db/')
@static.get('/lor2db/')
def landing(): return send_from_directory(ROOT/'LOR2DB/Application/landing', 'index.html')
@static.get('/lor2db/<path:name>')
def asset(name):
    if name == 'pc/': name = 'pc/index.html'
    if name not in {'lor2db.js','lor2db.css','pc/index.html','pc/handoff.js','pc/downloads/MSB-PC-Preview-Updater-1.0.5.zip'}:
        return Response('Unavailable in disposable read-only review', 404)
    return send_from_directory(ROOT/'LOR2DB/Application/landing', name)

routes = DispatcherMiddleware(static, {'/lor2db/preflight/api':backend.app})
def application(environ, start_response):
    if (environ.get('REMOTE_ADDR') != '127.0.0.1'
            or environ.get('REQUEST_METHOD') not in {'GET','HEAD'}):
        return Response('Disposable browser review permits local GET only', 403)(environ,start_response)
    # This identity injection exists only in the loopback clone harness. Never
    # deploy this module as a Production WSGI entry or public proxy replacement.
    environ['HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL'] = EMAIL
    def headers(status, values, exc_info=None):
        values += [('Cache-Control','no-store'),('X-MSB-Review','DISPOSABLE-NO-WRITES')]
        return start_response(status,values,exc_info)
    return routes(environ,headers)

if __name__ == '__main__':
    from werkzeug.serving import run_simple
    run_simple('127.0.0.1', PORT, application, use_reloader=False)
