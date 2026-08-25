"""Authenticated Windows-side runner for LOR2DB parser and ingest operations.

Initial release: 2026-08-13 V1.0.0

Current version: 2026-08-25 V1.6.0

V1.5.0 adds the fixed, digest-locked PostgreSQL ingest operation and bounded
read-only ingest console. Parser execution remains repeatable and never starts
ingest automatically.

V1.5.1 pairs that operation with ingest V0.4.1, whose digest-idempotent recovery
recognizes an already-committed snapshot after a console/reporting failure.

V1.6.0 adds the reviewed dual-host launcher contract: the existing Office
interactive recovery profile remains available, while PRINT-SERVER uses a
separate at-startup Password-logon task under Print Service.

The production LOR2DB API runs on Linux. This small internal service owns the
Windows/G-drive execution boundary and exposes only version-scoped operations;
callers cannot submit arbitrary executable or output paths.
"""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import hmac
import json
import os
import re
import sqlite3
import subprocess
import sys
import threading
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from lor_version_checker import build_manifest, compare_manifests, manifest_source_signature, write_json


RUNNER_VERSION = "V1.6.0"
MAX_BROWSER_CONSOLE_CHARACTERS = 500_000

AUTHORITATIVE_OUTPUT_TABLES = (
    "props",
    "subProps",
    "dmxChannels",
    "scenes",
    "scene_lor_props",
)
PREVIEW_METADATA_FIELDS = (
    "StageID",
    "Name",
    "Revision",
    "Brightness",
    "BackgroundFile",
    "SourceFilename",
)


def required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required setting {name} is missing")
    return value


def credential_fingerprint(value: str) -> str:
    """Return a non-secret diagnostic identifier for a credential value."""
    if not value:
        return "missing"
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:16]


def utc_now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def path_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def _table_contract(connection: sqlite3.Connection, table: str) -> list[tuple[Any, ...]]:
    return [
        (row[1], row[2], row[3], row[4], row[5])
        for row in connection.execute(f'PRAGMA table_info("{table}")')
    ]


def _content_columns(contract: list[tuple[Any, ...]]) -> list[str]:
    # Exclude only disposable integer primary keys. A prefix-only test would
    # incorrectly omit authoritative fields such as IndividualChannels.
    return [
        str(row[0])
        for row in contract
        if not (
            str(row[0]).startswith("Int")
            and str(row[1]).upper() == "INTEGER"
            and int(row[4]) > 0
        )
    ]


