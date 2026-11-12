from pathlib import Path


ROOT = Path(__file__).resolve().parent
DB_ROOT = ROOT.parent / "Database"


def read_db(name: str) -> str:
    return (DB_ROOT / name).read_text(encoding="utf-8")


def test_captain_candidate_projection_requires_active_person() -> None:
    sql = read_db("022_require_active_setup_captain_people.sql")
    assert "CREATE OR REPLACE FUNCTION ref.setup_captain_person_list()" in sql
    assert "FROM ref.person p" in sql
    assert "WHERE p.active_flag" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.setup_captain_person_list() TO fieldwiring_app" in sql


def test_captain_write_command_rejects_inactive_person_for_active_assignment() -> None:
    sql = read_db("022_require_active_setup_captain_people.sql")
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_captain" in sql
    assert "AND p.active_flag" in sql
    assert "Selected person is inactive and cannot receive a Setup Captain / knowledge-owner assignment" in sql
    assert "IF coalesce(p_active, true)" in sql
    assert "DELETE FROM ref.setup_task_captain" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_captain" in sql
