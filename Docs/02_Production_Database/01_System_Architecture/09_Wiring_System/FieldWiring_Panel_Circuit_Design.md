# Panel circuit definition and field capture


## Network identity versus path versus consumer — clarified October 24

**Three different relationships must stay separate:**

1. **LOR network → physical Controller:** the LOR configuration assigns the network to a Controller. That Controller is the equipment **consumer** of the network. Preserve the LOR Controller/network identity and its existing managed authority; do not infer or edit it from GPX waypoint names or from crew circuit entry.
2. **GIS network path → waypoints:** the surveyed physical network cable/path is represented by GIS traces and associated maintained waypoint endpoint/location identities. The waypoint is **where network infrastructure is located**, not necessarily the owner of a network assignment. Network designations written in GPX waypoint descriptions are source annotations to reconcile against the physical track and controller identity, **not a replacement Controller-to-LOR-network assignment authority**.
3. **FLW / LinkIQ test → endpoints:** an FLW observation documents the test between the same identified waypoints/endpoints, with measurement and provenance. It does not create Controller-to-network assignments or GIS path geometry.

A Controller installed at a waypoint can consume a particular physical path. Join `LOR network ↔ Controller`, `Controller installation ↔ waypoint`, and `GIS route ↔ endpoints` by maintained IDs, with actual evidence and unresolved cases explicit. Do **not** assume that network at waypoint means every Controller there belongs to that network, that a Combo name identifies its network, or that matching labels prove a cable connection.

**FieldWiring Production Crew only define electrical circuit/power assignment information.** No Crew network assignment creation or editing in FieldWiring, and no extra manual network assignment form. Show read-only sourced path/Controller information when validated, and flag gaps for owning LOR/GIS reconciliation. Preserve original GPX and FLW records.

## Final integrated system design — October 24, 2026; governing next-schema checkpoint

**Operator design confirmation:** these seven capabilities together close the previously missing link from physical site infrastructure and LOR Controllers to circuit loading, breaker/panel state and safe waypoint work. This is the consolidated target design, **not** a claim that every relationship is installed, verified or accepted. Preserve prior controlled detail and historical evidence in this document; this section controls where earlier draft language conflicts.

### Permanent identities and sources — one model, not parallel reference stores

| Capability | Maintained relationship / authoritative source | Write ownership and expected presentation |
|---|---|---|
| Controller at waypoint | Existing physical `ref.controller` identity ↔ active, dated/attributed installation at one maintained waypoint; location changes retire prior link, never replace history | Authorized Crew may assign/move a Controller **only when its LOR-assigned required network is verified available at that waypoint**; both UI and database enforce it |
| Networks available at waypoint | Derived from accepted/reconciled GIS physical network trace(s) and explicit endpoint/segment relationships, joined by stable waypoint IDs and `ref.site_network` dictionary | GIS governed source/review determines network route availability; waypoint description may annotate networks, never independently proves physical trace or LOR Controller membership. Crew read-only |
| Physical park tracks | GPX/GIS reviewed route geometry for **both power and network**; distinguish H / network / primary / shared-trench classifications, track source and field-observed versus design status; retain immutable original GPS source, revisions, logical endpoint links and physically intentional map offsets | Controlled GIS review/apply only; neither crew circuit editing nor FLW imports may create or alter trace geometry |
| Physical network test evidence | FLW/LinkIQ captured test measurements between the **same two maintained endpoint waypoint IDs**, time/instrument/result/provenance preserved | Import/link as measurement evidence; never assume passing FLW proves physical geometry, network availability, Controller membership or route identity |
| Branch circuit capacity | Recorded Display amperage → maintained Display↔Controller association → active actual Controller plug-in/outlet→circuit leg→one physical breaker and rating; sum only comparable distinct loads, plus explicitly known auxiliary consumption | Read-only calculated demand, nameplate breaker amps, nominal headroom/utilization, missing data and uncertainties per **circuit leg**; grouped 2-pole 20 A breaker is **20 A per pole**, not 40 A. Preserve shared-neutral and measurement limitations |
| Panel, location, utility/safety | One permanent panel ID, waypoint/location where known, owner **City Owned / MSB Owned** (historical names retained for reconciliation), optional installation year, panel-owned Meter ID, upstream supply/local or remote main, physical breaker positions and mapped supplied waypoints | Authorized Crew record panel/circuit data; safety view uses recorded topology and hazard/unknown condition, no automatic assertion that circuits are de-energized. Utility-owned equipment and required utility coordination clearly distinguished |
| Seasonal panel and breaker state | **Panel** has explicit planned/show-season and off-season supply/energization statuses; each grouped **breaker** has its own show and off-season desired status, with one action covering all poles. Some panels remain energized off-season while selected breakers are off; other panels shut down entirely | Maintain panel-level and breaker-level targets **separately** and record timestamped observed field switch/utility evidence separately; unknown and not-confirmed states remain explicit. Never propagate desired OFF into “safe/de-energized” without verification |

### Practical operational workflow and rules

The normal Crew path is: select panel → choose a breaker position/amps and circuit legs → assign eligible existing power/outlet waypoints → install existing physical Controller where its required LOR network is demonstrably reachable by an accepted GIS trace → select the Controller's *actual plugged-in outlet/circuit leg* → view connected Displays' expected demand against the rated branch capacity. The panel screen also shows Meter ID, owner, physical location, off-season **panel status** and each breaker's separate status; a waypoint safety view traces potential upstream power sources and known isolation actions, never a definitive safe-work clearance based solely on database state.

A Controller's LOR network remains LOR-owned. Crew **cannot define networks, assign network IDs, or edit physical traces**. No independent FieldWiring network-assignment form/API; show GIS-sourced available paths and LOR Controller consumption read-only. Combo only denotes **power plus network facilities** on a box or light pole; it does not prove a specific network. If network availability is missing/stale/ambiguous, hold Controller placement with reason and route to existing governed GIS reconciliation. No automatic topology inference from GPX names, FLW labels or proximity. A valid FLW test without accepted trace/endpoints is **tested but path unresolved**.

Electric load projection explicitly reports unknown Display currents, zero-versus-missing, estimates-versus-measured, duplicate or non-comparable load ratings, controllers without recorded power connection, loads without Controller identity, possible self/auxiliary loads, and equipment/voltage mismatch. Missing demand is **not zero**; totals must be marked incomplete. Headroom is nominal only and must not be labeled NEC-compliant or safe-to-load without verified continuous-load assumptions, conductor/receptacle limitations and field checks.

For safe work at waypoints, list **recorded potential sources** (panel, upstream main, grouped breaker and circuit leg, path uncertainty), planned OFF/ON and actual evidence, with cautions for alternate feeds and incomplete topology. Never treat a planned/saved OFF as measured absence of voltage. Physical lockout/tagout, tested de-energization and authorized utility action remain separate field safety procedures, not inferred database facts.

### Schema and validation gap list — next engineering thread MUST implement

