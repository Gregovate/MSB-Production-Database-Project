#!/usr/bin/env bash
# WO419-BR01 | Profile-specific current-clone browser runner
# Consumes MSB-Server-Management: Pre_Production_Browser_Review_Runbook.md
# SOURCE ONLY until Server Management approves #419 port profile and launcher.
set -Eeuo pipefail
umask 077

if [[ $# -ne 4 ]]; then
  echo "HOLD: candidate SHA, explicit registered port, reviewer email and approved ref required"
  exit 2
fi
CANDIDATE_SHA="$1"
PREVIEW_PORT="$2"
PREVIEW_EMAIL="$3"
CANDIDATE_REF="$4"

if [[ ! "$CANDIDATE_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "HOLD: exact 40-hex candidate SHA required"; exit 2
fi
if [[ "$PREVIEW_PORT" != "8898" ]]; then
  echo "HOLD: #419 proposed sequential port 8898; do not invent another port"; exit 2
fi
if [[ ! "$PREVIEW_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@sheboyganlights[.]org$ ]]; then
  echo "HOLD: approved MSB human reviewer email required"; exit 2
fi
if [[ "$CANDIDATE_REF" != "issue-419-unified-ticket-read-model-20261018" ]]; then
  echo "HOLD: #419 source branch changed; review target ancestry first"; exit 2
fi

REPO_ROOT="/opt/fieldwiring"
PRODUCTION_DB="msb"
PRODUCTION_CONTAINER="msb-postgres"
PG_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
PYTHON="/opt/fieldwiring/.venv/bin/python"
STAMP="$(date +%Y%m%dT%H%M%S)"
CLONE_CONTAINER="msb-wo419-preview-$$"
CLONE_DATABASE="msb_wo419_preview"
CLONE_DB_PASSWORD="$(openssl rand -hex 22)"
APP_PASSWORD="$(openssl rand -hex 22)"
WORKTREE="/tmp/msb-wo419-preview-candidate-$STAMP-$$"
DUMP="/tmp/msb-wo419-preview-$STAMP-$$.dump"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/WO419_Disposable_Browser_Preview_$STAMP.txt"
APP_LOG="/tmp/WO419_Disposable_Browser_Flask_$STAMP-$$.log"
PREVIEW_PID=""
PROD_BEFORE=""
LIVE_HEAD=""
CLONE_OWNED=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1
echo "========== WO419 DISPOSABLE BROWSER PROFILE =========="
echo "Authority: MSB-Server-Management — Pre_Production_Browser_Review_Runbook.md"
echo "Candidate: $CANDIDATE_SHA"
echo "Preview identity: $PREVIEW_EMAIL"
echo "Explicit review port: $PREVIEW_PORT"
echo "Report: $REPORT"
echo "Production DB: pg_dump and SELECT only; all app reads use isolated clone"
echo

fingerprint() {
  sudo docker exec "$PRODUCTION_CONTAINER" psql -X -qAt \
    -v ON_ERROR_STOP=1 -U "$PG_ACTOR" -d "$PRODUCTION_DB" -c "
    SELECT md5(
      coalesce((SELECT string_agg(row_to_json(w)::text,'' ORDER BY w.work_order_id)
                FROM ops.work_order w),'') || '|' ||
      coalesce((SELECT string_agg(row_to_json(a)::text,''
                                ORDER BY a.work_order_assignment_id)
                FROM ops.work_order_assignment a),'') || '|' ||
      coalesce((SELECT string_agg(row_to_json(i)::text,'' ORDER BY i.intake_id)
                FROM stage.work_order_intake i),'')
    )"
}
cleanup() {
  local status=$?
  trap - EXIT HUP INT TERM
  set +e
  echo
  echo "WO419 preview cleanup, initial status=$status"
  if [[ -n "$PREVIEW_PID" ]]; then
    local line
    line="$(sudo ps -p "$PREVIEW_PID" -o args= 2>/dev/null)"
    if [[ "$line" == *"WorkOrders/Application/preview_entry.py"* ]]; then
      sudo -u fieldwiring -H kill -- -"$PREVIEW_PID" >/dev/null 2>&1 || true
    else
      echo "HOLD: preview PID command mismatch; no broad process kill"
      status=80
    fi
  fi
  if [[ "$CLONE_OWNED" == 1 && "$CLONE_CONTAINER" == msb-wo419-preview-* ]]; then
    sudo docker rm -f "$CLONE_CONTAINER" >/dev/null 2>&1 || true
  fi
  if [[ "$WORKTREE" == /tmp/msb-wo419-preview-candidate-* ]]; then
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $WORKTREE"; then
      sudo git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
    fi
  fi
  [[ "$DUMP" == /tmp/msb-wo419-preview-* ]] && rm -f "$DUMP"
  if [[ -n "$PROD_BEFORE" ]]; then
    local after
    after="$(fingerprint 2>/dev/null)"
    if [[ "$after" != "$PROD_BEFORE" ]]; then
      echo "HOLD: production Work Order/Intake fingerprint changed; investigate external writes"
      status=81
    else
      echo "PASS: Production Work Order/Intake fingerprint unchanged"
    fi
  fi
  if [[ -n "$LIVE_HEAD" ]]; then
    local now
    now="$(sudo git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
    if [[ "$now" != "$LIVE_HEAD" ]]; then
      echo "HOLD: live repository checkout HEAD changed"
      status=82
    else
      echo "PASS: shared checkout HEAD unchanged"
    fi
  fi
  if [[ -z "$(ss -ltnH "sport = :$PREVIEW_PORT")" ]]; then
    echo "PASS: preview port no longer listening"
  else
    echo "HOLD: preview listener remains after cleanup; inspect exact PID before retry"
    status=83
  fi
  if [[ "$status" -eq 0 ]]; then
    echo "WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT"
  else
    echo "WO419 DISPOSABLE BROWSER REVIEW: HOLD (status $status)"
  fi
  echo "Retained report: $REPORT"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# No clone, worktree, cleanup, sudo or listener modification before
# verifying the explicit non-Production port and foreground authorization.
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
  echo "HOLD: port $PREVIEW_PORT already has a listener; do not kill it"
  ss -ltnp "sport = :$PREVIEW_PORT" || true
  exit 4
fi
sudo -v
if [[ ! -x "$PYTHON" ]]; then
  sudo -u fieldwiring -H test -x "$PYTHON" ||
    { echo "HOLD: documented runtime is not executable as service account"; exit 5; }
fi
sudo docker ps --format '{{.Names}}' | grep -Fxq "$PRODUCTION_CONTAINER" ||
  { echo "HOLD: production PostgreSQL container is unavailable"; exit 6; }
for service in msb-setup.service fieldwiring.service; do
  systemctl is-active --quiet "$service" ||
    { echo "HOLD: existing Production service inactive: $service"; exit 7; }
done
LIVE_HEAD="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "HOLD: existing repository checkout is dirty; do not modify live checkout"
  exit 8
fi
PROD_BEFORE="$(fingerprint)"
echo "Production fingerprint captured (not logging record-level PII)"

sudo git -C "$REPO_ROOT" fetch origin "$CANDIDATE_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$CANDIDATE_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$LIVE_HEAD" "$CANDIDATE_SHA"; then
  echo "HOLD: candidate is not a descendant of current shared checkout"
  exit 9
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$CANDIDATE_SHA"
# Only the temporary public-source worktree is readable by the service account;
# do not change /opt runtime permissions or live checkout ownership.
sudo chmod -R a+rX "$WORKTREE"
sudo -u fieldwiring -H test -r "$WORKTREE/WorkOrders/Application/backend.py" || {
  echo "HOLD: candidate worktree not accessible to approved service account"; exit 9;
}

echo "--- Candidate source tests (no database) ---"
sudo -u fieldwiring -H env PYTHONDONTWRITEBYTECODE=1 bash -c "
  cd '$WORKTREE'
  '$PYTHON' -m pytest -q -p no:cacheprovider \
    WorkOrders/Application/test_work_management_preview.py \
    Database/Acceptance/test_wo419_unified_ticket_read_model.py
"
echo "PASS: candidate source and isolated Flask tests"

echo "--- Current Production dump to Docker-private clone ---"
sudo docker exec "$PRODUCTION_CONTAINER" pg_dump \
  -U "$PG_ACTOR" -d "$PRODUCTION_DB" -Fc > "$DUMP"
test -s "$DUMP"
sudo docker exec -i "$PRODUCTION_CONTAINER" pg_restore --list < "$DUMP" >/dev/null

sudo docker run -d --name "$CLONE_CONTAINER" --network "$NETWORK" \
  -e POSTGRES_USER="$PG_ACTOR" -e POSTGRES_PASSWORD="$CLONE_DB_PASSWORD" \
  -e POSTGRES_DB=postgres "$IMAGE" >/dev/null
CLONE_OWNED=1
ready=0
for _ in $(seq 1 120); do
  if sudo docker exec -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
    pg_isready -U "$PG_ACTOR" -d postgres >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo "HOLD: isolated clone not ready"; exit 10; }

sudo docker exec -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
  createdb -U "$PG_ACTOR" -T template0 "$CLONE_DATABASE"
sudo docker exec -i -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
  pg_restore -U "$PG_ACTOR" -d "$CLONE_DATABASE" \
    --no-owner --no-acl --exit-on-error < "$DUMP"

psql_clone() {
  sudo docker exec -i -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$PG_ACTOR" -d "$CLONE_DATABASE" "$@"
}
# The app role exists only in the disposable instance, not Production.
psql_clone -c "CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';"
psql_clone -c "ALTER ROLE fieldwiring_app SET default_transaction_read_only = on;"
# The SQL file resides on the HOST worktree, not inside Docker.
# Stream it via stdin to the one disposable psql session, with a session-only
# approval marker. Never use `psql -f /tmp/host-worktree/...` inside a container.
{
  printf "%s\\n" "SET msb.wo419_preview_authorized='approved_disposable_clone';"
  cat "$WORKTREE/WorkOrders/Acceptance/wo419_preview_clone_read_grants.sql"
} | psql_clone

# Require a real private instance, not a public exposed port.
HOST_IP="$(sudo docker inspect "$CLONE_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
[[ -n "$HOST_IP" ]] || { echo "HOLD: clone private IP missing"; exit 11; }
if [[ "$(sudo docker inspect "$CLONE_CONTAINER" --format '{{json .NetworkSettings.Ports}}')" == *"HostIp"* ]]; then
  echo "HOLD: unexpected published clone DB port"; exit 11
fi
DSN="host=$HOST_IP port=5432 dbname=$CLONE_DATABASE user=fieldwiring_app password=$APP_PASSWORD"

echo "--- Clone query/read authorization and real stage assertions ---"
sudo -u fieldwiring -H env WORK_MGMT_PREVIEW_MODE=disposable \
  WORK_MGMT_DATABASE_DSN="$DSN" PYTHONDONTWRITEBYTECODE=1 \
  "$PYTHON" "$WORKTREE/WorkOrders/Acceptance/validate_work_management_clone.py" \
    --candidate-sha "$CANDIDATE_SHA" --preview-email "$PREVIEW_EMAIL"

echo "--- Start pinned Work Management reviewer (no client-supplied identity) ---"
PREVIEW_PID="$(
  sudo -u fieldwiring -H env WORK_MGMT_PREVIEW_MODE=disposable \
    WORK_MGMT_DATABASE_DSN="$DSN" WORK_MGMT_PREVIEW_EMAIL="$PREVIEW_EMAIL" \
    WORK_MGMT_PREVIEW_PORT="$PREVIEW_PORT" PYTHONDONTWRITEBYTECODE=1 \
    APP_DIR="$WORKTREE/WorkOrders/Application" APP_LOG="$APP_LOG" \
    PYTHON="$PYTHON" bash -c '
      cd "$APP_DIR"
      setsid "$PYTHON" "$APP_DIR/preview_entry.py" > "$APP_LOG" 2>&1 &
      echo $!
    '
)"
[[ "$PREVIEW_PID" =~ ^[0-9]+$ ]] || { echo "HOLD: preview PID missing"; exit 12; }
ready=0
for _ in $(seq 1 60); do
  if curl -fsS --max-time 5 "http://127.0.0.1:$PREVIEW_PORT/api/work-orders/health" >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 0.5
done
if [[ "$ready" != 1 ]]; then
  echo "HOLD: Work Management app did not become healthy"
  # Avoid printing raw sensitive app/runtime details from logs to the operator.
  exit 13
fi
# Real authorized browser routes and explicit negative write path.
curl -fsS --max-time 10 "http://127.0.0.1:$PREVIEW_PORT/api/work-orders/tickets?scope=all" >/dev/null
WRITE_STATUS="$(curl -s -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{}' \
  "http://127.0.0.1:$PREVIEW_PORT/api/work-orders/tickets")"
[[ "$WRITE_STATUS" == 405 ]] || { echo "HOLD: read-only POST boundary failed"; exit 14; }

echo
echo "WO419 BROWSER REVIEW READY"
echo "Open via the protected SSH tunnel: http://127.0.0.1:$PREVIEW_PORT/"
echo "Candidate SHA: $CANDIDATE_SHA"
echo "Reviewer: $PREVIEW_EMAIL"
echo "DB: private disposable clone only; Work Management GET API/read-only"
echo "Do not treat V0.1 as completed P0 triage/email/browser acceptance."
read -r -p "After reviewing the browser, press ENTER here for controlled teardown. " _
echo "Operator browser review window ended"
