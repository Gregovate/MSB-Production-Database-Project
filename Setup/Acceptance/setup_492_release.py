#!/usr/bin/env python3
"""PR492 source-only profile of the established Setup report installer.

The accepted application remains pinned independently of tooling commits. No
migration, maintenance-controller entry, SMTP, timer or recipient changes.
"""
from datetime import datetime, timezone
import fcntl
import hashlib
import json
from pathlib import Path
import signal
import sys
import time

import setup_88_report_source_only_deploy as source
from setup_88_report_source_only_deploy import require

CANDIDATE = '6a8cee60b96e28c62776c9668e9ca569c8ade81a'
OLD = 'aba4a5a4aacd54a648d8d2770743b757d28d4d86'
VERSION = 'V0.3.125-management-qc-hours'
MAIL_ROOT = '/opt/msb-setup-manager-pilot'
MAIL_FILES = ('manager_mail_pilot.py', 'manager_digest_template.txt', 'manager_digest_html.html')
MAIL_SERVICE = 'msb-setup-manager-season-2026.service'
source.TARGET = CANDIDATE
source.EXPECTED_OLD = OLD
source.OLD_VERSION = 'V0.3.124-qc-unscheduled'
source.VERSION = VERSION
source.FOCUSED += ['Setup/Application/test_management_metrics.py',
                   'Setup/Application/test_205_manager_mail_pilot.py',
                   'Setup/Application/test_205_manager_mail_admin_preview.py']


