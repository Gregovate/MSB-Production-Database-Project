from Procedures.Application import browser


def test_browser_index_is_served():
    browser.app.config.update(TESTING=True)
    with browser.app.test_client() as client:
        response = client.get("/")
    assert response.status_code == 200
    text = response.get_data(as_text=True)
    assert "Field Procedures" in text
    assert "Setup" in text
    assert "Takedown" in text
    assert "Inspection" in text
    assert "Includes current inventory Displays whether wired or not." in text
    assert "Selected Field Context" not in text
    assert 'id="selection-card"' not in text
    assert 'id="procedure-context"' in text
    assert 'id="clear-selection"' in text


def test_browser_assets_are_served():
    browser.app.config.update(TESTING=True)
    with browser.app.test_client() as client:
        css = client.get("/procedure.css")
        js = client.get("/procedure.js")
    assert css.status_code == 200
    assert css.mimetype == "text/css"
    assert js.status_code == 200
    assert js.mimetype == "application/javascript"


def test_browser_client_uses_only_procedure_api_contract():
    browser.app.config.update(TESTING=True)
    with browser.app.test_client() as client:
        text = client.get("/procedure.js").get_data(as_text=True)
    assert "api/displays" in text
    assert "api/stages" in text
    assert "api/procedures" in text
    assert "api/procedure/${kind}" in text
    assert "assetHref('document'" in text
    assert "assetHref('image'" in text
    assert "folder_path" not in text
    assert "SourceDocs" not in text
    assert "Archive/" not in text


def test_browser_compacts_resolved_context_into_instruction_card():
    browser.app.config.update(TESTING=True)
    with browser.app.test_client() as client:
        text = client.get("/procedure.js").get_data(as_text=True)
    assert "renderProcedureContext" in text
    assert "procedureContext.textContent" in text
    assert "selectionCard" not in text
    assert "selectionStatus" not in text
    assert "selectionGrid" not in text


def test_browser_supports_permanent_display_deep_link():
    browser.app.config.update(TESTING=True)
    with browser.app.test_client() as client:
        text = client.get("/procedure.js").get_data(as_text=True)
    assert "params.get('display_id')" in text
    assert "selectDisplay(Number(displayId))" in text
    assert "params.get('task')" in text


def test_browser_host_preserves_backend_api_routes():
    rules = {rule.rule for rule in browser.app.url_map.iter_rules()}
    assert "/api/health" in rules
    assert "/api/displays" in rules
    assert "/api/displays/<int:display_id>/context" in rules
    assert "/api/stages" in rules
    assert "/api/procedures" in rules
    assert "/api/procedure/document" in rules
    assert "/api/procedure/image" in rules
