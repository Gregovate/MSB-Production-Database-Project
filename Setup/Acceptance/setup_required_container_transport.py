"""Use the existing committed-byte Windows/Linux transport for PR389."""
import sys
import setup_88_report_transport as transport
transport.FILES = ('setup_required_container_deploy.py', 'setup_maintenance_deploy.py',
                   'setup_required_container_release.json')
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
