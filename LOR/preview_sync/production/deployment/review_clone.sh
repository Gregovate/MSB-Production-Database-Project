#!/usr/bin/env bash
# Temporary current-production clone + exact candidate browser review. No deploy.
set -euo pipefail
if [[ ( $# != 3 && $# != 4 ) || "$1" != 8898 || ! "$2" =~ ^[a-f0-9]{40}$ || "$3" != *@* ]]; then
    echo 'Usage: review_clone.sh 8898 <exact-candidate-sha> <existing-MSB-reviewer-email>' >&2; exit 2
fi
port="$1"; sha="$2"; reviewer="$3"
input_zip="${4:-}"
if [[ -n "$input_zip" && ( ! "$input_zip" =~ ^/tmp/msb299-catalog-[a-f0-9]{32}\.zip$ || ! -f "$input_zip" ) ]]; then
    echo 'HOLD: invalid copied master archive path'; exit 2
fi
[[ $(id -u) == 0 ]] || { echo 'Run via the established sudo boundary'; exit 2; }
[[ -z $(ss -ltnH "sport = :$port") ]] || { echo 'HOLD: review listener already occupied'; exit 2; }
repo=/opt/fieldwiring
runtime=/opt/lor-preflight/.venv/bin/python
[[ -x "$runtime" ]] || { echo 'HOLD: existing LOR runtime missing'; exit 2; }
git -C "$repo" fetch origin agent/issue-299-lor2db-2pc-sync-phase1
git -C "$repo" cat-file -e "$sha^{commit}"
root=$(mktemp -d /tmp/msb-lor2pc-review.XXXXXXXX)
name="lor2pc-review-${root##*.}"
pgid=''; worktree=0; container=0
cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    if [[ -n "$pgid" ]] && kill -0 "$pgid" 2>/dev/null; then
        command=$(ps -p "$pgid" -o args=)
        if [[ "$command" == *"$root/start.py"* ]]; then kill -- "-$pgid" 2>/dev/null || true
        else echo 'HOLD: preview PID ownership changed; not killed'; result=1; fi
    fi
    if [[ $container == 1 ]]; then
        # Capture only runtime state and logs, never docker inspect Config.Env.
        docker inspect "$name" --format '{{json .State}}' > "$root/container-state.json" 2>&1 || true
        docker logs "$name" > "$root/container.log" 2>&1 || true
        docker rm -f "$name" >/dev/null || result=1
    fi
    if [[ $worktree == 1 ]]; then git -C "$repo" worktree remove --force "$root/source" || result=1; fi
    # Logs and snapshot remain private evidence, not a claimed validated rollback.
    echo "Review evidence retained: $root"
    if [[ $result == 0 ]]; then echo 'LOR2PC DISPOSABLE BROWSER PREVIEW: CLEAN EXIT'; else echo 'LOR2PC PREVIEW HOLD: inspect retained evidence'; fi
    exit "$result"
}
trap cleanup EXIT HUP INT TERM
chmod 700 "$root"
umask 077
git -C "$repo" worktree add --detach "$root/source" "$sha" >/dev/null
worktree=1
chgrp -R msbadmin "$root/source"
chmod -R g+rX "$root/source"
# Source snapshot is a read-only pg_dump. It never locks/fences/restarts writers.
docker exec msb-postgres pg_dump -U msbadmin -d msb -Fc --no-owner --no-acl > "$root/production-copy.dump"
docker exec -i msb-postgres pg_restore --list < "$root/production-copy.dump" > "$root/archive-list.txt"
secret=$(python3 -c 'import secrets; print(secrets.token_hex(24))')
# Only a fresh disposable secret is supplied; never read the Production DSN.
docker run -d --name "$name" -e POSTGRES_USER=msbadmin -e "POSTGRES_PASSWORD=$secret" \
    -e POSTGRES_DB=lor2pc_disposable -p 127.0.0.1::5432 postgis/postgis:16-3.5 >/dev/null
container=1
# Consume Server Management's final post-init readiness contract, not the
# temporary Unix-socket server used while PostGIS extensions initialize.
ready=0
pid1=''
for attempt in $(seq 1 120); do
    running=$(docker inspect "$name" --format '{{.State.Running}}' 2>/dev/null || true)
    [[ "$running" == true ]] || break
    pid1=$(docker exec "$name" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)
    if [[ "$pid1" == postgres ]] && docker exec "$name" pg_isready -U msbadmin -d lor2pc_disposable >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ $ready != 1 ]]; then
    echo "HOLD: disposable PostgreSQL did not reach final post-init ready state; PID 1: ${pid1:-unknown}"
    exit 2
fi
docker exec -i "$name" pg_restore -U msbadmin -d lor2pc_disposable --no-owner --no-acl --exit-on-error < "$root/production-copy.dump"
# Restore without ACL, then recreate only the reviewed application permissions.
docker exec -i "$name" psql -X -U msbadmin -d lor2pc_disposable -v ON_ERROR_STOP=1 <<SQL
CREATE ROLE lor_preflight_app LOGIN PASSWORD '$secret';
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA ops, ref FROM PUBLIC;
SQL
docker exec -i "$name" psql -X -U msbadmin -d lor2pc_disposable -v ON_ERROR_STOP=1 \
    < "$root/source/LOR2DB/Application/grant_lor_preflight_app.sql"
