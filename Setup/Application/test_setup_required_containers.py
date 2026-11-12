"""Direct Container requirements reach the existing annual/manual pick projection."""
from contextlib import contextmanager
import pytest
from setup_material_readiness_repository import SetupMaterialReadinessRepository
from setup_material_readiness_projection import project_physical_demand
from setup_required_containers import required_containers, set_required_container
from setup_next_repository import SetupNextRepositoryError


@pytest.mark.parametrize('scheduled,moved,workshop,can_add', [
    (False, False, False, True), (True, False, False, False),
    (False, True, False, False), (False, False, True, False)])
def test_c106_annual_requirement_manual_pick_and_movement_gates(monkeypatch, scheduled, moved, workshop, can_add):
    repo = SetupMaterialReadinessRepository('synthetic-only')
    task = dict(setup_task_id=10, setup_session_task_id=20, task_name='Setup Who People',
                execution_status='NOT_STARTED', stage_id=9, stage_key='09', stage_name='Who Ville')
    reason = dict(task, demand_origin='DIRECT_SCHEDULE', reason_type='REQUIRED_CONTAINER')
    item = dict(physical_type='CONTAINER', physical_id=106, identity='CONT:106',
                label='Who Ville Panel Stands (8)', reasons=[reason], manager_overrides=[])
    monkeypatch.setattr(repo, 'material_readiness', lambda year: dict(
        session=dict(setup_session_id=1), physical_items=[item] if scheduled else []))
    monkeypatch.setattr(repo, '_annual_demand_graph', lambda sid: ({20: task}, {}))
    monkeypatch.setattr(repo, '_material_bearing_session_task_ids', lambda sid: {20})
    monkeypatch.setattr(repo, '_extra_material_rows', lambda ids, year: [])
    monkeypatch.setattr(repo, '_bulk_unscheduled_material_contexts', lambda **kw: {10: dict(
        displays=[], support_containers=[dict(container_id=106,
        container_description='Who Ville Panel Stands (8)', relationship_type='REQUIRED_CONTAINER')])})
    monkeypatch.setattr(repo, '_observation_state', lambda **kw:
        {('CONTAINER', 106): dict(movement_status='PICKED')} if moved else {})
    monkeypatch.setattr(repo, '_container_endpoint_policy', lambda ids: {106: 1 if workshop else 228})
    result = repo.manager_material_status(2026)['items']
    assert len(result) == 1
    assert result[0]['identity'] == 'CONT:106'
    assert result[0]['can_add_to_pick_list'] is can_add
    assert result[0]['on_pick_list'] is scheduled
    assert result[0]['reasons'][0]['reason_type'] == 'REQUIRED_CONTAINER'


def test_shared_required_container_deduplicates_without_material_quantity():
    rows = [dict(physical_type='CONTAINER', physical_id=106, identity='CONT:106',
                 setup_task_id=i, setup_session_task_id=i, setup_work_day_task_id=i,
                 work_date='2026-10-16', reason_type='REQUIRED_CONTAINER') for i in (1, 2)]
    items = project_physical_demand(rows)
    assert len(items) == 1
    assert len(items[0]['reasons']) == 2


class Cursor:
    def __init__(self): self.calls = []; self.result = {'ok': True}
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def execute(self, sql, params): self.calls.append((sql, params))
    def fetchone(self): return self.result
    def fetchall(self): return [{'container_id': 106, 'assigned': True}]


class Connection:
    def __init__(self): self.cur = Cursor(); self.commits = 0
    def cursor(self, **kwargs): return self.cur
    def commit(self): self.commits += 1


class Repository:
    def __init__(self): self.conn = Connection()
    @contextmanager
    def connect(self): yield self.conn
    write_connect = connect


def test_save_uses_actor_attributed_command_and_returns_persisted_links():
    repo = Repository()
    assert set_required_container(repo, email='manager@example.test', task_id=10,
                                  container_id=106, assigned=True)[0]['assigned']
    assert repo.conn.cur.calls[0][1] == ('manager@example.test', 10, 106, True, None)
    assert 'ref.set_setup_task_required_container' in repo.conn.cur.calls[0][0]
    assert repo.conn.commits == 1
    assert "'REQUIRED_CONTAINER'" in repo.conn.cur.calls[-1][0]


def test_missing_command_result_never_commits():
    repo = Repository(); repo.conn.cur.result = None
    with pytest.raises(SetupNextRepositoryError):
        set_required_container(repo, email='manager@example.test', task_id=10,
                               container_id=106, assigned=True)
    assert repo.conn.commits == 0


@pytest.fixture
def assignment_client(monkeypatch):
    from flask import Flask
    import setup_assignment_api as api
    app = Flask(__name__)
    app.register_blueprint(api.setup_assignment_api)
    monkeypatch.setattr(api, 'require_manager', lambda: (None, 'manager@example.test', {}))
    monkeypatch.setattr(api, 'require_setup_command', lambda: None)
    monkeypatch.setattr(api, 'repo', Repository)
    return app.test_client(), api


def test_protected_api_requires_no_material_fields(assignment_client):
    client, _ = assignment_client
    response = client.patch('/api/setup/tasks/10/required-containers/106', json={'assigned': True})
    assert response.status_code == 200
    assert response.json['containers'] == [{'container_id': 106, 'assigned': True}]


@pytest.mark.parametrize('value', [None, 'true', 1])
def test_required_api_rejects_non_boolean(assignment_client, value):
    client, _ = assignment_client
    assert client.patch('/api/setup/tasks/10/required-containers/106', json={'assigned': value}).status_code == 403


def test_required_api_denies_nonmanager_and_missing_command(assignment_client, monkeypatch):
    from setup_api import SetupCommandError
    client, api = assignment_client
    def denied(): raise SetupCommandError('Manager required')
    monkeypatch.setattr(api, 'require_manager', denied)
    assert client.get('/api/setup/tasks/10/required-containers').status_code == 403
    assert client.patch('/api/setup/tasks/10/required-containers/106', json={'assigned': True}).status_code == 403
    monkeypatch.setattr(api, 'require_manager', lambda: (None, 'manager@example.test', {}))
    monkeypatch.setattr(api, 'require_setup_command', denied)
    assert client.patch('/api/setup/tasks/10/required-containers/106', json={'assigned': True}).status_code == 403
