#!/usr/bin/env bash
# WO419-BR01 | Profile-specific current-clone browser runner
# Consumes MSB-Server-Management: Pre_Production_Browser_Review_Runbook.md
# SOURCE ONLY until Server Management approves #419 port profile and launcher.
set -Eeuo pipefail
umask 077

if [[ $# -lt 4 || $# -gt 5 ]]; then
  echo "HOLD: candidate SHA, registered port, reviewer email, approved ref and optional start/resume mode required"
  exit 2
fi
CANDIDATE_SHA="$1"
PREVIEW_PORT="$2"
PREVIEW_EMAIL="$3"
CANDIDATE_REF="$4"
MODE="${5:-start}"

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
if [[ "$MODE" != "start" && "$MODE" != "resume" ]]; then
  echo "HOLD: browser preview mode must be start or resume"; exit 2
fi
STATE_FILE="/tmp/msb-wo419-preview-state-${PREVIEW_PORT}.env"
PRESERVE_FOR_RECONNECT=0

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
CLONE_WRITE_TOKEN="$(openssl rand -hex 24)"
PREVIEW_CSRF_TOKEN="$(openssl rand -hex 24)"
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
  if [[ "$PRESERVE_FOR_RECONNECT" == 1 ]]; then
    echo
    echo "WO419_PREVIEW_TRANSPORT_LOST: preserving exact browser/clone for reconnect."
    echo "State: $STATE_FILE"
    echo "No Production fingerprint or cleanup is claimed before operator finish."
    exit "$status"
  fi
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
  rm -f "$STATE_FILE"
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
trap 'if [[ -s "$STATE_FILE" ]]; then PRESERVE_FOR_RECONNECT=1; exit 75; else exit 129; fi' HUP

write_resume_state() {
  # No credentials, CSRF tokens, clone DB passwords, or request data in state.
  # Only the owning msbadmin user can read this file.
  umask 077
  if [[ -e "$STATE_FILE" || -L "$STATE_FILE" ]]; then
    echo "HOLD: preview state already exists on port $PREVIEW_PORT; inspect before overwriting"
    return 1
  fi
  {
    printf 'CANDIDATE_SHA=%q\n' "$CANDIDATE_SHA"
    printf 'CANDIDATE_REF=%q\n' "$CANDIDATE_REF"
    printf 'PREVIEW_EMAIL=%q\n' "$PREVIEW_EMAIL"
    printf 'PREVIEW_PORT=%q\n' "$PREVIEW_PORT"
    printf 'CLONE_CONTAINER=%q\n' "$CLONE_CONTAINER"
    printf 'CLONE_DATABASE=%q\n' "$CLONE_DATABASE"
    printf 'CLONE_OWNED=%q\n' "$CLONE_OWNED"
    printf 'WORKTREE=%q\n' "$WORKTREE"
    printf 'DUMP=%q\n' "$DUMP"
    printf 'REPORT=%q\n' "$REPORT"
    printf 'APP_LOG=%q\n' "$APP_LOG"
    printf 'PREVIEW_PID=%q\n' "$PREVIEW_PID"
    printf 'PROD_BEFORE=%q\n' "$PROD_BEFORE"
    printf 'LIVE_HEAD=%q\n' "$LIVE_HEAD"
    printf 'VERIFIED_WORKTREE_SHA=%q\n' "$VERIFIED_WORKTREE_SHA"
  } > "$STATE_FILE"
  chmod 600 "$STATE_FILE"
}

resume_existing_preview() {
  # This path NEVER makes a new clone or runs start/stale cleanup.
  # Unknown listener/session always HOLD. No identity guessing.
  local requested_sha="$CANDIDATE_SHA"
  local requested_ref="$CANDIDATE_REF"
  local requested_port="$PREVIEW_PORT"
  local requested_email="$PREVIEW_EMAIL"
  local saved_version=""
  PRESERVE_FOR_RECONNECT=1
  sudo -v
  if [[ -L "$STATE_FILE" || ! -s "$STATE_FILE" ||
        "$(stat -c '%u:%a' "$STATE_FILE" 2>/dev/null)" != "$(id -u):600" ]]; then
    echo "HOLD: no owned private resume state for port $requested_port"
    exit 76
  fi
  # State created using Bash %q by the exact approved script, not HTTP input.
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  if [[ "$CANDIDATE_SHA" != "$requested_sha" ||
        "$CANDIDATE_REF" != "$requested_ref" ||
        "$PREVIEW_PORT" != "$requested_port" ||
        "$PREVIEW_EMAIL" != "$requested_email" ||
        "$VERIFIED_WORKTREE_SHA" != "$requested_sha" ]]; then
    echo "HOLD: resume request does not match exact SHA/ref/port/reviewer"
    exit 77
  fi
  if [[ ! "$PREVIEW_PID" =~ ^[0-9]+$ ||
        "$(sudo ps -p "$PREVIEW_PID" -o uid= 2>/dev/null | xargs)" != "$(id -u fieldwiring)" ||
        "$(sudo ps -p "$PREVIEW_PID" -o args= 2>/dev/null)" != *"WorkOrders/Application/preview_entry.py"* ]]; then
    echo "HOLD: expected exact Work Management preview PID not running/owned"
    exit 78
  fi
  if ! sudo ss -ltnp "sport = :$PREVIEW_PORT" 2>/dev/null |
      grep -Fq "pid=$PREVIEW_PID,"; then
    echo "HOLD: port is not owned by the saved preview PID; no cleanup attempted"
    exit 79
  fi
  if [[ "$CLONE_OWNED" != 1 || "$CLONE_CONTAINER" != msb-wo419-preview-* ||
        "$CLONE_DATABASE" != msb_wo419_preview ||
        "$(sudo docker inspect "$CLONE_CONTAINER" --format '{{.State.Running}}' 2>/dev/null)" != true ||
        -n "$(sudo docker inspect "$CLONE_CONTAINER" --format '{{range .NetworkSettings.Ports}}{{.HostIp}}{{end}}' 2>/dev/null)" ]]; then
    echo "HOLD: exact saved private disposable PostgreSQL clone not verified"
    exit 80
  fi
  if [[ "$WORKTREE" != /tmp/msb-wo419-preview-candidate-* ||
        "$(sudo git -C "$WORKTREE" rev-parse HEAD 2>/dev/null)" != "$CANDIDATE_SHA" ]]; then
    echo "HOLD: saved candidate worktree identity differs"
    exit 81
  fi
  local health
  health="$(curl -fsS --max-time 8 "http://127.0.0.1:$PREVIEW_PORT/api/work-orders/health")" || {
    echo "HOLD: preserved browser health unavailable"
    exit 82
  }
  saved_version="$(printf '%s' "$health" |
    sudo -u fieldwiring -H "$PYTHON" -c 'import sys,json; j=json.load(sys.stdin); print(j.get("version", ""))')" || {
      echo "HOLD: preserved browser version cannot be read"; exit 82;
    }
  local expected_version
  expected_version="$(grep -E '^APP_VERSION = ' "$WORKTREE/WorkOrders/Application/backend.py" | head -1 |
    sed -E 's/^APP_VERSION = "([^"]+)".*/\1/')"
  if [[ -z "$saved_version" || "$saved_version" != "$expected_version" ]]; then
    echo "HOLD: preserved browser version differs from pinned source"
    exit 83
  fi
  echo "WO419 DISPOSABLE BROWSER REVIEW RESUMED"
  echo "Same private clone, original Work Order edits, and preserved report: $REPORT"
  echo "Candidate: $CANDIDATE_SHA; reviewer: $PREVIEW_EMAIL; URL: http://127.0.0.1:$PREVIEW_PORT/"
  echo "When review is finished press ENTER; SSH loss will preserve it again."
  PRESERVE_FOR_RECONNECT=0
  if ! read -r -p "Press ENTER only after completing browser review. " _; then
    PRESERVE_FOR_RECONNECT=1
    echo "SSH/PTTY input lost; preserving preview state"
    exit 75
  fi
  echo "Operator finished resumed review; performing controlled teardown"
}

