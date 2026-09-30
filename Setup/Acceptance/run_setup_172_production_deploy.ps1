param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

# MSB Setup #172 — one-command Production deployment wrapper.
# Run from repository root:
#   .\Setup\Acceptance\run_setup_172_production_deploy.ps1
#
# Deployment tooling is versioned separately from the frozen accepted
# application candidate. This wrapper always deploys the exact accepted SHA.

$DeploymentBranch = 'deploy/setup-172-production-wrapper'
$TargetRef = 'issue-172-setup-context-work-order-intake'
$AcceptedTargetSha = 'fc0b76d57826eebf04b81c99cbb904109162cd87'
$MigrationPath = 'Setup/Database/062_add_setup_context_work_order_intake.sql'
$AcceptedMigrationBlob = 'c8a98d653de4797c30050397f07d8b0cbd5141c5'
$ExpectedJsPin = 'setup_next_pass.js?v=2026-09-27.2'
$ExpectedCssPin = 'setup_next_pass.css?v=2026-09-27.2'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path

$origin = (& git -C $RepoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'Gregovate/MSB-Production-Database-Project') {
    throw "STOP: wrong repository. origin=$origin"
}

$branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne $DeploymentBranch) {
    throw "STOP: run from '$DeploymentBranch'. Current branch: '$branch'"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty) {
    throw "STOP: local repository is not clean. $dirty"
}

& git -C $RepoRoot cat-file -e ($AcceptedTargetSha + '^{commit}')
if ($LASTEXITCODE -ne 0) {
    throw "STOP: frozen accepted target is unavailable locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "STOP: deployment-tooling branch is not based on frozen target $AcceptedTargetSha"
}

$actualBlob = (& git -C $RepoRoot rev-parse ($AcceptedTargetSha + ':' + $MigrationPath)).Trim()
if ($LASTEXITCODE -ne 0 -or $actualBlob -ne $AcceptedMigrationBlob) {
    throw "STOP: migration identity mismatch. Expected $AcceptedMigrationBlob, got '$actualBlob'."
}

$html = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/production.html')) | Out-String)
if ($LASTEXITCODE -ne 0 -or -not $html.Contains($ExpectedJsPin) -or -not $html.Contains($ExpectedCssPin)) {
    throw 'STOP: frozen target does not contain browser-accepted #172 asset pins.'
}

$ToolingCommit = (& git -C $RepoRoot rev-parse HEAD).Trim()

$ServerScript = @'
#!/usr/bin/env bash
set -Eeuo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"

TARGET_REF="__TARGET_REF__"
TARGET_SHA="__TARGET_SHA__"
MIGRATION_REL="__MIGRATION_PATH__"
MIGRATION_BLOB="__MIGRATION_BLOB__"
EXPECTED_JS_PIN="__EXPECTED_JS_PIN__"
EXPECTED_CSS_PIN="__EXPECTED_CSS_PIN__"
TOOLING_COMMIT="__TOOLING_COMMIT__"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="/home/msbadmin/backups/setup-172"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-172-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_172_Report_Correction_Production_Deploy_$STAMP.txt"
CANDIDATE="/tmp/msb-setup-172-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-172-detached-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-172-live-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-172-negative-$STAMP.txt"

OLD_HEAD=""
INITIAL_FP=""
FROZEN_FP=""
INITIAL_INTAKE_COUNT=""
BACKUP_CREATED=0
DB_MIGRATED=0
APP_ADVANCED=0
SUCCESS=0

mkdir -p "$BACKUP_DIR" "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_fp() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
SELECT md5(
    coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id) FROM ops.setup_work_day wd), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_task_id) FROM ops.setup_work_day_task wdt), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id) FROM ops.setup_task_progress p), '')
);
"
}

intake_count() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT count(*) FROM stage.work_order_intake;"
}

