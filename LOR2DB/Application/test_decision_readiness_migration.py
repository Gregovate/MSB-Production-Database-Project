"""Static safety contracts for decision-readiness synchronization."""

from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]
MIGRATION = ROOT / "02_Reconciliation" / "reconciliation" / "migrations" / (
    "0034_sync_readiness_after_every_decision.sql"
)
VALIDATION = ROOT / "02_Reconciliation" / "reconciliation" / "validation" / (
    "29_decision_readiness_sync_validation.sql"
)


class DecisionReadinessMigrationTests(unittest.TestCase):
    def test_every_action_refreshes_readiness(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("AFTER INSERT ON ops.lor_reconciliation_action", source)
        self.assertIn("trg_sync_lor_reconciliation_readiness_after_action", source)
        self.assertIn("effective_resolution_state = 'UNRESOLVED'", source)
        self.assertIn("THEN 'READY_TO_FINISH'", source)

    def test_preflight_is_not_advanced_while_groups_are_forming(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn(
            "IF v_status IN ('AWAITING_DECISIONS', 'READY_TO_FINISH')",
            source,
        )
        self.assertNotIn("IF v_status IN ('PREFLIGHT'", source)

    def test_migration_repairs_existing_open_runs(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("Repair any open run", source)
        self.assertIn("FOR v_run_id IN", source)
        self.assertIn(
            "ops.f_sync_lor_reconciliation_effective_counters(v_run_id)",
            source,
        )

    def test_sync_never_calls_promotion(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8").lower()
        for procedure in (
            "p1_promote",
            "p2_promote",
            "p3_promote",
            "p4_promote",
            "p_finish_lor_reconciliation",
        ):
            with self.subTest(procedure=procedure):
                self.assertNotIn(procedure, source)

    def test_validation_is_read_only_and_checks_lifecycle(self) -> None:
        source = VALIDATION.read_text(encoding="utf-8")
        self.assertIn(
            "An open run lifecycle disagrees with its effective decisions",
            source,
        )
        self.assertIn("READY_TO_FINISH", source)
        self.assertNotIn("UPDATE ops.", source)
        self.assertNotIn("CALL ops.", source)


if __name__ == "__main__":
    unittest.main()
