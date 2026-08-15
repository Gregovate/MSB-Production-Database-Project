"""Unit smoke tests for the LOR preflight API's non-database safety rules."""

from __future__ import annotations

import os
import tempfile
import unittest
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import MagicMock, patch

os.environ.setdefault("LOR_PREFLIGHT_OPERATORS", "greg@sheboyganlights.org")

import backend  # noqa: E402  (environment must exist before app import)


class BackendSafetyTests(unittest.TestCase):
    def test_runner_request_uses_direct_opener_and_bearer_header(self) -> None:
        response = MagicMock()
        response.__enter__.return_value = response
        response.read.return_value = b'{"status":"ok","version":"V1.3.0"}'
        settings = {
            "LOR_RUNNER_URL": "http://192.168.5.55:8791",
            "LOR_RUNNER_TOKEN": "a" * 64,
        }
        with patch.dict(os.environ, settings), patch.object(
            backend.DIRECT_RUNNER_OPENER,
            "open",
            return_value=response,
        ) as direct_open:
            result = backend.runner_request("health")

        self.assertEqual(result["status"], "ok")
        request_object = direct_open.call_args.args[0]
        self.assertEqual(
            request_object.get_header("Authorization"),
            f"Bearer {settings['LOR_RUNNER_TOKEN']}",
        )
        self.assertEqual(direct_open.call_args.kwargs["timeout"], 30)

    def test_publish_report_requires_an_absolute_publisher_path(self) -> None:
        with patch.dict(os.environ, {"LOR_REPORT_PUBLISHER_PATH": "publisher.py"}):
            with self.assertRaisesRegex(RuntimeError, "must be an absolute path"):
                backend.publish_report(5)

    def test_publish_report_rejects_a_missing_publisher_before_database_use(self) -> None:
        missing = Path(tempfile.gettempdir()) / "missing-lor-report-publisher.py"
        with patch.dict(os.environ, {"LOR_REPORT_PUBLISHER_PATH": str(missing)}):
            with self.assertRaisesRegex(backend.ApiError, "is not installed"):
                backend.publish_report(5)

    def test_browser_opens_run_report_with_archive_fallback(self) -> None:
        source = Path(__file__).with_name("preflight.js").read_text(encoding="utf-8")
        self.assertIn('result.report_url || "../reports/"', source)
        self.assertEqual(source.count("openPublishedReport(result);"), 2)

    def test_browser_renders_terminal_cancellation_proof(self) -> None:
        source = Path(__file__).with_name("preflight.js").read_text(encoding="utf-8")
        self.assertIn("Reconciliation cancelled", source)
        self.assertIn("captured ingest snapshot was removed", source)
        self.assertIn("Safe to close browser", source)
        self.assertNotIn("location.reload();", source)

    def test_browser_exposes_safe_stage_authority_labels_and_full_evidence(self) -> None:
        source = Path(__file__).with_name("preflight.js").read_text(encoding="utf-8")
        self.assertIn("APPROVE_STAGE_CHANGE", source)
        self.assertIn("ADD_NEW_STAGE", source)
        self.assertIn("Complete stage evidence", source)
        self.assertIn("candidate.members.map", source)

    def test_cancel_endpoint_returns_terminal_proof_and_report_url(self) -> None:
        class Cursor:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def execute(self, *_args):
                return None

        class Connection:
            def cursor(self, **_kwargs):
                return Cursor()

            def commit(self):
                return None

        @contextmanager
        def fake_database():
            yield Connection()

        cancelled = {
            "report_url": "https://example.test/reports/run-6.html",
            "cancelled_at": "2026-08-14T01:18:07Z",
            "completed_at": "2026-08-14T01:18:08Z",
            "cancellation_reason": "Correct LOR source",
        }
        with patch.object(backend, "database", fake_database), \
             patch.object(backend, "publish_report") as publish, \
             patch.object(backend, "load_run", return_value=cancelled):
            response = backend.app.test_client().post(
                "/runs/6/cancel",
                json={"reason": "Correct LOR source"},
                headers={
                    "Cf-Access-Authenticated-User-Email":
                        "greg@sheboyganlights.org"
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["status"], "CANCELLED")
        self.assertTrue(response.json["snapshot_removed"])
        self.assertFalse(response.json["production_changed"])
        self.assertTrue(response.json["safe_to_close"])
        self.assertEqual(response.json["report_url"], cancelled["report_url"])
        self.assertEqual(response.json["completed_at"], cancelled["completed_at"])
        publish.assert_called_once_with(6)

    def test_dashboard_marks_completed_snapshot_consumed(self) -> None:
        state = backend.dashboard_state(
            {"import_run_id": 45},
            {
                "lor_reconciliation_run_id": 4,
                "import_run_id": 45,
                "status": "COMPLETED",
            },
        )
        self.assertEqual(state["state"], "SNAPSHOT_CONSUMED")
        self.assertFalse(state["can_start"])

    def test_dashboard_allows_start_for_new_snapshot(self) -> None:
        state = backend.dashboard_state(
            {"import_run_id": 46},
            None,
        )
        self.assertEqual(state["state"], "READY_TO_START")
        self.assertTrue(state["can_start"])

    def test_dashboard_never_replaces_open_run(self) -> None:
        state = backend.dashboard_state(
            {"import_run_id": 46},
            {
                "lor_reconciliation_run_id": 4,
                "import_run_id": 45,
                "status": "AWAITING_DECISIONS",
            },
        )
        self.assertEqual(state["state"], "IN_PROGRESS")
        self.assertFalse(state["can_start"])
        self.assertEqual(state["action"]["url"], "preflight/?run=4")
        self.assertEqual(
            state["action"]["label"], "Continue previous reconciliation"
        )

    def test_dashboard_resumes_reporting_run_for_same_snapshot(self) -> None:
        state = backend.dashboard_state(
            {"import_run_id": 46},
            {
                "lor_reconciliation_run_id": 5,
                "import_run_id": 46,
                "status": "REPORTING",
            },
        )
        self.assertEqual(state["state"], "IN_PROGRESS")
        self.assertFalse(state["can_start"])
        self.assertEqual(state["action"]["url"], "preflight/?run=5")

    def test_dashboard_resumes_every_unfinished_lifecycle_state(self) -> None:
        for status in sorted(backend.OPEN_RUN_STATES):
            with self.subTest(status=status):
                state = backend.dashboard_state(
                    {"import_run_id": 46},
                    {
                        "lor_reconciliation_run_id": 5,
                        "import_run_id": 46,
                        "status": status,
                    },
                )
                self.assertEqual(state["state"], "IN_PROGRESS")
                self.assertFalse(state["can_start"])
                self.assertEqual(state["action"]["url"], "preflight/?run=5")

    def test_dashboard_resumes_open_run_after_cancel_removed_snapshot(self) -> None:
        state = backend.dashboard_state(
            None,
            {
                "lor_reconciliation_run_id": 5,
                "import_run_id": 46,
                "status": "REPORTING",
            },
        )
        self.assertEqual(state["state"], "IN_PROGRESS")
        self.assertFalse(state["can_start"])

    def test_dashboard_cancelled_snapshot_remains_consumed(self) -> None:
        state = backend.dashboard_state(
            {"import_run_id": 46},
            {
                "lor_reconciliation_run_id": 5,
                "import_run_id": 46,
                "status": "CANCELLED",
            },
        )
        self.assertEqual(state["state"], "SNAPSHOT_CONSUMED")
        self.assertFalse(state["can_start"])

    def test_optional_decision_reason_preserves_comment(self) -> None:
        self.assertEqual(
            backend.optional_decision_reason(
                {"reason": "  Saved frame  "}, "SET_RECYCLED"
            ),
            "Saved frame",
        )

    def test_optional_decision_reason_generates_audit_reason(self) -> None:
        self.assertEqual(
            backend.optional_decision_reason({}, "SET_RECYCLED"),
            "Operator selected SET_RECYCLED; no additional comment provided.",
        )

    def test_unambiguous_proposed_action(self) -> None:
        self.assertEqual(
            backend.proposed_action([
                "UPDATE_LOR_LINK", "CORRECT_SOURCE_REQUIRED", "DEFER"
            ]),
            "UPDATE_LOR_LINK",
        )

    def test_ambiguous_business_choice_has_no_accept_action(self) -> None:
        self.assertIsNone(backend.proposed_action([
            "SET_RETIRED", "SET_RECYCLED", "RESTORE_TO_LOR_REQUIRED", "DEFER"
        ]))

    def test_decision_version_is_order_independent(self) -> None:
        first = backend.decision_version([
            {"lor_reconciliation_group_id": 2, "effective_action_id": None},
            {"lor_reconciliation_group_id": 1, "effective_action_id": 7},
        ])
        second = backend.decision_version([
            {"lor_reconciliation_group_id": 1, "effective_action_id": 7},
            {"lor_reconciliation_group_id": 2, "effective_action_id": None},
        ])
        self.assertEqual(first, second)
        self.assertEqual(len(first), 64)

    def test_missing_access_identity_is_rejected_before_database_use(self) -> None:
        response = backend.app.test_client().get("/runs/4")
        self.assertEqual(response.status_code, 401)

    def test_non_operator_is_rejected_before_database_use(self) -> None:
        response = backend.app.test_client().get(
            "/runs/4",
            headers={
                "Cf-Access-Authenticated-User-Email": "wrong@sheboyganlights.org"
            },
        )
        self.assertEqual(response.status_code, 403)

    def test_parser_candidate_forwards_only_version_and_authenticated_actor(self) -> None:
        with patch.object(backend, "runner_request", return_value={"ok": True}) as runner:
            response = backend.app.test_client().post(
                "/parser/candidate",
                json={"new_lor_version": "6.6.10", "preview_folder": "C:\\unsafe"},
                headers={
                    "Cf-Access-Authenticated-User-Email": "greg@sheboyganlights.org"
                },
            )
        self.assertEqual(response.status_code, 200)
        runner.assert_called_once_with(
            "candidate",
            {
                "new_lor_version": "6.6.10",
                "actor": "greg@sheboyganlights.org",
            },
        )

    def test_parser_run_rejects_arbitrary_target(self) -> None:
        response = backend.app.test_client().post(
            "/parser/run",
            json={"target": "C:\\arbitrary\\command.exe"},
            headers={
                "Cf-Access-Authenticated-User-Email": "greg@sheboyganlights.org"
            },
        )
        self.assertEqual(response.status_code, 400)

    def test_parser_run_forwards_restricted_baseline_target(self) -> None:
        with patch.object(backend, "runner_request", return_value={"ok": True}) as runner:
            response = backend.app.test_client().post(
                "/parser/run",
                json={"target": "baseline"},
                headers={
                    "Cf-Access-Authenticated-User-Email": "greg@sheboyganlights.org"
                },
            )
        self.assertEqual(response.status_code, 200)
        runner.assert_called_once_with(
            "parser/run",
            {"target": "baseline", "actor": "greg@sheboyganlights.org"},
            timeout=920,
        )


if __name__ == "__main__":
    unittest.main()
