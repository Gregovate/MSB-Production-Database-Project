"""Static safety contracts for reconciliation migration 0032.

The transactional PostgreSQL validation script exercises the installed
objects.  These fast repository tests prevent accidental removal of the
evidence gates, permanent-ID preservation, or least-privilege grant.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]
MIGRATION = ROOT / "02_Reconciliation" / "reconciliation" / "migrations" / (
    "0032_add_safe_stage_authority_and_terminal_cancel.sql"
)
GRANTS = ROOT / "Application" / "grant_lor_preflight_app.sql"


class StageAuthorityMigrationTests(unittest.TestCase):
    def test_contradictory_evidence_is_not_approvable(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("count(DISTINCT c.proposed_stage_key) = 1", source)
        self.assertIn("count(DISTINCT ops.f_normalize_lor_stage_name", source)
        self.assertIn("BINDING_STAGE_KEY_CONFLICT", source)
        self.assertIn("SOURCE_FILENAME_MISSING", source)

    def test_existing_stage_change_preserves_stage_id(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("APPROVE_STAGE_CHANGE", source)
        self.assertIn("p1_promote_stage_from_reconciliation_before_0032", source)

    def test_new_stage_gets_permanent_row_and_stable_bindings(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("f_normalize_lor_stage_name", source)
        self.assertIn("source_stage_key", source)
        self.assertIn("INSERT INTO ref.stage (", source)
        self.assertIn("RETURNING stage_id INTO v_stage_id", source)
        self.assertIn("INSERT INTO ref.stage_lor_binding", source)

    def test_application_role_can_call_only_the_authority_recorder(self) -> None:
        source = GRANTS.read_text(encoding="utf-8")
        self.assertIn(
            "ops.f_record_lor_stage_authority_action(bigint,bigint,text,text,text)",
            source,
        )

    def test_cancelled_runs_receive_a_terminal_completion_timestamp(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("f_set_cancelled_reconciliation_completed_at", source)
        self.assertIn("NEW.status = 'CANCELLED'", source)
        self.assertIn("WHERE status = 'CANCELLED'", source)
        self.assertIn("AND completed_at IS NULL", source)


if __name__ == "__main__":
    unittest.main()
