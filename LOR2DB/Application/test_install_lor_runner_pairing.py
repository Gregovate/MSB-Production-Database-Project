"""Safety tests for the Linux-side runner pairing installer."""

from __future__ import annotations

import os
from pathlib import Path
import stat
import tempfile
import unittest

from install_lor_runner_pairing import (
    credential_fingerprint,
    install_pairing,
    upsert_environment,
    validate_runner_url,
)


class RunnerPairingInstallerTests(unittest.TestCase):
    def test_environment_upsert_replaces_without_duplicates(self) -> None:
        result = upsert_environment(
            "KEEP=value\nLOR_RUNNER_TOKEN=old\nLOR_RUNNER_TOKEN=duplicate\n",
            {
                "LOR_RUNNER_URL": "http://192.168.5.55:8791",
                "LOR_RUNNER_TOKEN": "a" * 64,
            },
        )
        self.assertEqual(result.count("LOR_RUNNER_TOKEN="), 1)
        self.assertEqual(result.count("LOR_RUNNER_URL="), 1)
        self.assertIn("KEEP=value", result)

    @unittest.skipUnless(
        hasattr(os, "getuid") and hasattr(os, "chown"),
        "requires POSIX ownership semantics",
    )
    def test_installer_is_atomic_preserves_mode_and_consumes_pending(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            pending = root / "pending"
            environment = root / "api.env"
            token = "b" * 64
            pending.write_text(token + "\n", encoding="utf-8")
            environment.write_text("KEEP=value\n", encoding="utf-8")
            pending.chmod(0o600)
            environment.chmod(0o640)

            backup, fingerprint = install_pairing(
                pending,
                environment,
                "http://192.168.5.55:8791",
                expected_pending_uid=os.getuid(),
            )

            self.assertFalse(pending.exists())
            self.assertTrue(backup.is_file())
            self.assertEqual(stat.S_IMODE(environment.stat().st_mode), 0o640)
            installed = environment.read_text(encoding="utf-8")
            self.assertIn("LOR_RUNNER_URL=http://192.168.5.55:8791", installed)
            self.assertIn(f"LOR_RUNNER_TOKEN={token}", installed)
            self.assertEqual(fingerprint, credential_fingerprint(token))
            self.assertNotIn(token, str(backup))

    def test_installer_rejects_exposed_pending_secret(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            pending = root / "pending"
            environment = root / "api.env"
            pending.write_text("c" * 64, encoding="utf-8")
            environment.write_text("KEEP=value\n", encoding="utf-8")
            pending.chmod(0o644)
            with self.assertRaisesRegex(RuntimeError, "group or others"):
                install_pairing(
                    pending,
                    environment,
                    "http://192.168.5.55:8791",
                )

    def test_runner_url_must_be_private_fixed_port(self) -> None:
        self.assertEqual(
            validate_runner_url("http://192.168.5.55:8791"),
            "http://192.168.5.55:8791",
        )
        for invalid in (
            "https://192.168.5.55:8791",
            "http://example.com:8791",
            "http://8.8.8.8:8791",
            "http://192.168.5.55:80",
            "http://user:pass@192.168.5.55:8791",
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                validate_runner_url(invalid)


if __name__ == "__main__":
    unittest.main()
