"""Pinned Catalog profile of the existing maintenance-controlled source installer."""
import hashlib
import json
from pathlib import Path
import signal
import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import require
from setup_required_container_deploy import ScheduledSearchDeploy


class CatalogScopeDeploy(ScheduledSearchDeploy):
    target = 'e3c39f2781b5a97648dce1f00965110becd2edd6'
    tree = '878fd6161c6cd29886a825070af6193fa04af85a'
    old_setup = '7740498e6602f36c8cdfd384791bbafaab71ee9e'
    old_version = 'V0.3.84-direct-crew-cells'
    version = 'V0.3.87-catalog-scene-refresh-r3'
    profile = 'catalog-scope-source'
    release_tag = 'PR440-Source'

    def preflight(self):
        # Pin the transported established helpers; never patch live infrastructure.
        for name, digest in self.m['helpers'].items():
            actual = hashlib.sha256(Path(__file__).with_name(name).read_bytes().replace(b'\r', b'')).hexdigest()
            require(actual == digest, 'Transported helper differs: ' + name)
        super().preflight()

    def mark(self, stage):
        if stage == 'server deployment PASS; protected scheduled search and documentation closeout pending':
            stage = 'server deployment PASS; protected Catalog and documentation closeout pending'
        super().mark(stage)


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Deployment signal ' + str(signum))
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    orchestrator.Deploy = CatalogScopeDeploy
    raise SystemExit(orchestrator.main())
