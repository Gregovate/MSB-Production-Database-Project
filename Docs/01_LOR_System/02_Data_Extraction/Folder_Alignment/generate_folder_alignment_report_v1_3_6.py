#!/usr/bin/env python3
"""V1.3.6 test patch for MSB Folder Alignment.

Implements the provisional deterministic naming/documentation-scope contract from
Folder_Alignment_Engineering_Design.md without changing the V7 parser.

Classification under test:
  Root            -> owning Background Preview Stage root
  NN-Name-XY      -> Stage root
  NNa-Name-XY     -> Sub-stage root
  NN-Name         -> Scene under Stage NN
  NNa-Name        -> Scene under Sub-stage NNa
  unprefixed      -> Display/group (hidden by default by V1.3.5)

Scene.BackgroundFile remains authoritative filesystem evidence when it resolves
inside the established Stage tree. Conflicts between the deterministic name and
BackgroundFile are reported for review. No filesystem changes are made.
"""
from __future__ import annotations

import html
import re
from dataclasses import dataclass
from pathlib import Path

import generate_folder_alignment_report_v1_3_5 as patch
import generate_folder_alignment_report_v1_3_1 as scope_patch

base = patch.base
base.VERSION = "V1.3.6"

_original_audit = base.audit
_original_write_reports = base.write_reports

ROOT_NAME = "root"
FULL_SCOPE_RE = re.compile(
    r"^(?P<token>\d{2}[A-Za-z]?)-(?P<body>.+)-(?P<suffix>[A-Za-z]{2})$"
)
PREFIXED_RE = re.compile(r"^(?P<token>\d{2}[A-Za-z]?)-(?P<body>.+)$")


@dataclass
class ScopeRow:
    stage_id: str
    preview_name: str
    preview_stage_id: str
    raw_scene_name: str
    scene_stage_id: str
    classification: str
    scope_token: str
    expected_path: Path | None
    resolved_path: Path | None
    resolution: str
    status: str
    note: str
    setup_exists: bool = False
    archive_exists: bool = False
    images_exists: bool = False


_LAST_SCOPE_ROWS: list[ScopeRow] = []


def _numeric_stage(token: str) -> str:
    m = re.match(r"^(\d{2})", token or "")
    return m.group(1) if m else ""


def classify_scene_name(info) -> tuple[str, str]:
    name = (info.scene_name or "").strip()

    # Reserved marker only has deterministic meaning when the Preview already
    # owns one Stage. Master Musical is intentionally excluded.
    if name.casefold() == ROOT_NAME and not info.is_master_musical and info.preview_stage_id:
        return "STAGE_ROOT_MARKER", info.preview_stage_id

    full = FULL_SCOPE_RE.fullmatch(name)
    if full:
        token = base.stage_key(full.group("token"))
        return ("SUB_STAGE_ROOT" if token[-1:].isalpha() else "STAGE_ROOT"), token

    prefixed = PREFIXED_RE.fullmatch(name)
    if prefixed:
        token = base.stage_key(prefixed.group("token"))
        return "SCENE", token

    return "DISPLAY_OR_GROUP", ""


def _unique_top_stage(stage_folders, sid: str) -> Path | None:
    matches = stage_folders.get(sid, [])
    return matches[0] if len(matches) == 1 else None


def _substage_roots(stage: Path, token: str) -> list[Path]:
    if not stage or not stage.is_dir():
        return []
    rx = re.compile(
        rf"^{re.escape(token)}-(?P<body>.+)-(?P<suffix>[A-Za-z]{{2}})$",
        re.IGNORECASE,
    )
    try:
        return sorted(
            [p for p in stage.iterdir() if p.is_dir() and rx.fullmatch(p.name)],
            key=lambda p: p.name.casefold(),
        )
    except OSError:
        return []


