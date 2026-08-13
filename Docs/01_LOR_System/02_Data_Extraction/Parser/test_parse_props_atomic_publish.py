"""Atomic SQLite publication regression tests for the canonical V7 parser."""

from __future__ import annotations

import errno
import unittest
from pathlib import Path
from unittest.mock import call, patch

import parse_props_v7_scene_parser as parser


class ParserAtomicPublishTests(unittest.TestCase):
    def test_transient_file_lock_is_retried_then_published(self) -> None:
        source = Path("candidate.db")
        destination = Path("published.db")
        locked = PermissionError(errno.EACCES, "temporarily locked")

        with (
            patch.object(parser.os, "replace", side_effect=[locked, locked, None]) as replace,
            patch.object(parser.time, "sleep") as sleep,
        ):
            parser.replace_with_lock_retry(
                source,
                destination,
                attempts=4,
                initial_delay_seconds=0.1,
            )

        self.assertEqual(replace.call_count, 3)
        replace.assert_has_calls([call(source, destination)] * 3)
        sleep.assert_has_calls([call(0.1), call(0.2)])

    def test_non_lock_file_error_is_not_retried(self) -> None:
        source = Path("missing.db")
        destination = Path("published.db")
        missing = FileNotFoundError(errno.ENOENT, "missing")

        with (
            patch.object(parser.os, "replace", side_effect=missing) as replace,
            patch.object(parser.time, "sleep") as sleep,
        ):
            with self.assertRaises(FileNotFoundError):
                parser.replace_with_lock_retry(source, destination)

        replace.assert_called_once_with(source, destination)
        sleep.assert_not_called()


if __name__ == "__main__":
    unittest.main()
