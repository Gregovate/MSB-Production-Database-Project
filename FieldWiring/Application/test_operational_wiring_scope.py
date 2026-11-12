from field_context_hierarchy import build_field_hierarchy
from repository import _flatten_fieldwiring_context


def _context(
    scene_name: str,
    *,
    scene_uuid: str,
    path: str,
    preview_uuid: str = "preview-24-background",
):
    return {
        "preview": {
            "preview_uuid": preview_uuid,
            "preview_name": "Show Background Stage 24 Traditional Christmas",
            "preview_background_file": None,
        },
        "scene": {
            "scene_uuid": scene_uuid,
            "scene_name": scene_name,
            "scene_stage_key": "24",
            "scene_background_file": path,
        },
        "scope_kind": "Scene",
        "context_type": "Background / Static",
    }


def _shared_display(contexts):
    return {
        "display_id": 141,
        "display_name": "TC-ChristmasHippo",
        "stage": {
            "stage_id": 54,
            "stage_key": "24",
            "stage_name": "Show Background Stage 24 Traditional Christmas",
            "folder_path": r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC",
        },
        "contexts": contexts,
    }


def test_display_adapter_uses_whole_stage_for_unprefixed_lor_scene():
    shared = _shared_display(
        [
            _context(
                "ChristmasHippo",
                scene_uuid="scene-hippo",
                path=(
                    r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                    r"\ChristmasHippo\PreviewBackground\Hippo.jpg"
                ),
            )
        ]
    )

    result = _flatten_fieldwiring_context(shared, "LOR")

    assert result["display_id"] == 141
    assert result["preview_uuid"] == "preview-24-background"
    assert result["scene_uuid"] is None
    assert result["scene_name"] is None
    assert result["scope_kind"] == "Stage / Preview"
    assert result["context_type"] == "Background / Static"


def test_display_adapter_keeps_formal_scene_scope():
    shared = _shared_display(
        [
            _context(
                "24-Nutcracker-Ornaments",
                scene_uuid="scene-nutcracker",
                path=(
                    r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                    r"\24-Nutcracker-Ornaments\PreviewBackground\Nutcracker.jpg"
                ),
            )
        ]
    )

    result = _flatten_fieldwiring_context(shared, "LOR")

    assert result["scene_uuid"] == "scene-nutcracker"
    assert result["scene_name"] == "24-Nutcracker-Ornaments"
    assert result["scope_kind"] == "Scene"


def test_stage24_browse_has_one_whole_stage_and_two_formal_scenes():
    contexts = [
        _context(
            "ChristmasHippo",
            scene_uuid="scene-hippo",
            path=(
                r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                r"\ChristmasHippo\PreviewBackground\Hippo.jpg"
            ),
        ),
        _context(
            "ChristmasTree",
            scene_uuid="scene-tree",
            path=(
                r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                r"\ChristmasTree\PreviewBackground\Tree.jpg"
            ),
        ),
        _context(
            "24-Nutcracker-Ornaments",
            scene_uuid="scene-nutcracker",
            path=(
                r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                r"\24-Nutcracker-Ornaments\PreviewBackground\Nutcracker.jpg"
            ),
        ),
        _context(
            "24-SnowFamily and 10YrStocking",
            scene_uuid="scene-snow",
            path=(
                r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                r"\24-SnowFamily and 10YrStocking\PreviewBackground\Snow.jpg"
            ),
        ),
    ]
    raw = {
        "stage": _shared_display([])["stage"],
        "contexts": contexts,
    }

    stage = build_field_hierarchy([raw])["stages"][0]

    assert len(stage["contexts"]) == 1
    assert stage["contexts"][0]["scene_uuid"] is None
    assert [scene["label"] for scene in stage["scenes"]] == [
        "24-Nutcracker-Ornaments",
        "24-SnowFamily and 10YrStocking",
    ]
