"""Read-only Controller capacity planning against current LOR/V7 and physical inventory."""
from __future__ import annotations

from typing import Any

from psycopg2.extras import RealDictCursor

from repository import PostgresRepository, Repository


class ControllerPlanningError(RuntimeError):
    """Raised when Controller planning data cannot be resolved safely."""


UID_MIN = 1
UID_MAX = 240


def _postgres(repo: Repository) -> PostgresRepository:
    if not isinstance(repo, PostgresRepository):
        raise ControllerPlanningError(
            "Controller planning requires the production PostgreSQL data source"
        )
    return repo


def _uid_hex(value: int) -> str:
    return format(int(value), "02X")


def _free_ranges(occupied: set[int], block_size: int) -> list[dict[str, Any]]:
    """Return contiguous LOR UID gaps and non-overlapping model-sized candidates."""
    if block_size < 1 or block_size > UID_MAX:
        raise ControllerPlanningError("Requested UID block size is outside 1..240")

    ranges: list[dict[str, Any]] = []
    start: int | None = None
    for uid in range(UID_MIN, UID_MAX + 2):
        free = uid <= UID_MAX and uid not in occupied
        if free and start is None:
            start = uid
            continue
        if free:
            continue
        if start is None:
            continue

        end = uid - 1
        length = end - start + 1
        candidates: list[dict[str, Any]] = []
        candidate_start = start
        while candidate_start + block_size - 1 <= end:
            candidate_end = candidate_start + block_size - 1
            candidates.append(
                {
                    "uid_start": candidate_start,
                    "uid_end": candidate_end,
                    "uid_range": (
                        _uid_hex(candidate_start)
                        if candidate_start == candidate_end
                        else f"{_uid_hex(candidate_start)}-{_uid_hex(candidate_end)}"
                    ),
                }
            )
            candidate_start = candidate_end + 1

        ranges.append(
            {
                "uid_start": start,
                "uid_end": end,
                "uid_range": (
                    _uid_hex(start) if start == end else f"{_uid_hex(start)}-{_uid_hex(end)}"
                ),
                "length": length,
                "fits_required_block": length >= block_size,
                "candidate_blocks": candidates,
            }
        )
        start = None
    return ranges


