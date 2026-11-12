#!/usr/bin/env bash
set -euo pipefail
umask 077

CONF="/usr/local/etc/nginx/conf.d/44755fe6-c616-423e-a026-028752779047/user.conf"
NGINX="/bin/nginx"
BACKUP_DIR="/root/msb-nginx-backups"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/user.conf.pre-people-$STAMP"
REPORT="/tmp/MSB_People_Synology_Route_Deploy_$STAMP.txt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_HEALTH="http://192.168.5.9:8796/api/health"
PUBLIC_ORIGIN="https://my.sheboyganlights.org"
CONFIG_CHANGED=0
SUCCESS=0

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE MANAGER SYNLOGY PROTECTED ROUTE DEPLOYMENT =========="
echo "Authority:     MSB-Server-Management — Synology_Protected_Application_Reverse_Proxy.md"
echo "Report:        $REPORT"
echo "Config:        $CONF"
echo "Backend:       $BACKEND_HEALTH"
echo "Public route:  $PUBLIC_ORIGIN/people/"
echo

restore_route() {
    if [[ -s "$BACKUP_FILE" ]]; then
        echo "Restoring Synology nginx config from $BACKUP_FILE"
        sudo cp -a "$BACKUP_FILE" "$CONF"
        sudo "$NGINX" -t
        sudo "$NGINX" -s reload
    fi
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 && "$CONFIG_CHANGED" -eq 1 ]]; then
        echo
        echo "--- FAIL-CLOSED SYNLOGY ROUTE ROLLBACK ---"
        restore_route || true
    fi

    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    if [[ -s "$BACKUP_FILE" ]]; then
        echo "Rollback config retained at: $BACKUP_FILE"
    else
        echo "Rollback config: not created before this stop"
    fi
    echo "Route deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

if [[ ! -f "$CONF" ]]; then
    echo "FAIL: documented Synology protected nginx config is missing: $CONF"
    exit 2
fi
if [[ ! -x "$NGINX" ]]; then
    echo "FAIL: documented nginx executable is missing: $NGINX"
    exit 3
fi

if ! curl -fsS "$BACKEND_HEALTH" >/tmp/msb-people-backend-health-$STAMP.json; then
    echo "FAIL: People backend is not reachable from Synology before route mutation"
    exit 4
fi
BACKEND_PAYLOAD="$(cat /tmp/msb-people-backend-health-$STAMP.json)"
rm -f /tmp/msb-people-backend-health-$STAMP.json
if [[ "$BACKEND_PAYLOAD" != *'"status":"ok"'* || "$BACKEND_PAYLOAD" != *'"version":"V0.2.0"'* ]]; then
    echo "FAIL: unexpected People backend health payload: $BACKEND_PAYLOAD"
    exit 5
fi
echo "PASS: People backend reachable from Synology: $BACKEND_PAYLOAD"

if sudo grep -Fq '# MSB PEOPLE BEGIN' "$CONF" \
   || sudo grep -Eq 'location[[:space:]]+(=|\^~)[[:space:]]+/people' "$CONF"; then
    echo "FAIL: /people route already exists in protected nginx config; stop for reconciliation"
    sudo grep -n -E 'MSB PEOPLE|/people' "$CONF" || true
    exit 6
fi

sudo mkdir -p "$BACKUP_DIR"
sudo cp -a "$CONF" "$BACKUP_FILE"
test -n "$BACKUP_FILE"
if ! sudo test -s "$BACKUP_FILE"; then
    echo "FAIL: Synology nginx rollback backup was not created"
    exit 7
fi
echo "Rollback config: $BACKUP_FILE"

cat <<'NGINX' | sudo tee -a "$CONF" >/dev/null

# MSB PEOPLE BEGIN
location = /people {
    return 301 /people/;
}

location ^~ /people/ {
    proxy_pass http://192.168.5.9:8796/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_connect_timeout 10s;
    proxy_read_timeout 120s;
    proxy_send_timeout 120s;
}
# MSB PEOPLE END
NGINX
CONFIG_CHANGED=1

echo
echo "--- Validate and reload Synology nginx ---"
sudo "$NGINX" -t
sudo "$NGINX" -s reload

