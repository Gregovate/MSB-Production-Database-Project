#!/usr/bin/env python3
"""
Safety guard for the FieldWiring Drive-context resolver test harness.

This wrapper enforces the engineering rule that SourceDocs is a hard
traversal boundary. If a current/legacy BackgroundFile pointer contains a
SourceDocs segment, the raw source path is retained only for reporting while
filesystem navigation is truncated before SourceDocs.
"""
from __future__ import annotations

import sys
from pathlib import PureWindowsPath

import test_drive_context_resolver as base


_original_resolve_one = base.resolve_one


def truncate_before_sourcedocs(path_text: str | None) -> tuple[str | None, bool]:
    if not path_text:
        return path_text, False

    parts = PureWindowsPath(path_text).parts
    for index, part in enumerate(parts):
        if part.casefold() == "sourcedocs":
            if index == 0:
                return None, True
            return str(PureWindowsPath(*parts[:index])), True

    return path_text, False


def guarded_resolve_one(conn, row, drive_root, drive_root_text):
    raw_scene_pointer = row["scene_background_file"]
    raw_preview_pointer = row["preview_background_file"]
    raw_pointer = raw_scene_pointer or raw_preview_pointer

    safe_pointer, blocked = truncate_before_sourcedocs(raw_pointer)
    if not blocked:
        return _original_resolve_one(conn, row, drive_root, drive_root_text)

    # sqlite3.Row is immutable, but the resolver only needs mapping access.
    safe_row = dict(row)
    if raw_scene_pointer:
        safe_row["scene_background_file"] = safe_pointer
    else:
        safe_row["preview_background_file"] = safe_pointer

    result = _original_resolve_one(conn, safe_row, drive_root, drive_root_text)

    # Preserve the actual stored pointer in the report while making it explicit
    # that the source-only endpoint itself was never tested or traversed.
    result.scene_background_file = raw_pointer
    result.exact_pointer_resolves = False
    result.warnings = [
        warning
        for warning in result.warnings
        if warning != "Exact BackgroundFile pointer does not currently resolve."
    ]
    result.warnings.insert(
        0,
        "BackgroundFile pointer enters SourceDocs. Traversal was blocked before "
        f"SourceDocs; source content was not accessed. Allowed path evidence: {safe_pointer}",
    )
    result.resolution_basis = "SourceDocs boundary enforced. " + result.resolution_basis
    return result


base.resolve_one = guarded_resolve_one


if __name__ == "__main__":
    try:
        raise SystemExit(base.main())
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)
