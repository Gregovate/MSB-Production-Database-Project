from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def test_compact_resource_picker_is_loaded_after_task_detail_refinement() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    backend = (APP_DIR / "production_backend.py").read_text(encoding="utf-8")

    assert "setup_resource_picker_compact.css?v=2026-09-11.2" in html
    assert "setup_resource_picker_compact.js?v=2026-09-11.2" in html
    assert html.index("setup_task_detail_compact.js?v=2026-09-11.1") < html.index(
        "setup_resource_picker_compact.js?v=2026-09-11.2"
    )
    assert '"setup_resource_picker_compact.css"' in backend
    assert '"setup_resource_picker_compact.js"' in backend


def test_normal_flow_is_picker_first_and_catalog_manager_opens_on_demand() -> None:
    js = (APP_DIR / "setup_resource_picker_compact.js").read_text(encoding="utf-8")
    css = (APP_DIR / "setup_resource_picker_compact.css").read_text(encoding="utf-8")

    assert "Resource picker" in js
    assert "Manage Resource Catalog" in js
    assert "Close Resource Catalog" in js
    assert "Resource not listed or named poorly?" in js
    assert "catalogEditor.hidden = true" in js
    assert "createBlock.hidden = true" in js
    assert "aria-expanded" in js
    assert ".resource-catalog-secondary[hidden]" in css


def test_manage_catalog_action_has_local_visual_emphasis() -> None:
    css = (APP_DIR / "setup_resource_picker_compact.css").read_text(encoding="utf-8")

    assert "#setup-resource-catalog-toggle" in css
    assert "background: var(--accent-soft)" in css
    assert "border-color: var(--accent)" in css
    assert "color: var(--accent)" in css
    assert "font-weight: 700" in css


def test_catalog_close_action_is_colored_and_beside_catalog_save() -> None:
    js = (APP_DIR / "setup_resource_picker_compact.js").read_text(encoding="utf-8")

    assert "catalogEditor.querySelector('.action-row')" in js
    assert "setup-resource-catalog-close" in js
    assert "success resource-catalog-close" in js
    assert "catalogActionRow.appendChild(closeButton)" in js
    assert "toggle.hidden = true" in js
    assert "toggle.hidden = false" in js
    assert "closeButton.addEventListener('click', closeCatalog)" in js


def test_name_is_normal_picker_order_and_numeric_order_is_advanced() -> None:
    repo = (APP_DIR / "setup_resource_repository.py").read_text(encoding="utf-8")
    js = (APP_DIR / "setup_resource_picker_compact.js").read_text(encoding="utf-8")

    catalog_order = repo.split("FROM ref.setup_resource", 1)[1].split('"""', 1)[0]
    assert "resource_name" in catalog_order
    assert catalog_order.index("resource_name") < catalog_order.index("resource_type")
    assert "Optional display order" in js
    assert "meaningful names drive the normal picker order" in js
    assert "sort.value === 'ORDER'" in js
    assert "sort.value = 'NAME'" in js
