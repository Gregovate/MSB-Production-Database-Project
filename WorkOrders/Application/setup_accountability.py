"""Read-only #122 Intake/Work Order → eligible wiring/verify Setup-step candidates.

An Intake's Stage is a scope hint, NEVER evidence of a particular task,
Captain, crew, original installer or cause. No arbitrary Setup tasks are shown:
only the existing annual PLUG IN & VERIFY: Wire ... step qualifies.

This module is deliberately independent of server/UI for unit testing.
"""
from __future__ import annotations

import re
from typing import Any

WIRING_VERIFY_PREFIX = re.compile(r"^PLUG IN\s*&\s*VERIFY\s*:\s*Wire\b", re.I)
YEAR = 2026


def eligible_wiring_task(name: Any) -> bool:
    return isinstance(name, str) and WIRING_VERIFY_PREFIX.search(name.strip()) is not None


def safe_identity(value: Any) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        result = int(value)
    except (ValueError, TypeError, OverflowError):
        return None
    return result if result > 0 else None


def stage_scope(ticket: dict[str, Any]) -> tuple[int | None, str | None]:
    detail = ticket.get("detail") or {}
    ctx = ticket.get("setup_context") or {}
    stage_id = safe_identity(ctx.get("stage_id")) or safe_identity(detail.get("stage_id"))
    raw = detail.get("stage_raw") or ctx.get("stage_name")
    raw = raw.strip() if isinstance(raw, str) else None
    return stage_id, (raw or None)


def fetch_wiring_candidates(cur: Any, ticket: dict[str, Any]) -> dict[str, Any]:
    stage_id, stage_name = stage_scope(ticket)
    if stage_id is None and not stage_name:
        return {"scope": "NO_STAGE", "candidates": [],
                "notice": "Only the request location is known; no Stage identity is available."}

    # An exact Stage identifier is authoritative. Free-form Stage text is
    # matched to a single real Stage by exact label, never by fuzzy matching.
    if stage_id is None:
        cur.execute("""
            SELECT stage_id, stage_name
            FROM ref.stage
            WHERE lower(btrim(stage_name)) = lower(btrim(%s))
            ORDER BY stage_id LIMIT 2
        """, (stage_name,))
        stages = [dict(x) for x in cur.fetchall()]
        if len(stages) != 1:
            return {"scope": "AMBIGUOUS_STAGE" if stages else "UNRESOLVED_STAGE",
                    "candidates": [], "notice": "Stage needs Manager confirmation."}
        stage_id = safe_identity(stages[0]["stage_id"])

    cur.execute("""
        SELECT st.setup_session_task_id, st.setup_task_id,
               st.annual_task_name AS task_name, st.execution_status,
               s.stage_id, s.stage_name, ss.season_year
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss ON ss.setup_session_id=st.setup_session_id
        JOIN ref.stage s ON s.stage_id=st.annual_stage_id
        WHERE ss.season_year=%s AND st.included_flag
          AND st.annual_stage_id=%s
          AND st.annual_task_name ~* '^PLUG IN[[:space:]]*&[[:space:]]*VERIFY[[:space:]]*:[[:space:]]*Wire[[:space:]]'
        ORDER BY st.annual_task_name, st.setup_session_task_id
        LIMIT 20
    """, (YEAR, stage_id))
    rows = [dict(row) for row in cur.fetchall()]
    # Defense in depth: only exact family allowed; no "Plug in Network" or
    # generic installation/setup/repair task can leak into linking choices.
    rows = [row for row in rows if eligible_wiring_task(row.get("task_name"))]
    return {
        "scope": "STAGE_WIRING_CANDIDATES",
        "stage_id": stage_id,
        "candidates": [
            dict(row, relationship="CANDIDATE_NOT_LINKED", original_worker="NOT_ESTABLISHED")
            for row in rows
        ],
        "notice": ("Select the exact wiring/verify step; a Stage match alone does "
                   "not establish who worked on it or who caused a defect.")
    }
