"""Windows console-encoding regression test for the canonical V7 parser."""

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path


PARSER_PATH = Path(__file__).with_name("parse_props_v7_scene_parser.py")


class ParserConsoleEncodingTests(unittest.TestCase):
    def test_ascii_redirect_cannot_abort_unicode_diagnostic(self) -> None:
        """Import-time configuration must escape characters absent from ASCII."""
        script = (
            "import runpy; "
            f"runpy.run_path({str(PARSER_PATH)!r}, run_name='parser_encoding_test'); "
            "print('parser output \\u2192 review log')"
        )
        environment = os.environ.copy()
        environment["PYTHONIOENCODING"] = "ascii:strict"
        completed = subprocess.run(
            [sys.executable, "-c", script],
            env=environment,
            capture_output=True,
            check=False,
        )
        self.assertEqual(
            completed.returncode,
            0,
            completed.stderr.decode(errors="replace"),
        )
        self.assertIn(b"parser output \\u2192 review log", completed.stdout)


if __name__ == "__main__":
    unittest.main()