class Release(source.Installer):
    def __init__(self):
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        self.root = Path('/home/msbadmin/setup-deployment-reports') / ('PR492-source-' + stamp)
        self.root.mkdir(parents=True)
        self.log = (self.root / 'report.txt').open('w', buffering=1)
        self.candidate = '/tmp/' + self.root.name
        self.advanced = self.worktree_created = self.mail_advanced = False
        self.before = None
        self.mail_before = {}

    def fingerprint(self):
        original = super().fingerprint()
        tables = ('setup_task_progress', 'setup_work_day_task', 'setup_work_day_crew',
                  'setup_qc_finding', 'setup_qc_event', 'setup_qc_auditor',
                  'setup_qc_signoff', 'setup_qc_signoff_history', 'setup_qc_correction',
                  'setup_qc_season_exception', 'setup_qc_intake_link')
        queries = ["SELECT '" + table + "' name,coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) v FROM ops." + table + " t"
                   for table in tables]
        sql = "BEGIN READ ONLY; SELECT md5(string_agg(v::text,'' ORDER BY name)) FROM (" + ' UNION ALL '.join(queries) + ") q; ROLLBACK;"
        extra = self.run(['sudo', 'docker', 'exec', '-i', 'msb-postgres', 'psql',
                          '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'msbadmin', '-d', 'msb'], input=sql)
        require(len(extra) == 32 and all(c in '0123456789abcdef' for c in extra), 'Invalid QC/labor fingerprint')
        return hashlib.sha256((original + extra).encode()).hexdigest()

    def mail_hashes(self):
        return {name: self.run(['sudo', 'sha256sum', MAIL_ROOT + '/' + name]).split()[0]
                for name in MAIL_FILES}

    def mail_idle(self, remaining_seconds=3600):
        require(self.run(['systemctl', 'show', MAIL_SERVICE, '--property=ActiveState', '--value'])
                == 'inactive', 'Manager sender is running or failed; inspect before release')
        timer = MAIL_SERVICE.replace('.service', '.timer')
        if self.run(['systemctl', 'show', timer, '--property=ActiveState', '--value']) == 'active':
            due = self.run(['systemctl', 'show', timer, '--property=NextElapseUSecRealtime', '--value'])
            require(bool(due), 'Manager timer next execution unknown')
            epoch = int(self.run(['date', '--date=' + due, '+%s']))
            require(epoch-time.time() > remaining_seconds, 'Manager send due within one hour; use another window')

    def mail_preflight(self):
        self.mail_idle()
        self.mail_before = self.mail_hashes()
        for name, digest in self.mail_before.items():
            expected = self.git('show', OLD + ':Setup/Acceptance/manager_mail_pilot/' + name) + '\n'
            require(hashlib.sha256(expected.encode()).hexdigest() == digest,
                    'Installed manager source drift: ' + name)
        # Preserve delivery receipts. Do not run the sender, even in preview mode.
        self.ledger_before = self.run(['sudo', 'find', '/var/lib/msb-setup-manager-mail-pilot',
                                      '-type', 'f', '-exec', 'sha256sum', '{}', '+'])
        (self.root / 'mail-before.json').write_text(json.dumps(self.mail_before, indent=2) + '\n')

    def install_mail(self):
        self.mail_idle(300)
        require(self.mail_hashes() == self.mail_before, 'Manager files changed during preflight')
        backup = self.root / 'manager-mail-before'
        backup.mkdir()
        for name in MAIL_FILES:
            self.run(['sudo', 'cp', '-a', MAIL_ROOT + '/' + name, str(backup / name)])
        # Set recovery intent before the first file replacement, including partial failure.
        self.mail_advanced = True
        for name in MAIL_FILES:
            temporary = MAIL_ROOT + '/' + name + '.pr492-new'
            self.run(['sudo', 'test', '!', '-e', temporary])
            self.run(['sudo', 'install', '-o', 'root', '-g', 'root', '-m', '0644',
                      source.LIVE + '/Setup/Acceptance/manager_mail_pilot/' + name, temporary])
            self.run(['sudo', 'mv', '--', temporary, MAIL_ROOT + '/' + name])
        self.mail_validate()
        print('STAGE PR492 manager report source installed; no email sent', flush=True)

    def mail_validate(self):
        for name in MAIL_FILES:
            self.run(['sudo', 'cmp', '--', source.LIVE + '/Setup/Acceptance/manager_mail_pilot/' + name,
                      MAIL_ROOT + '/' + name])
        ledger = self.run(['sudo', 'find', '/var/lib/msb-setup-manager-mail-pilot',
                           '-type', 'f', '-exec', 'sha256sum', '{}', '+'])
        require(sorted(ledger.splitlines()) == sorted(self.ledger_before.splitlines()),
                'Manager delivery receipts changed; inspect retained report')

    def health(self, version):
        super().health(version)
        if version == VERSION and not self.mail_advanced:
            self.install_mail()

    def report_read_probe(self):
        # This profile validates the management reads; the parent probe pins an
        # older movement-report query shape unrelated to the accepted change.
        # Existing columns/authorized snapshot, exercised with the runtime role.
        # Return only aggregate counts; never log finding text or credentials.
        self.run(['sudo', 'docker', 'exec', '-i', 'msb-postgres', 'psql',
                  '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'msbadmin', '-d', 'msb'], input="""
BEGIN READ ONLY;
SET LOCAL ROLE fieldwiring_app;
SELECT count(*),sum(st.annual_normal_crew_min*st.annual_expected_duration_minutes),
       sum(p.minutes),sum(p.missing)
FROM ops.setup_session_task st JOIN ops.setup_session s USING(setup_session_id)
LEFT JOIN LATERAL (SELECT sum(crew_count*duration_minutes) minutes,
 count(*) FILTER (WHERE crew_count IS NULL OR duration_minutes IS NULL) missing
 FROM ops.setup_task_progress p WHERE p.setup_session_task_id=st.setup_session_task_id) p ON true
WHERE s.season_year=2026 AND st.included_flag AND NOT st.qc_check_flag;
SELECT jsonb_array_length(q->'signoffs'),jsonb_array_length(q->'final_gates')
FROM (SELECT ops.setup_qc_snapshot('gliebig@sheboyganlights.org',2026) q) snapshot;
ROLLBACK;
""")

    def rollback(self):
        # Restore installed sender/templates even if only the first replacement succeeded.
        if self.mail_advanced:
            self.mail_idle(0)
            for name in MAIL_FILES:
                self.run(['sudo', 'cp', '-a', str(self.root / 'manager-mail-before' / name),
                          MAIL_ROOT + '/' + name])
                self.run(['sudo', 'rm', '-f', '--', MAIL_ROOT + '/' + name + '.pr492-new'])
            require(self.mail_hashes() == self.mail_before, 'Manager source rollback differs')
            self.mail_advanced = False
        super().rollback()

    def deploy(self):
        # Capture and preserve the clean shared checkout, never promote/reset it.
        source.SHARED = self.git('rev-parse', 'HEAD')
        require(len(source.SHARED) == 40, 'Invalid shared checkout identity')
        self.mail_preflight()
        print('STAGE PR492 source-only preflight; Production unchanged', flush=True)
        super().deploy()
        self.mail_validate()
        print('STAGE PR492 server deployment PASS; protected browser closeout pending', flush=True)


def main():
    signal.signal(signal.SIGTERM, source.interrupted)
    signal.signal(signal.SIGINT, source.interrupted)
    with open('/home/msbadmin/.msb-production-deploy.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        release = Release()
        status = 0
        try:
            release.deploy()
        except Exception as exc:
            release.log.write('STOP ' + repr(exc) + '\n')
            status = 1
            try:
                release.rollback()
            except Exception as recovery:
                release.log.write('ROLLBACK FAILED ' + repr(recovery) + '\n')
        finally:
            try:
                release.cleanup()
            except Exception as exc:
                release.log.write('CLEANUP FAILED ' + repr(exc) + '\n')
                status = 1
            release.log.close()
        print(('STOP: inspect retained report; do not retry' if status else
               'PASS: PR492 source and morning report installed; no email sent; protected live check pending')
              + '; report: ' + str(release.root), flush=True)
        return status


if __name__ == '__main__':
    sys.exit(main())
