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
const p = await cmd("panel", { ...base, panel_name: "Panel A" });
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
await denied(
  () =>
    cmd("panel", { ...base, panel_name: "no evidence", source_evidence: " " }),
  "22023",
);
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
  1,
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
console.log(
  `PASS: ${n} SQL command/denial checks plus snapshot, audit, seasonal and rollback assertions (isolated PGlite PostgreSQL; no Production connection).`,
);
await db.close();
