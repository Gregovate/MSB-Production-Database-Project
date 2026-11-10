#!/usr/bin/env python3
"""PR478 exact-candidate Setup release using the existing #37 maintenance controller.

No independent deployment, backup, or rollback implementation is provided here.
This profile supplies PR478-specific preflight, row invariants and SQL checks to
the established Setup/Acceptance/setup_maintenance_deploy.py orchestrator.
"""
import json
import os
from pathlib import Path
import re
import signal
import tempfile

import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, REPO, SETUP, PYTHON

TARGET = "e1d5c9d9d5ef5a8c59f0381ea559d240aed1c30b"
CANDIDATE = "df5aedd897aa967e1c567dd9d53e40da1712f308"
OLD = "85769c951429cec6faa1ed8ae627501bb8ba028b"
TREE = "277db87d435421f8c45af480ffe341b5eb6837f9"
VERSION = "V0.3.106-local-calendar"
MIGRATION = "Setup/Database/079_fix_setup_local_calendar_boundaries.sql"
MIGRATION_BLOB = "9e0b193a02b88141f91d2804c3af449c709b8412"
VALIDATION = "Setup/Acceptance/setup_122_local_calendar_validation.sql"
SIGNATURES = (
    "ops.reject_past_setup_work_day_insert()",
    "ops.add_historical_setup_work_day(text,integer,date,text)",
    "ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)",
    "ops.correct_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text)",
)