def _expected_from_name(info, classification: str, token: str, stage_folders) -> tuple[Path | None, str]:
    raw_name = info.scene_name.strip()

    if classification == "STAGE_ROOT_MARKER":
        top_sid = _numeric_stage(info.preview_stage_id)
        return _unique_top_stage(stage_folders, top_sid), "Background Preview Root marker"

    if classification == "STAGE_ROOT":
        top_sid = _numeric_stage(token)
        stage = _unique_top_stage(stage_folders, top_sid)
        if stage is None:
            return None, f"No unique top-level Stage folder for {top_sid}"
        return stage / "__NAME_CHECK__" / raw_name, "Stage-root name contract"

    if classification == "SUB_STAGE_ROOT":
        top_sid = _numeric_stage(token)
        stage = _unique_top_stage(stage_folders, top_sid)
        if stage is None:
            return None, f"No unique top-level Stage folder for {top_sid}"
        return stage / raw_name, "Sub-stage-root name contract"

    if classification == "SCENE":
        top_sid = _numeric_stage(token)
        stage = _unique_top_stage(stage_folders, top_sid)
        if stage is None:
            return None, f"No unique top-level Stage folder for {top_sid}"
        if token[-1:].isalpha():
            subs = _substage_roots(stage, token)
            if len(subs) != 1:
                return None, f"Expected one Sub-stage root for token {token}; found {len(subs)}"
            return subs[0] / raw_name, "Scene name contract under Sub-stage"
        return stage / raw_name, "Scene name contract under Stage"

    return None, "Display/group has no structured documentation root"


def _normalize_stage_root_expected(expected: Path | None, info, classification: str, stage_folders) -> Path | None:
    """For STAGE_ROOT, the expected object is the top-level folder itself."""
    if classification != "STAGE_ROOT":
        return expected
    token = base.stage_key(info.scene_stage_id or classify_scene_name(info)[1])
    top_sid = _numeric_stage(token)
    stage = _unique_top_stage(stage_folders, top_sid)
    if stage is None:
        return None
    # Return the actual Stage only when its full name is the deterministic name.
    return stage if stage.name.casefold() == info.scene_name.strip().casefold() else stage.parent / info.scene_name.strip()


def _background_path_root(info, stage_folders) -> Path | None:
    if not info.background_file:
        return None

    candidate_sids = []
    for token in (info.scene_stage_id, info.preview_stage_id):
        sid = _numeric_stage(token)
        if sid and sid not in candidate_sids:
            candidate_sids.append(sid)

    for sid in candidate_sids:
        stage = _unique_top_stage(stage_folders, sid)
        if stage is None:
            continue
        doc_root = scope_patch.documentation_root_from_background(info.background_file, stage)
        if doc_root is not None:
            return doc_root
    return None


def _make_scope_row(info, stage_folders) -> ScopeRow:
    classification, token = classify_scene_name(info)
    top_sid = _numeric_stage(token or info.preview_stage_id or info.scene_stage_id)

    expected, expected_reason = _expected_from_name(
        info, classification, token, stage_folders
    )
    expected = _normalize_stage_root_expected(expected, info, classification, stage_folders)

    path_root = _background_path_root(info, stage_folders)
    resolved = None
    resolution = expected_reason
    status = "REVIEW"
    note = ""

    if classification == "DISPLAY_OR_GROUP":
        status = "DISPLAY_GROUP"
        note = "Unprefixed Scene name does not establish a structured documentation scope."
    elif path_root is not None:
        resolved = path_root
        resolution = "Scene.BackgroundFile"
        if expected is not None and path_root != expected:
            status = "PATH_NAME_CONFLICT"
            note = (
                f"Deterministic name expects {expected}; BackgroundFile resolves {path_root}. "
                "Explicit path is retained as filesystem evidence; review the naming contract/source Preview."
            )
        else:
            status = "MATCH" if path_root.exists() else "MISSING"
            note = "BackgroundFile agrees with the deterministic documentation scope."
    elif classification == "STAGE_ROOT_MARKER":
        resolved = expected
        status = "MATCH" if expected is not None and expected.is_dir() else "MISSING"
        note = "Root means the owning Background Preview Stage root; no Root child folder is expected."
    elif expected is not None:
        resolved = expected if expected.is_dir() else None
        status = "MATCH" if resolved is not None else "MISSING"
        note = (
            "Deterministic expected folder exists."
            if resolved is not None
            else f"Deterministic expected folder not found: {expected}"
        )
    else:
        status = "UNRESOLVED"
        note = expected_reason

    setup_exists = archive_exists = images_exists = False
    if resolved is not None and classification != "DISPLAY_OR_GROUP":
        setup = resolved / "Procedures" / "Setup"
        setup_exists = setup.is_dir()
        archive_exists = (setup / "Archive").is_dir()
        images_exists = (setup / "images").is_dir()

    return ScopeRow(
        stage_id=top_sid,
        preview_name=info.preview_name,
        preview_stage_id=info.preview_stage_id,
        raw_scene_name=info.scene_name,
        scene_stage_id=info.scene_stage_id,
        classification=classification,
        scope_token=token,
        expected_path=expected,
        resolved_path=resolved,
        resolution=resolution,
        status=status,
        note=note,
        setup_exists=setup_exists,
        archive_exists=archive_exists,
        images_exists=images_exists,
    )


