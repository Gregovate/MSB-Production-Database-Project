from pathlib import Path

APP_DIR = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_primary_task_projection_carries_display_material_truth() -> None:
    source = read("setup_repository.py")
    assert "t.active_flag,\n                    t.requires_display_material," in source


def test_display_ownership_uses_setup_theme_surfaces_in_dark_mode() -> None:
    css = read("setup_display_ownership.css")
    assert "var(--surface," not in css
    assert "var(--surface-alt," not in css
    assert css.count("background: var(--card, #fff);") >= 3
    assert css.count("background: var(--theme-subtle, #f8fafb);") >= 2
