"""PR470 uses the existing committed-byte transport; no Scan bundle."""
import sys
import setup_88_report_transport as transport

FILES = ('setup_470_release.py', 'setup_maintenance_deploy.py', 'setup_470_release.json')

def package(repo, bundle):
    previous = transport.FILES
    try:
        transport.FILES = FILES
        transport.package(repo, bundle)
    finally:
        transport.FILES = previous

if __name__ == '__main__':
    package(sys.argv[1], sys.argv[2])