docker exec -i "$name" psql -X -U msbadmin -d lor2pc_disposable -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
IF has_function_privilege('lor_preflight_app','ref.setup_browser_capabilities(text)','EXECUTE') THEN
RAISE EXCEPTION 'Unexpected pre-grant capability'; END IF;
END $$;
SQL
docker exec -i "$name" psql -X -U msbadmin -d lor2pc_disposable -v ON_ERROR_STOP=1 \
    < "$root/source/LOR2DB/02_Reconciliation/reconciliation/migrations/0043_grant_lor2pc_source_reader.sql"
docker exec -i "$name" psql -X -U msbadmin -d lor2pc_disposable -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
IF NOT has_function_privilege('lor_preflight_app','ref.setup_browser_capabilities(text)','EXECUTE')
OR has_table_privilege('lor_preflight_app','ops.lor_reconciliation_source_run','UPDATE')
OR has_table_privilege('lor_preflight_app','public.directus_users','UPDATE') THEN
RAISE EXCEPTION 'Least-privilege validation failed'; END IF;
END $$;
SQL
dbport=$(docker port "$name" 5432/tcp | sed -n 's/^127\.0\.0\.1://p')
[[ "$dbport" =~ ^[0-9]+$ && "$dbport" != 5432 ]] || { echo 'HOLD: invalid disposable DB binding'; exit 2; }
# A private environment file avoids exposing the fresh disposable DSN in argv.
python3 - "$root/preview.env" "$dbport" "$secret" "$reviewer" <<'PY'
import json,sys
path,port,password,email=sys.argv[1:]
open(path,'w').write(json.dumps({'LOR2PC_PREVIEW_MODE':'disposable','LOR2PC_PREVIEW_PORT':'8898',
    'LOR2PC_PREVIEW_EMAIL':email,'LOR2PC_PREVIEW_DSN':f'host=127.0.0.1 port={port} dbname=lor2pc_disposable user=lor_preflight_app password={password}'}))
PY
unset secret
entry="$root/source/LOR/preview_sync/production/preview_entry.py"
if [[ -n "$input_zip" ]]; then
    cp -- "$input_zip" "$root/copied-master.zip"
    rm -- "$input_zip"
    mkdir "$root/catalog-workspace"
    chown lor-preflight:msbadmin "$root/catalog-workspace"
    chmod 700 "$root/catalog-workspace"
    chgrp msbadmin "$root/copied-master.zip"
    chmod 640 "$root/copied-master.zip"
    python3 - "$root/preview.env" "$root" <<'PYENV'
import json,sys
path,root=sys.argv[1:]
value=json.load(open(path))
value.update(LOR2PC_COPIED_MASTER_ZIP=root+'/copied-master.zip',LOR2PC_CATALOG_WORKSPACE=root+'/catalog-workspace')
open(path,'w').write(json.dumps(value))
PYENV
    entry="$root/source/LOR/preview_sync/production/catalog_preview_entry.py"
fi
cat > "$root/start.py" <<'PY'
import json,os,runpy,sys
os.environ.update(json.load(open(sys.argv[1])))
runpy.run_path(sys.argv[2],run_name='__main__')
PY
# Keep the Production dump private to root; the service account can traverse
# only the review source/config boundary and write its own log.
chgrp msbadmin "$root" "$root/start.py" "$root/preview.env"
chmod 750 "$root"
chmod 640 "$root/start.py" "$root/preview.env"
touch "$root/browser.log"
chown lor-preflight:msbadmin "$root/browser.log"
chmod 640 "$root/browser.log"
# Foreground user switch; only the authorized target shell backgrounds Flask.
pgid=$(runuser -u lor-preflight -- bash -c '
    setsid "$1" "$2" "$3" "$4" > "$5" 2>&1 &
    echo $!
' bash "$runtime" "$root/start.py" "$root/preview.env" "$entry" "$root/browser.log")
ready=0
for attempt in $(seq 1 40); do
    if curl -fsS "http://127.0.0.1:$port/lor2db/preflight/api/current-source" > "$root/current-source.json"; then ready=1; break; fi
    kill -0 "$pgid" 2>/dev/null || break
    sleep 1
done
[[ $ready == 1 ]] || { echo 'HOLD: browser/source readiness failed; inspect browser.log'; exit 2; }
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$port/lor2db/preflight/api/parser/run")
[[ $code == 403 ]] || { echo 'HOLD: preview write guard failed'; exit 2; }
echo 'BROWSER REVIEW READY: http://127.0.0.1:8898/lor2db/'
echo 'Disposable clone only. Actual Cloudflare/PC handoff is not accepted by this review.'
if [[ -n "$input_zip" ]]; then
    echo 'CATALOG REVIEW: unchanged accepted master copies + disposable DB/evidence only.'
    echo 'Review unchanged catalog first; then http://127.0.0.1:8898/review/ to upload your changed local export.'
    echo 'Return to LOR2DB to review/publish the disposable catalog. Do not install/launch the PC updater.'
else
    echo 'Inspect shared landing/status and the PC entry. Do not install/launch the PC updater.'
fi
read -r -p 'After browser review, press Enter for cleanup: ' _ </dev/tty
