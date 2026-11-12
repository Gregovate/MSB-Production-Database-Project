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
await denied(()=>cmd("network", { ...base, site_waypoint_id: 11, site_network_id: 1 }),"42501");
await denied(()=>cmd("network", { ...base, site_waypoint_id: 11, site_network_id: 2 },null,"manager@example.test"),"42501");
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
assert.equal(snapshot.networks.length, 4);
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

// Every waypoint type shares the same one-breaker rule, including indirect feeds.
await db.exec("INSERT INTO ref.site_waypoint VALUES (31,'Power cardinality','Power'),(32,'Pole cardinality','Pole-Combo'),(33,'Network cardinality','Network')");
for (const waypoint of [31,32,33]) {
 const first=await cmd("feed",{...base,source_circuit_id:legA.target_id,destination_waypoint_id:waypoint});
 const second=await cmd("feed",{...base,source_circuit_id:legB.target_id,destination_waypoint_id:waypoint});
 await denied(()=>cmd("feed",{...base,source_circuit_id:competingLeg.target_id,destination_waypoint_id:waypoint}),"23514");
 await cmd("feed",{active:false},first.target_id);
 await cmd("feed",{active:false},second.target_id);
 await cmd("feed",{...base,source_circuit_id:competingLeg.target_id,destination_waypoint_id:waypoint});
 assert.equal(Number((await db.query("SELECT count(*) n FROM ref.site_power_feed WHERE destination_waypoint_id=$1 AND NOT active",[waypoint])).rows[0].n),2);
}

