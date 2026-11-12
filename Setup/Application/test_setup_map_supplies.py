"""Regression for the field-reported panel/waypoint popup disagreement."""
from pathlib import Path
import shutil
import subprocess
import pytest


def test_map_supplies_use_snapshot_primary_keys_and_explicit_panel_outlets():
    node = shutil.which('node')
    if not node:
        pytest.skip('Node required for actual map renderer regression')
    subprocess.run([node, str(Path(__file__).with_suffix('.cjs'))], check=True)
