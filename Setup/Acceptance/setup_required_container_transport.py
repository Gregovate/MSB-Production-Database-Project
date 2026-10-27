"""Use the existing committed-byte Windows/Linux transport for PR389."""
import sys
import setup_88_report_transport as transport
manifest = sys.argv[3] if len(sys.argv)>3 else 'setup_required_container_release.json'
if manifest not in ('setup_required_container_release.json','setup_scheduled_search_release.json'):
    raise RuntimeError('Unknown reviewed release manifest')
transport.FILES = ('setup_required_container_deploy.py', 'setup_maintenance_deploy.py', manifest)
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
