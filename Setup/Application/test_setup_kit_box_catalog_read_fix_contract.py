from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_kit_box_catalog_fix_is_installed_after_assignment_layer() -> None:
    backend = read("production_backend.py")
    assignment_index = backend.index("install_setup_assignment_layer()")
    fix_index = backend.index("install_setup_kit_box_catalog_fix()")
    assert assignment_index < fix_index
    assert "from setup_kit_box_catalog_fix import install_setup_kit_box_catalog_fix" in backend


def test_kit_box_catalog_reads_only_type_2_without_container_type_join() -> None:
    source = read("setup_kit_box_catalog_fix.py")
    assert "WHERE c.container_type_id = 2" in source
    assert "'Kit Box'::text AS container_type_name" in source
    assert "JOIN ref.container_type" not in source
    assert "relationship_type = 'KIT'" in source
    assert "other_task_count" in source
    assert "other_task_assignments" in source
