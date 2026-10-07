"""Executable regression for guided contents decisions and installed projections."""
from pathlib import Path
import subprocess
import json
import pytest

APP = Path(__file__).parent


def test_actual_record_location_decisions_review_and_payload():
    source = (APP / 'setup_record_location.js').read_text()
    exports = '''globalThis.workflow = {
      renderContentsDecision, reconciliationPayload, contentsReview, priorLocationText,
      movementPayload, recordPending, renderRecordReadiness, applyQueuedContainerContext,
      renderDisplayPlacement, confirmPlacementStage, needsDisplayPlacement,
      display: (state) => {pendingIdentity={asset_type:'DISPLAY',asset_id:901,identity:'DISP:901'};
        pendingStateRow=state;displayPlacement=null;placementStageId=null;pendingContents=null;},
      placement: (value) => {displayPlacement=value;placementStageId=null;},
      gpsOff: () => {watchId=null;latestPosition=null;},
      select: (contents) => {pendingIdentity={asset_type:'CONTAINER',asset_id:216,identity:'CONT:216'};
        pendingContents=contents;pendingStateRow=contents;access={can_move_setup_assets:true,authenticated_email:'operator@example.org'};},
      decide: (value, identify=false) => {contentsDecision=value;identifyRemaining=identify;},
      gps: () => {watchId=1;latestPosition={timestamp:Date.now(),coords:{latitude:1,longitude:2,accuracy:3}};}
    };'''
    source = source.replace('  void initialize();', exports)
    source = source.replace('async function sendOrQueue(payload) {',
                            'async function sendOrQueue(payload) { globalThis.saved=payload; return {movement:{},queued:false};')
    harness = r'''
    const assert=require('node:assert/strict');
    class Element {
      constructor(){this.children=[];this.dataset={};this.value='';this.textContent='';this.disabled=false;this.hidden=false;this.checked=false;}
      set innerHTML(value){this.children=[];this._html=value;} get innerHTML(){return this._html||'';}
      appendChild(child){this.children.push(child);} addEventListener(){} setAttribute(k,v){this[k]=v;}
      focus(){} blur(){}
      querySelectorAll(query){const all=this.children.flatMap(c=>[c,...c.querySelectorAll('*')]);
        return query.includes('input') ? all.filter(c=>c.dataset.displayId && (!query.includes(':checked')||c.checked)) : all;}
    }
    const elements={};globalThis.document={getElementById:id=>elements[id]??=new Element(),createElement:()=>new Element(),
      querySelector:()=>new Element(),addEventListener(){},body:{classList:{toggle(){}}}};
    globalThis.window={crypto:{randomUUID:()=> '88000000-0000-4000-8000-000000000001'},setInterval(){},addEventListener(){},confirm:()=>false};
    globalThis.navigator={onLine:true};globalThis.location={search:'?season_year=2026'};
    globalThis.localStorage={getItem:()=> 'device',setItem(){}};
    '''
    assertions = r'''
    const w=workflow;
    const contents={label:'Panels',home_location_code:'RC02-A-01',last_movement_event_id:33,reconciliation_allowed:true,
      displays:[{display_id:900,display_name:'WV-MtCrumpitPanel-01'},{display_id:901,display_name:'CH-PeaceOnEarth'}],
      prior_location:{event_type:'CONTAINER_MOVE',named_context:'Prior park drop',gps_accuracy_m:5.12,occurred_at:'2026-10-07T10:00:00Z'}};
    w.select(contents);assert.throws(()=>w.reconciliationPayload(),/Choose Empty/);
    w.decide('NOT_SURE');assert.deepEqual(w.reconciliationPayload(),{decision:'NOT_SURE',identify_remaining:false});
    w.decide('EMPTY');let p=w.reconciliationPayload();assert.deepEqual(p.expected_display_ids,[900,901]);assert.equal(p.prior_event_id,33);
    assert.match(w.contentsReview(p),/WV-MtCrumpitPanel-01/);assert.ok(!w.contentsReview(p).includes('900'));
    w.decide('NOT_EMPTY',true);w.renderContentsDecision();let boxes=elements['movement-unload-groups'].querySelectorAll('input');
    assert.equal(boxes.length,2);assert.ok(boxes.every(x=>x.checked));boxes[1].checked=false;
    p=w.reconciliationPayload();assert.deepEqual(p.remaining_display_ids,[900]);assert.match(w.contentsReview(p),/CH-PeaceOnEarth/);
    boxes[0].checked=false;assert.throws(()=>w.reconciliationPayload(),/at least one/);
    w.decide('NOT_EMPTY',false);assert.equal(w.reconciliationPayload().expected_display_ids,undefined);
    assert.match(w.contentsReview(w.reconciliationPayload()),/later review/);
    w.gps();let returned=w.movementPayload({asset_type:'CONTAINER',asset_id:216},'RETURNED','HID_SCAN',[]);
    assert.equal(returned.gps_latitude,undefined);assert.equal(returned.destination_location_note,null);
    assert.match(w.priorLocationText(),/±17 ft/);
    w.select({...contents,reconciliation_allowed:false});w.decide('EMPTY');assert.throws(()=>w.reconciliationPayload(),/cannot be reconciled/);
    w.renderContentsDecision();let empty=elements['movement-unload-groups'].children[2].children[0];assert.ok(empty.disabled);
    w.select(null);w.decide('EMPTY');assert.throws(()=>w.reconciliationPayload(),/cannot be reconciled/);
    w.decide('NOT_SURE');w.renderRecordReadiness();assert.ok(elements['movement-return-home'].disabled);
    const queued={season_year:2026,asset_type:'CONTAINER',asset_id:216,client_event_id:'offline-prior',occurred_at:'2026-10-07T11:00:00Z',
      movement_action:'CONTAINER_MOVE',destination_location_note:'Offline park drop',gps_accuracy_m:3,queue_status:'QUEUED',
      reconciliation:{decision:'NOT_SURE'}};
    const offline=w.applyQueuedContainerContext(contents,[queued],216);
    w.select(offline);w.decide('EMPTY');assert.equal(w.reconciliationPayload().prior_client_event_id,'offline-prior');
    assert.match(w.priorLocationText(),/Offline park drop/);
    assert.equal(w.applyQueuedContainerContext(contents,[{...queued,queue_status:'FAILED'}],216).reconciliation_allowed,false);
    w.select(contents);w.decide('EMPTY');elements['movement-known-reference'].value='Workshop current scan';
    // Cancellation does not write, clear the reviewed identity, or queue an event.
    await w.recordPending(true);assert.equal(w.reconciliationPayload().prior_event_id,33);
    const display={label:'CH-PeaceOnEarth',container_id:216,can_detach:true,position_mode:'WITH_CONTAINER',
      placement_stages:[{stage_id:15,stage_key:'15',stage_name:'Church-ParkingLot',assigned:true},
        {stage_id:16,stage_key:'16',stage_name:'Other actual Stage',assigned:false}]};
    w.display(display);w.renderDisplayPlacement();w.renderRecordReadiness();
    assert.ok(elements['movement-record-here'].disabled);assert.ok(w.needsDisplayPlacement());
    w.placement('NO');await w.recordPending(false);assert.equal(globalThis.saved,undefined);
    w.placement('NOT_SURE');await w.recordPending(false);assert.equal(globalThis.saved,undefined);
    w.placement('YES');w.renderDisplayPlacement();await w.recordPending(false);
    assert.equal(globalThis.saved,undefined); // Assigned Stage has not been silently confirmed.
    w.gpsOff();w.confirmPlacementStage(16);elements['movement-location-note'].value='';
    w.renderRecordReadiness();assert.ok(!elements['movement-record-here'].disabled); // Confirmed Stage needs no GPS.
    await w.recordPending(false);assert.equal(globalThis.saved,undefined); // Final review cancelled.
    window.confirm=()=>true;await w.recordPending(false);
    assert.equal(saved.asset_id,901);assert.equal(saved.movement_action,'DISPLAY_MOVE');
    assert.equal(saved.destination_stage_id,16);assert.equal(saved.display_placement,'YES');
    assert.equal(saved.destination_location_note,'16 · Other actual Stage');assert.deepEqual(saved.unloaded_display_ids,[]);
    assert.equal(saved.gps_latitude,undefined);
    assert.match(saved.notes,/direct_display_observation=true/);
    w.display({...display,can_detach:false});w.placement('YES');w.confirmPlacementStage(15);globalThis.saved=undefined;
    await w.recordPending(false);assert.equal(saved,undefined);
    w.display({...display,position_mode:'DETACHED'});assert.equal(w.needsDisplayPlacement(),false);
    w.display({label:'OFFLINE — CURRENT CONTEXT UNAVAILABLE'});assert.ok(w.needsDisplayPlacement());
    w.placement('YES');await w.recordPending(false);assert.equal(saved,undefined);
    assert.deepEqual(w.applyQueuedContainerContext(contents,[{asset_type:'DISPLAY',asset_id:901,season_year:2026,
      movement_action:'DISPLAY_MOVE',queue_status:'QUEUED'}],216).displays.map(row=>row.display_id),[900]);
    console.log('guided decisions PASS');
    '''
    script = harness + source + '(async()=>{' + assertions + '})().catch(e=>{console.error(e);process.exit(1)});'
    result = subprocess.run(['node', '-e', script], text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr


def test_reconciliation_api_passes_snapshot_through_governed_command(monkeypatch):
    from flask import Flask
    import setup_movement_api as api
    class Repo:
        def record_event(self, **kwargs):
            captured.update(kwargs)
            return {'duplicate_event': False}
    captured = {}
    monkeypatch.setattr(api, 'require_setup_command', lambda: None)
    monkeypatch.setattr(api, 'require_movement_operator', lambda: (None,'operator@example.org',{}))
    monkeypatch.setattr(api, 'repo', lambda: Repo())
    app=Flask(__name__);app.register_blueprint(api.setup_movement_api)
    payload=dict(season_year=2026,client_event_id='88000000-0000-4000-8000-000000000001',
                 asset_type='CONTAINER',asset_id=216,movement_action='RETURNED',occurred_at='2026-10-07T10:00:00Z',
                 reconciliation={'decision':'EMPTY','expected_display_ids':[1,2], 'prior_event_id':33})
    result=app.test_client().post('/api/setup/movements',json=payload)
    assert result.status_code==201
    assert captured['reconciliation']==payload['reconciliation']
    assert captured['gps_latitude'] is None
    payload['reconciliation']['decision']='INVALID'
    assert app.test_client().post('/api/setup/movements',json=payload).status_code==403
    payload.update(asset_type='DISPLAY',asset_id=901,movement_action='DISPLAY_MOVE',display_placement='NO')
    payload.pop('reconciliation')
    captured.clear()
    for decision in ('NO','NOT_SURE','YES'):
        payload['display_placement']=decision
        assert app.test_client().post('/api/setup/movements',json=payload).status_code==403
        assert not captured
    payload.update(display_placement='YES',destination_stage_id=15,
                   destination_location_note='15 · Church-ParkingLot',notes='display_setup_location_confirmed=true')
    assert app.test_client().post('/api/setup/movements',json=payload).status_code==201
    assert captured['destination_stage_id']==15
    assert captured['movement_action']=='DISPLAY_MOVE'


def test_c095_latest_gps_keeps_prior_named_context_without_history_update():
    # Import fixture directly without installing Production method mutations here.
    import test_setup_175_current_location as fixture
    monkeypatch=pytest.MonkeyPatch()
    generator=fixture.projection.__wrapped__(monkeypatch)
    repo,conn=next(generator)
    try:
        conn.execute("UPDATE ops.setup_movement_event SET container_id=178,event_type='CONTAINER_MOVE' WHERE setup_movement_event_id IN (41,44)")
        conn.execute("UPDATE ops.setup_movement_event SET destination_location_note='15-Church-ParkingLot' WHERE setup_movement_event_id=41")
        item=repo.field_context(task_id=1,season_year=2026)['displays'][0]
        assert item['current_location_note']=='15-Church-ParkingLot'
        assert item['current_gps_latitude']==43.778556
        assert item['current_named_context_inherited']
        assert conn.execute('SELECT destination_location_note FROM ops.setup_movement_event WHERE setup_movement_event_id=44').fetchone()[0] is None
        conn.execute("ALTER TABLE ops.setup_container_state ADD COLUMN last_movement_at TEXT")
        from setup_material_readiness_repository import SetupMaterialReadinessRepository
        readiness=SetupMaterialReadinessRepository('fixture-only')
        monkeypatch.setattr(readiness,'connect',repo.connect)
        state=readiness._observation_state(setup_session_id=1,container_ids=[178],display_ids=[])
        assert state[('CONTAINER',178)]['current_location_note']=='15-Church-ParkingLot'
        # A new explicit return boundary prevents borrowing old park context.
        conn.execute("UPDATE ops.setup_movement_event SET event_type='RETURNED' WHERE setup_movement_event_id=44")
        assert repo.field_context(task_id=1,season_year=2026)['displays'][0]['current_location_note'] is None
    finally:
        generator.close();monkeypatch.undo()
