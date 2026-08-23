from pathlib import Path

import pytest

from FieldWiring.Application import field_context_resolver
from Procedures.Application import procedure_documents
from Procedures.Application.procedure_documents import resolve_procedure_documents


MARKER = field_context_resolver.MARKER_NAME


def _mark(folder: Path) -> None:
    (folder / MARKER).write_text("controlled", encoding="utf-8")


def _stage(root: Path, name: str = "15-Church-Bells-CH") -> Path:
    stage = root / name
    stage.mkdir()
    _mark(stage)
    return stage


def _procedures(scope: Path) -> Path:
    procedures = scope / "Procedures"
    procedures.mkdir()
    _mark(procedures)
    return procedures


def _context(stage_root: Path):
    stage = {
        "stage_key": "15",
        "stage_name": "Church Bells",
        "folder_path": str(stage_root),
    }
    preview = {"preview_background_file": None}
    return stage, preview


def test_adapter_imports_the_canonical_shared_resolver():
    assert (
        procedure_documents.resolve_structured_scope
        is field_context_resolver.resolve_structured_scope
    )


def test_church_like_setup_uses_root_markers_and_direct_pdf(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    procedures = _procedures(stage_root)
    setup = procedures / "Setup"
    setup.mkdir()
    pdf = setup / "15 - Church-Nativity-Bells.pdf"
    pdf.write_bytes(b"pdf")

    # There is deliberately no marker in Setup.  The Procedures-root marker
    # guards the fixed Setup/Takedown/Inspection child names.
    stage, preview = _context(stage_root)
    result = resolve_procedure_documents(stage, None, preview, "Setup", root)

    assert result["status"] == "AVAILABLE"
    assert result["scope_type"] == "STAGE"
    assert result["scope_root"] == str(stage_root)
    assert result["procedures_root"] == str(procedures)
    assert result["task_root"] == str(setup)
    assert [item["name"] for item in result["documents"]] == [pdf.name]


def test_unmarked_procedures_root_is_not_consumed(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    procedures = stage_root / "Procedures"
    procedures.mkdir()
    setup = procedures / "Setup"
    setup.mkdir()
    (setup / "Current.pdf").write_bytes(b"pdf")

    stage, preview = _context(stage_root)
    result = resolve_procedure_documents(stage, None, preview, "Setup", root)

    assert result["status"] == "PROCEDURES_UNAVAILABLE"
    assert result["documents"] == []
    assert any("marker is missing" in warning.lower() for warning in result["warnings"])


def test_archive_sourcedocs_and_images_pdfs_are_not_current_documents(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    procedures = _procedures(stage_root)
    setup = procedures / "Setup"
    setup.mkdir()

    (setup / "Current.pdf").write_bytes(b"current")
    archive = setup / "Archive"
    archive.mkdir()
    (archive / "Old.pdf").write_bytes(b"old")
    source_docs = setup / "SourceDocs"
    source_docs.mkdir()
    (source_docs / "Working.pdf").write_bytes(b"working")
    images = setup / "images"
    images.mkdir()
    (images / "Not-A-Procedure.pdf").write_bytes(b"support")
    (images / "step-01.jpg").write_bytes(b"image")

    stage, preview = _context(stage_root)
    result = resolve_procedure_documents(stage, None, preview, "Setup", root)

    assert [item["name"] for item in result["documents"]] == ["Current.pdf"]
    assert [item["name"] for item in result["images"]] == ["step-01.jpg"]


def test_multiple_current_pdfs_are_returned_in_deterministic_order(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    setup = _procedures(stage_root) / "Setup"
    setup.mkdir()
    (setup / "Zulu.pdf").write_bytes(b"z")
    (setup / "alpha.PDF").write_bytes(b"a")

    stage, preview = _context(stage_root)
    result = resolve_procedure_documents(stage, None, preview, "setup", root)

    assert result["status"] == "AVAILABLE"
    assert [item["name"] for item in result["documents"]] == [
        "alpha.PDF",
        "Zulu.pdf",
    ]


def test_empty_task_folder_has_explicit_missing_document_state(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    setup = _procedures(stage_root) / "Setup"
    setup.mkdir()

    stage, preview = _context(stage_root)
    result = resolve_procedure_documents(stage, None, preview, "Setup", root)

    assert result["status"] == "NO_CURRENT_DOCUMENTS"
    assert result["documents"] == []


def test_missing_task_folder_is_explicitly_unavailable(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    _procedures(stage_root)

    stage, preview = _context(stage_root)
    result = resolve_procedure_documents(stage, None, preview, "Takedown", root)

    assert result["status"] == "TASK_UNAVAILABLE"
    assert result["documents"] == []


def test_invalid_task_name_is_rejected_before_filesystem_selection(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    stage, preview = _context(stage_root)

    with pytest.raises(ValueError, match="Setup, Takedown, or Inspection"):
        resolve_procedure_documents(stage, None, preview, "../Setup", root)


def test_scene_scope_from_shared_resolver_controls_procedure_branch(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    scene_root = stage_root / "15-Nativity"
    scene_root.mkdir()
    _mark(scene_root)
    setup = _procedures(scene_root) / "Setup"
    setup.mkdir()
    (setup / "Nativity Setup.pdf").write_bytes(b"pdf")

    stage, preview = _context(stage_root)
    scene = {
        "scene_name": "15-Nativity",
        "scene_background_file": None,
    }
    result = resolve_procedure_documents(stage, scene, preview, "Setup", root)

    assert result["status"] == "AVAILABLE"
    assert result["scope_type"] == "SCENE"
    assert result["scope_root"] == str(scene_root)
    assert [item["name"] for item in result["documents"]] == ["Nativity Setup.pdf"]


def test_scene_fallback_warning_names_expected_windows_procedure_path(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _stage(root)
    setup = _procedures(stage_root) / "Setup"
    setup.mkdir()
    (setup / "Church Setup.pdf").write_bytes(b"pdf")

    stage = {
        "stage_key": "15",
        "stage_name": "Church Bells",
        "folder_path": r"G:\Shared drives\Display Folders\15-Church-Bells-CH",
    }
    scene = {
        "scene_name": "15-Church-CH",
        "scene_background_file": None,
    }
    preview = {"preview_background_file": None}

    result = resolve_procedure_documents(stage, scene, preview, "Setup", root)

    assert result["status"] == "AVAILABLE"
    assert result["scope_type"] == "STAGE"
    assert result["warnings"] == [
        "No Setup procedure found in "
        r"G:\Shared drives\Display Folders\15-Church-Bells-CH\15-Church-CH\Procedures\Setup. "
        "Using the Stage-level Setup procedure instead."
    ]
