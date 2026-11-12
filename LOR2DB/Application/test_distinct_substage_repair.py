import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
MIGRATION = (
    ROOT / "02_Reconciliation" / "reconciliation" / "migrations"
    / "0035_repair_distinct_substages_and_protect_display_stage.sql"
)
VALIDATION = (
    ROOT / "02_Reconciliation" / "reconciliation" / "validation"
    / "30_distinct_substage_and_stage_assignment_validation.sql"
)
FOLLOWUP_MIGRATION = (
    ROOT / "02_Reconciliation" / "reconciliation" / "migrations"
    / "0036_complete_stage05a_scene_repair.sql"
)
FOLLOWUP_VALIDATION = (
    ROOT / "02_Reconciliation" / "reconciliation" / "validation"
    / "31_complete_stage05a_scene_repair_validation.sql"
)
P1 = (
    ROOT / "02_Reconciliation" / "reconciliation" / "current_procedures"
    / "P1_stage_promotion.sql"
)
P2 = (
    ROOT / "02_Reconciliation" / "reconciliation" / "current_procedures"
    / "P2_display_promotion.sql"
)


class DistinctSubstageRepairTests(unittest.TestCase):
    def test_true_rename_requires_one_source_key(self):
        source = MIGRATION.read_text(encoding="utf-8")
        approve = source.split(
            "CREATE OR REPLACE FUNCTION ops.f_stage_group_can_approve_change", 1
        )[1].split(
            "CREATE OR REPLACE FUNCTION ops.f_stage_group_new_stage_key", 1
        )[0]
        self.assertIn("count(DISTINCT c.source_stage_key) = 1", approve)

    def test_new_substage_target_excludes_the_current_stage_key(self):
        source = MIGRATION.read_text(encoding="utf-8")
        target = source.split(
            "CREATE OR REPLACE FUNCTION ops.f_stage_group_new_stage_key", 1
        )[1].split(
            "CREATE OR REPLACE FUNCTION ops.f_stage_group_can_add_new_stage", 1
        )[0]
        self.assertIn("count(DISTINCT source_stage_key) = 2", target)
        self.assertIn(
            "source_stage_key IS DISTINCT FROM resolved_stage_key", target
        )

    def test_repair_is_exact_and_does_not_rewrite_snapshot_evidence(self):
        source = MIGRATION.read_text(encoding="utf-8")
        repair = source.split("DO $repair$", 1)[1]
        self.assertIn("v_restored_count <> 50", repair)
        self.assertIn("stage_lor_binding_id = 142", repair)
        self.assertIn("stage_lor_binding_id = 143", repair)
        self.assertNotIn("UPDATE lor_snap.", repair)
        self.assertNotIn("UPDATE ops.lor_reconciliation_stage_candidate", repair)
        self.assertNotIn("UPDATE ops.lor_reconciliation_display_candidate", repair)

    def test_p1_moves_only_the_target_source_key(self):
        source = P1.read_text(encoding="utf-8")
        self.assertIn("c.source_stage_key = v_group.stage_key", source)
        self.assertIn("accepted_source_stage_key", source)

    def test_p2_resolves_stage_by_key_and_rejects_null_resolution(self):
        source = P2.read_text(encoding="utf-8")
        self.assertIn("AS effective_stage_id", source)
        self.assertIn("stage_by_key.stage_key", source)
        self.assertIn(
            "P2 cannot resolve one or more approved source StageIDs", source
        )
        self.assertNotIn("stage_id = v_row.proposed_stage_id", source)

    def test_validation_checks_frozen_keys_and_repaired_assignments(self):
        source = VALIDATION.read_text(encoding="utf-8")
        self.assertIn("source_stage_key = '05'", source)
        self.assertIn("source_stage_key = '05a'", source)
        self.assertIn("display_id = 869", source)
        self.assertNotIn("UPDATE ", source.upper())

    def test_followup_moves_only_the_exact_permanent_scene(self):
        source = FOLLOWUP_MIGRATION.read_text(encoding="utf-8")
        repair = source.split("DO $repair$", 1)[1]
        self.assertIn("UPDATE ref.lor_scene", repair)
        self.assertIn("d57761f7-3527-4b00-a8ce-2eeb70eb3d8c", repair)
        self.assertIn("05a-Mega Star-MS", repair)
        self.assertIn("v_updated_count <> 1", repair)
        self.assertNotIn("UPDATE lor_snap.", repair)
        self.assertNotIn("UPDATE ops.lor_reconciliation_", repair)

    def test_followup_validation_checks_scene_and_remains_read_only(self):
        source = FOLLOWUP_VALIDATION.read_text(encoding="utf-8")
        self.assertIn("FROM ref.lor_scene", source)
        self.assertIn("ls.stage_id = v_stage_05a", source)
        self.assertIn("ls.stage_id = v_stage_05", source)
        self.assertNotIn("UPDATE ", source.upper())


if __name__ == "__main__":
    unittest.main()
