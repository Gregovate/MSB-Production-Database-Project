"""MSB People Manager — Milestone 1 browser application.

Milestone 1 intentionally owns only governed ref.person contact maintenance:
- manager-authorized search/detail;
- duplicate review;
- reserved @sheboyganlights.org email candidates;
- safe create/update;
- active/inactive lifecycle;
- current foreign-key dependency visibility.

It does not create Directus users, create Google Workspace accounts, change
Directus roles/policies, edit directus_user_id/pg_login_name, or delete people.
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Any, Iterator

import psycopg2
from flask import Flask, Response, jsonify, request, send_from_directory
from psycopg2 import Error as PsycopgError
from psycopg2.extras import RealDictCursor

APP_VERSION = "V0.1.1"
BASE_DIR = Path(__file__).resolve().parent
PEOPLE_COMMAND_HEADER = "X-MSB-People-Command"
CLOUDFLARE_EMAIL_HEADER = "Cf-Access-Authenticated-User-Email"
app = Flask(__name__)


class PeopleApiError(RuntimeError):
    def __init__(self, message: str, status: int = 400) -> None:
        super().__init__(message)
        self.status = status


def required_setting(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise PeopleApiError(
            "People Manager is temporarily unavailable because its database connection is not configured.",
            503,
        )
    return value


@contextmanager
def database() -> Iterator[Any]:
    conn = psycopg2.connect(required_setting("PEOPLE_DATABASE_DSN"))
    try:
        yield conn
    finally:
        conn.close()


def cloudflare_operator_email() -> str:
    email = request.headers.get(CLOUDFLARE_EMAIL_HEADER, "").strip().lower()
    if not email:
        raise PeopleApiError("Cloudflare Access identity is required for People Manager.", 401)
    return email


def json_body() -> dict[str, Any]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise PeopleApiError("A JSON object is required.")
    return payload


def require_command_request() -> None:
    """Require the same-origin non-simple request shape for People mutations."""
    if not request.is_json:
        raise PeopleApiError("People command requires an application/json request.", 403)
    if request.headers.get(PEOPLE_COMMAND_HEADER, "") != "1":
        raise PeopleApiError("People command request guard is missing.", 403)


def people_access(email: str) -> dict[str, Any]:
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT email, display_name, role_name, policy_names, can_manage_people
            FROM ref.people_browser_capabilities(%s)
            """,
            (email,),
        )
        row = cur.fetchone()

    if row is None:
        return {
            "authenticated_email": email,
            "known_user": False,
            "display_name": email,
            "role_name": None,
            "policy_names": [],
            "can_manage_people": False,
        }

    item = dict(row)
    return {
        "authenticated_email": email,
        "known_user": True,
        "display_name": item.get("display_name") or email,
        "role_name": item.get("role_name"),
        "policy_names": list(item.get("policy_names") or []),
        "can_manage_people": bool(item.get("can_manage_people")),
    }


def require_people_manager() -> str:
    email = cloudflare_operator_email()
    access = people_access(email)
    if not access["can_manage_people"]:
        raise PeopleApiError("This account is not authorized for People Manager.", 403)
    return email


def duplicate_arguments(payload: dict[str, Any]) -> tuple[Any, ...]:
    return (
        payload.get("first_name"),
        payload.get("last_name"),
        payload.get("email"),
        payload.get("personal_email"),
        payload.get("cell_phone"),
    )


def person_command_payload(payload: dict[str, Any], *, update: bool) -> dict[str, Any]:
    allowed = {
        "first_name",
        "last_name",
        "preferred_name",
        "email",
        "personal_email",
        "cell_phone",
        "active_flag",
        "duplicate_review_ack",
        "email_exception_ack",
    }
    if update:
        allowed.add("expected_updated_at")

    unknown = set(payload) - allowed
    if unknown:
        raise PeopleApiError(f"Unsupported fields: {', '.join(sorted(unknown))}")

    if not str(payload.get("first_name") or "").strip():
        raise PeopleApiError("First name is required.")
    if not str(payload.get("last_name") or "").strip():
        raise PeopleApiError("Last name is required.")
    if update and not payload.get("expected_updated_at"):
        raise PeopleApiError("This record must be reloaded before it can be saved.", 409)

    return payload


def json_row(row: Any) -> dict[str, Any]:
    """Serialize PostgreSQL timestamps without losing optimistic-lock precision."""
    item = dict(row)
    for key, value in item.items():
        if isinstance(value, datetime):
            item[key] = value.isoformat()
    return item


def rows(cur: Any) -> list[dict[str, Any]]:
    return [json_row(row) for row in cur.fetchall()]


@app.get("/")
def index() -> Response:
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/people.css")
def css() -> Response:
    return send_from_directory(BASE_DIR, "people.css")


@app.get("/people.js")
def js() -> Response:
    return send_from_directory(BASE_DIR, "people.js")


@app.get("/static/<path:name>")
def static_asset(name: str) -> Response:
    return send_from_directory(BASE_DIR / "static", name)


