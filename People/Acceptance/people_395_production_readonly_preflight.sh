#!/usr/bin/env bash
# Issue #395: read-only Production readiness only; NEVER execute a migration.
# Authority: MSB-Server-Management Production_Database_Change_Deployment_Runbook.md
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
case "$SCRIPT_DIR" in
    /tmp/msb-people-395-production-preflight-*) ;;
    *) echo "STOP: unrecognized preflight upload directory"; exit 2 ;;
esac

EXPECTED_MAIN_SHA="${1:?exact merged main SHA required}"
EXPECTED_LIVE_SHA="bb8dfa498c5b4bbecfc3693f68c4066c1e08242e"
REPO="/opt/fieldwiring"
ENV_FILE="/etc/msb-people/people.env"
REPORT="/tmp/MSB_People395_Production_Readonly_Preflight_$(date +%Y%m%dT%H%M%S).txt"
STEP="preflight"
CHECKOUT="NOT CHECKED"
MAINTENANCE="NOT CHECKED"
SECRET="NOT CHECKED"
RESULT="STOP"
PERSON_FP="NOT CAPTURED"
DIRECTUS_FP="NOT CAPTURED"

exec > >(tee "$REPORT") 2>&1

finish() {
    local rc=$?
    trap - EXIT HUP INT TERM
    set +e
    if [[ "$rc" == 0 ]]; then RESULT="PASS: READ-ONLY PREFLIGHT"; fi
    # Clean only this unique upload; keep report in /tmp.
    if [[ "$SCRIPT_DIR" == /tmp/msb-people-395-production-preflight-* ]]; then
        rm -rf -- "$SCRIPT_DIR"
    fi
    echo
    echo "========== BEGIN #395 RESULT =========="
    echo "Release target:     $EXPECTED_MAIN_SHA"
    echo "Production HEAD:    $CHECKOUT"
    echo "Controller:         $MAINTENANCE"
    echo "Credential:         $SECRET"
    echo "Person fingerprint: $PERSON_FP"
    echo "Directus fingerprint: $DIRECTUS_FP"
    echo "Last step:          $STEP"
    echo "Result:             $RESULT"
    echo "Exit status:        $rc"
    echo "Report:             $REPORT"
    echo "Production writes:  NONE"
    echo "========== END #395 RESULT =========="
    exit "$rc"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
stop() { echo "STOP: $1"; exit 30; }
psql_read() {
    sudo docker exec msb-postgres \
        psql -X -qAt -v ON_ERROR_STOP=1 -U msbadmin -d msb -c "$1"
}

STEP="Authenticate and confirm host"
sudo -v
[[ "$(hostname)" == "msb-prod-db" ]] || stop "incorrect server host"
[[ "$EXPECTED_MAIN_SHA" =~ ^[0-9a-f]{40}$ ]] || stop "invalid exact target SHA"
echo "READ-ONLY #395 PRODUCTION PREFLIGHT"
echo "Exact merged-main target: $EXPECTED_MAIN_SHA"

STEP="Check Issue #37 ONLINE"
status_json="$(sudo python3 /opt/msb-maintenance/msb_maintenance_controller.py \
    --config /etc/msb-maintenance/config.json status)"
python3 -c '
import json,sys
o=json.load(sys.stdin)
assert o.get("state")=="ONLINE", "Controller is not ONLINE"
assert o.get("live",{}).get("database_fenced") is False, "Database unexpectedly fenced"
assert not o.get("last_error"), "Maintenance controller reports an error"
' <<< "$status_json" || stop "maintenance controller is not healthy ONLINE"
MAINTENANCE="ONLINE / UNFENCED"
echo "PASS: Issue #37 controller ONLINE; no transition requested"

STEP="Check required services"
sudo docker inspect msb-postgres >/dev/null
sudo docker inspect msb-directus >/dev/null
for unit in msb-people.service msb-setup.service msb-procedures.service fieldwiring.service; do
    systemctl is-active --quiet "$unit" || stop "required service not active: $unit"
done
echo "PASS: database, Directus, and live services present/active"

STEP="Check deployed People version"
health="$(curl -fsS --max-time 10 http://192.168.5.9:8796/api/health)"
python3 -c '
import json,sys
o=json.load(sys.stdin)
assert o.get("status")=="ok", "People health status not OK"
assert o.get("version")=="V0.2.2", "People live version differs from expected V0.2.2"
' <<< "$health" || stop "People version/baseline differs; reconcile current live state"
echo "PASS: live People V0.2.2 health"

STEP="Check exact shared checkout and remote main"
CHECKOUT="$(sudo git -C "$REPO" rev-parse HEAD)"
[[ -z "$(sudo git -C "$REPO" status --porcelain)" ]] || stop "shared Production checkout is dirty"
[[ "$CHECKOUT" == "$EXPECTED_LIVE_SHA" ]] || stop "live checkout changed since #395 browser acceptance"
remote_main="$(sudo git -C "$REPO" ls-remote origin refs/heads/main | awk '{print $1}')"
[[ "$remote_main" == "$EXPECTED_MAIN_SHA" ]] || stop "origin main changed or cannot be verified as approved target"
echo "PASS: expected live checkout, clean tree and exact remote main"

STEP="Check migration 006 absence and #385 prerequisite"
[[ "$(psql_read "SELECT to_regprocedure('ref.reconcile_directus_person_identity(text)') IS NOT NULL;")" == "t" ]] \
    || stop "#385 reconciliation prerequisite missing"
[[ "$(psql_read "SELECT to_regprocedure('ref.people_identity_bootstrap_status(text)') IS NULL;")" == "t" ]] \
    || stop "migration 006 already present or ambiguous; do not replay"
[[ "$(psql_read "SELECT to_regprocedure('ref.people_identity_bootstrap_reconcile(text)') IS NULL;")" == "t" ]] \
    || stop "migration 006 reconcile function already present; do not replay"
[[ "$(psql_read "SELECT count(*) FROM public.directus_roles WHERE name='MSB Browser';")" == "1" ]] \
    || stop "MSB Browser role identity is not unique"
echo "PASS: migration 006 absent; #385 and Browser baseline present"

STEP="Preserve Don's first-login fixture"
fixture="$(psql_read "SELECT
    (SELECT count(*) FROM ref.person
     WHERE person_id=18 AND active_flag AND directus_user_id IS NULL
       AND lower(email)='dmartens@sheboyganlights.org')=1
    AND
    (SELECT count(*) FROM public.directus_users
     WHERE lower(email)='dmartens@sheboyganlights.org')=0;")"
[[ "$fixture" == "t" ]] || stop "preserved first-login fixture changed; reconcile before proceeding"
echo "PASS: Don's first-login fixture remains unconsumed"

STEP="Capture Production fingerprints"
PERSON_FP="$(psql_read "SELECT md5(coalesce(string_agg(row_to_json(p)::text,'' ORDER BY p.person_id),'')) FROM ref.person p;")"
DIRECTUS_FP="$(psql_read "SELECT md5(coalesce(string_agg(row_to_json(u)::text,'' ORDER BY u.id),'')) FROM public.directus_users u;")"
[[ "$PERSON_FP" =~ ^[0-9a-f]{32}$ && "$DIRECTUS_FP" =~ ^[0-9a-f]{32}$ ]] \
    || stop "identity fingerprint capture failed"
echo "PASS: Production identity fingerprints read (no mutations)"

STEP="Check protected Directus credential without printing secret"
# The credential is read only inside the Python process, never put in a CLI arg
# or printed. No request to create or change a Directus user is made.
if ! sudo python3 - "$ENV_FILE" <<'PY'
import json, pathlib, stat, sys
from urllib.request import Request, build_opener, ProxyHandler
from urllib.error import HTTPError, URLError
p=pathlib.Path(sys.argv[1])
try:
    st=p.stat()
    if st.st_uid != 0 or (stat.S_IMODE(st.st_mode) & 0o027):
        raise ValueError("protected environment-file owner/mode mismatch")
    values={}
    for line in p.read_text(encoding="utf-8").splitlines():
        raw=line.strip()
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key,val=raw.split("=",1)
        val=val.strip()
        if len(val)>=2 and val[0] in "'\"" and val[-1]==val[0]:
            val=val[1:-1]
        values[key.strip()]=val
    token=values.get("PEOPLE_DIRECTUS_IDENTITY_TOKEN","").strip()
    if not token:
        raise ValueError("missing identity token")
    url=values.get("PEOPLE_DIRECTUS_URL","http://127.0.0.1:8055").strip().rstrip("/")
    if url!="http://127.0.0.1:8055":
        raise ValueError("unexpected Directus target")
    request=Request(url+"/users/me?fields=id,status",headers={"Authorization":"Bearer "+token})
    with build_opener(ProxyHandler({})).open(request,timeout=5) as response:
        payload=json.load(response)
    if payload.get("data",{}).get("status")!="active":
        raise ValueError("token user not active")
    print("PASS: protected credential present and authenticated for read")
except (OSError,ValueError,HTTPError,URLError,KeyError,TypeError):
    print("STOP: protected Directus credential missing, invalid or unusable")
    sys.exit(1)
PY
then
    SECRET="STOP: NOT READY"
    stop "Directus identity-bootstrap credential requires governed provisioning"
fi
SECRET="PRESENT / VALID API READ"
echo "NOTE: provider-field creation authority still requires release validation."

STEP="Read-only preflight complete"
echo "PASS: read-only prerequisites met; no migration or Apps publication executed"
echo "NOTE: reviewed release runner/rollback and Backbone publisher are separate gates."