class CalendarRelease(Deploy):
    """Fail-closed exact-profile extension; the parent owns the mutation window."""

    def online(self):
        state = self.controller("status")
        live = state.get("live", {})
        require(state.get("state") == "ONLINE" and not state.get("last_error")
                and live.get("mode") == "real" and live.get("database_fenced") is False,
                "PR478 requires healthy real ONLINE state")
        for unit in ("msb-setup.service", "fieldwiring.service",
                     "msb-procedures.service", "msb-people.service",
                     "lor-preflight-api.service", "msb-work-management.service"):
            require(live.get("services", {}).get(unit) == "active",
                    "Required service unavailable: " + unit)
        require(live.get("services", {}).get("container:msb-directus") == "running",
                "Directus container not healthy")
        backups = live.get("backups", {})
        require(backups.get("nas_mounted") is True
                and backups.get("replication", {}).get("current_run_ok") is True,
                "Production NAS/replication gate failed")

    def source_baseline(self, promoted=False):
        expected = TARGET if promoted else OLD
        require(self.git("rev-parse", "HEAD", root=SETUP) == expected,
                "Live Setup SHA differs; STOP, do not overwrite")
        require(not self.git("status", "--porcelain", root=SETUP),
                "Live Setup checkout dirty")
        require(self.git("rev-parse", "HEAD") == self.m["shared"],
                "Shared checkout drift")
        require(not self.git("status", "--porcelain"),
                "Shared checkout dirty")

    def source_version(self, sha):
        backend = self.git("show", sha + ":Setup/Application/production_backend.py")
        match = re.search(r'^PRODUCTION_VERSION\s*=\s*["\']([^"\']+)["\']', backend, re.M)
        require(match is not None, "Setup source version missing")
        return match.group(1)

    def health(self, version):
        h = json.loads(self.run(["curl", "-fsS", "--max-time", "12",
                                 "http://192.168.5.9:8794/api/health"]))
        require(h.get("status") == "ok" and h.get("data_mode") == "postgres"
                and h.get("version") == version,
                "Live Setup health/version differs from expected source")

    def functions(self):
        quoted = ",".join("('" + sig + "')" for sig in SIGNATURES)
        raw = self.sql("""BEGIN READ ONLY;
            SELECT json_agg(json_build_object(
              'signature', q.signature, 'source_md5', md5(p.prosrc),
              'configuration', p.proconfig, 'owner', p.proowner,
              'acl', p.proacl, 'definer', p.prosecdef,
              'volatility', p.provolatile, 'language', p.prolang)
              ORDER BY q.signature)
            FROM (VALUES """ + quoted + """) AS q(signature)
            LEFT JOIN pg_proc p ON p.oid = to_regprocedure(q.signature);
            ROLLBACK;""").splitlines()
        require(raw and raw[0] and raw[0] != "null", "Function evidence missing")
        rows = json.loads(raw[0])
        require(len(rows) == len(SIGNATURES) and all(r["source_md5"] for r in rows),
                "Missing PR478 function baseline")
        return {row["signature"]: row for row in rows}

    def function_gate(self, installed):
        current = self.functions()
        for signature in SIGNATURES:
            row = current[signature]
            settings = row["configuration"] or []
            has_zone = "TimeZone=America/Chicago" in settings
            require(has_zone is installed,
                    "PR478 timezone migration unexpectedly " +
                    ("missing: " if installed else "already present: ") + signature)
            if installed:
                old = self.original_functions[signature]
                for key in ("source_md5", "owner", "acl", "definer", "volatility", "language"):
                    require(row[key] == old[key], "Function definition/ACL changed: " + signature)
                expected = sorted(set((old["configuration"] or []) +
                                      ["TimeZone=America/Chicago"]))
                require(sorted(settings) == expected,
                        "Function settings changed beyond PR478 timezone: " + signature)

    def preflight(self):
        require(self.m == {
            "profile": "478-local-calendar",
            "release_tag": "PR478-Local-Calendar",
            "candidate": CANDIDATE,
            "target": TARGET,
            "tree": TREE,
            "old_setup": OLD,
            "version": VERSION,
            "migration": MIGRATION,
            "migration_blob": MIGRATION_BLOB,
        }, "Unreviewed PR478 release manifest")
        self.mark("ONLINE PR478 preflight")
        self.online()
        self.m["shared"] = self.git("rev-parse", "HEAD")
        self.journal()
        self.source_baseline()
        self.health(self.source_version(OLD))
        require(not self.run(["ss", "-ltnH", "sport = :8898"]),
                "Setup preview port 8898 remains occupied")
        self.git("fetch", "origin", "+refs/heads/main:refs/remotes/origin/main")
        self.git("merge-base", "--is-ancestor", TARGET, "origin/main")
        self.git("merge-base", "--is-ancestor", OLD, TARGET)
        self.git("merge-base", "--is-ancestor", self.m["shared"], TARGET)
        require(self.git("rev-parse", TARGET + "^{tree}") == TREE,
                "Target merged tree differs")
        require(self.git("rev-parse", TARGET + ":" + MIGRATION) == MIGRATION_BLOB,
                "Reviewed migration content differs")
        for subtree in ("Setup/Application", "Setup/Database"):
            require(self.git("rev-parse", TARGET + ":" + subtree) ==
                    self.git("rev-parse", CANDIDATE + ":" + subtree),
                    "Merged source differs from browser-accepted candidate: " + subtree)
        require(self.source_version(TARGET) == VERSION, "Expected Setup version absent")
        client = self.git("show", TARGET + ":Setup/Application/setup_catalog_dirty_guard.js")
        require("CLIENT_BUILD = '" + VERSION + "'" in client,
                "Expected browser version absent")
        self.original_functions = self.functions()
        self.function_gate(installed=False)
        self.worktree = tempfile.mkdtemp(prefix="msb-478-calendar-", dir="/tmp")
        os.chmod(self.worktree, 0o755)
        self.git("worktree", "add", "--detach", self.worktree, TARGET)
        self.regression(self.worktree)
        self.source_baseline()
        self.online()
        self.function_gate(installed=False)
        self.mark("preflight PASS; Production unchanged")

    def regression(self, path):
        self.run(["sudo", "-u", "fieldwiring", "-H", "env", "PYTHONDONTWRITEBYTECODE=1",
                  "bash", "-c", "cd " + path + " && " + PYTHON +
                  " -m pytest -q -p no:cacheprovider Setup/Application"], timeout=360)

    def capture(self):
        # PR478 only sets function-local TimeZone; ALL business rows must be identical
        # throughout the frozen migration interval. No annual task or audit writes.
        return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format($q$SELECT json_build_object('table',%L,'digest',
             md5(coalesce(string_agg(h,'' ORDER BY h),''))) FROM
             (SELECT md5(to_jsonb(t)::text) AS h FROM %I.%I t) rows;$q$,
             n.nspname||'.'||c.relname,n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p')
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def apply_migrations(self):
        # Invoked only by the existing orchestrator after freeze and validated snapshot.
        self.function_gate(installed=False)
        self.sql(self.git("show", TARGET + ":" + MIGRATION))

    def validate(self):
        self.function_gate(installed=True)
        self.sql(self.git("show", TARGET + ":" + VALIDATION))

    def before_reopen(self, baseline):
        self.frozen(self.controller("status"))
        self.source_baseline(promoted=True)
        require(self.capture() == baseline, "Business rows changed before ONLINE")

    def live_validation(self):
        self.source_baseline(promoted=True)
        self.health(VERSION)
        self.function_gate(installed=True)
        self.regression(SETUP)

    def after_reopen(self):
        snapshot = json.loads((self.root / "snapshot.json").read_text())
        print("PR478 rollback snapshot: " + snapshot["path"], flush=True)
        print("PR478 snapshot SHA256: " + snapshot["sha256"], flush=True)
        print("PR478 live Setup version: " + VERSION, flush=True)


if __name__ == "__main__":
    def interrupted(sig, frame):
        raise KeyboardInterrupt("PR478 deployment interrupted " + str(sig))
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    orchestrator.Deploy = CalendarRelease
    raise SystemExit(orchestrator.main())