@app.get("/api/health")
def health() -> Response:
    with database() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                to_regclass('ref.person') IS NOT NULL,
                to_regprocedure('ref.people_search(text,text,boolean)') IS NOT NULL,
                to_regprocedure('ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)') IS NOT NULL,
                to_regprocedure('ref.update_person_from_people_manager(text,integer,text,text,text,text,text,text,boolean,timestamptz,boolean,boolean)') IS NOT NULL
            """
        )
        person_table, search_fn, create_fn, update_fn = cur.fetchone()
    return jsonify(
        status="ok",
        version=APP_VERSION,
        person_table=bool(person_table),
        search_contract=bool(search_fn),
        create_contract=bool(create_fn),
        update_contract=bool(update_fn),
        delete_exposed=False,
        google_provisioning_exposed=False,
        directus_identity_edit_exposed=False,
    )


@app.get("/api/access")
def api_access() -> Response:
    email = cloudflare_operator_email()
    return jsonify(access=people_access(email))


@app.get("/api/people")
def api_people_search() -> Response:
    email = require_people_manager()
    query = request.args.get("q", "")
    include_inactive = request.args.get("include_inactive", "").lower() in {"1", "true", "yes"}
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_search(%s, %s, %s)",
            (email, query, include_inactive),
        )
        items = rows(cur)
    return jsonify(people=items)


@app.get("/api/people/<int:person_id>")
def api_person_detail(person_id: int) -> Response:
    email = require_people_manager()
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM ref.people_person_detail(%s, %s)", (email, person_id))
        row = cur.fetchone()
    if row is None:
        raise PeopleApiError("Person was not found.", 404)
    return jsonify(person=json_row(row))


@app.get("/api/people/<int:person_id>/dependencies")
def api_person_dependencies(person_id: int) -> Response:
    email = require_people_manager()
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM ref.people_person_dependencies(%s, %s)", (email, person_id))
        items = rows(cur)
    return jsonify(dependencies=items)


@app.post("/api/people/email-candidates")
def api_email_candidates() -> Response:
    require_command_request()
    email = require_people_manager()
    payload = json_body()
    allowed = {"first_name", "last_name", "exclude_person_id"}
    unknown = set(payload) - allowed
    if unknown:
        raise PeopleApiError(f"Unsupported fields: {', '.join(sorted(unknown))}")

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_email_candidates(%s, %s, %s, %s)",
            (
                email,
                payload.get("first_name"),
                payload.get("last_name"),
                payload.get("exclude_person_id"),
            ),
        )
        items = rows(cur)
    return jsonify(candidates=items)


@app.post("/api/people/duplicates")
def api_duplicate_candidates() -> Response:
    require_command_request()
    email = require_people_manager()
    payload = json_body()
    allowed = {
        "first_name",
        "last_name",
        "email",
        "personal_email",
        "cell_phone",
        "exclude_person_id",
    }
    unknown = set(payload) - allowed
    if unknown:
        raise PeopleApiError(f"Unsupported fields: {', '.join(sorted(unknown))}")

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT *
            FROM ref.people_duplicate_candidates(%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                email,
                *duplicate_arguments(payload),
                payload.get("exclude_person_id"),
            ),
        )
        items = rows(cur)
    return jsonify(candidates=items)


@app.post("/api/people")
def api_create_person() -> Response:
    require_command_request()
    email = require_people_manager()
    payload = person_command_payload(json_body(), update=False)

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT * FROM ref.create_person_from_people_manager(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            """,
            (
                email,
                payload.get("first_name"),
                payload.get("last_name"),
                payload.get("preferred_name"),
                payload.get("email"),
                payload.get("personal_email"),
                payload.get("cell_phone"),
                payload.get("active_flag", True),
                bool(payload.get("duplicate_review_ack", False)),
                bool(payload.get("email_exception_ack", False)),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(person=result), 201


@app.patch("/api/people/<int:person_id>")
def api_update_person(person_id: int) -> Response:
    require_command_request()
    email = require_people_manager()
    payload = person_command_payload(json_body(), update=True)

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT * FROM ref.update_person_from_people_manager(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            """,
            (
                email,
                person_id,
                payload.get("first_name"),
                payload.get("last_name"),
                payload.get("preferred_name"),
                payload.get("email"),
                payload.get("personal_email"),
                payload.get("cell_phone"),
                payload.get("active_flag", True),
                payload.get("expected_updated_at"),
                bool(payload.get("duplicate_review_ack", False)),
                bool(payload.get("email_exception_ack", False)),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(person=result)


@app.errorhandler(PeopleApiError)
def people_api_error(exc: PeopleApiError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), exc.status


@app.errorhandler(PsycopgError)
def postgres_error(exc: PsycopgError) -> tuple[Response, int]:
    sqlstate = getattr(exc, "pgcode", None)
    detail = getattr(getattr(exc, "diag", None), "message_primary", None) or str(exc)

    if sqlstate == "42501":
        return jsonify(error="This account is not authorized for that People action.", engineering_error=detail), 403
    if sqlstate == "P0002":
        return jsonify(error=detail or "Person was not found.", engineering_error=detail), 404
    if sqlstate in {"23505", "P0001", "40001"}:
        return jsonify(error=detail or "People record conflicts with current data.", engineering_error=detail), 409
    if sqlstate in {"22023", "23514", "22P02"}:
        return jsonify(error=detail or "People data is invalid.", engineering_error=detail), 400

    return jsonify(
        error="People Manager could not complete the database operation.",
        engineering_error=detail,
    ), 503


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8794")), debug=False)
