from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_reusable_catalog_exposes_material_checkbox_and_governed_save() -> None:
    js = read("setup_catalog_effort.js")
    assert "applySetupCatalogMaterialControls" in js
    assert "setup-catalog-material-checkbox" in js
    assert "Uses Display / Container Material" in js
    assert "saveCatalogSetupMaterialRequirement" in js
    assert "api/setup/tasks/${task.setup_task_id}/display-material" in js
    assert "requires_display_material: requires" in js
    assert "Inactive reusable tasks cannot be selected for Display ownership" in js


def test_catalog_material_selection_defines_visible_ownership_targets() -> None:
    js = read("setup_catalog_effort.js")
    assert "function materialScopeTasks(task)" in js
    assert "Boolean(candidate?.active_flag)" in js
    assert "Boolean(candidate?.requires_display_material)" in js
    assert "setupMaterialScopeKey(candidate) === key" in js
    assert "selectedChecked && checkedTasks.length > 1" in js
    assert ".setup-display-owner-column[data-target-task-id]" in js
    assert "column.hidden = shouldHideColumn" in js
    assert "only reusable tasks checked Uses Display / Container Material in the Catalog are shown" in js


def test_catalog_selection_preserves_stage_vs_real_scene_scope() -> None:
    js = read("setup_catalog_effort.js")
    assert "function isRealSetupSceneName(sceneName)" in js
    assert "return !/-[A-Za-z]{2}$/.test(name);" in js
    assert "return `SCENE:${sceneId}`" in js
    assert "return `STAGE:${stageId}`" in js


def test_material_selection_sync_is_mutation_safe() -> None:
    js = read("setup_catalog_effort.js")
    assert "control.hidden !== shouldHideControl" in js
    assert "column.hidden !== shouldHideColumn" in js
    assert "note.innerHTML !== noteHtml" in js
    assert "note.hidden !== shouldHideNote" in js
    assert "MutationObserver" in js


def test_catalog_hint_explains_preselection_before_display_assignment() -> None:
    js = read("setup_catalog_effort.js")
    assert "check Uses Display / Container Material on the reusable tasks that actually need Display material" in js
    assert "open one of those tasks to assign the resolved Displays between only those checked tasks" in js
