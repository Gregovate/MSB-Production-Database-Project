"""Regression contract for the parser page's single-submit ingest approval."""

from __future__ import annotations

import unittest
from pathlib import Path


class ParserIngestSingleSubmitTests(unittest.TestCase):
    def test_approval_click_is_the_ingest_submit(self) -> None:
        parser_dir = Path(__file__).parent / "landing" / "parser"
        source = (parser_dir / "parser.js").read_text(encoding="utf-8")
        page = (parser_dir / "index.html").read_text(encoding="utf-8")
        run_start = source.index("  async function runIngest(event) {")
        run_end = source.index("  async function startReconciliation(event) {")
        run_ingest = source[run_start:run_end]

        self.assertIn(
            '<button id="run-ingest" class="primary" type="button">Parser output looks correct — ready for ingest</button>',
            source,
        )
        self.assertNotIn('id="mark-ready-ingest"', source)
        self.assertNotIn('querySelector("#mark-ready-ingest")', source)
        self.assertIn(
            'document.querySelector("#run-ingest")?.addEventListener("click", runIngest);',
            source,
        )
        self.assertIn("reviewedDigest = digest;", run_ingest)
        self.assertIn("reviewedParserActivityId = parserActivityId;", run_ingest)
        self.assertNotIn("reviewedDigest !== digest", run_ingest)
        self.assertNotIn("reviewedParserActivityId !== parserActivityId", run_ingest)
        self.assertIn('"ingest/start"', run_ingest)
        self.assertIn("request_id: requestId", run_ingest)
        self.assertIn("parser_activity_id: parserActivityId", run_ingest)
        self.assertIn("expected_sqlite_sha256: digest", run_ingest)
        self.assertLess(
            run_ingest.index("reviewedDigest = digest;"),
            run_ingest.index('"ingest/start"'),
        )
        self.assertIn('parser.js?v=0.6.2.1', page)


if __name__ == "__main__":
    unittest.main()
