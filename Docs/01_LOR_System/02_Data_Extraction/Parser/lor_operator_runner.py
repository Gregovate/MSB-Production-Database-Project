"""Authenticated Windows-side runner for LOR2DB parser operations.

Initial release: 2026-08-13 V1.0.0

The production LOR2DB API runs on Linux. This small internal service owns the
Windows/G-drive execution boundary and exposes only version-scoped operations;
callers cannot submit arbitrary executable or output paths.
"""

from __future__ import annotations

import argparse
import hmac
import json
import os
import re
import subprocess
import sys
import threading
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from lor_version_checker import build_manifest, write_json


RUNNER_VERSION = "V1.0.0"


def required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required setting {name} is missing")
    return value


def utc_now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def path_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


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
        self.preview_parent = Path(required_environment("LOR_PREVIEW_PARENT")).resolve()
        self.production_db = Path(required_environment("LOR_SQLITE_OUTPUT")).resolve()
        self.reports_root = Path(required_environment("LOR_RUNNER_REPORTS_ROOT")).resolve()
        for script in (self.parser_path, self.checker_path):
            if not script.is_file():
                raise RuntimeError(f"Runner executable is missing: {script}")

    def public_state(self) -> dict[str, Any]:
        state = self.store.read()
        return {
            "runner_version": RUNNER_VERSION,
            "current_lor_version": state["current_lor_version"],
            "current_preview_folder": state["current_preview_folder"],
            "current_manifest_sha256": state["current_manifest_sha256"],
            "new_lor_version": state.get("new_lor_version"),
            "new_preview_folder": state.get("new_preview_folder"),
            "candidate_check": state.get("candidate_check"),
            "candidate_parser_run": state.get("candidate_parser_run"),
            "candidate_resolution": state.get("candidate_resolution"),
            "production_parser_run": state.get("production_parser_run"),
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
            current["candidate_resolution"] = None

        self.store.update(operation)
        return record

    def run_parser(self, target: str, actor: str) -> dict[str, Any]:
        state = self.store.read()
        if target == "current":
            version = state["current_lor_version"]
            folder = Path(state["current_preview_folder"])
            db_file = self.production_db
            run_mode = "PRODUCTION"
            compatibility_manifest_sha256 = state["current_manifest_sha256"]
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
            compatibility_manifest_sha256 = candidate_manifest["manifest_sha256"]
        else:
            raise ValueError("Parser target must be current or candidate")
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
        completed = subprocess.run(command, capture_output=True, text=True, timeout=900, check=False)
        if completed.returncode or not result_json.is_file():
            raise RuntimeError((completed.stderr or completed.stdout).strip() or "Parser run failed")
        result = json.loads(result_json.read_text(encoding="utf-8"))
        record = {
            **result,
            "run_by": actor,
            "completed_at": utc_now(),
            "result_json": str(result_json),
        }

        def operation(current: dict[str, Any]) -> None:
            expected = current["current_lor_version"] if target == "current" else current.get("new_lor_version")
            if expected != version:
                raise RuntimeError("LOR version changed while the parser was running; result was not recorded")
            key = "production_parser_run" if target == "current" else "candidate_parser_run"
            current[key] = record

        self.store.update(operation)
        return record

    def resolve_candidate_findings(self, notes: str, actor: str) -> dict[str, Any]:
        notes = notes.strip()
        if not notes:
            raise ValueError("Engineering resolution notes are required")
        state = self.store.read()
        check = state.get("candidate_check") or {}
        parser_run = state.get("candidate_parser_run") or {}
        if check.get("status") == "PASSED":
            raise ValueError("The compatibility check already passed; no resolution is required")
        if not check:
            raise ValueError("Run the compatibility check first")
        if parser_run.get("status") != "COMPLETE" or parser_run.get("validation_status") != "PASSED":
            raise ValueError("A validated candidate parser run is required before resolving findings")
        resolution = {
            "status": "RESOLVED",
            "resolved_at": utc_now(),
            "resolved_by": actor,
            "parser_version": parser_run["parser_version"],
            "notes": notes,
            "parser_modifications_required": check.get("parser_modifications_required", []),
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
        parser_run = state.get("candidate_parser_run") or {}
        resolution = state.get("candidate_resolution") or {}
        check_accepted = check.get("status") == "PASSED" or resolution.get("status") == "RESOLVED"
        if not check_accepted:
            raise ValueError("Compatibility findings have not passed or been resolved")
        if parser_run.get("status") != "COMPLETE" or parser_run.get("validation_status") != "PASSED":
            raise ValueError("Candidate parser run has not passed")
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
                "candidate_sqlite_sha256": parser_run["sqlite_sha256"],
                "compatibility_resolution": resolution or None,
            }
            current["last_approval"] = approval
            current.setdefault("approval_history", []).append(approval)
            current["current_lor_version"] = version
            current["current_preview_folder"] = current["new_preview_folder"]
            current["current_manifest_path"] = str(approved_manifest)
            current["current_manifest_sha256"] = manifest["manifest_sha256"]
            current["new_lor_version"] = None
            current["new_preview_folder"] = None
            current["candidate_check"] = None
            current["candidate_parser_run"] = None
            current["candidate_resolution"] = None
            current["production_parser_run"] = None

        return self.store.update(operation)


class RequestHandler(BaseHTTPRequestHandler):
    server_version = "MSBLORRunner/1.0"

    @property
    def runner(self) -> Runner:
        return self.server.runner  # type: ignore[attr-defined]

    def log_message(self, format_string: str, *args: Any) -> None:
        sys.stderr.write(f"[{self.log_date_time_string()}] {format_string % args}\n")

    def authorized(self) -> bool:
        expected = f"Bearer {required_environment('LOR_RUNNER_TOKEN')}"
        provided = self.headers.get("Authorization", "")
        return hmac.compare_digest(provided, expected)

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
        payload = self.body()
        actor = str(payload.get("actor") or "unknown-operator")
        if self.command == "POST":
            # Only one state-changing/check/parser operation may run at a time.
            # This prevents concurrent website clicks from targeting the same
            # candidate database or changing the version record mid-run.
            with self.runner.operation_lock:
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
                if path == "/candidate/resolve":
                    return HTTPStatus.OK, self.runner.resolve_candidate_findings(
                        str(payload.get("notes") or ""), actor
                    )
                if path == "/candidate/approve":
                    self.runner.approve_candidate(
                        str(payload.get("confirm_lor_version") or ""), actor
                    )
                    return HTTPStatus.OK, self.runner.public_state()
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
        "new_lor_version": None,
        "new_preview_folder": None,
        "candidate_check": None,
        "candidate_parser_run": None,
        "candidate_resolution": None,
        "production_parser_run": None,
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
    print(f"[INFO] LOR runner {RUNNER_VERSION} listening on {arguments.host}:{arguments.port}")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
