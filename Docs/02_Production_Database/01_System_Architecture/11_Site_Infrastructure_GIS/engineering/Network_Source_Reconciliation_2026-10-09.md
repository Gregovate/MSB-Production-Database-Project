# #171 Network source reconciliation — October 9, 2026

| Document control | Value |
|---|---|
| Status | ENGINEERING CANDIDATE; operator review required |
| Owner | Site Infrastructure / GIS, with Network Infrastructure |
| Main baseline | `38f6f9427007470cbc02b3e2d23a97450d4414ba` |
| Implementation path | Existing PR #318, after `a523b5082dba54ec2fd14567aeb520a5a9813f88` |

## Source responsibilities — operator clarification, October 10

These sources have distinct responsibilities, not one blanket ranking:

| Source | Authority / role |
|---|---|
| GPX | Authority for waypoint locations; supplies geographic tracks and recorded installation evidence. |
| LinkIQ | Consumes those waypoint identities for testing; identifies each cable's endpoints, network/spare designation, measured length and test history. It does not establish waypoint coordinates. |
| draw.io | Schematic presentation plus source evidence for switches/other infrastructure and connections absent elsewhere. Drawing positions and line shapes are not GPS geometry or location authority. |
| Database | Eventual consolidation of these distinct facts with shared identities, original provenance and reviewed corrections. |

Start with GPX waypoint locations and reconcile the waypoint references used by
LinkIQ to them. Then check the draw.io presentation against the reconciled
connections and report entry discrepancies to Greg. Do not derive geographic
coordinates, route shapes or geographic distances from schematic layout.
LinkIQ cable length can help assess a GPX track match; it does not authorize
moving authoritative waypoint locations. Preserve original traces and dates.
This clarification narrows earlier "tester-first" wording to cable/test facts;
it never gives the tester authority over waypoint locations.
#171 owns this GIS/reconciliation work within #122's commanding Setup workflow.

## October 10 finding: raw LinkIQ source and consolidation authority

Greg confirmed on 2026-10-10 that the tester cable names identify individual
cables, endpoint to endpoint, including network/spare designation. Draw.io is
hand-entered from these records and should agree; discrepancies must be reported
to Greg with exact object ID, entered values, tester values and proposed correction.
Do not silently rewrite the drawing. The eventual consolidated source of truth is
the PostgreSQL database, with source provenance and reviewed reconciliation.

The supplied `26-10-09-Park-Data.flw` is directly readable SQLite, opened read-only.
Size: 174,149,636 bytes. SHA256:
`75a6b4673c9acf3aa7698fef0617df219a2742aeaebf022daebb7b8a8277b5ef`.
The file reports TesterType=LinkIQ (the conversation previously called it CableIQ).
Tables: Records, RecordData, Admin and 606A. Records contains 470 test rows,
447 distinct literal CableId values, 466 Deleted=NO and four Deleted=YES.
These are record/name counts, not a verified count of physical cables.

Readable fields include CableId, CableIdLong, LengthF, LengthM, TimeSpan,
TestStatus, Deleted, Hash, UUID and TesterType. ResultBrief and RecordData.BinRec
hold binary data; detailed binary results and numeric test-status meanings have
NOT been decoded. Timestamp semantics/timezone still require verification.
A tester timestamp must not automatically become an installation date.
CSV export is unnecessary to access the verified scalar fields. Preserve raw
names and raw values; do not use the zero-padded CableIdLong sorting form as a
human cable name.

Verified source examples (literal CableId and LengthF):

| Tester cable name | Feet |
|---|---:|
| WV 00 to WV 03 AUX-I | 110 |
| WV 04 TO WV-00 | 266 |
| WV-11 TO WV-13 REG | 91 |
| WV-11 TO WV-13 AUX-I | 87 |

The first record supports correcting draw.io object
`Cable_WV-00_WV-03_AuxI` Waypoint_2 from WV-04 to WV-03; report it for Greg's
source correction. The second is a separate tester record and has no explicit
network suffix: do not invent one. The last two prove separately named REG and
AUX-I cables between the same endpoints; shared endpoints are not duplicates.
The draw.io `Cable_WV-11_WV-13_Reg` label/Network conflict still needs
object-to-cable reconciliation before its intended identity is chosen.

