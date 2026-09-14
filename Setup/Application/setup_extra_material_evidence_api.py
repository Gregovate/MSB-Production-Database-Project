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
    """Return normalized procedure findings before final task/step assignment.

    Procedure/folder context already supplies authoritative Stage identity. These
    rows remain evidence/reconciliation context until a Manager accepts specific
    task, Kit, source, or expected-content relationships.
    """
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    e.setup_extra_material_evidence_source_id,
                    e.source_batch,
                    e.stage_id,
                    e.stage_key,
                    s.stage_name,
                    e.source_file,
                    e.source_pages,
                    e.material_families,
                    e.material_keys,
                    e.family_page_index,
                    e.legacy_container_refs,
                    e.current_id_refs,
                    e.noncurrent_or_legacy_refs,
                    e.proposed_current_source_container_ids,
                    e.current_stage_kit_candidate_ids,
                    e.suggested_setup_task_ids,
                    e.source_mapping_statuses,
                    e.task_mapping_statuses,
                    e.requirement_preload_states,
                    e.catalog_dispositions,
                    e.catalog_statuses,
                    e.verification_needed,
                    e.usage_restrictions
                FROM ref.setup_extra_material_evidence_source e
                JOIN ref.stage s ON s.stage_id = e.stage_id
                ORDER BY s.park_order, s.sub_order, e.source_file
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