// Continuations preserve each circuit identity: both poles may extend to the
// same downstream waypoint, but a different breaker's circuit cannot enter it.
await db.exec("INSERT INTO ref.site_waypoint VALUES (34,'Two-pole continuation','Power'),(35,'Single-pole origin','Power'),(36,'Single-pole continuation','Power')");
await cmd("feed",{...base,source_device_id:socketA.target_id,destination_waypoint_id:34});
await cmd("feed",{...base,source_device_id:socketB.target_id,destination_waypoint_id:34});
const singleOutlet=await cmd("device",{...base,device_name:"Single-pole continuation outlet",device_kind:"OUTLET",site_waypoint_id:35});
await cmd("feed",{...base,source_circuit_id:competingLeg.target_id,destination_device_id:singleOutlet.target_id});
await cmd("feed",{...base,source_device_id:singleOutlet.target_id,destination_waypoint_id:36});
await denied(()=>cmd("feed",{...base,source_device_id:singleOutlet.target_id,destination_waypoint_id:34}),"23514");
await denied(()=>cmd("feed",{...base,source_device_id:socketA.target_id,destination_waypoint_id:36}),"23514");
await denied(()=>cmd("feed",{...base,source_circuit_id:legB.target_id,destination_waypoint_id:35}),"23514");
const continued=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') x")).rows[0].x.waypoint_power_sources;
assert.deepEqual([...new Set(continued.filter(x=>x.site_waypoint_id===34).map(x=>x.site_power_circuit_id))].sort(),[legA.target_id,legB.target_id].sort());
assert.deepEqual([...new Set(continued.filter(x=>x.site_waypoint_id===36).map(x=>x.site_power_circuit_id))],[competingLeg.target_id]);
n+=2;

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
await denied(()=>cmd("controller_installation",{...base,controller_id:103,site_waypoint_id:13}),"23514");
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
// Final integrated design: unavailable or stale source facts fail closed at SQL.
const availability=async()=> (await db.query("SELECT * FROM ref.site_controller_placement_eligibility WHERE controller_id=103 AND site_waypoint_id=11")).rows;
assert.equal((await availability()).length,1);
for(const [change,restore] of [
 ["UPDATE ref.controller SET lor_network='AUX-A' WHERE controller_id=103","UPDATE ref.controller SET lor_network='REG' WHERE controller_id=103"],
 ["UPDATE lor_snap.v_current_props SET network='AUX-A' WHERE raw_prop_id='prop-103'","UPDATE lor_snap.v_current_props SET network='REG' WHERE raw_prop_id='prop-103'"],
 ["UPDATE lor_snap.v_current_props SET uid='invalid' WHERE raw_prop_id='prop-103'","UPDATE lor_snap.v_current_props SET uid='01' WHERE raw_prop_id='prop-103'"]
]) {
 await db.exec(change);
 assert.equal((await availability()).length,0);
 await denied(()=>cmd("controller_installation",{controller_id:103,site_waypoint_id:11}),"23514");
 await db.exec(restore);
 assert.equal((await availability()).length,1);
}
// An explicitly reviewed network cable may follow a shared power-trench trace.
await db.exec("UPDATE ref.site_route_source_track SET source_class='HV'");
assert.equal((await availability()).length,1);
await db.exec("UPDATE ref.site_route_source_track SET source_class='NET'");
// FLW endpoint membership remains available without reviewed GPX geometry.
await db.exec("INSERT INTO ops.linkiq_test VALUES(gen_random_uuid(),1,'2026-10-24',1,'REVIEWED','fixture','Cat6',123,'Fixture test'); UPDATE ref.site_route_segment SET review_status='REVIEW_REQUIRED' WHERE site_route_segment_id=1");
assert.equal((await availability()).length,1);
await db.exec("UPDATE ref.site_route_segment SET review_status='REVIEWED' WHERE site_route_segment_id=1");
const installed=await cmd("controller_installation",{controller_id:103,site_waypoint_id:11});
// Panel plans and evidence remain independent of branch plans and never imply OFF.
await cmd("panel",{show_desired_state:"ON",restoration_desired_state:"OFF"},p.target_id);
const pa=await cmd("action",{site_panel_id:p.target_id,action_name:"Panel utility shutdown",phase:"RESTORATION",action_kind:"REQUEST_UTILITY",desired_state:"OFF"});
await cmd("event",{site_power_action_id:pa.target_id,season_year:2026,event_kind:"UTILITY_REQUESTED",condition:"UNKNOWN",observed_at:"2026-10-24T12:00:00Z",evidence:"Requested utility isolation; not confirmed"});
await denied(()=>cmd("panel",{active:false},p.target_id),"23514");
const panelState=(await db.query("SELECT * FROM ref.site_panel WHERE site_panel_id=$1",[p.target_id])).rows[0];
assert.equal(panelState.restoration_desired_state,"OFF");
assert.equal((await db.query("SELECT condition FROM ops.setup_power_activity_event WHERE site_power_action_id=$1",[pa.target_id])).rows[0].condition,"UNKNOWN");
// Two actual Controllers on the same branch sum their distinct physical Displays.
const load=async()=> (await db.query("SELECT * FROM ref.site_circuit_load WHERE site_power_circuit_id=$1",[downstreamCircuit])).rows[0];
assert.equal(Number((await load()).recorded_display_amps),4);
assert.equal((await load()).completeness,"INCOMPLETE");
// Shared wiring lineage is not duplicate physical load. Each measured Display counts once.
await db.exec("INSERT INTO ref.display VALUES(201,'Physical copy','copy',1,3); INSERT INTO ref.controller_display VALUES(103,201,101)");
assert.equal(Number((await load()).recorded_display_amps),7);
// A Display associated with two Controllers is ambiguous even on one circuit.
await db.exec("INSERT INTO ref.controller_display VALUES(101,201,101)");
assert.equal(Number((await load()).recorded_display_amps),4);
assert.equal(Number((await load()).unresolved_displays),1);
await db.exec("UPDATE ref.display SET amps_measured=NULL WHERE display_id=101; UPDATE ref.display SET amps_measured=0 WHERE display_id=103");
assert.equal((await load()).recorded_display_amps,null);
const missing=(await db.query("SELECT load_status FROM ref.site_circuit_load_lineage WHERE display_id IN (101,103)")).rows.map(x=>x.load_status);
assert.ok(missing.includes("MISSING_AMPS") && missing.includes("ZERO_UNVERIFIED"));
// Ratings never add poles together, and missing basis remains incomplete at either voltage.
await db.exec("UPDATE ref.display SET amps_measured=2 WHERE display_id IN (101,103)");
const rating=(await load()).rated_amps;
assert.equal(Number((await load()).nominal_headroom_amps),Number(rating)-4);
await cmd("circuit",{voltage:240},downstreamCircuit);
assert.equal((await load()).completeness,"INCOMPLETE");
assert.ok((await load()).warnings.includes("AMP_BASIS_AND_VOLTAGE_UNVERIFIED"));
const finalSnapshot=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') x")).rows[0].x;
assert.ok(finalSnapshot.waypoint_power_sources.some(x=>x.site_waypoint_id===14 && x.site_power_circuit_id===downstreamCircuit));
assert.ok(finalSnapshot.linkiq_evidence.some(x=>x.endpoint_a===11 && x.endpoint_b===12));
assert.ok(finalSnapshot.load_lineage.some(x=>x.load_status==='NO_POWER_CONNECTION'));
for(const view of ["site_network_availability","site_controller_placement_eligibility","site_circuit_load"]) {
 assert.equal((await db.query("SELECT has_table_privilege('fieldwiring_app',$1,'INSERT,UPDATE,DELETE') allowed",["ref."+view])).rows[0].allowed,false);
}
n+=20;
// Network-only endpoints use the same reviewed-route/LOR gate, never power.
await cmd("controller_installation",{active:false},installed.target_id);
await db.exec("UPDATE ref.site_waypoint SET waypoint_type='Network' WHERE site_waypoint_id=11");
await cmd("controller_installation",{controller_id:103,site_waypoint_id:11});
assert.equal(finalSnapshot.linkiq_evidence[0].test_standard,"Cat6");
assert.equal(Number(finalSnapshot.linkiq_evidence[0].length_ft),123);
n+=2;
// A remote distribution panel can name its known upstream panel without
// fabricating the not-yet-inventoried feeder breaker.
const source15=await cmd("panel",{panel_name:"Panel 15"});
const remoteFE=await cmd("panel",{panel_name:"Panel FE-00",supply_panel_id:source15.target_id});
await denied(()=>cmd("panel",{supply_panel_id:remoteFE.target_id},source15.target_id),"23514");
await denied(()=>cmd("panel",{supply_panel_id:remoteFE.target_id},remoteFE.target_id),"23514");
await denied(()=>cmd("panel",{active:false},source15.target_id),"23514");
const feeder15=await cmd("breaker",{site_panel_id:source15.target_id,breaker_name:"FE feeder",breaker_role:"BRANCH",pole_count:2});
await denied(()=>cmd("panel",{supply_breaker_id:competing.target_id},remoteFE.target_id),"23514");
await cmd("panel",{supply_breaker_id:feeder15.target_id},remoteFE.target_id);
await cmd("panel",{supply_breaker_id:null},remoteFE.target_id);
const remoteState=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') x")).rows[0].x.panels.find(p=>p.site_panel_id===remoteFE.target_id);
assert.equal(remoteState.supply_panel_id,source15.target_id);
assert.equal(remoteState.supply_breaker_id,null);
n+=2;
// GPX classification cannot veto an FLW-resolved network endpoint.
const liveInstallation=(await db.query("SELECT site_controller_installation_id id FROM ref.site_controller_installation WHERE controller_id=103 AND active")).rows[0].id;
await cmd("controller_installation",{active:false},liveInstallation);
for(const [label,type] of [["RA-00","Panel"],["SW","Building"],["PO",""],["Other junction","Unclassified"]]) {
 await db.query("UPDATE ref.site_waypoint SET canonical_label=$1,waypoint_type=$2 WHERE site_waypoint_id=11",[label,type]);
 const endpointSnapshot=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') x")).rows[0].x;
 assert.equal(endpointSnapshot.waypoints.find(w=>w.id===11).network_capable,true);
 const entry=await cmd("controller_installation",{controller_id:103,site_waypoint_id:11});
 await cmd("controller_installation",{active:false},entry.target_id);
}
await db.exec("UPDATE ref.site_waypoint SET canonical_label='Outlet A',waypoint_type='Network' WHERE site_waypoint_id=11");
n+=4;
// FLW authority: unordered endpoints, multiple networks, old dates, latest failure.
const immutableBefore=(await db.query("SELECT jsonb_agg(to_jsonb(t) ORDER BY test_uuid) evidence FROM ops.linkiq_test t")).rows[0].evidence;
await db.exec(`INSERT INTO ref.site_network VALUES(3,'AUX-E','LOR');
INSERT INTO ops.linkiq_test VALUES
 ('00000000-0000-0000-0000-000000000021',NULL,'2023-10-01T10:00:00',1,'UNMATCHED','flw','1000BASE-T',306,'A TO B AUX-E'),
 ('00000000-0000-0000-0000-000000000022',NULL,'2024-10-01T10:00:00',2,'UNMATCHED','flw','1000BASE-T',309,'B TO A AUX E'),
 ('00000000-0000-0000-0000-000000000023',NULL,'1970-02-10T10:00:00',1,'UNMATCHED','flw','1000BASE-T',307,'A TO B AUX-E');
INSERT INTO ops.linkiq_intake_review(source_sha256,test_uuid,proposal) VALUES
 ('flw','00000000-0000-0000-0000-000000000021','{"endpoint_candidates":[[11],[12]],"designation":"AUX-E","reasons":[]}'),
 ('flw','00000000-0000-0000-0000-000000000022','{"endpoint_candidates":[[12],[11]],"designation":"Aux E","reasons":[]}'),
 ('flw','00000000-0000-0000-0000-000000000023','{"endpoint_candidates":[[11],[12]],"designation":"AUX-E","reasons":[]}');
UPDATE ref.site_route_segment SET review_status='REVIEW_REQUIRED';`);
const cableTests=(await db.query("SELECT * FROM ref.site_flw_cable_test WHERE network_key='AUX-E'")).rows;
assert.equal(new Set(cableTests.map(x=>x.cable_key)).size,1);
assert.equal(cableTests.filter(x=>x.latest_reliably_dated).length,1);
assert.equal(cableTests.find(x=>x.latest_reliably_dated).test_status_code,2);
assert.ok(cableTests.every(x=>x.has_unknown_test_order));
assert.equal(cableTests.find(x=>x.test_time_local.startsWith('1970')).reliable_test_time,null);
assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_network_availability WHERE site_waypoint_id=11")).rows[0].n,2);
await db.exec("DELETE FROM ref.controller_display WHERE controller_id=103 AND display_id=201; UPDATE ref.controller SET lor_network='Aux E' WHERE controller_id=103; UPDATE lor_snap.v_current_props SET network='AUX-E' WHERE raw_prop_id='prop-103'");
assert.equal((await availability()).length,1);
await db.exec(`INSERT INTO ops.linkiq_intake_review(source_sha256,test_uuid,proposal) VALUES
 ('conflicting','00000000-0000-0000-0000-000000000022','{"endpoint_candidates":[[11],[99]],"designation":"AUX-E","reasons":[]}');`);
assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_flw_cable_test WHERE test_uuid='00000000-0000-0000-0000-000000000022'")).rows[0].n,0);
assert.deepEqual((await db.query("SELECT jsonb_agg(to_jsonb(t) ORDER BY test_uuid) evidence FROM ops.linkiq_test t WHERE first_seen_source_sha256<>'flw'")).rows[0].evidence,immutableBefore);
n+=9;

// Independent four-controller graph: no assumptions from earlier power fixtures.
const chainDb=await createFixtureDatabase();
let chainRevision=0;
const chainCommand=async(fields,id=null,rev=chainRevision,uuid=crypto.randomUUID(),email="crew@example.test")=>{
 const r=(await chainDb.query("SELECT ref.site_power_command($1,$2::uuid,$3,'controller_installation',$4,$5::jsonb) result",[email,uuid,rev,id,JSON.stringify(fields)])).rows[0].result;
 chainRevision=r.revision;n++;return r;
};
const chainIds=[];
for(const id of [101,102,103,104]) {
 chainIds.push((await chainCommand({controller_id:id,site_waypoint_id:11,upstream_kind:id===101?"WAYPOINT":"CONTROLLER",upstream_controller_id:id===101?null:id-1})).target_id);
}
await chainCommand({chain_end:"TERMINATOR"},chainIds[3]);
assert.deepEqual((await chainDb.query("SELECT controller_id,upstream_controller_id FROM ref.site_controller_installation WHERE active ORDER BY controller_id")).rows.map(r=>[r.controller_id,r.upstream_controller_id]),[[101,null],[102,101],[103,102],[104,103]]);
await chainCommand({chain_end:"RETURN_TO_ORIGIN"},chainIds[3]);
await denied(()=>chainCommand({chain_end:"TERMINATOR"},chainIds[0]),"23514");
await denied(()=>chainCommand({active:false},chainIds[1]),"23514");
await denied(()=>chainCommand({upstream_controller_id:102},chainIds[1]),"23514");
await denied(()=>chainCommand({upstream_kind:"CONTROLLER",upstream_controller_id:104},chainIds[0]),"23514");
await chainCommand({chain_end:"UNKNOWN"},chainIds[3]);
await denied(()=>chainCommand({upstream_kind:"CONTROLLER",upstream_controller_id:104},chainIds[0]),"23514");
await denied(()=>chainCommand({upstream_controller_id:101},chainIds[2]),"23514");
// Known OUT edges remain meaningful while an IN is unrecorded.
await chainCommand({upstream_kind:"UNKNOWN"},chainIds[0]);
await chainCommand({upstream_kind:"WAYPOINT"},chainIds[0]);
await denied(()=>chainCommand({chain_end:"TERMINATOR"},chainIds[3],chainRevision-1),"40001");
await denied(()=>chainCommand({chain_end:"TERMINATOR"},chainIds[3],chainRevision,crypto.randomUUID(),"volunteer@example.test"),"42501");
// Failed batch rolls back the valid first edit, its audit and revision too.
const beforeChain=(await chainDb.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s;
await chainDb.exec("BEGIN");
await chainCommand({chain_end:"TERMINATOR"},chainIds[3]);
await denied(()=>chainCommand({active:false},chainIds[0]),"23514");
await chainDb.exec("ROLLBACK");chainRevision=beforeChain.revision;
assert.deepEqual((await chainDb.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s,beforeChain);
// Reordering explicitly reconnects children; origin/network mismatch cannot slip in.
await chainCommand({upstream_kind:"WAYPOINT",upstream_controller_id:null},chainIds[3]);
await chainCommand({active:false},chainIds[2]);
await denied(()=>chainCommand({controller_id:103,site_waypoint_id:12,upstream_kind:"CONTROLLER",upstream_controller_id:102}),"23514");
await chainDb.exec("UPDATE ref.controller SET lor_network='AUX-A' WHERE controller_id=103; UPDATE lor_snap.v_current_props SET network='AUX-A' WHERE raw_prop_id='prop-103'");
await denied(()=>chainCommand({controller_id:103,site_waypoint_id:11,upstream_kind:"CONTROLLER",upstream_controller_id:102}),"23514");
await chainDb.exec("UPDATE ref.controller SET lor_network='REG' WHERE controller_id=103; UPDATE lor_snap.v_current_props SET network='REG' WHERE raw_prop_id='prop-103'");
const replacement=await chainCommand({controller_id:103,site_waypoint_id:11,upstream_kind:"CONTROLLER",upstream_controller_id:104});
const replayRequest=crypto.randomUUID(),replayRevision=chainRevision;
await chainCommand({chain_end:"RETURN_TO_ORIGIN"},replacement.target_id,replayRevision,replayRequest);
assert.equal((await chainCommand({chain_end:"RETURN_TO_ORIGIN"},replacement.target_id,replayRevision,replayRequest)).replayed,true);
assert.ok((await chainDb.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s.history.some(h=>h.before_data?.upstream_controller_id===103&&h.after_data?.upstream_kind==="WAYPOINT"));
await chainDb.close();

// Reciprocal physical ports, using Greg's two concrete examples as synthetic data.
const portsDb=await createFixtureDatabase();
await portsDb.exec(`
 UPDATE ref.site_waypoint SET canonical_label=CASE site_waypoint_id WHEN 11 THEN 'RA-00' WHEN 12 THEN 'ST-01' ELSE canonical_label END;
 UPDATE ref.site_network SET network_code=CASE site_network_id WHEN 1 THEN 'AUX-E' ELSE 'AUX-J' END;
 UPDATE ops.linkiq_intake_review SET proposal=jsonb_set(proposal,'{designation}','"AUX-E"');
 UPDATE ops.linkiq_intake_review SET proposal=jsonb_set(proposal,'{designation}','"AUX-J"') WHERE proposal->'endpoint_candidates'='[[12],[99]]'::jsonb;
 INSERT INTO ref.controller(controller_id,controller_model_id,serial_number,lor_network,lor_uid_start,lor_uid_end)
 SELECT id,1,'ports-'||id,CASE WHEN id<1005 THEN 'AUX-E' ELSE 'AUX-J' END,1,1 FROM unnest(ARRAY[1001,1002,1003,1004,1005,1006,1036]) id;
 INSERT INTO ref.display SELECT controller_id,'Display '||controller_id,'prop-'||controller_id,1,2 FROM ref.controller WHERE controller_id>=1000;
 INSERT INTO ref.controller_display SELECT controller_id,controller_id,NULL FROM ref.controller WHERE controller_id>=1000;
 INSERT INTO lor_snap.v_current_props SELECT d.lor_prop_id,d.lor_prop_id,1,c.lor_network,'01','LOR' FROM ref.display d JOIN ref.controller c ON c.controller_id=d.display_id WHERE c.controller_id>=1000;
`);
let portsRev=0;
const ports=async(id,origin,input,output,rev=portsRev,uuid=crypto.randomUUID(),email='crew@example.test')=>{
 const f={site_waypoint_id:origin,in_kind:typeof input==='number'?'CONTROLLER':input,in_controller_id:typeof input==='number'?input:null,out_kind:typeof output==='number'?'CONTROLLER':output,out_controller_id:typeof output==='number'?output:null};
 const r=(await portsDb.query("SELECT ref.site_power_command($1,$2::uuid,$3,'controller_ports',$4,$5::jsonb) r",[email,uuid,rev,id,JSON.stringify(f)])).rows[0].r;portsRev=r.revision;n++;return r;
};
const portRow=async id=>(await portsDb.query("SELECT * FROM ref.site_controller_installation WHERE active AND controller_id=$1",[id])).rows[0];
await ports(1001,11,'WAYPOINT',1002);
assert.equal((await portRow(1002)).upstream_controller_id,1001);
await ports(1002,11,1001,1003);
await ports(1003,11,1002,1004);
await ports(1004,11,1003,'TERMINATOR');
assert.equal((await portRow(1004)).chain_end,'TERMINATOR');
await ports(1004,11,1003,'RETURN_TO_ORIGIN');
assert.equal((await portRow(1004)).verification_status,'UNVERIFIED');
await ports(1005,12,'WAYPOINT',1006);
await ports(1006,12,1005,1036);
await ports(1036,12,1006,'RETURN_TO_ORIGIN');
assert.equal((await portRow(1036)).site_waypoint_id,12);
assert.equal((await portRow(1036)).upstream_controller_id,1006);
await denied(()=>ports(1001,11,'WAYPOINT',1001),'23514');
await denied(()=>ports(1004,11,1003,1001),'23514');
await denied(()=>ports(1001,11,'WAYPOINT',1003),'23514'); // occupied IN
await denied(()=>ports(1004,11,1001,'TERMINATOR'),'23514'); // occupied OUT
await denied(()=>ports(1001,11,'WAYPOINT',1005),'23514'); // wrong network
await denied(()=>ports(1004,12,1003,'TERMINATOR'),'23514'); // wrong origin
await denied(()=>ports(1004,11,1003,'TERMINATOR',portsRev-1),'40001');
await denied(()=>ports(1004,11,1003,'TERMINATOR',portsRev,crypto.randomUUID(),'volunteer@example.test'),'42501');
const portsReplayId=crypto.randomUUID(),portsOldRev=portsRev;
await ports(1004,11,1003,'TERMINATOR',portsOldRev,portsReplayId);
assert.equal((await ports(1004,11,1003,'TERMINATOR',portsOldRev,portsReplayId)).replayed,true);
// Replace OUT: release the previous IN without inventing a direct waypoint feed.
await ports(1002,11,1001,'UNKNOWN');
assert.equal((await portRow(1003)).upstream_kind,'UNKNOWN');
assert.equal((await portRow(1004)).upstream_controller_id,1003);
await ports(1001,11,'WAYPOINT',1003);
assert.equal((await portRow(1002)).upstream_kind,'UNKNOWN');
assert.equal((await portRow(1003)).upstream_controller_id,1001);
// Editing IN is the very same edge, reflected immediately in the predecessor OUT.
await ports(1003,11,1002,1004);
assert.equal((await portsDb.query('SELECT count(*)::int n FROM ref.site_controller_installation WHERE active AND upstream_controller_id=1001')).rows[0].n,0);
assert.equal((await portRow(1003)).upstream_controller_id,1002);
const beforePorts=(await portsDb.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s;
await denied(()=>ports(1002,11,1004,1003),'23514'); // cycle / terminated predecessor, no partial detach
assert.deepEqual((await portsDb.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s,beforePorts);
assert.ok(beforePorts.history.some(h=>h.command==='controller_ports'&&Array.isArray(h.before_data)&&h.after_data.some(i=>i.controller_id===1003)));
await ports(1003,null,'UNKNOWN','UNKNOWN');
assert.equal(await portRow(1003),undefined);
assert.equal((await portRow(1004)).upstream_kind,'UNKNOWN');
assert.equal((await portRow(1004)).chain_end,'TERMINATOR');
await portsDb.close();
console.log(
  `PASS: ${n} SQL command/denial checks plus snapshot, audit, seasonal and rollback assertions (isolated PGlite PostgreSQL; no Production connection).`,
);

// Configured slot count uses the same audited panel command and protects both
// directions: shrinking a panel and placing/moving a breaker beyond its extent.
const slotsPanel=await cmd('panel',{...base,panel_name:'Configured slots',branch_position_count:20});
for(const count of [12,18,20,24,30,40,42]) await cmd('panel',{...base,branch_position_count:count},slotsPanel.target_id);
await cmd('panel',{...base,branch_position_count:20},slotsPanel.target_id);
for(const count of [0,201,-1]) await denied(()=>cmd('panel',{...base,branch_position_count:count},slotsPanel.target_id),'23514');
const lastBreaker=await cmd('breaker',{...base,site_panel_id:slotsPanel.target_id,breaker_name:'18/20',breaker_role:'BRANCH',panel_positions:[18,20],pole_count:2,rated_amps:20});
const protectedState=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s;
await denied(()=>cmd('panel',{...base,branch_position_count:18},slotsPanel.target_id),'23514');
await denied(()=>cmd('breaker',{...base,panel_positions:[20,22]},lastBreaker.target_id),'23514');
assert.deepEqual((await db.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s,protectedState);
await cmd('panel',{...base,branch_position_count:40},slotsPanel.target_id);
await cmd('breaker',{...base,panel_positions:[38,40]},lastBreaker.target_id);
await denied(()=>cmd('panel',{...base,branch_position_count:38},slotsPanel.target_id),'23514');
await denied(()=>cmd('panel',{...base,branch_position_count:42},slotsPanel.target_id,'volunteer@example.test'),'42501');
await cmd('panel',{...base,branch_position_count:null},slotsPanel.target_id);
assert.equal((await db.query('SELECT branch_position_count FROM ref.site_panel WHERE site_panel_id=$1',[slotsPanel.target_id])).rows[0].branch_position_count,null);
console.log('PASS: configured slot count, range, occupied shrink/overflow denial, atomic preservation and role boundary');
await db.close();
