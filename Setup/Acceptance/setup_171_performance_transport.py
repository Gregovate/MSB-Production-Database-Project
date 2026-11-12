"""Use existing committed-byte bundle packaging for the accepted performance release."""
import sys
import setup_88_report_transport as transport

transport.FILES = ('setup_171_performance_release.py', 'setup_maintenance_deploy.py',
                   'setup_171_performance_release.json')
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
