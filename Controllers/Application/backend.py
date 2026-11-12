"""MSB Controller Inventory bootstrap review application.

Initial scope:
- Review/edit stage.controller_bootstrap evidence.
- Resolve permanent ref.display relationships.
- Review/override first-known year_deployed.
- Mark candidates READY only when blockers are clear.
- Prepare/review the proposed 1001+ order in stage.*.

This application intentionally does NOT promote rows into ref.controller.
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import psycopg2
from flask import Flask, Response, jsonify, request, send_from_directory
from psycopg2.extras import RealDictCursor

APP_VERSION = "V0.1.0"
BASE_DIR = Path(__file__).resolve().parent
app = Flask(__name__)


class ApiError(RuntimeError):
    def __init__(self, message: str, status: int = 400) -> None:
        super().__init__(message)
        self.status = status


def required_setting(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required setting {name} is missing")
    return value


@contextmanager
def database() -> Iterator[Any]:
    conn = psycopg2.connect(required_setting("CONTROLLER_DATABASE_DSN"))
    try:
        yield conn
    finally:
        conn.close()


def operator_email() -> str:
    """Require the Access identity for mutation endpoints when configured."""
    allowed_raw = os.environ.get("CONTROLLER_OPERATORS", "").strip()
    if not allowed_raw:
        # Engineering/local mode only. Production deployment must configure
        # CONTROLLER_OPERATORS behind the authenticated reverse proxy.
        return "engineering-local"

    email = request.headers.get(
        "Cf-Access-Authenticated-User-Email", ""
    ).strip().lower()
    if not email:
        raise ApiError("Controller operator identity is missing", 401)

    allowed = {
        item.strip().lower() for item in allowed_raw.split(",") if item.strip()
    }
    if email not in allowed:
        raise ApiError("This account is not authorized for Controller Inventory", 403)
    return email


def fetch_candidate(cur: Any, candidate_id: int) -> dict[str, Any]:
    cur.execute(
        """
        SELECT *
        FROM stage.v_controller_bootstrap_review
        WHERE controller_bootstrap_id = %s
        """,
        (candidate_id,),
    )
    row = cur.fetchone()
    if row is None:
        raise ApiError("Controller bootstrap candidate was not found", 404)
    return dict(row)


def body_json() -> dict[str, Any]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise ApiError("A JSON object is required")
    return payload


@app.get("/")
def index() -> Response:
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/controller.css")
def css() -> Response:
    return send_from_directory(BASE_DIR, "controller.css")


@app.get("/controller.js")
def js() -> Response:
    return send_from_directory(BASE_DIR, "controller.js")


@app.get("/api/health")
def health() -> Response:
    with database() as conn, conn.cursor() as cur:
        cur.execute("SELECT to_regclass('stage.controller_bootstrap'), to_regclass('ref.controller')")
        stage_table, controller_table = cur.fetchone()
    return jsonify(
        status="ok",
        version=APP_VERSION,
        stage_bootstrap=stage_table is not None,
        ref_controller=controller_table is not None,
        permanent_promotion_exposed=False,
    )


@app.get("/api/bootstrap")
def bootstrap_list() -> Response:
    state = request.args.get("state", "").strip().upper()
    q = request.args.get("q", "").strip()
    parameters: list[Any] = []
    where: list[str] = []

    if state:
        if state not in {"REVIEW_REQUIRED", "READY", "SKIPPED"}:
            raise ApiError("Invalid bootstrap state")
        where.append("review_state = %s")
        parameters.append(state)

    if q:
        where.append(
            "(display_name_evidence ILIKE %s OR model_evidence ILIKE %s "
            "OR network_evidence ILIKE %s OR uid_evidence ILIKE %s "
            "OR for_what_evidence ILIKE %s)"
        )
        token = f"%{q}%"
        parameters.extend([token, token, token, token, token])

    sql = "SELECT * FROM stage.v_controller_bootstrap_review"
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY source_row_num"

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, parameters)
        rows = [dict(row) for row in cur.fetchall()]
        cur.execute(
            """
            SELECT
                count(*) AS total,
                count(*) FILTER (WHERE review_state='REVIEW_REQUIRED') AS review_required,
                count(*) FILTER (WHERE review_state='READY') AS ready,
                count(*) FILTER (WHERE review_state='SKIPPED') AS skipped,
                count(*) FILTER (WHERE bootstrap_order IS NOT NULL) AS ordered
            FROM stage.controller_bootstrap
            """
        )
        summary = dict(cur.fetchone())

    return jsonify(summary=summary, candidates=rows)


@app.get("/api/bootstrap/<int:candidate_id>")
def bootstrap_detail(candidate_id: int) -> Response:
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        candidate = fetch_candidate(cur, candidate_id)
        cur.execute(
            """
            SELECT
                bd.relationship_type,
                bd.display_id,
                d.display_name,
                d.year_built,
                bd.relationship_note
            FROM stage.controller_bootstrap_display AS bd
            JOIN ref.display AS d ON d.display_id = bd.display_id
            WHERE bd.controller_bootstrap_id = %s
            ORDER BY bd.relationship_type, d.display_name
            """,
            (candidate_id,),
        )
        relationships = [dict(row) for row in cur.fetchall()]
    return jsonify(candidate=candidate, relationships=relationships)


@app.get("/api/displays")
def displays() -> Response:
    q = request.args.get("q", "").strip()
    if len(q) < 2:
        return jsonify(displays=[])
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT display_id, display_name, year_built, stage_id
            FROM ref.display
            WHERE display_name ILIKE %s
            ORDER BY display_name
            LIMIT 50
            """,
            (f"%{q}%",),
        )
        rows = [dict(row) for row in cur.fetchall()]
    return jsonify(displays=rows)


