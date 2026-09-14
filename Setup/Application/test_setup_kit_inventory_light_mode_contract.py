from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent


def test_kit_rows_and_pills_use_theme_text_color() -> None:
    css = (BASE_DIR / "setup_kit_inventory.css").read_text(encoding="utf-8")

    assert ".kit-row {" in css
    assert "background: var(--card); color: var(--text);" in css
    assert ".pill {" in css
    assert "background: var(--soft); color: var(--text);" in css
