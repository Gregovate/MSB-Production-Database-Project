# Panel circuit definition and field capture

| Document control | Value |
|---|---|
| Status | Implementation candidate; not deployed or operator accepted |
| Owner | #171 / #230, commanding #122; FieldWiring |
| Reviewed | 2026-10-23 |

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

## October 23 operator panel-board correction

Review remains failed. Screenshots show generic forms rather than a panel board.
The existing panel owns meter information; show it beside a top-center main
breaker area. Add explicit breaker role UNKNOWN / MAIN / BRANCH and ordered
physical panel positions (one position per pole). These are independent of
circuit designation and pole ordinal. Positions are operator-entered, never
parsed from waypoint/circuit names. One active main per panel; main has no branch
positions. Reject duplicate occupied positions in one panel, malformed positions,
and positions inconsistent with pole count. Unpositioned records remain visible.

The branch schedule displays odd positions on the left, even on the right, with
an explicit conventional-layout / verify-installed-numbering caption. Connected
positions of one multipole breaker share its permanent identity and rating;
show its circuits and endpoints beneath that breaker. Main impact includes all
recorded circuits in that panel; it remains incomplete recorded coverage, not
proof of isolation. Do not seed main ratings, positions, circuits or meter IDs.
Add-circuit from a breaker carries that breaker and panel, with pole selection
limited to its known poles. Unknown breaker membership remains possible and
visible separately. Keep existing command/audit/Directus and migration authority.

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

## Breaker grouping and shared-neutral design — October 23

**IMPLEMENTATION CANDIDATE; combined current-clone/operator acceptance pending.**
The combined candidate replaces circuit-owned breaker ratings/free-text grouping
with `site_power_breaker` and circuit breaker/pole foreign-key membership.
Correction history is retained by the existing before/after command log rather
than a second live membership store. Cable specification, conductor and
conductor/circuit associations reference the existing physical site_cable IDs.
An unknown pole count may be recorded but cannot accept pole assignments until
resolved. The grouped projection is explicitly recorded coverage, never proof
of isolation. Existing SQL/HTTP/browser boundaries own these extensions.
Earlier acceptance of PR #454 does not validate this combined candidate.

Greg requires one combined GIS/circuit database release. Retain the existing
#319 foundation and #454 identities, commands, audit and UI; extend them within
the ordered migration set, with one exact-candidate disposable acceptance and
one approved Production maintenance window. No separate electrical map store.

### Records and ownership

| Record | Required meaning and relationships |
|---|---|
| Panel | Existing permanent panel ID; geographic location is optional. |
| Breaker | New permanent breaker ID, parent panel ID, observed designation, rated amperes, pole count, evidence and verification. Unknown ratings/pole counts remain null. |
| Breaker pole | Explicit pole position within its breaker; panel slot designation is independent text, not an inferred ID. |
| Circuit membership | A retained, evidence-backed association between an existing circuit ID and a breaker pole. Each active circuit has at most one supplying pole in this model. Multiple circuits on a pole or alternative supplies require explicit engineering reconciliation, not silent acceptance. |
| Receptacle | Reuse the existing power-device identity, with an OUTLET device per independently supplied receptacle and a readable position within the waypoint's box. A quad box may therefore contain two devices at one waypoint. Do not assume each socket is independently supplied. |
| Feed | Existing circuit/device feed edges remain the source of recorded connectivity. A waypoint-only feed is allowed when the particular receptacle is unknown; it must not imply all receptacles are supplied. |
| Cable and conductors | Extend the existing physical site-cable identity with recorded cable specification and conductor identities/roles. Circuit-to-conductor membership records hot and neutral usage; a neutral shared by two circuits is one conductor with two memberships. Keep unknown conductor details null. GIS track geometry is optional evidence, never proof of connectivity. |

Breaker ratings have one authoritative value on the breaker. Pole/circuit
projections display that rating without adding poles together. Retire the
uninstalled draft's competing circuit-owned breaker rating/pole fields when
implementing the extension; preserve any encountered candidate evidence through
an explicit migration mapping, never guess groups from equal ratings or names.
A circuit-specific rating field, if retained, must have a separately defined
meaning and cannot silently compete with the protective-device rating.

Breaker membership, feed edges and conductor membership retain evidence,
verification, before/after audit and retirement history. Shared-neutral membership
is scoped to physical cable/conductor segments: it is not a boolean applying to
every downstream cable of both circuits. Changing a breaker or cable does not
replace the permanent circuit or waypoint IDs.

For Greg's reported example, `A5-18/20` stays one waypoint label. Capture two
circuit IDs, two receptacle devices, one two-pole 20 A breaker, and the reported
12-3 shared-neutral cable configuration only from supplied evidence. Do not
parse the label into verified panel slots, infer voltage/phase/conductor colors,
or present this as a single 40 A circuit. Each circuit can independently continue
to additional waypoint/device destinations.

### Shutoff impact and operator behavior

Add a read-only breaker-impact projection to the existing governed reference API.
Starting with every active circuit membership on that breaker, traverse recorded
active feed edges through intermediate devices to all reachable destinations.
Return breaker ID, rating/poles, circuit IDs, receptacle/device IDs, waypoint IDs
and current names, supporting edge IDs, and verification/conflict state per path.
Deduplicate waypoint display while retaining all supplying circuits and paths.
Do not collapse two circuits at the same waypoint into one electrical connection.

Display verified affected locations separately from recorded unverified or
conflicting paths. Missing pole assignments, unknown downstream connectivity,
alternative recorded supplies or cycles make the result explicitly incomplete;
an empty result must not be described as proof that nothing is affected.
The UI says "recorded affected endpoints", not "all endpoints verified".
Known alternate feeds must remain visible: this projection reports the effect of
removing the selected supply and does not claim a destination is de-energized.

Breaker OFF/ON is one grouped operation affecting every attached pole. Extend
existing power actions to target exactly one breaker, circuit or device. A
circuit-specific operation must identify the actual switching device; it cannot
record independent switching of one pole of a grouped breaker. Contradictory
desired states on its legs produce a conflict requiring review, not last-write-wins.

Before recording a breaker action, show the grouped impact for the current
reference revision. A changed topology/revision invalidates the preview and
requires review again. Store the breaker/circuit/path snapshot, uncertainties,
actor and season with the existing append-only activity event. Later wiring
corrections must not rewrite an earlier action's recorded impact.
No application entry switches hardware or verifies absence of voltage.

### Integrity and acceptance gates

- Reject cross-panel breaker/circuit membership, duplicate active pole assignment,
  out-of-range pole positions, nonpositive known ratings, stale edits and feed
  cycles. Unknown data remains explicitly incomplete rather than fabricated.
- Keep unverified/conflicting source observations even when promotion into an
  active relationship fails. Report exact conflicting IDs and corrective action.
- Confirm one single-pole breaker and one two-pole breaker retain correct ratings.
- Confirm two circuits feed separate receptacles at the same waypoint, each also
  feeds additional destinations, and the breaker preview includes both legs and
  all recorded downstream paths without losing duplicate-waypoint provenance.
- Confirm shared-neutral segment membership survives asymmetric downstream
  branching, corrections and retirement; no name or track auto-creates membership.
- Confirm unknown receptacles, missing pole members and alternative supplies are
  visible as incomplete/conflicting, not accepted as verified shutoff coverage.
- Confirm grouped action snapshots, contradictory desired states, stale-preview
  rejection, Directus permissions and audit attribution through SQL/API/browser.
- Confirm GPX rename/replay changes display names without altering circuit,
  breaker, receptacle or cable identity. Include this in the existing exact
  combined current-Production-clone acceptance before operator approval.

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
