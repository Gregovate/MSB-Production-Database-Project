"""Protected read-only API for Setup Extra Material evidence discovery."""
from __future__ import annotations

from contextlib import closing

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Blueprint, Response, jsonify

from setup_api import SetupAuthenticationError, require_reader, setup_database_dsn
from setup_repository import SetupRepositoryError

setup_extra_material_evidence_api = Blueprint("setup_extra_material_evidence_api", __name__)


@setup_extra_material_evidence_api.get("/api/setup/extra-material-evidence/sources")
def api_setup_extra_material_evidence_sources() -> Response:
    """Return normalized procedure/spreadsheet findings before final assignment.

    These rows are evidence/reconciliation context, not accepted Setup truth. One
    source document may point at several candidate Containers and reusable tasks.
    """
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    setup_extra_material_evidence_source_id,
                    source_batch,
                    stage_key,
                    source_file,
                    source_pages,
                    material_families,
                    material_keys,
                    family_page_index,
                    legacy_container_refs,
                    current_id_refs,
                    noncurrent_or_legacy_refs,
                    proposed_current_source_container_ids,
                    current_stage_kit_candidate_ids,
                    suggested_setup_task_ids,
                    source_mapping_statuses,
                    task_mapping_statuses,
                    requirement_preload_states,
                    catalog_dispositions,
                    catalog_statuses,
                    verification_needed,
                    usage_restrictions
                FROM ref.setup_extra_material_evidence_source
                ORDER BY
                    CASE WHEN stage_key ~ '^[0-9]+$' THEN stage_key::integer ELSE 999 END,
                    stage_key,
                    source_file
                """
            )
            rows = [dict(row) for row in cur.fetchall()]
    return jsonify(sources=rows)


@setup_extra_material_evidence_api.errorhandler(SetupAuthenticationError)
def authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_extra_material_evidence_api.errorhandler(SetupRepositoryError)
def repository_error(exc: SetupRepositoryError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Extra Material evidence is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_extra_material_evidence_api.errorhandler(psycopg2.Error)
def database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    message = (exc.diag.message_primary or "Setup Extra Material evidence query failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), 500
