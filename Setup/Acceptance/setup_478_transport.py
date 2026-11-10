"""PR478 packages the exact committed release profile with existing transport."""
import sys
import setup_88_report_transport as transport

transport.FILES = (
    "setup_478_local_calendar_release.py",
    "setup_maintenance_deploy.py",
    "setup_478_local_calendar_release.json",
)

if __name__ == "__main__":
    transport.package(sys.argv[1], sys.argv[2])
