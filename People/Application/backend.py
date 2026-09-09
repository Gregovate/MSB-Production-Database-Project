"""MSB People Manager — global People and Identity browser application.

The People Manager owns governed contact maintenance plus reusable capability,
qualification, and Setup/Takedown eligibility metadata. It exposes current
Setup Captain/Alternate/Advisor relationships read-only.

It does not create Google Workspace accounts, Directus users, PostgreSQL logins,
or delete/merge person identities.
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from datetime import date, datetime
from pathlib import Path
from typing import Any, Iterator

import psycopg2
from flask import Flask, Response, jsonify, request, send_from_directory
from psycopg2 import Error as PsycopgError
from psycopg2.extras import RealDictCursor

APP_VERSION = "V0.2.0"
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


def json_row(row: Any) -> dict[str, Any]:
    item = dict(row)
    for key, value in item.items():
        if isinstance(value, (datetime, date)):
            item[key] = value.isoformat()
    return item


def rows(cur: Any) -> list[dict[str, Any]]:
    return [json_row(row) for row in cur.fetchall()]


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


def ensure_allowed(payload: dict[str, Any], allowed: set[str]) -> None:
    unknown = set(payload) - allowed
    if unknown:
        raise PeopleApiError(f"Unsupported fields: {', '.join(sorted(unknown))}")


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
                to_regclass('ref.person_capability_type') IS NOT NULL,
                to_regclass('ref.person_qualification_type') IS NOT NULL,
                to_regclass('ref.person_setup_role') IS NOT NULL,
                to_regprocedure('ref.people_search(text,text,boolean)') IS NOT NULL,
                to_regprocedure('ref.people_person_capabilities(text,integer,boolean)') IS NOT NULL,
                to_regprocedure('ref.people_person_qualifications(text,integer,boolean)') IS NOT NULL,
                to_regprocedure('ref.people_person_setup_roles(text,integer)') IS NOT NULL
            """
        )
        (
            person_table,
            capability_table,
            qualification_table,
            setup_role_table,
            search_fn,
            capability_fn,
            qualification_fn,
            setup_role_fn,
        ) = cur.fetchone()
    return jsonify(
        status="ok",
        version=APP_VERSION,
        person_table=bool(person_table),
        capability_contract=bool(capability_table and capability_fn),
        qualification_contract=bool(qualification_table and qualification_fn),
        setup_role_contract=bool(setup_role_table and setup_role_fn),
        search_contract=bool(search_fn),
        delete_exposed=False,
        merge_exposed=False,
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
    ensure_allowed(payload, {"first_name", "last_name", "exclude_person_id"})

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
    ensure_allowed(
        payload,
        {
            "first_name",
            "last_name",
            "email",
            "personal_email",
            "cell_phone",
            "exclude_person_id",
        },
    )

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


@app.get("/api/catalogs/capabilities")
def api_capability_catalog() -> Response:
    email = require_people_manager()
    include_inactive = request.args.get("include_inactive", "").lower() in {"1", "true", "yes"}
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_capability_catalog(%s, %s)",
            (email, include_inactive),
        )
        items = rows(cur)
    return jsonify(capabilities=items)


