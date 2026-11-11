"""Run the actual summary/status renderer contrast checks with existing Node."""
from pathlib import Path
import subprocess


def test_perform_theme_contrast():
    subprocess.run(['node',str(Path(__file__).with_suffix('.cjs'))],check=True)
