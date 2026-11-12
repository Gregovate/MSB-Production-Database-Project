"""Static contracts for migration 0038 SPARE/Display lifecycle handling."""

from __future__ import annotations

import unittest
from pathlib import Path


LOR2DB_ROOT = Path(__file__).parents[1]
MIGRATION = (
    LOR2DB_ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "migrations"
    / "0038_allow_spare_to_display_activation.sql"
)
VALIDATION = (
    LOR2DB_ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "validation"
    / "33_spare_to_display_activation_validation.sql"
)


class SpareDisplayLifecycleMigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.migration = MIGRATION.read_text(encoding="utf-8")
        cls.validation = VALIDATION.read_text(encoding="utf-8")

    def test_duplicate_counts_include_only_physical_rows(self) -> None:
        source_view = self.migration.split(
            "CREATE OR REPLACE VIEW lor_snap.v_display_reconciliation_source AS",
            1,
        )[1].split(
            "CREATE OR REPLACE VIEW ops.v_lor_display_reconciliation AS",
            1,
        )[0]
        physical_filter = "WHERE NOT is_spare AND NOT is_phantom"
        self.assertEqual(source_view.count(physical_filter), 3)
        self.assertIn("count(*) FILTER", source_view)
        self.assertIn("count(DISTINCT display_name_normalized) FILTER", source_view)
        self.assertIn("count(DISTINCT lor_prop_id) FILTER", source_view)

    def test_nonphysical_classification_precedes_duplicate_checks(self) -> None:
        reconciliation_view = self.migration.split(
            "CREATE OR REPLACE VIEW ops.v_lor_display_reconciliation AS",
            1,
        )[1].split(
            "CREATE OR REPLACE FUNCTION ops.f_start_lor_display_reconciliation(",
            1,
        )[0]
        excluded = reconciliation_view.index(
            "WHEN swm.is_spare OR swm.is_phantom"
        )
        duplicate = reconciliation_view.index(
            "WHEN swm.lor_uuid_name_count > 1"
        )
        self.assertLess(excluded, duplicate)

    def test_occurrence_evidence_is_scoped_by_uuid_and_name(self) -> None:
        self.assertIn(
            "GROUP BY\n        o.import_run_id,\n        o.lor_prop_id,\n"
            "        o.display_name_normalized",
            self.migration,
        )
        self.assertIn(
            "os.display_name_normalized IS NOT DISTINCT FROM\n"
            "         swm.display_name_normalized",
            self.migration,
        )

    def test_nonphysical_rows_cannot_join_physical_identity_groups(self) -> None:
        self.assertIn(
            "WHERE r.classification_code <> 'EXCLUDED_NONPHYSICAL'",
            self.migration,
        )
        self.assertIn(
            "THEN format('NONPHYSICAL:%s', r.source_prop_id)",
            self.migration,
        )

    def test_validation_covers_both_triggering_lifecycle_directions(self) -> None:
        self.assertIn("invalid_physical_count_assignment", self.validation)
        self.assertIn("invalid_nonphysical_classification_count", self.validation)
        self.assertIn("CL-LOLLIPOPSTICK-01", self.validation)
        self.assertIn("FC-METROHEATLAMP", self.validation)

    def test_validation_is_read_only(self) -> None:
        source = self.validation.upper()
        for token in (
            "INSERT ",
            "UPDATE ",
            "DELETE ",
            "ALTER ",
            "CREATE ",
            "DROP ",
            "TRUNCATE ",
            "CALL ",
        ):
            self.assertNotIn(token, source)


if __name__ == "__main__":
    unittest.main()
