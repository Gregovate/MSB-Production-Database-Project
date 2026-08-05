"""Unit smoke tests for the LOR preflight API's non-database safety rules."""

from __future__ import annotations

import os
import unittest

os.environ.setdefault("LOR_PREFLIGHT_OPERATORS", "greg@sheboyganlights.org")

import backend  # noqa: E402  (environment must exist before app import)


class BackendSafetyTests(unittest.TestCase):
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