- Inspect the actual existing LOR source of Controller→network and Display→Controller associations and the recorded amperage **unit/basis** before specifying joins or aggregate formula. Reuse permanent IDs; do not invent another association table when a maintained one exists.
- Inspect and reconcile #319's current waypoint/track/cable/network-source schema and GPX/FLW intake for stable route segment endpoints and network type/availability. Build a **governed derived availability projection**; protect it from Crew writes and reject Controller placement unless the required path is confirmed. Preserve approved Crew Controller *location* and power-circuit assignments.
- Add explicit panel-level planned show-season/off-season energized states **only after checking installed/candidate panel fields**; preserve breaker-level separate planned statuses and actual action evidence. Model panel shutoff via its own main/upstream supply, not a fictional per-circuit OFF.
- Implement one read-only per-leg branch amperage rollup with lineage, completeness warnings and breaker ratings, avoiding duplicate Display attribution. Test multiple Displays/Controller, multiple Controllers/circuit, shared grouped breaker legs, mismatched units, missing amps and ambiguity.
- Implement sourced waypoint work/safety view with upstream sources and switching status, unknowns and prerequisite/verification guidance. Never claim electrical safety from application state.
- Remove/deny `network` CRUD from ordinary FieldWiring UI **and** SQL/privileged command; GIS/Garmin/FLW operations remain separately governed. Test negative access at the DB boundary.
- Prove the entire chain in isolated synthetic SQL/browser tests and current-Production PostgreSQL 16/PostGIS disposable clone using preserved original GPX/FLW evidence, then protected Crew/Manager operator browser acceptance. Validate historic audit/replay/rollback and do not run parallel #454 power migration.

**Operational cleanup evidence provided by operator:** `Setup REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT`; postcheck `PASS: preview port and GIS source lock are available`; SSH session closed and wrapper `PASS: preview exited; port and GIS source lock available`. This proves teardown/port-lock release for the reviewed disposable session **only**; it is not feature acceptance, source fingerprint proof, or Production release. No report path supplied with this excerpt; preserve the actual remote report if available.

**Governance:** #122 controls launch integration; #171 GIS; #230 maintained reference editor; PR #319 is the current canonical candidate; draft PR #454's older power DDL must **not** be installed alongside it. Existing #37 maintenance/snapshot/rollback/ONLINE procedure governs any separately approved Production release. Current candidate is **CHANGES REQUIRED** for the final network/controller/capacity/panel status/safety design, irrespective of prior source CI PASS.

## Controller placement, circuit loading and breaker capacity — October 24

**Operator-approved missing relationship:** A Display has recorded amperage; the existing LOR/FieldWiring relationship identifies which Displays are connected to which physical Controller. A Controller is installed at a waypoint and plugged into an identified outlet supplied by a particular **circuit leg**. From these existing IDs, the application can produce a computed expected amperage per supplying circuit and compare it to the protective breaker's **rated amps**, without adding pole ratings together.

**Crew permissions:** Authorized Production Crew may assign or move an existing Controller installation to a waypoint **only if the required LOR network assigned to that Controller is confirmed available at that waypoint through the accepted GIS physical network route/endpoints**. Crew may then record which physical supplying circuit/outlet that Controller plugs into. Crew never create or change Controller LOR network assignments, GIS physical traces, network paths or network membership. Network validation must be enforced in the database command, not just dropdown filtering. A waypoint merely labeled Combo does **not** prove the correct network is available; an unverified, missing, stale or conflicting network path must HOLD the assignment with an actionable reason and allow governed reconciliation. Preserve previous installation/plug-in history on moves; do not invent connectivity from proximity, names or FLW tests.

**Derived loading (read-only, recomputed):**
1. Resolve each active Display's known current amperage and maintained Display→Controller association; distinguish missing, zero and estimated from verified demand.
2. Resolve the Controller's active recorded power input/outlet connection → circuit ID → supplying breaker/pole, using the maintained relationships. Controller location alone must not imply plug-in supply.
3. Sum distinct attributable Display loads **once per active physical assignment** to produce expected amperage per circuit. Do not double-count Display aliases, controllers with multiple records, or the same display attached through projections. Unresolved mappings are separately reported and never silently treated as 0 A. Include known Controller/auxiliary self-load only if independently recorded; otherwise report **incomplete**.
4. For each breaker pole/circuit show rated protective-device amperage, calculated connected/display demand, headroom and utilization; keep one two-pole breaker's common rating (e.g. 20 A per pole), not a fictional 40 A branch capacity. Do not combine legs with different neutral/phase assumptions. Surface grouped-breaker and shared-neutral uncertainties separately.
5. Different voltage, power factor, AC/DC rating basis or noncomparable device amperage must be normalized using verified specifications before addition. If such evidence is unavailable, show an **unverified/incomplete calculation**, not a safe-capacity claim.
6. Treat branch utilization as engineering planning information; any applicable continuous-load derating, breaker/cable/receptacle limits and actual operational measurement require separately verified field design. Do not call an estimated sum safe merely because it is below nameplate breaker amps.

The read-only projection must include provenance for each Display demand and assignment plus unmapped Displays, missing Controller network path, missing plug-in circuit, and unresolved circuit leg. It must be auditable and refresh after a Crew-saved Controller installation/outlet assignment or LOR/GPX source reconciliation. The UI should present **recorded load / breaker rating / remaining nominal capacity / completeness**, distinguish estimated from measured, and never edit amps redundantly at waypoint or breaker.

**Required integration/acceptance:** source inventory and actual schema for Display amps and Display→Controller mapping first; joined calculation over stable identities with synthetic cases for one controller/multiple displays, multiple controllers/one circuit, multiple circuit legs, absent demand, duplicate mappings, noncomparable units, unavailable network, accepted network, missing outlet and saved/reloaded correction history. Crew allowed Controller installation and plug-in power assignment; Crew network/GIS/LOR reassignment DENIED. Do not deploy until these tests, current PostgreSQL 16 clone review and protected Crew/Manager browser acceptance pass.

## Controlling network, GIS, FLW and Crew authority — October 24, 2026

**Operator correction; supersedes any older assertion that Production Crew may assign or edit networks in FieldWiring. They never had that authority.**

| Subject | Authoritative evidence and ownership | Allowed FieldWiring action |
|---|---|---|
| Network identity at a waypoint | Maintained master GPX waypoint description, reconciled through the governed GIS source-intake process; `ref.site_network` supplies standardized network codes | **View only**. No manual Assign network, Create network, Replace network, or network relationship correction by Crew |
| Physical network route/path | Surveyed and reviewed **GIS physical traces/tracks** and maintained endpoint relationships; preserve original GPX geometry, notes and provenance | **View only**. Do not infer a route from a network code, Circuit designation, Combo label, or physical proximity |
| FLW / LinkIQ | FLW records **physical cable test observations between the same maintained waypoint endpoints** (instrument results, date, evidence); it does not declare the network route or rewrite the GPX master | **View test results**, and investigate discrepancies; never promote test data into authoritative route geometry |
| Power panel, breaker, circuit and supplied outlets | Governed FieldWiring PostgreSQL circuit model and recorded Crew observations, with Directus authorization and audit | Production Crew **may define and correct circuit information** and associate supplying circuit legs with existing eligible power waypoints; never rename or move the master waypoint |

**Combo** is a waypoint capability meaning both **power and network**, independent of whether the structure is a network box or light pole. Combo by itself is not a network ID or proof of any particular network trace.

The GPX description's network assertions must be parsed according to the accepted source conventions and mapped to existing stable waypoint/network IDs. The database stores a queryable **projection**, not a second network authoring authority. Multiple confirmed memberships may exist. If the description is absent, ambiguous or inconsistent with a historical database relationship or GIS trace, preserve the conflict and mark it **unresolved**; do not guess, silently replace the GPX, or invite Crew to re-enter it. GIS source review resolves the discrepancy. Network route evidence and LinkIQ test evidence remain separate even when they share endpoint IDs.

**UI and command consequence:** Normal FieldWiring should display sourced network memberships and their provenance/read-only status, not the current `Define network` / `Assign network` field-editor action. The underlying `network` write command must not remain available to Crew through an alternate API path. Design and code acceptance must verify that Crew still can save breaker/circuit data but cannot create/update network membership, and that GPX→PostGIS projection and FLW endpoint joins never fabricate physical topology. **The current candidate is CHANGES REQUIRED until these are implemented and tested.**


