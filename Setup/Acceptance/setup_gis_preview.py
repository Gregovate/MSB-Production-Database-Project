"""Review Field Wiring -> GIS navigation on the existing isolated Setup listener."""
from importlib.util import module_from_spec, spec_from_file_location
import os
from pathlib import Path
import sys

from werkzeug.middleware.dispatcher import DispatcherMiddleware


def mount_fieldwiring_preview(setup_wsgi, repo_root):
    """Mount actual candidate applications; require the launcher's shared clone DSN.

    This helper is acceptance-only. Production retains its separate services and
    reverse-proxy mounts; no second map or fixture landing page is introduced.
    """
    setup_dsn = os.environ.get('SETUP_DATABASE_DSN', '')
    if not setup_dsn or os.environ.get('FIELDWIRING_DATABASE_DSN') != setup_dsn:
        raise RuntimeError('GIS preview requires the same disposable DSN for both apps')
    field_dir = Path(repo_root) / 'FieldWiring' / 'Application'
    # Setup already owns the name "backend". Load the Field Wiring entry point
    # under a distinct module name without replacing the Setup module.
    sys.path.insert(0, str(field_dir))
    spec = spec_from_file_location('gis_preview_fieldwiring_backend', field_dir / 'backend.py')
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return DispatcherMiddleware(setup_wsgi, {
        '/setup': setup_wsgi,
        '/fieldwiring': module.app,
    })
