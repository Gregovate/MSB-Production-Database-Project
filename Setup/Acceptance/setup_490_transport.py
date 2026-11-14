"""#490 uses the existing exact committed-byte transport, including Windows CRLF handling."""
import sys
import setup_88_report_transport as transport
transport.FILES = ('setup_490_release.py', 'setup_490_release.json',
                   'setup_478_local_calendar_release.py', 'setup_maintenance_deploy.py')
if __name__ == '__main__':
    transport.package(sys.argv[1],sys.argv[2])