| Document control | Value |
|---|---|
| Status | Implementation candidate; not deployed or operator accepted |
| Owner | #171 / #230, commanding #122; FieldWiring |
| Reviewed | 2026-10-23 |

## October 23 revised candidate — panel diagram and Combo inventory

Design-first disposition: V0.4.8 is CHANGES REQUIRED, not operator accepted.
The next candidate separates panel identity, outlet supply and network-box inventory.
Panel owns GPX identity, owner, meter and local main or explicit remote supplying
breaker. Breaker owns amps and seasonal/non-seasonal desired state. Circuit legs
own supplied-waypoint relationships; ordinary Power waypoints require only those
relationships. No duplicate circuit-rating or outlet seasonal-state entry.

The normal panel interaction is a compact odd-left/even-right diagram. A two-pole
breaker spans vertically adjacent same-side positions (1/3 or 18/20), never 1/2.
Click a circuit leg to select its supplied waypoints. Breaker properties are edited
separately and retain existing circuit IDs and feeds. Empty diagram positions are
entry controls, not assertions that installed slots are empty. A5 acceptance uses
18 two-pole breakers: left 1/3 through 33/35, right 2/4 through 34/36, 20 A per
pole, main 200 A. This is a disposable fixture, not authorization to seed Production.
Unusual recorded positions remain visible for reconciliation.

OUT-Combo is one waypoint with a receptacle and a separate network enclosure.
Only the network enclosure receives inventory installation records. Reuse existing
ref.controller IDs and model catalog for switches, repeaters, PixieLink and power
supplies. Add only ref.site_controller_installation: controller FK, waypoint FK,
active/retired relationship, evidence and verification. One active installation per
controller; moving equipment retires the old association before creating another.
Identity/location fields are immutable on an association; history is retained in
the existing revision/audit log. Existing controller current_location_code remains
legacy descriptive context, not a second editable waypoint mapping on this page.
Do not create another device catalog or use site_power_device as asset inventory.
Work Orders continue to own failures/repairs linked to controller_id. Unknown PSU
models and the reported failures require identified assets; no invented records.

Controllers can also plug into an outlet at either a Power or OUT-Combo waypoint.
This is independent of network-box installation: ref.site_controller_power_connection
links an existing controller ID, outlet waypoint and explicitly selected circuit leg.
No inference from physical placement, waypoint name or two-pole grouping. Multiple
controllers can use an outlet. A controller has at most one active recorded plug-in
connection in this candidate; multi-input hardware requires a later explicit input
model, not ambiguous duplicate connections. Require an active recorded feed path
from the selected circuit to that waypoint, including intermediate devices. Reject
retiring/changing that supply while an active controller connection depends on it.
Moving a connection retires the old row then creates another; retain audit/history.
Both associations enter the GPX dependency fingerprint. The ordinary Power view
shows supplying circuits and plugged-in controllers, with no network-box fields.

Reuse site_power_snapshot/site_power_command, Directus authorization, atomic API
batches and exact-retry handling. Include installation relationships in the GPX
dependency fingerprint. Existing controller/model tables are deployment dependencies;
minimal synthetic catalog tables belong only in existing disposable CI fixtures.
No additional service, importer, migration runner or acceptance workflow.

Validation must cover A5 diagram spanning and circuit-click assignment, ordinary
Power hiding network inventory, multiple Combo assets, duplicate placement denial,
retire/reinstall history, authorization/retry, shared-breaker feeds and themes.
GPX/FLW intake remains the PC GIS Manager's two governed workflows under #378.
Preserve the existing cached source paths and reusable preview CLEAN EXIT procedure.
No Production change until exact-candidate disposable and operator acceptance.

## October 23 operator review — one breaker workflow (supersedes generic entry)

Disposition: CHANGES REQUIRED at candidate 99198bbd. Operator confirmed successful
preview CLEAN EXIT and independent free port/source-lock check. Cleanup is not
feature acceptance. Screenshots show duplicated circuit entry, silent Save failure,
no light-mode control, and irrelevant equipment/network detail on the breaker page.

Primary workflow is Panel -> meter -> main or branch -> positions/circuit legs ->
whole-number amps -> show ON/OFF/UNKNOWN -> feeds per leg -> one Save. Common amp
suggestions are 15,20,30,40,50,90,100,200; allow other positive whole-number ratings,
never fractional spinner precision or summed pole ratings. Accept slash or comma
position separators; hide/ignore branch positions for MAIN. Source/evidence notes
remain optional in the simple UI with explicit unverified operator-entry provenance;
verification must not be silently asserted. Validation errors stay visible inside
the dialog, retain input, focus the error, and never fail as unhandled exceptions.
Use the existing FieldWiring theme preference and CSS variables, including dialogs.

One atomic backend compound command reuses existing named commands/Directus/audit/
revision locking and retry identity to save the breaker, its circuit legs and direct
waypoint feeds. No separate circuit form is required for normal breaker entry.
Retain permanent circuit IDs on edits; never infer pole membership from GPX names.
The explicit entered positions provide initial circuit designations; existing
circuit designations are retained. Each leg selects its actual supplied waypoints;
A5-18/20 can appear on both legs, with 18 and 20 shown separately. Additional
waypoints on either leg are supported. Indirect feed paths are retained; their
correction is separate from replacing the explicitly displayed direct selections.
Existing unusual/unknown circuit records remain available for reconciliation.

Show/restoration desired states belong to the breaker interaction; historical
circuit values must be reconciled rather than silently discarded. Meter identity
remains panel-owned and editable beside the main/supply area, not duplicated on
each breaker. A panel may have a local main or a reviewed upstream breaker in a
different defined panel. Record remote supply by breaker ID, including FE-00 from
Panel 15 only when its actual supplying breaker is selected; do not invent that
breaker or rating from the example. Reject supply cycles and contradictory active
local-main/remote-main definitions. Recorded impact includes downstream supplied
panels, without claiming verified isolation or complete installed topology.

An OUT-Combo waypoint must never have active supplies from different breakers.
Enforce this across direct and intermediate-device paths and after circuit,
breaker, feed or equipment corrections, using permanent breaker identities.
Two circuit legs from the SAME breaker are allowed. Unknown membership is not
permission to accept competing supplies; unresolved multiple supplies must HOLD.
Retain contradictory historical evidence without publishing it as an accepted
active relationship. Database command validation remains authoritative.

Equipment, network switches, PoE supplies, network assignments and conductor
engineering are waypoint/OUT-Combo detail, not required breaker fields. Keep the
underlying records and access available in a clearly separate detail area while
the breaker schedule remains compact. Do not invent new equipment inventory.

Acceptance: simple branch save/edit/retry atomicity, whole-amp validation, slash
positions and malformed-input message, main hidden positions/meter, upstream panel
supply and cycle denial, same-breaker two-leg OUT-Combo acceptance, different-breaker
rejection including indirect paths, retained IDs/history, both themes and mobile.
One combined candidate/current-Production-clone review remains required.

### Implemented defect correction checkpoint — not a new operator handoff

V0.4.7-breaker-review fixes uncaught position-parser errors before Save handling,
accepts slash/comma integer positions, hides/clears branch positions for MAIN,
uses positive whole-number amps with common suggestions, and adds a persistent
FieldWiring light/dark control with themed dialogs. The same governed database
command now rejects fractional ratings and competing active supplies to an
OUT-Combo, including device paths, circuit rebindings and unresolved competing
memberships. Two same-breaker circuit legs remain allowed. IDs/history are retained.