Potential stray record: `1000 ft test cat-6 on roll`, 995 feet. Flag it for
operator disposition rather than dropping it. Preserve deleted source records
and repeated test records as evidence; do not automatically import them as active
cables or collapse retests. Identical names alone are not a durable unique key.

Required reconciliation sequence:

1. Use GPX as waypoint-location authority. Reconcile LinkIQ's references to those
   waypoint identities, then check draw.io's schematic references. Retain original
   spellings and confirmed aliases; report missing, ambiguous and conflicting
   references without deriving locations from the tester or schematic.
2. Establish individual cable identity from tester evidence, including endpoints,
   network/spare designation and separate parallel cables. Attach multiple tests
   as history to a reconciled cable; preserve source-file hash and source-row keys.
3. Report draw.io discrepancies with exact source object IDs and both sets of
   values so Greg can correct human entry errors.
4. Link cables to their GPX installation traces and preserve recorded installation
   dates and original geometry/provenance. Greg considers bad traces unlikely;
   inspect naming/matching errors first, without assuming all geometry is perfect.
5. Compare route length in feet with tester-measured cable length to help assess
   waypoint/track alignment. Slack, vertical runs and service loops can differ
   from mapped length; length alone cannot determine a route. Store reviewed
   corrections separately from original recordings and retain EPSG:8158 authority.
6. Consolidate reviewed waypoint/cable/route identities and append-only test
   history in the existing database/Wiring integration, reusing existing IDs.
   The map and schematic should consume reconciled information rather than
   independently assigning network identity.

V0.3.54 is still the earlier draw.io-derived implementation. Its network
assignments are provisional and its automatic dashed "alternative routes"
classification is not supported merely by shared cable-path evidence. Separate
cables may share endpoints/routes. This documentation supersedes that assumption;
the application correction and full three-source reconciliation remain pending.
No raw tester binary has been committed, no source drawing/GPX edited, and no
database import, schema change or Production mutation occurred for this finding.

## Actual source inventory

`Park Network Schematic 2026(8).drawio` SHA256
`e59d67383e735b4bbd77b59f6ec1f6a73dedd1b983d6594a379159d18ace953c`
has 375 object-wrapped edges: 372 structured records with Cable_ID,
Waypoint_1, Waypoint_2 and Network, plus three legacy records. Another 70
bare mxCell edges require review. The earlier object-only extractor omits those
70 edges. Source object IDs and raw attributes are retained in the candidate
cross-reference, including duplicate-looking records; they are not collapsed
into asserted physical cable identities.

The supplied October 9 02:00 compressed SQL has SHA256
`cc2df6a9e1e13045ad05b4b5e75b0341b2a61475b8f4b441833e54c13a243525`.
Read as text without restoration/execution: 155 CREATE TABLE definitions,
PostGIS in public, no dedicated physical cable/network/waypoint mapping/test
history tables. ref.container_endpoint is movement terminology. Reuse existing
controller_id, stage_id, display_id and Wiring consumption paths. lor_network
and management_ip describe controller configuration; they cannot substitute for
physical cable identity. Schema integration/writer/editor remain unimplemented.

## Historical V0.3.54 candidate matching rule — correction pending

V0.3.54 used draw.io as network identity/topology input; this is superseded by
the source-specific responsibilities above. GPX carries route geometry. GPX description text never assigns network membership.
The first V0.3.53 candidate matched only literal two-endpoint track names (11
routes, 67 unresolved). Greg's 23:05 screenshots exposed incomplete AUX-I/INET
highlighting and confusing raw-track versus network search results. That browser
review requires changes; it is not operator acceptance.

V0.3.54 screens existing route geometry against named GPX waypoint positions.
Waypoint names match source endpoint codes directly; literal panel forms such as
PANEL 09 / PANEL-09 and PANEL RA-00 / RA-00 are retained in `waypoint_lookup`.
Confirmed GG-10 → GG-11 and Aux I/Aux-I aliases remain. Original names/attributes
are preserved. Ambiguous duplicate waypoint identities are excluded.

A route segment requires named source endpoints within a 30-ft **screening**
radius and exactly one monotonic draw.io cable-node path for the same network.
Every path node must be within that radius of the original line. All segments of
a multi-segment GPX feature must support the same network before the full feature
can be highlighted. Missing links, conflicting source attributes and multiple
possible node paths remain unresolved. Network identity comes only from draw.io.

