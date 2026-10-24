import { createFixtureDatabase } from "./power_test_database.mjs";
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import path from "node:path";
const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const db = await createFixtureDatabase();
let revision = 0,
  n = 0;
const base = {
  source_evidence: "Observed label in fixture",
  verification_status: "UNVERIFIED",
};
async function cmd(
  kind,
  fields,
  id = null,
  email = "crew@example.test",
  rev = revision,
  uuid = crypto.randomUUID(),
) {
  const r = await db.query(
    "SELECT ref.site_power_command($1,$2::uuid,$3,$4,$5,$6::jsonb) AS result",
    [email, uuid, rev, kind, id, JSON.stringify(fields)],
  );
  revision = r.rows[0].result.revision;
  n++;
  return r.rows[0].result;
}
const p = await cmd("panel", { ...base, panel_name: "Panel A", owner_name: "City Owned", year_installed: 2018 });
const panelRecord=await db.query("SELECT owner_name,year_installed FROM ref.site_panel WHERE site_panel_id=$1",[p.target_id]);
assert.equal(panelRecord.rows[0].owner_name,"City Owned");
assert.equal(panelRecord.rows[0].year_installed,2018);
n++;
const c = await cmd("circuit", {
  ...base,
  site_panel_id: p.target_id,
  circuit_code: "1",
});
await cmd("feed", {
  ...base,
  source_circuit_id: c.target_id,
  destination_waypoint_id: 11,
});
await cmd("feed", {
  ...base,
  source_circuit_id: c.target_id,
  destination_waypoint_id: 12,
});
async function denied(fn, code) {
  await assert.rejects(fn, (e) => e.code === code);
  n++;
}
for (const email of [
  "volunteer@example.test",
  "inactive@example.test",
  "norole@example.test",
  "missing@example.test",
])
  await denied(
    () => cmd("panel", { ...base, panel_name: "denied" }, null, email),
    "42501",
  );
await denied(
  () =>
    cmd(
      "panel",
      { ...base, panel_name: "stale" },
      null,
      "crew@example.test",
      0,
    ),
  "40001",
);
await denied(
  () =>
    cmd("circuit", {
      ...base,
      site_panel_id: p.target_id,
      circuit_code: " 1 ",
    }),
  "23505",
);
await denied(
  () =>
    cmd("panel", { ...base, panel_name: "spoof", verified_by_person_id: 2 }),
  "22023",
);
// A normal Crew panel save requires no free-text verification or evidence.
const simpleFields={panel_name:"Field capture without notes"};
const simpleUuid=crypto.randomUUID(), simpleRevision=revision;
const simple = await cmd("panel", simpleFields, null, "crew@example.test", revision, simpleUuid);
assert.equal((await cmd("panel", simpleFields, null, "crew@example.test", simpleRevision, simpleUuid)).replayed,true);
n++;
const simpleStatus = await db.query(
  "SELECT source_evidence,verification_status FROM ref.site_panel WHERE site_panel_id=$1",
  [simple.target_id],
);
assert.equal(simpleStatus.rows[0].source_evidence, null);
assert.equal(simpleStatus.rows[0].verification_status, "UNVERIFIED");
n++;
await denied(() => cmd('panel', {...base, active:false}, p.target_id), '23514');
await denied(() => cmd('circuit', {...base, active:false}, c.target_id), '23514');
const p2 = await cmd("panel", {
  ...base,
  panel_name: "Panel B",
  verification_status: "VERIFIED",
});
await denied(
  () => cmd("circuit", { ...base, site_panel_id: p2.target_id }, c.target_id),
  "22023",
);
await cmd("circuit", {
  ...base,
  site_panel_id: p2.target_id,
  circuit_code: "1",
});
await cmd("panel", { panel_name: "Panel B label corrected" }, p2.target_id);
const correctedPanel = await db.query(
  "SELECT verification_status,verified_by_person_id,verified_at FROM ref.site_panel WHERE site_panel_id=$1",
  [p2.target_id],
);
assert.equal(correctedPanel.rows[0].verification_status, "UNVERIFIED");
assert.equal(correctedPanel.rows[0].verified_by_person_id, null);
assert.equal(correctedPanel.rows[0].verified_at, null);
n++;
const uuid = crypto.randomUUID(),
  payload = { ...base, panel_name: "Replay" };
