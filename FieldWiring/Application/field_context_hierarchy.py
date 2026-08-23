"""Validated field-facing Stage/Sub-stage/Scene browse contract.

This module is the conservative public wrapper over ``field_context_browse``.
The lower-level builder resolves actual marked filesystem roots and deduplicates
raw LOR Scene evidence by resolved scope.  This wrapper adds the final top-level
Stage binding gate required by the released Google Drive hierarchy contract:

a top-level Stage is normal browse only when the persisted ``ref.stage`` path
resolves back to that same marked top-level field root.  Missing, stale, or
conflicting Stage-path evidence is review-only rather than silently guessed.

Sub-stage rows are intentionally handled differently.  A marked NNa child root
beneath its owning NN Stage is already physically bounded by the authoritative
Google Drive hierarchy, so stale/missing Sub-stage ``folder_path`` remains a
review finding but does not erase that real nested scope.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from field_context_browse import build_field_hierarchy as _build_field_hierarchy

_TOP_LEVEL_PATH_REVIEW = "PERSISTED_STAGE_PATH_REVIEW_REQUIRED"
_TOP_LEVEL_BINDING_REVIEW = "TOP_LEVEL_STAGE_BINDING_REVIEW_REQUIRED"


def _review_sort_key(item: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(item.get("stage_key") or "").casefold(),
        str(item.get("code") or "").casefold(),
        str(item.get("scope_root") or "").casefold(),
        str(item.get("scene_name") or "").casefold(),
    )


def build_field_hierarchy(
    raw_stage_items: list[dict[str, Any]],
    drive_root: str | Path,
) -> dict[str, Any]:
    """Return resolved field hierarchy with ambiguous top-level Stages removed.

    ``field_context_browse`` remains responsible for filesystem resolution,
    hierarchy shape, Scene deduplication, and review evidence.  This wrapper
    converts any top-level Stage with unresolved persisted-path alignment into
    review-only output.
    """
    result = _build_field_hierarchy(raw_stage_items, drive_root)
    stages = list(result.get("stages") or [])
    reviews = list(result.get("review_required") or [])

    blocked: dict[str, list[dict[str, Any]]] = {}
    for review in reviews:
        if review.get("code") != _TOP_LEVEL_PATH_REVIEW:
            continue
        key = str(review.get("stage_key") or "").strip()
        if key:
            blocked.setdefault(key.casefold(), []).append(review)

    normal: list[dict[str, Any]] = []
    existing_review_keys = {
        (
            item.get("code"),
            item.get("stage_id"),
            str(item.get("stage_key") or "").casefold(),
            str(item.get("scope_root") or "").casefold(),
        )
        for item in reviews
    }

    for stage in stages:
        key = str(stage.get("stage_key") or "").strip()
        findings = blocked.get(key.casefold())
        if not findings:
            normal.append(stage)
            continue

        review = {
            "code": _TOP_LEVEL_BINDING_REVIEW,
            "stage_id": stage.get("stage_id"),
            "stage_key": key,
            "scope_root": stage.get("scope_root"),
            "database_stage_name": stage.get("database_stage_name"),
            "database_folder_path": stage.get("database_folder_path"),
            "warnings": [
                "Marked top-level field Stage exists, but persisted ref.stage path evidence does not resolve to that same root; normal browse suppressed pending alignment review."
            ],
        }
        dedupe_key = (
            review["code"],
            review.get("stage_id"),
            key.casefold(),
            str(review.get("scope_root") or "").casefold(),
        )
        if dedupe_key not in existing_review_keys:
            reviews.append(review)
            existing_review_keys.add(dedupe_key)

    return {
        "stages": normal,
        "review_required": sorted(reviews, key=_review_sort_key),
    }


def resolve_field_hierarchy(repository: Any, drive_root: str | Path) -> dict[str, Any]:
    """Canonical shared field-facing hierarchy entry point."""
    return build_field_hierarchy(repository.stages(), drive_root)
