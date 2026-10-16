"""Reuse committed-byte packaging; no new workstation dependency or transport."""
import sys
import setup_88_report_transport as transport

transport.FILES = ('setup_205_estimates_deploy.py', 'setup_maintenance_deploy.py',
                   'setup_required_container_deploy.py', 'check_setup_ui_update_date.py',
                   'setup_205_estimates_release.json')
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