const first = await cmd(
  "panel",
  payload,
  null,
  "crew@example.test",
  revision,
  uuid,
);
const replay = await cmd("panel", payload, null, "crew@example.test", 0, uuid);
assert.equal(first.target_id, replay.target_id);
assert.equal(replay.replayed, true);
await denied(
  () =>
    cmd(
      "panel",
      { ...payload, panel_name: "changed" },
      null,
      "crew@example.test",
      revision,
      uuid,
    ),
  "22023",
);
const d1 = await cmd("device", {
    ...base,
    device_name: "Fuse",
    device_kind: "FUSE",
  }),
  d2 = await cmd("device", {
    ...base,
    device_name: "Disconnect",
    device_kind: "DISCONNECT",
  });
await cmd("feed", {
  ...base,
  source_circuit_id: c.target_id,
  destination_device_id: d1.target_id,
});
await cmd("feed", {
  ...base,
  source_device_id: d1.target_id,
  destination_device_id: d2.target_id,
});
await denied(
  () =>
    cmd("feed", {
      ...base,
      source_device_id: d2.target_id,
      destination_device_id: d1.target_id,
    }),
  "23514",
);
await cmd("network", { ...base, site_waypoint_id: 11, site_network_id: 1 });
await cmd("network", { ...base, site_waypoint_id: 11, site_network_id: 2 });
const a = await cmd("action", {
  ...base,
  action_name: "Utility off",
  site_power_circuit_id: c.target_id,
  phase: "SETUP",
  action_kind: "REQUEST_UTILITY",
});
const a2 = await cmd("action", {
  ...base,
  action_name: "Energize show",
  site_power_circuit_id: c.target_id,
  phase: "SETUP",
  action_kind: "ENERGIZE",
  prerequisite_action_ids: [a.target_id],
});
await denied(
  () =>
    cmd(
      "action",
      { ...base, prerequisite_action_ids: [a2.target_id] },
      a.target_id,
    ),
  "23514",
);
const event = {
  site_power_action_id: a.target_id,
  season_year: 2026,
  event_kind: "UTILITY_REQUESTED",
  condition: "UNKNOWN",
  observed_at: new Date().toISOString(),
  evidence: "Fixture utility request",
};
await cmd("event", event);
await denied(
  () => cmd("event", { ...event, event_kind: "COMPLETED" }),
  "22023",
);
await denied(
  () =>
    cmd("event", {
      ...event,
      site_power_action_id: a2.target_id,
      event_kind: "COMPLETED",
    }),
  "23514",
);
const completed = await cmd("event", {
  ...event,
  event_kind: "UTILITY_CONFIRMED",
  condition: "OFF",
});
await cmd("event", {
  ...event,
  site_power_action_id: a2.target_id,
  event_kind: "COMPLETED",
  condition: "ON",
});
await denied(
  () =>
    cmd("event", {
      ...event,
      site_power_action_id: a2.target_id,
      season_year: 2025,
      event_kind: "COMPLETED",
    }),
  "23514",
);
await cmd(
  "action",
  { ...base, action_name: "Utility corrected name" },
  a.target_id,
);
let snapshot = (
  await db.query("SELECT ref.site_power_snapshot('crew@example.test') AS data")
).rows[0].data;
assert.equal(
  snapshot.events.find((e) => e.event_id === completed.target_id)
    .definition_snapshot.action_name,
  "Utility off",
);
assert.equal(
  snapshot.events.filter((e) => e.event_kind === "FIELD_VERIFIED").length,
  0,
);
assert.equal(snapshot.circuits[0].show_desired_state, "UNKNOWN");
assert.equal(snapshot.networks.length, 2);
assert.equal(
  snapshot.waypoints.find((w) => w.id === 11).aliases[0],
  "Old Outlet A",
);
assert.equal(
  snapshot.panels.find((x) => x.site_panel_id === p2.target_id)
    .verified_by_person_id,
  null,
);
assert.equal(
  snapshot.panels.find((x) => x.site_panel_id === p2.target_id)
    .verification_status,
  "UNVERIFIED",
);
assert.ok(
  snapshot.history.every(
    (h) => h.person_id === 1 && h.operator_email === "crew@example.test",
  ),
);
await db.exec(
  "GRANT USAGE ON SCHEMA ref,ops TO fieldwiring_app; SET ROLE fieldwiring_app;",
);
await cmd("panel", { ...base, panel_name: "Least privilege crew write" });
assert.ok(
  (
    await db.query(
      "SELECT ref.site_power_snapshot('crew@example.test') AS data",
    )
  ).rows[0].data.panels.length > 0,
);
await denied(
  () => db.exec("UPDATE ref.site_panel SET panel_name='illegal'"),
  "42501",
);
await denied(() => db.exec("DELETE FROM ops.site_power_edit_log"), "42501");
await denied(
  () => db.query("SELECT ref.site_power_snapshot('inactive@example.test')"),
  "42501",
);
await db.exec("RESET ROLE;");
// Prove an atomic batch rolls back its first successful command on later failure.
const priorCount = (
  await db.query("SELECT count(*)::int AS n FROM ref.site_panel")
).rows[0].n;
await db.exec("BEGIN");
await cmd("panel", { ...base, panel_name: "rolled back" });
await denied(
  () =>
    cmd("feed", {
      ...base,
      source_circuit_id: c.target_id,
      destination_waypoint_id: 9999,
    }),
  "23503",
);
await db.exec("ROLLBACK");
assert.equal(
  (await db.query("SELECT count(*)::int AS n FROM ref.site_panel")).rows[0].n,
  priorCount,
);
// Grouped breaker regression: two receptacles at one waypoint, asymmetric
// onward paths, shared neutral, immutable event evidence and no name-based joins.
revision = (await db.query("SELECT revision FROM ref.site_power_revision")).rows[0].revision;
await db.exec("INSERT INTO ref.site_waypoint VALUES (21,'Quad fixture','OUT-Combo'),(22,'Continuation fixture','OUT-Combo')");
const groupedPanel = await cmd("panel", {...base,panel_name:"Grouped fixture"});
const breaker = await cmd("breaker", {...base,site_panel_id:groupedPanel.target_id,breaker_name:"18/20",rated_amps:20,pole_count:2});
const legA = await cmd("circuit", {...base,site_panel_id:groupedPanel.target_id,circuit_code:"18",site_power_breaker_id:breaker.target_id,breaker_pole:1});
const legB = await cmd("circuit", {...base,site_panel_id:groupedPanel.target_id,circuit_code:"20",site_power_breaker_id:breaker.target_id,breaker_pole:2});
await denied(() => cmd("circuit", {...base,site_panel_id:groupedPanel.target_id,circuit_code:"duplicate",site_power_breaker_id:breaker.target_id,breaker_pole:2}),"23505");
await denied(() => cmd("circuit", {...base,site_panel_id:p.target_id,circuit_code:"cross-panel",site_power_breaker_id:breaker.target_id,breaker_pole:3}),"23514");
await denied(() => cmd("breaker", {...base,pole_count:1},breaker.target_id),"23514");
const socketA = await cmd("device", {...base,device_name:"Quad receptacle A",device_kind:"OUTLET",site_waypoint_id:21});
const socketB = await cmd("device", {...base,device_name:"Quad receptacle B",device_kind:"OUTLET",site_waypoint_id:21});
await cmd("feed", {...base,source_circuit_id:legA.target_id,destination_device_id:socketA.target_id});
await cmd("feed", {...base,source_circuit_id:legB.target_id,destination_device_id:socketB.target_id});
await cmd("feed", {...base,source_device_id:socketA.target_id,destination_waypoint_id:22});
// Two same-breaker legs above are allowed; an independent breaker is not.
const competing = await cmd("breaker", {...base,site_panel_id:groupedPanel.target_id,breaker_name:"Other supply",rated_amps:15,pole_count:1});
const competingLeg = await cmd("circuit", {...base,site_panel_id:groupedPanel.target_id,circuit_code:"Other supply",site_power_breaker_id:competing.target_id,breaker_pole:1});
await denied(()=>cmd("feed",{...base,source_circuit_id:competingLeg.target_id,destination_waypoint_id:21}),"23514");
await denied(()=>cmd("feed",{...base,source_circuit_id:competingLeg.target_id,destination_device_id:socketA.target_id}),"23514");
await denied(()=>cmd("circuit",{...base,site_power_breaker_id:competing.target_id,breaker_pole:1},legB.target_id),"23505");
await denied(()=>cmd("breaker",{...base,rated_amps:20.000001},breaker.target_id),"23514");
const spareBreaker=await cmd("breaker",{...base,site_panel_id:groupedPanel.target_id,breaker_name:"Unoccupied independent breaker",rated_amps:30,pole_count:1});
await denied(()=>cmd("circuit",{...base,site_power_breaker_id:spareBreaker.target_id,breaker_pole:1},legB.target_id),"23514");
await denied(()=>cmd("circuit",{...base,site_power_breaker_id:null,breaker_pole:null},legB.target_id),"23514");

