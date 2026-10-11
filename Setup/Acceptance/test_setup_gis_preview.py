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
from production_backend import app
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
assert 'V0.3.62-field-networks' in page.text
for url in ['/fieldwiring/fieldwiring.css','/fieldwiring/fieldwiring.js',
            '/setup/locate/assets/setup_locate_networks.json',
            '/setup/locate/assets/setup_locate_assets.js','/locate/']:
    assert client.get(url).status_code == 200, url
assert client.get('/fieldwiring/api/health').json['version'] == 'V0.4.1-gis-entry'
assert client.get('/setup/api/health').json['version'] == 'V0.3.62-field-networks'
assert client.post('/setup/locate/').status_code == 405
'''
    subprocess.run([sys.executable, '-c', program], cwd=ROOT, check=True, capture_output=True, text=True)
