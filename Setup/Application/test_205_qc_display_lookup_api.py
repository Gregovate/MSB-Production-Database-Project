"""#205 QC Display lookup: exercising the actual protected Flask route.

No Production database or Node.js needed. This verifies identity/authorization
handoff, correct search arguments, and that the route performs no writes.
"""
from flask import Flask
import setup_scheduling_board_api as mod


def test_qc_lookup_uses_existing_reader_and_exact_year(monkeypatch):
    observed = {}
    def reader():
        observed["authorized"] = True
    class Repository:
        def qc_display_lookup(self, year, query):
            observed.update(year=year, query=query)
            return [
                dict(display_id=12, display_name="John's Tree",
                     setup_session_task_id=422,
                     relationship="STAGE_CANDIDATE", work_reports=3)
            ]
    monkeypatch.setattr(mod, "require_reader", reader)
    monkeypatch.setattr(mod, "repo", lambda: Repository())
    app = Flask(__name__)
    app.register_blueprint(mod.setup_scheduling_board_api)
    response = app.test_client().get(
        "/api/setup/scheduling-board/qc-displays?season_year=2026&q=John"
    )
    assert response.status_code == 200
    assert observed == {"authorized": True, "year": 2026, "query": "John"}
    assert response.json["displays"][0]["display_id"] == 12
    assert response.json["displays"][0]["relationship"] == "STAGE_CANDIDATE"


def test_qc_lookup_rejects_long_query_before_db_call(monkeypatch):
    monkeypatch.setattr(mod, "require_reader", lambda: None)
    class Repository:
        def qc_display_lookup(self, *args):
            raise AssertionError("Database was accessed for overlong search")
    monkeypatch.setattr(mod, "repo", lambda: Repository())
    app = Flask(__name__)
    app.register_blueprint(mod.setup_scheduling_board_api)
    # The handler raises the existing SetupCommandError, which Production
    # registers globally; call the route under a context to assert its gate.
    from setup_api import SetupCommandError
    with app.test_request_context(
        "/api/setup/scheduling-board/qc-displays?season_year=2026&q=" + "x"*101
    ):
        import pytest
        with pytest.raises(SetupCommandError, match="Display search is too long"):
            mod.api_setup_qc_display_lookup()
