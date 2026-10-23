"""Read the existing PostgreSQL network table; never create or update rows."""
import json
from pathlib import Path
import subprocess
import sys

from gis_track_reconcile import read_network_catalog

SQL = """
BEGIN READ ONLY;
SELECT jsonb_build_object(
 'format_version',1,'data_mode','postgres','source_table','ref.site_network',
 'source_host','msb-prod-db','database',current_database(),
 'fetched_at',CURRENT_TIMESTAMP,
 'revision',md5(coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.network_code),'[]'::jsonb)::text),
 'networks',coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.network_code),'[]'::jsonb))
FROM ref.site_network n;
ROLLBACK;
"""


def cache_path():
    directory = Path(sys.executable).parent if getattr(sys, "frozen", False) else Path(__file__).parent
    return directory / "site_network_catalog_cache.json"


def load():
    cached = cache_path()
    bundled = Path(__file__).parent / "site_network_catalog.json"
    return read_network_catalog(cached if cached.exists() else bundled)


def refresh():
    """Reuse the verified workstation SSH identity; no password prompts or writes."""
    result = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8",
         "msbadmin@192.168.5.9",
         "docker exec -i msb-postgres psql -X -qAt -v ON_ERROR_STOP=1 -U msbadmin -d msb"],
        input=SQL, text=True, capture_output=True, timeout=20,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), check=False)
    if result.returncode:
        raise ValueError("Could not refresh PostgreSQL networks through the existing server connection. "
                         "The last verified table remains available.")
    data = json.loads(result.stdout)
    destination = cache_path()
    temporary = destination.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2), encoding="utf8")
    catalog = read_network_catalog(temporary)
    if not catalog["networks"]:
        raise ValueError("PostgreSQL returned an empty network table; saved table retained.")
    temporary.replace(destination)
    return catalog