wait_setup() {
    for _ in $(seq 1 60); do
        if systemctl is-active --quiet "$SETUP_SERVICE" \
           && curl -fsS http://192.168.5.9:8794/api/health >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

rollback_062() {
    local now_count
    now_count="$(intake_count 2>/dev/null || true)"
    if [[ -z "$now_count" || "$now_count" != "$INITIAL_INTAKE_COUNT" ]]; then
        echo "REFUSE automatic migration rollback: Work Order Intake count changed."
        return 1
    fi

    psql_prod <<'SQL'
BEGIN;
REVOKE ALL ON FUNCTION ops.prepare_setup_work_order_intake(
    text,bigint,bigint,text,text,jsonb
) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.prepare_setup_work_order_intake(
    text,bigint,bigint,text,text,jsonb
) FROM fieldwiring_app;
DROP FUNCTION IF EXISTS ops.prepare_setup_work_order_intake(
    text,bigint,bigint,text,text,jsonb
);
COMMIT;
SQL
}

cleanup() {
    rc=$?
    trap - EXIT HUP INT TERM
    set +e
    rollback_failed=0

    if [[ "$rc" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED #172 RECOVERY ---"

        if [[ "$DB_MIGRATED" -eq 1 || "$APP_ADVANCED" -eq 1 ]]; then
            sudo systemctl stop "$SETUP_SERVICE" >/dev/null 2>&1 || true
        fi

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to $OLD_HEAD"
            if sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD"; then
                APP_ADVANCED=0
                echo "Application rollback: PASS"
            else
                rollback_failed=1
                echo "Application rollback: FAILED"
            fi
        fi

        if [[ "$DB_MIGRATED" -eq 1 ]]; then
            echo "Attempting bounded migration 062 rollback"
            if rollback_062; then
                DB_MIGRATED=0
                echo "Migration 062 rollback: PASS"
            else
                rollback_failed=1
                echo "Migration 062 rollback: REFUSED/FAILED"
            fi
        fi

        if [[ "$rollback_failed" -eq 0 ]]; then
            sudo systemctl restart "$SETUP_SERVICE" || true
            wait_setup || true
        else
            echo "WARNING: rollback requires review; Setup remains stopped."
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -Fq "worktree $CANDIDATE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$FROZEN_FP" ]]; then
        FINAL_FP="$(setup_fp 2>/dev/null || true)"
        echo "Frozen Setup fingerprint: $FROZEN_FP"
        echo "Final Setup fingerprint:  $FINAL_FP"
        if [[ -z "$FINAL_FP" || "$FINAL_FP" != "$FROZEN_FP" ]]; then
            echo "FAIL: governed Setup business fingerprint changed"
            rc=97
        fi
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback archive retained at: $BACKUP_FILE"
        echo "Rollback SHA256: $BACKUP_SHA"
    else
        echo "Rollback archive: not created before this stop"
    fi
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $rc"
    exit "$rc"
}
trap cleanup EXIT HUP INT TERM

sudo -v

echo "========== SETUP #172 REPORT CORRECTION PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Deployment tooling commit: $TOOLING_COMMIT"
echo "Frozen accepted SHA:       $TARGET_SHA"
echo "Migration:                 $MIGRATION_REL"
echo "Report:                    $REPORT"
echo

[[ "$(hostname)" == "msb-prod-db" ]] || { echo "FAIL: wrong host"; exit 2; }

sudo docker inspect "$PROD_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "postgis/postgis:16-3.5" ]] \
    || { echo "FAIL: unexpected PostgreSQL image"; exit 3; }

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Live Setup SHA: $OLD_HEAD"
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]] \
    || { echo "FAIL: live Setup worktree is dirty"; exit 4; }

systemctl is-active --quiet "$SETUP_SERVICE" \
    || { echo "FAIL: Setup service is not active"; exit 5; }

PRE_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy health: $PRE_HEALTH"
[[ "$PRE_HEALTH" == *'"status":"ok"'* && "$PRE_HEALTH" == *'"data_mode":"postgres"'* ]] \
    || { echo "FAIL: abnormal Setup health"; exit 6; }

echo
echo "--- Verify Setup -> Directus authentication ---"
SETUP_PID="$(systemctl show -p MainPID --value "$SETUP_SERVICE")"
sudo python3 - "$SETUP_PID" <<'PY'
from pathlib import Path
from urllib.request import Request, ProxyHandler, build_opener
import sys

env = {}
for item in Path(f"/proc/{sys.argv[1]}/environ").read_bytes().split(b"\0"):
    if b"=" in item:
        key, value = item.split(b"=", 1)
        env[key.decode()] = value.decode()
token = env.get("SETUP_DIRECTUS_INTAKE_TOKEN", "")
if not token:
    raise SystemExit("STOP: running Setup has no Directus Intake token")
req = Request(
    "http://127.0.0.1:8055/users/me?fields=id",
    headers={"Authorization": f"Bearer {token}"},
)
with build_opener(ProxyHandler({})).open(req, timeout=10) as response:
    if response.status != 200:
        raise SystemExit(f"STOP: Directus authentication HTTP {response.status}")
    response.read()
print("RUNNING SETUP -> DIRECTUS AUTHENTICATION: PASS")
PY

echo
echo "--- Verify existing Directus items.create notification boundary ---"
psql_prod <<'SQL'
DO $flow$
DECLARE
    v_flow integer;
    v_mail integer;