@app.post("/api/catalogs/capabilities")
def api_upsert_capability_type() -> Response:
    require_command_request()
    email = require_people_manager()
    payload = json_body()
    ensure_allowed(
        payload,
        {
            "person_capability_type_id",
            "capability_name",
            "capability_category",
            "notes",
            "active_flag",
            "sort_order",
        },
    )
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT * FROM ref.upsert_people_capability_type(
                %s, %s, %s, %s, %s, %s, %s
            )
            """,
            (
                email,
                payload.get("person_capability_type_id"),
                payload.get("capability_name"),
                payload.get("capability_category", "OTHER"),
                payload.get("notes"),
                payload.get("active_flag", True),
                payload.get("sort_order", 100),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(capability=result)


@app.get("/api/people/<int:person_id>/capabilities")
def api_person_capabilities(person_id: int) -> Response:
    email = require_people_manager()
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_person_capabilities(%s, %s, true)",
            (email, person_id),
        )
        items = rows(cur)
    return jsonify(capabilities=items)


@app.put("/api/people/<int:person_id>/capabilities/<int:capability_type_id>")
def api_set_person_capability(person_id: int, capability_type_id: int) -> Response:
    require_command_request()
    email = require_people_manager()
    payload = json_body()
    ensure_allowed(payload, {"active_flag", "notes"})
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.set_people_person_capability(%s, %s, %s, %s, %s)",
            (
                email,
                person_id,
                capability_type_id,
                payload.get("active_flag", True),
                payload.get("notes"),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(capability=result)


@app.get("/api/catalogs/qualifications")
def api_qualification_catalog() -> Response:
    email = require_people_manager()
    include_inactive = request.args.get("include_inactive", "").lower() in {"1", "true", "yes"}
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_qualification_catalog(%s, %s)",
            (email, include_inactive),
        )
        items = rows(cur)
    return jsonify(qualifications=items)


@app.post("/api/catalogs/qualifications")
def api_upsert_qualification_type() -> Response:
    require_command_request()
    email = require_people_manager()
    payload = json_body()
    ensure_allowed(
        payload,
        {
            "person_qualification_type_id",
            "qualification_name",
            "notes",
            "active_flag",
            "sort_order",
        },
    )
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT * FROM ref.upsert_people_qualification_type(
                %s, %s, %s, %s, %s, %s
            )
            """,
            (
                email,
                payload.get("person_qualification_type_id"),
                payload.get("qualification_name"),
                payload.get("notes"),
                payload.get("active_flag", True),
                payload.get("sort_order", 100),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(qualification_type=result)


@app.get("/api/people/<int:person_id>/qualifications")
def api_person_qualifications(person_id: int) -> Response:
    email = require_people_manager()
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_person_qualifications(%s, %s, true)",
            (email, person_id),
        )
        items = rows(cur)
    return jsonify(qualifications=items)


def qualification_payload(payload: dict[str, Any]) -> dict[str, Any]:
    ensure_allowed(
        payload,
        {
            "person_qualification_type_id",
            "completed_on",
            "valid_from",
            "expires_on",
            "qualification_role",
            "certificate_number",
            "evidence_reference",
            "active_flag",
            "notes",
        },
    )
    if not payload.get("person_qualification_type_id"):
        raise PeopleApiError("Qualification type is required.")
    return payload


@app.post("/api/people/<int:person_id>/qualifications")
def api_add_person_qualification(person_id: int) -> Response:
    require_command_request()
    email = require_people_manager()
    payload = qualification_payload(json_body())
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT * FROM ref.upsert_people_person_qualification(
                %s, NULL, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            """,
            (
                email,
                person_id,
                payload.get("person_qualification_type_id"),
                payload.get("completed_on"),
                payload.get("valid_from"),
                payload.get("expires_on"),
                payload.get("qualification_role"),
                payload.get("certificate_number"),
                payload.get("evidence_reference"),
                payload.get("active_flag", True),
                payload.get("notes"),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(qualification=result), 201


@app.patch("/api/people/<int:person_id>/qualifications/<int:qualification_id>")
def api_update_person_qualification(person_id: int, qualification_id: int) -> Response:
    require_command_request()
    email = require_people_manager()
    payload = qualification_payload(json_body())
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT * FROM ref.upsert_people_person_qualification(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            """,
            (
                email,
                qualification_id,
                person_id,
                payload.get("person_qualification_type_id"),
                payload.get("completed_on"),
                payload.get("valid_from"),
                payload.get("expires_on"),
                payload.get("qualification_role"),
                payload.get("certificate_number"),
                payload.get("evidence_reference"),
                payload.get("active_flag", True),
                payload.get("notes"),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(qualification=result)


@app.get("/api/people/<int:person_id>/setup-roles")
def api_person_setup_roles(person_id: int) -> Response:
    email = require_people_manager()
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_person_setup_roles(%s, %s)",
            (email, person_id),
        )
        items = rows(cur)
    return jsonify(roles=items)


@app.put("/api/people/<int:person_id>/setup-roles/<string:role_code>")
def api_set_person_setup_role(person_id: int, role_code: str) -> Response:
    require_command_request()
    email = require_people_manager()
    payload = json_body()
    ensure_allowed(payload, {"active_flag", "notes"})
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.set_people_person_setup_role(%s, %s, %s, %s, %s)",
            (
                email,
                person_id,
                role_code,
                payload.get("active_flag", True),
                payload.get("notes"),
            ),
        )
        result = json_row(cur.fetchone())
        conn.commit()
    return jsonify(role=result)


@app.get("/api/people/<int:person_id>/leadership")
def api_person_task_leadership(person_id: int) -> Response:
    email = require_people_manager()
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM ref.people_person_task_leadership(%s, %s)",
            (email, person_id),
        )
        items = rows(cur)
    return jsonify(leadership=items)


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
        return jsonify(error=detail or "People record was not found.", engineering_error=detail), 404
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