def audit(root: Path, previews, scenes, displays, scene_infos):
    global _LAST_SCOPE_ROWS

    findings, old_helpers = _original_audit(root, previews, scenes, displays, scene_infos)
    stage_folders, _stage_by_name, _candidates, _direct = base.inventory_drive(root)

    rows = [_make_scope_row(info, stage_folders) for info in scene_infos]
    _LAST_SCOPE_ROWS = rows

    # Remove inherited Scene/Musical grouping findings. V1.3.6 replaces those
    # semantics with deterministic scope findings below. Preserve Stage, Display,
    # legacy, and other independent engineering findings.
    scene_names = {r.raw_scene_name.casefold() for r in rows}
    findings = [
        f for f in findings
        if not (
            f.kind in {"SCENE", "MUSICAL_GROUP", "BACKGROUND_GROUP"}
            and f.lor_name.casefold() in scene_names
        )
    ]

    # Keep only inherited top-level Stage helper contexts. Rebuild subordinate
    # helper contexts from the deterministic contract so old fuzzy Scene matches
    # cannot leak back into the Setup roadmap.
    helpers = {}
    for sid, contexts in old_helpers.items():
        kept = [ctx for ctx in contexts if ctx.scope_type == "STAGE"]
        if kept:
            helpers[sid] = kept

    helper_keys = {
        (sid, str(ctx.base_path).casefold())
        for sid, contexts in helpers.items()
        for ctx in contexts
    }

    for row in rows:
        if row.classification == "DISPLAY_OR_GROUP":
            # Optional engineering visibility remains a Display finding and is
            # suppressed by default by the V1.3.5 report layer.
            findings.append(base.Finding(
                row.stage_id,
                "DISPLAY",
                row.raw_scene_name,
                "",
                "",
                "",
                "",
                "DISPLAY_SCOPE",
                "HIGH",
                "NONE",
                row.note,
            ))
            continue

        current = base.rel(row.resolved_path, root) if row.resolved_path is not None else ""
        expected = base.rel(row.expected_path, root) if row.expected_path is not None else ""
        findings.append(base.Finding(
            row.stage_id,
            "DOCUMENTATION_SCOPE",
            row.raw_scene_name,
            current,
            row.resolved_path.name if row.resolved_path is not None else "",
            "",
            expected,
            row.status,
            "HIGH" if row.status in {"MATCH", "MISSING"} else "REVIEW",
            "NONE" if row.status == "MATCH" else "REVIEW",
            f"{row.classification}; {row.resolution}. {row.note}",
        ))

        if row.resolved_path is None or not row.resolved_path.is_dir():
            continue
        if row.classification in {"STAGE_ROOT", "STAGE_ROOT_MARKER"}:
            # Existing Stage helper already owns this root.
            continue

        key = (row.stage_id, str(row.resolved_path).casefold())
        if key in helper_keys:
            continue
        helpers.setdefault(row.stage_id, []).append(base.helper_context(
            root,
            row.stage_id,
            "SUB-STAGE" if row.classification == "SUB_STAGE_ROOT" else "SCENE",
            row.raw_scene_name,
            row.resolved_path,
            f"Deterministic {row.classification} contract ({row.resolution})",
        ))
        helper_keys.add(key)

    return findings, helpers


