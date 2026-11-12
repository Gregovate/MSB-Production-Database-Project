from pathlib import Path

import pytest

from FieldWiring.Application.field_context_repository import FieldContextRepository
from FieldWiring.Application.field_context_resolver import MARKER_NAME
from Procedures.Application import backend


class FakeFieldContextRepository(FieldContextRepository):
    def __init__(self, displays=None, stages=None):
        self._displays = displays or {}
        self._stages = stages or []

    def search_displays(self, query: str, limit: int = 40):
        q = (query or "").strip().casefold()
        if not q:
            return []
        result = []
        for item in self._displays.values():
            if q in item["display_name"].casefold() or q in {
                str(item["display_id"]),
                f"disp:{item['display_id']}".casefold(),
            }:
                result.append(
                    {
                        "display_id": item["display_id"],
                        "display_name": item["display_name"],
                        "stage": item["stage"],
                    }
                )
        return result[:limit]

    def display_context(self, display_id: int):
        return self._displays.get(display_id)

    def stages(self):
        return list(self._stages)


def _mark(folder: Path) -> None:
    (folder / MARKER_NAME).write_text("controlled", encoding="utf-8")


def _build_fixture(tmp_path: Path):
    root = tmp_path / "Display Folders"
    root.mkdir()

    stage_root = root / "25-Racing Arches-RA"
    stage_root.mkdir()
    _mark(stage_root)

    procedures = stage_root / "Procedures"
    procedures.mkdir()
    _mark(procedures)

    setup = procedures / "Setup"
    setup.mkdir()
    current_pdf = setup / "Racing Arches Setup.pdf"
    current_pdf.write_bytes(b"current-pdf")

    archive = setup / "Archive"
    archive.mkdir()
    (archive / "Old Setup.pdf").write_bytes(b"old-pdf")

    source_docs = setup / "SourceDocs"
    source_docs.mkdir()
    (source_docs / "Working Setup.pdf").write_bytes(b"working-pdf")
    (source_docs / "source.jpg").write_bytes(b"source-image")

    images = setup / "images"
    images.mkdir()
    current_image = images / "step-01.jpg"
    current_image.write_bytes(b"current-image")

    stage = {
        "stage_id": 55,
        "stage_key": "25",
        "stage_name": "RGB Plus Stage 25 Racing Arches Traditional",
        "folder_path": str(stage_root),
    }

    second_context_a = {
        "preview": {
            "preview_uuid": "preview-a",
            "preview_name": "Preview A",
            "preview_background_file": None,
            "preview_revision": None,
            "source_filename": None,
        },
        "scene": {
            "scene_uuid": "scene-a",
            "scene_name": "Scene A",
            "scene_stage_key": "25",
            "scene_background_file": None,
        },
        "scope_kind": "Scene",
        "context_type": "Other",
    }
    second_context_b = {
        "preview": {
            "preview_uuid": "preview-b",
            "preview_name": "Preview B",
            "preview_background_file": None,
            "preview_revision": None,
            "source_filename": None,
        },
        "scene": {
            "scene_uuid": "scene-b",
            "scene_name": "Scene B",
            "scene_stage_key": "25",
            "scene_background_file": None,
        },
        "scope_kind": "Scene",
        "context_type": "Other",
    }

    displays = {
        807: {
            "display_id": 807,
            "display_name": "RA-SteelArch-DS-F-03",
            "stage": stage,
            # Deliberately no wiring/device fields and no Scene membership.
            "contexts": [],
        },
        808: {
            "display_id": 808,
            "display_name": "RA-ContextChoice",
            "stage": stage,
            "contexts": [second_context_a, second_context_b],
        },
    }
    stages = [{"stage": stage, "contexts": []}]
    repo = FakeFieldContextRepository(displays=displays, stages=stages)
    return root, repo, current_pdf, current_image


@pytest.fixture
def client(tmp_path, monkeypatch):
    root, repo, current_pdf, current_image = _build_fixture(tmp_path)
    monkeypatch.setattr(backend, "repository", lambda: repo)
    monkeypatch.setattr(backend, "drive_root", lambda: root)
    backend.app.config.update(TESTING=True)
    with backend.app.test_client() as test_client:
        yield test_client, root, repo, current_pdf, current_image


