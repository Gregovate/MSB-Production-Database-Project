"""Contract tests: compliant evidence passes and common omissions fail."""
import unittest
from check_engineering_compliance import validate, RULES

BASE = """Design authority: Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md
Implementation scope: Only authorized Work Orders preview behavior is modified.
Regression evidence: Complete required suite plus focused negative tests.
Acceptance status: Browser acceptance pending; Production remains untouched.
Runbook / existing mechanism: Server Management disposable PostgreSQL standard is reused.
Infrastructure reuse / exception: Existing runner reused; no new server infrastructure.
"""


class ComplianceTests(unittest.TestCase):
    def test_complete_protected_change(self):
        self.assertEqual([], validate(["WorkOrders/Acceptance/example.sh"], BASE, set(RULES)))

    def test_missing_design_reference(self):
        invalid = BASE.replace(
            "Design authority: Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md",
            "Design authority: PR #420"
        )
        self.assertTrue(validate(["WorkOrders/Acceptance/example.sh"], invalid, set(RULES)))

    def test_empty_evidence_rejected(self):
        self.assertTrue(validate([".github/workflows/foo.yml"], "", set(RULES)))

    def test_infrastructure_exception_required(self):
        invalid = BASE.replace(
            "Infrastructure reuse / exception: Existing runner reused; no new server infrastructure.", "")
        self.assertTrue(validate(["Setup/Acceptance/runner.sh"], invalid, set(RULES)))

    def test_implementation_requires_documentation(self):
        self.assertTrue(validate(["WorkOrders/Application/backend.py"], BASE, set(RULES)))
        self.assertEqual([], validate(
            ["WorkOrders/Application/backend.py",
             "Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md"],
            BASE, set(RULES)))

    def test_missing_existing_standard_rejected(self):
        self.assertTrue(validate(["WorkOrders/Acceptance/example.sh"], BASE, set(RULES[:-1])))


if __name__ == "__main__":
    unittest.main()
