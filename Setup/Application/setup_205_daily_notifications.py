"""#205 daily Setup notification producer. NOT installed as a scheduler.

Read-only counts by default. Only governed server-side timer with separately
enabled SETUP_NOTIFICATION_DAILY_ENABLED=1 may run --queue. Running this from a
workstation does not configure Directus Flows or an active 04:00 job.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from setup_api import setup_database_dsn
from setup_notification_service import SetupNotificationError, daily_dispatch


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Plan or enqueue Setup Manager/Captain daily notifications")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true", help="read-only summary; never send")
    mode.add_argument("--queue", action="store_true", help="requires explicitly enabled guarded Directus outbox")
    args = parser.parse_args(argv)
    try:
        outcome = daily_dispatch(setup_database_dsn(),dry_run=args.dry_run)
    except SetupNotificationError as exc:
        print(json.dumps({"status":"STOP","reason":str(exc)}))
        return 2
    # Never put recipient names, addresses, tokens or message bodies in logs.
    if outcome.get("errors"):
        result = {k:v for k,v in outcome.items() if k!="errors"}
        result["error_count"] = len(outcome["errors"])
        print(json.dumps(result))
        return 3
    print(json.dumps(outcome))
    return 0


if __name__ == "__main__":
    sys.exit(main())
