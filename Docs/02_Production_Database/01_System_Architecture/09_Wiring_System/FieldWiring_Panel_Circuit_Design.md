# Panel circuit definition and field capture

| Document control | Value |
|---|---|
| Status | Implementation candidate; not deployed or operator accepted |
| Owner | #171 / #230, commanding #122; FieldWiring |
| Reviewed | 2026-10-22 |

## Evidence and integration contract

The operator supplied a complete read-only catalog inventory from `msb`, captured
2026-10-22T23:45:38.139501-05:00: PostgreSQL 16.9, PostGIS 3.5.2. Of the queried
site/power relations only `ref.site_network` and `ref.season` exist. No installed
waypoint, alias, panel, circuit or site-reference command was returned. Existing
Directus-backed capability functions and `ref.setup_inventory_actor(text,boolean)`
are installed; the latter resolves active Production Crew/Manager/Administrator
and invokes `ref.reconcile_directus_person_identity` for attributed writes.

The #319 foundation owns `ref.site_waypoint` and retained `site_waypoint_alias`.
The circuit migration requires those exact objects, and never imports GPX or
creates replacement waypoints. Existing network IDs/rows remain unchanged.
The old #319 operations SQL contains uninstalled proposed power tables and a
separate editor-grant store. This candidate supersedes its POWER definitions;
that old operations migration must be split/reconciled before combined release.
It must not be applied alongside this migration. No independent role grant store
is introduced. This integration remains a release gate, not an assertion that
#319 has been accepted.

## Maintained records

Permanent panel ID is independent of optional geographic waypoint, readable panel
label, owner and meter notes. Unknown values are null. Circuit designations are
unique within a permanent panel (case/whitespace normalized); names do not become
foreign keys. Panel, circuit and intermediate equipment changes retain explicit
source, verification state, verifier/time and correction history.

Documented feed edges run from exactly one circuit or intermediate device to
exactly one waypoint or intermediate device. Multiple feed edges are allowed;
unknown/conflicting evidence is explicit. Cycles are rejected. Effective circuit
waypoint relationships are derived only by traversing these recorded edges.
Networks remain independent many-to-many waypoint relationships. Multi-select
circuit assignment edits direct edges; intermediate paths remain visible and are
corrected in the feed editor. Retire relationships rather than deleting history.

## Commands and authorization

Use the existing protected FieldWiring Flask host and authenticated Cloudflare
email. Non-simple JSON command headers protect browser writes. The database
rechecks active Directus authorization for EVERY command using the existing actor
resolver; the browser never supplies actor or verification identity. Ordinary
Volunteer read rights do not confer Production Crew write rights. No direct table
DML is granted to fieldwiring_app. Functions use qualified names, fixed search
paths, and revoked PUBLIC execution.

A single circuit-reference revision serializes small field edits and rejects
stale-tab saves. Before/after JSON, operator email, Directus UUID, person ID,
server timestamp, source and command remain append-only. Unrecognized fields and
invalid partial combinations fail closed. Source/evidence is required; ratings,
meter information and seasonal states may remain unknown. A new verification
claim requires explicit evidence; modifying verified facts requires deliberate
reverification or downgrade. Saves never change waypoint identity or coordinates.

## Seasonal separation

Circuit rows hold show-season and restoration DESIRED states independently.
Reusable action definitions identify circuit/equipment, phase, action, desired
state, responsible party, instructions and prerequisite actions. Annual activity
observations belong in ops under Setup ownership, keyed by ref.season. Events
retain the action definition snapshot and actor/time, so later corrections do not
rewrite prior years. Reported state, field verification, switching completion,
utility request and utility confirmation are distinct event types. A command
never derives one from another. A completed task or stored state is never physical
proof of de-energization. No electrical switching is performed by this application.

## Acceptance

Test SQL constraints and real PL/pgSQL commands, least privilege, inactive and
Volunteer denial, actor attribution, stale revisions, multiple destinations and
networks, aliases, feed cycles, correction history, unknown values, seasonal
separation and retained snapshots. Test Flask transport guards/errors and browser
workflow. Local isolated database tests do not replace current-Production-clone
and protected crew/Manager operator acceptance. Use the established Server
Management disposable/browser/release mechanism; no new server runner.

## Related documents

- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [Source checkpoint](FieldWiring_Panel_Circuit_Capture_Checkpoint.md)
- [Wiring System](README.md)

## Test infrastructure reuse

Extend the existing `setup205-regression.yml` FieldWiring job with isolated
PGlite relational/PLpgSQL and Playwright checks. PGlite supplies a local PostgreSQL
engine with synthetic Directus/waypoint fixtures; it does not test PostGIS source
synchronization or replace the existing current-Production disposable acceptance.
The actual installed actor-function source and Setup capability source are loaded
in the fixture; only the People identity-reconciliation dependency is stubbed.
No new deployment runner, browser port allocation on the MSB host, service or
Production privilege is introduced.
