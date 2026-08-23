from pathlib import Path

from field_context_hierarchy import build_field_hierarchy
from field_context_resolver import MARKER_NAME


def mark(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    (path / MARKER_NAME).write_text("marker", encoding="utf-8")
    return path


def raw_stage(stage_id: int, key: str, name: str, folder_path: str | None):
    return {
        "stage": {
            "stage_id": stage_id,
            "stage_key": key,
            "stage_name": name,
            "folder_path": folder_path,
        },
        "contexts": [],
    }


def test_valid_top_level_stage_remains_normal(tmp_path):
    drive = tmp_path / "Display Folders"
    root = mark(drive / "15-Church-Bells-CH")

    result = build_field_hierarchy(
        [raw_stage(15, "15", "LOR Church Name", str(root))],
        drive,
    )

    assert [item["stage_key"] for item in result["stages"]] == ["15"]
    assert result["stages"][0]["label"] == "15-Church-Bells-CH"
    assert not any(
        item["code"] == "TOP_LEVEL_STAGE_BINDING_REVIEW_REQUIRED"
        for item in result["review_required"]
    )


def test_conflicting_top_level_stage_path_is_review_only(tmp_path):
    drive = tmp_path / "Display Folders"
    mark(drive / "39-Parade Float-PF")
    other = mark(drive / "40-Parade Float-PF")

    result = build_field_hierarchy(
        [raw_stage(39, "39", "RGB Plus Stage 39 Parade Float", str(other))],
        drive,
    )

    assert result["stages"] == []
    codes = [item["code"] for item in result["review_required"]]
    assert "PERSISTED_STAGE_PATH_REVIEW_REQUIRED" in codes
    assert "TOP_LEVEL_STAGE_BINDING_REVIEW_REQUIRED" in codes


def test_missing_top_level_stage_path_is_review_only(tmp_path):
    drive = tmp_path / "Display Folders"
    mark(drive / "40-CommandCenter")

    result = build_field_hierarchy(
        [raw_stage(40, "40", "CommandCenter-CC", None)],
        drive,
    )

    assert result["stages"] == []
    codes = [item["code"] for item in result["review_required"]]
    assert "PERSISTED_STAGE_PATH_REVIEW_REQUIRED" in codes
    assert "TOP_LEVEL_STAGE_BINDING_REVIEW_REQUIRED" in codes


def test_nested_substage_with_missing_persisted_path_remains_browseable(tmp_path):
    drive = tmp_path / "Display Folders"
    stage_root = mark(drive / "07-Whoville-WV")
    mark(stage_root / "07a-Who Forest-WF")

    result = build_field_hierarchy(
        [
            raw_stage(7, "07", "Whoville", str(stage_root)),
            raw_stage(70, "07a", "Who Forest", None),
        ],
        drive,
    )

    assert [item["stage_key"] for item in result["stages"]] == ["07"]
    assert [item["stage_key"] for item in result["stages"][0]["sub_stages"]] == ["07a"]
    assert any(
        item["code"] == "PERSISTED_SUBSTAGE_PATH_REVIEW_REQUIRED"
        and str(item.get("stage_key")) == "07a"
        for item in result["review_required"]
    )