let impact = (await db.query("SELECT ref.site_power_breaker_impact('crew@example.test',$1) AS x",[breaker.target_id])).rows[0].x;
assert.equal(impact.breaker.rated_amps,20);
assert.equal(impact.missing_pole_membership,false);
assert.equal(impact.paths.filter(x => x.waypoint_id===21).length,2);
assert.equal(impact.paths.filter(x => x.waypoint_id===22).length,1);
assert.equal(impact.coverage,"RECORDED_ONLY_NOT_PROOF_OF_ISOLATION");
await cmd("cable_spec", {...base,site_cable_id:1,cable_specification:"12-3 operator observation"});
const neutral = await cmd("conductor", {...base,site_cable_id:1,conductor_label:"Recorded neutral",conductor_role:"NEUTRAL"});
await cmd("conductor_circuit", {...base,site_power_conductor_id:neutral.target_id,site_power_circuit_id:legA.target_id});
await cmd("conductor_circuit", {...base,site_power_conductor_id:neutral.target_id,site_power_circuit_id:legB.target_id});
await denied(() => cmd("conductor", {...base,conductor_role:"HOT"},neutral.target_id),"23514");
await denied(() => cmd("conductor", {...base,active:false},neutral.target_id),"23514");
const action = await cmd("action", {...base,action_name:"Grouped OFF",site_power_breaker_id:breaker.target_id,phase:"SETUP",action_kind:"OTHER",desired_state:"OFF"});
const oldRevision=revision;
await cmd("breaker", {...base,breaker_name:"Corrected breaker label"},breaker.target_id);
await denied(() => cmd("event",{impact_reviewed:true,site_power_action_id:action.target_id,season_year:2026,event_kind:"REPORTED",condition:"OFF",observed_at:new Date().toISOString(),evidence:"Fixture observation"},null,"crew@example.test",oldRevision),"40001");
const groupedEvent=await cmd("event",{impact_reviewed:true,site_power_action_id:action.target_id,season_year:2026,event_kind:"REPORTED",condition:"OFF",observed_at:new Date().toISOString(),evidence:"Fixture observation"});
await db.exec("UPDATE ref.site_waypoint SET canonical_label='Corrected quad name' WHERE site_waypoint_id=21");
impact = (await db.query("SELECT ref.site_power_breaker_impact('crew@example.test',$1) AS x",[breaker.target_id])).rows[0].x;
assert.equal(impact.paths.find(x=>x.waypoint_id===21).waypoint_name,"Corrected quad name");
const eventSnapshot = (await db.query("SELECT definition_snapshot FROM ops.setup_power_activity_event WHERE event_id=$1",[groupedEvent.target_id])).rows[0].definition_snapshot;
assert.notEqual(eventSnapshot.impact.paths.find(x=>x.waypoint_id===21).waypoint_name,"Corrected quad name");
await denied(() => cmd("action", {...base,action_name:"Invalid leg switch",site_power_circuit_id:legA.target_id,phase:"SETUP",action_kind:"OTHER",desired_state:"OFF"}),"23514");
await cmd("circuit", {...base,show_desired_state:"OFF"},legA.target_id);
await denied(() => cmd("circuit", {...base,show_desired_state:"ON"},legB.target_id),"23514");
const single=await cmd("breaker", {...base,site_panel_id:groupedPanel.target_id,breaker_name:"Single",rated_amps:15,pole_count:1});
await cmd("circuit", {...base,site_panel_id:groupedPanel.target_id,circuit_code:"Single",site_power_breaker_id:single.target_id,breaker_pole:1});
await denied(() => db.query("SELECT ref.site_power_breaker_impact('inactive@example.test',$1)",[breaker.target_id]),"42501");
// Panel-board positions and main disconnect are independently audited facts.
await cmd("breaker", {...base,breaker_role:"BRANCH",panel_positions:[18,20]}, breaker.target_id);
for (const positions of [[18],[1,1],[0],[201],[2,4]]) {
  await denied(()=>cmd("breaker",{...base,site_panel_id:groupedPanel.target_id,
    breaker_name:"Invalid position",breaker_role:"BRANCH",pole_count:positions.join(",")==="2,4"?1:positions.length,
    panel_positions:positions}),"23514");
}
await cmd("breaker",{...base,breaker_role:"BRANCH",panel_positions:[1]},single.target_id);
const main=await cmd("breaker",{...base,site_panel_id:groupedPanel.target_id,
  breaker_name:"Main",breaker_role:"MAIN",rated_amps:100,pole_count:2});
