"""Run the real scheduling dialog JavaScript against continuation/move scenarios."""
from pathlib import Path
import subprocess


def test_inline_captain_dialog():
    subprocess.run(["node", str(Path(__file__).with_suffix('.cjs'))], check=True)