if [[ "$MODE" == "resume" ]]; then
  resume_existing_preview
  exit 0
fi

# No clone, worktree, cleanup, sudo or listener modification before
# verifying the explicit non-Production port and foreground authorization.
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
  echo "HOLD: port $PREVIEW_PORT already has a listener; do not kill it"
  ss -ltnp "sport = :$PREVIEW_PORT" || true
  exit 4
fi
if [[ -e "$STATE_FILE" || -L "$STATE_FILE" ]]; then
  echo "HOLD: an earlier #419 preview resume state exists; inspect ownership before start"
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
# The root-admin boundary owns Git metadata; the fieldwiring reader must
# never be granted traverse access to the shared production Git directory.
VERIFIED_WORKTREE_SHA="$(sudo git -C "$WORKTREE" rev-parse HEAD)"
[[ "$VERIFIED_WORKTREE_SHA" == "$CANDIDATE_SHA" ]] || {
  echo "HOLD: detached candidate Git identity mismatch"; exit 9;
}
echo "PASS: privileged detached candidate SHA verified"

# Only the temporary public-source worktree is readable by the service account;
# do not change /opt runtime permissions or live checkout ownership.
sudo chmod -R a+rX "$WORKTREE"
sudo -u fieldwiring -H test -r "$WORKTREE/WorkOrders/Application/backend.py" || {
  echo "HOLD: candidate worktree not accessible to approved service account"; exit 9;
}

