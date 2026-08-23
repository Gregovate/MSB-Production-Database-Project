from field_context_operator_messages import operator_warning, with_operator_warning


def test_scene_not_defined_maps_to_plain_wiring_warning():
    diagnostic = {
        "code": "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE",
        "scene_name": "21-Sliding Penguins",
        "scope_root": r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB",
    }

    message = operator_warning(diagnostic, task="Wiring")

    assert message == (
        "Wiring not found for 21-Sliding Penguins in folder "
        r"G:\Shared drives\Display Folders\21-Polar Bear Playground-PB."
    )
    assert "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE" not in message


def test_same_diagnostic_maps_to_procedure_specific_warning():
    diagnostic = {
        "code": "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE",
        "scene_name": "13-Christmas Story",
        "scope_root": r"G:\Shared drives\Display Folders\13-Winter Wonderland-WW",
    }

    assert operator_warning(diagnostic, task="Setup procedure") == (
        "Setup procedure not found for 13-Christmas Story in folder "
        r"G:\Shared drives\Display Folders\13-Winter Wonderland-WW."
    )


def test_unknown_engineering_code_never_leaks_to_operator():
    diagnostic = {
        "code": "SOME_INTERNAL_ENGINEERING_CODE",
        "scene_name": "21-SnowballBears",
    }

    message = operator_warning(diagnostic, task="Wiring")

    assert message == "Wiring is not available for 21-SnowballBears."
    assert "SOME_INTERNAL_ENGINEERING_CODE" not in message


def test_engineering_payload_can_keep_code_separate_from_operator_warning():
    diagnostic = {
        "code": "LOR_CONTEXT_UNRESOLVED",
        "scene_name": "07-Who People",
        "scope_root": r"G:\Shared drives\Display Folders\07-Whoville-WV",
    }

    result = with_operator_warning(diagnostic, task="Takedown procedure")

    assert result["code"] == "LOR_CONTEXT_UNRESOLVED"
    assert result["operator_warning"] == (
        "Takedown procedure location could not be resolved for 07-Who People in folder "
        r"G:\Shared drives\Display Folders\07-Whoville-WV."
    )
