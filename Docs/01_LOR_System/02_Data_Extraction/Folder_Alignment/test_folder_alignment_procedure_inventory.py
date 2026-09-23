from __future__ import annotations

import csv
import importlib.util
import os
import sys
from pathlib import Path


MODULE_PATH = (
    Path(__file__).resolve().parent
    / "folder_alignment.py"
)

SPEC = importlib.util.spec_from_file_location("folder_alignment_under_test", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
folder_alignment = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = folder_alignment
SPEC.loader.exec_module(folder_alignment)


def _scope(tmp_path: Path) -> object:
    root = tmp_path / "Display Folders"
    scope_root = root / "26-Magic Igloo-MI"
    setup = scope_root / "Procedures" / "Setup"
    archive = setup / "Archive"
    source = setup / "SourceDocs"
    images = setup / "images"
    for path in (archive, source, images):
        path.mkdir(parents=True, exist_ok=True)

    # One preserved original can legitimately become multiple current components.
    (archive / "26 Magic Igloo Setup Procedure.gdoc").write_text("archive", encoding="utf-8")
    (source / "Magic Igloo Frame.gdoc").write_text("source", encoding="utf-8")
    (source / "Magic Igloo Skins.gdoc").write_text("source", encoding="utf-8")
    (source / "Magic Igloo Interior Lighting.gdoc").write_text("source", encoding="utf-8")
    (setup / "Magic Igloo Frame.pdf").write_bytes(b"pdf")
    (setup / "Magic Igloo Skins.pdf").write_bytes(b"pdf")
    (setup / "Magic Igloo Interior Lighting.pdf").write_bytes(b"pdf")

    fixed_mtime = 1_700_000_000
    for item in (
        archive / "26 Magic Igloo Setup Procedure.gdoc",
        source / "Magic Igloo Frame.gdoc",
        source / "Magic Igloo Skins.gdoc",
        source / "Magic Igloo Interior Lighting.gdoc",
        setup / "Magic Igloo Frame.pdf",
        setup / "Magic Igloo Skins.pdf",
        setup / "Magic Igloo Interior Lighting.pdf",
    ):
        os.utime(item, (fixed_mtime, fixed_mtime))

    return (
        root,
        folder_alignment.Scope(
            stage_id="26",
            scope_type="STAGE",
            scope_name="26-Magic Igloo-MI",
            path=scope_root,
            status="OK",
        ),
    )


def test_procedure_inventory_supports_split_procedure_without_filename_pairing(tmp_path: Path) -> None:
    _root, scope = _scope(tmp_path)

    inventory = folder_alignment.procedure_inventory(scope)

    assert [item.name for item in inventory.archive_gdocs] == [
        "26 Magic Igloo Setup Procedure.gdoc"
    ]
    assert [item.name for item in inventory.source_gdocs] == [
        "Magic Igloo Frame.gdoc",
        "Magic Igloo Interior Lighting.gdoc",
        "Magic Igloo Skins.gdoc",
    ]
    assert [item.name for item in inventory.published_pdfs] == [
        "Magic Igloo Frame.pdf",
        "Magic Igloo Interior Lighting.pdf",
        "Magic Igloo Skins.pdf",
    ]


def test_procedure_inventory_reports_only_missing_procedure_structure(tmp_path: Path) -> None:
    root = tmp_path / "Display Folders"
    scope_root = root / "08-Elf Choir-EC"
    (scope_root / "Procedures" / "Setup" / "Archive").mkdir(parents=True)
    scope = folder_alignment.Scope(
        stage_id="08",
        scope_type="STAGE",
        scope_name="08-Elf Choir-EC",
        path=scope_root,
        status="OK",
    )

    missing = folder_alignment.missing_procedure_contract(scope)

    assert "Procedures/Setup/SourceDocs" in missing
    assert "Procedures/Setup/images" in missing
    assert "Photos/Current" not in missing
    assert "Wiring/BackgroundStage/SourceDocs" not in missing


def test_procedure_inventory_writes_shareable_html_and_csv(tmp_path: Path) -> None:
    root, scope = _scope(tmp_path)
    output = tmp_path / "reports"
    output.mkdir()

    html_path, csv_path = folder_alignment.write_procedure_inventory(
        output,
        root,
        [scope],
        "20260923-120000",
    )

    assert html_path.name == "procedure-inventory-20260923-120000.html"
    assert csv_path.name == "procedure-inventory-20260923-120000.csv"

    html_text = html_path.read_text(encoding="utf-8")
    assert "<h1>MSB Procedure Inventory</h1>" in html_text
    assert "<h2>How to Update a Setup Procedure</h2>" in html_text
    assert "File → Make a copy" in html_text
    assert "Procedures\\Setup\\SourceDocs" in html_text
    assert "File → Download → PDF Document (.pdf)" in html_text
    assert "Do not edit or delete the Archive original" in html_text
    assert "26-Magic Igloo Setup - Frame" in html_text
    assert "<h2>Do Not Change the Folder Structure</h2>" in html_text
    assert "_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt" in html_text
    assert "Big Picture — same idea as the office whiteboard" in html_text
    assert "same folder structure" in html_text
    assert "Stage folder" in html_text
    assert "Sub-stage folder" in html_text
    assert "Scene folder" in html_text
    assert "current field procedure(s)" in html_text
    assert "A single archived legacy procedure may legitimately be split" in html_text
    assert "Magic Igloo Frame.gdoc" in html_text
    assert "Magic Igloo Interior Lighting.pdf" in html_text
    assert "Procedures\\Setup\\SourceDocs" in html_text
    assert "Modified:" in html_text
    assert folder_alignment.file_modified_text(
        scope.path / "Procedures" / "Setup" / "SourceDocs" / "Magic Igloo Frame.gdoc"
    ) in html_text

    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert len(rows) == 1
    assert rows[0]["scope_name"] == "26-Magic Igloo-MI"
    assert rows[0]["archive_gdoc_count"] == "1"
    assert rows[0]["sourcedoc_gdoc_count"] == "3"
    assert rows[0]["published_pdf_count"] == "3"
    assert "Magic Igloo Frame.gdoc" in rows[0]["sourcedoc_gdoc_paths"]
    assert rows[0]["published_pdf_modified"]
    assert rows[0]["sourcedoc_gdoc_modified"]
    assert rows[0]["archive_gdoc_modified"]
