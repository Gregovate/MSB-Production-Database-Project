from pathlib import Path

import pytest

from FieldWiring.Application.field_context_repository import FieldContextRepository
from FieldWiring.Application.field_context_resolver import MARKER_NAME
from Procedures.Application.procedure_context import (
    ProcedureContextError,
    resolve_display_procedure,
    resolve_stage_procedure,
)


class FakeFieldContextRepository(FieldContextRepository):
    def __init__(self, displays=None, stages=None):
        self._displays = displays or {}
        self._stages = stages or []

    def search_displays(self, query: str, limit: int = 40):
        q = query.casefold()
        return [
            {
                "display_id": item["display_id"],
                "display_name": item["display_name"],
                "stage": item["stage"],
            }
            for item in self._displays.values()
            if q in item["display_name"].casefold() or q == str(item["display_id"])
        ][:limit]

    def display_context(self, display_id: int):
        return self._displays.get(display_id)

    def stages(self):
        return list(self._stages)


def _mark(folder: Path) -> None:
    (folder / MARKER_NAME).write_text("controlled", encoding="utf-8")


def _scope(root: Path, name: str) -> Path:
    folder = root / name
    folder.mkdir(parents=True)
    _mark(folder)
    procedures = folder / "Procedures"
    procedures.mkdir()
    _mark(procedures)
    return folder


def _publish(scope: Path, task: str, name: str) -> Path:
    folder = scope / "Procedures" / task
    folder.mkdir(exist_ok=True)
    pdf = folder / name
    pdf.write_bytes(b"pdf")
    return pdf


def _context(preview_uuid: str, scene_uuid: str, scene_name: str, background: str | None = None):
    return {
        "preview": {
            "preview_uuid": preview_uuid,
            "preview_name": "2026 Master Musical Preview",
            "preview_background_file": None,
            "preview_revision": "1",
            "source_filename": "master.lorprev",
        },
        "scene": {
            "scene_uuid": scene_uuid,
            "scene_name": scene_name,
            "scene_stage_key": "25",
            "scene_background_file": background,
        },
        "scope_kind": "Scene",
        "context_type": "Musical",
    }


