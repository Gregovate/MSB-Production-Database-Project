"""Translate shared field-context diagnostics into operator-facing task messages.

Engineering codes remain stable for logs/tests. Field applications must not
render those codes directly. Instead, the task adapter supplies its human task
name (for example ``Wiring`` or ``Setup procedure``) and this module returns a
plain-language message using the current Scene/scope folder evidence.
"""
from __future__ import annotations

from typing import Any


OPERATOR_WARNING_MAP = {
    "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE": (
        "{task} not found for {subject} in folder {folder}."
    ),
    "LOR_CONTEXT_UNRESOLVED": (
        "{task} location could not be resolved for {subject} in folder {folder}."
    ),
    "FIELD_SCENE_MARKER_MISSING": (
        "{task} folder for {subject} is not approved for field use: {folder}."
    ),
    "LOR_CONTEXT_OUTSIDE_OWNING_SCOPE": (
        "{task} location for {subject} points outside the expected Stage folder: {folder}."
    ),
    "LOR_CONTEXT_NESTING_REVIEW_REQUIRED": (
        "{task} location for {subject} needs review in folder {folder}."
    ),
}


def _subject(diagnostic: dict[str, Any]) -> str:
    return str(
        diagnostic.get("scene_name")
        or diagnostic.get("stage_key")
        or "this selection"
    )


def _folder(diagnostic: dict[str, Any]) -> str:
    return str(
        diagnostic.get("scope_root")
        or diagnostic.get("database_folder_path")
        or "the current Stage folder"
    )


def operator_warning(diagnostic: dict[str, Any], *, task: str) -> str:
    """Return one operator-safe message without exposing the engineering code."""
    code = str(diagnostic.get("code") or "")
    template = OPERATOR_WARNING_MAP.get(code)
    if template is None:
        return f"{task} is not available for {_subject(diagnostic)}."
    return template.format(
        task=task,
        subject=_subject(diagnostic),
        folder=_folder(diagnostic),
    )


def with_operator_warning(diagnostic: dict[str, Any], *, task: str) -> dict[str, Any]:
    """Keep engineering metadata while adding the UI-safe translated message."""
    result = dict(diagnostic)
    result["operator_warning"] = operator_warning(diagnostic, task=task)
    return result
