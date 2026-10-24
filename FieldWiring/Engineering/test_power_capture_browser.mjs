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
    let filename = url.pathname.replace("/fieldwiring/", "");
    if (filename === "circuits") filename = "circuits.html";
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
  await dialog.waitFor({ state: "hidden" });
  await page.getByText(/Revision \d+/).waitFor();
}
try {
  await page.goto(base);
  await page
    .getByText("Production Crew editing available", { exact: false })
    .waitFor();
  await page.getByRole("button", { name: "Add panel", exact: true }).click();
  await dialog.locator("[name=panel_name]").fill("A5 panel");
  // Empty optional note must not block ordinary field registration.
  assert.equal(await dialog.locator("[name=source_evidence]").getAttribute("required"), null);
  assert.equal(await dialog.locator("[name=verification_status]").count(), 0);
  await save();
  await page
    .locator("#panels")
    .getByRole("button", { name: "A5 panel", exact: true })
    .click();
  await page.getByRole("button", { name: "Add circuit", exact: true }).click();
  await dialog.locator("[name=circuit_code]").fill("7");
  assert.equal(await dialog.locator("[name=verification_status]").count(), 0);
  await dialog.locator("[name=breaker_rating_amps]").selectOption("20");
  await save();
  await page.getByRole("button", { name: "Assign multiple waypoints" }).click();
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
  for (const network of ["1", "2"]) {
    await page
      .getByRole("button", { name: "Assign network", exact: true })
      .click();
    await dialog.locator("[name=site_waypoint_id]").selectOption("11");
    await dialog.locator("[name=site_network_id]").selectOption(network);
    await evidence();
    await save();
  }
  assert.equal(
    (await db.query("SELECT count(*)::int AS n FROM ref.site_waypoint_network"))
      .rows[0].n,
    2,
  );
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
  user = "volunteer@example.test";
  await page.reload();
  await page.getByText("Read only", { exact: false }).waitFor();
  assert.equal(
    await page
      .getByRole("button", { name: "Add panel", exact: true })
      .isDisabled(),
    true,
  );
  assert.deepEqual(errors, []);
  console.log(
    "PASS: actual browser panel/circuit creation, alias search, multi-select, retirement, safe retry, mobile width and read-only user.",
  );
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
  await db.close();
}
