from __future__ import annotations

import json
from pathlib import Path

from setup_google_docs import (
    indexed_google_sources,
    linked_google_sources,
    preferred_editable_sources,
    runtime_google_sources,
)


def test_rclone_metadata_distinguishes_google_doc_from_native_word(tmp_path: Path) -> None:
    drive_root = tmp_path / "Display Folders"
    task_root = drive_root / "03-Welcome Area-WA" / "03a-Mega Cube-MC" / "Procedures" / "Setup"
    task_root.mkdir(parents=True)

    index = tmp_path / "google-doc-index.json"
    index.write_text(
        json.dumps(
            [
                {
                    "Path": "03-Welcome Area-WA/03a-Mega Cube-MC/Procedures/Setup/Archive/03-Mega Cube-MC Setup Procedure.docx",
                    "ID": "1yoRW4vLmnLUhrDFCzvZTA2njiPmahmjwPKE0XSR1Wqk",
                    "OrigID": "1yoRW4vLmnLUhrDFCzvZTA2njiPmahmjwPKE0XSR1Wqk",
                    "Metadata": {"content-type": "application/vnd.google-apps.document"},
                },
                {
                    "Path": "03-Welcome Area-WA/03a-Mega Cube-MC/Procedures/Setup/Archive/Mega Cube - Randy.docx",
                    "ID": "1-rQGTPLqtl90NGPadFnQEqmIyrzsJdZf",
                    "OrigID": "1-rQGTPLqtl90NGPadFnQEqmIyrzsJdZf",
                    "Metadata": {
                        "content-type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                    },
                },
            ]
        ),
        encoding="utf-8",
    )

    sources, warnings = indexed_google_sources(
        task_root=str(task_root),
        drive_root=str(drive_root),
        index_path=str(index),
    )

    assert warnings == []
    assert len(sources) == 1
    source = sources[0]
    assert source["name"] == "03-Mega Cube-MC Setup Procedure.gdoc"
    assert source["role"] == "ARCHIVE"
    assert source["google_doc_id"] == "1yoRW4vLmnLUhrDFCzvZTA2njiPmahmjwPKE0XSR1Wqk"
    assert source["edit_url"] == "https://docs.google.com/document/d/1yoRW4vLmnLUhrDFCzvZTA2njiPmahmjwPKE0XSR1Wqk/edit"
    assert "Randy" not in json.dumps(sources)


def test_lazy_link_view_distinguishes_google_doc_without_global_index(tmp_path: Path) -> None:
    drive_root = tmp_path / "Display Folders"
    relative = Path("03-Welcome Area-WA") / "03a-Mega Cube-MC" / "Procedures" / "Setup"
    task_root = drive_root / relative
    task_root.mkdir(parents=True)

    link_root = tmp_path / "Google Links"
    archive = link_root / relative / "Archive"
    archive.mkdir(parents=True)
    (archive / "03-Mega Cube-MC Setup Procedure.link.html").write_text(
        '<html><meta http-equiv="refresh" content="0; url=https://docs.google.com/document/d/1yoRW4vLmnLUhrDFCzvZTA2njiPmahmjwPKE0XSR1Wqk/edit?usp=drivesdk"></html>',
        encoding="utf-8",
    )
    (archive / "Mega Cube - Randy.docx").write_bytes(b"native word")

    sources, warnings = linked_google_sources(
        task_root=str(task_root),
        drive_root=str(drive_root),
        link_root=str(link_root),
    )

    assert warnings == []
    assert [item["name"] for item in sources] == ["03-Mega Cube-MC Setup Procedure.gdoc"]
    assert sources[0]["source_backend"] == "rclone-link-view"
    assert sources[0]["role"] == "ARCHIVE"
    assert "Randy" not in json.dumps(sources)


def test_source_docs_preferred_over_archive() -> None:
    archive = {
        "name": "Old.gdoc",
        "role": "ARCHIVE",
        "extension": ".gdoc",
        "edit_url": "https://docs.google.com/document/d/archive123456/edit",
        "google_doc_id": "archive123456",
    }
    source_doc = {
        "name": "Current.gdoc",
        "role": "SOURCEDOC",
        "extension": ".gdoc",
        "edit_url": "https://docs.google.com/document/d/source123456/edit",
        "google_doc_id": "source123456",
    }

    assert preferred_editable_sources([archive], [source_doc]) == [source_doc]
    assert preferred_editable_sources([archive], []) == [archive]


def test_google_doc_index_only_accepts_direct_setup_source_children(tmp_path: Path) -> None:
    drive_root = tmp_path / "Display Folders"
    task_root = drive_root / "04-Food Collection-FC" / "Procedures" / "Setup"
    task_root.mkdir(parents=True)
    index = tmp_path / "index.json"
    index.write_text(
        json.dumps(
            [
                {
                    "Path": "04-Food Collection-FC/Procedures/Setup/Archive/nested/Ignore.docx",
                    "ID": "nested123456789",
                    "Metadata": {"content-type": "application/vnd.google-apps.document"},
                },
                {
                    "Path": "04-Food Collection-FC/Procedures/Setup/Archive/Official.docx",
                    "ID": "official123456789",
                    "Metadata": {"content-type": "application/vnd.google-apps.document"},
                },
            ]
        ),
        encoding="utf-8",
    )

    sources, warnings = indexed_google_sources(
        task_root=str(task_root),
        drive_root=str(drive_root),
        index_path=str(index),
    )
    assert warnings == []
    assert [item["name"] for item in sources] == ["Official.gdoc"]


def test_runtime_prefers_lazy_link_view_over_index(tmp_path: Path, monkeypatch) -> None:
    drive_root = tmp_path / "Display Folders"
    relative = Path("04-Food Collection-FC") / "Procedures" / "Setup"
    task_root = drive_root / relative
    task_root.mkdir(parents=True)

    link_root = tmp_path / "links"
    source_docs = link_root / relative / "SourceDocs"
    source_docs.mkdir(parents=True)
    (source_docs / "Official.link.html").write_text(
        '<a href="https://docs.google.com/document/d/linkview123456789/edit">Official</a>',
        encoding="utf-8",
    )

    bad_index = tmp_path / "bad-index.json"
    bad_index.write_text("not json", encoding="utf-8")
    monkeypatch.setenv("SETUP_GOOGLE_DOC_LINK_ROOT", str(link_root))
    monkeypatch.setenv("SETUP_GOOGLE_DOC_INDEX", str(bad_index))

    sources, warnings = runtime_google_sources(
        task_root=str(task_root),
        drive_root=str(drive_root),
    )
    assert warnings == []
    assert [item["name"] for item in sources] == ["Official.gdoc"]
    assert sources[0]["source_backend"] == "rclone-link-view"
