from __future__ import annotations

from pathlib import Path

from field_context_browse import resolve_field_hierarchy
from field_context_resolver import MARKER_NAME


class FakeRepository:
    def __init__(self, items):
        self.items = items

    def stages(self):
        return self.items


def mark(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    (path / MARKER_NAME).write_text("scope", encoding="utf-8")
    return path


def evidence_file(root: Path, *parts: str) -> str:
    path = root.joinpath(*parts)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"x")
    return str(path)


def context(scene_name: str, scene_uuid: str, pointer: str, preview_uuid: str = "p1"):
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
            "scene_stage_key": None,
            "scene_background_file": pointer,
        },
        "scope_kind": "Scene",
        "context_type": "Musical",
    }


def stage_item(stage_id: int, stage_key: str, stage_name: str, folder_path: str | None, contexts=None):
    return {
        "stage": {
            "stage_id": stage_id,
            "stage_key": stage_key,
            "stage_name": stage_name,
            "folder_path": folder_path,
        },
        "contexts": list(contexts or []),
    }


def by_key(hierarchy, key: str):
    return next(item for item in hierarchy["stages"] if item["stage_key"] == key)


def test_stage_15_root_contexts_collapse_to_one_field_stage(tmp_path):
    drive = tmp_path / "Display Folders"
    church = mark(drive / "15-Church-Bells-CH")
    pointer = evidence_file(church, "Wiring", "MusicalStage", "church.jpg")

    items = [
        stage_item(
            45,
            "15",
            "Show Background Stage 15 Church",
            str(church),
            [
                context("15-Church-CH", "scene-musical", pointer),
                context("Root", "scene-root", pointer, "p2"),
            ],
        )
    ]

    result = resolve_field_hierarchy(FakeRepository(items), drive)
    assert len(result["stages"]) == 1
    stage = result["stages"][0]
    assert stage["label"] == "15-Church-Bells-CH"
    assert stage["database_stage_name"] == "Show Background Stage 15 Church"
    assert stage["scenes"] == []
    assert {c["scene"]["scene_name"] for c in stage["contexts"]} == {
        "15-Church-CH",
        "Root",
    }


def test_stage_07_contains_07a_substage_and_defined_scene(tmp_path):
    drive = tmp_path / "Display Folders"
    stage = mark(drive / "07-Whoville-WV")
    who_people = mark(stage / "07-Who People")
    substage = mark(stage / "07a-Who Forest-WF")
    stale_substage = stage / "07a-Who Forest"
    stale_substage.mkdir()

    stage_pointer = evidence_file(who_people, "PreviewBackground", "people.jpg")
    sub_pointer = evidence_file(substage, "Wiring", "MusicalStage", "forest.jpg")

    items = [
        stage_item(
            37,
            "07",
            "Show Background Stage 07 WhoHouse Mt Crumpet",
            str(stage),
            [context("07-Who People", "scene-people", stage_pointer)],
        ),
        stage_item(
            59,
            "07a",
            "RGB Plus Stage 07a Who Forest",
            str(stale_substage),
            [context("07a-Who Forest-WF", "scene-forest", sub_pointer)],
        ),
    ]

    result = resolve_field_hierarchy(FakeRepository(items), drive)
    assert [item["stage_key"] for item in result["stages"]] == ["07"]
    whoville = result["stages"][0]
    assert [item["label"] for item in whoville["scenes"]] == ["07-Who People"]
    assert [item["stage_key"] for item in whoville["sub_stages"]] == ["07a"]
    forest = whoville["sub_stages"][0]
    assert forest["label"] == "07a-Who Forest-WF"
    assert forest["scenes"] == []
    assert any(
        item["code"] == "PERSISTED_SUBSTAGE_PATH_REVIEW_REQUIRED"
        and item["stage_key"] == "07a"
        for item in result["review_required"]
    )


