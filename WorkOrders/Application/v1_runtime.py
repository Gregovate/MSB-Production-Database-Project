"""#419 Work Orders V1 native PostgreSQL adapter (source candidate, no deployment).

The existing Work Management browser/app remains the same. Its disposable
implementation still uses CloneCommands. This module describes the guarded
Production extension WITHOUT granting DML to the web role or reusing the
disposable authorization tables. No SMTP/Directus send occurs here.

Activation requires separately reviewed Server Management deployment of:
  WorkOrders/Database/001_work_management_v1_governed_commands.sql
and exact Work Order Manager grants approved by the operator.
"""
from __future__ import annotations

import os
import re
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import Json, RealDictCursor

from repository import WorkManagementError, WorkManagementRepository

SERVICE_ROLE = "work_management_app"
PROD_DB = "msb"
WORK_ORDER_RUNTIME_ENV = "WORK_MGMT_RUNTIME_MODE"
WRITES_APPROVAL_ENV = "WORK_MGMT_V1_WRITE_GATE"
WRITES_APPROVAL = "authorized_v1_release_only"


def require_v1_production_configuration(*, writes: bool = False) -> str:
    """Fail closed without a dedicated DB account and explicit release gate.

    This is a SECOND application gate; database SECURITY DEFINER routines
    independently resolve Manager/Crew capabilities by active Person identity.
    """
    if os.environ.get(WORK_ORDER_RUNTIME_ENV) != "production":
        raise WorkManagementError("Work Orders V1 runtime is not enabled.", 503)
    dsn = os.environ.get("WORK_MGMT_PRODUCTION_DSN", "").strip()
    if not dsn:
        raise WorkManagementError("Work Orders V1 database connection is not configured.", 503)
    if writes and os.environ.get(WRITES_APPROVAL_ENV) != WRITES_APPROVAL:
        raise WorkManagementError(
            "Work Orders V1 write release is not approved; Production state unchanged.", 503
        )
    return dsn


def require_native_database(cur: Any) -> None:
    """Prevent accidental use of the privileged runtime against a disposable DB.

    No credentials are printed. Database role must NOT be a superuser or
    privileged postgres/msbadmin/fieldwiring connection. Runtime checks
    complement dedicated GRANT EXECUTE-only SQL and deployment preflight.
    """
    cur.execute(
        "SELECT current_database() AS db_name,session_user AS login_name,"
        "current_setting('transaction_read_only') AS read_only"
    )
    row = cur.fetchone()
    if (row["db_name"] != PROD_DB or row["login_name"] != SERVICE_ROLE):
        raise WorkManagementError(
            "Work Orders V1 requires the dedicated native database and application role.", 503
        )


class V1Repository(WorkManagementRepository):
    """Existing unified read-model SQL with a governed Production reader."""

    activity_table = "ops.work_management_activity"

    def __init__(self) -> None:
        self.dsn = require_v1_production_configuration()

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=True, autocommit=False)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                require_native_database(cur)
            yield conn
        finally:
            conn.close()

    def access(self, email: str) -> dict:
        """Use the exact active linked Person and dedicated Work Order grant.

        setup_browser_capabilities gates existing read access, but can_manage
        MUST NOT come from a broad Setup/Directus Manager role in V1.
        """
        current = super().access(email)
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT person_id,can_manage FROM ops.work_management_v1_actor(%s)",
                (email,),
            )
            row = cur.fetchone()
        if row is None or int(row["person_id"]) != int(current["person_id"]):
            raise WorkManagementError("Work Order Person permission differs.", 403)
        manager = bool(row["can_manage"])
        current.update(
            email=email.strip().lower(),
            can_manage=manager,
            can_create=manager,
            can_assign=manager,
            can_triage=manager,
        )
        return current


class V1Commands:
    """Production actions through a narrow SQL command, never broad DML."""

    def __init__(self) -> None:
        self.dsn = require_v1_production_configuration()

    def perform(self, actor: dict, action: str, ticket: str | None,
                body: dict) -> dict:
        require_v1_production_configuration(writes=True)
        if not isinstance(body, dict):
            raise WorkManagementError("Work Order command body must be an object.")
        if action not in {
            "create", "promote", "assign", "progress", "complete",
            "correction_owner", "clarify", "reply", "resolve",
        }:
            raise WorkManagementError(
                "This Work Orders V1 operation is not yet approved for release.", 409
            )
        # Seasonal Setup link needs separately reviewed existing Setup security
        # command composition. Never pretend it is covered by V1 core.
        key = str(body.get("request_key", ""))
        if not re.fullmatch(
            r"[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}",
            key.lower(),
        ):
            raise WorkManagementError("Valid idempotent Work Order command key required.")
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=False, autocommit=False)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                require_native_database(cur)
                cur.execute(
                    "SELECT ops.work_management_v1_command(%s,%s,%s,%s,%s::uuid) "
                    "AS outcome",
                    (actor["email"], action, ticket, Json(body), key),
                )
                saved = cur.fetchone()["outcome"]
                if not isinstance(saved, dict) or not saved.get("saved"):
                    raise WorkManagementError("Work Order command did not save.", 503)
            conn.commit()
            return saved
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def activity(self, actor: dict, ticket: str) -> list[dict]:
        require_v1_production_configuration()
        if not re.fullmatch(r"(?:WO|INTAKE)-[1-9][0-9]{0,12}", ticket):
            raise WorkManagementError("Invalid ticket identity.")
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=True, autocommit=False)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                require_native_database(cur)
                cur.execute(
                    "SELECT event_kind,actor_person_id,target_person_id,note,"
                    "details,created_at FROM ops.work_management_v1_activity(%s,%s)",
                    (actor["email"], ticket),
                )
                return [dict(row) for row in cur.fetchall()]
        finally:
            conn.close()
