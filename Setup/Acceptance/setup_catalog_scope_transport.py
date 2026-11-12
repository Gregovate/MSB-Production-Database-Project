"""Reuse committed-byte/LF transport; Windows autocrlf is not an installer delta."""
import sys
import setup_88_report_transport as transport
transport.FILES = ('setup_catalog_scope_deploy.py', 'setup_required_container_deploy.py',
                   'setup_maintenance_deploy.py', 'setup_catalog_scope_release.json')
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
