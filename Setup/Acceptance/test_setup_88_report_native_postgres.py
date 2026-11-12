"""Optional engineering proof of psql meta commands and ACL preservation SQL.

pgserver supplies isolated native PostgreSQL; absent on Production/workstations,
this engineering check skips. The actual current-clone gate still runs on host.
"""
import re
import os
from pathlib import Path
import subprocess
import sys
import pytest


@pytest.mark.skipif(sys.platform != 'linux' or os.geteuid() == 0,
                   reason='Optional native PostgreSQL check runs as a non-root engineering user')
def test_report_grant_psql_validation_and_acl_preservation(tmp_path):
    pgserver=pytest.importorskip('pgserver',reason='Optional native PostgreSQL engineering tool')
    from pgserver import postgres_server
    import setup_88_report_read_deploy as deploy
    server=pgserver.get_server(tmp_path/'pgdata',cleanup_mode='delete')
    uri=server.get_uri()
    psql=Path(postgres_server.__file__).parent/'pginstall/bin/psql'
    def sql(text,ok=True):
        result=subprocess.run([str(psql),uri,'-X','-qAt','-v','ON_ERROR_STOP=1'],
                              input=text,text=True,capture_output=True,timeout=30)
        if ok: assert result.returncode==0,result.stderr
        else: assert result.returncode!=0 and 'permission denied' in result.stderr
        return result.stdout.strip()
    try:
        fixture=Path(__file__).with_name('test_setup_88_report_read_privilege.mjs').read_text()
        parts=re.findall(r'await db.exec\(`([\s\S]*?)`\);',fixture)
        assert len(parts)==2
        sql(parts[0])
        sql("ALTER TABLE ref.container ADD COLUMN location_code text; ALTER TABLE ref.stage ADD COLUMN stage_key text; ALTER TABLE ops.setup_movement_event ADD COLUMN gps_quality text; ALTER TABLE ops.setup_movement_event ADD COLUMN gps_fix_age_ms int;")
        sql(parts[1])
        # Exercise the real runner's SQL methods against a real psql connection.
        instance=deploy.ReadDeploy.__new__(deploy.ReadDeploy)
        instance.sql=sql
        instance.git=lambda *args: Path(__file__).parents[1].joinpath('Application/setup_production_report.py').read_text() if args[1].endswith('setup_production_report.py') else Path(__file__).with_name('setup_88_report_read_validation.sql').read_text()
        instance.missing_read()
        before=instance.capture(); acl_before=instance.acl_preservation()
        sql('SET ROLE fieldwiring_app; SELECT container_type_name FROM ref.container_type;',ok=False)
        migration=Path(__file__).parents[1].joinpath('Database/071_grant_setup_container_type_report_read.sql').read_text()
        sql(migration)
        instance.validate()
        assert instance.capture()==before
        assert instance.acl_preservation()==acl_before
        sql('SET ROLE fieldwiring_app; SELECT private_notes FROM ref.container_type;',ok=False)
        sql("SET ROLE fieldwiring_app; UPDATE ref.container_type SET container_type_name='wrong';",ok=False)
        exporter=Path(__file__).with_name('setup_production_read_boundary.sql').read_text()
        reads=sql(exporter)
        assert 'GRANT SELECT (container_type_id,container_type_name) ON TABLE ref.container_type' in reads
        assert 'GRANT SELECT ON TABLE ref.container_type' not in reads
    finally:
        server.cleanup()