def controller_planning_networks(repo: Repository) -> dict[str, Any]:
    """List current LOR networks plus physical-programming-only networks."""
    pg = _postgres(repo)
    with pg.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT DISTINCT btrim(fw.network) AS network
            FROM lor_snap.preview_wiring_fieldlead_v6 AS fw
            WHERE nullif(btrim(fw.network), '') IS NOT NULL
            ORDER BY btrim(fw.network)
            """
        )
        lor_networks = {row["network"] for row in cur.fetchall()}

        cur.execute(
            """
            SELECT DISTINCT btrim(c.lor_network) AS network
            FROM ref.controller AS c
            WHERE nullif(btrim(c.lor_network), '') IS NOT NULL
            ORDER BY btrim(c.lor_network)
            """
        )
        controller_networks = {row["network"] for row in cur.fetchall()}

    networks = []
    for network in sorted(lor_networks | controller_networks, key=str.casefold):
        networks.append(
            {
                "network": network,
                "used_by_current_lor": network in lor_networks,
                "present_in_controller_programming": network in controller_networks,
            }
        )
    return {"networks": networks}


def controller_network_uid_plan(
    repo: Repository,
    *,
    network: str,
    controller_model_id: int | None = None,
) -> dict[str, Any]:
    """Resolve current LOR UID usage and model-aware contiguous free blocks.

    LOR/V7 usage answers what the current approved show consumes. Controller
    Inventory programming is overlaid separately and never changes whether a
    UID is considered occupied by the current show.
    """
    pg = _postgres(repo)
    network = network.strip()
    if not network:
        raise ControllerPlanningError("LOR Network is required")

    model: dict[str, Any] | None = None
    block_size = 1

    with pg.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        if controller_model_id is not None:
            cur.execute(
                """
                SELECT
                    controller_model_id,
                    model_code,
                    manufacturer,
                    model_name,
                    device_family,
                    lor_uid_capacity,
                    coalesce(lor_uid_requires_full_capacity, false)
                        AS lor_uid_requires_full_capacity
                FROM ref.controller_model
                WHERE controller_model_id = %s
                """,
                (controller_model_id,),
            )
            row = cur.fetchone()
            if row is None:
                raise ControllerPlanningError(
                    f"Controller model {controller_model_id} was not found"
                )
            model = dict(row)
            if model.get("lor_uid_capacity") is not None:
                # Planning defaults to the full physical model capacity. This is
                # exact for full-capacity models and conservative for models
                # whose stored value is a maximum.
                block_size = int(model["lor_uid_capacity"])

        cur.execute(
            """
            SELECT
                fw.preview_name,
                btrim(fw.network) AS network,
                upper(btrim(fw.controller)) AS controller,
                fw.start_channel,
                fw.end_channel,
                fw.display_name,
                fw.channel_name,
                fw.device_type
            FROM lor_snap.preview_wiring_fieldlead_v6 AS fw
            WHERE lower(btrim(fw.network)) = lower(%s)
              AND btrim(fw.controller) ~* '^[0-9a-f]{1,2}$'
            ORDER BY
                CASE
                    WHEN btrim(fw.controller) ~* '^[0-9a-f]+$'
                    THEN ('x' || btrim(fw.controller))::bit(32)::int
                    ELSE NULL
                END,
                fw.start_channel,
                fw.display_name
            """,
            (network,),
        )
        lor_rows = [dict(row) for row in cur.fetchall()]

        cur.execute(
            """
            SELECT
                c.controller_id,
                c.controller_model_id,
                m.model_code,
                m.model_name,
                s.controller_status_name,
                btrim(c.lor_network) AS lor_network,
                c.lor_uid_start,
                c.lor_uid_count,
                c.lor_uid_end,
                c.current_location_code,
                count(cd.display_id) AS assignment_count,
                string_agg(d.display_name, ', ' ORDER BY d.display_name)
                    AS display_names
            FROM ref.controller AS c
            JOIN ref.controller_model AS m
              ON m.controller_model_id = c.controller_model_id
            JOIN ref.controller_status AS s
              ON s.controller_status_id = c.controller_status_id
            LEFT JOIN ref.controller_display AS cd
              ON cd.controller_id = c.controller_id
            LEFT JOIN ref.display AS d
              ON d.display_id = cd.display_id
            WHERE lower(btrim(c.lor_network)) = lower(%s)
              AND c.lor_uid_start IS NOT NULL
              AND c.lor_uid_end IS NOT NULL
            GROUP BY
                c.controller_id,
                m.controller_model_id,
                s.controller_status_id
            ORDER BY c.controller_id
            """,
            (network,),
        )
        physical = [dict(row) for row in cur.fetchall()]

        available_stock: list[dict[str, Any]] = []
        if controller_model_id is not None:
            cur.execute(
                """
                SELECT
                    c.controller_id,
                    m.model_code,
                    s.controller_status_name,
                    c.current_location_code,
                    c.lor_network,
                    c.lor_uid_start,
                    c.lor_uid_count,
                    c.lor_uid_end,
                    host(c.management_ip) AS management_ip,
                    c.programmed_config_verification_state
                FROM ref.controller AS c
                JOIN ref.controller_model AS m
                  ON m.controller_model_id = c.controller_model_id
                JOIN ref.controller_status AS s
                  ON s.controller_status_id = c.controller_status_id
                WHERE c.controller_model_id = %s
                  AND s.controller_status_name = 'AVAILABLE'
                  AND NOT EXISTS (
                      SELECT 1
                      FROM ref.controller_display AS cd
                      WHERE cd.controller_id = c.controller_id
                  )
                ORDER BY c.controller_id
                """,
                (controller_model_id,),
            )
            available_stock = [dict(row) for row in cur.fetchall()]

    usage: dict[int, dict[str, Any]] = {}
    for row in lor_rows:
        try:
            uid = int(str(row["controller"]).strip(), 16)
        except (TypeError, ValueError):
            continue
        if uid < UID_MIN or uid > UID_MAX:
            continue
        item = usage.setdefault(
            uid,
            {
                "uid": uid,
                "uid_hex": _uid_hex(uid),
                "previews": set(),
                "displays": set(),
                "channels": set(),
                "device_types": set(),
            },
        )
        if row.get("preview_name"):
            item["previews"].add(str(row["preview_name"]))
        if row.get("display_name"):
            item["displays"].add(str(row["display_name"]))
        if row.get("device_type"):
            item["device_types"].add(str(row["device_type"]))
        start_channel = row.get("start_channel")
        end_channel = row.get("end_channel")
        channel_name = row.get("channel_name")
        item["channels"].add(
            f"{start_channel}-{end_channel}" if end_channel not in (None, start_channel)
            else str(start_channel if start_channel is not None else channel_name or "")
        )

    occupied = set(usage)
    physical_by_uid: dict[int, list[dict[str, Any]]] = {}
    for controller in physical:
        start = int(controller["lor_uid_start"])
        end = int(controller["lor_uid_end"])
        for uid in range(max(UID_MIN, start), min(UID_MAX, end) + 1):
            physical_by_uid.setdefault(uid, []).append(controller)

    uid_rows: list[dict[str, Any]] = []
    for uid in range(UID_MIN, UID_MAX + 1):
        lor = usage.get(uid)
        controllers = physical_by_uid.get(uid, [])
        if lor is None and not controllers:
            continue
        uid_rows.append(
            {
                "uid": uid,
                "uid_hex": _uid_hex(uid),
                "lor_state": "USED" if lor else "UNUSED_BY_LOR",
                "lor_shared": bool(lor and len(lor["displays"]) > 1),
                "previews": sorted(lor["previews"]) if lor else [],
                "displays": sorted(lor["displays"]) if lor else [],
                "channels": sorted(lor["channels"]) if lor else [],
                "device_types": sorted(lor["device_types"]) if lor else [],
                "physical_controllers": [
                    {
                        "controller_id": item["controller_id"],
                        "model_code": item["model_code"],
                        "status": item["controller_status_name"],
                        "uid_range": (
                            _uid_hex(item["lor_uid_start"])
                            if item["lor_uid_start"] == item["lor_uid_end"]
                            else f"{_uid_hex(item['lor_uid_start'])}-{_uid_hex(item['lor_uid_end'])}"
                        ),
                        "assignment_count": item["assignment_count"],
                        "display_names": item["display_names"],
                        "location": item["current_location_code"],
                    }
                    for item in controllers
                ],
            }
        )

    return {
        "network": network,
        "model": model,
        "required_uid_count": block_size,
        "required_uid_basis": "model_capacity" if model else "single_uid",
        "occupied_uid_count": len(occupied),
        "free_uid_count": UID_MAX - len(occupied),
        "free_ranges": _free_ranges(occupied, block_size),
        "uid_usage": uid_rows,
        "available_controllers": available_stock,
        "rules": {
            "lor_usage_authority": "current approved LOR/V7",
            "physical_programming_authority": "ref.controller",
            "duplicate_network_uid_allowed": True,
            "uid_min_hex": "01",
            "uid_max_hex": "F0",
        },
    }
