// Actual page against isolated PostgreSQL fixtures; never a Production/browser-auth test.
import { createFixtureDatabase } from "./power_test_database.mjs";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";
const require = createRequire(import.meta.url);
const { chromium } = process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES
  ? require(
      path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES, "playwright"),
    )
  : require("playwright");
const app = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../Application",
);
const db = await createFixtureDatabase();
let user = "crew@example.test",
  failNext = false;
const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname === "/fieldwiring/api/power") {
      const result = await db.query(
        "SELECT ref.site_power_snapshot($1) AS data",
        [user],
      );
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify(result.rows[0].data));
      return;
    }
    if (url.pathname === "/fieldwiring/api/power/commands") {
      let raw = "";
      for await (const chunk of req) raw += chunk;
      const body = JSON.parse(raw);
      await db.exec("BEGIN");
      try {
        let revision = body.revision;
        const results = [];
        for (const c of body.commands) {
          const r = await db.query(
            "SELECT ref.site_power_command($1,$2::uuid,$3,$4,$5,$6::jsonb) AS result",
            [
              user,
              c.request_id,
              revision,
              c.kind,
              c.id,
              JSON.stringify(c.fields),
            ],
          );
          results.push(r.rows[0].result);
          revision = r.rows[0].result.revision;
        }
        await db.exec("COMMIT");
        if (failNext) {
          failNext = false;
          res.statusCode = 503;
          res.setHeader("Content-Type", "application/json");
          res.end(
            JSON.stringify({
              error: "Simulated lost confirmation after commit",
            }),
          );
          return;
        }
        res.setHeader("Content-Type", "application/json");
        res.end(JSON.stringify({ revision, results }));
        return;
      } catch (e) {
        await db.exec("ROLLBACK");
        throw e;
      }
    }
    // Inventory metadata is synthetic; deployment reads/writes above use real SQL.
    if(url.pathname.startsWith("/fieldwiring/api/")) {
      const id=Number(url.pathname.match(/controllers\/(\d+)/)?.[1]||101);
      res.setHeader("Content-Type","application/json");
      res.end(JSON.stringify({controller:{controller_id:id,manufacturer:"Fixture",model_code:"Fixture",model_name:"Fixture",controller_status_name:"AVAILABLE",lor_network:"REG"},controllers:[],assignments:[],firmware_history:[],access:{can_manage:false},can_manage:false}));return;
    }
    let filename = url.pathname.replace("/fieldwiring/", "");
    if (["circuits","waypoints","equipment","cable-tests"].includes(filename)) filename = "circuits.html";
    if (filename === "controllers") filename = "controllers.html";
    const full = path.resolve(app, filename);
    if (!full.startsWith(app + path.sep)) throw new Error("Invalid path");
    res.setHeader(
      "Content-Type",
      filename.endsWith(".js")
        ? "application/javascript"
        : filename.endsWith(".css")
          ? "text/css"
          : "text/html",
    );
    res.end(await readFile(full));
  } catch (e) {
    res.statusCode = e.code === "40001" ? 409 : e.code === "42501" ? 403 : 400;
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ error: e.message }));
  }
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const browser = await chromium.launch({
  headless: true,
  args: ["--no-sandbox"],
  ...(process.env.POWER_TEST_CHROMIUM
    ? { executablePath: process.env.POWER_TEST_CHROMIUM }
    : {}),
});
const page = await browser.newPage({ viewport: { width: 1100, height: 850 } });
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
const base = `http://127.0.0.1:${server.address().port}/fieldwiring/circuits`;
const dialog = page.locator("#editor");
async function evidence() {
  await dialog
    .locator("[name=source_evidence]")
    .fill("Browser fixture label observation");
}
async function save() {
  await dialog.locator("#save").click();
  try { await dialog.waitFor({ state: "hidden", timeout: 10000 }); }
  catch (e) { throw new Error((await dialog.innerText()) + "\n" + e.message); }
  await page.getByText(/Revision \d+/).waitFor();
}
try {
  await page.goto(base);
  await page
    .getByText("Production Crew editing available", { exact: false })
    .waitFor();
  await page.getByRole("button", { name: "Add panel", exact: true }).click();
  await dialog.locator("[name=panel_name]").fill("A5 panel");
  await dialog.locator("[name=owner_name]").selectOption("City Owned");
  await dialog.locator("[name=year_installed]").fill("2018");
  await dialog.locator("[name=show_desired_state]").selectOption("ON");
  await dialog.locator("[name=restoration_desired_state]").selectOption("OFF");
  assert.equal(await dialog.locator("[name=active]").count(), 0);
  assert.equal(await dialog.locator("[name=source_evidence]").getAttribute("required"), null);
  assert.equal(await dialog.locator("[name=verification_status]").count(), 0);
  await save();
  await page
    .locator("#panels")
    .getByRole("button", { name: "A5 panel", exact: true })
    .click();
  const panelYear=await db.query("SELECT owner_name,year_installed FROM ref.site_panel WHERE panel_name='A5 panel'");
  assert.equal(panelYear.rows[0].owner_name,"City Owned");
  assert.equal(panelYear.rows[0].year_installed,2018);
  assert.match(await page.locator("#panel-detail").innerText(),/Panel plan — show: ON; off-season: OFF/);
  await page.getByText("Reconcile circuits with unknown breaker membership",{exact:true}).click();
  await page.getByRole("button", { name: "Reconcile legacy circuit", exact: true }).click();
  await dialog.locator("[name=circuit_code]").fill("legacy7");
  assert.equal(await dialog.locator("[name=verification_status]").count(), 0);
  await save();
  await page.getByText("Reconcile circuits with unknown breaker membership",{exact:true}).click();
  await page.getByRole("button", { name: "Assign multiple waypoints" }).click();
  // A panel or unrelated reference waypoint is not an electrical endpoint.
  assert.equal(await dialog.locator('input[name=waypoint][value="10"]').count(),0);
  await dialog.locator("[name=waypoint_search]").fill("Old Outlet A");
  assert.equal(await dialog.locator(".power-choices label:visible").count(), 1);
  await dialog.locator('input[name=waypoint][value="11"]').check();
  await dialog.locator("[name=waypoint_search]").fill("");
  await dialog.locator('input[name=waypoint][value="12"]').check();
  assert.equal(await dialog.locator("[name=verification_status]").count(), 0);
  await save();
  assert.equal(
    (
      await db.query(
        "SELECT count(*)::int AS n FROM ref.site_power_feed WHERE active",
      )
    ).rows[0].n,
    2,
  );
  await page.getByText("Reconcile circuits with unknown breaker membership",{exact:true}).click();
  await page.getByRole("button", { name: "Assign multiple waypoints" }).click();
  await dialog.locator('input[name=waypoint][value="12"]').uncheck();
  await evidence();
  await save();
  assert.equal(
    (
      await db.query(
        "SELECT count(*)::int AS n FROM ref.site_power_feed WHERE active",
      )
    ).rows[0].n,
    1,
  );
  assert.equal(
    (
      await db.query(
        "SELECT count(*)::int AS n FROM ref.site_power_feed WHERE NOT active",
      )
    ).rows[0].n,
    1,
  );
  await page.getByRole("button", { name: "Add panel", exact: true }).click();
  await dialog.locator("[name=panel_name]").fill("Retry panel");
  await evidence();
  failNext = true;
  await dialog.locator("#save").click();
  await dialog.getByText(/Retry Save resends/).waitFor();
  await save();
  assert.equal(
    (
      await db.query(
        "SELECT count(*)::int AS n FROM ref.site_panel WHERE panel_name='Retry panel'",
      )
    ).rows[0].n,
    1,
  );
  await page.goto(base.replace("circuits","waypoints"));
  await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#detail-waypoint").selectOption("11");
  assert.equal(await page.getByRole("button",{name:"Assign network",exact:true}).count(),0);
  assert.match(await page.locator("#networks").innerText(),/REG.*FLW endpoint record/);
  assert.match(await page.locator("#waypoint-safety").innerText(),/do not prove absence of voltage/);
  await page.goto(base);
  await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#seasonal-activities > summary").click();
  await page
    .getByRole("button", { name: "Define activity", exact: true })
    .click();
  await dialog.locator("[name=action_name]").fill("Utility switch request");
  await dialog.locator("[name=site_power_circuit_id]").selectOption("1");
  await dialog.locator("[name=action_kind]").selectOption("REQUEST_UTILITY");
  await evidence();
  await save();
  await page
    .getByRole("button", {
      name: "Record seasonal activity / condition",
      exact: true,
    })
    .click();
  await dialog.locator("[name=event_kind]").selectOption("UTILITY_REQUESTED");
  await dialog.locator("[name=observed_at]").fill("2026-10-01T12:00");
  await dialog.locator("[name=evidence]").fill("Fixture request submitted");
  await save();
  assert.equal(
    (
      await db.query(
        "SELECT count(*)::int AS n FROM ops.setup_power_activity_event WHERE event_kind='UTILITY_CONFIRMED'",
      )
    ).rows[0].n,
    0,
  );
  // The grouped schema must also be operable through the actual page.
  await page.locator("#panels").getByRole("button", {name:"A5 panel",exact:true}).click();
  await page.getByRole("button", {name:"Add branch breaker",exact:true}).click();
  await dialog.locator("[name=breaker_name]").fill("18/20 grouped");
  await dialog.locator("[name=rated_amps]").selectOption("20");
  await dialog.locator("[name=pole_count]").selectOption("2");
  await dialog.locator("[name=panel_positions]").fill("18,20");
  await dialog.locator("[name=panel_positions]").blur();
  assert.equal(await dialog.locator("[name=source_evidence]").getAttribute("required"), null);
  await dialog.locator("[name=panel_positions]").fill("1/3 or 1,3?");
  await dialog.locator("#save").click();
  await dialog.getByText(/Enter panel positions such as/).waitFor();
  assert.equal(await dialog.locator("[name=breaker_name]").inputValue(), "18/20 grouped");
  await dialog.locator("[name=panel_positions]").fill("18/20");
  await dialog.locator("[name=panel_positions]").blur();

  await dialog.locator("[name=show_desired_state]").selectOption("ON");
  assert.equal(await dialog.locator("[name=rated_amps]").locator("option[value=\"20\"]").count(), 1);
  await save();
  const breakerId=(await db.query("SELECT site_power_breaker_id FROM ref.site_power_breaker WHERE breaker_name='18/20 grouped'")).rows[0].site_power_breaker_id;
  const breakerNotes=await db.query("SELECT source_evidence,verification_status FROM ref.site_power_breaker WHERE site_power_breaker_id=$1",[breakerId]);
  assert.equal(breakerNotes.rows[0].source_evidence,null);
  assert.equal(breakerNotes.rows[0].verification_status,"UNVERIFIED");
  const groupedRow=page.locator("#panel-detail .power-record").filter({has:page.getByRole("heading",{name:"Breaker 18/20 grouped",exact:true})});
  for (const leg of ["18","20"]) {
    await groupedRow.getByRole("button",{name:new RegExp(`^Circuit ${leg} —`)}).click();
    await dialog.locator('input[name=waypoint][value="12"]').check();
    assert.equal(await dialog.locator("[name=also_other_leg]").count(),1);
    if (leg==="18") await dialog.locator("[name=also_other_leg]").check();
    await evidence(); await save();
  }
  await groupedRow.getByText("Connections · unverified",{exact:true}).click();
  assert.match(await groupedRow.innerText(),/20 A · 2 poles/);
  assert.match(await groupedRow.innerText(),/A5 panel \/ 18/);
  assert.match(await groupedRow.innerText(),/A5 panel \/ 20/);
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_power_circuit WHERE site_power_breaker_id=$1",[breakerId])).rows[0].n,2);
  await groupedRow.getByRole("button",{name:/^Open Outlet B \/ equipment/}).first().click();
  // Navigation completes before the async shared snapshot populates the picker.
  await page.getByText(/Revision \d+/).waitFor();
  assert.equal(await page.locator("#waypoint-detail").getAttribute("open"),"");
  assert.equal(await page.locator("#detail-waypoint").inputValue(),"12");
  assert.equal((await db.query("SELECT count(DISTINCT f.source_circuit_id)::int n FROM ref.site_power_feed f JOIN ref.site_power_circuit c ON c.site_power_circuit_id=f.source_circuit_id WHERE c.site_power_breaker_id=$1 AND f.destination_waypoint_id=12 AND f.active",[breakerId])).rows[0].n,2);
  await page.goto(base);
  await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#panels").getByRole("button",{name:"A5 panel",exact:true}).click();
  assert.equal(await page.locator(".power-slot").count(),35);
  assert.equal(await groupedRow.locator("..").evaluate(e=>e.style.gridRow),"9 / span 2");
  assert.equal(await groupedRow.locator("..").evaluate(e=>e.style.gridColumn),"2");
  const savedIds=(await db.query("SELECT site_power_circuit_id FROM ref.site_power_circuit WHERE site_power_breaker_id=$1 ORDER BY breaker_pole",[breakerId])).rows;
  await groupedRow.getByRole("button",{name:"Breaker settings",exact:true}).click();
  await dialog.locator("[name=show_desired_state]").selectOption("OFF");
  failNext=true;
  await dialog.locator("#save").click();
  await dialog.getByText(/Retry Save resends/).waitFor();
  await save();
  assert.deepEqual((await db.query("SELECT site_power_circuit_id FROM ref.site_power_circuit WHERE site_power_breaker_id=$1 ORDER BY breaker_pole",[breakerId])).rows,savedIds);
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_power_circuit WHERE site_power_breaker_id=$1 AND show_desired_state='OFF'",[breakerId])).rows[0].n,2);
  await page.getByRole("button",{name:"Meter / upstream supply",exact:true}).click();
  await dialog.locator("[name=meter_information]").fill("TEST-METER-100");
  await evidence();await save();
  assert.match(await page.locator(".power-main").innerText(),/TEST-METER-100/);
  await page.locator("#panels").getByRole("button",{name:"Retry panel",exact:true}).click();
  await page.getByRole("button",{name:"Meter / upstream supply",exact:true}).click();
  await dialog.locator("[name=supply_breaker_id]").selectOption(String(breakerId));
  await evidence();await save();
  assert.match(await page.locator(".power-main").innerText(),/Remote main \/ supply: A5 panel — 18\/20 grouped/);
  assert.equal(await page.getByRole("button",{name:"Record main breaker",exact:true}).count(),0);
  await page.locator("#panels").getByRole("button",{name:"A5 panel",exact:true}).click();
  await page.getByRole("button",{name:"Record main breaker",exact:true}).click();
  assert.equal(await dialog.locator("[name=panel_positions]").isVisible(), false);
  await dialog.locator("[name=breaker_name]").fill("Main disconnect");
  await dialog.locator("[name=rated_amps]").selectOption("200");
  await dialog.locator("[name=pole_count]").selectOption("2");
  await evidence(); await save();
  assert.match(await page.locator(".power-main").innerText(),/200 A · 2 poles · MAIN/);
  await page.getByRole("button",{name:"Set number of slots",exact:true}).click();
  await dialog.locator('[name=branch_position_count]').fill("40"); await evidence(); await save();
  // Fill remaining A5 positions through the same diagram entry used by the operator.
  for (const start of [1,2,5,6,9,10,13,14,17,21,22,25,26,29,30,33,34]) {
    await page.getByRole("button",{name:`Position ${start} · Add breaker`,exact:true}).click();
    await dialog.locator("[name=pole_count]").selectOption("2");
    await dialog.locator("[name=pole_count]").blur();
    assert.equal(await dialog.locator("[name=panel_positions]").inputValue(),`${start}/${start+2}`);
    await dialog.locator("[name=rated_amps]").selectOption("20");
    await save();
  }
  assert.equal(await page.locator(".power-slot-grid .power-breaker").count(),18);
  const positions=await page.locator(".power-slot-grid .power-slot").filter({has:page.locator(".power-breaker")}).evaluateAll(nodes=>nodes.map(n=>[n.style.gridColumn,n.style.gridRow]));
  assert.equal(positions.filter(x=>x[0]==="1").length,9);
  assert.equal(positions.filter(x=>x[0]==="2").length,9);
  assert.ok(positions.every(x=>x[1].endsWith("span 2")));
  // The main disconnect does not consume branch positions. Fill the final four
  // positions using the UI, then reload to prove stable IDs and persistence.
  for (const start of [37,38]) {
    await page.getByRole("button",{name:`Position ${start} · Add breaker`,exact:true}).click();
    await dialog.locator("[name=pole_count]").selectOption("2");
    await dialog.locator("[name=pole_count]").blur();
    assert.equal(await dialog.locator("[name=panel_positions]").inputValue(),`${start}/${start+2}`);
    await dialog.locator("[name=rated_amps]").selectOption("20"); await save();
  }
  await page.reload(); await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#panels").getByRole("button",{name:"A5 panel",exact:true}).click();
  assert.equal(await page.locator(".power-slot-grid .power-breaker").count(),20);
  const endSlots=await db.query("SELECT panel_positions FROM ref.site_power_breaker WHERE panel_positions && ARRAY[39,40] ORDER BY panel_positions[1]");
  assert.deepEqual(endSlots.rows.map(r=>r.panel_positions),[[37,39],[38,40]]);
  // Owner labels and selected outline survive both themes; colors are not status.
  await db.exec("UPDATE ref.site_panel SET owner_name=CASE WHEN panel_name='A5 panel' THEN 'MSB Owned' ELSE 'City Owned' END");
  await page.reload(); await page.getByText(/Revision \d+/).waitFor();
  for (const theme of ["light","dark"]) {
    if(await page.locator("html").getAttribute("data-theme")!==theme) await page.locator("#theme-toggle").click();
    const msb=page.locator('#panels button[data-owner="msb"]');
    const city=page.locator('#panels button[data-owner="city"]').first();
    assert.match(await msb.innerText(),/MSB Owned/);assert.match(await city.innerText(),/City Owned/);
    assert.notEqual(await msb.evaluate(n=>getComputedStyle(n).backgroundColor),await city.evaluate(n=>getComputedStyle(n).backgroundColor));
  }
  // A small configured panel gets only its real slots, not a global minimum.
  const hardwareBefore=(await db.query("SELECT (SELECT count(*) FROM ref.site_power_breaker)::int breakers,(SELECT count(*) FROM ref.site_power_circuit)::int circuits")).rows[0];
  await page.getByRole("button",{name:"Add panel",exact:true}).click();
  await dialog.locator('[name=panel_name]').fill("Small panel");
  await dialog.locator('[name=branch_position_count]').fill("18"); await save();
  assert.equal(await page.locator('.power-slot-grid .power-slot').count(),18);
  assert.equal(await page.getByRole("button",{name:"Position 19 · Add breaker",exact:true}).count(),0);
  assert.deepEqual((await db.query("SELECT (SELECT count(*) FROM ref.site_power_breaker)::int breakers,(SELECT count(*) FROM ref.site_power_circuit)::int circuits")).rows[0],hardwareBefore);
  // Power-only outlet has circuit and plug-in controls, no network enclosure form.
  await page.goto(base.replace("circuits","waypoints"));
  await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#detail-waypoint").selectOption("13");
  assert.equal(await page.locator("#combo-network-box").isVisible(),false);
  assert.equal(await page.locator("#connect-controller").isVisible(),true);
  const firstCircuit=(await db.query("SELECT site_power_circuit_id FROM ref.site_power_circuit WHERE circuit_code='1'")).rows[0].site_power_circuit_id;
  await page.locator("#waypoint-supply select").selectOption(String(firstCircuit));
  await dialog.locator('input[name=waypoint][value="13"]').check();
  await evidence(); await save();
  await page.goto(base.replace("circuits","waypoints?waypoint=13"));
  await page.getByText(/Revision \d+/).waitFor();
  await page.getByRole("button",{name:"Connect controller to outlet",exact:true}).click();
  await dialog.locator("[name=controller_id]").selectOption("101");
  await dialog.locator("[name=site_power_circuit_id]").selectOption(String(firstCircuit));
  await evidence();await save();
  assert.match(await page.locator("#plugged-controllers").innerText(),/Controller 101/);
  await page.goto(base);
  await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#panels").getByRole("button",{name:"A5 panel",exact:true}).click();
  assert.match(await page.locator("#panel-detail").innerText(),/Display load: 2 A · incomplete/);
  await page.goto(base.replace("circuits","waypoints"));
  await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#detail-waypoint").selectOption("12");
  for(const id of ["101","102"]) {
    await page.getByRole("button",{name:"Install existing controller",exact:true}).click();
    await dialog.locator("#port-controller").selectOption(id);
    await dialog.locator("#deployment-network").waitFor();
    await dialog.locator("#deployment-save").click();
    await dialog.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
    await dialog.getByRole("button",{name:"Done",exact:true}).click();
    await dialog.waitFor({state:"hidden"});await page.getByText(/Revision \d+/).waitFor();
  }
  assert.equal(await page.locator("#installations .power-record").count(),2);
  // GPX geometry updates do not erase FLW-backed network membership.
  await db.exec("UPDATE ref.site_track SET changed_at='2027-01-01'");
  await page.locator("#reload").click();
  await page.getByText(/Revision \d+/).waitFor();
  await page.getByRole("button",{name:"Install existing controller",exact:true}).click();
  await dialog.locator("#port-controller").selectOption("103");
  await dialog.locator("#deployment-network").waitFor();
  assert.equal(await dialog.locator("#deployment-network option").count(),4);
  await dialog.getByRole("button",{name:"Done",exact:true}).click();
  await dialog.waitFor({state:"hidden"});
  await db.exec("UPDATE ref.site_track SET changed_at='2026-01-01'");
  await page.locator("#reload").click();
  await page.getByText(/Revision \d+/).waitFor();
  // Network equipment is recorded at its Combo waypoint, not forced into
  // the LOR Controller model inventory.
  await page.goto(base.replace("circuits","equipment?waypoint=12"));
  await page.getByText(/Revision \d+/).waitFor();
  await page.getByRole("button",{name:"Add new equipment",exact:true}).click();
  await dialog.locator("[name=device_name]").selectOption("TRENDnet TI-PGLC50 · 5-port PoE+");
  assert.equal(await dialog.locator("[name=device_kind]").inputValue(),"POE_SWITCH");
  assert.equal(await dialog.locator("[name=device_kind]").isVisible(),false);
  assert.equal(await dialog.locator("[name=site_waypoint_id]").inputValue(),"12");
  await save();
  assert.match(await page.locator("#equipment").innerText(),/TRENDnet TI-PGLC50 · 5-port PoE\+ · POE_SWITCH/);
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_power_device WHERE device_kind='POE_SWITCH' AND site_waypoint_id=12")).rows[0].n,1);
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.controller")).rows[0].n,4);
  // Empty selectors must distinguish unresolved LOR from missing FLW endpoints,
  // and a known outlet with no circuit must point back to the existing editor.
  const previousNetwork=(await db.query("SELECT lor_network FROM ref.controller WHERE controller_id=104")).rows[0].lor_network;
  await db.exec("UPDATE ref.controller SET lor_network=NULL WHERE controller_id=104");
  await page.goto(base.replace("circuits","controllers?controller_id=104"));
  await page.locator("#deployment-network-status").waitFor();
  assert.match(await page.locator("#deployment-network-status").innerText(),/LOR network requirement is unresolved/);
  await db.exec("INSERT INTO ref.site_waypoint VALUES(98,'Unassigned outlet','Power')");
  await page.getByRole("button",{name:"Reload connections",exact:true}).click();
  await page.locator('#deployment-outlet option[value="98"]').waitFor({state:"attached"});
  await page.locator("#deployment-outlet").selectOption("98");
  assert.match(await page.locator("#deployment-supply-status").innerText(),/No supplying circuit is recorded for Unassigned outlet/);
  assert.equal(await page.locator("#deployment-circuit option").count(),1);
  assert.equal(await page.locator("#deployment-supply-link").getAttribute("href"),"circuits");
  await db.query("UPDATE ref.controller SET lor_network=$1 WHERE controller_id=104",[previousNetwork]);
  // Restore test-only FLW evidence after proving the distinct confirmed-network gap.
  await db.exec("UPDATE ops.linkiq_intake_review SET proposal=jsonb_set(proposal,'{reasons}','[\"SOURCE_DELETED\"]')");
  page.once("dialog",d=>d.accept());
  await page.goto(base.replace("circuits","controllers?controller_id=101"));
  await page.locator("#deployment-network-status").waitFor();
  assert.match(await page.locator("#deployment-network-status").innerText(),/FLW endpoint records/);
  await db.exec("UPDATE ops.linkiq_intake_review SET proposal=jsonb_set(proposal,'{reasons}','[]'); DELETE FROM ref.site_waypoint WHERE site_waypoint_id=98");
  // Editing from Controller Inventory must update the same records visible at
  // the waypoint, retaining history and safely replaying an uncertain response.
  await page.goto(base.replace("circuits","controllers?controller_id=101"));
  await page.locator("#deployment-network").waitFor();
  assert.equal(await page.locator("#deployment-network").inputValue(),"12");
  assert.equal(await page.locator("#deployment-outlet").inputValue(),"13");
  await page.locator("#deployment-network").selectOption("11");
  await page.locator("#deployment-outlet").selectOption("12");
  const movedCircuit=(await db.query("SELECT site_power_circuit_id FROM ref.site_power_circuit WHERE circuit_code='18'")).rows[0].site_power_circuit_id;
  await page.locator("#deployment-circuit").selectOption(String(movedCircuit));
  // List presentation must retain stage scope, selection and unsaved port edits.
  await page.evaluate(() => {
    currentControllers = [
      {controller_id:1094, assignment_count:1, display_names:'WF-Tree-10'},
      {controller_id:1138, assignment_count:1, display_names:'WF-Tree-2'},
      {controller_id:1090, assignment_count:1, display_names:'wf-tree-2'},
      {controller_id:1000, assignment_count:0, display_names:null},
      {controller_id:101, assignment_count:1, display_names:'WF-Tree-1'}
    ];
    stageFilter.add(new Option('Who Forest', '77'));
    stageFilter.value = '77';
    renderControllerList(currentControllers);
  });
  const listIds = () => page.locator('#controller-list .controller-row').evaluateAll(rows => rows.map(r => Number(r.dataset.controllerId)));
  assert.deepEqual(await listIds(), [101,1000,1090,1094,1138]);
  const portState = async () => page.evaluate(() => Object.fromEntries(
    ['deployment-upstream','deployment-out'].map(id => {
      const select=document.getElementById(id);
      return [id,{value:select.value, options:Array.from(select.options).map(o=>({value:o.value,name:o.dataset.displayName||''}))}];
    })));
  const portsBeforeSort=await portState();
  const checkPortOrder = async mode => {
    const after=await portState();
    const names=new Intl.Collator(undefined,{numeric:true,sensitivity:'base'});
    for(const [id,before] of Object.entries(portsBeforeSort)) {
      const special=before.options.filter(o=>!/^\d+$/.test(o.value));
      const controllers=before.options.filter(o=>/^\d+$/.test(o.value)).sort((a,b)=>{
        if(mode==='display'){
          if(Boolean(a.name)!==Boolean(b.name))return a.name ? -1 : 1;
          const byName=names.compare(a.name,b.name);if(byName)return byName;
        }
        return Number(a.value)-Number(b.value);
      });
      assert.deepEqual(after[id].options,[...special,...controllers]);
      assert.equal(after[id].value,before.value);
    }
  };
  await page.locator('#controller-sort').selectOption('display');
  assert.deepEqual(await listIds(), [101,1090,1138,1094,1000]);
  await checkPortOrder('display');
  assert.equal(await page.locator('#stage-filter').inputValue(), '77');
  assert.equal(await page.locator('#controller-list .active').getAttribute('data-controller-id'), '101');
  assert.equal(await page.locator('#deployment-network').inputValue(), '11');
  assert.equal(await page.locator('#deployment-outlet').inputValue(), '12');
  assert.equal(await page.locator('#deployment-circuit').inputValue(), String(movedCircuit));
  await page.locator('#controller-sort').selectOption('id');
  await checkPortOrder('id');
  assert.deepEqual(await listIds(), [101,1000,1090,1094,1138]);
  await page.locator('#controller-sort').selectOption('display');
  // Refresh keeps the chosen order and active detail; the server owns filtering.
  await page.route('**/api/controllers?*', route => {
    assert.equal(new URL(route.request().url()).searchParams.get('stage_id'), '77');
    return route.fulfill({json:{controllers:[
      {controller_id:1094,assignment_count:1,display_names:'WF-Tree-10'},
      {controller_id:1138,assignment_count:1,display_names:'WF-Tree-2'}
    ]}});
  });
  await page.locator('#refresh-button').click();
  await page.waitForFunction(() => document.querySelector('#controller-count').textContent === '2 shown');
  assert.deepEqual(await listIds(), [1138,1094]);
  assert.equal(await page.locator('#controller-sort').inputValue(), 'display');
  assert.equal(await page.locator('#deployment-network').inputValue(), '11');
  await page.unroute('**/api/controllers?*');
  failNext=true;
  await page.locator("#deployment-save").click();
  await page.getByText(/Save outcome unknown/).waitFor();
  await page.locator("#deployment-save").click();
  await page.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_controller_installation WHERE controller_id=101 AND active")).rows[0].n,1);
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_controller_installation WHERE controller_id=101 AND NOT active")).rows[0].n,1);
  assert.equal((await db.query("SELECT site_waypoint_id FROM ref.site_controller_power_connection WHERE controller_id=101 AND active")).rows[0].site_waypoint_id,12);
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_controller_power_connection WHERE controller_id=101 AND NOT active")).rows[0].n,1);
  await page.goto(base.replace("circuits","waypoints?waypoint=11"));
  await page.getByText(/Revision \d+/).waitFor();
  assert.match(await page.locator("#installations").innerText(),/CTRL 101/);
  assert.equal(await page.locator('#detail-waypoint option[value="10"]').count(),0);
  // A panel-typed waypoint stays eligible when FLW endpoints resolve.
  await db.exec("UPDATE ref.site_waypoint SET waypoint_type='Panel' WHERE site_waypoint_id=11");
  await page.goto(base.replace("circuits","controllers?controller_id=102"));
  await page.locator("#deployment-network").waitFor();
  await page.locator("#deployment-network").selectOption("11");
  await page.locator("#deployment-save").click();
  await page.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  assert.equal((await db.query("SELECT site_waypoint_id FROM ref.site_controller_installation WHERE controller_id=102 AND active")).rows[0].site_waypoint_id,11);
  // Stale revision cannot silently overwrite another screen's update.
  await page.locator("#deployment-network").selectOption("12");
  await db.exec("UPDATE ref.site_power_revision SET revision=revision+1");
  await page.locator("#deployment-save").click();
  await page.getByText(/Records changed. Reload connections/).waitFor();
  assert.equal(await page.locator("#deployment-save").isDisabled(),true);
  page.once("dialog",d=>d.accept());
  await page.getByRole("button",{name:"Reload connections",exact:true}).click();
  await page.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  // Record physical order on Controller Inventory, then correct the same record
  // from Waypoint Connections. These saves do not require a power circuit.
  await page.locator("#deployment-upstream").selectOption("101");
  await page.locator("#deployment-out").selectOption("TERMINATOR");
  await page.locator("#deployment-save").click();
  await page.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  await page.reload();await page.locator("#deployment-upstream").waitFor();
  assert.equal(await page.locator("#deployment-upstream").inputValue(),"101");
  assert.equal(await page.locator("#deployment-out").inputValue(),"TERMINATOR");
  await page.goto(base.replace("circuits","waypoints?waypoint=11"));
  await page.getByText(/Revision \d+/).waitFor();
  const chainRecord=page.locator("#installations .power-record").filter({has:page.getByRole("heading",{name:"CTRL 102",exact:true})});
  await chainRecord.getByRole("button",{name:"Edit IN / OUT",exact:true}).click();
  await dialog.locator("#deployment-upstream").waitFor();
  assert.equal(await dialog.locator("#deployment-upstream").inputValue(),"101");
  await dialog.locator("#deployment-out").selectOption("RETURN_TO_ORIGIN");
  await dialog.locator("#deployment-save").click();
  await dialog.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  await dialog.getByRole("button",{name:"Done",exact:true}).click();
  await dialog.waitFor({state:"hidden"});
  await page.goto(base.replace("circuits","controllers?controller_id=102"));
  await page.locator("#deployment-out").waitFor();
  assert.equal(await page.locator("#deployment-out").inputValue(),"RETURN_TO_ORIGIN");
  // Select an unassigned controller directly from OUT; reciprocal IN must be
  // created in the same save, without manually installing the next controller.
  await page.locator("#deployment-out").selectOption("103");
  await page.locator("#deployment-save").click();
  await page.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  await page.goto(base.replace("circuits","controllers?controller_id=103"));
  await page.locator("#deployment-upstream").waitFor();
  assert.equal(await page.locator("#deployment-upstream").inputValue(),"102");
  assert.equal(await page.locator("#deployment-network").inputValue(),"11");
  await page.locator("#deployment-out").selectOption("104");
  await page.locator("#deployment-save").click();
  await page.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  await page.goto(base.replace("circuits","controllers?controller_id=104"));
  await page.locator("#deployment-upstream").waitFor();
  assert.equal(await page.locator("#deployment-upstream").inputValue(),"103");
  await page.locator("#deployment-out").selectOption("RETURN_TO_ORIGIN");
  await page.locator("#deployment-save").click();
  await page.getByText("Current shared waypoint records loaded.",{exact:true}).waitFor();
  assert.match(await page.locator(".controller-port-summary").innerText(),/CTRL 103[\s\S]*CTRL 104[\s\S]*return/);
  assert.equal(await page.locator(".controller-port-summary td").first().evaluate(n=>getComputedStyle(n).borderTopStyle),"solid");
  assert.deepEqual((await db.query("SELECT controller_id,upstream_controller_id FROM ref.site_controller_installation WHERE active ORDER BY controller_id")).rows.map(r=>[r.controller_id,r.upstream_controller_id]),[[101,null],[102,101],[103,102],[104,103]]);
  // Asset IDs and physical display names are independent. A wiring-source
  // template must not replace the displayed physical copy's name.
  await db.exec("UPDATE ref.display SET display_name='WF-Tree-08' WHERE display_id=104; UPDATE ref.display SET display_name='Template Tree' WHERE display_id=101; UPDATE ref.controller_display SET wiring_source_display_id=101 WHERE controller_id=104");
  await page.reload();await page.locator("#deployment-chain").waitFor();
  assert.equal(await page.locator(".controller-port-summary td").nth(1).locator(".controller-port-display").innerText(),"WF-Tree-08");
  assert.match(await page.locator("#deployment-chain").innerText(),/CTRL 104 — WF-Tree-08/);
  await page.goto(base.replace("circuits","controllers?controller_id=103"));
  await page.locator("#deployment-out").waitFor();
  assert.equal(await page.locator('#deployment-out option[value="104"]').innerText(),"CTRL 104 — WF-Tree-08");
  await page.goto(base.replace("circuits","waypoints?waypoint=11"));
  await page.getByText(/Revision \d+/).waitFor();
  const namedRecord=page.locator("#installations .power-record").filter({has:page.getByRole("heading",{name:"CTRL 104",exact:true})});
  assert.equal(await namedRecord.locator("td").nth(1).locator(".controller-port-display").innerText(),"WF-Tree-08");
  assert.equal(await page.evaluate(()=>window.MSBControllerDeployment.controllerLabel({load_lineage:[]},999)),"CTRL 999 — No display assigned");
  assert.equal(await page.evaluate(()=>window.MSBControllerDeployment.controllerLabel({load_lineage:[{controller_id:999,display_name:'Tree B'},{controller_id:999,display_name:'Tree A'}]},999)),"CTRL 999 — Tree A / Tree B");
  // Separate read-only history retains retests and unresolved identities.
  await db.exec("INSERT INTO ops.linkiq_test VALUES(gen_random_uuid(),1,'2026-10-23',1,'REVIEWED','source-one','Cat6',100,'first'),(gen_random_uuid(),1,'2026-10-24',2,'REVIEWED','source-two','Cat6',101,'retest'),(gen_random_uuid(),NULL,NULL,NULL,'UNMATCHED','source-three',NULL,NULL,'unresolved')");
  await page.goto(base.replace("circuits","cable-tests"));
  await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#test-pair").selectOption("11:12");
  assert.equal(await page.locator("#test-history article").count(),3);
  assert.match(await page.locator("#test-history").innerText(),/source-one/);
  assert.match(await page.locator("#test-history").innerText(),/source-two/);
  await page.locator("#test-pair").selectOption("unresolved");
  assert.equal(await page.locator("#test-history article").count(),1);
  assert.equal(await page.locator("#cable-history button").count(),0);
  // Parsed FLW labels remain browsable before waypoint/cable reconciliation.
  await db.exec(`INSERT INTO ops.linkiq_test VALUES
    ('11111111-1111-4111-8111-111111111111',NULL,'2026-10-20',1,'UNMATCHED','flw-source','10BASE-T',210,'FE-02B TO FE-02 AUX-E'),
    ('22222222-2222-4222-8222-222222222222',NULL,'2026-10-20',1,'UNMATCHED','flw-source','10BASE-T',209,'FE-02B TO FE-02 SPARE-01');
    INSERT INTO ops.linkiq_intake_review(source_sha256,test_uuid,proposal)
    VALUES ('flw-source','11111111-1111-4111-8111-111111111111','{"endpoint_labels":["FE-02B","FE-02"],"endpoint_candidates":[[],[]],"designation":"AUX-E","display_label":"FE-02B TO FE-02 AUX-E"}'),
    ('flw-source','22222222-2222-4222-8222-222222222222','{"endpoint_labels":["FE-02B","FE-02"],"endpoint_candidates":[[],[]],"designation":"SPARE-01","display_label":"FE-02B TO FE-02 SPARE-01"}');`);
  await page.reload();await page.getByText(/Revision \d+/).waitFor();
  await page.locator("#test-pair").selectOption('label:["FE-02","FE-02B"]');
  assert.equal(await page.locator("#test-history article").count(),2);
  assert.equal(await page.locator("#test-history h3").count(),2);
  assert.match(await page.locator("#test-history").innerText(),/physical cable unreviewed/);
  // Save Panel 15 as FE-00's supply even when it has no recorded breakers.
  await page.goto(base);await page.getByText(/Revision \d+/).waitFor();
  for(const name of ["Panel 15","Panel FE-00"]) {
    await page.getByRole("button",{name:"Add panel",exact:true}).click();
    await dialog.locator("[name=panel_name]").fill(name);await save();
  }
  await page.locator("#panels").getByRole("button",{name:"Panel FE-00",exact:true}).click();
  await page.getByRole("button",{name:"Meter / upstream supply",exact:true}).click();
  const source15=(await db.query("SELECT site_panel_id FROM ref.site_panel WHERE panel_name='Panel 15'")).rows[0].site_panel_id;
  await dialog.locator("[name=supply_panel_id]").selectOption(String(source15));
  assert.equal(await dialog.locator("[name=supply_breaker_id] option").count(),1);
  await save();
  assert.match(await page.locator(".power-main").innerText(),/Panel 15.*feeder breaker unknown/);
  // Prefix suggestions prioritize A5 while keeping power-pole exceptions.
  await db.exec("UPDATE ref.site_panel SET panel_name='PANEL A5-00' WHERE panel_name='A5 panel'; UPDATE ref.site_waypoint SET canonical_label='A5-02' WHERE site_waypoint_id=12; UPDATE ref.site_waypoint SET canonical_label='Light Pole 13' WHERE site_waypoint_id=13");
  await page.goto(`${base}?circuit=${movedCircuit}`);
  await dialog.waitFor({state:"visible"});
  const choices=await dialog.locator("input[name=waypoint]").evaluateAll(nodes=>nodes.map(n=>n.value));
  assert.ok(choices.indexOf("12")<choices.indexOf("13"));
  assert.match(await dialog.innerText(),/circuit may have no discovered waypoint/);
  page.once("dialog",d=>d.accept());await dialog.locator("#cancel").click();
  await dialog.waitFor({state:"hidden"});
  await page.goto(base);
  await page.getByText(/Revision \d+/).waitFor();
  await page.screenshot({path:"/tmp/power-panel-desktop.png",fullPage:true});
  await page.getByRole("button", {name:/Light mode|Dark mode/}).click();
  const changedTheme = await page.locator("html").getAttribute("data-theme");
  await page.reload();
  await page.getByText(/Revision \d+/).waitFor();
  assert.equal(await page.locator("html").getAttribute("data-theme"), changedTheme);
  await page.getByRole("button", {name:/Light mode|Dark mode/}).click();
  assert.notEqual(await page.locator("html").getAttribute("data-theme"), changedTheme);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({
    path: process.env.POWER_TEST_SCREENSHOT || "/tmp/power-mobile.png",
    fullPage: true,
  });
  assert.equal(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
    true,
  );
  // Equipment expectations are read-only; FLW endpoints remain valid without
  // GPX network typing and no installed stock is created from network evidence.
  const devicesBefore=(await db.query("SELECT count(*)::int n FROM ref.site_power_device")).rows[0].n;
  await db.exec(`INSERT INTO ref.site_network VALUES(3,'INET','IP');
    INSERT INTO ops.linkiq_test VALUES('00000000-0000-0000-0000-000000000099',NULL,'2024-01-01',1,'UNMATCHED','expectation','1000BASE-T',306,'Outlet B TO Pole INET');
    INSERT INTO ops.linkiq_intake_review(source_sha256,test_uuid,proposal) VALUES('expectation','00000000-0000-0000-0000-000000000099','{"endpoint_candidates":[[12],[99]],"designation":"INET","reasons":[]}');`);
  await page.goto(base.replace("circuits","waypoints?waypoint=12"));
  await page.getByText(/Revision \d+/).waitFor();
  assert.match(await page.locator("#networks").innerText(),/branch requiring a LOR repeater/);
  assert.match(await page.locator("#networks").innerText(),/verify switch and power-supply inventory/);
  assert.match(await page.locator("#networks").innerText(),/verify PoE/);
  assert.equal((await db.query("SELECT count(*)::int n FROM ref.site_power_device")).rows[0].n,devicesBefore);
  await page.goto(base);
  await page.getByText(/Revision \d+/).waitFor();
  user = "volunteer@example.test";
  await page.reload();
  await page.getByText("Read only", { exact: false }).waitFor();
  assert.equal(
    await page
      .getByRole("button", { name: "Add panel", exact: true })
      .isDisabled(),
    true,
  );
  await page.goto(`${base}?circuit=1`);
  await page.getByText("Read only",{exact:false}).waitFor();
  assert.equal(await page.locator("#editor").isVisible(),false);
  await page.goto(base.replace("circuits","controllers?controller_id=101"));
  await page.locator("#deployment-network").waitFor();
  assert.equal(await page.locator("#deployment-save").isDisabled(),true);
  assert.equal(await page.locator("#deployment-network").isDisabled(),true);
  assert.deepEqual(errors, []);
  console.log(
    "PASS: focused panel/waypoint/equipment/history routes, shared Controller placement and power moves, retained history, exact batch retry, stale denial, network-only eligibility, retests, mobile width and read-only user.",
  );
} finally {
  await browser.close();
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
  await db.close();
}
