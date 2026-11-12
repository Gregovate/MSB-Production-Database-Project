"""#483 reuses committed-byte transport; no Node or Windows EOL dependency."""
import sys
import setup_88_report_transport as transport
transport.FILES = ('setup_483_source_release.py','setup_305_source_only_deploy.py')
if __name__ == '__main__':
    transport.package(sys.argv[1],sys.argv[2])
