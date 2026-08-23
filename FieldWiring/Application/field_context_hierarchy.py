"""Validated field-facing Stage/Sub-stage/Scene browse contract.

This module is the canonical public wrapper over ``field_context_browse``.
The lower-level builder resolves actual marked filesystem roots, nests formal
Sub-stages, deduplicates raw LOR Scene evidence by resolved scope, and emits
alignment findings separately from normal browse output.

A top-level field Stage does not require an LOR association.  The released
Google Drive contract allows a permanent ``ref.stage`` identity to exist as a
physical/documentation Stage even when LOR has no Preview/Scene binding for it.
A unique Stage key paired with one unique marked ``NN-...`` top-level folder is
therefore sufficient field-hierarchy identity.

Persisted ``ref.stage.folder_path`` and LOR Preview/Scene relationships remain
important supporting evidence.  Missing, stale, or conflicting path evidence
is surfaced under ``review_required``; it is not by itself a reason to hide an
otherwise uniquely resolved physical Stage.  True identity ambiguity remains
blocked by the lower-level builder when no unique Stage-key/root pair exists.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from field_context_browse import build_field_hierarchy as _build_field_hierarchy


def build_field_hierarchy(
    raw_stage_items: list[dict[str, Any]],
    drive_root: str | Path,
) -> dict[str, Any]:
    """Return the canonical resolved field hierarchy plus review evidence."""
    return _build_field_hierarchy(raw_stage_items, drive_root)


def resolve_field_hierarchy(repository: Any, drive_root: str | Path) -> dict[str, Any]:
    """Canonical shared field-facing hierarchy entry point."""
    return build_field_hierarchy(repository.stages(), drive_root)