Screening uses a local WGS84 distance approximation at park latitude; it does not
transform/persist replacement coordinates. The 30-ft bound is only a candidate
search radius (CC-00 is about 23 ft from the old GPX endpoint). It is not survey
accuracy or a locate/clearance threshold. Existing EPSG:8158 authority and original
browser geometry remain unchanged. These source correspondences require operator
review and must not become accepted current physical topology automatically.

The new source snapshot contains **43 candidate GPX routes, 35 unresolved routes**;
AUX-I has **13 candidate routes and two conflicting cable records**; INET has
**19 candidate routes and 15 records without supported full-route correspondence**.
V0.3.54 highlights GPX features sharing the same source cable-path evidence dashed
as alternatives. That classification is premature and must be corrected; sharing
evidence does not prove that the traces are alternatives.
This is a read-only source consumption snapshot, not a second editable inventory.
Candyland reconstruction still requires geographic validation. A candidate there
does not establish that older route geometry describes the reconstructed cable.

Concrete discrepancies include TC-01 TO PN-01 with Waypoint_2 RA-08,
WV-00 to WV-03 Aux I with Waypoint_2 WV-04, and A5-02A to A5-02B AuxN with
Waypoint_1 A5-04. A5 formatting differences (A5-2A/A5-02A, A5-003/A5-03,
slash versus ampersand combined endpoints) also require explicit reconciliation.
No global spelling correction is made. The AUX-I record
`Cable_WV-00_WV-03_AuxI` cannot resolve the missing WV-00/WV-03 section because its
label/key indicate WV-03 while Waypoint_2 says WV-04. The October 10 tester evidence above identifies the endpoint correction to
report to Greg. `Cable_WV-11_WV-13_Reg` also has a Reg label but Network = Aux I; its
network assignment is held unresolved instead of being counted as a second
confirmed Aux-I cable. Other nonconfirmed Aux spellings are not globally merged.

## Browser behavior

An exact network-name/confirmed-alias query returns the logical network group
only. Thus Aux-I and Aux I each yield one AUX-I result; INET does not also return
Flammables Cabinets. Broader route queries still show **GPX route (source name)**
results. Selecting a raw route or asset clears stale network evidence. Refresh
clears that selection. Network selection opens its evidence without an arbitrary
first-route popup.
Selecting a network highlights every rendered segment of all supported candidate
GPX features, fits their combined bounds, and reveals source cable evidence.
The details list includes unmapped and conflicting records and per-cable Show
cable route buttons. Networks with zero mapped routes remain searchable and
show an explicit unavailable geographic state. Source load failure preserves
ordinary map search. Switching selection or refreshing restores original styles.
No lines bridge missing routes. Common network labels do not assert continuous
physical connectivity. Feet and Speed remain source fields; Speed is not claimed
as throughput, negotiated speed, or a new independently inspected test result.

## Operator-confirmed broader integration facts

Waypoints support multiple infrastructure functions: Outlet Combo includes power
and network; Out Power/LP Power are power-only; some waypoints are network-only.
Lookup should reach shared Wiring/reference records, power circuits, meter and
breaker details, switches/PoE and preserved test history with Show on map.
MSB owns FC-00, ST-00, WW-00, A5-00, CL-00, RA-00, GG-00 and PANEL 42-00;
all remaining park panels are city-owned. MSB pays its eight panels' monthly bills;
city billing was not specified. PANEL 42-00 is GPX w106, type Panel, source comment
“MSB / 2019 New”. Ownership, billing, meter and breaker identity stay separate.
GPX cameras are incomplete; preserve existing entries and defer camera management.

## Resume point

Start with GPX-authoritative waypoint locations and reconcile the October 9
LinkIQ cable/test references to those waypoint identities. Produce the actionable
draw.io schematic discrepancy list, and then correct
PR #318's map matching/classification. The tester source is now available; full
reconciliation and raw-binary decoding have not yet been implemented.
PR #319 (`99a2534aa5bea51645de2de6d255b97d89981bb2`) owns existing CableIQ
validation and is not duplicated or replaced. Next integration must reconcile
source identities and design minimal extensions linked to existing Wiring and
reference tables under #171/#230, preserve append-only retests, and obtain normal
disposable/operator acceptance before Production. No database writer, editable
network records, test ingestion or complete topology is delivered by this slice.

