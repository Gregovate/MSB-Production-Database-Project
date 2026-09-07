from __future__ import annotations

import json
from pathlib import Path

from setup_google_docs import indexed_google_sources, preferred_editable_sources


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
