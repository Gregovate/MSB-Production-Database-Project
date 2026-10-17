#!/usr/bin/env bash
# #205 under #122. Controlled FIRST-SEND one-day, Manager-only activation.
# Authority: MSB-Server-Management/docs/server/Setup_205_One_Day_Manager_Mail_Pilot_2026-10-17.md
# Invoked as sudo bash THIS_SCRIPT <exact-commit-sha> <detached-worktree-root>.
set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then
  echo "STOP: root admin install required"; exit 2
fi
if [[ "$#" -ne 2 ]]; then
  echo "STOP: exact source commit and detached worktree are required"; exit 2
fi
SOURCE_SHA="$1"
SOURCE_ROOT="$2"
PILOT_DIR="$SOURCE_ROOT/Setup/Acceptance/manager_mail_pilot"
INSTALL_DIR=/opt/msb-setup-manager-pilot
UNIT=msb-setup-manager-one-day-live
SERVICE_UNIT="/etc/systemd/system/${UNIT}.service"
TIMER_UNIT="/etc/systemd/system/${UNIT}.timer"
APPROVAL=/etc/msb-setup/manager_pilot_2026_10_17.approved
ROSTER_ENV=/etc/msb-setup/manager_pilot_2026_10_17.env
LEDGER=/var/lib/msb-setup-manager-mail-pilot
APP_DB_ROOT=/opt/msb-setup/Setup/Application
PY=/opt/fieldwiring/.venv/bin/python
EXPECTED_ROSTER="rhoffmann@sheboyganlights.org,gliebig@sheboyganlights.org,dmartens@sheboyganlights.org,rmiller@sheboyganlights.org,rneerhof@sheboyganlights.org,esandvig@sheboyganlights.org,tshircel@sheboyganlights.org"

echo "Authority: MSB Server Management #205 one-day Manager mail runbook"
echo "Action: schedule the first 04:00 Central 2026-10-17 Manager-only run"
local_time="$(TZ=America/Chicago date '+%Y%m%d%H%M')"
if [[ "$local_time" < "202610170000" || "$local_time" >= "202610170400" ]]; then
  echo "STOP: not before the October 17 04:00 Chicago trigger"
  exit 2
fi
if ! [[ "$SOURCE_SHA" =~ ^[[:xdigit:]]{40}$ ]]; then
  echo "STOP: exact 40-digit source SHA required"; exit 2