BEGIN
    SELECT count(*) INTO v_flow
    FROM public.directus_flows f
    WHERE f.name='WOI Request Triage Email'
      AND f.status='active'
      AND f.trigger='event'
      AND coalesce(f.options::text,'') ILIKE '%items.create%'
      AND coalesce(f.options::text,'') ILIKE '%work_order_intake%';

    IF v_flow <> 1 THEN
        RAISE EXCEPTION 'WOI Request Triage Email items.create Flow not exactly active';
    END IF;

    SELECT count(*) INTO v_mail
    FROM public.directus_operations o
    JOIN public.directus_flows f ON f.id=o.flow
    WHERE f.name='WOI Request Triage Email'
      AND o.type='mail';

    IF v_mail < 1 THEN
        RAISE EXCEPTION 'WOI Request Triage Email has no mail operation';
    END IF;
END
$flow$;
SQL
echo "DIRECTUS NOTIFICATION BOUNDARY: PASS"

INITIAL_FP="$(setup_fp)"
INITIAL_INTAKE_COUNT="$(intake_count)"
[[ -n "$INITIAL_FP" && -n "$INITIAL_INTAKE_COUNT" ]] \
    || { echo "FAIL: initial invariants unavailable"; exit 7; }
echo "Initial Setup fingerprint:  $INITIAL_FP"
echo "Initial Intake row count:    $INITIAL_INTAKE_COUNT"

echo
echo "--- Fetch and verify frozen accepted target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA" \
    || { echo "FAIL: target is not a forward descendant of live Setup"; exit 8; }
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF" \
    || { echo "FAIL: frozen target is not contained in remote feature branch"; exit 9; }

ACTUAL_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
[[ "$ACTUAL_BLOB" == "$MIGRATION_BLOB" ]] \
    || { echo "FAIL: migration 062 blob mismatch"; exit 10; }
echo "Target ancestry/blob: PASS"

echo
echo "--- Detached exact-target Production-runtime regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE" "$TARGET_SHA"
M062="$CANDIDATE/$MIGRATION_REL"
test -s "$M062"
grep -Fq "$EXPECTED_JS_PIN" "$CANDIDATE/Setup/Application/production.html"
grep -Fq "$EXPECTED_CSS_PIN" "$CANDIDATE/Setup/Application/production.html"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" \
    bash -c "cd '$CANDIDATE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED EXACT #172 REGRESSION: PASS"

echo
echo "--- Freeze Setup writes ---"
sudo systemctl stop "$SETUP_SERVICE"
! systemctl is-active --quiet "$SETUP_SERVICE" \
    || { echo "FAIL: Setup service did not stop"; exit 11; }

FROZEN_FP="$(setup_fp)"
[[ "$FROZEN_FP" == "$INITIAL_FP" ]] \
    || { echo "FAIL: Setup business data changed before mutation"; exit 12; }
[[ "$(intake_count)" == "$INITIAL_INTAKE_COUNT" ]] \
    || { echo "FAIL: Intake changed before mutation"; exit 13; }
echo "WRITE-FREEZE STABILITY: PASS"

