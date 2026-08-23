from pathlib import Path

from FieldWiring.Application.field_context_repository import FieldContextRepository
from FieldWiring.Application.field_context_resolver import MARKER_NAME
from Procedures.Application import backend
from Procedures.Application.procedure_documents import resolve_procedure_documents


class FakeRepository(FieldContextRepository):
    def search_displays(self, query: str, limit: int = 40):
        return []

    def display_context(self, display_id: int):
        return None

    def stages(self):
        return [
            {
                "stage": {
                    "stage_id": 37,
                    "stage_key": "07",
                    "stage_name": "Show Background Stage 07 Whoville",
                    "folder_path": r"G:\Shared drives\Display Folders\07-Whoville-WV",
                },
                "contexts": [],
            },
            {
                "stage": {
                    "stage_id": 59,
                    "stage_key": "07a",
                    "stage_name": "RGB Plus Stage 07a Who Forest",
                    "folder_path": None,
                },
                "contexts": [
                    {
                        "preview": {
                            "preview_uuid": "preview-07a",
                            "preview_name": "Show Background Stage 07a Who Forest",
                            "preview_background_file": None,
                        },
                        "scene": {
                            "scene_uuid": "scene-07a",
                            "scene_name": "07a-Who Forest-WF",
                            "scene_stage_key": "07a",
                            "scene_background_file": (
                                r"G:\Shared drives\Display Folders\07-Whoville-WV"
                                r"\07a-Who Forest-WF\PreviewBackground\Who-Forest.jpg"
                            ),
                        },
                        "scope_kind": "Scene",
                        "context_type": "Background / Static",
                    }
                ],
            },
        ]


def _mark(folder: Path) -> None:
    (folder / MARKER_NAME).write_text("controlled", encoding="utf-8")


def test_stage_api_uses_fast_shared_hierarchy_without_drive_root(monkeypatch):
    monkeypatch.setattr(backend, "repository", lambda: FakeRepository())

    def forbidden_drive_root():
        raise AssertionError("browse-time Procedure API must not touch Display Folders")

    monkeypatch.setattr(backend, "drive_root", forbidden_drive_root)
    backend.app.config.update(TESTING=True)

    with backend.app.test_client() as client:
        response = client.get("/api/stages")

    assert response.status_code == 200
    payload = response.get_json()
    assert [stage["stage_key"] for stage in payload["stages"]] == ["07"]
    assert payload["stages"][0]["label"] == "07-Whoville-WV"
    assert [sub["stage_key"] for sub in payload["stages"][0]["sub_stages"]] == ["07a"]
    assert payload["stages"][0]["sub_stages"][0]["label"] == "07a-Who Forest-WF"


def test_backend_operator_errors_hide_internal_configuration_names():
    message = backend.operator_config_error(
        backend.ConfigError("Configure PROCEDURE_DATABASE_DSN and PROCEDURE_DRIVE_ROOT")
    )
    assert "PROCEDURE_DATABASE_DSN" not in message
    assert "PROCEDURE_DRIVE_ROOT" not in message
    assert "temporarily unavailable" in message


def test_missing_setup_pdf_reports_exact_operator_folder(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = root / "15-Church-Bells-CH"
    stage_root.mkdir()
    _mark(stage_root)
    procedures = stage_root / "Procedures"
    procedures.mkdir()
    _mark(procedures)
    setup = procedures / "Setup"
    setup.mkdir()

    stage = {
        "stage_key": "15",
        "stage_name": "Church Bells",
        "folder_path": str(stage_root),
    }
    result = resolve_procedure_documents(
        stage,
        None,
        {"preview_background_file": None},
        "Setup",
        root,
    )

    assert result["status"] == "NO_CURRENT_DOCUMENTS"
    assert result["operator_warnings"]
    warning = result["operator_warnings"][0]
    assert "Setup procedure" in warning
    assert r"Procedures\Setup" in warning
    assert "TASK_CONTENT_NOT_FOUND" not in warning


def test_task_adapters_choose_exact_procedure_branch(tmp_path):
    root = tmp_path / "Display Folders"
    root.mkdir()
    stage_root = root / "15-Church-Bells-CH"
    stage_root.mkdir()
    _mark(stage_root)
    procedures = stage_root / "Procedures"
    procedures.mkdir()
    _mark(procedures)

    stage = {
        "stage_key": "15",
        "stage_name": "Church Bells",
        "folder_path": str(stage_root),
    }

    for task in ("Setup", "Takedown", "Inspection"):
        result = resolve_procedure_documents(
            stage,
            None,
            {"preview_background_file": None},
            task,
            root,
        )
        assert result["status"] == "TASK_UNAVAILABLE"
        assert result["operator_warnings"]
        assert f"Procedures\\{task}" in result["operator_warnings"][0]