fi
if [[ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" != "$SOURCE_SHA" ]]; then
  echo "STOP: candidate SHA differs"; exit 2
fi
if [[ -n "$(git -C "$SOURCE_ROOT" status --porcelain)" ]]; then
  echo "STOP: candidate worktree not clean"; exit 2
fi
if [[ "$(git -C "$SOURCE_ROOT" rev-parse --show-toplevel)" != "$SOURCE_ROOT" ]]; then
  echo "STOP: unexpected detached source location"; exit 2
fi
for p in manager_mail_pilot.py manager_digest_subject.txt manager_digest_template.txt manager_digest_html.html; do
  test -f "$PILOT_DIR/$p" || { echo "STOP: missing source asset $p"; exit 2; }
done
if [[ -e "$SERVICE_UNIT" || -e "$TIMER_UNIT" || -e "$APPROVAL" || -e "$ROSTER_ENV" ]]; then
  echo "STOP: first-send service, timer or approval file already exists"
  exit 2
fi
test -d "$LEDGER" || { echo "STOP: protected previous-attempt ledger missing"; exit 2; }
test "$(stat -c '%U' "$LEDGER")" = "fieldwiring" || {
  echo "STOP: protected ledger owner differs"; exit 2;
}
test -f /var/lib/fieldwiring/.pgpass || { echo "STOP: accepted password source absent"; exit 2; }
test "$(systemctl is-active msb-setup.service)" = "active" || {
  echo "STOP: Setup service not healthy"; exit 2;
}
curl -fsS --max-time 5 http://192.168.5.9:8794/api/health >/dev/null || {
  echo "STOP: Setup health endpoint unavailable"; exit 2;
}
calendar="$(systemd-analyze calendar '2026-10-17 04:00:00 America/Chicago' 2>&1)"
echo "$calendar"
if [[ "$calendar" != *"Sat 2026-10-17 09:00:00 UTC"* ]]; then
  echo "STOP: unexpected systemd calendar conversion"; exit 2
fi
echo "Checking current 2026 database, all 7 active eligible contacts and live report without sending..."
sudo -u fieldwiring -H env \
  HOME=/var/lib/fieldwiring \
  PGPASSFILE=/var/lib/fieldwiring/.pgpass \
  SETUP_DATABASE_DSN="host=127.0.0.1" \
  MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER="$EXPECTED_ROSTER" \
  PYTHONPATH="$APP_DB_ROOT" \
  "$PY" - "$PILOT_DIR/manager_mail_pilot.py" <<'PY'
import importlib.util
import sys
from pathlib import Path
from setup_scheduling_board_repository import SetupSchedulingBoardRepository
p = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("msb_mail_activation_check", p)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
dsn = module.accepted_setup_dsn()
rows = module.manager_directory(dsn)
eligible = [r for r in rows if r["send_eligible"]]
module.enforce_approved_manager_audience(eligible, rows)
assert len(rows) == len(eligible) == 7, "Expected precisely seven live Managers"
board = SetupSchedulingBoardRepository(dsn).board(2026)
summary = module.summarize(board,module.chicago_now().date())
summary.update(module.container_summary(dsn,2026))
assert summary["total_tasks"] > 0 and summary["containers_total"] > 0
print("PASS: exact active seven-recipient roster:")
for r in rows:
    print("  ",r["display_name"],"<"+r["email"]+">",r.get("onboarding_note") or "")
print("READ-ONLY: Total",summary["total_tasks"],"Completed",summary["completed_tasks"],
      "Remaining",summary["remaining_tasks"],"Containers",summary["containers_total"])
print("NO SEND during preflight.")
PY

# No service/timer files or source checkout updates before every gate above passed.
install -d -o root -g root -m 0755 "$INSTALL_DIR"
for p in manager_mail_pilot.py manager_digest_subject.txt manager_digest_template.txt manager_digest_html.html; do
  install -o root -g root -m 0644 "$PILOT_DIR/$p" "$INSTALL_DIR/$p"
  cmp -s "$PILOT_DIR/$p" "$INSTALL_DIR/$p" || { echo "STOP: asset checksum mismatch"; exit 2; }
done
test -d /etc/msb-setup || { echo "STOP: existing Setup config directory missing"; exit 2; }
printf '%s\n' "MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER=$EXPECTED_ROSTER" > "$ROSTER_ENV"
chown root:fieldwiring "$ROSTER_ENV"
chmod 0640 "$ROSTER_ENV"

cat > "$SERVICE_UNIT" <<'UNIT'
[Unit]
Description=MSB #205 first Manager-only Setup Morning Brief (2026-10-17 04:00 Chicago)
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/msb-setup/manager_pilot_2026_10_17.approved

[Service]
Type=oneshot
User=fieldwiring
Group=fieldwiring
WorkingDirectory=/opt/msb-setup/Setup/Application
EnvironmentFile=/etc/msb-setup/setup.env
EnvironmentFile=/etc/msb-setup/manager_pilot_2026_10_17.env
Environment=HOME=/var/lib/fieldwiring
Environment=PGPASSFILE=/var/lib/fieldwiring/.pgpass
Environment=PYTHONPATH=/opt/msb-setup/Setup/Application
Environment=MSB_SETUP_MANAGER_PILOT_SEND=APPROVED_OCT_17_MANAGER_ONLY
Environment=SETUP_NOTIFICATION_SMTP_SEND_ENABLED=1
StateDirectory=msb-setup-manager-mail-pilot
StateDirectoryMode=0700
ExecStart=/opt/fieldwiring/.venv/bin/python /opt/msb-setup-manager-pilot/manager_mail_pilot.py --live
NoNewPrivileges=true
PrivateTmp=true
TimeoutStartSec=900
UNIT

cat > "$TIMER_UNIT" <<'UNIT'
[Unit]
Description=MSB #205 first Manager-only digest: 2026-10-17 04:00 Chicago

[Timer]
OnCalendar=2026-10-17 04:00:00 America/Chicago
AccuracySec=1s
Persistent=false
Unit=msb-setup-manager-one-day-live.service

[Install]
WantedBy=timers.target
UNIT

chmod 0644 "$SERVICE_UNIT" "$TIMER_UNIT"
systemd-analyze verify "$SERVICE_UNIT" "$TIMER_UNIT"
install -o root -g root -m 0600 /dev/null "$APPROVAL"
systemctl daemon-reload
systemctl enable --now "$UNIT.timer"
echo "--- Confirm only future run, not delivered yet ---"
systemctl show "$UNIT.timer" -p ActiveState -p NextElapseUSecRealtime -p Unit
systemctl list-timers --all "$UNIT.timer" --no-pager
test "$(systemctl is-active "$UNIT.timer")" = "active"
echo "SUCCESS: 04:00 Chicago first Manager-only timer ACTIVATED; no Captain emails."
