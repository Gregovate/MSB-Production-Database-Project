from field_context_hierarchy import (
    build_field_hierarchy,
    resolve_display_operational_context,
)


def context(
    scene_name: str,
    *,
    stage_key: str,
    path: str | None,
    context_type: str = "Musical",
    preview_uuid: str = "preview-1",
    scene_uuid: str = "scene-1",
):
    return {
        "preview": {
            "preview_uuid": preview_uuid,
            "preview_name": "2026 Master Musical Preview",
            "preview_background_file": None,
        },
        "scene": {
            "scene_uuid": scene_uuid,
            "scene_name": scene_name,
            "scene_stage_key": stage_key,
            "scene_background_file": path,
        },
        "scope_kind": "Scene",
        "context_type": context_type,
    }


def raw_stage(
    stage_id: int,
    key: str,
    name: str,
    folder_path: str | None,
    contexts=None,
):
    return {
        "stage": {
            "stage_id": stage_id,
            "stage_key": key,
            "stage_name": name,
            "folder_path": folder_path,
        },
        "contexts": list(contexts or []),
    }


def test_build_hierarchy_does_not_touch_drive_root():
    class ForbiddenDriveRoot:
        def __fspath__(self):
            raise AssertionError("runtime browse must not touch Display Folders")

    result = build_field_hierarchy(
        [
            raw_stage(
                45,
                "15",
                "Show Background Stage 15 Church",
                r"G:\Shared drives\Display Folders\15-Church-Bells-CH",
            )
        ],
        ForbiddenDriveRoot(),
    )

    assert [item["label"] for item in result["stages"]] == ["15-Church-Bells-CH"]


def test_persisted_stage_folder_path_is_fast_field_label():
    result = build_field_hierarchy(
        [
            raw_stage(
                51,
                "21",
                "Show Background Stage 21 Polar Bears",
                r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB",
            )
        ]
    )

    stage = result["stages"][0]
    assert stage["label"] == "21-Polar Bear Playground-PB"
    assert stage["label_basis"] == "PERSISTED_STAGE_PATH"


def test_stale_stage_path_uses_stored_lor_path_string_without_filesystem_scan():
    result = build_field_hierarchy(
        [
            raw_stage(
                58,
                "39",
                "RGB Plus Stage 39 Parade Float",
                r"G:\Shared drives\Display Folders\40-Parade Float-PF",
                [
                    context(
                        "Parade Float",
                        stage_key="39",
                        path=(
                            r"G:\Shared drives\Display Folders\39-Parade Float-PF"
                            r"\Wiring\BackgroundStage\Parade.jpg"
                        ),
                    )
                ],
            )
        ]
    )

    stage = result["stages"][0]
    assert stage["label"] == "39-Parade Float-PF"
    assert stage["label_basis"] == "LOR_PATH_EVIDENCE"


def test_substage_is_nested_and_uses_lor_path_string_when_folder_path_missing():
    result = build_field_hierarchy(
        [
            raw_stage(
                37,
                "07",
                "Show Background Stage 07 WhoHouse Mt Crumpet",
                r"G:\Shared drives\Display Folders\07-Whoville-WV",
            ),
            raw_stage(
                59,
                "07a",
                "RGB Plus Stage 07a Who Forest",
                None,
                [
                    context(
                        "07a-Who Forest-WF",
                        stage_key="07a",
                        path=(
                            r"G:\Shared drives\Display Folders\07-Whoville-WV"
                            r"\07a-Who Forest-WF\PreviewBackground\Who-Forest.jpg"
                        ),
                    )
                ],
            ),
        ]
    )

    assert [item["stage_key"] for item in result["stages"]] == ["07"]
    sub = result["stages"][0]["sub_stages"][0]
    assert sub["stage_key"] == "07a"
    assert sub["label"] == "07a-Who Forest-WF"
    assert sub["label_basis"] == "LOR_PATH_EVIDENCE"