Local verification: 220 FieldWiring application tests, 91 isolated PostgreSQL
command/denial checks, and actual Chromium workflow PASS. Browser coverage includes
malformed positions with visible retained-input error, slash entry, main positions
hidden, whole-number step, theme toggle/reload, save/retry, mobile and read-only.
Tests now use separate synthetic boxes for independent fixture supplies instead
of treating unrelated breakers on one combo box as valid. Real PostGIS CI and
current-clone/operator acceptance remain separate gates.

### Integrated workflow candidate — V0.4.8-breaker-schedule

The single atomic breaker/circuit/feed form, breaker-level show/restoration state,
panel-owned meter/remote-supply editing and waypoint-focused equipment area are
now implemented in the existing #319 candidate. Generic circuit entry is confined
to the collapsed unknown-membership reconciliation area. The same SQL command
boundary, Directus authority, revision lock and audit store remain authoritative.

Local regression: 220 FieldWiring and 901 Setup application tests; 106 isolated
PostgreSQL command/denial checks; actual Chromium combined-save/edit/retry workflow
PASS, including retained leg IDs, same-box two-leg supplies, meter editing, remote
supply selection, themes and mobile width. Source/allowlist tests: 44 PASS, one
real-PostGIS-only test skipped locally. The existing real-source acceptance helper
now exercises the compound schedule and exact replay with imported waypoint IDs;
its disposable changes still roll back. No new acceptance runner or auth bypass.
Exact-head CI, current-Production-clone and operator acceptance remain required.
Production is unchanged. Prior successful CLEAN EXIT is cleanup evidence only.

### Compound command and remote-supply implementation contract

The existing `site_power_command` gains `breaker_schedule`, with one request UUID,
revision, breaker ID (null for new), and fields `breaker`, `legs`,
`show_desired_state`, `restoration_desired_state`. Each explicit leg contains
`pole`, `circuit_code`, and `waypoint_ids`. Existing active legs are matched by pole
and retain IDs; omitted existing legs are rejected, not silently retired. Direct
feeds removed by the operator are retired; indirect equipment paths are retained.
The command recursively invokes the same audited named commands under the existing
revision lock. Deterministic child UUIDs and a final compound receipt provide exact
retry identity. Every child and receipt rolls back if any validation fails.

Breaker desired states are persisted on the breaker, including mains; the combined
form explicitly reconciles active leg states to the selected breaker states. When
changing grouped legacy states, audited UNKNOWN transitions and final states occur
inside the same transaction and are never externally visible as partial saves.
Generic legacy circuit editing remains a reconciliation surface, not normal entry.

`site_panel.supply_breaker_id` references the actual upstream breaker. The existing
panel command edits meter and supply together; active remote supplies require an
active different panel/breaker, reject cycles and local-main conflicts, and block
retirement of referenced supplies. Impact walks descendant panels through recorded
supply breaker identities, retaining the recorded-coverage qualification.

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

## October 24 implementation reconciliation at e97ab34

Repository inspection confirms `ref.controller_display` owns physical Display assignments; `wiring_source_display_id` is wiring lineage, not a replacement physical load identity. `ref.display.amps_measured` is a nullable numeric recorded current with no voltage, AC/DC, measurement-condition or estimate classification columns. Therefore show attributable recorded-current subtotals with explicit INCOMPLETE basis/self-load/field-confirmation warnings; no verified branch-capacity claim or invented conversion. Multi-controller Displays are unresolved, never charged in full to every controller. Physical copies with a shared wiring source keep their independent Display currents.

`ref.controller.lor_network` is recorded programming, not LOR assignment authority. Placement must corroborate it against current LOR props/subprops reached through the existing physical assignment and wiring-source Display IDs, with matching UID range. Missing or conflicting required networks hold placement. Reuse the reviewed ordered `site_cable_route_segment` chain, its directional endpoint continuity, reviewed `site_route_segment` and current source-track provenance to derive availability at cable endpoints. A test, manual waypoint membership, source label, or Combo classification cannot satisfy this gate. Later source changes recompute eligibility; existing installation history remains visible with current eligibility.

Extend the existing uninstalled canonical power migration with read-only projections, panel show/restoration targets and panel-targeted actions using existing append-only activity evidence. No additional migration or asset/catalog store. FieldWiring snapshot and GIS membership projection consume the same derived network availability. Waypoint safety lists recorded feed paths, upstream panels/main breakers and actual event evidence separately from plans; incomplete topology and alternate supply remain explicit. SQL denies network writes before idempotent replay; removing a form alone is insufficient. Existing synthetic command/browser fixtures gain current-LOR/route dependencies; existing PostGIS CI and disposable runner remain the acceptance mechanisms.

Reviewed network cable routing can explicitly reference NET, PRI or HV source geometry: a shared trench does not change the cable's maintained network identity. The explicit reviewed cable-to-route and route-to-source relationships remain mandatory. Network spellings use case/outer-whitespace comparison; different dictionary designations remain unresolved rather than inventing membership aliases.

## October 24 operator deployment workflow correction

The operator rejected the mixed panel/equipment page and all-waypoint selector. Keep Panel Circuits focused on breakers, assignments, loads and seasonal switching. Provide separate Waypoint Connections, Combo Equipment and read-only Cable Test History routes on the existing FieldWiring host, sharing the existing snapshot/command implementation rather than new applications or stores. Endpoint selectors list structured Power, Network or Combo capabilities only; action-specific controls restrict power input to power/Combo and network installation to network/Combo with the existing LOR/GIS eligibility gate. Stage, panel, hydrant and manhole types are not deployment endpoints.

Controller Inventory must display and edit the same active `site_controller_installation` and `site_controller_power_connection` records used by Waypoint Connections. Keep network location separate from actual plugged-in power outlet/circuit. Moving a connection atomically retires its prior historical row and creates the new association through the existing revision/idempotent command batch; blank explicitly disconnects that relationship. Refresh after saving; reject stale revisions and preserve exact retries. No writes to LOR programming or duplicate location field.

Combo Equipment owns location-specific additional installed equipment UI, reusing `site_power_device` identities/categories. Cable Test History is read-only: choose a maintained endpoint pair, distinguish parallel physical cables, list every retained FLW/LinkIQ UUID/retest with date, raw result, standard, measured length and source provenance. Unresolved cable bindings remain explicitly unresolved; no label/proximity inference. No test editing/deletion or route/network assignment controls.

### Breaker-to-waypoint cardinality correction

One breaker may supply multiple waypoints. Every waypoint, regardless of type, may resolve to at most one active breaker through its direct and equipment feed paths. Multiple circuit legs of the same breaker remain allowed; different breakers or unresolved competing circuit identities are rejected. Historical retired feeds remain available. Moving an assignment requires retiring the previous supply before activating the replacement; dependent controller connections must be reconciled in the same governed workflow. The assignment picker identifies conflicting supplies rather than offering an invalid second breaker.

### Single-pole and two-pole continuation rule — explicit operator clarification

The exclusivity boundary is the supplying breaker identity, **not a single circuit per waypoint**.

- A two-pole breaker has two separately identified circuits. Both may serve one waypoint; either or both circuits may continue to additional waypoints. Each continuation retains its original circuit and breaker identity.
- A single-pole breaker has one circuit. That circuit may serve one waypoint and continue to additional waypoints, retaining the same circuit and breaker identity.
- No destination waypoint may receive a circuit from another breaker, whether the competing supply arrives directly or through any number of intermediate equipment/feed connections. This rule applies at every waypoint along the recorded path.
- Circuits from the two poles remain distinct; sharing a waypoint does not join the circuits electrically or combine their load ratings. Waypoint names do not establish circuit membership or physical continuity.