@app.get("/api/models")
def models() -> Response:
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT controller_model_id, model_code, manufacturer, model_name,
                   device_family
            FROM ref.controller_model
            ORDER BY model_code
            """
        )
        rows = [dict(row) for row in cur.fetchall()]
    return jsonify(models=rows)


@app.patch("/api/bootstrap/<int:candidate_id>")
def update_bootstrap(candidate_id: int) -> Response:
    operator_email()
    payload = body_json()

    allowed_keys = {
        "controller_model_id",
        "year_deployed",
        "review_state",
        "review_notes",
    }
    unknown = set(payload) - allowed_keys
    if unknown:
        raise ApiError(f"Unsupported fields: {', '.join(sorted(unknown))}")

    requested_state = payload.get("review_state")
    if requested_state is not None:
        requested_state = str(requested_state).upper()
        if requested_state not in {"REVIEW_REQUIRED", "READY", "SKIPPED"}:
            raise ApiError("Invalid review_state")

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        current = fetch_candidate(cur, candidate_id)

        model_id = payload.get("controller_model_id", current.get("controller_model_id"))
        year = payload.get("year_deployed", current.get("year_deployed"))
        notes = payload.get("review_notes", current.get("review_notes"))
        state = requested_state or current.get("review_state")

        if model_id is not None:
            try:
                model_id = int(model_id)
            except (TypeError, ValueError) as exc:
                raise ApiError("controller_model_id must be an integer") from exc
            cur.execute(
                "SELECT 1 FROM ref.controller_model WHERE controller_model_id=%s",
                (model_id,),
            )
            if cur.fetchone() is None:
                raise ApiError("Controller model was not found", 404)

        if year in ("", None):
            year = None
        else:
            try:
                year = int(year)
            except (TypeError, ValueError) as exc:
                raise ApiError("year_deployed must be an integer") from exc
            if year < 1980 or year > 2100:
                raise ApiError("year_deployed is outside the accepted range")

        if state == "SKIPPED" and not str(notes or "").strip():
            raise ApiError("SKIPPED requires a review note")

        cur.execute(
            """
            UPDATE stage.controller_bootstrap
            SET controller_model_id = %s,
                year_deployed = %s,
                year_deployed_source = CASE
                    WHEN %s IS DISTINCT FROM year_deployed
                        THEN 'OPERATOR_REVIEW'
                    ELSE year_deployed_source
                END,
                review_notes = %s,
                review_state = %s,
                bootstrap_order = NULL
            WHERE controller_bootstrap_id = %s
            """,
            (model_id, year, year, notes, state, candidate_id),
        )

        candidate = fetch_candidate(cur, candidate_id)
        if state == "READY" and candidate.get("blockers"):
            raise ApiError(
                "Candidate cannot be READY while blockers remain: "
                + ", ".join(candidate["blockers"]),
                409,
            )

        conn.commit()
    return jsonify(candidate=candidate)


@app.post("/api/bootstrap/<int:candidate_id>/displays")
def add_display(candidate_id: int) -> Response:
    operator_email()
    payload = body_json()
    try:
        display_id = int(payload.get("display_id"))
    except (TypeError, ValueError) as exc:
        raise ApiError("display_id is required") from exc
    relationship_type = str(payload.get("relationship_type", "SERVES")).upper()
    if relationship_type not in {"SERVES", "WIRING_SOURCE"}:
        raise ApiError("Invalid relationship_type")

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        fetch_candidate(cur, candidate_id)
        cur.execute("SELECT 1 FROM ref.display WHERE display_id=%s", (display_id,))
        if cur.fetchone() is None:
            raise ApiError("Display was not found", 404)

        if relationship_type == "WIRING_SOURCE":
            cur.execute(
                """
                SELECT count(*)
                FROM stage.controller_bootstrap_display
                WHERE controller_bootstrap_id=%s
                  AND relationship_type='WIRING_SOURCE'
                  AND display_id<>%s
                """,
                (candidate_id, display_id),
            )
            if cur.fetchone()[0] > 0:
                raise ApiError("Only one reviewed WIRING_SOURCE is allowed", 409)

        cur.execute(
            """
            INSERT INTO stage.controller_bootstrap_display (
                controller_bootstrap_id, display_id, relationship_type,
                relationship_note
            ) VALUES (%s, %s, %s, %s)
            ON CONFLICT (controller_bootstrap_id, display_id, relationship_type)
            DO UPDATE SET relationship_note = EXCLUDED.relationship_note
            """,
            (
                candidate_id,
                display_id,
                relationship_type,
                payload.get("relationship_note"),
            ),
        )

        cur.execute(
            """
            UPDATE stage.controller_bootstrap
            SET review_state='REVIEW_REQUIRED', bootstrap_order=NULL
            WHERE controller_bootstrap_id=%s
            """,
            (candidate_id,),
        )

        # Fill year only if it was not already reviewed/set.
        cur.execute(
            """
            WITH y AS (
                SELECT min(d.year_built) AS first_year
                FROM stage.controller_bootstrap_display AS bd
                JOIN ref.display AS d ON d.display_id=bd.display_id
                WHERE bd.controller_bootstrap_id=%s
                  AND bd.relationship_type='SERVES'
                  AND d.year_built IS NOT NULL
            )
            UPDATE stage.controller_bootstrap
            SET year_deployed=y.first_year,
                year_deployed_source='EARLIEST_ASSIGNED_DISPLAY_YEAR_BUILT'
            FROM y
            WHERE controller_bootstrap_id=%s
              AND year_deployed IS NULL
              AND y.first_year IS NOT NULL
            """,
            (candidate_id, candidate_id),
        )
        conn.commit()
        candidate = fetch_candidate(cur, candidate_id)
    return jsonify(candidate=candidate)


@app.delete("/api/bootstrap/<int:candidate_id>/displays/<int:display_id>")
def remove_display(candidate_id: int, display_id: int) -> Response:
    operator_email()
    relationship_type = request.args.get("type", "SERVES").strip().upper()
    if relationship_type not in {"SERVES", "WIRING_SOURCE"}:
        raise ApiError("Invalid relationship type")

    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        fetch_candidate(cur, candidate_id)
        cur.execute(
            """
            DELETE FROM stage.controller_bootstrap_display
            WHERE controller_bootstrap_id=%s
              AND display_id=%s
              AND relationship_type=%s
            """,
            (candidate_id, display_id, relationship_type),
        )
        cur.execute(
            """
            UPDATE stage.controller_bootstrap
            SET review_state='REVIEW_REQUIRED', bootstrap_order=NULL
            WHERE controller_bootstrap_id=%s
            """,
            (candidate_id,),
        )
        conn.commit()
        candidate = fetch_candidate(cur, candidate_id)
    return jsonify(candidate=candidate)


@app.post("/api/bootstrap/prepare-order")
def prepare_order() -> Response:
    operator_email()
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT stage.prepare_controller_bootstrap_order() AS ordered")
        ordered = cur.fetchone()["ordered"]
        conn.commit()
    return jsonify(ordered=ordered, first_proposed_id=1001, last_proposed_id=1000 + ordered)


@app.get("/api/bootstrap/order")
def order_preview() -> Response:
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                bootstrap_order,
                proposed_controller_id,
                year_deployed,
                network_evidence,
                uid_evidence,
                display_name_evidence,
                model_evidence,
                firmware_evidence,
                firmware_state_evidence,
                for_what_evidence,
                source_row_num
            FROM stage.controller_bootstrap
            WHERE review_state='READY'
            ORDER BY bootstrap_order NULLS LAST,
                     year_deployed,
                     lower(coalesce(network_evidence,'')),
                     lower(coalesce(uid_evidence,'')),
                     source_row_num
            """
        )
        rows = [dict(row) for row in cur.fetchall()]
    return jsonify(order=rows)