def test_inventory_only_display_can_reach_procedure_without_wiring_fields(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _scope(root, "25-Racing Arches-RA")
    pdf = _publish(stage_root, "Setup", "Racing Arches Setup.pdf")
    background = stage_root / "scene.jpg"
    background.write_bytes(b"image")

    stage = {
        "stage_id": 55,
        "stage_key": "25",
        "stage_name": "RGB Plus Stage 25 Racing Arches Traditional",
        "folder_path": str(stage_root),
    }
    repo = FakeFieldContextRepository(
        displays={
            807: {
                "display_id": 807,
                "display_name": "RA-SteelArch-DS-F-03",
                "stage": stage,
                "contexts": [
                    _context(
                        "preview-25",
                        "scene-25",
                        "25-Racing Arches-RA",
                        str(background),
                    )
                ],
            }
        }
    )

    result = resolve_display_procedure(
        repo,
        display_id=807,
        task="Setup",
        drive_root=root,
    )

    assert result["status"] == "AVAILABLE"
    assert result["trigger"] == {
        "type": "DISPLAY",
        "display_id": 807,
        "display_name": "RA-SteelArch-DS-F-03",
    }
    # Exact path evidence lands at the owning Stage root.  The governing
    # path contract does not invent a Scene merely because the LOR scene name
    # repeats the Stage folder name.
    assert result["scope_type"] == "STAGE"
    assert [item["name"] for item in result["documents"]] == [pdf.name]


def test_display_with_no_scene_context_can_use_current_stage_scope(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _scope(root, "15-Church-Bells-CH")
    _publish(stage_root, "Setup", "Church Setup.pdf")
    stage = {
        "stage_id": 15,
        "stage_key": "15",
        "stage_name": "Church Bells",
        "folder_path": str(stage_root),
    }
    repo = FakeFieldContextRepository(
        displays={
            900: {
                "display_id": 900,
                "display_name": "CH-InventoryOnly",
                "stage": stage,
                "contexts": [],
            }
        }
    )

    result = resolve_display_procedure(
        repo,
        display_id=900,
        task="Setup",
        drive_root=root,
    )

    assert result["status"] == "AVAILABLE"
    assert result["scope_type"] == "STAGE"
    assert result["selected_context"] is None


def test_multiple_display_contexts_require_explicit_selection(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _scope(root, "25-Racing Arches-RA")
    stage = {
        "stage_id": 55,
        "stage_key": "25",
        "stage_name": "Racing Arches",
        "folder_path": str(stage_root),
    }
    repo = FakeFieldContextRepository(
        displays={
            807: {
                "display_id": 807,
                "display_name": "RA-SteelArch-DS-F-03",
                "stage": stage,
                "contexts": [
                    _context("preview-a", "scene-a", "Scene A"),
                    _context("preview-b", "scene-b", "Scene B"),
                ],
            }
        }
    )

    result = resolve_display_procedure(
        repo,
        display_id=807,
        task="Setup",
        drive_root=root,
    )

    assert result["status"] == "CONTEXT_SELECTION_REQUIRED"
    assert [item["scene_uuid"] for item in result["contexts"]] == [
        "scene-a",
        "scene-b",
    ]
    assert result["documents"] == []


def test_explicit_display_context_is_validated_and_used(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _scope(root, "25-Racing Arches-RA")
    # Governed Scene roots use NN-Name under the owning Stage.  Unprefixed
    # names are Display/shared-group folders and must not be promoted to Scene.
    scene_a = _scope(stage_root, "25-Scene A")
    scene_b = _scope(stage_root, "25-Scene B")
    _publish(scene_b, "Setup", "Scene B Setup.pdf")
    stage = {
        "stage_id": 55,
        "stage_key": "25",
        "stage_name": "Racing Arches",
        "folder_path": str(stage_root),
    }
    repo = FakeFieldContextRepository(
        displays={
            807: {
                "display_id": 807,
                "display_name": "RA-SteelArch-DS-F-03",
                "stage": stage,
                "contexts": [
                    _context("preview-a", "scene-a", scene_a.name),
                    _context("preview-b", "scene-b", scene_b.name),
                ],
            }
        }
    )

    result = resolve_display_procedure(
        repo,
        display_id=807,
        task="Setup",
        drive_root=root,
        preview_uuid="preview-b",
        scene_uuid="scene-b",
    )

    assert result["status"] == "AVAILABLE"
    assert result["scope_root"] == str(scene_b)
    assert result["selected_context"]["scene_uuid"] == "scene-b"


def test_invalid_display_context_is_rejected(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _scope(root, "25-Racing Arches-RA")
    stage = {
        "stage_id": 55,
        "stage_key": "25",
        "stage_name": "Racing Arches",
        "folder_path": str(stage_root),
    }
    repo = FakeFieldContextRepository(
        displays={
            807: {
                "display_id": 807,
                "display_name": "RA-SteelArch-DS-F-03",
                "stage": stage,
                "contexts": [_context("preview-a", "scene-a", "Scene A")],
            }
        }
    )

    with pytest.raises(ProcedureContextError, match="not one unique current field context"):
        resolve_display_procedure(
            repo,
            display_id=807,
            task="Setup",
            drive_root=root,
            preview_uuid="preview-x",
            scene_uuid="scene-x",
        )


def test_whole_stage_browse_is_explicit_even_when_scene_contexts_exist(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _scope(root, "15-Church-Bells-CH")
    _publish(stage_root, "Setup", "Whole Stage Setup.pdf")
    stage = {
        "stage_id": 15,
        "stage_key": "15",
        "stage_name": "Church Bells",
        "folder_path": str(stage_root),
    }
    repo = FakeFieldContextRepository(
        stages=[
            {
                "stage": stage,
                "contexts": [_context("preview-a", "scene-a", "Scene A")],
            }
        ]
    )

    result = resolve_stage_procedure(
        repo,
        stage_id=15,
        task="Setup",
        drive_root=root,
        whole_stage=True,
    )

    assert result["status"] == "AVAILABLE"
    assert result["scope_type"] == "STAGE"
    assert result["selected_context"] is None


def test_stage_browse_with_multiple_contexts_requires_choice(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = _scope(root, "15-Church-Bells-CH")
    stage = {
        "stage_id": 15,
        "stage_key": "15",
        "stage_name": "Church Bells",
        "folder_path": str(stage_root),
    }
    repo = FakeFieldContextRepository(
        stages=[
            {
                "stage": stage,
                "contexts": [
                    _context("preview-a", "scene-a", "Scene A"),
                    _context("preview-b", "scene-b", "Scene B"),
                ],
            }
        ]
    )

    result = resolve_stage_procedure(
        repo,
        stage_id=15,
        task="Setup",
        drive_root=root,
    )

    assert result["status"] == "CONTEXT_SELECTION_REQUIRED"
    assert len(result["contexts"]) == 2


def test_missing_display_is_rejected(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    repo = FakeFieldContextRepository()

    with pytest.raises(ProcedureContextError, match="Display is not available"):
        resolve_display_procedure(
            repo,
            display_id=9999,
            task="Setup",
            drive_root=root,
        )
