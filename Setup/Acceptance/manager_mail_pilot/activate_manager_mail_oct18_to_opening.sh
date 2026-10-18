#!/usr/bin/env bash
# #205 under #122. Server authority:
# docs/server/Setup_205_Bounded_Manager_Daily_Mail_2026-10-18.md
# Execute as sudo bash SCRIPT EXACT_SHA DETACHED_WORKTREE, using the approved seven-person roster.
set -euo pipefail
if [[ "$EUID" -ne 0 || "$#" -ne 2 ]]; then echo 'STOP: root and (SHA, worktree) required'; exit 2; fi
SHA="$1"; ROOT="$2"; SOURCE="$ROOT/Setup/Acceptance/manager_mail_pilot"
DEST=/opt/msb-setup-manager-pilot
PY=/opt/fieldwiring/.venv/bin/python
IMPORTS=/opt/msb-setup/Setup/Application
LEDGER=/var/lib/msb-setup-manager-mail-pilot
ENV_FILE=/etc/msb-setup/manager_mail_2026_bounded.env
ROSTER="${MSB_FIRST_MANAGER_ROSTER:-}"
STOP_DAY="${MSB_MANAGER_MAIL_STOP_DATE:-2026-11-27}"
TODAY=msb-setup-manager-2026-today.service
SEASON=msb-setup-manager-season-2026
echo 'Authority: MSB Server Management #205 bounded Manager mail runbook'
echo 'Procedure: preflight -> one authorized Oct18 send -> finite 04:00 timer'
if [[ "$(TZ=America/Chicago date +%F)" != 2026-10-18 ]]; then echo 'STOP: October 18 only, no catch-up'; exit 2; fi
if [[ ! "$SHA" =~ ^[[:xdigit:]]{40}$ ]] ||
   [[ "$(git -C "$ROOT" rev-parse HEAD)" != "$SHA" ]] ||
   [[ -n "$(git -C "$ROOT" status --porcelain)" ]] ||
   [[ "$(git -C "$ROOT" rev-parse --show-toplevel)" != "$ROOT" ]]; then
  echo 'STOP: detached clean exact source required'; exit 2
fi
if [[ -z "$ROSTER" ]]; then echo 'STOP: private approved seven-Manager roster missing'; exit 2; fi
if [[ ! "$STOP_DAY" =~ ^2026-(10|11)-[0-9][0-9]$ ]] ||
   [[ "$STOP_DAY" < 2026-10-18 || "$STOP_DAY" > 2026-11-27 ]] ||
   ! date -d "$STOP_DAY" +%F 2>/dev/null | grep -Fxq "$STOP_DAY"; then
  echo 'STOP: stop date must be valid Oct18..Nov27, 2026'; exit 2
fi
test "$(systemctl is-active msb-setup.service)" = active || { echo 'STOP: Setup unhealthy'; exit 2; }
test -f /var/lib/fieldwiring/.pgpass && test -f /etc/msb-setup/setup.env || { echo 'STOP: accepted Setup credentials missing'; exit 2; }
test -d "$LEDGER" && test "$(stat -c %U "$LEDGER")" = fieldwiring || { echo 'STOP: prior delivery ledger unavailable'; exit 2; }
for f in manager_mail_pilot.py manager_digest_subject.txt manager_digest_template.txt manager_digest_html.html; do test -f "$SOURCE/$f" || { echo "STOP: source file absent: $f"; exit 2; }; done
if [[ -e "/etc/systemd/system/$TODAY" ||
      -e "/etc/systemd/system/$SEASON.service" ||
      -e "/etc/systemd/system/$SEASON.timer" || -e "$ENV_FILE" ]]; then
  echo 'STOP: bounded unit/config already exists; inspect, never blindly retry'; exit 2
fi
if find "$LEDGER" -maxdepth 1 -type f -name 'manager-2026-10-18-*.json' -print -quit | grep -q .; then
  echo 'STOP: Oct18 daily send already attempted; no repeat'; exit 2