await denied(()=>cmd("breaker",{...base,site_panel_id:groupedPanel.target_id,
  breaker_name:"Duplicate main",breaker_role:"MAIN"}),"23505");
await denied(()=>cmd("breaker",{...base,panel_positions:[3,5]},main.target_id),"23514");
await denied(()=>cmd("circuit",{...base,site_panel_id:groupedPanel.target_id,
  circuit_code:"Invalid main pole",site_power_breaker_id:main.target_id,breaker_pole:1}),"23514");
const mainImpact=(await db.query("SELECT ref.site_power_breaker_impact('crew@example.test',$1) AS x",[main.target_id])).rows[0].x;
assert.ok(mainImpact.circuits.includes(legA.target_id));
assert.ok(mainImpact.circuits.includes(legB.target_id));
assert.equal(mainImpact.breaker.rated_amps,100);
assert.equal(mainImpact.coverage,"RECORDED_ONLY_NOT_PROOF_OF_ISOLATION");
// One schedule Save owns the breaker, both legs and direct endpoints atomically.
const schedulePanel=await cmd("panel",{...base,panel_name:"Schedule fixture"});
const scheduleFields={breaker:{...base,site_panel_id:schedulePanel.target_id,breaker_name:"31/33",breaker_role:"BRANCH",panel_positions:[31,33],pole_count:2,rated_amps:20},
  show_desired_state:"ON",restoration_desired_state:"OFF",
  legs:[{pole:1,circuit_code:"31",waypoint_ids:[]},{pole:2,circuit_code:"33",waypoint_ids:[]}]};
