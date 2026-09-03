from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent


def test_controller_page_loads_assignment_context() -> None:
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")
    assert "controllers_assignment_context.css" in html
    assert "controllers_assignment_context.js" in html


def test_assignment_context_is_read_only_and_compares_current_lor() -> None:
    source = (BASE_DIR / "static" / "controllers_assignment_context.js").read_text(
        encoding="utf-8"
    )

    assert "api(`api/wiring?display_id=${displayId}`)" in source
    assert "MATCH" in source
    assert "MISMATCH" in source
    assert "UNPROGRAMMED" in source
    assert "REVIEW_REQUIRED" in source
    assert "planning_controller_programming" in source
    assert "Repeated addresses may be intentional" in source
    assert "Assignment does not reprogram the Controller" in source

    assert "X-MSB-Controller-Command" not in source
    assert "method:'POST'" not in source
    assert "method:'PATCH'" not in source
    assert "method:'DELETE'" not in source


def test_non_assignment_device_is_blocked_in_ui_and_database() -> None:
    source = (BASE_DIR / "static" / "controllers_assignment_context.js").read_text(
        encoding="utf-8"
    )
    sql = (
        REPO_ROOT
        / "Controllers"
        / "Database"
        / "024_harden_controller_assignment_capability.sql"
    ).read_text(encoding="utf-8")

    assert "display_assignment_capable === false" in source
    assert "not a Display-assignment device" in sql
    assert "display_assignment_capable" in sql
    assert "ref.assign_controller_display" in sql
    assert "ref.reassign_controller_display" in sql
    assert "ref.unassign_controller_display" not in sql
    assert "GRANT EXECUTE ON FUNCTION ref.assign_controller_display" in sql
    assert "GRANT INSERT ON ref.controller_display" not in sql
