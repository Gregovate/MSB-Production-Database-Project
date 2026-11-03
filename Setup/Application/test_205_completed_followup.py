"""Execute the actual browser classifiers without live database or mail access."""
from pathlib import Path
import shutil
import subprocess
import pytest


def test_completed_followup_browser_classifiers():
    node = shutil.which('node')
    if not node:
        pytest.skip('Node unavailable in this runtime; CI runs executable classifiers')
    subprocess.run([node, str(Path(__file__).with_suffix('.cjs'))], check=True)