def test_stage_13_and_21_emit_only_distinct_defined_scene_roots(tmp_path):
    drive = tmp_path / "Display Folders"
    winter = mark(drive / "13-Winter Wonderland-WW")
    christmas_story = mark(winter / "13-Christmas Story")
    bears = mark(drive / "21-Polar Bear Playground-PB")
    snowballs = mark(bears / "21-SnowballBears")

    story_pointer = evidence_file(christmas_story, "PreviewBackground", "story.jpg")
    winter_root_pointer = evidence_file(winter, "Wiring", "BackgroundStage", "stage.jpg")
    snowball_pointer = evidence_file(snowballs, "PreviewBackground", "snowballs.jpg")
    bears_root_pointer = evidence_file(bears, "Wiring", "BackgroundStage", "stage.jpg")

    items = [
        stage_item(
            43,
            "13",
            "Show Background Stage 13 Winter Wonderland",
            str(winter),
            [
                context("13-Christmas Story", "story", story_pointer),
                context("13-Grover Train", "grover", winter_root_pointer, "p2"),
            ],
        ),
        stage_item(
            51,
            "21",
            "Show Background Stage 21 Polar Bears",
            str(bears),
            [
                context("21-SnowballBears", "snowballs", snowball_pointer),
                context("21-Sliding Penguins", "sliding", bears_root_pointer, "p2"),
                context("Root", "root", bears_root_pointer, "p3"),
            ],
        ),
    ]

    result = resolve_field_hierarchy(FakeRepository(items), drive)
    assert [item["label"] for item in by_key(result, "13")["scenes"]] == [
        "13-Christmas Story"
    ]
    assert [item["label"] for item in by_key(result, "21")["scenes"]] == [
        "21-SnowballBears"
    ]


def test_raw_lor_scene_does_not_promote_unprefixed_group_folder(tmp_path):
    drive = tmp_path / "Display Folders"
    entrance = mark(drive / "01-Front Entrance-FE")
    goal = mark(entrance / "Goal Sign")
    pointer = evidence_file(goal, "PreviewBackground", "goal.jpg")

    items = [
        stage_item(
            31,
            "01",
            "Show Background Stage 01 FE Open-Close Sign",
            str(entrance),
            [context("Goal Sign", "goal", pointer)],
        )
    ]

    result = resolve_field_hierarchy(FakeRepository(items), drive)
    entrance_node = result["stages"][0]
    assert entrance_node["scenes"] == []
    assert any(
        item["code"] == "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE"
        and item["scene_name"] == "Goal Sign"
        for item in result["review_required"]
    )


def test_stage_39_40_alignment_is_review_not_browse_guess(tmp_path):
    drive = tmp_path / "Display Folders"
    drive.mkdir()
    parade = drive / "40-Parade Float-PF"
    parade.mkdir()

    items = [
        stage_item(58, "39", "RGB Plus Stage 39 Parade Float", str(parade)),
        stage_item(368, "40", "CommandCenter-CC", None),
    ]

    result = resolve_field_hierarchy(FakeRepository(items), drive)
    assert result["stages"] == []
    review_keys = {item.get("stage_key") for item in result["review_required"]}
    assert {"39", "40"}.issubset(review_keys)
    assert any(
        item["code"] == "STAGE_ROOT_UNMARKED" and item["stage_key"] == "40"
        for item in result["review_required"]
    )


def test_database_only_90_series_rows_are_not_normal_field_stages(tmp_path):
    drive = tmp_path / "Display Folders"
    mark(drive / "15-Church-Bells-CH")

    items = [
        stage_item(45, "15", "Show Background Stage 15 Church", str(drive / "15-Church-Bells-CH")),
        stage_item(91, "90", "Show Animation EL 90 Elf On Shelf-1", None),
        stage_item(92, "91", "Show Animation EL 91 Elf On Shelf-2", None),
    ]

    result = resolve_field_hierarchy(FakeRepository(items), drive)
    assert [item["stage_key"] for item in result["stages"]] == ["15"]
    review_keys = {item.get("stage_key") for item in result["review_required"]}
    assert {"90", "91"}.issubset(review_keys)