## Coordinated implementation plan and PR audit — October 10, 2026

Status: engineering plan / unresolved integration gates, not implementation or
Production acceptance. Refreshed main: `38f6f9427007470cbc02b3e2d23a97450d4414ba`.
#171 controls this work within commanding #122. Links below are the shared resume
point for concurrent threads; reuse existing PRs rather than duplicating work.

### Additional source responsibilities

Draw.io is schematic presentation, but also supplies switches and other device
inventory/connections absent from other sources. Preserve these objects, source
IDs, attributes and connections; absence from LinkIQ/GPX/LOR is not proof of a
stray device. Associate devices with a GPX waypoint only where supported; retain
unknown geographic location explicitly. Schematic coordinates never become GPS.

LOR/V7 owns expected show network/UID/channel/universe topology.
[Controller Inventory's current programmed configuration contract](../../08_Controller_Inventory/Controller_Current_Programmed_Configuration_Contract_2026-08-31.md)
separately owns physical controller identity and recorded programmed settings.
Reuse controller_id and existing Display assignments; Network/UID/IP are mutable
and not globally unique physical keys. Compare expected LOR usage, recorded
controller configuration and confirmed physical connections without conflating
them. LinkIQ qualification is not configured or negotiated network speed.

Greg reports all infrastructure icons are created and integration is running in
another thread. Do not recreate artwork. No separate icon PR was identified in
this repository's open-PR inventory during this audit. Existing PR #318 contains
four Container SVGs and existing type/symbol mappings; that does not prove the
other thread's complete icon set is integrated. Required handoff: exact repo,
branch/PR/SHA, asset paths, type-to-icon mapping and acceptance state. Icon artwork
does not assign physical identity, geographic location or confirmed load status.

### Existing work and dependencies

| Owner / PR | Verified repository state | Next action / integration boundary |
|---|---|---|
| [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171), [#318](https://github.com/Gregovate/MSB-Production-Database-Project/pull/318) | Open map/search candidate; contains current main; V0.3.54 app still has provisional draw.io inference | Consume reviewed cable/waypoint/device relationships, correct unsupported alternative classification, implement URL focus and shared rendering contract. No authoritative-network acceptance yet. |
| [#319](https://github.com/Gregovate/MSB-Production-Database-Project/pull/319) | Draft CSV validator/source inventory; original head 99a2534; 134 main commits absent at audit | Preserve CSV adapter; extend this existing import work with read-only FLW adapter and reviewed manifests. Correct source authority; reconcile current main before implementation. No database loader exists. |
| [#230](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230) | Existing governed reference-management owner, with #171 infrastructure requirements | Reuse its maintenance boundaries for reviewed identities/edits; design only demonstrated schema gaps. No new parallel reference editor. |
| [#175](https://github.com/Gregovate/MSB-Production-Database-Project/issues/175), [#308](https://github.com/Gregovate/MSB-Production-Database-Project/pull/308) | #175 closed for accepted core; draft #308 still open, conflicts with main; 154 main commits absent | Pending location wording/Home visibility work remains tracked under #122 DBG-2026-001. Reconcile renderer changes with #309; issue closure is not follow-up acceptance. |
| [#88](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88), [#309](https://github.com/Gregovate/MSB-Production-Database-Project/pull/309) | Draft guided stops, conflicts with main; 154 main commits absent; separate report slice already has deployment evidence | Own movement/contents truth. Keep unfinished guided stops, historical repair and migration070 out of GIS integration unless separately accepted. Preserve inferred-location provenance in shared renderer. |
| [#321](https://github.com/Gregovate/MSB-Production-Database-Project/pull/321) | Draft links only; head 6bd76eb; 134 main commits absent; no recorded tests | Depends on #318 consuming container_id URL parameter. Static task-specific map inset remains missing and must stay explicit in this existing coversheet work. |
| [#229](https://github.com/Gregovate/MSB-Production-Database-Project/pull/229) | Old open reconnaissance-doc PR, head cc5f65d; 2090 main commits absent | Compare its unique GIS README findings against current #318 before merge/closure. Do not blindly merge old README over current authority. |

Behind counts are commit-ancestry counts, not counts of missing features. #308
and #309 both modify nextLocationText/nextLocationMarkup in setup_next_pass.js;
#321 modifies the task asset list in that same file. Preserve all intended
behaviors during deliberate reconciliation, not whole-file replacement.
#318 and #309 also touch movement API/report and shared release files.
None of these overlaps proves the other chat is hung; remote repository evidence
cannot reveal an in-progress chat's uncommitted work or runtime state.

### Work order and acceptance gates

1. **Source reconciliation (#171 / #319):** inventory GPX-authoritative waypoint
   names/locations; extract FLW cable/test evidence read-only; preserve draw.io
   device inventory and schematic connections. Produce exact matches, confirmed
   aliases, unresolved references, candidate stray cables and draw.io corrections.
   Preserve shared trench/HV route evidence: GPX need not have one NET track per
   cable. Existing confirmed aliases/co-location facts in #171 remain applicable.
2. **Physical route association (#171 / #318):** associate individual cables with
   existing GPX routes (many cables may share a route), installation history and
   length comparison. Record unresolved geometry; never bridge a missing section
   by guess or derive geography from the schematic. Correct V0.3.54 assumptions.
3. **LOR integration (#171 with existing Wiring/Controller authorities):** inspect
   current approved LOR snapshot and controller records, resolve expected network
   usage versus programmed settings, then link supported physical connections.
   Report unmatched/conflicting cases. Name equality alone does not establish
   controller attachment to a cable/switch.
4. **Database consolidation (#171 / #230 / #319):** after existing-object inventory,
   define minimal shared waypoint/cable/device/route/source/test relationships,
   explicit reviewed matches, repeat-import idempotency and append-only retests.
   Prove importer/edits on a disposable database before Production approval.
   Reference edits retain versions/audit; #88 observations remain evidence.
5. **Map and schematic consumption (#318 plus icon-thread handoff):** one identity
   can open geographic, schematic and history views. Keep schematic layout
   separate from GPX geometry. Reuse supplied icon assets and stable type mapping.
   Deliver incrementally; do not claim a read-only overlay supplies the full editor.
6. **Setup handoff (#308 / #309 / #321):** first reconcile current-location
   presentation against accepted #88 state; #318 must select a Container from
   /setup/locate/?container_id=<permanent ID> after asset loading, show missing
   location explicitly, and respect protected access. Then #321 consumes it.
   Validate C095, an unlocated Container and colocated assets. Printed coversheet
   also needs the already-requested static task-specific map inset with nearby
   references, Container numbers, legend and observation time; a hyperlink alone
   does not fulfill paper/offline use. Use the common #171 renderer, not a second
   set of geometry rules.
7. **Integrated acceptance and closeout (#122):** reconcile each touched branch
   with current main, run relevant regressions on the combined exact candidate,
   use current-Production disposable clone/browser review on registered 8898
   after previous CLEAN EXIT, and preserve test/report/SHA evidence. Production
   requires the governing runbook and explicit authorization. Merge/ancestry and
   deployed evidence are separate; preserve unrelated worktrees and live behavior.

Parallel work is possible: icon packaging and source reconciliation can proceed
independently. #321 URL integration needs map focus, not completion of every cable
test decoder; it must not wait unnecessarily for all infrastructure editing.
No raw binary decoding is required merely to reconcile the verified FLW scalar
fields. Keep unknown status/time semantics explicit until independently decoded.

### Concurrent-thread checkpoint

Before the next code edit, each active thread should read this plan and post its
exact branch/head, changed files, remaining gate and dependency to its existing
PR. One thread owns each shared-file change at a time; reconcile heads before a
second thread edits that file. This is coordination guidance, not a claim that a
message here interrupts another running chat. The unresolved icon-thread identity
must be supplied or recorded before integrating its unpublished work.

## Direct FLW ingestion and cross-reference investigation — October 10, 07:11 CDT

Greg clarifies that the last CSV was exported from the SQLite-backed tester file.
CSV export is not a required operator step or a prerequisite for continuing:
use the FLW directly, retain original source evidence and report unresolved
records. Earlier cross-thread comments requesting the CSV as a blocking input
are superseded by this clarification. Existing CSV support can remain for
historical inputs.

Screenshot image(20261010-121002).png shows LinkWare PC with the supplied FLW,
a blank Info column and 463 records in the selected view. The database has
470 raw Records rows (466 nondeleted); the selected-view total is not yet
reconciled with raw totals. Do not equate a UI view count with entire-file count
or silently remove rows to force equality.

Greg proposes using the blank Info field as the MSB/tester cross-reference.
Fluke's LinkWare PC documentation says Info displays icons for optional plot
data or comments; a note icon indicates a note entered in Record Properties.
Thus the visible Info column is not established as an editable text-ID field.
Reference:
https://www.flukenetworks.com/datacom-cabling/copper-testing/LinkWare-Cable-Test-Management-Software

Read-only source inspection: all 470 InfoVector values are integer 0; Notes,
User, Service and OutletId are empty strings in all 470 rows. Records also has
UUID values. A blank field name alone does not prove supported application or
tester semantics; do not write an ID into InfoVector or alter binary records.

Candidate design: retain a stable MSB physical cable ID distinct from cable name
and individual test identity. A supported Record Properties note may carry a
namespaced reference such as MSB-CABLE:<id>, pending verification. Keep the
database-side source/test-to-cable mapping authoritative and preserve existing
human notes if a tag is added. UUID durability across save/export/reimport must
be checked before relying on it as the sole test key.

Next bounded experiment: on a disposable FLW copy, use LinkWare Record Properties
to enter a unique test note, save/reopen, and compare SQLite fields to locate its
representation. Then independently verify whether that metadata can be entered
on/transferred to the LinkIQ device and survives a new test/import. A LinkWare PC
note is not proof of bidirectional device support. Do not require device writeback
for read-only FLW ingestion; it is a separate integration improvement. No FLW
writes, device changes or database import performed during this investigation.

## LinkWare property save/readback result — October 10, 07:25 CDT

Read-only comparison of original FLW (SHA256 75a6b4673c9acf3aa7698fef0617df219a2742aeaebf022daebb7b8a8277b5ef)
and supplied 26-10-09-Park-Data-roundtrip-test.flw
(SHA256 9afe232a7efdd4ea9e64682af22476d1eb4a97915b7c826d5d3d9b97c4c28f21):
both 174,149,636 bytes; SQLite quick_check OK. All 470 Records UUIDs unique and
unchanged; no added/removed rows. This verifies UUID stability for this edit/save,
not universal cross-import/retest identity.

| Exact CableId in saved file | SQLite field | Before | After |
|---|---|---|---|
| WV 03 TO WV 05 AUX-I | Notes | empty | MSB roundtrip test 2026-10-10 |
| WV 03 TO WV 05 AUX-I | Faceplate | empty | WV-03 |
| WV-03 TO WV-05 AUX-I | OutletId | empty | WV-03 |
| WV-03 TO WV-05 REG | OutletId | empty | WV-03 |

Thus the multiple WV-03 property edits landed in two different columns:
Faceplate on one test, OutletId on two others. Preserve this distinction.
Notes is confirmed directly readable after a supported LinkWare property edit.
InfoVector remained 0 even on the edited record; do not infer note absence from it.

The saved file also carries prior/source cleanup relative to the originally
uploaded baseline: 46 CableId changes with 46 CableIdLong changes and three
Deleted NO -> YES changes. Newly marked deleted: 1000 ft test cat-6 on roll,
A5-00 TO BELLS REG TEMP, and A5-00 TO BELLS REG TEMQ. Result: 463 nondeleted,
seven deleted, 470 total records. This explains the screenshot's 463 count for
this saved file; the earlier raw snapshot had 466 nondeleted. Do not describe
these extra changes as side effects of the note or assume the note was the only
difference. This direct comparison supersedes unverified prior CSV edit counts.

All other Records fields, including lengths, statuses, timestamps, Hash, UUID
and ResultBrief, are unchanged. RecordData (470 rows, including binary results),
606A (two rows) and Admin (one row) have identical row multisets. Schema not
changed by this comparison; neither source file was modified.

Outcome: LinkWare PC property edit -> saved FLW -> MSB SQLite readback PASS for
the stated note/fields. Notes can carry cross-reference text at the PC-file level;
permanent field choice and device round-trip are still separate decisions/tests.
Use the newer file's corrected metadata as source evidence while retaining the
original snapshot, and exclude the test note from real cable identity assignment.
