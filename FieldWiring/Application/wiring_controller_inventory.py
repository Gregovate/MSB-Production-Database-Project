"""Permanent Controller Inventory context for FieldWiring presentation.

The resolver deliberately starts from the governed Controller-to-Display
relationship. Network / Unit ID is used only to distinguish which already-
assigned physical controller applies to a current LOR row; addressing is never
used as permanent controller identity.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Any

from psycopg2.extras import RealDictCursor

from repository import PostgresRepository, Repository


def _normalized_network(value: Any) -> str:
    return str(value or "").strip().casefold()


def _hex_uid(value: Any) -> int | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return int(text, 16)
    except ValueError:
        return None


def _public_controller(candidate: dict[str, Any]) -> dict[str, Any]:
    return {
        "controller_id": int(candidate["controller_id"]),
        "model_code": candidate.get("model_code"),
        "controller_status_name": candidate.get("controller_status_name"),
    }


def match_row_controllers(
    row: dict[str, Any],
    candidates: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], str | None]:
    """Resolve assigned physical controllers for one current wiring row.

    AC/PIXIE rows may be distinguished by the controller's *current programmed*
    LOR Network + UID range after the Display relationship has established the
    candidate physical assets. Intentional duplicate addresses therefore remain
    legal and may resolve more than one physical controller.

    E1.31/DMX families currently lack a governed universe-to-physical-controller
    partition in Controller Inventory. Their Display relationship can still be
    shown as assignment context, but it must not claim an exact group split.
    """
    if not candidates:
        return [], None

    family = str(row.get("presentation_family") or "").strip().upper()
    if family in {"AC", "PIXIE"}:
        uid = _hex_uid(row.get("controller"))
        network = _normalized_network(row.get("network"))
        if uid is None or not network:
            return [], None

        matched: list[dict[str, Any]] = []
        for candidate in candidates:
            start = candidate.get("lor_uid_start")
            end = candidate.get("lor_uid_end")
            try:
                start_int = int(start) if start is not None else None
                end_int = int(end) if end is not None else None
            except (TypeError, ValueError):
                continue
            if start_int is None or end_int is None:
                continue
            if _normalized_network(candidate.get("lor_network")) != network:
                continue
            if start_int <= uid <= end_int:
                matched.append(_public_controller(candidate))

        matched.sort(key=lambda item: item["controller_id"])
        return matched, "PROGRAMMED_LOR_ADDRESS" if matched else None

    assigned = [_public_controller(candidate) for candidate in candidates]
    assigned.sort(key=lambda item: item["controller_id"])
    return assigned, "DISPLAY_ASSIGNMENT"


def attach_permanent_controller_context(
    repo: Repository,
    rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Attach governed physical Controller context without changing LOR wiring.

    SQLite development snapshots do not currently carry the permanent Controller
    Inventory tables, so that explicit development mode preserves the established
    presentation without Controller cross-links.
    """
    for row in rows:
        row["permanent_controllers"] = []
        row["permanent_controller_basis"] = None

    if not rows or not isinstance(repo, PostgresRepository):
        return rows

    display_ids = sorted({
        int(row["display_id"])
        for row in rows
        if row.get("display_id") is not None
    })
    if not display_ids:
        return rows

    with repo.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                cd.controller_id,
                COALESCE(cd.wiring_source_display_id, cd.display_id) AS wiring_display_id,
                cd.display_id AS physical_display_id,
                m.model_code,
                s.controller_status_name,
                c.lor_network,
                c.lor_uid_start,
                c.lor_uid_end,
                host(c.management_ip) AS management_ip
            FROM ref.controller_display cd
            JOIN ref.controller c
              ON c.controller_id = cd.controller_id
            JOIN ref.controller_model m
              ON m.controller_model_id = c.controller_model_id
            JOIN ref.controller_status s
              ON s.controller_status_id = c.controller_status_id
            WHERE COALESCE(cd.wiring_source_display_id, cd.display_id) = ANY(%s)
            ORDER BY
                COALESCE(cd.wiring_source_display_id, cd.display_id),
                cd.controller_id
            """,
            (display_ids,),
        )
        candidates = [dict(item) for item in cur.fetchall()]

    by_wiring_display: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for candidate in candidates:
        by_wiring_display[int(candidate["wiring_display_id"])].append(candidate)

    for row in rows:
        display_id = row.get("display_id")
        if display_id is None:
            continue
        matched, basis = match_row_controllers(
            row,
            by_wiring_display.get(int(display_id), []),
        )
        row["permanent_controllers"] = matched
        row["permanent_controller_basis"] = basis

    return rows
