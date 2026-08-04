import importlib.util
import unittest
from datetime import datetime, timezone
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "tools" / "publish_lor_reconciliation_report.py"
SPEC = importlib.util.spec_from_file_location("lor_report", MODULE_PATH)
REPORT = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(REPORT)


class ReportRenderingTests(unittest.TestCase):
    def base_data(self):
        run = {
            "lor_reconciliation_run_id": 101,
            "import_run_id": 202,
            "status": "REPORTING",
            "validation_state": "PASSED",
            "parser_completed_at": datetime(2026, 8, 3, 20, 0, tzinfo=timezone.utc),
            "parser_version": "V7-test",
            "parser_actor": "operator",
            "parser_host": "master-pc",
            "preview_count": 1,
            "scene_count": 2,
            "prop_count": 3,
            "sub_prop_count": 4,
            "dmx_channel_count": 5,
            "scene_lor_prop_count": 6,
            "ingest_completed_at": datetime(2026, 8, 3, 20, 5, tzinfo=timezone.utc),
            "ingest_script_version": "V0.3.2",
            "ingest_actor": "operator",
            "ingest_host": "master-pc",
            "source_preview_folder": r"G:\Production Previews",
        }
        return {
            "run": run,
            "previews": [{
                "source_filename": "Stage 01.lorprev",
                "preview_revision": "12",
                "preview_name": "Stage 01",
                "stage_id": "01",
                "preview_id": "preview-uuid",
                "brightness": 100,
                "background_file": None,
            }],
            "changes": [], "names": [], "problems": [],
            "display_names": {}, "preview_names": {"preview-uuid": "Stage 01"},
            "stage_names": {}, "scene_names": {},
            "decisions": [],
            "validations": [{
                "validation_check": "FINISH_POST_WRITE_VALIDATION_PASSED",
                "result": "PASS",
                "detail": "All checks passed.",
                "recorded_at": datetime(2026, 8, 3, 20, 6, tzinfo=timezone.utc),
            }],
        }

    def test_all_six_sections_are_always_present(self):
        output = REPORT.render_report(self.base_data(), datetime.now(timezone.utc))
        headings = [
            "1. Parser Run", "2. PostgreSQL Ingest", "3. Source Preview Files",
            "4. Changes Made and Required Actions",
            "5. Problems and Operator Decisions", "6. Final Validation",
        ]
        positions = [output.index(heading) for heading in headings]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("No display-name changes were committed.", output)
        self.assertIn("No other production changes were committed.", output)
        self.assertIn("No blocked, deferred, unresolved, or failed items.", output)
        self.assertIn("No operator decisions were required.", output)

    def test_name_change_produces_label_action(self):
        data = self.base_data()
        data["names"] = [{
            "display_id": 123,
            "before_name": "Old",
            "after_name": "New",
            "action_required": "Print replacement label",
        }]
        output = REPORT.render_report(data, datetime.now(timezone.utc))
        self.assertIn("Print replacement labels", output)
        self.assertIn("Print replacement label", output)

    def test_manifest_hides_uuid_and_formats_whole_numbers_as_integers(self):
        data = self.base_data()
        data["previews"][0]["preview_revision"] = "12.0"
        data["previews"][0]["brightness"] = 20.0
        output = REPORT.render_report(data, datetime.now(timezone.utc))
        self.assertNotIn("Preview UUID", output)
        self.assertNotIn("20.0", output)
        self.assertIn(">20<", output)

    def test_changes_use_human_readable_display_and_scene_keys(self):
        data = self.base_data()
        data["display_names"] = {"920": "WA-WelcomeTo-01"}
        data["scene_names"] = {("preview-uuid", "scene-uuid"): {
            "scene_name": "Welcome Area", "preview_name": "Stage 01",
            "stage_name": "Welcome Area",
        }}
        data["changes"] = [
            {"entity_type": "DISPLAY", "entity_key": "920", "result_class": "UPDATED",
             "reason_code": "P2_AUTO_APPROVED", "operator_message": "internal", "recorded_at": None},
            {"entity_type": "SCENE", "entity_key": "SCENE:preview-uuid:scene-uuid",
             "result_class": "ADDED", "reason_code": "P3_ADD_SCENE",
             "operator_message": "internal UUID detail", "recorded_at": None},
        ]
        output = REPORT.render_report(data, datetime.now(timezone.utc))
        self.assertIn("920-WA-WelcomeTo-01", output)
        self.assertIn("SCENE: Welcome Area", output)
        self.assertIn('Synchronized scene &quot;Welcome Area&quot;', output)
        self.assertNotIn("scene-uuid", output)

    def test_database_text_is_html_escaped(self):
        data = self.base_data()
        data["previews"][0]["preview_name"] = "<script>alert(1)</script>"
        output = REPORT.render_report(data, datetime.now(timezone.utc))
        self.assertNotIn("<script>alert(1)</script>", output)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", output)

    def test_problem_query_uses_effective_state_not_frozen_candidate_flag(self):
        source = MODULE_PATH.read_text(encoding="utf-8")
        problem_query = source.split("problems = rows(cur,", 1)[1].split(
            "decisions = rows(cur,", 1
        )[0]

        self.assertIn("effective_resolution_state", problem_query)
        self.assertNotIn("is_blocking", problem_query)


if __name__ == "__main__":
    unittest.main()
