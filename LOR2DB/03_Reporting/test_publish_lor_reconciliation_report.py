import importlib.util
import subprocess
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("publish_lor_reconciliation_report.py")
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
            "scene_backgrounds": [{
                "preview_id": "preview-uuid",
                "scene_id": "scene-uuid-1",
                "preview_name": "Stage 01",
                "scene_name": "Scene with background",
                "preview_stage_id": "01",
                "scene_stage_id": "01",
                "report_stage_id": "01",
                "background_file": r"G:\Backgrounds\stage-01.jpg",
                "stage_name": "Stage 01",
            }, {
                "preview_id": "preview-uuid",
                "scene_id": "scene-uuid-2",
                "preview_name": "Stage 01",
                "scene_name": "Scene without background",
                "preview_stage_id": "01",
                "scene_stage_id": "01",
                "report_stage_id": "01",
                "background_file": None,
                "stage_name": "Stage 01",
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

    def test_report_has_dashboard_navigation(self):
        output = REPORT.render_report(self.base_data(), datetime.now(timezone.utc))

        self.assertIn('href="../">Return to LOR2DB dashboard</a>', output)

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

    def test_manifest_is_sorted_naturally_by_stage(self):
        data = self.base_data()
        data["previews"] = [
            {"source_filename": "Stage 10.lorprev", "preview_revision": 1,
             "preview_name": "Stage 10", "stage_id": "10", "preview_id": "p10",
             "brightness": 20, "background_file": None},
            {"source_filename": "Stage 05a.lorprev", "preview_revision": 1,
             "preview_name": "Stage 05a", "stage_id": "05a", "preview_id": "p05a",
             "brightness": 20, "background_file": None},
            {"source_filename": "Stage 02.lorprev", "preview_revision": 1,
             "preview_name": "Stage 02", "stage_id": "02", "preview_id": "p02",
             "brightness": 20, "background_file": None},
        ]

        output = REPORT.render_report(data, datetime.now(timezone.utc))

        self.assertLess(output.index("Stage 02.lorprev"), output.index("Stage 05a.lorprev"))
        self.assertLess(output.index("Stage 05a.lorprev"), output.index("Stage 10.lorprev"))

    def test_report_uses_scene_background_coverage_not_preview_background(self):
        output = REPORT.render_report(self.base_data(), datetime.now(timezone.utc))

        self.assertIn("1 of 2 Scenes", output)
        self.assertIn("Scene without an assigned background", output)
        self.assertIn("Scene without background", output)
        self.assertNotIn("G:\\Backgrounds\\stage-01.jpg", output)
        self.assertNotIn("<th>Background file</th>", output)

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
        self.assertEqual(REPORT.REPORT_VERSION, "V0.5.2")

    def test_cancelled_report_is_terminal_and_has_no_required_actions(self):
        data = self.base_data()
        data["run"].update({
            "cancelled_at": datetime.now(timezone.utc),
            "cancellation_reason": "Correct the LOR source and re-ingest.",
            "validation_state": None,
        })
        data["problems"] = [{
            "entity_type": "DISPLAY", "entity_key": "1",
            "result_class": "BLOCKED", "reason_code": "CORRECT_SOURCE_REQUIRED",
            "operator_message": "Fix source", "recorded_at": None,
        }]

        output = REPORT.render_report(data, datetime.now(timezone.utc))

        self.assertIn('data-report-outcome="CANCELLED"', output)
        self.assertIn("CANCELLED — NO PRODUCTION CHANGES COMMITTED", output)
        self.assertIn("captured ingest snapshot was removed", output)
        self.assertIn("Not applicable — reconciliation cancelled", output)
        self.assertNotIn("Review listed items", output)

    def test_decision_operator_uses_authenticated_cloudflare_email(self):
        data = self.base_data()
        data["decisions"] = [{
            "logical_group_key": "DISPLAY:1",
            "action_type": "ADD_NEW_DISPLAY",
            "reason": "Approved",
            "acted_by": "msbadmin",
            "acted_by_application": "lor-preflight-api:greg@example.com",
            "acted_at": datetime.now(timezone.utc),
        }]
        output = REPORT.render_report(data, datetime.now(timezone.utc))
        self.assertIn("greg@example.com", output)
        self.assertNotIn(">msbadmin<", output)

    def test_index_includes_existing_published_and_evaluation_reports(self):
        with TemporaryDirectory() as output_dir:
            directory = Path(output_dir)
            published = directory / "lor-reconciliation-20260803-233221-run-3.html"
            evaluation = directory / "lor-reconciliation-20260804-170000-run-3-evaluation.html"
            published.write_text(
                '<body data-report-outcome="COMPLETED"><p class="meta">Generated 2026-08-03 23:32:21 CDT · '
                'Report framework V0.1.0 · Captured ingest 44</p>', encoding="utf-8"
            )
            evaluation.write_text(
                '<body data-report-outcome="CANCELLED"><p class="meta">Generated 2026-08-04 17:00:00 CDT · '
                'Report framework V0.3.0 · Captured ingest 44</p>', encoding="utf-8"
            )

            index = REPORT.refresh_report_index(output_dir).read_text(encoding="utf-8")

            self.assertIn(published.name, index)
            self.assertIn(evaluation.name, index)
            self.assertIn("Published report", index)
            self.assertIn("Evaluation copy", index)
            self.assertIn("Captured ingest", index)
            self.assertIn("Outcome", index)
            self.assertIn("CANCELLED", index)
            self.assertIn("Return to LOR2DB dashboard", index)
            self.assertLess(index.index(evaluation.name), index.index(published.name))

    def test_index_ignores_unrecognized_html_files(self):
        with TemporaryDirectory() as output_dir:
            directory = Path(output_dir)
            (directory / "unrelated.html").write_text("not a report", encoding="utf-8")

            index = REPORT.refresh_report_index(output_dir).read_text(encoding="utf-8")

            self.assertNotIn("unrelated.html", index)
            self.assertIn("No reconciliation reports are available", index)

    def test_index_recovers_cancelled_outcome_from_legacy_report(self):
        with TemporaryDirectory() as output_dir:
            path = Path(output_dir) / "lor-reconciliation-20260814-011807-run-6.html"
            path.write_text(
                '<p class="meta">Generated 2026-08-14 01:18:07 UTC · '
                'Report framework V0.4.2 · Captured ingest 47</p>'
                '<table><tr><td>6</td><td>CANCELLED</td></tr></table>',
                encoding="utf-8",
            )

            index = REPORT.refresh_report_index(output_dir).read_text(encoding="utf-8")

            self.assertIn("CANCELLED", index)
            self.assertNotIn("UNKNOWN", index)

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