Examples: breaker A5 2/4 may supply both circuits 2 and 4 at one waypoint; circuit 2 may continue to A5-02A and A5-02B while circuit 4 continues to A5-04. None of those waypoints may also receive a circuit from a different breaker. A single-pole breaker 6 may supply several other waypoints, but its circuit cannot extend into any waypoint already supplied by breaker 2/4. Use the existing circuit/feed records for these relationships; no duplicate schema or inferred wiring.

## October 24 disposable review corrections: parsed pairs and remote panels

FLW test labels already express endpoint pairs and designation (for example FE-02B TO FE-02 AUX-E). Cable Test History must consume the existing LinkIQ intake parser/proposals, grouping source-declared pairs and designation even before a physical cable has been reviewed. Preserve original labels, source hashes, retests and qualifiers. Parsed evidence is not permission to assign physical cables or establish network/GIS continuity. Ambiguous names remain explicit. Extend existing proposals with parsed endpoint labels; do not add another parser or source authority.

Remote distribution panels can have a known supplying panel before its specific feeder breaker is inventoried. Extend the existing site_panel with nullable supply_panel_id, retaining supply_breaker_id for the actual isolation device. Panel FE-00 may select Panel 15 with breaker unknown; never fabricate a breaker. If both are recorded they must agree, be active and not form a cycle. Trace known panel ancestry for safety and retain unknown isolation-device warnings.

Panel prefixes (A5, CL, GG, FE, etc.) prioritize assignment candidates by the associated panel/waypoint name. This is a selection aid, not a circuit assignment or capacity inference. Show matching-prefix waypoints first, preserve existing assignments and allow all eligible exceptions, especially powered light poles. Breakers/circuits without discovered waypoints are valid and must remain recordable, including non-show/security/bathroom lighting and seasonal pole or dusk/dawn controls. Empty mapping means incomplete GIS coverage, not absent electrical load.

## October 24 bounded deployment release scope

Greg directs proceeding with panels, breakers, meters, waypoint assignments **and Controller network placement and actual outlet/circuit assignments** so panel inventory can precede field deployment. The cleaned current master is the initial source; preserve its bytes, provenance and permanent waypoint identities. Later corrections must preserve existing panel/controller relationships. Do not require the later GPX synchronization interface before this release. This supersedes the earlier all-capabilities acceptance requirement only for the explicitly deferred work, not the shared schema or authorization boundaries.

Operator PASS: panel, breaker, waypoint assignment and existing Combo equipment screens on V0.4.13. Controller assignment remains incomplete operator acceptance. Existing model/instance inventory enhancement, failed component replacement and future 24 mm labels, cable-history simplification and direction-independent retest presentation, and GPX ingest/reconciliation workflow remain deferred. The current master is accepted for starting inventory; it does not certify all database geometry or reviewed network routes. No bypass of the LOR/GIS placement gate is authorized.

Controller empty selectors must explain the actual prerequisite from the existing snapshot: unresolved current LOR requirement versus confirmed network with no eligible reviewed route. An outlet with no active recorded supply must explicitly say so and link to Panel Circuits for assignment. Preserve two-pole selection and never choose a circuit from a similar name. Add no records from guesses or browser tests. Inventory may be recorded UNVERIFIED before technicians confirm physical associations.

Use the same canonical migration chain and application host, without competing tables or a new deployment runner. Deferred workflows are not declared accepted merely because their schema/read-only views are shared dependencies. Before Production: exact candidate checks, targeted Controller browser acceptance, current source import/reconciliation evidence, current live checkout preflight and the Server Management database-changing release procedure. No Production deployment has occurred.

## October 24 FLW authority correction — controlling release decision

Greg establishes LinkWare/FLW as physical cable, endpoint and network authority; GPX supplies cable-run geometry only. This supersedes the earlier requirement for reviewed GIS paths before Controller placement. Derive network membership at BOTH uniquely resolved endpoints from existing immutable FLW intake proposals/tests; normalize REG and AUX letter spellings (Aux E / AUX-E) against the existing network catalog. Do not permit Crew network editing or infer connections from waypoint prefixes. Multiple networks may belong to one waypoint. Retain current LOR programming validation and Network/Combo capability checks.

Cable retests group by unordered permanent endpoint pair and normalized network/designation, with recorded physical cable identity separating replacements. Newer reliable tester timestamps win regardless of age; never fall back to an older pass after a newer failure. Preserve known unset tester dates (2/10/1970) and other invalid/missing dates as raw evidence. Without reliable ordering, mark chronology uncertain instead of treating import order or UUID as physical test order. Such uncertainty does not erase endpoint/network evidence. Display test result separately from membership; a past test is not today's live-link proof.

This release reads existing imported records only. No test UPDATE/DELETE, new intake workflow, invented cable binding, duplicate inventory or GPX rewrite. Future incremental FLW ingestion and expanded cable-history presentation are deferred. Controller field acceptance is still required. Operator reports the latest preview CLEAN EXIT with port 8898 and source lock available; next launch must recheck them.

## October 24 panel endpoints and LOR topology clarification

Greg confirms all panel locations have network facilities, including RA-00 and CL-00. SW and PO are network distribution boxes without power. A GPX waypoint type that lacks Network/Combo must not hide an endpoint established by FLW; use the existing FLW network-membership projection for Controller placement on both screens and at the database boundary. Keep actual outlet power separate: network capability does not establish a power outlet. Specific Controller placement still requires its LOR network to match FLW evidence; do not assign every network to every panel.

LOR topology requirement: branching from one waypoint to two different waypoints uses a LOR repeater at that distribution point. Controllers on a branch are daisy-chained controller-to-controller. Record the end as a terminating resistor, or a return cable to the originating point that continues toward the next waypoint. A return-to-origin continuation must not be represented as an assumed closed electrical ring. Do not manufacture installed repeater inventory or verified branch/termination facts from graph degree alone. Existing RS485_REPEATER equipment classification remains the inventory owner.

The four Racing Arch Controllers are reported from memory as a waypoint-fed controller chain ending there; this is UNVERIFIED field evidence, including the actual termination. The current controller_installation record captures the network attachment waypoint, not Controller predecessor/successor order or branch termination. These are additional topology requirements, not capabilities already implemented or tested. Preserve them for the existing model's topology extension; do not claim complete topology capture from the endpoint fix.

### Endpoint authority and equipment expectations — final clarification

Every uniquely resolved FLW endpoint carrying the required network is eligible regardless of GPX waypoint type. No Panel, SW, PO or other name-based exceptions are needed. Power outlet eligibility remains a separate fact. The waypoint projection exposes FLW-derived network capability so Controller Inventory and Waypoint Connections use the same rule as the command guard. An attachment waypoint may be the origin of a Controller daisy chain; assigning it does not assert a direct cable from each Controller to that waypoint or record chain order.

At INET/E1.31 distribution points, prompt inventory/verification of switches and power supplies where contiguous runs approach roughly 300 feet, and PoE for any security cameras on the line. Multiple same-network neighboring endpoints flag possible LOR branching for repeater verification, not a proven branch or installed repeater. These are read-only equipment expectations. Do not create installed equipment from length, graph shape or network membership. Existing actual inventory is entered only from known equipment. Preserve the Racing Arch chain as unverified recollection.

Operator confirms the latest disposable review CLEAN EXIT and port/source-lock release. Next candidate needs exact-head tests and a fresh lock/port preflight; this is not Production deployment approval.

## October 24 controller chain order — required before release

