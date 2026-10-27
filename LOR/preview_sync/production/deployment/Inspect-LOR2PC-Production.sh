#!/usr/bin/env bash
# Read-only reconnaissance. No source copy, restart, grants or reconciliation.
set -euo pipefail
printf '%s\n' 'LOR2PC READ-ONLY PRODUCTION PREFLIGHT'
systemctl is-active lor-preflight-api.service
systemctl show lor-preflight-api.service -p User -p Group -p WorkingDirectory
curl --fail --silent --show-error --max-time 10 http://192.168.5.9:8784/health
printf '\n'
for file in /opt/lor-preflight/backend.py /opt/lor-preflight/publish_lor_reconciliation_report.py; do
    sudo -u lor-preflight sha256sum "$file"
done
# The accepted runtime uses this mount for NAS static files, not a new route.
findmnt --target /mnt/msb-web -no TARGET,FSTYPE
sudo docker exec -i msb-postgres psql -X -U postgres -d msb -v ON_ERROR_STOP=1 <<'SQL'
BEGIN READ ONLY;
SELECT current_database(),
       has_function_privilege('lor_preflight_app',
           'ref.setup_browser_capabilities(text)', 'EXECUTE') AS crew_resolver_execute,
       has_table_privilege('lor_preflight_app',
           'ops.lor_reconciliation_source_run', 'SELECT') AS frozen_source_select,
       has_table_privilege('lor_preflight_app',
           'ops.lor_reconciliation_source_preview', 'SELECT') AS frozen_preview_select;
SELECT r.lor_reconciliation_run_id, r.import_run_id, r.status,
       r.validation_state, r.completed_at, r.report_published_at,
       sr.source_lor_version, sr.source_preview_folder, sr.preview_count,
       sr.parser_validation_status,
       sr.source_manifest_sha256, sr.source_sqlite_sha256, r.report_sha256
FROM (SELECT * FROM ops.lor_reconciliation_run WHERE status='COMPLETED'
      ORDER BY completed_at DESC, lor_reconciliation_run_id DESC LIMIT 1) r
LEFT JOIN ops.lor_reconciliation_source_run sr USING (lor_reconciliation_run_id);
COMMIT;
SQL
printf '%s\n' 'READ-ONLY PREFLIGHT COMPLETE. Cloudflare path policy still requires separate review.'
