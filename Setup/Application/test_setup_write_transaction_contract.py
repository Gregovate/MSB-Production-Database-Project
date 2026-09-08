from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent


def _source(name: str) -> str:
    return (BASE_DIR / name).read_text(encoding="utf-8")


def test_setup_repositories_preserve_readonly_default_and_opt_in_for_commands() -> None:
    for filename in (
        "setup_repository.py",
        "setup_resource_repository.py",
        "setup_next_repository.py",
    ):
        source = _source(filename)
        assert "def connect(self)" in source
        assert "def write_connect(self)" in source
        assert "conn.set_session(readonly=False, autocommit=False)" in source


def test_core_setup_commands_use_explicit_write_connections() -> None:
    source = _source("setup_repository.py")
    for command in (
        "create_session",
        "create_task",
        "update_task",
        "update_session_task_review",
    ):
        start = source.index(f"    def {command}(")
        next_def = source.find("\n    def ", start + 1)
        block = source[start:] if next_def == -1 else source[start:next_def]
        assert "with self.write_connect()" in block
        assert "conn.commit()" in block


def test_resource_commands_use_explicit_write_connections() -> None:
    source = _source("setup_resource_repository.py")
    for command in ("create_resource", "set_task_resource"):
        start = source.index(f"    def {command}(")
        next_def = source.find("\n    def ", start + 1)
        block = source[start:] if next_def == -1 else source[start:next_def]
        assert "with self.write_connect()" in block
        assert "conn.commit()" in block


def test_planning_commands_use_explicit_write_connections() -> None:
    source = _source("setup_next_repository.py")
    for command in (
        "set_scope",
        "set_dependency",
        "set_planned_order",
        "promote_plan_baseline",
        "upsert_work_day",
        "set_work_day_task",
        "record_progress",
    ):
        start = source.index(f"    def {command}(")
        next_def = source.find("\n    def ", start + 1)
        block = source[start:] if next_def == -1 else source[start:next_def]
        assert "with self.write_connect()" in block
        assert "conn.commit()" in block