Greg requires the physical order, not only the shared network origin. Extend the existing
`ref.site_controller_installation` with `upstream_kind` (UNKNOWN, WAYPOINT,
CONTROLLER), nullable `upstream_controller_id`, and `chain_end` (UNKNOWN,
TERMINATOR, RETURN_TO_ORIGIN). The existing waypoint remains the chain origin.
UNKNOWN preserves incomplete observations; never infer a direct connection from
an older origin-only record. A controller predecessor is an existing inventory ID,
not another inventory or wiring system. Controller-to-display wiring is unchanged.

Both supported endings are explicit: RA-00 → 1001 → 1002 → 1003 → 1004 → RA-00
(return cable for onward continuation), or the same chain ending in a terminating
resistor. Return is an end designation at the origin, not a controller dependency
and not an inferred closed electrical ring. Only a last controller may have a
recorded ending. UNKNOWN allows incomplete inventory and is never called verified.

A predecessor must be active, have recorded upstream order, share the origin and
confirmed current LOR network, and have no other downstream controller. Every
member retains the existing FLW/LOR placement gate. Reject self-links, controller
cycles, controller branching, mixed networks/origins, and dangling dependencies.
Multiple independent chains at a waypoint are allowed; repeater equipment remains
a field verification expectation, never automatically installed inventory.

Use the existing serialized revision-checked command and audit history. Topology
corrections on an existing installation retain before/after audit evidence. Changing
origin continues to retire/create installations. Rewire or disconnect downstream
controllers first before retiring/moving their predecessor. Clear a recorded chain
ending before extending it. Do not silently cascade moves, change downstream wiring,
or invent termination. Controller Inventory and Waypoint Connections edit the same
fields; power remains independent and network-only saves remain possible.

Required regression: a four-controller ordered chain and both endings; mixed network,
self/cycle/fanout, wrong origin, terminated predecessor and retirement denial;
reordering, stale edits, exact replay, rollback, shared-screen persistence, unknown
order display and authorization. Reuse the current disposable runner and migration
chain. Current review exited cleanly; new exact-head browser acceptance is pending.

## October 24 reciprocal IN / OUT correction — controlling operator requirement

V0.4.16 is not accepted: recording only a predecessor and a terminal selector does
not expose the physical controller ports. Both screens must present editable IN and
OUT. OUT includes eligible controllers, terminating resistor and the named return
waypoint. Saving A OUT → B establishes B IN ← A; editing B IN establishes the same
relationship and A's displayed OUT. Store one edge using the existing predecessor
field; do not add a second independently editable successor column or another schema.

Extend the existing audited command boundary with an atomic controller_ports command.
It changes the selected installation and, if needed, the previous/new downstream
installation under the existing revision lock. Validate the completed graph before
commit. Retain audit before/after for every affected controller and preserve retired
origin records. Detaching an edge makes the released port UNKNOWN, never invents a
new waypoint cable or deletes the remaining chain. A known OUT may coexist with an
unknown IN; this supersedes V0.4.16's requirement for a known predecessor input.
Occupied controller ports must not be silently stolen: reconcile an existing input
or output explicitly. Reject self/circular links, fanout, different current LOR
networks/origins and ineligible FLW origins. Network and power remain independent.

Required operator examples (not automatically installed or verified):
RA-00 → 1001 → 1002 → 1003 → 1004 → resistor OR return to RA-00 (unverified);
ST-01 → 1005 → 1006 → 1036 → return to ST-01 (unverified).
Show each controller's IN and OUT with names and verification status, including
both ends when the operator navigates to the neighboring controller. Use the same
port editor from Controller Inventory and Waypoint Connections. Tests must start
with an unassigned next controller and prove it is selectable from OUT, persisted
reciprocally, replaceable without invented wiring, and protected on stale/replay,
invalid graphs, existing occupied ports and rollback. No replacement preview may
be started while the current review holds port 8898/source lock; current V0.4.16
review has no subsequent clean-exit receipt yet. Production unchanged.

## October 24 display names in network wiring

Greg's AUX-I review shows a recorded cross-stage chain from WV-03 through eight
Who Forest controllers and into Whoville, ending at CTRL 1061 with a resistor.
He reports difficulty identifying Tree 8 (CTRL 1094) from asset IDs alone; the
screenshots are evidence of the recorded chain, not confirmation that all intended
controllers or the physical wiring are verified. The current repeat preview has
no new CLEAN EXIT receipt yet.

Display the assigned physical display name below each Controller ID in the IN /
Controller / OUT table and alongside IDs in choices and the chain description.
Use existing ref.controller_display/ref.display relationships already exposed in
snapshot load_lineage, including controllers without power connections. Never use
wiring-source template names in place of physical display names, infer tree order
from IDs or stage order, rename controller assets, or copy names into installation
records. Show all assigned display names and an explicit no-display fallback.
Reuse the same labeling helpers on both screens. This is presentation only: network
eligibility, topology, power, audit and stage filtering remain unchanged.


## October 25 controller list sort — final operator refinement

Greg accepts V0.4.18's physical display names in network wiring and supplies CLEAN
EXIT with port 8898 and GIS source lock released. Retain earlier panel/breaker/
waypoint, Racing Arches and Elf Choir acceptance; physical wiring stays UNVERIFIED.

Add a visible Sort by selector in the left Controller list: Controller ID (default)
or Display name. Sort the existing filtered inventory response locally, using its
physical display_names, with natural numeric/case-insensitive name ordering,
unnamed/unassigned controllers last and numeric Controller ID as tie-breaker.
The choice remains active during filtering/refresh in this page. Sorting must only
rerender the list, retaining selected controller and unsaved detail/connection edits.
Do not change stage filters, network chain order, assignments, schemas or API.
Reuse the existing browser regression and disposable preview mechanism.


## October 25 picker sorting follows Controller list

Greg accepts V0.4.19 left-list sorting, but screenshots 053857 / 054133 show the
IN/OUT controller options remain in ID order when the list uses Display name.
CLEAN EXIT confirms port 8898/source lock available. Extend the same sort choice
and comparison rules to both port pickers, initially and immediately on sort changes.
Keep non-controller choices first, preserve selected values and unsaved edits, and
retain all eligible controllers across stages. Reorder existing options without
triggering connection-change handlers, reloads or saves. Do not sort the recorded
chain or change eligibility, topology, power, database or source files.


## October 25 approved initial Production installation profile

Production receipt proves PostGIS 3.5.2 and only ref.site_network (27 rows) in
the new model namespace; no waypoint/power/FLW tables or site functions exist.
Both accepted source cache hashes pass. Existing Directus Manager capability passes.
Preserve all 27 network rows/IDs and every pre-existing ref/ops business row.

Extend the established setup_maintenance_deploy.py profile mechanism; retain its
single lock, controller ON/freeze/snapshot/OFF, journal and failure containment.
Extract source-promotion/live-proof hooks with unchanged default behavior so the
#171 profile can promote both shared and dedicated Setup to the accepted app SHA.
Do not run the September Controller installer or introduce another orchestrator.

Pin accepted app 439ab237beaae4ac648e7590f824a774969cd84f separately from later
tooling commits. Require app contained in merged main, exact reviewed migration
blobs and both observed old source SHAs. Recheck clean source, ONLINE, all services
including Work Management, backup chain, idle preview and exclusive source lock.
Run detached regression before maintenance. Hold before mutation for any unexpected
site table/function, altered network schema/count, missing source or runtime probe.

