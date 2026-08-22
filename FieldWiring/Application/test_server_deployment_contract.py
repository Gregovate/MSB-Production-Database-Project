from __future__ import annotations

from pathlib import Path

from wiring import MARKER_NAME
from wiring_images import resolve_images


WINDOWS_ROOT = r"G:\Shared drives\Display Folders"


def _mark(path: Path, text: str = "marker") -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / MARKER_NAME).write_text(text, encoding="utf-8")


def test_windows_drive_evidence_resolves_against_linux_mount(tmp_path, monkeypatch):
    linux_root = tmp_path / "msb-display-folders"
    stage_root = linux_root / "15-Church-Bells-CH"
    scene_root = stage_root / "15-Church-CH"

    _mark(stage_root, "stage")
    _mark(scene_root, "scene")

    wiring_root = scene_root / "Wiring"
    _mark(wiring_root, "wiring")
    musical = wiring_root / "MusicalStage"
    musical.mkdir()
    (musical / "Church Wiring.jpg").write_bytes(b"jpeg")

    preview_background = scene_root / "PreviewBackground"
    _mark(preview_background, "background")
    (preview_background / "Church Context.jpg").write_bytes(b"jpeg")

    monkeypatch.setenv("FIELDWIRING_DRIVE_ROOT", str(linux_root))
    monkeypatch.setenv("FIELDWIRING_WINDOWS_DRIVE_ROOT", WINDOWS_ROOT)

    stage = {
        "stage_key": "15",
        "folder_path": WINDOWS_ROOT + r"\15-Church-Bells-CH",
    }
    scene = {
        "scene_name": "15-Church-CH",
        "scene_background_file": (
            WINDOWS_ROOT
            + r"\15-Church-Bells-CH\15-Church-CH\PreviewBackground\Church Context.jpg"
        ),
    }
    preview = {"preview_background_file": None}

    images = resolve_images(stage, scene, preview, "Musical")

    assert images["scope_type"] == "SCENE"
    assert images["scope_root"] == str(scene_root)
    assert [item["name"] for item in images["wiring_images"]] == ["Church Wiring.jpg"]
    assert [item["name"] for item in images["context_images"]] == ["Church Context.jpg"]
    assert images["wiring_images"][0]["relative_path"] == (
        "15-Church-Bells-CH/15-Church-CH/Wiring/MusicalStage/Church Wiring.jpg"
    )
    assert images["wiring_images"][0]["url"].startswith("api/wiring/image?path=")
    assert not images["wiring_images"][0]["url"].startswith("/")


def test_stage_windows_folder_path_resolves_without_background_pointer(tmp_path, monkeypatch):
    linux_root = tmp_path / "msb-display-folders"
    stage_root = linux_root / "15-Church-Bells-CH"
    _mark(stage_root, "stage")

    wiring_root = stage_root / "Wiring"
    _mark(wiring_root, "wiring")
    background = wiring_root / "BackgroundStage"
    background.mkdir()
    (background / "Stage 15.jpg").write_bytes(b"jpeg")

    monkeypatch.setenv("FIELDWIRING_DRIVE_ROOT", str(linux_root))
    monkeypatch.setenv("FIELDWIRING_WINDOWS_DRIVE_ROOT", WINDOWS_ROOT)

    images = resolve_images(
        {
            "stage_key": "15",
            "folder_path": WINDOWS_ROOT + r"\15-Church-Bells-CH",
        },
        {"scene_name": "Root", "scene_background_file": None},
        {"preview_background_file": None},
        "Background / Static",
    )

    assert images["scope_type"] == "STAGE"
    assert images["scope_root"] == str(stage_root)
    assert [item["name"] for item in images["wiring_images"]] == ["Stage 15.jpg"]


def test_public_frontend_uses_subpath_safe_links():
    app_dir = Path(__file__).resolve().parent

    lookup_js = (app_dir / "fieldwiring.js").read_text(encoding="utf-8")
    wiring_js = (app_dir / "wiring.js").read_text(encoding="utf-8")
    wiring_html = (app_dir / "wiring.html").read_text(encoding="utf-8")

    forbidden_lookup = ["`/api/", "'/api/", '"/api/', "'/wiring?", '"/wiring?']
    forbidden_detail = ["'/api/", '"/api/', "'/wiring?", '"/wiring?', 'href="/"']
    forbidden_html = [
        'href="/wiring.css"',
        'href="/wiring_sticky_context.css"',
        'href="/wiring_workspace_focus.css"',
        'src="/wiring.js"',
        'src="/wiring_e131.js"',
        'src="/wiring_dumbrgb.js"',
        'src="/wiring_disclosure.js"',
        'src="/wiring_workspace_focus.js"',
    ]

    assert all(token not in lookup_js for token in forbidden_lookup)
    assert all(token not in wiring_js for token in forbidden_detail)
    assert all(token not in wiring_html for token in forbidden_html)

    assert "wiring.html?" in lookup_js
    assert "api/wiring?" in wiring_js
    assert 'href="./"' in wiring_html


def test_current_field_copy_banner_is_print_only():
    wiring_html = (Path(__file__).resolve().parent / "wiring.html").read_text(encoding="utf-8")

    assert 'id="currentness" class="currentness print-only"' in wiring_html
    assert "CURRENT FIELD COPY" in wiring_html


def test_postgres_display_name_search_orders_outside_distinct_subquery():
    source = (Path(__file__).resolve().parent / "repository.py").read_text(encoding="utf-8")

    assert "SELECT *\n                    FROM (\n                        SELECT DISTINCT" in source
    assert ") AS matches\n                    ORDER BY" in source
    assert "CASE WHEN lower(display_name) = lower(%s)" in source


def test_lookup_frontend_handles_non_json_api_errors():
    source = (Path(__file__).resolve().parent / "fieldwiring.js").read_text(encoding="utf-8")

    assert "const text = await response.text();" in source
    assert "FieldWiring server error (${response.status})" in source
    assert "FieldWiring server returned an unexpected response." in source
