"""Reuse committed-byte packaging; no new workstation dependency or transport."""
import sys
import setup_88_report_transport as transport

transport.FILES = ('setup_171_release.py', 'setup_maintenance_deploy.py',
                   'site_171_source_install.py',
                   'setup_171_release.json')
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