Use the three existing canonical candidate SQL files verbatim, in accepted order,
under the separate explicit Production approval. Their historical candidate headers
do not authorize execution independently. Never introduce renamed duplicate schema.
Reuse bootstrap_expertgps, seed_gpx_panels and ingest_linkiq for one initial load;
leave accept_site_sources.py's disposable-only guard intact. No fixture commands,
preview wiring copy, new Directus grants or future incremental ingest interface.

The deployment-only source adapter uses the existing host Python/psycopg2 as root
to reach the container's existing filesystem Unix socket through /proc/<pid>/root.
Discover PID/socket directory read-only; prove current_database=msb,
current_user=msbadmin and inet_client_addr IS NULL before maintenance.
Do not open a TCP bypass, modify HBA, mount a socket or install dependencies.
Re-probe while frozen immediately before source intake. Failure stops fenced.
This path is an implementation of the runbook's local administrator boundary;
the existing controller remains the sole fence authority.

Freeze and snapshot precede schema or source writes. Fingerprint all pre-existing
ref/ops tables plus Directus identity/policy tables; newly created #171 tables are
excluded only by the fixed reviewed table list. Validate read contracts, role
EXECUTE/no broad DML, 240 waypoints/220 tracks, source bindings/archive and immutable
FLW counts, preserving source bytes and the original 27 network records. Journal
each migration and import stage; partial commit or unknown outcome stays fenced
for reviewed recovery. No automatic OFF, inverse SQL or full-database restore.
Promote source only after database validation/preservation passes, then recheck
fence and hashes, controller OFF, exact health and role denial checks. Operator
Production smoke test and actual deployment-log/server closeout follow receipt.

## October 25 Production panel-entry correction — final design

PR319 server deployment passed (report PR319-GIS-20261025T062215Z). Greg began
real panel inventory and found WV-00 / Panel 10 stopped at 38 positions. The old
screen used a 36-position minimum and expanded only to the highest recorded slot.
The final correction is an explicit **Number of slots** field in Panel setup,
not a larger fixed minimum and not a count inferred from amperage.

Persist nullable branch_position_count (1–200) on the existing ref.site_panel.
Suggest 12/18/20/24/30/40/42 while allowing another actual count. The main is
excluded; two-pole breakers occupy two slots. Render 1 through the configured
count, odd left/even right. Empty slots are placeholders, never automatic installed
breakers or circuit rows. Unknown existing counts stay null: show only the occupied
extent and a Set number of slots prompt. Do not claim the occupied extent is the
panel's physical capacity. Block count reduction or breaker placement/movement
that would put an active branch position beyond the configured count. Preserve
all existing panel, breaker, circuit and waypoint identities and assignments.

Use one bounded additive migration, 171_panel_slot_count.sql, and the existing
audited site_power_command. Extend only its panel field allowlist after checking
the deployed function body; retain authorization, revisions, audit and grants.
Enforce occupied-slot bounds on panel and breaker writes, sharing the model
revision lock. No duplicate inventory/schema, source reimport, initial-schema
replay, panel renumbering or data rewrite. Future deployment is DATABASE-CHANGING
and requires the existing maintenance/snapshot procedure after candidate approval.

Group panel identity/ownership, main supply, and branch schedule. Each physical
breaker is one outlined card spanning its occupied rows, containing its circuit
assignment buttons. Avoid duplicate position headings when the breaker designation
already supplies the numbers. Shorten load and affected-endpoint disclosure labels;
retain full incomplete-load, usable-capacity and isolation caveats inside them.
Keep disclosures closed initially so entry controls remain easy to scan.

Owner tint: MSB Owned light blue, City Owned light orange, other/unknown neutral.
Include explicit owner text and a separate selected/focus outline. Save/Add use
shared primary blue; circuit assignment uses a pale blue outlined button;
settings/navigation/Cancel remain neutral. Disabled controls retain role guards
and a distinct disabled appearance. Provide readable dark-theme variants.
No color asserts energized/de-energized, safe, verified, capacity or completed work.

Validate small-panel extent, 40/42-slot entry, multi-pole layout, reload persistence,
occupied-slot shrink/overflow denial, atomicity, audit/role boundaries, ownership
colors in both themes and mobile width. Extend only the existing preview SQL
allowlist and workflow tests. Review on a fresh disposable current-Production clone
with Greg's populated panels; use only the incremental migration, no initial
migrations or GPX/FLW intake. Production remains unchanged by this engineering.

### October 25 follow-up review: ratings, return navigation and action colors

Greg reviewed 70c856ce on a current-Production clone and returned CLEAN EXIT,
port/source lock free. Greg subsequently specified the exact default breaker sizes:
10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150,
175, 200 A. Use this supplied list instead of a custom-size entry. Existing numeric
rated_amps remains authoritative; retain existing saved ratings as additional
numerically sorted, deduplicated choices. Do not silently change unknown or
existing breaker ratings. No new catalog or installed inventory is created.

Return from waypoint/equipment must restore the selected panel, search filter,
disclosure state and scroll position, including browser Back. Use tab-local view
state/URL context, not database fields or an independent navigation system. Provide
an explicit Back to panel action and align screen links with the main content.
Invalid/stale stored context must degrade safely. No external redirect parameter.
Breaker settings and secondary actions use light gray; waypoint/equipment opening
uses a distinct teal navigation treatment; Add/Save retain blue. Dark mode uses
readable equivalent colors. Ownership colors and slot configuration remain intact.

Observed clone dump increased from about 9.8M to 142M after Production source
installation. Retained GPX document/observations/geometry and FLW original results
are plausible contributors, not measured attribution. Add a read-only relation/
evidence-size query; do not delete evidence, vacuum, rewrite, or change retention
based only on dump size. No Production mutation for this investigation.

### October 25 — accepted PR455 incremental Production release

Greg accepted exact application 0fd7fabd48dce287722112405bafb8e3aa65f637,
V0.4.22-panel-navigation, with CLEAN EXIT and requested Production preparation.
PR455 merged at 6a421e47c80bd4e1976a67137fe1686bfa92caac. Fresh read-only
host evidence confirms both live checkouts at 439ab237beaae4ac648e7590f824a774969cd84f,
clean; FieldWiring V0.4.20, Setup V0.3.91, Procedures V0.1.0 healthy; controller
ONLINE, backups replicated, source lock and port available. Slot column absent;
command body MD5 49ed9c2fda6accb89dd9c72966aa4b78 matches migration guard.
Observed inventory: 17 panels, 55 breakers, 92 circuits, 240 waypoints. Counts
are observations, not fixed deployment constraints: legitimate edits may continue.

Use a narrowly scoped panel-release profile of existing setup_maintenance_deploy.py
and committed-byte transport, with one SCP and foreground SSH. No new deployment
or maintenance mechanism. The profile pins accepted application/tree, current live
rollback identities, exact incremental migration and validation blobs, and helper
hashes. Production application source is the accepted SHA, proven merged; tooling
may be a later merged commit. Setup checkout remains unchanged. The initial
PR319 installer and initial migrations/source loads are prohibited for this upgrade.

Before maintenance, repeat live identity/health/backups/baseline gates, acquire
existing deployment and preview-source locks, and run detached FieldWiring and
Procedures regression. Under the existing controller: freeze, stable business-row
fingerprints, validated rollback snapshot, only 171_panel_slot_count.sql,
171_panel_slot_count_validation.sql, preservation equality, shared source promotion,
final frozen proof, OFF and exact health/negative-auth proof. Fingerprints preserve
all ref/ops/lor_snap rows and Directus authority rows; exclude only the new nullable
branch_position_count key from existing panel row projection. Hash each row before
aggregation so immutable source payloads do not form a huge aggregate string.
Do not compare fingerprints across ONLINE edits. Do not infer actual panel counts
from breaker amperage or backfill counts during release.

