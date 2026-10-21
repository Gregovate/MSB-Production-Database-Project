"""Bounded Oct18 to Nov27 Manager-only mail activation contract; no Production access."""
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
INSTALL=ROOT/"Acceptance"/"manager_mail_pilot"/"activate_manager_mail_oct18_to_opening.sh"


def test_bounded_activation_installer_shell_syntax():
    assert INSTALL.is_file()
    if shutil.which("bash"):
        subprocess.run(["bash","-n",str(INSTALL)],check=True)


def test_bounded_activation_only_one_today_and_year_qualified_future_timer():
    s=INSTALL.read_text(encoding="utf-8")
    assert "msb-setup-manager-2026-today.service" in s
    assert "msb-setup-manager-season-2026" in s
    assert "2026-10-19.." in s
    assert "2026-11-01.." in s
    assert "04:00:00 America/Chicago" in s
    assert "Persistent=false" in s
    assert "ONCalendar=" not in s
    assert "OnCalendar=" in s
    assert "--send-today" in s and "--daily" in s
    assert "2026-11-27" in s
    assert "2026-10-18" in s
    assert "MSB_MANAGER_MAIL_STOP_DATE" in s
    assert "OCT18_MAILED_SMTP_ACCEPTED" in s
    assert "BOUNDED_DAILY_TIMER_ACTIVE" in s
    assert s.index('systemctl start "$TODAY"') < s.index('systemctl enable --now "$SEASON.timer"')
    assert "msb-setup-manager-mail-pilot" in s
    assert "NoNewPrivileges=true" in s
    assert "public.directus_users" not in s
    assert "UPDATE ref.person" not in s
    assert "GRANT " not in s
    # No manually invented/fake labor, Container progress, or duplicate reset.
    assert "DELETE FROM" not in s
    assert "msb-setup.service" in s


def test_finite_timers_explicit_year_and_chicago_dst():
    if not shutil.which("systemd-analyze"):
        return
    for expression, day in [
        ("2026-10-19..31 04:00:00 America/Chicago","2026-10-19 09:00:00 UTC"),
        ("2026-11-01..27 04:00:00 America/Chicago","2026-11-01 10:00:00 UTC"),
    ]:
        out=subprocess.run(["systemd-analyze","calendar",expression],
                           check=True,text=True,capture_output=True).stdout
        assert day in out


def test_approved_roster_is_runtime_supplied_and_limited():
    s=INSTALL.read_text(encoding="utf-8")
    assert "MSB_FIRST_MANAGER_ROSTER" in s
    assert "len(roster)==len(managers)==7" in s
    assert "enforce_approved_manager_audience" in s
    assert "gliebig@sheboyganlights.org" not in s
    assert "dmartens@sheboyganlights.org" not in s
    assert "rmiller@sheboyganlights.org" not in s