fi
# Year-qualified finite calendar. November transitions to CST automatically.
OCT=''; NOV=''
if [[ "$STOP_DAY" > 2026-10-18 ]]; then
  if [[ "${STOP_DAY:5:2}" == 10 ]]; then
    OCT="2026-10-19..${STOP_DAY:8:2} 04:00:00 America/Chicago"
  else
    OCT='2026-10-19..31 04:00:00 America/Chicago'
    NOV="2026-11-01..${STOP_DAY:8:2} 04:00:00 America/Chicago"
  fi
  systemd-analyze calendar "$OCT" >/dev/null
  if [[ -n "$NOV" ]]; then systemd-analyze calendar "$NOV" >/dev/null; fi
fi
echo 'Read-only check: current seven Manager contacts and whole 2026 progress...'
sudo -u fieldwiring -H env \
  HOME=/var/lib/fieldwiring PGPASSFILE=/var/lib/fieldwiring/.pgpass \
  SETUP_DATABASE_DSN='host=127.0.0.1' PYTHONPATH="$IMPORTS" \
  MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER="$ROSTER" \
  "$PY" - "$SOURCE/manager_mail_pilot.py" <<'PY'
import sys,importlib.util
from pathlib import Path
from setup_scheduling_board_repository import SetupSchedulingBoardRepository
file=Path(sys.argv[1]); sp=importlib.util.spec_from_file_location("manager_bounded",file)
m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
dsn=m.accepted_setup_dsn()
roster=m.manager_directory(dsn)
managers=[p for p in roster if p["send_eligible"]]
m.enforce_approved_manager_audience(managers,roster)
assert len(roster)==len(managers)==7, "Seven eligible Manager contacts required"
report=m.summarize(SetupSchedulingBoardRepository(dsn).board(2026),m.chicago_now().date())
report.update(m.container_summary(dsn,season_year=2026))
assert report["total_tasks"]>0 and report["containers_total"]>0
print("PASS: seven authorized Managers; task count",report["total_tasks"],"Containers",report["containers_total"])
print("NO_SEND during preflight")
PY
# All read-only gates above must pass before writing units or sending.
install -d -o root -g root -m 0755 "$DEST"
for f in manager_mail_pilot.py manager_digest_subject.txt manager_digest_template.txt manager_digest_html.html; do
  install -o root -g root -m 0644 "$SOURCE/$f" "$DEST/$f"
  cmp -s "$SOURCE/$f" "$DEST/$f" || { echo 'STOP: source copy mismatch'; exit 2; }