Failure retains the existing controller fence, snapshot and report for review;
never automatically retry, restore, call OFF, remove source evidence or replay the
initial importer. The wrapper defaults to preflight; deployment requires explicit
-Deploy after authorization. Production remains unchanged during preparation.

Storage evidence: database 413 MB; ops.site_source_observation 111 MB and
ops.linkiq_test 79 MB dominate newly retained source evidence. These are physical
relation sizes, not exact attribution of the compressed 142M dump. No retention
change is part of this release. All source evidence remains preserved.

### October 25 — breaker notes after PR455 deployment

Greg reported PR455 server deployment PASS, report
/home/msbadmin/setup-deployment-reports/PR455-Panels-20261025T084618Z.
Protected browser review found breaker notes appear unsaved and are absent from
the board. The editor initializes existing source_evidence to empty, allowing a
later settings save to overwrite it. Use the existing persisted notes/evidence
field; initialize from the saved breaker and render it as plain text on its card.
An explicit clear may remove the current note; unrelated settings edits must
preserve it. No parallel notes table, new schema or audit rewrite.

Panel14 breaker14 Gate Power and breaker16 Gate Lights can have notes without
waypoints. Panel receptacle circuits2/4 and6/8 likewise need no fabricated panel
waypoint or automatic feed. Keep optional waypoint assignment available and label
it optional; absence of a waypoint is not proof of spare or disconnected hardware.
Test save/reopen/reload/other-setting preservation and no-waypoint breakers.
This source-only correction is a new candidate, not yet approved or deployed.

### October25 review — independent circuit notes

Greg's next PR457 review confirms breaker notes persist and optional waypoints
are useful. Screenshot2 shows Upper Panel GFI's on breaker2/4; breaker6/8 is
cropped, so its Lower Panel GFI's display is not established by that image.
Screenshot4 proves the assignment evidence Notes field cannot save without a
feed change. Add Circuit notes using existing site_power_circuit.description,
loaded and saved independently of waypoint selections through existing audited
circuit commands. Display each leg's notes immediately alongside that circuit.
Keep breaker notes separate, and label feed evidence Assignment correction note.
A circuit-note-only edit must not create feeds, reverify existing feeds, change
other-leg notes, or alter breaker notes. Clearing circuit notes is allowed.
Test no-waypoint and unchanged-waypoint saves, refresh and sibling isolation.
No schema change or migration; continue PR457, acceptance remains pending.

### October25 — approved seasonal breaker execution checklist

Greg confirmed the following operator design after accepting notes saving and
panel-board display in V0.4.24. This records the next engineering scope, not an
implemented feature or Production release approval.

The seasonal-change checklist defaults to active grouped breakers whose known
show-season and off-season targets differ. Setup uses show_desired_state;
takedown/restoration uses restoration_desired_state. ON/ON and OFF/OFF breakers
are omitted from the change list, but remain visible on the full panel board.
Unknown targets appear under Needs configuration and are never silently omitted.

Each listed breaker shows panel identity/location, breaker designation/description,
required state, last recorded state, recording person and observation timestamp.
The control records the physical action already performed: Record ON or Record
OFF; it does not operate equipment. One control covers a grouped multipole breaker.
No waypoint is required. Reuse existing panel GIS identity for map navigation;
missing location remains explicit and does not prevent recording the action.

The panel board shows last recorded state for every breaker, separately from
planned seasonal settings. With no event, show Not recorded; never initialize
actual state from desired state, previous task percentage or an assumption that
work occurred. Retain previous changes in the existing seasonal action/event
history. Preserve correction semantics and order observations deterministically;
older historical entries must not overwrite a newer observation. Display when
the last observation was made, including if it belongs to an earlier season.
Recorded switch position is not electrical-isolation or absence-of-voltage proof.

Within the selected season and setup/restoration phase, a change-list item moves
to Completed only when an applicable recorded action matches that phase's target.
Retain completed items for review. Do not silently count a prior-season event as
current-season completion. Show outstanding and completed counts with their
actual scope; incomplete panel inventory must not imply all park work is captured.

Reusable task57, Turn On Site Breakers, has a crew-reported October9,2026 report:
Crew1,3 hours,3 person-hours,80% complete; remaining access to bathrooms and park
office to turn off outdoor security lights. Preserve this historical report and
percentage. It does not identify completed breakers and cannot backfill individual
states. The checklist covers both ON show power and OFF unwanted lighting; do not
automatically overwrite Setup progress or create another task/reporting system.

Implementation must reuse the existing site_power_action and append-only seasonal
event model, command authorization and audit/revision boundaries. Reconcile any
missing command capability before schema changes; do not create a parallel switch
state table. Test target matrix, unknown states, grouped breakers, no-waypoint
loads, ON/OFF history, corrections, prior-season completion isolation, permissions,
retry/stale requests and panel-map navigation. Production and GIS sources remain
untouched during engineering; prepare a governed disposable candidate for review.


### October 25 — final-test implementation contract

The panelboard uses green **Recorded ON**, red **Recorded OFF**, and gray **Not recorded**, with text labels and actor/time in both themes. Colors represent the latest uncorrected observation, never the desired state. One control operates on a grouped breaker, independent of waypoint membership. A brief impact review precedes recording physical work.

The existing audited `site_power_command` gains an atomic `breaker_state` command. It resolves a reusable breaker/phase observation action and appends a REPORTED event in the existing append-only activity ledger. No second state table or task-progress authority is introduced. Stable request IDs, revision conflicts, actor authorization, impact snapshots, and replay protection remain enforced. Existing custom activities are retained. History is interpreted using the event's captured definition, so editing an action cannot move a historical observation to another breaker or phase.

The checklist is across active panels, with setup/restoration and season selectors and Open, Completed, and Needs configuration views. Equal known targets are omitted. Completion requires the latest uncorrected observation to match the required state AND selected season/phase. Old observations remain visible without claiming current-season completion. Unknown observations supersede old known observations rather than reviving stale ON/OFF. Print uses the selected checklist view. Reusable task 57's October 9 crew report remains unchanged.

Latest operator handoff: reusable preview CLEAN EXIT; port 8898 and GIS source lock available. New engineering and disposable acceptance remain pending; this is not Production deployment authorization.

### October 25 — operator review correction: rapid observations and exception reports

Greg's V0.4.25 disposable review ended CLEAN EXIT. Supersedes the confirmation-box requirement: Record ON/OFF is a single-click observation with no dialog or acknowledgment. Keep authenticated attribution, observed timestamp, immutable history, revision checking, exact retry IDs and grouped impact snapshot; do not manufacture an impact-reviewed acknowledgment. Season mode is labeled ON/OFF (existing SETUP/RESTORATION storage values remain internal); state cards say Season/year/position and person's name, not email. Canonical Directus names are resolved read-only for existing events; original audit identity remains unchanged.

Include 8 in slot suggestions and explicitly accept integer counts 1–200, preserving occupied-slot protections. Test an 8-slot FE-00-style panel through the real editor and database.

Provide visible downloadable PDF status and exception reports, with panel/breaker/description, required and recorded state, last observer/time, season and completion/exception reason. Reports cover ALL active breakers, including unchanged seasonal targets. Explicit exceptions: wrong position, no known recorded position, earlier-season/other-season-mode observation, and unknown required target. Checklist retains change-only workflow; report totals distinguish confirmed, exceptions and missing work without altering task57 or claiming photos were entered as observations. PDF generation is read-only through existing authenticated snapshot access; no second state system. Production and source files remain untouched. New exact disposable candidate required before release.
