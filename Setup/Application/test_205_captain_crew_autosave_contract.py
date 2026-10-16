"""#205 autosave Captain and crew by field change with no redundant Save control."""
from pathlib import Path

SOURCE = (Path(__file__).parent / "setup_scheduling_board.js").read_text(encoding="utf-8")
STYLE = (Path(__file__).parent / "setup_scheduling_board.css").read_text(encoding="utf-8")


def test_each_crew_field_autosaves_and_button_is_gone():
    assert "setup-board205-save-crew" not in SOURCE
    assert "Saved automatically" in SOURCE
    assert "querySelector('.setup-board205-crew-captain-select')?.addEventListener('change', autosave)" in SOURCE
    for selector in (".setup-board205-crew-am", ".setup-board205-crew-pm"):
        assert selector in SOURCE
    assert "input?.addEventListener('change', autosave)" in SOURCE
    assert "input?.addEventListener('blur'" in SOURCE
    assert "setup-board205-retry-crew" in SOURCE
    assert "setup-board205-crew-save-status" in SOURCE
    assert "aria-live=" in SOURCE


def test_autosave_uses_existing_guarded_crew_patch_without_new_schema():
    handler = SOURCE.split("async function board205SaveCrew(crewId, crewNode) {", 1)[1].split(
        "\nasync function board205EnsureCrewSaved(", 1
    )[0]
    assert "appState.access?.can_manage_setup" in handler
    assert "commandOptions('PATCH', draft)" in handler
    assert "api/setup/scheduling-board/crews/" in handler
    assert "board205CrewCapacityWarnings" in handler
    assert "board205MaybeLearnCaptainForCrewAssignments" in handler
    assert "Captain is already assigned to another crew" in handler
    assert "if (state.promise) return state.promise" in handler
    assert "while (state.pending)" in handler
    assert "board205Load()" not in handler, "Do not re-render and erase another unsaved crew edit"
    assert "Not saved" in handler
    assert "setAlert(" in handler


def test_drop_waits_for_pending_crew_update_or_aborts():
    function = SOURCE.split("async function board205DropToCell(", 1)[1].split(
        "\nasync function board205NudgeAssignment(", 1
    )[0]
    assert "if (!await board205EnsureCrewSaved(crewId)) return;" in function
    assert function.index("board205EnsureCrewSaved(crewId)") < function.index("setBusy(true)")
    assert "setupBoard205State.dragged = null" in function


def test_autosave_status_is_visible_and_failed_writes_flagged():
    assert ".setup-board205-crew-save-status {" in STYLE
    assert ".setup-board205-crew-save-status.save-failed {" in STYLE
