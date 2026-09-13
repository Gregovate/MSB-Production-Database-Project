from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_catalog_material_checkbox_stays_in_compact_right_side_row() -> None:
    css = read("setup_display_ownership.css")
    assert ".next-task-row {" in css
    assert "grid-template-columns: 4rem minmax(14rem, 1fr) minmax(12rem, .9fr) max-content auto;" in css
    assert ".next-task-row > .setup-catalog-material-toggle" in css
    assert "min-width: 0;" in css
    assert "white-space: nowrap;" in css
    assert "font-size: 0;" in css
    assert "content: 'Material';" in css
    assert ".next-task-row > .library-actions" in css
    assert "justify-self: end;" in css


def test_catalog_material_checkbox_does_not_use_the_previous_wide_visual_label() -> None:
    css = read("setup_display_ownership.css")
    compact = css.split(".next-task-row > .setup-catalog-material-toggle", 1)[1]
    compact = compact.split("}", 1)[0]
    assert "min-width: 210px" not in compact
    assert "width: max-content" in compact