@app.get("/api/controllers")
def controllers() -> Response:
    with database() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                c.controller_id,
                m.model_code,
                s.controller_status_name,
                c.year_deployed,
                fv.firmware_version,
                c.current_location_code,
                c.verification_state,
                c.label_required,
                c.print_label,
                c.label_template_id,
                count(cd.display_id) AS display_count
            FROM ref.controller AS c
            JOIN ref.controller_model AS m
              ON m.controller_model_id=c.controller_model_id
            JOIN ref.controller_status AS s
              ON s.controller_status_id=c.controller_status_id
            LEFT JOIN ref.controller_firmware_version AS fv
              ON fv.controller_firmware_version_id=c.installed_firmware_version_id
            LEFT JOIN ref.controller_display AS cd
              ON cd.controller_id=c.controller_id
            GROUP BY c.controller_id, m.model_code, s.controller_status_name,
                     c.year_deployed, fv.firmware_version,
                     c.current_location_code, c.verification_state,
                     c.label_required, c.print_label, c.label_template_id
            ORDER BY c.controller_id
            """
        )
        rows = [dict(row) for row in cur.fetchall()]
    return jsonify(controllers=rows)


@app.errorhandler(ApiError)
def api_error(exc: ApiError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), exc.status


@app.errorhandler(RuntimeError)
def config_error(exc: RuntimeError) -> tuple[Response, int]:
    return jsonify(error="Controller Inventory application is not configured", detail=str(exc)), 503


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8792")), debug=False)
