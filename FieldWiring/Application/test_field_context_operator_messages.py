from field_context_operator_messages import operator_warning, with_operator_warning


def test_scene_not_defined_maps_to_exact_musical_wiring_folder():
    diagnostic = {
        "code": "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE",
        "scene_name": "21-Sliding Penguins",
        "scope_root": r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB",
    }

    message = operator_warning(
        diagnostic,
        task="Wiring",
        task_relative_folder=r"Wiring\MusicalStage",
    )

    assert message == (
        "Wiring not found for 21-Sliding Penguins in folder "
        r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\MusicalStage."
    )
    assert "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE" not in message


def test_same_diagnostic_maps_to_exact_background_wiring_folder():
    diagnostic = {
        "code": "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE",
        "scene_name": "21-Sliding Penguins",
        "scope_root": r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB",
    }

    assert operator_warning(
        diagnostic,
        task="Wiring",
        task_relative_folder=r"Wiring\BackgroundStage",
    ) == (
        "Wiring not found for 21-Sliding Penguins in folder "
        r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\BackgroundStage."
    )


def test_same_diagnostic_maps_to_exact_setup_procedure_folder():
    diagnostic = {
        "code": "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE",
        "scene_name": "13-Christmas Story",
        "scope_root": r"G:\Shared drives\Display Folders\13-Winter Wonderland-WW",
    }

    assert operator_warning(
        diagnostic,
        task="Setup procedure",
        task_relative_folder=r"Procedures\Setup",
    ) == (
        "Setup procedure not found for 13-Christmas Story in folder "
        r"G:\Shared drives\Display Folders\13-Winter Wonderland-WW\Procedures\Setup."
    )


def test_takedown_and_inspection_paths_are_caller_selected():
    diagnostic = {
        "code": "LOR_CONTEXT_UNRESOLVED",
        "scene_name": "07-Who People",
        "scope_root": r"G:\Shared drives\Display Folders\07-Whoville-WV",
    }

    takedown = operator_warning(
        diagnostic,
        task="Takedown procedure",
        task_relative_folder=r"Procedures\Takedown",
    )
    inspection = operator_warning(
        diagnostic,
        task="Inspection procedure",
        task_relative_folder=r"Procedures\Inspection",
    )

    assert r"\Procedures\Takedown" in takedown
    assert r"\Procedures\Inspection" in inspection


def test_unknown_engineering_code_never_leaks_and_keeps_expected_folder():
    diagnostic = {
        "code": "SOME_INTERNAL_ENGINEERING_CODE",
        "scene_name": "21-SnowballBears",
        "scope_root": r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\21-SnowballBears",
    }

    message = operator_warning(
        diagnostic,
        task="Wiring",
        task_relative_folder=r"Wiring\MusicalStage",
    )

    assert message == (
        "Wiring is not available for 21-SnowballBears. Expected folder: "
        r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\21-SnowballBears\Wiring\MusicalStage."
    )
    assert "SOME_INTERNAL_ENGINEERING_CODE" not in message


def test_engineering_payload_keeps_code_separate_from_operator_warning():
    diagnostic = {
        "code": "LOR_CONTEXT_UNRESOLVED",
        "scene_name": "07-Who People",
        "scope_root": r"G:\Shared drives\Display Folders\07-Whoville-WV",
    }

    result = with_operator_warning(
        diagnostic,
        task="Takedown procedure",
        task_relative_folder=r"Procedures\Takedown",
    )

    assert result["code"] == "LOR_CONTEXT_UNRESOLVED"
    assert result["operator_warning"] == (
        "Takedown procedure location could not be resolved for 07-Who People. Expected folder: "
        r"G:\Shared drives\Display Folders\07-Whoville-WV\Procedures\Takedown."
    )


def test_server_mount_is_textually_translated_to_operator_drive_path():
    diagnostic = {
        "code": "LOR_CONTEXT_UNRESOLVED",
        "scene_name": "21-Sliding Penguins",
        "scope_root": "/mnt/msb-display-folders/21-Polar Bear Playground-PB",
    }

    message = operator_warning(
        diagnostic,
        task="Setup procedure",
        task_relative_folder=r"Procedures\Setup",
    )

    assert (
        r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Procedures\Setup"
        in message
    )
    assert "/mnt/msb-display-folders" not in message


def test_operator_mapper_is_formatting_only_source_contract():
    source = __import__("pathlib").Path(
        __file__
    ).with_name("field_context_operator_messages.py").read_text(encoding="utf-8")

    assert "psycopg" not in source
    assert "sqlite" not in source
    assert "requests" not in source
    assert ".exists(" not in source
    assert ".is_dir(" not in source
    assert ".is_file(" not in source
    assert ".iterdir(" not in source
