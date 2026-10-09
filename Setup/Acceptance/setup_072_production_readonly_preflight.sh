#!/usr/bin/env bash
# Migration 072: READ-ONLY Production preflight, run as msbadmin on msb-prod-db.
# Does not enter maintenance, write SQL, restart services, or change Git.
# Authority: MSB-Server-Management Production_Database_Change_Deployment_Runbook.md
set -euo pipefail
CONTROL=/opt/msb-maintenance/msb_maintenance_controller.py
CONFIG=/etc/msb-maintenance/config.json
echo '=== MIGRATION 072 READ-ONLY PRODUCTION PREFLIGHT ==='
sudo python3 "$CONTROL" --config "$CONFIG" status
echo '=== Live application identity ==='
sudo git -C /opt/msb-setup rev-parse HEAD
sudo git -C /opt/msb-setup status --porcelain
sudo git -C /opt/fieldwiring rev-parse HEAD
sudo git -C /opt/fieldwiring status --porcelain
echo '=== Live application health ==='
curl -fsS --max-time 10 http://192.168.5.9:8794/api/health
echo
echo '=== Existing migration objects and audit counts ==='
sudo docker exec -i msb-postgres psql -X -v ON_ERROR_STOP=1 -U msbadmin -d msb <<'SQL'
SELECT to_regclass('ops.preview_setup_schedule_churn_v1') AS churn_view,
       to_regprocedure('ops.audit_setup_assignment_lifecycle()') AS lifecycle_function;
SELECT event_type, count(*) AS events,
       count(*) FILTER (WHERE created_by_person_id IS NULL) AS missing_actor
FROM ops.setup_schedule_event GROUP BY event_type ORDER BY event_type;
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid='ops.setup_work_day_task'::regclass
AND tgname IN ('trg_setup_assignment_lifecycle_insert',
               'trg_setup_assignment_lifecycle_delete')
ORDER BY tgname;
SQL
echo '=== READ-ONLY PREFLIGHT COMPLETE: inspect all results before maintenance ==='