done
printf 'MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER=%s\nMSB_MANAGER_MAIL_STOP_DATE=%s\n' "$ROSTER" "$STOP_DAY" > "$ENV_FILE"
chown root:fieldwiring "$ENV_FILE"; chmod 0640 "$ENV_FILE"
cat > "/etc/systemd/system/$TODAY" <<'UNIT'
[Unit]
Description=MSB Oct18 one-time explicitly authorized Manager digest
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
User=fieldwiring
Group=fieldwiring
WorkingDirectory=/opt/msb-setup/Setup/Application
EnvironmentFile=/etc/msb-setup/setup.env
EnvironmentFile=/etc/msb-setup/manager_mail_2026_bounded.env
Environment=HOME=/var/lib/fieldwiring
Environment=PGPASSFILE=/var/lib/fieldwiring/.pgpass
Environment=PYTHONPATH=/opt/msb-setup/Setup/Application
Environment=MSB_SETUP_MANAGER_SEASON_SEND=APPROVED_OCT_18_TO_SHOW_START_MANAGER_ONLY
Environment=MSB_SETUP_MANAGER_TODAY_SEND=APPROVED_OCT_18_IMMEDIATE_MANAGER_ONLY
Environment=SETUP_NOTIFICATION_SMTP_SEND_ENABLED=1
StateDirectory=msb-setup-manager-mail-pilot
StateDirectoryMode=0700
ExecStart=/opt/fieldwiring/.venv/bin/python /opt/msb-setup-manager-pilot/manager_mail_pilot.py --send-today
NoNewPrivileges=true
PrivateTmp=true
TimeoutStartSec=180
UNIT
cat > "/etc/systemd/system/$SEASON.service" <<'UNIT'
[Unit]
Description=MSB Setup bounded 2026 season Manager digest at 04:00
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
User=fieldwiring
Group=fieldwiring
WorkingDirectory=/opt/msb-setup/Setup/Application
EnvironmentFile=/etc/msb-setup/setup.env
EnvironmentFile=/etc/msb-setup/manager_mail_2026_bounded.env
Environment=HOME=/var/lib/fieldwiring
Environment=PGPASSFILE=/var/lib/fieldwiring/.pgpass
Environment=PYTHONPATH=/opt/msb-setup/Setup/Application
Environment=MSB_SETUP_MANAGER_SEASON_SEND=APPROVED_OCT_18_TO_SHOW_START_MANAGER_ONLY
Environment=SETUP_NOTIFICATION_SMTP_SEND_ENABLED=1
StateDirectory=msb-setup-manager-mail-pilot
StateDirectoryMode=0700
ExecStart=/opt/fieldwiring/.venv/bin/python /opt/msb-setup-manager-pilot/manager_mail_pilot.py --daily
NoNewPrivileges=true
PrivateTmp=true
TimeoutStartSec=180
UNIT
if [[ -n "$OCT" ]]; then
  {
    printf '[Unit]\nDescription=MSB bounded 04:00 Manager email through %s\n\n[Timer]\n' "$STOP_DAY"
    printf 'OnCalendar=%s\n' "$OCT"
    if [[ -n "$NOV" ]]; then printf 'OnCalendar=%s\n' "$NOV"; fi
    printf 'AccuracySec=1s\nPersistent=false\nUnit=msb-setup-manager-season-2026.service\n\n[Install]\nWantedBy=timers.target\n'
  } > "/etc/systemd/system/$SEASON.timer"
fi
chmod 0644 "/etc/systemd/system/$TODAY" "/etc/systemd/system/$SEASON.service"
if [[ -n "$OCT" ]]; then
  chmod 0644 "/etc/systemd/system/$SEASON.timer"
  systemd-analyze verify "/etc/systemd/system/$TODAY" "/etc/systemd/system/$SEASON.service" "/etc/systemd/system/$SEASON.timer"
else
  systemd-analyze verify "/etc/systemd/system/$TODAY" "/etc/systemd/system/$SEASON.service"
fi
systemctl daemon-reload
echo 'Sending October 18 to seven Managers exactly once...'
systemctl start "$TODAY"
test "$(systemctl show "$TODAY" -p Result --value)" = success
sudo -u fieldwiring -H "$PY" - "$LEDGER" <<'PY'
import json,sys
from pathlib import Path
receipts=list(Path(sys.argv[1]).glob("manager-2026-10-18-*.json"))
if len(receipts)!=7: raise SystemExit("STOP: expected seven Oct18 attempt receipts")
for file in receipts:
    row=json.loads(file.read_text(encoding="utf-8"))
    if row.get("date")!="2026-10-18" or row.get("purpose")!="MANAGER_DAILY" or row.get("status")!="SMTP_ACCEPTED_NOT_DELIVERED":
        raise SystemExit("STOP: uncertain SMTP receipt; never retry automatically")
print("OCT18_MAILED_SMTP_ACCEPTED: seven Managers; actual Inbox proof is separate")
PY
if [[ -n "$OCT" ]]; then
  systemctl enable --now "$SEASON.timer"
  test "$(systemctl is-active "$SEASON.timer")" = active
  systemctl show "$SEASON.timer" -p ActiveState -p NextElapseUSecRealtime -p Unit
  systemctl list-timers --all --no-pager "$SEASON.timer"
  echo "BOUNDED_DAILY_TIMER_ACTIVE: 04:00 Chicago through $STOP_DAY"
else
  echo 'NO FUTURE TIMER: operator cutoff is October 18'
fi