def test_stage_binding_scene_collapses_to_stage_context_when_path_has_no_child():
    result = build_field_hierarchy(
        [
            raw_stage(
                45,
                "15",
                "Show Background Stage 15 Church",
                r"G:\Shared drives\Display Folders\15-Church-Bells-CH",
                [
                    context(
                        "15-Church-CH",
                        stage_key="15",
                        path=(
                            r"G:\Shared drives\Display Folders\15-Church-Bells-CH"
                            r"\PreviewBackground\Church.jpg"
                        ),
                    )
                ],
            )
        ]
    )

    stage = result["stages"][0]
    assert stage["scenes"] == []
    assert [item["scene_name"] for item in stage["contexts"]] == [None]
    assert [item["scene_uuid"] for item in stage["contexts"]] == [None]
    assert [item["scope_kind"] for item in stage["contexts"]] == ["Stage / Preview"]


def test_scene_child_is_derived_from_path_string_not_drive_enumeration():
    result = build_field_hierarchy(
        [
            raw_stage(
                43,
                "13",
                "Show Background Stage 13 Winter Wonderland",
                r"G:\Shared drives\Display Folders\13-Winter Wonderland-WW",
                [
                    context(
                        "13-Christmas Story",
                        stage_key="13",
                        path=(
                            r"G:\Shared drives\Display Folders\13-Winter Wonderland-WW"
                            r"\13-Christmas Story\PreviewBackground\Story.jpg"
                        ),
                    )
                ],
            )
        ]
    )

    scenes = result["stages"][0]["scenes"]
    assert [item["label"] for item in scenes] == ["13-Christmas Story"]
    assert scenes[0]["scope_path_evidence"].endswith(r"13-Christmas Story")


def test_background_filename_with_stage_prefix_is_not_promoted_to_scene():
    result = build_field_hierarchy(
        [
            raw_stage(
                33,
                "03",
                "Show Background Stage 03 Welcome Area",
                r"G:\Shared drives\Display Folders\03-Welcome Area-WA",
                [
                    context(
                        "03-Welcome Area",
                        stage_key="03",
                        path=(
                            r"G:\Shared drives\Display Folders\03-Welcome Area-WA"
                            r"\PreviewBackground\03-welcome area.jpg"
                        ),
                    )
                ],
            )
        ]
    )

    stage = result["stages"][0]
    assert stage["scenes"] == []
    assert [item["scene_name"] for item in stage["contexts"]] == [None]


def test_legacy_nested_scene_with_short_code_is_retained_when_path_proves_child():
    result = build_field_hierarchy(
        [
            raw_stage(
                33,
                "03",
                "Show Background Stage 03 Welcome Area",
                r"G:\Shared drives\Display Folders\03-Welcome Area-WA",
                [
                    context(
                        "03-Mega Cube-MC",
                        stage_key="03",
                        path=(
                            r"G:\Shared drives\Display Folders\03-Welcome Area-WA"
                            r"\03-Mega Cube-MC\PreviewBackground\Mega.jpg"
                        ),
                    )
                ],
            )
        ]
    )

    assert [item["label"] for item in result["stages"][0]["scenes"]] == [
        "03-Mega Cube-MC"
    ]


def test_unprefixed_lor_group_is_context_evidence_not_browse_scene():
    result = build_field_hierarchy(
        [
            raw_stage(
                44,
                "14",
                "Show Background Stage 14 Icicle Tunnel",
                r"G:\Shared drives\Display Folders\14-Icicle Tunnel-IT",
                [
                    context(
                        "Anna",
                        stage_key="14",
                        path=(
                            r"G:\Shared drives\Display Folders\14-Icicle Tunnel-IT"
                            r"\Anna\PreviewBackground\Anna.jpg"
                        ),
                    )
                ],
            )
        ]
    )

    stage = result["stages"][0]
    assert stage["scenes"] == []
    assert [item["scene_name"] for item in stage["contexts"]] == [None]