echo "--- Exact candidate full application regression (no database) ---"
# Match the established Setup disposable acceptance regression, then
# exercise the #419 feature-owned tests. No partial-suite substitution.
sudo -u fieldwiring -H env PYTHONDONTWRITEBYTECODE=1 bash -c "
  cd '$WORKTREE'
  '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application Setup/Acceptance/test_setup_gis_preview.py
  '$PYTHON' -m pytest -q -p no:cacheprovider FieldWiring/Application
  '$PYTHON' -m pytest -q -p no:cacheprovider \
    WorkOrders/Application/test_work_management_preview.py \
    WorkOrders/Acceptance/test_work_management_disposable_profile.py \
    Database/Acceptance/test_wo419_unified_ticket_read_model.py
"
echo "PASS: exact candidate full Setup, FieldWiring and #419 regression"

echo "--- Current Production dump to Docker-private clone ---"
if command -v pv >/dev/null 2>&1; then
  echo "Production dump: streaming archive bytes (total unknown during export)"
  sudo docker exec "$PRODUCTION_CONTAINER" pg_dump \
    -U "$PG_ACTOR" -d "$PRODUCTION_DB" -Fc | pv -f -b -r -t > "$DUMP"
else
  echo "INFO: pv unavailable; dump transfer progress not displayed"
  sudo docker exec "$PRODUCTION_CONTAINER" pg_dump \
    -U "$PG_ACTOR" -d "$PRODUCTION_DB" -Fc > "$DUMP"
fi
test -s "$DUMP"
sudo docker exec -i "$PRODUCTION_CONTAINER" pg_restore --list < "$DUMP" >/dev/null

sudo docker run -d --name "$CLONE_CONTAINER" --network "$NETWORK" \
  -e POSTGRES_USER="$PG_ACTOR" -e POSTGRES_PASSWORD="$CLONE_DB_PASSWORD" \
  -e POSTGRES_DB=postgres "$IMAGE" >/dev/null
