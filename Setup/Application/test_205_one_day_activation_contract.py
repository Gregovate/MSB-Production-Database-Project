"""#205 one-time server activation contract: no network/DB or systemd needed."""
from pathlib import Path
import shutil
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / "Acceptance" / "manager_mail_pilot" / "install_first_manager_4am_20261017.sh"


def test_one_day_installer_syntax_and_no_directus_privilege_change():
    source = INSTALL.read_text(encoding="utf-8")
    if shutil.which("bash"):
        subprocess.run(["bash", "-n", str(INSTALL)], check=True)
    assert "202610170400" in source
    assert 'SETUP_DATABASE_DSN="host=127.0.0.1"' in source
    assert "PGPASSFILE=/var/lib/fieldwiring/.pgpass" in source
    assert "msb-setup-manager-one-day-live" in source
    assert "Persistent=false" in source
    assert "OnCalendar=2026-10-17 04:00:00 America/Chicago" in source
    assert "StateDirectory=msb-setup-manager-mail-pilot" in source
    assert "MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER" in source
    assert "enforce_approved_manager_audience" in source
    assert "NoNewPrivileges=true" in source
    assert "PRIVATE" not in source
    assert "public.directus_users" not in source
    assert "GRANT " not in source
    assert "UPDATE ref.person" not in source
    assert "Captain" not in source.replace("no Captain emails", "")
    assert "systemctl enable --now" in source
    assert "systemctl is-active" in source


def test_authorized_first_seven_and_no_eighth_person():
    content = INSTALL.read_text(encoding="utf-8")
    line=next(x for x in content.splitlines() if x.startswith("EXPECTED_ROSTER="))
    roster = line.split("=", 1)[1].strip('"').split(",")
    assert len(roster) == 7 and len(set(roster)) == 7
    assert set(roster) == {
        "rhoffmann@sheboyganlights.org",
        "gliebig@sheboyganlights.org",
        "dmartens@sheboyganlights.org",
        "rmiller@sheboyganlights.org",
        "rneerhof@sheboyganlights.org",
        "esandvig@sheboyganlights.org",
        "tshircel@sheboyganlights.org",
    }
