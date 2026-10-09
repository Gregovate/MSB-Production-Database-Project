#!/usr/bin/env python3
"""Issue #205 Migration 072 only: governed, fail-closed Production deployment.

Run on the Production host as msbadmin AFTER explicit release approval.
No Setup source promotion, no PR293 runner reuse, no auto-recovery on failure.
"""
import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
from datetime import datetime, timezone

CONTROL = ["sudo", "python3", "/opt/msb-maintenance/msb_maintenance_controller.py",
           "--config", "/etc/msb-maintenance/config.json"]
PSQL = ["sudo", "docker", "exec", "-i", "msb-postgres", "psql",
        "-X", "-v", "ON_ERROR_STOP=1", "-U", "msbadmin", "-d", "msb"]
EXPECTED_LIVE = "86a025a2528be9f7071355965f679320a1362181"
APPROVED_CANDIDATE = "e0058d94abe337a8095923c08a0b9432c73e80bd"


def call(args, data=None):
    result = subprocess.run(args, input=data, text=True, capture_output=True, timeout=300)
    if result.returncode:
        raise RuntimeError(f"STOP: {args[0]} failed: {result.stdout} {result.stderr}")
    return result.stdout.strip()


def controller(action, *args):
    result = json.loads(call(CONTROL + [action, *args]))
    if result.get("ok") is False or result.get("last_error"):
        raise RuntimeError("STOP: Maintenance controller error: " + str(result))
    return result


def frozen(state):
    if state.get("state") != "MAINTENANCE" or not state.get("gates", {}).get("freeze_proof", {}).get("ok"):
        raise RuntimeError("STOP: Maintenance freeze not proven")
    if state.get("live", {}).get("database_fenced") is not True:
        raise RuntimeError("STOP: Database writer fence not proven")


def sql(query):
    return call(PSQL, query)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--migration", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--accepted-release", default="")
    args = parser.parse_args()
    migration = Path(args.migration)
    data = migration.read_bytes()
    if hashlib.sha256(data).hexdigest() != args.sha256:
        raise RuntimeError("STOP: Migration bytes differ from approved SHA-256")
    if args.candidate != APPROVED_CANDIDATE:
        raise RuntimeError("STOP: Candidate mismatch")
    if args.execute and args.accepted_release != "MIGRATION-072-APPROVED":
        raise RuntimeError("STOP: Explicit accepted release marker required for Production mutation")
    if not data.startswith(b"-- #205 / #122: durable annual-task schedule lifecycle evidence."):
        raise RuntimeError("STOP: Unexpected migration content")

    with (Path.home() / ".msb-production-deploy.lock").open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        old = call(["sudo", "git", "-C", "/opt/msb-setup", "rev-parse", "HEAD"])
        if old != EXPECTED_LIVE:
            raise RuntimeError(f"STOP: Live Setup SHA drift: {old}")
        if call(["sudo", "git", "-C", "/opt/msb-setup", "status", "--porcelain"]):
            raise RuntimeError("STOP: Live Setup worktree dirty")
        health = json.loads(call(["curl", "-fsS", "http://192.168.5.9:8794/api/health"]))
        if health.get("status") != "ok" or health.get("data_mode") != "postgres":
            raise RuntimeError("STOP: Setup health failed")
        state = controller("status")
        if state.get("state") != "ONLINE" or state.get("live", {}).get("database_fenced") is not False:
            raise RuntimeError("STOP: Controller not healthy ONLINE")
        existing = sql("SELECT (to_regprocedure('ops.audit_setup_assignment_lifecycle()') IS NOT NULL)::text;")
        if existing != "f":
            raise RuntimeError("STOP: Migration 072 already present or partially applied")
        if not args.execute:
            print("PASS: 072 read-only deployment preflight. No maintenance entered.")
            return

        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        root = Path.home() / "setup-deployment-reports" / ("PR320-072-" + stamp)
        root.mkdir(parents=True, exist_ok=False)
        (root / "migration.sha256").write_text(args.sha256 + "\n")
        stage = "before-maintenance"
        try:
            stage = "maintenance-entering"
            frozen(controller("on"))
            stage = "frozen"
            # Authoritative backup must be taken only after the controller fence.
            archive = "/home/msbadmin/backups/setup-205/msb-pre-pr320-072-" + stamp + ".dump"
            snapshot = controller("snapshot", archive).get("snapshot", {})
            if not (snapshot.get("validated") is True and snapshot.get("ok") is True
                    and snapshot.get("sha256") and snapshot.get("bytes", 0) > 0):
                raise RuntimeError("STOP: Validated rollback snapshot missing")
            (root / "snapshot.json").write_text(json.dumps(snapshot, indent=2))
            frozen(controller("status"))
            stage = "migration-started"
            sql(data.decode("utf-8"))
            stage = "migration-committed"
            frozen(controller("status"))
            sql("""DO $$ BEGIN
              IF to_regprocedure('ops.audit_setup_assignment_lifecycle()') IS NULL
                 OR to_regclass('ops.preview_setup_schedule_churn_v1') IS NULL
              THEN RAISE EXCEPTION '072 objects missing'; END IF;
              IF (SELECT count(*) FROM pg_trigger
                  WHERE tgrelid='ops.setup_work_day_task'::regclass
                    AND tgname IN ('trg_setup_assignment_lifecycle_insert',
                                   'trg_setup_assignment_lifecycle_delete')
                    AND tgenabled IN ('O','A')) <> 2
              THEN RAISE EXCEPTION '072 triggers missing'; END IF;
              IF has_table_privilege('fieldwiring_app','ops.setup_schedule_event','INSERT')
                 OR has_table_privilege('fieldwiring_app','ops.setup_schedule_event','UPDATE')
                 OR has_table_privilege('fieldwiring_app','ops.setup_schedule_event','DELETE')
              THEN RAISE EXCEPTION 'Schedule event ACL broadened'; END IF;
            END $$;""")
            stage = "validation-pass"
            online = controller("off")
            if online.get("state") != "ONLINE" or online.get("gates", {}).get("online_proof", {}).get("ok") is not True:
                raise RuntimeError("STOP: Return-to-service proof failed")
            stage = "online"
            if call(["sudo", "git", "-C", "/opt/msb-setup", "rev-parse", "HEAD"]) != old:
                raise RuntimeError("STOP: Live Setup SHA changed")
            print("PASS: Migration 072 installed; controller ONLINE; report:", root)
        except BaseException:
            # Deliberately leave MAINTENANCE in place for reviewed recovery.
            raise
        finally:
            (root / "last-stage.txt").write_text(stage + "\n")


if __name__ == "__main__":
    main()
