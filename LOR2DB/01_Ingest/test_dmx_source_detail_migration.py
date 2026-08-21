"""Static contract tests for the V7.0.11 DMX PostgreSQL propagation artifacts."""

from __future__ import annotations

import unittest
from pathlib import Path


LOR2DB_ROOT = Path(__file__).parents[1]
REPO_ROOT = LOR2DB_ROOT.parent
MIGRATION = (
    LOR2DB_ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "migrations"
    / "0037_add_dmx_source_detail.sql"
)
VALIDATION = (
    LOR2DB_ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "validation"
    / "32_dmx_source_detail_validation.sql"
)
REFERENCE_DDL = (
    REPO_ROOT
    / "Database"
    / "Basic_Query_Tools_Dev"
    / "DDL_lor_snap.dmx_channels.sql"
)


class DmxSourceDetailMigrationTests(unittest.TestCase):
    def test_migration_is_additive_without_historical_backfill(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("ADD COLUMN IF NOT EXISTS raw_prop_id TEXT", source)
        self.assertIn("ADD COLUMN IF NOT EXISTS channel_name TEXT", source)
        self.assertIn(
            "ADD COLUMN IF NOT EXISTS channel_grid_row_number INTEGER", source
        )
        self.assertNotIn("UPDATE lor_snap.dmx_channels", source)
        self.assertNotIn("INSERT INTO lor_snap.dmx_channels", source)
        self.assertNotIn("DELETE FROM lor_snap.dmx_channels", source)
        self.assertNotIn("NOT NULL", source.split("ALTER TABLE", 1)[1].split("COMMENT", 1)[0])

    def test_current_view_appends_new_fields_after_legacy_contract(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        view = source.split(
            "CREATE OR REPLACE VIEW lor_snap.v_current_dmx_channels AS", 1
        )[1].split("ALTER VIEW", 1)[0]
        expected_order = [
            "dc.import_run_id",
            "dc.int_dmx_channel_id",
            "dc.prop_id",
            "dc.network",
            "dc.start_universe",
            "dc.start_channel",
            "dc.end_channel",
            "dc.unknown",
            "dc.preview_id",
            "dc.raw_prop_id",
            "dc.channel_name",
            "dc.channel_grid_row_number",
        ]
        positions = [view.index(item) for item in expected_order]
        self.assertEqual(positions, sorted(positions))

    def test_current_view_reasserts_owner_and_read_grant(self) -> None:
        migration = MIGRATION.read_text(encoding="utf-8")
        validation = VALIDATION.read_text(encoding="utf-8")
        self.assertIn(
            "ALTER VIEW lor_snap.v_current_dmx_channels OWNER TO msbadmin;",
            migration,
        )
        self.assertIn(
            "GRANT SELECT ON lor_snap.v_current_dmx_channels TO directus_app;",
            migration,
        )
        self.assertIn("pg_get_userbyid(c.relowner) AS owner_name", validation)
        self.assertIn("has_table_privilege(", validation)
        self.assertIn("'directus_app'", validation)

    def test_migration_does_not_replace_legacy_wiring_views(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8")
        self.assertNotIn("CREATE OR REPLACE VIEW lor_snap.preview_wiring_", source)
        self.assertNotIn("DROP VIEW", source.upper())

    def test_raw_prop_id_is_not_made_a_foreign_key(self) -> None:
        migration = MIGRATION.read_text(encoding="utf-8")
        ddl = REFERENCE_DDL.read_text(encoding="utf-8")
        self.assertNotIn("FOREIGN KEY (import_run_id, raw_prop_id)", migration)
        self.assertNotIn("FOREIGN KEY (import_run_id, raw_prop_id)", ddl)
        self.assertIn("FOREIGN KEY (import_run_id, prop_id)", ddl)
        self.assertIn("FOREIGN KEY (import_run_id, preview_id)", ddl)

    def test_validation_script_is_read_only(self) -> None:
        source = VALIDATION.read_text(encoding="utf-8").upper()
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

    def test_validation_gates_source_detail_completeness_at_v7011(self) -> None:
        source = VALIDATION.read_text(encoding="utf-8")
        self.assertIn("dmx_source_detail_required", source)
        self.assertIn(">= ARRAY[7, 0, 11]", source)
        self.assertIn("WHEN r.parser_version ~", source)
        self.assertIn("ELSE false", source)
        self.assertIn(
            "WHERE dmx_source_detail_required\n          AND (raw_prop_id IS NULL",
            source,
        )
        self.assertIn(
            "WHERE dmx_source_detail_required\n          AND (channel_name IS NULL",
            source,
        )
        self.assertIn(
            "WHERE dmx_source_detail_required\n          AND (\n              channel_grid_row_number IS NULL",
            source,
        )


if __name__ == "__main__":
    unittest.main()