def _yn(value: bool) -> str:
    return "YES" if value else "NO"


def _scope_validation_html(rows: list[ScopeRow], root: Path) -> str:
    if not rows:
        return ""

    trs = []
    for row in rows:
        expected = base.rel(row.expected_path, root) if row.expected_path is not None else ""
        resolved = base.rel(row.resolved_path, root) if row.resolved_path is not None else ""
        trs.append(
            "<tr>"
            f"<td><code>{html.escape(row.raw_scene_name)}</code></td>"
            f"<td>{html.escape(row.classification)}</td>"
            f"<td>{html.escape(row.scope_token or row.preview_stage_id or '')}</td>"
            f"<td><code>{html.escape(expected)}</code></td>"
            f"<td><code>{html.escape(resolved)}</code></td>"
            f"<td>{html.escape(row.resolution)}</td>"
            f"<td><strong>{html.escape(row.status)}</strong></td>"
            f"<td>{_yn(row.setup_exists)}</td>"
            f"<td>{_yn(row.archive_exists)}</td>"
            f"<td>{_yn(row.images_exists)}</td>"
            f"<td>{html.escape(row.note)}</td>"
            "</tr>"
        )

    return (
        "<div class='roadmap'><h3>Deterministic Documentation-Scope Validation</h3>"
        "<p>This is the V1.3.6 provisional naming-contract test. It does not change LOR or Drive folders. "
        "<code>SceneSection</code> is not used as folder identity.</p>"
        "<table><tr><th>Raw LOR Scene Name</th><th>Classification</th><th>Token</th>"
        "<th>Expected Path</th><th>Resolved Path</th><th>Evidence</th><th>Status</th>"
        "<th>Setup</th><th>Archive</th><th>images</th><th>Notes</th></tr>"
        + "".join(trs)
        + "</table></div>"
    )


def write_reports(output: Path, root: Path, db: Path, previews, findings, helpers, provenance):
    html_path, csv_path, counts = _original_write_reports(
        output, root, db, previews, findings, helpers, provenance
    )

    text = html_path.read_text(encoding="utf-8")

    visible_rows = [
        row for row in _LAST_SCOPE_ROWS
        if patch.INCLUDE_DISPLAYS or row.classification != "DISPLAY_OR_GROUP"
    ]

    by_stage = {}
    for row in visible_rows:
        if row.stage_id:
            by_stage.setdefault(row.stage_id, []).append(row)

    for sid, rows in sorted(by_stage.items()):
        marker = f"<h2>Stage {html.escape(sid)}</h2>"
        if marker in text:
            text = text.replace(marker, marker + _scope_validation_html(rows, root), 1)

    header_note = (
        "<div class='roadmap'><h3>V1.3.6 Provisional Contract Test</h3>"
        "<p>Folder scope is classified from raw LOR Scene <code>Name</code>, Preview context, and "
        "authoritative <code>BackgroundFile</code> evidence. Parser behavior has not been changed. "
        "The reserved Background Preview Scene name <code>Root</code> means the owning Stage root "
        "and never a child folder named Root.</p></div>"
    )
    marker = "<h2>Summary</h2>"
    if marker in text:
        text = text.replace(marker, header_note + marker, 1)

    html_path.write_text(text, encoding="utf-8")
    return html_path, csv_path, counts


base.audit = audit
base.write_reports = write_reports


def main() -> int:
    # Delegate option handling to V1.3.5 so --include-displays retains the same
    # operator contract while the underlying base.main() uses our patched audit.
    return patch.main()


if __name__ == "__main__":
    raise SystemExit(main())