def test_health(client):
    test_client, *_ = client
    response = test_client.get("/api/health")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload["status"] == "ok"
    assert payload["version"] == backend.APP_VERSION


def test_shared_display_search_includes_inventory_only_display(client):
    test_client, *_ = client
    response = test_client.get("/api/displays?q=SteelArch")
    assert response.status_code == 200
    items = response.get_json()["displays"]
    assert [item["display_id"] for item in items] == [807]
    assert "device_type" not in items[0]


def test_display_context_uses_shared_context_contract(client):
    test_client, *_ = client
    response = test_client.get("/api/displays/807/context")
    assert response.status_code == 200
    context = response.get_json()["context"]
    assert context["display_name"] == "RA-SteelArch-DS-F-03"
    assert context["stage"]["stage_id"] == 55
    assert context["contexts"] == []


def test_missing_display_context_returns_404(client):
    test_client, *_ = client
    response = test_client.get("/api/displays/9999/context")
    assert response.status_code == 404


def test_inventory_only_display_resolves_current_setup(client):
    test_client, *_ = client
    response = test_client.get("/api/procedures?display_id=807&task=Setup")
    assert response.status_code == 200
    result = response.get_json()["procedure"]
    assert result["status"] == "AVAILABLE"
    assert result["scope_type"] == "STAGE"
    assert result["trigger"]["display_id"] == 807
    assert [item["name"] for item in result["documents"]] == [
        "Racing Arches Setup.pdf"
    ]


def test_stage_whole_stage_browse_resolves_current_setup(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedures?stage_id=55&task=Setup&whole_stage=true"
    )
    assert response.status_code == 200
    result = response.get_json()["procedure"]
    assert result["status"] == "AVAILABLE"
    assert result["trigger"]["type"] == "STAGE_BROWSE"
    assert result["selected_context"] is None


def test_multiple_shared_contexts_are_returned_for_browser_choice(client):
    test_client, *_ = client
    response = test_client.get("/api/procedures?display_id=808&task=Setup")
    assert response.status_code == 200
    result = response.get_json()["procedure"]
    assert result["status"] == "CONTEXT_SELECTION_REQUIRED"
    assert [item["scene_uuid"] for item in result["contexts"]] == [
        "scene-a",
        "scene-b",
    ]


def test_lookup_requires_exactly_one_entry_identity(client):
    test_client, *_ = client

    neither = test_client.get("/api/procedures?task=Setup")
    assert neither.status_code == 400

    both = test_client.get(
        "/api/procedures?display_id=807&stage_id=55&task=Setup"
    )
    assert both.status_code == 400


def test_current_direct_pdf_is_served_by_name_after_rediscovery(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedure/document?display_id=807&task=Setup&name=Racing%20Arches%20Setup.pdf"
    )
    assert response.status_code == 200
    assert response.data == b"current-pdf"
    assert response.mimetype == "application/pdf"


def test_archive_pdf_cannot_be_served(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedure/document?display_id=807&task=Setup&name=Old%20Setup.pdf"
    )
    assert response.status_code == 404


def test_sourcedocs_pdf_cannot_be_served(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedure/document?display_id=807&task=Setup&name=Working%20Setup.pdf"
    )
    assert response.status_code == 404


def test_traversal_style_filename_cannot_be_served(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedure/document?display_id=807&task=Setup&name=../SourceDocs/Working%20Setup.pdf"
    )
    assert response.status_code == 404


def test_current_supporting_image_is_served_by_name_after_rediscovery(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedure/image?display_id=807&task=Setup&name=step-01.jpg"
    )
    assert response.status_code == 200
    assert response.data == b"current-image"
    assert response.mimetype == "image/jpeg"


def test_sourcedocs_image_cannot_be_served(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedure/image?display_id=807&task=Setup&name=source.jpg"
    )
    assert response.status_code == 404


def test_whole_stage_is_rejected_for_display_entry(client):
    test_client, *_ = client
    response = test_client.get(
        "/api/procedures?display_id=807&task=Setup&whole_stage=true"
    )
    assert response.status_code == 400