def _quoted(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def _rows(
    connection: sqlite3.Connection,
    table: str,
    columns: list[str],
) -> Counter[tuple[Any, ...]]:
    selected = ", ".join(_quoted(column) for column in columns)
    return Counter(connection.execute(f'SELECT {selected} FROM {_quoted(table)}').fetchall())


def _write_output_comparison_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# LOR Parser Output Comparison",
        "",
        f"- Current LOR version: {report['current_lor_version']}",
        f"- New LOR version: {report['new_lor_version']}",
        f"- Status: **{report['status']}**",
        f"- Approval blocked: **{'YES' if report['approval_blocked'] else 'NO'}**",
        f"- Blocking findings: {report['blocking_count']}",
        f"- Review findings: {report['review_count']}",
        f"- Informational findings: {report['information_count']}",
        f"- Parser version: {report['parser_contract']['baseline_version']}",
        f"- View contracts equal: **{'YES' if report['view_contract']['contracts_equal'] else 'NO'}**",
        "",
        "## Authoritative table comparison",
        "",
        "| Table | Baseline only | Candidate only | Schema equal |",
        "|---|---:|---:|---|",
    ]
    for table, detail in report["tables"].items():
        lines.append(
            f"| {table} | {detail['baseline_only']} | {detail['candidate_only']} | "
            f"{'YES' if detail['schema_equal'] else 'NO'} |"
        )
    lines.extend([
        "",
        "## Preview metadata changes",
        "",
        "| Field | Changed previews |",
        "|---|---:|",
    ])
    for field, count in report["preview_metadata_change_counts"].items():
        lines.append(f"| {field} | {count} |")
    lines.extend([
        "",
        "## Findings",
        "",
        "| Severity | Area | Finding |",
        "|---|---|---|",
    ])
    if report["findings"]:
        for finding in report["findings"]:
            message = str(finding["message"]).replace("|", "\\|")
            lines.append(f"| {finding['severity']} | {finding['area']} | {message} |")
    else:
        lines.append("| — | — | No differences found. |")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def compare_parser_outputs(
    baseline_db: Path,
    candidate_db: Path,
    current_lor_version: str,
    new_lor_version: str,
    report_json: Path,
    report_markdown: Path,
) -> dict[str, Any]:
    """Compare same-parser SQLite outputs and fail closed on unexplained content."""
    for label, path in (("Baseline", baseline_db), ("Candidate", candidate_db)):
        if not path.is_file():
            raise ValueError(f"{label} parser database does not exist: {path}")

    baseline = sqlite3.connect(baseline_db)
    candidate = sqlite3.connect(candidate_db)
    try:
        findings: list[dict[str, str]] = []
        tables: dict[str, dict[str, Any]] = {}
        for table in ("previews", *AUTHORITATIVE_OUTPUT_TABLES):
            baseline_contract = _table_contract(baseline, table)
            candidate_contract = _table_contract(candidate, table)
            schema_equal = bool(baseline_contract) and baseline_contract == candidate_contract
            if not schema_equal:
                findings.append({
                    "severity": "BLOCKING",
                    "area": f"{table} schema",
                    "message": "Baseline and candidate SQLite table contracts differ.",
                })
            columns = _content_columns(baseline_contract)
            if not columns or not schema_equal:
                baseline_only = candidate_only = 0
            else:
                baseline_rows = _rows(baseline, table, columns)
                candidate_rows = _rows(candidate, table, columns)
                baseline_only = sum((baseline_rows - candidate_rows).values())
                candidate_only = sum((candidate_rows - baseline_rows).values())
            tables[table] = {
                "schema_equal": schema_equal,
                "baseline_only": baseline_only,
                "candidate_only": candidate_only,
            }
            if table != "previews" and (baseline_only or candidate_only):
                findings.append({
                    "severity": "BLOCKING",
                    "area": table,
                    "message": (
                        f"Authoritative content differs: baseline-only={baseline_only}; "
                        f"candidate-only={candidate_only}."
                    ),
                })

        baseline_parser_contract = _table_contract(baseline, "parser_run")
        candidate_parser_contract = _table_contract(candidate, "parser_run")
        if baseline_parser_contract != candidate_parser_contract:
            findings.append({
                "severity": "BLOCKING",
                "area": "parser_run schema",
                "message": "Baseline and candidate parser provenance contracts differ.",
            })
        baseline_parser_rows = baseline.execute(
            "SELECT ParserVersion, RunMode, ValidationStatus FROM parser_run"
        ).fetchall()
        candidate_parser_rows = candidate.execute(
            "SELECT ParserVersion, RunMode, ValidationStatus FROM parser_run"
        ).fetchall()
        baseline_parser_version = baseline_parser_rows[0][0] if len(baseline_parser_rows) == 1 else None
        candidate_parser_version = candidate_parser_rows[0][0] if len(candidate_parser_rows) == 1 else None
        if (
            len(baseline_parser_rows) != 1
            or len(candidate_parser_rows) != 1
            or baseline_parser_version != candidate_parser_version
            or baseline_parser_rows[0][1:] != ("VERSION_CHECK", "PASSED")
            or candidate_parser_rows[0][1:] != ("VERSION_CHECK", "PASSED")
        ):
            findings.append({
                "severity": "BLOCKING",
                "area": "parser provenance",
                "message": "Outputs were not produced by the same passing parser in VERSION_CHECK mode.",
            })

        baseline_views = {
            row[0]: row[1]
            for row in baseline.execute(
                "SELECT name, sql FROM sqlite_master WHERE type='view' ORDER BY name"
            )
        }
        candidate_views = {
            row[0]: row[1]
            for row in candidate.execute(
                "SELECT name, sql FROM sqlite_master WHERE type='view' ORDER BY name"
            )
        }
        view_names_equal = set(baseline_views) == set(candidate_views)
        common_views = sorted(set(baseline_views) & set(candidate_views))
        differing_view_contracts = [
            name
            for name in common_views
            if baseline_views[name] != candidate_views[name]
            or _table_contract(baseline, name) != _table_contract(candidate, name)
        ]
        view_contracts_equal = bool(baseline_views) and view_names_equal and not differing_view_contracts
        if not view_contracts_equal:
            findings.append({
                "severity": "BLOCKING",
                "area": "SQLite views",
                "message": (
                    f"View contracts differ: baseline={len(baseline_views)}; "
                    f"candidate={len(candidate_views)}; changed={len(differing_view_contracts)}."
                ),
            })

        preview_columns = [row[0] for row in _table_contract(baseline, "previews")]
        if "id" not in preview_columns:
            raise RuntimeError("previews table does not contain stable id identity")
        selected = ", ".join(_quoted(column) for column in preview_columns)
        baseline_previews = {
            row[preview_columns.index("id")]: dict(zip(preview_columns, row))
            for row in baseline.execute(f'SELECT {selected} FROM "previews"')
        }
        candidate_previews = {
            row[preview_columns.index("id")]: dict(zip(preview_columns, row))
            for row in candidate.execute(f'SELECT {selected} FROM "previews"')
        }
        missing = sorted(set(baseline_previews) - set(candidate_previews))
        added = sorted(set(candidate_previews) - set(baseline_previews))
        if missing or added:
            findings.append({
                "severity": "BLOCKING",
                "area": "preview identity",
                "message": f"Stable PreviewID sets differ: missing={len(missing)}; added={len(added)}.",
            })

        changes: list[dict[str, Any]] = []
        change_counts = {field: 0 for field in PREVIEW_METADATA_FIELDS}
        for preview_id in sorted(set(baseline_previews) & set(candidate_previews)):
            before = baseline_previews[preview_id]
            after = candidate_previews[preview_id]
            for field in PREVIEW_METADATA_FIELDS:
                if before.get(field) == after.get(field):
                    continue
                change_counts[field] += 1
                changes.append({
                    "preview_id": preview_id,
                    "preview_name": after.get("Name") or before.get("Name"),
                    "field": field,
                    "baseline": before.get(field),
                    "candidate": after.get(field),
                })

        revision_count = change_counts["Revision"]
        if revision_count:
            findings.append({
                "severity": "INFO",
                "area": "preview Revision",
                "message": (
                    f"LOR changed Revision metadata for {revision_count} preview(s). "
                    "Revision is recorded but is not treated as proof of a content change."
                ),
            })
        for field in PREVIEW_METADATA_FIELDS:
            count = change_counts[field]
            if not count or field == "Revision":
                continue
            findings.append({
                "severity": "REVIEW",
                "area": f"preview {field}",
                "message": f"{field} changed for {count} stable PreviewID row(s); operator resolution is required.",
            })

        blocking_count = sum(item["severity"] == "BLOCKING" for item in findings)
        review_count = sum(item["severity"] == "REVIEW" for item in findings)
        information_count = sum(item["severity"] == "INFO" for item in findings)
        status = "BLOCKED" if blocking_count else "REVIEW_REQUIRED" if review_count else "PASSED"
        report = {
            "current_lor_version": current_lor_version,
            "new_lor_version": new_lor_version,
            "status": status,
            "approval_blocked": status != "PASSED",
            "blocking_count": blocking_count,
            "review_count": review_count,
            "information_count": information_count,
            "tables": tables,
            "parser_contract": {
                "schema_equal": baseline_parser_contract == candidate_parser_contract,
                "baseline_version": baseline_parser_version,
                "candidate_version": candidate_parser_version,
            },
            "view_contract": {
                "baseline_count": len(baseline_views),
                "candidate_count": len(candidate_views),
                "names_equal": view_names_equal,
                "contracts_equal": view_contracts_equal,
                "changed_views": differing_view_contracts,
            },
            "preview_metadata_change_counts": change_counts,
            "preview_metadata_changes": changes,
            "findings": findings,
            "report_json": str(report_json),
            "report_markdown": str(report_markdown),
        }
        write_json(report_json, report)
        _write_output_comparison_markdown(report_markdown, report)
        return report
    finally:
        baseline.close()
        candidate.close()


class StateStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.lock = threading.RLock()

    def read(self) -> dict[str, Any]:
        with self.lock:
            if not self.path.is_file():
                raise RuntimeError(f"Runner state is not initialized: {self.path}")
            return json.loads(self.path.read_text(encoding="utf-8"))

    def write(self, state: dict[str, Any]) -> None:
        with self.lock:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.path.with_name(f".{self.path.name}.writing")
            temporary.write_text(
                json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
            os.replace(temporary, self.path)

    def update(self, operation) -> dict[str, Any]:
        with self.lock:
            state = self.read()
            operation(state)
            self.write(state)
            return state


class Runner:
    def __init__(self, store: StateStore) -> None:
        self.store = store
        self.operation_lock = threading.Lock()
        self.parser_path = Path(
            os.environ.get("LOR_PARSER_PATH")
            or Path(__file__).with_name("parse_props_v7_scene_parser.py")
        ).resolve()
        self.checker_path = Path(
            os.environ.get("LOR_CHECKER_PATH")
            or Path(__file__).with_name("lor_version_checker.py")
        ).resolve()
        self.ingest_path = Path(
            os.environ.get("LOR_INGEST_PATH")
            or Path(__file__).resolve().parents[4]
            / "LOR2DB" / "01_Ingest"
            / "postgres_ingest_from_lor_sqlite_v7.py"
        ).resolve()
        self.preview_parent = Path(required_environment("LOR_PREVIEW_PARENT")).resolve()
        self.production_db = Path(required_environment("LOR_SQLITE_OUTPUT")).resolve()
        self.reports_root = Path(required_environment("LOR_RUNNER_REPORTS_ROOT")).resolve()
        for script in (self.parser_path, self.checker_path, self.ingest_path):
            if not script.is_file():
                raise RuntimeError(f"Runner executable is missing: {script}")
        self._mark_interrupted_parser_activity()
        self._mark_interrupted_ingest_activity()

    def _mark_interrupted_parser_activity(self) -> None:
        """Make a stale RUNNING marker truthful after a runner restart."""
        state = self.store.read()
        activity = state.get("parser_activity") or {}
        if activity.get("status") != "RUNNING":
            return

        def operation(current: dict[str, Any]) -> None:
            stale = current.get("parser_activity") or {}
            if stale.get("status") == "RUNNING":
                stale.update({
                    "status": "INTERRUPTED",
                    "completed_at": utc_now(),
                    "error": "The runner restarted before this parser operation completed.",
                })
                current["parser_activity"] = stale

        self.store.update(operation)

    def _mark_interrupted_ingest_activity(self) -> None:
        """Make a stale RUNNING ingest marker truthful after a restart."""
        state = self.store.read()
        activity = state.get("ingest_activity") or {}
        if activity.get("status") != "RUNNING":
            return

        def operation(current: dict[str, Any]) -> None:
            stale = current.get("ingest_activity") or {}
            if stale.get("status") == "RUNNING":
                stale.update({
                    "status": "INTERRUPTED",
                    "completed_at": utc_now(),
                    "error": "The runner restarted before this ingest completed.",
                })
                current["ingest_activity"] = stale

        self.store.update(operation)

    def _start_parser_activity(
        self, target: str, version: str, folder: Path, actor: str
    ) -> tuple[dict[str, Any], Path]:
        """Record one recoverable browser-visible parser attempt."""
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        log_path = (
            self.reports_root / f"V{version}" / "browser-parser-runs" /
            f"{target}-{stamp}.log"
        )
        log_path.parent.mkdir(parents=True, exist_ok=True)
        activity = {
            "activity_id": f"{target}-{stamp}",
            "target": target,
            "status": "RUNNING",
            "source_lor_version": version,
            "source_preview_folder": str(folder),
            "started_at": utc_now(),
            "completed_at": None,
            "run_by": actor,
            "console_log_path": str(log_path),
            "error": None,
            "result": None,
        }

        def operation(current: dict[str, Any]) -> None:
            current["parser_activity"] = activity

        self.store.update(operation)
        return activity, log_path

    def _finish_parser_activity(
        self,
        activity: dict[str, Any],
        status: str,
        log_path: Path,
        console_output: str,
        *,
        result: dict[str, Any] | None = None,
        error: str | None = None,
    ) -> None:
        """Persist the terminal parser result and its complete console log."""
        log_path.write_text(console_output, encoding="utf-8")

        def operation(current: dict[str, Any]) -> None:
            latest = current.get("parser_activity") or {}
            if latest.get("activity_id") != activity["activity_id"]:
                raise RuntimeError("A newer parser activity replaced this run")
            latest.update({
                "status": status,
                "completed_at": utc_now(),
                "error": error,
                "result": result,
            })
            current["parser_activity"] = latest

        self.store.update(operation)

    def public_parser_activity(self) -> dict[str, Any] | None:
        """Return the latest parser attempt with bounded read-only output."""
        activity = (self.store.read().get("parser_activity") or None)
        if not activity:
            return None
        public = dict(activity)
        log_path = Path(str(public.pop("console_log_path", "")))
        console_output = ""
        truncated = False
        if log_path.is_file():
            console_output = log_path.read_text(encoding="utf-8", errors="replace")
            if len(console_output) > MAX_BROWSER_CONSOLE_CHARACTERS:
                console_output = console_output[-MAX_BROWSER_CONSOLE_CHARACTERS:]
                truncated = True
        public["console_output"] = console_output
        public["console_truncated"] = truncated
        return public

    def _start_ingest_activity(
        self, digest: str, actor: str
    ) -> tuple[dict[str, Any], Path]:
        """Record one recoverable browser-visible PostgreSQL ingest attempt."""
        state = self.store.read()
        version = state["current_lor_version"]
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        log_path = (
            self.reports_root / f"V{version}" / "browser-ingest-runs" /
            f"ingest-{stamp}.log"
        )
        log_path.parent.mkdir(parents=True, exist_ok=True)
        activity = {
            "activity_id": f"ingest-{stamp}",
            "status": "RUNNING",
            "source_lor_version": version,
            "sqlite_sha256": digest,
            "started_at": utc_now(),
            "completed_at": None,
            "run_by": actor,
            "console_log_path": str(log_path),
            "error": None,
            "result": None,
        }

        def operation(current: dict[str, Any]) -> None:
            current["ingest_activity"] = activity

        self.store.update(operation)
        return activity, log_path

    def _finish_ingest_activity(
        self,
        activity: dict[str, Any],
        status: str,
        log_path: Path,
        console_output: str,
        *,
        result: dict[str, Any] | None = None,
        error: str | None = None,
    ) -> None:
        """Persist the terminal ingest result and its complete console log."""
        log_path.write_text(console_output, encoding="utf-8")

        def operation(current: dict[str, Any]) -> None:
            latest = current.get("ingest_activity") or {}
            if latest.get("activity_id") != activity["activity_id"]:
                raise RuntimeError("A newer ingest activity replaced this run")
            latest.update({
                "status": status,
                "completed_at": utc_now(),
                "error": error,
                "result": result,
            })
            current["ingest_activity"] = latest
            if result:
                current["production_ingest_run"] = result

        self.store.update(operation)

    def public_ingest_activity(self) -> dict[str, Any] | None:
        """Return the latest ingest attempt with bounded read-only output."""
        activity = self.store.read().get("ingest_activity") or None
        if not activity:
            return None
        public = dict(activity)
        log_path = Path(str(public.pop("console_log_path", "")))
        console_output = ""
        truncated = False
        if log_path.is_file():
            console_output = log_path.read_text(
                encoding="utf-8", errors="replace"
            )
            if len(console_output) > MAX_BROWSER_CONSOLE_CHARACTERS:
                console_output = console_output[-MAX_BROWSER_CONSOLE_CHARACTERS:]
                truncated = True
        public["console_output"] = console_output
        public["console_truncated"] = truncated
        return public

    def run_ingest(self, expected_digest: str, actor: str) -> dict[str, Any]:
        """Run the one fixed, parser-authorized SQLite-to-PostgreSQL ingest."""
        digest = expected_digest.strip().lower()
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Expected SQLite SHA-256 must contain 64 hexadecimal characters")
        state = self.store.read()
        parser_run = state.get("production_parser_run") or {}
        if (
            parser_run.get("status") != "COMPLETE"
            or parser_run.get("validation_status") != "PASSED"
        ):
            raise ValueError("Run and validate the production parser before ingest")
        if str(parser_run.get("sqlite_sha256") or "").lower() != digest:
            raise ValueError("The requested SQLite digest is not the latest validated parser output")
        if Path(str(parser_run.get("sqlite_path") or "")).resolve() != self.production_db:
            raise ValueError("The validated parser output is not the production SQLite file")
        if parser_run.get("source_lor_version") != state["current_lor_version"]:
            raise ValueError("The validated parser output does not use the approved LOR version")
        if not self.production_db.is_file():
            raise ValueError(f"Production SQLite file does not exist: {self.production_db}")
        with self.production_db.open("rb") as source:
            actual_digest = hashlib.file_digest(source, "sha256").hexdigest()
        if actual_digest != digest:
            raise ValueError("Production SQLite changed after the validated parser run")
        previous = state.get("production_ingest_run") or {}
        if (
            previous.get("status") == "COMPLETE"
            and previous.get("sqlite_sha256") == digest
        ):
            raise ValueError("This exact SQLite digest was already ingested")

        password = required_environment("LOR_INGEST_PG_PASSWORD")
        version = state["current_lor_version"]
        activity, console_log = self._start_ingest_activity(digest, actor)
        command = [
            sys.executable,
            str(self.ingest_path),
            "--sqlite", str(self.production_db),
            "--expected-sqlite-sha256", digest,
            "--pg-host", "192.168.5.9",
            "--pg-db", "msb",
            "--pg-user", "msbadmin",
            "--notes", (
                f"LOR2DB web ingest for approved LOR {version}; "
                f"requested by {actor}"
            ),
        ]
        child_environment = os.environ.copy()
        child_environment["PGPASSWORD"] = password
        try:
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=900,
                check=False,
                env=child_environment,
            )
        except Exception as error:
            detail = f"[FATAL] PostgreSQL ingest could not complete: {error}"
            self._finish_ingest_activity(
                activity, "FAILED", console_log, detail, error=str(error)
            )
            raise RuntimeError(detail) from error
        console_output = "\n".join(
            part.strip() for part in (completed.stdout, completed.stderr)
            if part and part.strip()
        )
        if completed.returncode:
            detail = console_output or "PostgreSQL ingest failed"
            self._finish_ingest_activity(
                activity, "FAILED", console_log, detail, error=detail
            )
            raise RuntimeError(detail)
        match = re.search(r"import_run_id=(\d+)", console_output)
        if not match:
            detail = "Ingest completed without reporting its import_run_id"
            diagnostic = "\n".join(
                part for part in (console_output, f"[FATAL] {detail}") if part
            )
            self._finish_ingest_activity(
                activity, "FAILED", console_log, diagnostic, error=detail
            )
            raise RuntimeError(detail)
        result = {
            "status": "COMPLETE",
            "sqlite_sha256": digest,
            "source_lor_version": version,
            "import_run_id": int(match.group(1)),
            "completed_at": utc_now(),
            "run_by": actor,
        }
        self._finish_ingest_activity(
            activity, "PASSED", console_log, console_output, result=result
        )
        return result

    def public_state(self) -> dict[str, Any]:
        state = self.store.read()
        parser_activity = dict(state.get("parser_activity") or {}) or None
        if parser_activity:
            parser_activity.pop("console_log_path", None)
        ingest_activity = dict(state.get("ingest_activity") or {}) or None
        if ingest_activity:
            ingest_activity.pop("console_log_path", None)
        return {
            "runner_version": RUNNER_VERSION,
            "current_lor_version": state["current_lor_version"],
            "current_preview_folder": state["current_preview_folder"],
            "current_manifest_sha256": state["current_manifest_sha256"],
            "new_lor_version": state.get("new_lor_version"),
            "new_preview_folder": state.get("new_preview_folder"),
            "candidate_check": state.get("candidate_check"),
            "baseline_parser_run": state.get("baseline_parser_run"),
            "candidate_parser_run": state.get("candidate_parser_run"),
            "candidate_output_comparison": state.get("candidate_output_comparison"),
            "candidate_resolution": state.get("candidate_resolution"),
            "production_parser_run": state.get("production_parser_run"),
            "parser_activity": parser_activity,
            "production_ingest_run": state.get("production_ingest_run"),
            "ingest_activity": ingest_activity,
            "ingest_configured": bool(
                os.environ.get("LOR_INGEST_PG_PASSWORD", "").strip()
            ),
            "last_approval": state.get("last_approval"),
            "approval_history": state.get("approval_history", []),
        }

    def select_candidate(self, version: str, actor: str) -> dict[str, Any]:
        version = version.strip().lstrip("vV")
        if not version or not re.fullmatch(r"\d+(?:\.\d+){2,3}", version):
            raise ValueError("New LOR version must be numeric and dot-separated, such as 6.6.10")
        folder = (self.preview_parent / f"Database Previews V{version}").resolve()
        if not path_within(folder, self.preview_parent):
            raise ValueError("Candidate preview folder escaped the configured preview root")

        def operation(state: dict[str, Any]) -> None:
            if version == state["current_lor_version"]:
                raise ValueError("New LOR version must differ from the approved current version")
            state.update({
                "new_lor_version": version,
                "new_preview_folder": str(folder),
                "candidate_check": None,
                "candidate_parser_run": None,
                "candidate_output_comparison": None,
                "candidate_resolution": None,
                "candidate_selected_at": utc_now(),
                "candidate_selected_by": actor,
            })

        return self.store.update(operation)

    def run_compatibility_check(self, actor: str) -> dict[str, Any]:
        state = self.store.read()
        version = state.get("new_lor_version")
        folder = Path(state.get("new_preview_folder") or "")
        if not version:
            raise ValueError("Select a new LOR version first")
        if not folder.is_dir():
            raise ValueError(f"Candidate preview folder does not exist: {folder}")

        report_dir = self.reports_root / f"V{version}" / "compatibility"
        candidate_manifest = report_dir / "candidate-manifest.json"
        report_json = report_dir / "compatibility-report.json"
        report_md = report_dir / "compatibility-report.md"
        command = [
            sys.executable, str(self.checker_path), "compare",
            "--baseline", state["current_manifest_path"],
            "--new-lor-version", version,
            "--preview-folder", str(folder),
            "--deep-preview", state["deep_preview"],
            "--candidate-manifest", str(candidate_manifest),
            "--report-json", str(report_json),
            "--report-md", str(report_md),
        ]
        completed = subprocess.run(command, capture_output=True, text=True, timeout=300, check=False)
        if not report_json.is_file():
            raise RuntimeError((completed.stderr or completed.stdout).strip() or "Compatibility checker failed")
        report = json.loads(report_json.read_text(encoding="utf-8"))
        record = {
            **report,
            "checked_by": actor,
            "report_json": str(report_json),
            "report_markdown": str(report_md),
            "candidate_manifest_path": str(candidate_manifest),
            "stdout": completed.stdout.strip(),
        }

        def operation(current: dict[str, Any]) -> None:
            if current.get("new_lor_version") != version:
                raise RuntimeError("Candidate changed while the compatibility check was running")
            current["candidate_check"] = record
            current["candidate_parser_run"] = None
            current["candidate_output_comparison"] = None
            current["candidate_resolution"] = None

        self.store.update(operation)
        return record

    def run_parser(self, target: str, actor: str) -> dict[str, Any]:
        state = self.store.read()
        if target in {"current", "baseline"}:
            version = state["current_lor_version"]
            folder = Path(state["current_preview_folder"])
            approved_manifest = json.loads(
                Path(state["current_manifest_path"]).read_text(encoding="utf-8")
            )
            current_manifest = build_manifest(
                folder,
                version,
                approved_manifest.get("deep_preview"),
                deep_identity=approved_manifest.get("deep_preview_identity"),
            )
            # Approved LOR compatibility is a structural contract, not a ban on
            # routine preview authoring.  Current-version production previews
            # are expected to change between parser runs.  Rebuild their live
            # manifest and block only a parser-breaking XML contract change.
            # Candidate-version runs retain the exact-source guard below so a
            # checked candidate cannot change between Check and Run Parser.
            blocking = [
                finding for finding in compare_manifests(
                    approved_manifest, current_manifest
                )
                if finding.severity == "BLOCKING"
            ]
            if blocking:
                detail = "; ".join(
                    f"{finding.area}: {finding.message}" for finding in blocking
                )
                raise ValueError(
                    "The current preview folder contains parser-breaking XML "
                    f"changes relative to approved LOR {version}: {detail}"
                )
            compatibility_manifest_sha256 = state["current_manifest_sha256"]
            if target == "current":
                db_file = self.production_db
                run_mode = "PRODUCTION"
            else:
                db_file = self.reports_root / f"V{version}" / "parser" / "lor_output_v7_scene.db"
                run_mode = "VERSION_CHECK"
        elif target == "candidate":
            version = state.get("new_lor_version")
            if not version:
                raise ValueError("Select a new LOR version first")
            check = state.get("candidate_check")
            if not check:
                raise ValueError(
                    "Run the parser-independent XML compatibility check before the candidate parser"
                )
            folder = Path(state["new_preview_folder"])
            db_file = self.reports_root / f"V{version}" / "parser" / "lor_output_v7_scene.db"
            run_mode = "VERSION_CHECK"
            candidate_manifest = json.loads(
                Path(check["candidate_manifest_path"]).read_text(encoding="utf-8")
            )
            live_manifest = build_manifest(
                folder,
                version,
                candidate_manifest.get("deep_preview"),
                deep_identity=candidate_manifest.get("deep_preview_identity"),
            )
            if manifest_source_signature(live_manifest) != manifest_source_signature(candidate_manifest):
                raise ValueError(
                    "The candidate preview folder changed after its XML check; rerun XML compatibility"
                )
            compatibility_manifest_sha256 = candidate_manifest["manifest_sha256"]
        else:
            raise ValueError("Parser target must be current, baseline, or candidate")
        if not folder.is_dir():
            raise ValueError(f"Preview folder does not exist: {folder}")

        reports = db_file.parent / "reports"
        result_json = db_file.parent / "parser-result.json"
        command = [
            sys.executable, str(self.parser_path),
            "--db-file", str(db_file),
            "--preview-folder", str(folder),
            "--reports-folder", str(reports),
            "--run-mode", run_mode,
            "--source-lor-version", version,
            "--compatibility-manifest-sha256", compatibility_manifest_sha256,
            "--result-json", str(result_json),
            "--non-interactive",
        ]
        activity, console_log = self._start_parser_activity(target, version, folder, actor)
        try:
            completed = subprocess.run(
                command, capture_output=True, text=True, timeout=900,
                check=False,
            )
        except Exception as error:
            detail = f"[FATAL] Parser process could not complete: {error}"
            self._finish_parser_activity(
                activity, "FAILED", console_log, detail, error=str(error)
            )
            raise RuntimeError(detail) from error
        console_output = "\n".join(
            part.strip() for part in (completed.stdout, completed.stderr)
            if part and part.strip()
        )
        if completed.returncode or not result_json.is_file():
            detail = console_output or "Parser run failed"
            self._finish_parser_activity(
                activity, "FAILED", console_log, detail, error=detail
            )
            raise RuntimeError(detail)
        try:
            result = json.loads(result_json.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            detail = f"[FATAL] Parser result file is invalid: {error}"
            diagnostic = "\n".join(part for part in (console_output, detail) if part)
            self._finish_parser_activity(
                activity, "FAILED", console_log, diagnostic, error=detail
            )
            raise RuntimeError(detail) from error
        record = {
            **result,
            "run_by": actor,
            "completed_at": utc_now(),
            "result_json": str(result_json),
        }

        def operation(current: dict[str, Any]) -> None:
            expected = (
                current["current_lor_version"]
                if target in {"current", "baseline"}
                else current.get("new_lor_version")
            )
            if expected != version:
                raise RuntimeError("LOR version changed while the parser was running; result was not recorded")
            if target == "current":
                key = "production_parser_run"
                previous_ingest = current.get("production_ingest_run") or {}
                if previous_ingest.get("sqlite_sha256") != record.get("sqlite_sha256"):
                    current["production_ingest_run"] = None
                    current["ingest_activity"] = None
            elif target == "baseline":
                key = "baseline_parser_run"
                current["candidate_output_comparison"] = None
                current["candidate_resolution"] = None
            else:
                key = "candidate_parser_run"
                current["candidate_output_comparison"] = None
                current["candidate_resolution"] = None
            current[key] = record

        self.store.update(operation)
        if target == "candidate":
            refreshed = self.store.read()
            baseline_run = refreshed.get("baseline_parser_run") or {}
            if (
                baseline_run.get("status") == "COMPLETE"
                and baseline_run.get("validation_status") == "PASSED"
                and baseline_run.get("source_lor_version") == refreshed["current_lor_version"]
            ):
                comparison_dir = self.reports_root / f"V{version}" / "comparison"
                comparison = compare_parser_outputs(
                    Path(baseline_run["sqlite_path"]),
                    Path(record["sqlite_path"]),
                    refreshed["current_lor_version"],
                    version,
                    comparison_dir / "parser-output-comparison.json",
                    comparison_dir / "parser-output-comparison.md",
                )

                def save_comparison(current: dict[str, Any]) -> None:
                    if current.get("new_lor_version") != version:
                        raise RuntimeError("Candidate changed while parser outputs were compared")
                    current["candidate_output_comparison"] = comparison

                self.store.update(save_comparison)
        self._finish_parser_activity(
            activity, "PASSED", console_log, console_output, result=record
        )
        return record

    def resolve_candidate_findings(self, notes: str, actor: str) -> dict[str, Any]:
        notes = notes.strip()
        if not notes:
            raise ValueError("Engineering resolution notes are required")
        state = self.store.read()
        check = state.get("candidate_check") or {}
        baseline_run = state.get("baseline_parser_run") or {}
        parser_run = state.get("candidate_parser_run") or {}
        comparison = state.get("candidate_output_comparison") or {}
        if check.get("status") == "PASSED" and comparison.get("status") == "PASSED":
            raise ValueError("The compatibility and output checks passed; no resolution is required")
        if not check:
            raise ValueError("Run the compatibility check first")
        if baseline_run.get("status") != "COMPLETE" or baseline_run.get("validation_status") != "PASSED":
            raise ValueError("A validated approved-version baseline parser run is required")
        if parser_run.get("status") != "COMPLETE" or parser_run.get("validation_status") != "PASSED":
            raise ValueError("A validated candidate parser run is required before resolving findings")
        if not comparison:
            raise ValueError("Run the baseline/candidate SQLite output comparison first")
        resolution = {
            "status": "RESOLVED",
            "resolved_at": utc_now(),
            "resolved_by": actor,
            "parser_version": parser_run["parser_version"],
            "notes": notes,
            "parser_modifications_required": check.get("parser_modifications_required", []),
            "xml_status": check.get("status"),
            "output_comparison_status": comparison.get("status"),
        }

        def operation(current: dict[str, Any]) -> None:
            if current.get("new_lor_version") != state.get("new_lor_version"):
                raise RuntimeError("Candidate changed before findings could be resolved")
            current["candidate_resolution"] = resolution

        self.store.update(operation)
        return resolution

    def approve_candidate(self, version: str, actor: str) -> dict[str, Any]:
        state = self.store.read()
        if version != state.get("new_lor_version"):
            raise ValueError("Approval confirmation does not match the selected new LOR version")
        check = state.get("candidate_check") or {}
        baseline_run = state.get("baseline_parser_run") or {}
        parser_run = state.get("candidate_parser_run") or {}
        comparison = state.get("candidate_output_comparison") or {}
        resolution = state.get("candidate_resolution") or {}
        check_accepted = check.get("status") == "PASSED" or resolution.get("status") == "RESOLVED"
        comparison_accepted = (
            comparison.get("status") == "PASSED" or resolution.get("status") == "RESOLVED"
        )
        if not check_accepted:
            raise ValueError("Compatibility findings have not passed or been resolved")
        if baseline_run.get("status") != "COMPLETE" or baseline_run.get("validation_status") != "PASSED":
            raise ValueError("Approved-version comparison baseline has not passed")
        if parser_run.get("status") != "COMPLETE" or parser_run.get("validation_status") != "PASSED":
            raise ValueError("Candidate parser run has not passed")
        if not comparison_accepted:
            raise ValueError("Parser output differences have not passed or been resolved")
        candidate_manifest = Path(check["candidate_manifest_path"])
        manifest = json.loads(candidate_manifest.read_text(encoding="utf-8"))
        approved_manifest = self.store.path.with_name("current-lor-manifest.json")
        write_json(approved_manifest, manifest)

        def operation(current: dict[str, Any]) -> None:
            if current.get("new_lor_version") != version:
                raise RuntimeError("Candidate changed before approval could be recorded")
            approval = {
                "previous_lor_version": current["current_lor_version"],
                "approved_lor_version": version,
                "approved_at": utc_now(),
                "approved_by": actor,
                "compatibility_report": check["report_json"],
                "compatibility_manifest_sha256": manifest["manifest_sha256"],
                "parser_version": parser_run["parser_version"],
                "baseline_sqlite_sha256": baseline_run["sqlite_sha256"],
                "candidate_sqlite_sha256": parser_run["sqlite_sha256"],
                "output_comparison_report": comparison["report_json"],
                "compatibility_resolution": resolution or None,
            }
            current["last_approval"] = approval
            current.setdefault("approval_history", []).append(approval)
            current["current_lor_version"] = version
            current["current_preview_folder"] = current["new_preview_folder"]
            current["current_manifest_path"] = str(approved_manifest)
            current["current_manifest_sha256"] = manifest["manifest_sha256"]
            current["deep_preview"] = manifest["deep_preview"]
            current["deep_preview_identity"] = manifest["deep_preview_identity"]
            current["new_lor_version"] = None
            current["new_preview_folder"] = None
            current["candidate_check"] = None
            current["baseline_parser_run"] = parser_run
            current["candidate_parser_run"] = None
            current["candidate_output_comparison"] = None
            current["candidate_resolution"] = None
            current["production_parser_run"] = None
            current["parser_activity"] = None
            current["production_ingest_run"] = None
            current["ingest_activity"] = None

        return self.store.update(operation)


class RequestHandler(BaseHTTPRequestHandler):
    server_version = "MSBLORRunner/1.0"

    @property
    def runner(self) -> Runner:
        return self.server.runner  # type: ignore[attr-defined]

    def log_message(self, format_string: str, *args: Any) -> None:
        """Write normal HTTP access records to the managed stdout log."""
        print(
            f"{self.address_string()} - - [{self.log_date_time_string()}] "
            f"{format_string % args}",
            flush=True,
        )

    def authorized(self) -> bool:
        expected = f"Bearer {required_environment('LOR_RUNNER_TOKEN')}"
        provided = self.headers.get("Authorization", "")
        authorized = hmac.compare_digest(provided, expected)
        if not authorized:
            self.log_error(
                "Runner authentication rejected; expected fingerprint=%s; "
                "provided fingerprint=%s; provided length=%d",
                credential_fingerprint(expected),
                credential_fingerprint(provided),
                len(provided),
            )
        return authorized

    def body(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if not length:
            return {}
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("JSON body must be an object")
        return payload

    def respond(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def dispatch(self) -> tuple[HTTPStatus, dict[str, Any]]:
        if not self.authorized():
            return HTTPStatus.UNAUTHORIZED, {"error": "Runner authentication failed"}
        path = urlparse(self.path).path.rstrip("/") or "/"
        if self.command == "GET" and path == "/health":
            return HTTPStatus.OK, {"status": "ok", "version": RUNNER_VERSION}
        if self.command == "GET" and path == "/state":
            return HTTPStatus.OK, self.runner.public_state()
        if self.command == "GET" and path == "/parser/activity":
            return HTTPStatus.OK, {"activity": self.runner.public_parser_activity()}
        if self.command == "GET" and path == "/ingest/activity":
            return HTTPStatus.OK, {"activity": self.runner.public_ingest_activity()}
        payload = self.body()
        actor = str(payload.get("actor") or "unknown-operator")
        if self.command == "POST":
            # Only one state-changing/check/parser/ingest operation may run at a time.
            # This prevents concurrent website clicks from targeting the same
            # candidate database or changing the version record mid-run. A
            # second request is rejected rather than queued to run later.
            if not self.runner.operation_lock.acquire(blocking=False):
                return HTTPStatus.CONFLICT, {
                    "error": "Another parser, ingest, or version-check operation is already running"
                }
            try:
                if path == "/candidate":
                    self.runner.select_candidate(
                        str(payload.get("new_lor_version") or ""), actor
                    )
                    return HTTPStatus.OK, self.runner.public_state()
                if path == "/candidate/check":
                    return HTTPStatus.OK, self.runner.run_compatibility_check(actor)
                if path == "/parser/run":
                    return HTTPStatus.OK, self.runner.run_parser(
                        str(payload.get("target") or ""), actor
                    )
                if path == "/ingest/run":
                    return HTTPStatus.OK, self.runner.run_ingest(
                        str(payload.get("expected_sqlite_sha256") or ""), actor
                    )
                if path == "/candidate/resolve":
                    return HTTPStatus.OK, self.runner.resolve_candidate_findings(
                        str(payload.get("notes") or ""), actor
                    )
                if path == "/candidate/approve":
                    self.runner.approve_candidate(
                        str(payload.get("confirm_lor_version") or ""), actor
                    )
                    return HTTPStatus.OK, self.runner.public_state()
            finally:
                self.runner.operation_lock.release()
        return HTTPStatus.NOT_FOUND, {"error": "Runner endpoint was not found"}

    def handle_request(self) -> None:
        try:
            status, payload = self.dispatch()
        except (ValueError, RuntimeError, OSError, json.JSONDecodeError) as error:
            status, payload = HTTPStatus.CONFLICT, {"error": str(error)}
        self.respond(status, payload)

    do_GET = handle_request
    do_POST = handle_request


def initialize(arguments: argparse.Namespace) -> None:
    folder = arguments.current_preview_folder.resolve()
    version = arguments.current_lor_version.strip().lstrip("vV")
    if not re.fullmatch(r"\d+(?:\.\d+){2,3}", version):
        raise ValueError("Current LOR version must look like 6.6.4")
    manifest = build_manifest(folder, version, arguments.deep_preview)
    manifest_path = arguments.state_file.with_name("current-lor-manifest.json")
    write_json(manifest_path, manifest)
    StateStore(arguments.state_file).write({
        "schema_version": 1,
        "initialized_at": utc_now(),
        "current_lor_version": version,
        "current_preview_folder": str(folder),
        "current_manifest_path": str(manifest_path),
        "current_manifest_sha256": manifest["manifest_sha256"],
        "deep_preview": manifest["deep_preview"],
        "deep_preview_identity": manifest["deep_preview_identity"],
        "new_lor_version": None,
        "new_preview_folder": None,
        "candidate_check": None,
        "baseline_parser_run": None,
        "candidate_parser_run": None,
        "candidate_output_comparison": None,
        "candidate_resolution": None,
        "production_parser_run": None,
        "parser_activity": None,
        "production_ingest_run": None,
        "ingest_activity": None,
        "last_approval": None,
        "approval_history": [],
    })
    print(f"[OK] Initialized approved LOR {version}: {arguments.state_file}")


def command_parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="MSB Windows-side LOR operator runner")
    commands = root.add_subparsers(dest="command", required=True)
    initialize_command = commands.add_parser("init")
    initialize_command.add_argument("--state-file", required=True, type=Path)
    initialize_command.add_argument("--current-lor-version", required=True)
    initialize_command.add_argument("--current-preview-folder", required=True, type=Path)
    initialize_command.add_argument("--deep-preview")
    serve = commands.add_parser("serve")
    serve.add_argument("--state-file", required=True, type=Path)
    serve.add_argument("--host", default="127.0.0.1")
    serve.add_argument("--port", type=int, default=8791)
    return root


def main(argv: list[str] | None = None) -> int:
    arguments = command_parser().parse_args(argv)
    if arguments.command == "init":
        initialize(arguments)
        return 0
    runner = Runner(StateStore(arguments.state_file.resolve()))
    server = ThreadingHTTPServer((arguments.host, arguments.port), RequestHandler)
    server.runner = runner  # type: ignore[attr-defined]
    token = required_environment("LOR_RUNNER_TOKEN")
    print(
        f"[INFO] LOR runner {RUNNER_VERSION} listening on "
        f"{arguments.host}:{arguments.port}"
    )
    print(
        "[INFO] Runner credential fingerprint: "
        f"{credential_fingerprint(f'Bearer {token}')}"
    )
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
