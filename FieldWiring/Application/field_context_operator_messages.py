"""Translate shared field-context diagnostics into operator-facing task messages.

This module is formatting-only runtime code. It must perform no database
queries, filesystem access, Drive enumeration, marker checks, or network calls.
It receives facts the caller already resolved and turns them into useful
operator-facing text.

Engineering codes remain stable for logs/tests. Operator-facing applications
must not render those codes directly. A task adapter supplies its human task
name and, when applicable, the exact task-relative location already selected by
that application.

Examples::

    Wiring / Musical      -> Wiring\\MusicalStage
    Wiring / Background   -> Wiring\\BackgroundStage
    Setup procedure       -> Procedures\\Setup
    Takedown procedure    -> Procedures\\Takedown
    Inspection procedure  -> Procedures\\Inspection

The shared mapper does not choose the task branch. Server-side mount paths are
translated textually to the canonical operator-visible Shared Drive path; no
filesystem lookup is used.
"""
from __future__ import annotations

import re
from pathlib import PurePosixPath, PureWindowsPath
from typing import Any


OPERATOR_DRIVE_ROOT = r"G:\Shared drives\Display Folders"
SERVER_DRIVE_ROOT = "/mnt/msb-display-folders"

OPERATOR_WARNING_MAP = {
    "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE": (
        "{task} not found for {subject} in folder {folder}."
    ),
    "LOR_CONTEXT_UNRESOLVED": (
        "{task} location could not be resolved for {subject}. Expected folder: {folder}."
    ),
    "FIELD_SCENE_MARKER_MISSING": (
        "{task} folder for {subject} is not approved for field use: {folder}."
    ),
    "LOR_CONTEXT_OUTSIDE_OWNING_SCOPE": (
        "{task} location for {subject} points outside the expected Stage area. Expected folder: {folder}."
    ),
    "LOR_CONTEXT_NESTING_REVIEW_REQUIRED": (
        "{task} location for {subject} needs review. Expected folder: {folder}."
    ),
    # Generic cross-application task conditions. These are intentionally not
    # FieldWiring-specific so Procedure and future operator UIs can use the
    # same presentation contract without copying strings.
    "TASK_CONTENT_NOT_FOUND": (
        "{task} not found for {subject} in folder {folder}."
    ),
    "TASK_FOLDER_UNAPPROVED": (
        "{task} folder for {subject} is not approved for field use: {folder}."
    ),
    "TASK_SCOPE_UNRESOLVED": (
        "{task} location could not be resolved for {subject}. Expected folder: {folder}."
    ),
}


def _subject(diagnostic: dict[str, Any]) -> str:
    scene_name = str(diagnostic.get("scene_name") or "").strip()
    stage_key = str(diagnostic.get("stage_key") or "").strip()
    if scene_name and scene_name.casefold() != "root":
        return scene_name
    if stage_key:
        return f"Stage {stage_key}"
    return "this selection"


def _operator_scope_folder(diagnostic: dict[str, Any]) -> str:
    raw = str(
        diagnostic.get("scope_root")
        or diagnostic.get("database_folder_path")
        or "the current Stage folder"
    )

    normalized = raw.replace("\\", "/").rstrip("/")
    server_root = SERVER_DRIVE_ROOT.rstrip("/")
    if normalized.casefold() == server_root.casefold():
        return OPERATOR_DRIVE_ROOT
    if normalized.casefold().startswith(server_root.casefold() + "/"):
        suffix = normalized[len(server_root):].lstrip("/")
        return str(PureWindowsPath(OPERATOR_DRIVE_ROOT, *PurePosixPath(suffix).parts))

    return raw


def expected_operator_folder(
    diagnostic: dict[str, Any],
    task_relative_folder: str | None = None,
) -> str:
    """Return a human-facing expected folder using already-resolved path text."""
    base = _operator_scope_folder(diagnostic)
    relative = str(task_relative_folder or "").strip().strip("\\/")
    if not relative:
        return base

    if "\\" in base or re.match(r"^[A-Za-z]:", base):
        relative_parts = [
            part
            for part in PureWindowsPath(relative).parts
            if part not in {"\\", "/"}
        ]
        return str(PureWindowsPath(base, *relative_parts))

    if base.startswith("/"):
        relative_parts = [
            part
            for part in PurePosixPath(relative.replace("\\", "/")).parts
            if part != "/"
        ]
        return str(PurePosixPath(base, *relative_parts))

    return base.rstrip("\\/") + "\\" + relative.replace("/", "\\")


def operator_warning(
    diagnostic: dict[str, Any],
    *,
    task: str,
    task_relative_folder: str | None = None,
) -> str:
    """Return one operator-safe message without exposing the engineering code."""
    code = str(diagnostic.get("code") or "")
    template = OPERATOR_WARNING_MAP.get(code)
    folder = expected_operator_folder(diagnostic, task_relative_folder)
    if template is None:
        return f"{task} is not available for {_subject(diagnostic)}. Expected folder: {folder}."
    return template.format(
        task=task,
        subject=_subject(diagnostic),
        folder=folder,
    )


def with_operator_warning(
    diagnostic: dict[str, Any],
    *,
    task: str,
    task_relative_folder: str | None = None,
) -> dict[str, Any]:
    """Keep engineering metadata while adding the UI-safe translated message."""
    result = dict(diagnostic)
    result["operator_warning"] = operator_warning(
        diagnostic,
        task=task,
        task_relative_folder=task_relative_folder,
    )
    return result
