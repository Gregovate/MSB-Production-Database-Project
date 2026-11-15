"""PR492 uses the existing committed-byte transport, including Windows CRLF handling."""
import sys
import setup_88_report_transport as transport
transport.FILES = ('setup_492_release.py', 'setup_88_report_source_only_deploy.py')
if __name__ == '__main__':
    transport.package(sys.argv[1], sys.argv[2])
