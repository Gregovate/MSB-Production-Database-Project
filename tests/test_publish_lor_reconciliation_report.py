import importlib.util
import subprocess
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch


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

    def test_evaluation_copy_renders_completed_run_without_database_write(self):
        data = self.base_data()
        data["run"]["status"] = "COMPLETED"

        class ReadOnlyConnection:
            def cursor(self):
                raise AssertionError("evaluation copy attempted a database write")

            def commit(self):
                raise AssertionError("evaluation copy attempted a database commit")

        with TemporaryDirectory() as output_dir, patch.object(
            REPORT, "collect_report_data", return_value=data
        ):
            path = REPORT.render_evaluation_copy(
                ReadOnlyConnection(), 101, output_dir
            )

            self.assertTrue(path.exists())
            self.assertTrue(path.name.endswith("-run-101-evaluation.html"))
            self.assertIn("LOR Production Reconciliation Report", path.read_text())

    def test_evaluation_copy_rejects_noncompleted_run(self):
        data = self.base_data()
        with TemporaryDirectory() as output_dir, patch.object(
            REPORT, "collect_report_data", return_value=data
        ):
            with self.assertRaisesRegex(RuntimeError, "not COMPLETED"):
                REPORT.render_evaluation_copy(object(), 101, output_dir)

    def test_report_framework_version_identifies_evaluation_copy_release(self):
        self.assertEqual(REPORT.REPORT_VERSION, "V0.4.0")

    def test_index_includes_existing_published_and_evaluation_reports(self):
        with TemporaryDirectory() as output_dir:
            directory = Path(output_dir)
            published = directory / "lor-reconciliation-20260803-233221-run-3.html"
            evaluation = directory / "lor-reconciliation-20260804-170000-run-3-evaluation.html"
            published.write_text(
                '<p class="meta">Generated 2026-08-03 23:32:21 CDT · '
                'Report framework V0.1.0 · Captured ingest 44</p>', encoding="utf-8"
            )
            evaluation.write_text(
                '<p class="meta">Generated 2026-08-04 17:00:00 CDT · '
                'Report framework V0.3.0 · Captured ingest 44</p>', encoding="utf-8"
            )

            index = REPORT.refresh_report_index(output_dir).read_text(encoding="utf-8")

            self.assertIn(published.name, index)
            self.assertIn(evaluation.name, index)
            self.assertIn("Published report", index)
            self.assertIn("Evaluation copy", index)
            self.assertIn("Captured ingest", index)
            self.assertLess(index.index(evaluation.name), index.index(published.name))

    def test_index_ignores_unrecognized_html_files(self):
        with TemporaryDirectory() as output_dir:
            directory = Path(output_dir)
            (directory / "unrelated.html").write_text("not a report", encoding="utf-8")

            index = REPORT.refresh_report_index(output_dir).read_text(encoding="utf-8")

            self.assertNotIn("unrelated.html", index)
            self.assertIn("No reconciliation reports are available", index)

    def test_refresh_index_cli_needs_no_database_arguments(self):
        with TemporaryDirectory() as output_dir:
            result = subprocess.run(
                [sys.executable, str(MODULE_PATH), "--output-dir", output_dir, "--refresh-index"],
                capture_output=True,
                check=False,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("REPORT_INDEX_PATH=", result.stdout)
            self.assertTrue((Path(output_dir) / "index.html").is_file())


if __name__ == "__main__":
    unittest.main()