def test_duplicate_nonformal_lor_scenes_collapse_to_one_whole_stage_context():
    result = build_field_hierarchy(
        [
            raw_stage(
                54,
                "24",
                "Show Background Stage 24 Traditional Christmas",
                r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC",
                [
                    context(
                        "ChristmasHippo",
                        stage_key="24",
                        path=(
                            r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                            r"\ChristmasHippo\PreviewBackground\Hippo.jpg"
                        ),
                        context_type="Background / Static",
                        preview_uuid="preview-24-background",
                        scene_uuid="scene-hippo",
                    ),
                    context(
                        "ChristmasTree",
                        stage_key="24",
                        path=(
                            r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                            r"\ChristmasTree\PreviewBackground\Tree.jpg"
                        ),
                        context_type="Background / Static",
                        preview_uuid="preview-24-background",
                        scene_uuid="scene-tree",
                    ),
                    context(
                        "24-Nutcracker-Ornaments",
                        stage_key="24",
                        path=(
                            r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                            r"\24-Nutcracker-Ornaments\PreviewBackground\Nutcracker.jpg"
                        ),
                        context_type="Background / Static",
                        preview_uuid="preview-24-background",
                        scene_uuid="scene-nutcracker",
                    ),
                    context(
                        "24-SnowFamily and 10YrStocking",
                        stage_key="24",
                        path=(
                            r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                            r"\24-SnowFamily and 10YrStocking\PreviewBackground\Snow.jpg"
                        ),
                        context_type="Background / Static",
                        preview_uuid="preview-24-background",
                        scene_uuid="scene-snow",
                    ),
                ],
            )
        ]
    )

    stage = result["stages"][0]
    assert len(stage["contexts"]) == 1
    assert stage["contexts"][0]["scene_uuid"] is None
    assert stage["contexts"][0]["scene_name"] is None
    assert [scene["label"] for scene in stage["scenes"]] == [
        "24-Nutcracker-Ornaments",
        "24-SnowFamily and 10YrStocking",
    ]


def test_display_with_unprefixed_lor_scene_resolves_to_whole_stage_package():
    shared = raw_stage(
        54,
        "24",
        "Show Background Stage 24 Traditional Christmas",
        r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC",
        [
            context(
                "ChristmasHippo",
                stage_key="24",
                path=(
                    r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                    r"\ChristmasHippo\PreviewBackground\Hippo.jpg"
                ),
                context_type="Background / Static",
                preview_uuid="preview-24-background",
                scene_uuid="scene-hippo",
            )
        ],
    )
    shared.update({"display_id": 141, "display_name": "TC-ChristmasHippo"})

    selected = resolve_display_operational_context(shared)

    assert selected is not None
    assert selected["scope_kind"] == "Stage / Preview"
    assert selected["preview"]["preview_uuid"] == "preview-24-background"
    assert selected["scene"] is None


def test_display_in_formal_scene_resolves_to_entire_scene_package():
    shared = raw_stage(
        54,
        "24",
        "Show Background Stage 24 Traditional Christmas",
        r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC",
        [
            context(
                "24-Nutcracker-Ornaments",
                stage_key="24",
                path=(
                    r"G:\Shared drives\Display Folders\24-Traditional Christmas-TC"
                    r"\24-Nutcracker-Ornaments\PreviewBackground\Nutcracker.jpg"
                ),
                context_type="Background / Static",
                preview_uuid="preview-24-background",
                scene_uuid="scene-nutcracker",
            )
        ],
    )
    shared.update({"display_id": 142, "display_name": "TC-Nutcracker-01"})

    selected = resolve_display_operational_context(shared)

    assert selected is not None
    assert selected["scope_kind"] == "Scene"
    assert selected["scene"]["scene_uuid"] == "scene-nutcracker"
    assert selected["scene"]["scene_name"] == "24-Nutcracker-Ornaments"


def test_animation_only_rows_without_physical_stage_path_are_excluded():
    result = build_field_hierarchy(
        [
            raw_stage(
                91,
                "90",
                "Show Animation EL 90 Elf On Shelf-1",
                None,
                [
                    context(
                        "Root",
                        stage_key="90",
                        path=None,
                        context_type="Animation",
                    )
                ],
            )
        ]
    )

    assert result["stages"] == []
    assert result["review_required"][0]["code"] == "DATABASE_STAGE_NOT_IN_FIELD_HIERARCHY"


def test_database_stage_without_lor_context_remains_browseable_for_manual_stage_use():
    result = build_field_hierarchy(
        [raw_stage(368, "40", "CommandCenter-CC", None, [])]
    )

    assert [item["stage_key"] for item in result["stages"]] == ["40"]
    assert result["stages"][0]["label"] == "CommandCenter-CC"
    assert result["review_required"][0]["code"] == "STAGE_PATH_EVIDENCE_REVIEW_REQUIRED"
