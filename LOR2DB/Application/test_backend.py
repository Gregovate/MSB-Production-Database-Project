"""Unit smoke tests for the LOR preflight API's non-database safety rules."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("LOR_PREFLIGHT_OPERATORS", "greg@sheboyganlights.org")

import backend  # noqa: E402  (environment must exist before app import)


class BackendSafetyTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
