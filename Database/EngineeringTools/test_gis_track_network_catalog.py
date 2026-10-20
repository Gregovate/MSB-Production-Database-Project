"""Network choices come from existing PostgreSQL IDs, with read-only refresh."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import gis_network_catalog as catalog

class NetworkCatalogTests(unittest.TestCase):
    def test_read_only_refresh_preserves_real_ids(self):
        data=dict(format_version=1,data_mode="postgres",revision="row-hash",fetched_at="2026-10-20T16:51:24Z",
                  networks=[dict(site_network_id=19,network_code="SPARE-1",network_kind="OTHER")])
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"catalog.json"
            with patch.object(catalog,"cache_path",return_value=path), patch.object(catalog.subprocess,"run",return_value=SimpleNamespace(returncode=0,stdout=json.dumps(data))) as run:
                result=catalog.refresh()
            self.assertEqual(result["networks"][0]["site_network_id"],19)
            self.assertEqual(json.loads(path.read_text()),data)
            self.assertIn("BEGIN READ ONLY",run.call_args.kwargs["input"])
            self.assertIn("FROM ref.site_network",run.call_args.kwargs["input"])
            self.assertNotIn("shell",run.call_args.kwargs)
            self.assertEqual(run.call_args.kwargs["timeout"],20)
            self.assertIn("BatchMode=yes",run.call_args.args[0])

    def test_failed_refresh_keeps_saved_table(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"catalog.json";path.write_bytes(b"saved table")
            with patch.object(catalog,"cache_path",return_value=path), patch.object(catalog.subprocess,"run",return_value=SimpleNamespace(returncode=1,stdout="")):
                with self.assertRaisesRegex(ValueError,"last verified table"):catalog.refresh()
            self.assertEqual(path.read_bytes(),b"saved table")

    def test_invalid_refresh_cannot_replace_table(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"catalog.json";path.write_bytes(b"saved table")
            with patch.object(catalog,"cache_path",return_value=path), patch.object(catalog.subprocess,"run",return_value=SimpleNamespace(returncode=0,stdout='{}')):
                with self.assertRaises(ValueError):catalog.refresh()
            self.assertEqual(path.read_bytes(),b"saved table")
