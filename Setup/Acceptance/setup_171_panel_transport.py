"""Use existing committed-byte bundle packaging for the incremental panel release."""
import sys
import setup_88_report_transport as transport

transport.FILES = ('setup_171_panel_release.py', 'setup_maintenance_deploy.py',
                   'setup_171_panel_release.json')
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