people_ready=0
for attempt in $(seq 1 20); do
    CODE="$(curl -sk --resolve my.sheboyganlights.org:443:192.168.5.4 -o /tmp/msb-people-public-health-$STAMP.json -w '%{http_code}' "$PUBLIC_ORIGIN/people/api/health" || true)"
    if [[ "$CODE" == "200" ]]; then
        PAYLOAD="$(cat /tmp/msb-people-public-health-$STAMP.json)"
        if [[ "$PAYLOAD" == *'"status":"ok"'* && "$PAYLOAD" == *'"version":"V0.2.0"'* ]]; then
            echo "People route ready on attempt $attempt: HTTP 200 $PAYLOAD"
            people_ready=1
            break
        fi
    fi
    sleep 1
done
rm -f /tmp/msb-people-public-health-$STAMP.json
if [[ "$people_ready" -ne 1 ]]; then
    echo "FAIL: /people/api/health did not become ready within the documented bounded window"
    exit 8
fi

REDIRECT_CODE="$(curl -skI --resolve my.sheboyganlights.org:443:192.168.5.4 -o /tmp/msb-people-redirect-$STAMP.txt -w '%{http_code}' "$PUBLIC_ORIGIN/people")"
if [[ "$REDIRECT_CODE" != "301" ]]; then
    echo "FAIL: /people returned HTTP $REDIRECT_CODE, expected 301"
    cat /tmp/msb-people-redirect-$STAMP.txt || true
    rm -f /tmp/msb-people-redirect-$STAMP.txt
    exit 9
fi
if ! grep -qi '^location: .*/people/' /tmp/msb-people-redirect-$STAMP.txt; then
    echo "FAIL: /people redirect did not point to /people/"
    cat /tmp/msb-people-redirect-$STAMP.txt || true
    rm -f /tmp/msb-people-redirect-$STAMP.txt
    exit 10
fi
rm -f /tmp/msb-people-redirect-$STAMP.txt

echo "PASS: /people -> /people/ redirect"

ROOT_CODE="$(curl -sk --resolve my.sheboyganlights.org:443:192.168.5.4 -o /tmp/msb-people-root-$STAMP.html -w '%{http_code}' "$PUBLIC_ORIGIN/people/")"
if [[ "$ROOT_CODE" != "200" ]] || ! grep -q '<title>MSB People Manager</title>' /tmp/msb-people-root-$STAMP.html; then
    echo "FAIL: /people/ did not render the People Manager application"
    echo "HTTP $ROOT_CODE"
    rm -f /tmp/msb-people-root-$STAMP.html
    exit 11
fi
rm -f /tmp/msb-people-root-$STAMP.html
echo "PASS: /people/ renders People Manager"

NO_ID_CODE="$(curl -sk --resolve my.sheboyganlights.org:443:192.168.5.4 -o /tmp/msb-people-route-noid-$STAMP.json -w '%{http_code}' "$PUBLIC_ORIGIN/people/api/access")"
if [[ "$NO_ID_CODE" != "401" ]]; then
    echo "FAIL: routed People /api/access without identity returned HTTP $NO_ID_CODE, expected 401"
    cat /tmp/msb-people-route-noid-$STAMP.json || true
    rm -f /tmp/msb-people-route-noid-$STAMP.json
    exit 12
fi
rm -f /tmp/msb-people-route-noid-$STAMP.json
echo "PASS: reverse proxy does not inject People identity"

echo
echo "--- Regression-check existing protected applications ---"
for spec in \
    "fieldwiring:/fieldwiring/api/health" \
    "procedures:/procedures/api/health" \
    "setup:/setup/api/health"; do
    name="${spec%%:*}"
    path="${spec#*:}"
    code="$(curl -sk --resolve my.sheboyganlights.org:443:192.168.5.4 -o /tmp/msb-existing-$name-$STAMP.json -w '%{http_code}' "$PUBLIC_ORIGIN$path" || true)"
    if [[ "$code" != "200" ]]; then
        echo "FAIL: existing protected $name health returned HTTP $code"
        cat /tmp/msb-existing-$name-$STAMP.json || true
        rm -f /tmp/msb-existing-$name-$STAMP.json
        exit 13
    fi
    rm -f /tmp/msb-existing-$name-$STAMP.json
    echo "PASS: existing protected $name route healthy"
done

echo
echo "PEOPLE MANAGER SYNLOGY PROTECTED ROUTE DEPLOYMENT: PASS"
echo "Public route: $PUBLIC_ORIGIN/people/"
echo "Next: normal Cloudflare-authenticated browser verification and GA4 acceptance."
SUCCESS=1