const request=crypto.randomUUID(), initialRevision=revision;
const schedule=await cmd("breaker_schedule",scheduleFields,null,"crew@example.test",revision,request);
const savedLegs=(await db.query("SELECT site_power_circuit_id FROM ref.site_power_circuit WHERE site_power_breaker_id=$1 ORDER BY breaker_pole",[schedule.target_id])).rows;
const receipt=await cmd("breaker_schedule",scheduleFields,null,"crew@example.test",initialRevision,request);
assert.equal(receipt.replayed,true); assert.equal(receipt.target_id,schedule.target_id);
await denied(()=>cmd("breaker_schedule",{...scheduleFields,show_desired_state:"OFF"},null,"crew@example.test",revision,request),"22023");
await cmd("breaker_schedule",{...scheduleFields,show_desired_state:"OFF"},schedule.target_id);
assert.deepEqual((await db.query("SELECT site_power_circuit_id FROM ref.site_power_circuit WHERE site_power_breaker_id=$1 ORDER BY breaker_pole",[schedule.target_id])).rows,savedLegs);
assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_power_circuit WHERE site_power_breaker_id=$1 AND show_desired_state='OFF'",[schedule.target_id])).rows[0].n,2);
const beforeFailure=(await db.query("SELECT revision FROM ref.site_power_revision")).rows[0].revision;
await denied(()=>cmd("breaker_schedule",{...scheduleFields,breaker:{...scheduleFields.breaker,breaker_name:"Should roll back"},legs:[scheduleFields.legs[0],{pole:2,circuit_code:"33",waypoint_ids:[999999]}]},schedule.target_id),"23503");
assert.equal((await db.query("SELECT revision FROM ref.site_power_revision")).rows[0].revision,beforeFailure);
assert.equal((await db.query("SELECT breaker_name FROM ref.site_power_breaker WHERE site_power_breaker_id=$1",[schedule.target_id])).rows[0].breaker_name,"31/33");
await denied(()=>cmd("breaker_schedule",{...scheduleFields,legs:[scheduleFields.legs[0]]},schedule.target_id),"23514");
await denied(()=>cmd("breaker_schedule",scheduleFields,null,"volunteer@example.test"),"42501");
await denied(()=>cmd("breaker_schedule",scheduleFields,null,"crew@example.test",0),"40001");
// Remote panel points to an actual breaker, never a guessed panel-name relationship.
const remote=await cmd("panel",{...base,panel_name:"Remote fixture",meter_information:"Meter fixture",supply_breaker_id:schedule.target_id});
const downstream=await cmd("breaker_schedule",{...scheduleFields,breaker:{...scheduleFields.breaker,site_panel_id:remote.target_id}},null);
const downstreamCircuit=(await db.query("SELECT site_power_circuit_id FROM ref.site_power_circuit WHERE site_power_breaker_id=$1 LIMIT 1",[downstream.target_id])).rows[0].site_power_circuit_id;
const impactRemote=(await db.query("SELECT ref.site_power_breaker_impact('crew@example.test',$1) x",[schedule.target_id])).rows[0].x;
assert.ok(impactRemote.affected_panel_ids.includes(remote.target_id));
assert.ok(impactRemote.circuits.includes(downstreamCircuit));
await denied(()=>cmd("panel",{...base,supply_breaker_id:downstream.target_id},schedulePanel.target_id),"23514");
await denied(()=>cmd("panel",{...base,supply_breaker_id:downstream.target_id},remote.target_id),"23514");
await denied(()=>cmd("breaker",{...base,site_panel_id:remote.target_id,breaker_name:"Conflicting main",breaker_role:"MAIN"}),"23514");
await denied(()=>cmd("breaker",{...base,active:false},schedule.target_id),"23514");
// Inventory identity is reused for enclosure placement AND independent plug-in supply.
// Combo capability applies to both outlet boxes and light poles.
const comboPole=await cmd("controller_installation",{controller_id:104,site_waypoint_id:99});
assert.ok(comboPole.target_id > 0);
n++;
const install=await cmd("controller_installation",{...base,controller_id:101,site_waypoint_id:11});
await cmd("controller_installation",{...base,controller_id:102,site_waypoint_id:11});
await denied(()=>cmd("controller_installation",{...base,controller_id:101,site_waypoint_id:12}),"23505");
await denied(()=>cmd("controller_installation",{...base,controller_id:103,site_waypoint_id:13}),"22023");
await denied(()=>cmd("controller_installation",{...base,site_waypoint_id:12},install.target_id),"22023");
await cmd("controller_installation",{...base,active:false},install.target_id);
await cmd("controller_installation",{...base,controller_id:101,site_waypoint_id:12});
const supply=await cmd("feed",{...base,source_circuit_id:downstreamCircuit,destination_waypoint_id:13});
const plugFields={...base,controller_id:101,site_waypoint_id:13,site_power_circuit_id:downstreamCircuit};
const plugRequest=crypto.randomUUID(), plugRevision=revision;
const plug=await cmd("controller_power_connection",plugFields,null,"crew@example.test",revision,plugRequest);
assert.equal((await cmd("controller_power_connection",plugFields,null,"crew@example.test",plugRevision,plugRequest)).replayed,true);
await denied(()=>cmd("controller_power_connection",plugFields),"23505");
await denied(()=>cmd("controller_power_connection",{...plugFields,controller_id:102,site_waypoint_id:12}),"23514");
await denied(()=>cmd("controller_power_connection",{...plugFields,controller_id:102},null,"volunteer@example.test"),"42501");
await denied(()=>cmd("feed",{...base,active:false},supply.target_id),"23514");
await denied(()=>cmd("controller_power_connection",{...base,site_waypoint_id:12},plug.target_id),"22023");
await cmd("controller_power_connection",{...base,active:false},plug.target_id);
await cmd("feed",{...base,active:false},supply.target_id);
await cmd("feed",{...base,source_circuit_id:downstreamCircuit,destination_waypoint_id:13});
await cmd("controller_power_connection",plugFields);
const plugImpact=(await db.query("SELECT ref.site_power_breaker_impact('crew@example.test',$1) x",[downstream.target_id])).rows[0].x;
assert.ok(plugImpact.controller_connections.some(x=>x.controller_id===101 && x.site_waypoint_id===13));
// An indirect electrical path supports a plug without equating inventory placement with power.
await db.exec("INSERT INTO ref.site_waypoint VALUES(14,'Indirect outlet','Power')");
const intermediate=await cmd("device",{...base,device_name:"Fixture outlet feed",device_kind:"OUTLET",site_waypoint_id:14});
await cmd("feed",{...base,source_circuit_id:downstreamCircuit,destination_device_id:intermediate.target_id});
await cmd("controller_power_connection",{...plugFields,controller_id:103,site_waypoint_id:14});
await denied(()=>cmd("controller_power_connection",{...plugFields,controller_id:999999}),"23503");
const inventorySnapshot=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') AS x")).rows[0].x;
assert.equal(inventorySnapshot.controller_options.length,4);
assert.equal(inventorySnapshot.controller_installations.filter(x=>x.controller_id===101).length,2);
assert.equal(inventorySnapshot.controller_power_connections.filter(x=>x.controller_id===101).length,2);
assert.ok(inventorySnapshot.history.some(x=>x.command==='controller_power_connection' && x.before_data?.active===true && x.after_data?.active===false));
await denied(()=>db.exec("SET ROLE fieldwiring_app; DELETE FROM ref.site_controller_installation"),"42501");
await db.exec("RESET ROLE");
console.log(
  `PASS: ${n} SQL command/denial checks plus snapshot, audit, seasonal and rollback assertions (isolated PGlite PostgreSQL; no Production connection).`,
);
await db.close();
