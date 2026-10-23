"""Check real cross-app navigation and clone-only preview configuration."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def test_actual_fieldwiring_landing_and_gis_share_preview_routes():
    # Isolate the two applications' legacy absolute imports from pytest modules.
    program = r'''
import os, sys
from pathlib import Path
from werkzeug.test import Client
from werkzeug.wrappers import Response
root = Path.cwd()
sys.path.insert(0, str(root / 'Setup' / 'Application'))
sys.path.insert(0, str(root / 'Setup' / 'Acceptance'))
from production_backend import app, PRODUCTION_VERSION
from setup_gis_preview import mount_fieldwiring_preview
original = app.wsgi_app
os.environ['SETUP_DATABASE_DSN'] = 'disposable-clone-test'
os.environ['FIELDWIRING_DATABASE_DSN'] = 'different-target'
try:
    mount_fieldwiring_preview(original, root)
except RuntimeError:
    pass
else:
    raise AssertionError('Mismatched database targets must fail closed')
os.environ['FIELDWIRING_DATABASE_DSN'] = 'disposable-clone-test'
client = Client(mount_fieldwiring_preview(original, root), Response)
landing = client.get('/fieldwiring/')
assert landing.status_code == 200
assert 'no-store' in landing.headers['Cache-Control']
assert 'href="/setup/locate/?view=fieldwiring"' in landing.text
assert 'id="display-search"' in landing.text
assert 'id="stage-select"' in landing.text
assert 'href="controllers"' in landing.text
page = client.get('/setup/locate/')
assert page.status_code == 200
assert 'MSB Park Map v1' in page.text
assert 'href="/fieldwiring/"' in page.text
assert 'V0.3.63-site-reference' in page.text
for url in ['/fieldwiring/fieldwiring.css','/fieldwiring/fieldwiring.js',
            '/setup/locate/assets/setup_locate_networks.json',
            '/setup/locate/assets/setup_locate_assets.js','/locate/']:
    assert client.get(url).status_code == 200, url
field_health = client.get('/fieldwiring/api/health')
assert field_health.status_code == 200, (field_health.status_code, field_health.text)
# Compare mounted runtime with the exact checked-out FieldWiring release,
# including when main integrates a newer FieldWiring version.
import ast
field_source = ast.parse((root / 'FieldWiring' / 'Application' / 'backend.py').read_text(encoding='utf-8'))
field_version = next(
    statement.value.value
    for statement in field_source.body
    if isinstance(statement, ast.Assign)
    and any(isinstance(target, ast.Name) and target.id == 'APP_VERSION' for target in statement.targets)
    and isinstance(statement.value, ast.Constant)
)
assert field_health.json['version'] == field_version, (field_health.json, field_version)
assert client.get('/setup/api/health').json['version'] == PRODUCTION_VERSION
# Exercise real mounted static routing; the independent Node fixture cannot catch
# Flask root_path errors caused by loading the second host under an alias.
for asset in ['power_capture.js','power_capture.css']:
    response=client.get('/fieldwiring/static/'+asset)
    assert response.status_code==200, (asset,response.status_code)
# Setup already owns sys.modules['backend']; power must use its own host factory.
from unittest.mock import MagicMock
import power_capture
conn=MagicMock()
conn.cursor.return_value.__enter__.return_value.fetchone.return_value=({'revision':0},)
def connect(dsn):
    assert dsn=='disposable-clone-test'
    return conn
power_capture.psycopg2.connect=connect
response=client.get('/fieldwiring/api/power',headers={'Cf-Access-Authenticated-User-Email':'fixture@example.invalid'})
assert response.status_code==200, (response.status_code,response.text)
assert response.json['revision']==0
conn.cursor.return_value.__enter__.return_value.fetchone.return_value=({'revision':1,'target_id':1},)
response=client.post('/fieldwiring/api/power/commands',headers={
 'Cf-Access-Authenticated-User-Email':'fixture@example.invalid','X-MSB-Power-Command':'1'},
 json={'revision':0,'commands':[{'request_id':'00000000-0000-0000-0000-000000000001','kind':'panel','id':None,'fields':{}}]})
assert response.status_code==200, (response.status_code,response.text)
conn.commit.assert_called_once()
assert client.post('/setup/locate/').status_code == 405
required='87b195845a0334769334be9e22d056c3061feaa5f5a2d9dae127db975ce8bc24'
os.environ['MSB_GIS_REQUIRED_SOURCE_SHA']=required
strict_map=client.get('/setup/locate/')
assert strict_map.status_code==200
assert 'window.MSBRequiredGpxSha="'+required+'"' in strict_map.text
assert 'const data={"type":"FeatureCollection","features":[]};' in strict_map.text
assert 'GPX candidate SHA 3272269d493131f0' not in strict_map.text
os.environ.pop('MSB_GIS_REQUIRED_SOURCE_SHA')
'''
    result = subprocess.run([sys.executable, '-c', program], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, f'GIS preview subprocess failed:\nstdout={result.stdout}\nstderr={result.stderr}'