echo
echo "--- Create and validate PostgreSQL rollback archive ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "Rollback SHA256:  $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Migration 062 Production preflight ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regprocedure(
        'ops.prepare_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 062 function already exists';
    END IF;

    IF to_regprocedure('ref.setup_execution_actor(text,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Migration 061 execution actor authority missing';
    END IF;

    IF to_regclass('stage.work_order_intake') IS NULL THEN
        RAISE EXCEPTION 'stage.work_order_intake missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='stage'
          AND table_name='work_order_intake'
          AND column_name='source_payload'
          AND data_type='jsonb'
    ) THEN
        RAISE EXCEPTION 'Work Order Intake source_payload contract missing';
    END IF;
END
$preflight$;
SQL
echo "MIGRATION 062 PREFLIGHT: PASS"

echo
echo "--- Apply migration 062 only ---"
psql_prod < "$M062"
DB_MIGRATED=1
echo "MIGRATION 062: COMMITTED"

echo
echo "--- Validate #172 least privilege ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regprocedure(
        'ops.prepare_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Migration 062 prepare function missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.prepare_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks #172 EXECUTE';
    END IF;

    IF has_table_privilege(
        'fieldwiring_app',
        'stage.work_order_intake',
        'INSERT'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has direct Intake INSERT';
    END IF;
END
$validate$;
SQL

[[ "$(setup_fp)" == "$FROZEN_FP" ]] \
    || { echo "FAIL: migration 062 changed governed Setup business data"; exit 14; }
[[ "$(intake_count)" == "$INITIAL_INTAKE_COUNT" ]] \
    || { echo "FAIL: migration 062 changed Intake rows"; exit 15; }
echo "MIGRATION 062 CONTRACT/DATA PRESERVATION: PASS"

echo
echo "--- Advance /opt/msb-setup to frozen accepted target ---"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1
[[ "$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)" == "$TARGET_SHA" ]]
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]
echo "EXACT SETUP TARGET INSTALLED: PASS"

echo
echo "--- Restart and verify Setup ---"
sudo systemctl restart "$SETUP_SERVICE"
wait_setup || { echo "FAIL: Setup did not return healthy"; exit 16; }

POST_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy health: $POST_HEALTH"

ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
[[ "$ROOT_HTML" == *"$EXPECTED_JS_PIN"* && "$ROOT_HTML" == *"$EXPECTED_CSS_PIN"* ]] \
    || { echo "FAIL: accepted #172 asset pins are not live"; exit 17; }

NEXT_JS="$(curl -fsS http://192.168.5.9:8794/setup_next_pass.js)"
[[ "$NEXT_JS" == *"Report Correction"* && "$NEXT_JS" == *"Submitted to Work Order Intake"* ]] \
    || { echo "FAIL: accepted #172 behavior is not live"; exit 18; }
echo "LIVE #172 ASSETS: PASS"

echo
echo "--- Protected Report Correction negative path ---"
NEGATIVE_CODE="$(
    curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' \
      -X POST \
      -H 'Content-Type: application/json' \
      -H 'X-MSB-Setup-Command: 1' \
      -d '{"problem":"negative path","setup_work_day_task_id":1}' \
      http://192.168.5.9:8794/api/setup/session-tasks/1/correction-intake
)"
echo "Unauthenticated status: $NEGATIVE_CODE"
[[ "$NEGATIVE_CODE" == "401" ]] \
    || { echo "FAIL: Report Correction endpoint did not fail closed"; exit 19; }
echo "PROTECTED NEGATIVE PATH: PASS"

echo
echo "--- Full live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" \
    bash -c "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE #172 SETUP REGRESSION: PASS"

FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_FP="$(setup_fp)"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ "$FINAL_FP" == "$FROZEN_FP" ]]
[[ "$FINAL_HEALTH" == *'"status":"ok"'* ]]

SUCCESS=1
echo
echo "SETUP_172_REPORT_CORRECTION_PRODUCTION_DEPLOYMENT_PASS"
echo "Final SHA:         $FINAL_HEAD"
echo "Rollback archive:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "Deployment report: $REPORT"
'@

$ServerScript = $ServerScript.Replace('__TARGET_REF__', $TargetRef)
$ServerScript = $ServerScript.Replace('__TARGET_SHA__', $AcceptedTargetSha)
$ServerScript = $ServerScript.Replace('__MIGRATION_PATH__', $MigrationPath)
$ServerScript = $ServerScript.Replace('__MIGRATION_BLOB__', $AcceptedMigrationBlob)
$ServerScript = $ServerScript.Replace('__EXPECTED_JS_PIN__', $ExpectedJsPin)
$ServerScript = $ServerScript.Replace('__EXPECTED_CSS_PIN__', $ExpectedCssPin)
$ServerScript = $ServerScript.Replace('__TOOLING_COMMIT__', $ToolingCommit)

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-172-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$cr = [string][char]13
$lf = [string][char]10

Write-Host '========== SETUP #172 REPORT CORRECTION PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                    $Server"
Write-Host "Deployment tooling commit: $ToolingCommit"
Write-Host "Frozen accepted SHA:       $AcceptedTargetSha"
Write-Host "Migration:                 $MigrationPath"
Write-Host "Migration Git blob:        $AcceptedMigrationBlob"
Write-Host "Remote bundle:             $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Directus secret is read only from the already-running Production Setup service.'
Write-Host
Write-Host 'IMPORTANT: keep Setup editing paused while this bounded deployment runs.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = $ServerScript.Replace($cr + $lf, $lf).Replace($cr, $lf)
    $localServer = Join-Path $localBundle 'setup_172_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains($cr)) {
        throw 'STOP: generated Linux deployment runner contains CR characters.'
    }

    & scp -r $localBundle ($Server + ':/tmp/')
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_172_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded #172 Production deployment...'
    Write-Host

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #172 Production deployment stopped with exit code $remoteExit. Review the retained server deployment report before further mutation."
    }

    Write-Host
    Write-Host 'SETUP #172 REPORT CORRECTION PRODUCTION DEPLOYMENT WRAPPER: PASS'
    Write-Host 'Next: submit one real protected-route Report Correction and confirm Intake + manager email.'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
