import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import scanExtension from '../src/index.js';

async function renderRoute(path) {
  const routes = new Map();
  const router = {
    get(routePath, handler) {
      routes.set(routePath, handler);
    },
  };

  let databaseCalled = false;
  const response = {
    body: null,
    headers: new Map(),
    setHeader(name, value) {
      this.headers.set(String(name).toLowerCase(), value);
    },
    send(body) {
      this.body = body;
    },
  };

  scanExtension.handler(router, {
    database() {
      databaseCalled = true;
      throw new Error('field-test route must not query the database');
    },
  });

  const handler = routes.get(path);
  assert.ok(handler, 'expected route ' + path + ' to be registered');
  await handler({}, response);

  return { response, databaseCalled };
}

test('field acceptance route is read-only and contains no database dependency', async () => {
  const { response, databaseCalled } = await renderRoute('/field-test');

  assert.equal(databaseCalled, false);
  assert.match(response.body, /READ-ONLY ENGINEERING TEST/);
  assert.match(response.body, /does not change Setup movement state or write test observations to PostgreSQL/i);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('field acceptance route exercises real browser GPS and HID capture primitives', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /navigator\.geolocation\.watchPosition/);
  assert.match(response.body, /enableHighAccuracy:\s*true/);
  assert.match(response.body, /localStorage\.setItem/);
  assert.match(response.body, /navigator\.onLine/);
  assert.match(response.body, /window\.addEventListener\('offline'/);
  assert.match(response.body, /window\.addEventListener\('online'/);
  assert.match(response.body, /document\.addEventListener\('keydown'/);
  assert.match(response.body, /Operator location comment/);
  assert.match(response.body, /operator_location_comment/);
  assert.match(response.body, /expectedReference\.addEventListener\('change', function\(\) \{\s+if \(latestPosition && latestPosition\._msbSource === 'CONTROLLED_PREVIEW'\) \{\s+loadControlledPreviewFix\(\);\s+\}\s+scheduleScanInputFocus\(\);\s+\}\);/);
  assert.match(response.body, /inputMethod\.addEventListener\('change', scheduleScanInputFocus\)/);
  assert.match(response.body, /operatorLocationComment\.addEventListener\('blur', scheduleScanInputFocus\)/);
  assert.match(response.body, /Verify normal Scan route/);
});

test('field acceptance route preserves current GPX reference provenance and named candidates', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /2026_msb\.gpx/);
  assert.match(response.body, /ExpertGPS 9\.34 using Garmin GPSMAP 66sr/);
  assert.match(response.body, /eff23e666e0c288b52741621c1450b5a95150b36394de38bfe50b307c311de74/);
  assert.match(response.body, /source_waypoint_count:\s*519/);
  assert.match(response.body, /selection_rule:\s*'type=Stage'/);
  assert.match(response.body, /reference_points:\s*referencePoints\.map/);
  assert.match(response.body, /03a-Mega Cube-MC/);
  assert.match(response.body, /23-Peanuts-PN/);
  assert.match(response.body, /24-Traditional Christmas-TC/);
  assert.match(response.body, /30-Santa's Station Entrance/);

  const referenceCount = (response.body.match(/"name":/g) || []).length;
  assert.equal(referenceCount, 31);
});

test('CSV export carries the complete field evidence needed for later comparison', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /'reference_source_sha256'/);
  assert.match(response.body, /'reference_selection_rule'/);
  assert.match(response.body, /'fix_timestamp'/);
  assert.match(response.body, /'gps_acquisition_elapsed_ms'/);
  assert.match(response.body, /'expected_reference_latitude'/);
  assert.match(response.body, /'expected_reference_longitude'/);
  assert.match(response.body, /'nearest_5'/);
  assert.match(response.body, /'nearest_5_distance_ft'/);
  assert.match(response.body, /'browser_online'/);
  assert.match(response.body, /'effective_type'/);
});


test('field acceptance route captures disposable raw field-reference observations', async () => {
  const { response, databaseCalled } = await renderRoute('/field-test');

  assert.equal(databaseCalled, false);
  assert.match(response.body, /Provisional field-reference observations/);
  assert.match(response.body, /field_reference_observations:\s*\[\]/);
  assert.match(response.body, /function captureFieldReferenceObservation\(\)/);
  assert.match(response.body, /provisional_name:/);
  assert.match(response.body, /area_context:/);
  assert.match(response.body, /environment_context:/);
  assert.match(response.body, /environment_note:/);
  assert.match(response.body, /operator_comment:/);
  assert.match(response.body, /gps_acquisition_elapsed_ms:/);
  assert.match(response.body, /Multiple observations with this name remain separate raw points/);
});

test('field references remain provenance-distinct and participate in ranking without averaging', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /source_type:\s*'GPX_SEED'/);
  assert.match(response.body, /source_type:\s*'FIELD_OBSERVATION'/);
  assert.match(response.body, /referenceCandidates\(\)/);
  assert.match(response.body, /session\.field_reference_observations\.map/);
  assert.match(response.body, /rankedReferences/);
  assert.match(response.body, /\[FIELD\]/);
  assert.match(response.body, /\[GPX\]/);
  assert.match(response.body, /no averaging\/promotion/i);
  assert.doesNotMatch(response.body, /averageFieldReference|averaged_coordinate|mean_latitude/i);
});

test('controlled preview fix is explicitly marked as non-physical evidence', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /Load controlled preview fix/);
  assert.match(response.body, /CONTROLLED_PREVIEW/);
  assert.match(response.body, /UI test data, not physical GPS evidence/);
  assert.match(response.body, /fix_source:/);
});

test('field-reference evidence survives JSON CSV export and clear-all flow', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /FIELD_REFERENCE_OBSERVATION/);
  assert.match(response.body, /'field_reference_observation_id'/);
  assert.match(response.body, /'field_reference_name'/);
  assert.match(response.body, /'field_reference_area_context'/);
  assert.match(response.body, /'field_reference_environment_context'/);
  assert.match(response.body, /'field_reference_environment_note'/);
  assert.match(response.body, /'gps_fix_source'/);
  assert.match(response.body, /'nearest_1_source'/);
  assert.match(response.body, /localStorage\.removeItem\(STORAGE_KEY\)/);
  assert.match(response.body, /renderFieldReferences\(\)/);
});

test('harness documentation assigns #219/#122 ownership and defers offline architecture', () => {
  const doc = fs.readFileSync(
    new URL('../../../Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Scan_GPS_Field_Acceptance_Harness_2026-09-18.md', import.meta.url),
    'utf8'
  );

  assert.match(doc, /Issue #219 — Scan \+ GPS acceptance harness; #122 governs Setup integration decisions/);
  assert.match(doc, /#219 \(owner\), #122 \(governing Setup\)/);
  assert.match(doc, /one hypothesis that this experiment may inform, not an accepted Production design/i);
  assert.doesNotMatch(doc, /The intended production model is therefore store-and-forward/);
  assert.doesNotMatch(doc, /compatibility origin.*404 Not Found/i);
  assert.match(doc, /field reference observations/i);
  assert.match(doc, /not authoritative GIS waypoints/i);
  assert.match(doc, /raw observations/i);
  assert.match(doc, /do not average/i);
  assert.match(doc, /browser localStorage/i);
});

test('scan source and deployed dist candidate remain byte-identical', () => {
  const src = fs.readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
  const dist = fs.readFileSync(new URL('../dist/index.js', import.meta.url), 'utf8');
  assert.equal(src, dist);
});
