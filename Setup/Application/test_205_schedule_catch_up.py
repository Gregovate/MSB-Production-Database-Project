"""Run the real scheduling dialog JavaScript where Node is available."""
from pathlib import Path
import shutil
import subprocess
import pytest


def test_schedule_catch_up():
    # Production previews have Python but do not require a Node installation.
    # Local engineering and CI execute this same JavaScript regression.
    node = shutil.which('node')
    if not node:
        pytest.skip('Node unavailable in this runtime; CI runs executable dialog checks')
    subprocess.run([node, str(Path(__file__).with_suffix('.cjs'))], check=True)