CLONE_OWNED=1
# PostGIS 16-3.5 runs a temporary initialization PostgreSQL instance:
# pg_isready may PASS during that temporary server, which the entrypoint
# intentionally shuts down. Existing MSB-Server-Management standard:
# PostgreSQL_Disposable_Acceptance_Standard.md -> final PID 1 contract.
ready=0
pid1=""
for _ in $(seq 1 120); do
  if [[ "$(sudo docker inspect "$CLONE_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" != "true" ]]; then
    break
  fi
  pid1="$(sudo docker exec "$CLONE_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
  if [[ "$pid1" == "postgres" ]] && \
     sudo docker exec -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
       pg_isready -U "$PG_ACTOR" -d postgres >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "HOLD: disposable PostGIS did not reach final PID1=postgres ready state"
  echo "Observed PID 1 command: ${pid1:-unknown}"
  sudo docker inspect "$CLONE_CONTAINER" --format 'Clone state: running={{.State.Running}} oom_killed={{.State.OOMKilled}} exit={{.State.ExitCode}}' || true
  sudo docker logs --tail 40 "$CLONE_CONTAINER" || true
  exit 10
fi
echo "PASS: disposable PostgreSQL final post-init PID1=postgres and pg_isready"

sudo docker exec -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
  createdb -U "$PG_ACTOR" -T template0 "$CLONE_DATABASE"
# The optional progress display never weakens pipefail/restore exit gates.
if command -v pv >/dev/null 2>&1; then
  echo "Clone restore: archive transfer progress (not restored-object count)"
  if pv -f -p -t -e -r -b -s "$(stat -c %s "$DUMP")" "$DUMP" | \
    sudo docker exec -i -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
      pg_restore -U "$PG_ACTOR" -d "$CLONE_DATABASE" \
        --no-owner --no-acl --exit-on-error; then
    restore_status=0
  else
    restore_status=$?
  fi
else
  echo "INFO: pv unavailable; restoring archive without progress display"
  if sudo docker exec -i -e PGPASSWORD="$CLONE_DB_PASSWORD" "$CLONE_CONTAINER" \
    pg_restore -U "$PG_ACTOR" -d "$CLONE_DATABASE" \
      --no-owner --no-acl --exit-on-error < "$DUMP"; then
    restore_status=0
  else
    restore_status=$?
  fi
fi
if [[ "$restore_status" -eq 0 ]]; then
  echo "PASS: disposable database restore finished on final PostgreSQL server"
else
  echo "HOLD: disposable PostgreSQL restore failed (exit $restore_status)"
  echo "Final-server gate passed; inspect clone rather than assuming OOM or schema failure"
  sudo docker inspect "$CLONE_CONTAINER" --format 'Clone state: running={{.State.Running}} oom_killed={{.State.OOMKilled}} exit={{.State.ExitCode}}' || true
  sudo docker logs --tail 40 "$CLONE_CONTAINER" || true
  exit "$restore_status"
fi

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
  printf '%s\n' "SET msb.wo419_preview_authorized='approved_disposable_clone';"
  cat "$WORKTREE/WorkOrders/Acceptance/wo419_preview_clone_read_grants.sql"
} | psql_clone

# Require a real private instance, not a public exposed port.
HOST_IP="$(sudo docker inspect "$CLONE_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
[[ -n "$HOST_IP" ]] || { echo "HOLD: clone private IP missing"; exit 11; }
if [[ "$(sudo docker inspect "$CLONE_CONTAINER" --format '{{json .NetworkSettings.Ports}}')" == *"HostIp"* ]]; then
  echo "HOLD: unexpected published clone DB port"; exit 11
fi
# Apply guarded acceptance persistence only INSIDE the private disposable clone.
# The marker and secret never appear in operator logs or Git and are destroyed
# with the clone. Production has neither the approval marker nor token table.
{
  printf '%s\n' "SET msb.wo419_preview_authorized='approved_disposable_clone';"
  printf '%s\n' "SET msb.wo419_clone_write_token='$CLONE_WRITE_TOKEN';"
  cat "$WORKTREE/WorkOrders/Acceptance/wo419_disposable_actions.sql"
} | psql_clone
echo "PASS: isolated clone write commands and no-send activity/outbox fixture installed"

DSN="host=$HOST_IP port=5432 dbname=$CLONE_DATABASE user=fieldwiring_app password=$APP_PASSWORD"

echo "--- Clone query/read authorization and real stage assertions ---"
sudo -u fieldwiring -H env WORK_MGMT_PREVIEW_MODE=disposable \
  WORK_MGMT_DATABASE_DSN="$DSN" WORK_MGMT_CLONE_IP="$HOST_IP" \
  WORK_MGMT_CLONE_WRITE_TOKEN="$CLONE_WRITE_TOKEN" \
  WORK_MGMT_VERIFIED_CANDIDATE_SHA="$VERIFIED_WORKTREE_SHA" PYTHONDONTWRITEBYTECODE=1 \
  "$PYTHON" "$WORKTREE/WorkOrders/Acceptance/validate_work_management_clone.py" \
    --candidate-sha "$CANDIDATE_SHA" --preview-email "$PREVIEW_EMAIL"

echo "--- Start pinned Work Management reviewer (no client-supplied identity) ---"
PREVIEW_PID="$(
  sudo -u fieldwiring -H env WORK_MGMT_PREVIEW_MODE=disposable \
    WORK_MGMT_DATABASE_DSN="$DSN" WORK_MGMT_CLONE_IP="$HOST_IP" \
    WORK_MGMT_CLONE_WRITE_TOKEN="$CLONE_WRITE_TOKEN" WORK_MGMT_PREVIEW_CSRF_TOKEN="$PREVIEW_CSRF_TOKEN" \
    WORK_MGMT_PREVIEW_EMAIL="$PREVIEW_EMAIL" \
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
# A reporter-facing personal queue is read-only; Manager queues are gated
# by the approved identity, not by a client-controlled preview flag.
curl -fsS --max-time 10 "http://127.0.0.1:$PREVIEW_PORT/api/work-orders/tickets?scope=my-feedback" >/dev/null
curl -fsS --max-time 10 "http://127.0.0.1:$PREVIEW_PORT/work-orders/assets/review_actions.js" >/dev/null

WRITE_STATUS="$(curl -s -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{}' \
  "http://127.0.0.1:$PREVIEW_PORT/api/work-orders/tickets")"
[[ "$WRITE_STATUS" == 405 ]] || { echo "HOLD: legacy list POST boundary failed"; exit 14; }
COMMAND_NEGATIVE_STATUS="$(curl -s -o /dev/null -w '%{http_code}' -X POST   -H 'Content-Type: application/json' -d '{"action":"create"}'   "http://127.0.0.1:$PREVIEW_PORT/api/work-orders/commands")"
[[ "$COMMAND_NEGATIVE_STATUS" == 403 ]] || { echo "HOLD: cross-site/no-CSRF write gate failed"; exit 14; }

echo
write_resume_state
echo "Reconnect state: $STATE_FILE"
echo "WO419 BROWSER REVIEW READY"
echo "Open via the protected SSH tunnel: http://127.0.0.1:$PREVIEW_PORT/"
echo "Candidate SHA: $CANDIDATE_SHA"
echo "Reviewer: $PREVIEW_EMAIL"
echo "DB: private disposable clone only; Work Management GET API/read-only"
echo "V0.3: Save actions mutate ONLY disposable clone; no mail/Directus send."
echo "Review: Manager Create, multi-person assignment, notes, separate triage, Testing and Feedback."
echo "Clone writes disappear at cleanup; Production and Directus remain unchanged."
if ! read -r -p "After reviewing the browser, press ENTER here for controlled teardown. " _; then
  PRESERVE_FOR_RECONNECT=1
  echo "Review input/tunnel was lost; preserving browser, clone, and saved review changes"
  exit 75
fi
echo "Operator browser review window ended; performing controlled teardown"
