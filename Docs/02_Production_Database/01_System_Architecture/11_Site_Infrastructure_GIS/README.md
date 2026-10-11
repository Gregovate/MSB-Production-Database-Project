# Site Infrastructure / GIS

This subsystem documents permanent physical-site identities, location history, power/site infrastructure relationships, and PostgreSQL integration of MSB GIS/GPS data.

## Icon artwork maintenance — new normal operator workflow (#171)

For updates to GIS/ExpertGPS **artwork**, use the repository-controlled [MSB Icon Library Manager](../../../../Database/EngineeringTools/README-Icon-Library-Manager.md) via its **one-time-installed Windows desktop shortcut**. Edit artwork under G: `MSB GIS\\Symbols\\Masters`, save approved Plain SVG output under sibling `Plain`, then use the manager's **Check and preview icons** and **Save approved PNG changes** controls. It discovers all icons dynamically; **maximum canvas 32 px wide and 32 px high**, with smaller/rectangular dimensions allowed. It rejects wrong units (mm, etc.), Inkscape metadata accidentally retained in Plain, missing resources, oversized or incorrect PNG exports, and conflicting destination filenames. It backs up changed PNGs and keeps hash receipts under shared `Symbols\\release-history`. The canonical derived output is `Symbols\\png` — no more routine ZIP handoffs through Downloads.

**Source/master distinction remains intentional:** multiple Plain icons can come from one layered master (LP-Combo), so an operator selects the desired layers in Inkscape; the manager does **not** guess them. ExpertGPS local copies, GPX type/URLs, Synology/web assets, browser markers and draw.io schematic/library content are **separate release gates**, not synchronized automatically by the PNG update. The desktop GUI is implemented and disposable engine/integration tests have passed, but first-run Windows/G: acceptance is still pending.

## GIS data authority and editing — operator reaffirmation, October 11, 2026

**Requirement authority: Greg, 2026-10-11 16:17 America/Chicago. Implementation
and Production cutover are not established by this documentation.** This section
clarifies the required workflow from today forward; historical GPX-first
stopgaps below do not authorize continued maintenance of competing masters.

| Subject | Authority and required flow |
|---|---|
| Waypoint identities and maintained reference data | **PostgreSQL is the authority.** Managers need a usable governed waypoint editor. Correct once in the database; map and downstream consumers use the same accepted revision. |
| ExpertGPS waypoints/tracks | Export maintained database data to GPX for ExpertGPS waypoint/track adjustment. Reconcile changes back into PostgreSQL against stable IDs and the exported baseline, with explicit conflicts and retained provenance. ExpertGPS is a geometry-editing tool, not an independent competing master. |
| Cable tests and evidence of cables between waypoints | **LinkIQ/LinkWare FLW is the authority for test data and evidence of how many cables connect waypoints.** The supplied FLW is SQLite. Import one-way and preserve original tests. Multiple appearances/retests of the same cable are not automatically additional physical cables; retain ambiguity explicitly. **Corrections cannot be pushed back to the tester.** |
| Park draw.io schematic | Contains **existing keys** used to build an understandable **park network schematic only**. Historically used to record test data; not every entity is converted to structured XML data. Preserve/reuse keys, unconverted entities and operator layout; update reviewed bound network objects from maintained DB data. Schematic coordinates are presentation, not geographic positions. |
| Panels, circuits and power waypoints | Authorized **Production Crew** need to add/maintain circuits within existing panels and link existing power waypoints. Maintain which circuits must be turned on/off for show season and restoration. Managers maintain waypoint identity/position; crew circuit links do not require waypoint-edit permission. Crew meter-ID maintenance remains permitted by the recovered role clarification. |

Track priorities already documented on #171 are **NET, PRI and HV**; preserve
other tracks. Multiple cables may share a reviewed geographic route; do not
duplicate traces for every cable or infer cable/electrical identity from overlap.
**Operator clarification, October 11 at 16:21 America/Chicago:** the track
names have **not** been updated to the corrected waypoint names. The tracks
themselves (their geometry) have **not changed**, per Greg. This is an explicit
remaining reconciliation task from the missing engineering conversation, not a
request to redraw, move or regenerate surveyed traces. Preserve original track
names as provenance; reconcile maintained names and endpoint references against
the corrected authoritative waypoint identities with review of ambiguous matches.
Prioritize NET/PRI/HV as already directed in #171.

**Multiple tracks may share the same waypoint.** A waypoint is not exclusively
owned by one track; do not impose uniqueness of waypoint usage across tracks.
Keep distinct track identities and geometries even when they share one or both
endpoints. Shared waypoints alone do not prove tracks are duplicates or share the
same physical route. This is separate from multiple physical cables sharing one
reviewed route. A naming correction must not silently alter geometry or merge
tracks. The unchanged-geometry statement is operator-confirmed; independent
old/new geometry comparison has not been performed in this recovery.

Keep reference action definitions separate from seasonal execution/completion
evidence under #122. Existing map/search, #230 editing and mandatory offline
reference acceptance remain the required end-to-end outcome.

### Required delivery: import, maintained editing, GPX export

Greg reaffirmed on October 11 at 16:22 America/Chicago that the work includes
**getting the data into PostgreSQL, making it editable going forward, and the
ability to export back to GPX**. Track-name reconciliation alone is not delivery.

**Two-source integration, not two independent maintained datasets:** Greg
clarified at 16:22 America/Chicago that we are merging data from two sources
into one. Integrate **GPX waypoint/track reference data** and **LinkIQ FLW
cable/test data** into one coherent PostgreSQL model, linking cable/test evidence
to the maintained waypoint identities and reviewed route relationships. Separate
source provenance and test history remain necessary, but disconnected import
tables or two viewers are not the intended outcome. PostgreSQL is the maintained
waypoint authority; LinkIQ remains the origin/authority for test evidence and
cable-count evidence. Preserve repeated-test versus distinct-cable distinctions.
The draw.io file contains existing keys used to build an understandable schematic
of the **park network only** (operator clarification, October 11 at 16:24).
Preserve and reuse those keys when binding maintained network records to schematic
entities. Not every entity has been converted to structured XML data, so retain
unconverted content and layout. Do not assume the keys' exact field names or
uniqueness without inspecting their definitions. This is a network schematic,
not a geographic editor, power-circuit editor or third competing maintenance master.
GPX export is a projection of the integrated database's geographic records;
it must not imply tester writeback.

Acceptance must demonstrate the complete usable workflow:
1. Import the supplied corrected waypoint/track reference data and LinkIQ test
   evidence into governed PostgreSQL records, preserving source provenance,
   stable identity, unresolved relationships and immutable original tests.
   Reconcile structured draw.io evidence without dropping unconverted entities.
2. Edit maintained reference data through the authorized application: Managers
   maintain waypoints; Production Crew maintain panel/circuit relationships and
   seasonal on/off designations under the established field permissions.
   Accepted changes must be reflected in the existing map/search.
3. Export the current accepted PostgreSQL waypoint/track data as a usable GPX
   file for ExpertGPS, preserving required labels, types/icons, geometry and
   source extensions. Open and verify the exported file in ExpertGPS.
4. Reconcile subsequent ExpertGPS waypoint/track adjustments back into
   PostgreSQL with stable identities, baseline version checks and explicit
   conflicts. Repeated imports must not duplicate identities or overwrite
   accepted database edits silently.

Record actual import, edit and export evidence separately. A schema-only test,
read-only extraction, corrected static map or engineering JSON projection does
not establish this end-to-end acceptance. Production execution remains subject
to #122 and the governing runbook; these requirements do not claim deployment.

### Fresh attachment evidence — read-only inspection

These are upload filenames, not new canonical Shared Drive names. Greg reports
the GPX waypoints were corrected last night and FLW cleaned up. File inspection
establishes bytes and structure, not the correctness of every relationship.

| Uploaded source | Bytes | SHA-256 |
|---|---:|---|
| 2026_msb_FRESH_START_CLEANED_2026-10-06(20261011-211351).gpx | 408440 | a4e48a8938a6e3e889065df74d6140b95e8097d76cd53c0d4dbbce1fb591e0af |
| LinkIQ Data Import for DB with corrected names(7).flw | 253149212 | e76d39179da99bb74ed8e2af7f4e555a71ff530cae58bdb0015e770677a3ef5e |
| Park Network Schematic 2026(20261011-211438).drawio | 1658546 | 65d7607485e526e4d058b4ce997a24f2fe53a731b4f52817dcd44233e420a0a8 |

Fresh GPX: 233 waypoints and 181 tracks; track-name prefixes NET 78, PRI 15,
HV 70, other 18. Its hash differs from the earlier baseline
3272269d493131f0b2e401013ac7f32dc55b598ebf3e7e53d6ab3fd9ec7e2cea.
**Do not reuse the earlier GPX hash as approval for this new file.** Greg confirmed at 16:19 America/Chicago that this GPX was updated by his
icon work this morning. This is operator-confirmed provenance for the new file,
not evidence of a waypoint-correction regression. Semantic differences have not
yet been compared; do not claim that every changed byte is icon-only or that
coordinates/track geometry are unchanged without comparison. FLW and drawing hashes match the earlier
recorded source baseline exactly. FLW was opened SQLite read-only; tables Records,
606A, Admin and RecordData are present. Drawing parses as one diagram, 463 object
elements and 743 mxCell elements; these raw structural counts do not classify
which entities are converted or prove complete database bindings.

### Recovery and repository status

[Recovery index on #171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171#issuecomment-6113744285)
records partial recovery of the inaccessible morning GIS DATA EDITING conversation,
with cross-references in #122 and #230. The Icon Library Manager belongs to a
separate thread. Neither the later shared-route checkpoint nor this short
reaffirmation captures the complete missing engineering conversation.

The operator recalls #319 as merged for waypoint correction. GitHub checked during
this recovery reports #319 draft/open at
384ee47ea8cc90c74d5cf12f58213bc891808296; #352 is the separately merged source-map
correction, with operator Production acceptance recorded in #171. Preserve this
numbering discrepancy without asking the operator to repeat the accepted map fix.
Current main baseline for this documentation is
04de9cfa94e2ff4f641130fdbbacfff9c1c56aca.

The existing draft #319 carries detailed controlled
[editor/offline acceptance requirements](https://github.com/Gregovate/MSB-Production-Database-Project/blob/384ee47ea8cc90c74d5cf12f58213bc891808296/Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/Park_Map_Current_State_Offline_Editor_Gap_2026-10-11.md)
and the
[source synchronization contract](https://github.com/Gregovate/MSB-Production-Database-Project/blob/384ee47ea8cc90c74d5cf12f58213bc891808296/Database/EngineeringTools/Site_Source_Synchronization_Contract.md).
Read those before continuation; reconcile actual editor/API/import implementation
and the changed GPX before any mutation. Do not equate a source-only map correction
with removal of embedded snapshots or completed database-backed editing.

Every new decision, confirmed discovery, source revision, acceptance result and
resume point must be recorded during work in its responsible controlled document
and linked owning issue. Issue comments alone do not replace controlled engineering
files. No source overwrite, database migration, runtime deployment or claim of
editor completion is authorized or performed by this documentation update.

## Required reference-data editing authority — #171 / #230

Operator decision, 2026-10-10: the MSB database-backed application will be the
normal editor and source of truth for maintained infrastructure reference data.
This is required scope of unfinished [#230 Reference Data Manager](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230),
coordinated with [#171 GIS/infrastructure](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171)
under commanding [#122 Setup](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122).

- Maintain permanent waypoints, names/aliases, reference geometry, tracks,
  physical cables/endpoints, networks, switches/devices, reference classifications
  and type/icon mappings in governed `ref` tables and relationships. Reuse existing
  identities and objects; exact table names/DDL follow current-schema inventory.
- #171 owns spatial/source reconciliation and coordinate rules. #230 owns the
  governed reference-maintenance interface, including map-based reference edits.
  Map, schematic and Wiring views consume the same maintained records.
- Names, waypoint positions, track geometry and device/cable relationships must
  be editable through authorized application actions with validation, actor/time
  audit and retained prior versions. A read-only import/archive is insufficient.
- Schematic layout is separate presentation state; moving a schematic symbol
  must not move geographic coordinates. Reuse supplied icon assets rather than
  recreate artwork; editable type/icon references do not change physical identity.
- GPX is the authoritative location source during initial reconciliation and
  transition. After accepted migration/editor cutover, database reference records
  become maintenance authority; GPX/draw.io are source evidence or controlled
  interchange/presentation outputs. Do not silently maintain competing masters.
- Keep original GPX/FLW/draw.io provenance, test results and #88 seasonal movement
  observations separate from editable reference facts. Declaring reference data
  in `ref` does not put all test/event history there or make evidence overwriteable.
  LOR remains authoritative for expected show wiring configuration.
- Correct reference identity once. Routine workflow is download FLW -> process
  new/updated test evidence -> done. Preserve approved corrections/aliases,
  skip already-imported tests, append retests and surface only new/ambiguous
  matches. Routine work requires neither CSV export nor tester writeback.
- #230 remains unfinished for this integration until reference editing and
  shared consumption are implemented and accepted. Existing map rendering is
  preserved while this is completed. This decision authorizes documentation and
  design direction, not an unreviewed Production migration or source cutover.

## Required panel, circuit and seasonal power records — #171 / #230 / #122

Operator requirement, October 10, 2026: capture power information currently held
in people's heads or scattered lists as maintained, searchable reference data.
The map and seasonal work lists must consume the same records.

### Maintained reference facts

- Panel permanent identity, readable panel identification/label, geographic
  waypoint/location, ownership and supporting photos/source documents.
- Each panel's breaker/circuit identification, label and applicable ratings or
  pole/ganged-device information when documented. A breaker number is scoped to
  its panel; do not treat it as a park-wide identifier.
- Explicit feed relationships from panel/circuit through downstream equipment
  to the waypoints, outlets, light poles and other loads it supplies. Support
  intermediate devices and multiple documented feeds; do not force one upstream
  breaker when the evidence does not establish that.
- LP fuse/disconnect identification and the documented seasonal action required
  for that specific pole. Identify utility-owned poles by the utility's asset
  identification as well as the MSB waypoint, where both exist.
- Responsible owner/party (including Alliant), source evidence, verification
  status, verifier/date and effective/change history for feed and device facts.
  Unknown and conflicting relationships remain explicit. GPX proximity, track
  appearance and network-test data cannot establish electrical feed identity.

These belong in governed reference relationships edited through #230, using
existing site/equipment identities after current-schema reconciliation. Exact
DDL and additional table names are not prescribed by this requirement.

### Map behavior

Clicking a waypoint such as FE-00 must show its documented upstream panel
identification and breaker/circuit designation, intermediate fuse/disconnect
information, and other downstream waypoints affected by that circuit. Show the
recorded service-isolation information with provenance and verification status.
No actual FE-00 feed assignment has been supplied here and none is inferred.
A map record or completed seasonal task is not proof of present de-energization;
service verification remains a separate field procedure/event.

### Seasonal activity lists

Maintain reusable action definitions with the equipment/circuit affected,
seasonal phase (show setup, operation where applicable, teardown/restoration),
desired state, responsible party, prerequisites and linked instructions. Provide
lists grouped/filterable by activity, panel, area, waypoint and responsible party:

- turn off designated lights;
- remove the specified LP fuses;
- request Alliant to turn off its identified light poles;
- turn on specified circuits at identified panels for the show;
- restore documented normal operation after the season, including corresponding
  fuse/light/circuit restoration tasks where applicable.

#122 Setup owns seasonal work instances, assignment and completion evidence;
reference records own enduring equipment/feed relationships and action templates.
Keep planned/desired state, last reported state and actual verified field state
separate. Utility request submitted and utility work confirmed complete are
separate statuses. Retain who/when/evidence, exceptions and blocked dependencies.
Do not turn annual completion into a permanent reference fact or overwrite prior
seasons when a reference mapping is corrected.

### Editing ownership — operator clarification, October 10

- Production crew owns and must be able to update season-specific operational
  records: activity progress/completion, observed or reported seasonal state,
  exceptions and supporting evidence. Use authorized Production crew roles;
  routine seasonal updates must not require Manager intervention.
- Production crew must also be able to identify and record panel/circuit/breaker
  information and assign existing waypoints to the circuits that feed them,
  including correcting those assignments through the governed application.
  These maintained circuit/feed relationships are reference facts, not merely
  seasonal notes; their editing is explicitly permitted to authorized crew.
  Routine circuit identification and waypoint-to-circuit assignment must not
  require Manager intervention. Record source and verification status explicitly.
- Managers currently maintain waypoint records themselves: create/rename/retire
  waypoint identities and edit geographic coordinates/reference geometry.
  Assigning an existing waypoint to a circuit does not change its identity or GPS
  position and is a separate permission from waypoint maintenance.
- Direct waypoint-record/coordinate maintenance by Production crew is a possible
  future delegated permission, not current authorization. Crew may report
  waypoint identity/position discrepancies for Manager correction now.
- Do not interpret Manager waypoint maintenance as a blanket Manager-only rule
  for circuit/feed editing. Other reference-edit permissions remain governed by
  #230's field/action policy rather than inferred from this waypoint boundary.
- Preserve actor/time attribution and prior values. Seasonal observations or task
  completion do not automatically promote a reference mapping to verified status.

### Future incomplete-record editing and panel detail — October 10 examples

Deferred by Greg explicitly: not an implementation request for today.

- A5-Church screenshot shows Type OUT-Combo, Comment "New 2025" and GPX source
  time 2026-08-28T16:56:31Z. Provide a future way to update descriptive metadata
  or record additional knowledge before all structured reference fields are
  available/populated. Allow partial saves with explicit unknown values and
  attributed notes/source evidence; do not require invented placeholders.
- Preserve original imported description/comment/time as provenance separately
  from maintained metadata and subsequent edits. GPX source time is not an
  established installation date or the date a crew verified the equipment.
- A5-00 screenshot shows a Panel with repeated Description/Comment "MSB Owned
  Meter ID:" and no meter number. The editor needs structured equipment ownership
  (distinct from editing responsibility), panel identification, meter identifier(s),
  and circuit rows with breaker/circuit numbers, assigned waypoints/loads, and
  desired On/Off state for both show season and off-season. Unknown meter/circuit
  values must remain visibly unknown and must not prevent capturing known facts.
- Model meter/panel relationships according to evidence; do not assume every
  panel has its own meter or extract an empty "Meter ID:" label as an identifier.
  Retain the current MSB ownership statement as source evidence for reconciliation.
- Circuit rows must support crew editing/waypoint assignment under the ownership
  rules above. Managers maintain waypoint identities/coordinates. Desired seasonal
  state remains separate from reported/verified actual state and completed actions.
- When notes are reconciled into structured fields, retain their source/history
  and identify unresolved conflicts. Avoid competing free-text and structured
  authorities or silently discarding information once fields are populated.

### OUT-Combo network and circuit assignments — October 10 clarification

An OUT-Combo waypoint must expose both its assigned networks (multiple allowed)
and its supplying electrical circuit, identified by panel plus breaker/circuit.
These are separate relationships, not competing values in one type/category field.

- Waypoint-to-network assignment is many-to-many: a waypoint can carry several
  networks, and each network can occur at several waypoints. Maintain linked
  network identities through a multi-select/relationship editor, not comma-separated
  names or one network column. Preserve assignment evidence and physical cable
  relationships separately; assignment alone does not prove cable continuity.
- A circuit can feed multiple waypoints. Assign existing waypoints to the shared
  circuit record; do not duplicate a circuit per waypoint or make circuit assignment
  unique across waypoints. The normal OUT-Combo view shows its supplying circuit;
  unknown or conflicting feeds stay explicit under the existing feed-evidence rules.
- Clicking an OUT-Combo shows all assigned networks plus its upstream panel and
  breaker/circuit. Opening that circuit shows every assigned waypoint/load. Network
  selection can identify assigned waypoint membership separately from matched GPX
  cable-route evidence; lack of test evidence must not erase a maintained assignment.
- Crew circuit identification/assignment permission remains as specified above.
  These are deferred reference-editor/data-model requirements, not changes to the
  current read-only map snapshot or authorization to invent source assignments.

### Acceptance and source collection

Collect existing lists, panel schedules/photos, pole labels and knowledgeable
operator input, reconcile them against waypoint identities, and flag gaps for
verification. Record contributions immediately with their source rather than
leaving them in chat. Review before presenting a feed as verified.

Acceptance requires waypoint-to-panel/circuit lookup and reverse circuit-to-load
lookup, explicit unresolved feeds, LP fuse actions, an Alliant action list, and
season-specific activation/restoration lists generated from the same maintained
data. This is required unfinished #230 scope coordinated under #171 and #122;
the current read-only map candidate does not yet implement these power records.

## Current State

Substantial historical field/site information exists outside PostgreSQL, including GPX data going back to at least 2015, waypoints and tracks, receptacles, network tracks, power tracks, utility meters, distribution panels, circuit identifiers, and seasonal energization requirements.

Field collection uses a Garmin GPSMAP 66sr. ExpertGPS and county aerial imagery are used for validation/refinement.

Production PostgreSQL has PostGIS/geospatial capability available, but no accepted Setup/Deployment operational GIS workflow is currently using it. Before schema or application changes, verify the exact installed extension/version and existing geometry/geography objects rather than assuming how PostGIS is configured.

## Coordinate-System Contract

The working coordinate reference is:

`NAD83 HARN WISCRS Sheboygan County Feet (USft)`

This contract must be preserved when historical or new field data is integrated.

Browser/mobile device GPS normally arrives as latitude/longitude in a different coordinate reference. Any operational Setup workflow must explicitly transform/normalize that device input rather than silently mixing coordinate systems.

## 2026 Launch Reference Maintenance Stopgap

The launch Record Location screen needs a small trusted known-reference set before the long-term #171 GIS maintenance workflow exists.

Until that maintenance/import path is implemented, the accepted launch stopgap is:

```text
ExpertGPS / Garmin authoritative waypoint editing
    -> EPSG:8158 Easting/Northing retained as source authority
    -> deliberate EPSG:8158 -> WGS84 transform
    -> versioned Setup/Application/setup_location_references.json
    -> Record Location known-reference / nearest-reference UI
```

Do not ask the operator to reformat ExpertGPS output into latitude/longitude manually. ExpertGPS exports in the established MSB projected CRS are valid source evidence.

The curated Setup reference file is **not** a replacement GIS database. It exists so launch can use known references while preserving provenance and coordinate authority.

Perform Work's #175 Current Location candidate also consumes this exact versioned
set to describe recorded effective movement coordinates with a nearest waypoint
name/distance. It preserves the raw observation and confirmed named-location
precedence. This is derived presentation, not a new Stage assignment, reference
edit, historical rewrite or claim that the asset is placed at the anchor.
See [the Current Location contract](../12_Setup_and_Deployment/engineering/Setup_Task_Supporting_Information_Contract_2026-09-11.md#effective-current-location--175--dbg-2026-001).

On 2026-10-03 the operator supplied an ExpertGPS correction/export that:

- moved `15-Church-Bells-CH` to the corrected map position; and
- added `15-Church-ParkingLot` as an intentional operational unload/drop reference.

Those source EPSG:8158 coordinates are retained with the transformed WGS84 values used by the browser. Future field observations may improve ranking/operational understanding but must not silently overwrite these curated reference anchors.

A maintainable reference editor/import process is required joint #171/#230 work under the rule above.

## Waypoint Type / Layer Classification Direction

ExpertGPS does not treat every waypoint as the same kind of feature. The source data carries waypoint types/categories, including the operator-confirmed **Stages** type, and the broader file contains multiple other waypoint types.

That classification is operationally valuable because it makes the map easier to layer, filter, and interpret. Future #171 reference/location design should therefore preserve waypoint type/category as first-class source metadata rather than flattening every waypoint into one generic location list.

Required direction:

```text
ExpertGPS waypoint
    -> stable source identity/name
    -> source waypoint type/category
    -> EPSG:8158 reference coordinates
    -> optional transformed WGS84 browser coordinates
    -> application-specific associations/ranking
```

Important boundaries:

- preserve the original ExpertGPS type/category value as source provenance;
- support type-based map layers and filters, such as showing **Stages** separately from other waypoint classes;
- do not equate waypoint type with exclusive Stage ownership;
- a waypoint may be useful to Setup without becoming a Stage, Scene, Display, Container, or Home Location identity;
- if a future normalized internal category is introduced, retain the original ExpertGPS type alongside it rather than replacing the source classification;
- the temporary launch reference JSON may remain a simplified consumption layer, but the long-term #171 maintenance/import path should carry type/category through from the authoritative GIS source.

This classification requirement is especially important because the full ExpertGPS/Garmin source contains many waypoint classes beyond the current launch reference subset. Preserving them will make later GIS/map layering substantially easier and avoid having to infer feature meaning from names after import.

## Operational Asset Overlay Candidate — #171

The V0.3.51 candidate extends the existing Locate map with independent Container
and independent Display layers. GET `/api/setup/locate/assets?season_year=2026`
requires existing Setup read access and returns a no-store snapshot. It reuses
#88 `movement_picture` with optional unobserved Container inventory inside the
same read-only REPEATABLE READ transaction. The report default is unchanged.

Coordinates come only from each state row's `last_movement_event_id`; the map
adapter does not independently search prior history. Missing/invalid coordinates
and RETURNED/storage state remain unlocated. This exposes the gap between the
requested last-valid-GPS continuity and current #88 projections rather than
silently changing the projection. Review C095 against the current clone before
acceptance; any projection repair belongs to #88.

Active WITH_CONTAINER Display associations appear inside Container popups.
DETACHED and NO_ASSIGNED_CONTAINER Displays use their own state event, or remain
unlocated. Expected/reference assignments, recorded position mode and physical
contents are distinct. Icons describe recorded associations: all WITH_CONTAINER
is Loaded, mixed WITH_CONTAINER/DETACHED is Partial, and all DETACHED is Empty.
No assigned active Displays or unsupported modes is Unknown. These categories
do not assert a physical contents inspection; missing Display state still
defaults to WITH_CONTAINER in the owning projection. Historical contents-review flags are shown as
recorded evidence, without claiming they are resolved or still actionable.

Exact coordinate matches share one marker/popup within a layer. Coordinates are
never moved or snapped to Stage anchors. Display artwork is anchored above
Container artwork and given a higher stacking order at shared coordinates. Observation timestamps, GPS feet,
quality/stale-fix evidence, destination notes and capture provenance remain
visible. Refresh clears prior operational markers before requesting new data;
a failed request exposes an unavailable state rather than leaving stale pins.

See [candidate review and limitations](../../../../Setup/Acceptance/Setup_171_Operational_Map_Candidate.md).
This is engineering candidate documentation, not a Production deployment claim.

## Network search candidate — October 9, 2026

Current candidate is reconciled with main `38f6f9427007470cbc02b3e2d23a97450d4414ba`
and preserves the accepted scheduling changes/Production closeout from PR #324/#325.
Use Greg's laptop feature worktree `C:\lor\ImportExport\VSCode-171-map-review`;
its primary main is divergent and must not be reset as a preview preparation step.


PR #318 now has a V0.3.54-gis-network-routes candidate consuming a read-only
draw.io/GPX cross-reference: network groups highlight all segments of every
endpoint-matched route and expose unresolved cables and endpoint conflicts.
43 route candidates use named waypoint anchors and draw.io cable chains; 35
remain unresolved. Exact AUX-I/INET search returns a single network group; raw
GPX routes remain separately discoverable. Dashed highlights currently classify shared-evidence routes as alternatives;
that classification is unsupported and pending correction. These are
operator-review correspondences, not verified reconstructed routes or proof of
continuous connectivity. Existing asset/waypoint search remains available.

[Source inventory, matching rules, confirmed infrastructure facts and resume point](engineering/Network_Source_Reconciliation_2026-10-09.md)
record the current SQL inventory and #319 boundary. Wiring database integration,
editable infrastructure and corrected tester-export reconciliation remain open.

## Deferred Symbol Registry / Type Mapping — #171

The operator-confirmed symbol artwork authority, corrected 31-icon inventory,
Inkscape/Plain SVG maintenance workflow, ExpertGPS PNG generation, legacy
PNG/BMP compatibility and separate web publication locations are recorded in
[GIS Symbol Creation, Publication, and Compatibility](engineering/GIS_Symbol_Management.md).
This is current source-maintenance guidance, **not** acceptance of a new icon
registry, Production schema, web deployment, or browser marker behavior.
ExpertGPS's current per-user custom-symbol location is
`%LOCALAPPDATA%\TopoGrafix\Symbols\msb\`, with the original `readme.txt`
pointing to `https://webassets.sheboyganlights.org/images/symbols/`.
The similarly named `MSB Icons` directory is **not** the currently accepted
replacement. Preserve `msb` and its legacy PNG/BMP URL references until an
explicit ExpertGPS/GPX folder migration is reviewed; see the linked symbol SOP.
**PNG currentness gap:** previously delivered October 9/11 PNG ZIPs derive from an
uploaded SVG snapshot, not a fresh export of today's Shared Drive Plain files.
The [staged current-Plain exporter](../../../../Database/EngineeringTools/Export-ExpertGPSSymbols.ps1)
must be run on a PC with access to those files before treating a PNG batch as
current; installation/publication has not been verified.
October 11 source inventory adds `MSB GIS\Symbols\png` as the intended
canonical local PNG derivative folder, separate from the Windows Downloads staging
used by the current exporter. The current G: `Plain` contains a mixed-case
`msb-splitter-Combiner.svg`, so the exporter correctly refused it; reconcile the
source variants before renaming. Historical ZIP reconnaissance found Inkscape
editing metadata retained in some SVGs outside their `inkscape-masters` folders.
Use [read-only source inventory](../../../../Database/EngineeringTools/inventory_gis_symbols.py)
to list and classify sources from the actual laptop G: and ExpertGPS trees before
export/release.
**2026-10-11 first live inventory:** 454 files (32 chosen Masters, 31 Plain,
109 scattered SVGs, 282 ExpertGPS PNGs); 54 review flags, mostly 41 raw-hash
variation groups. Three Plain SVGs retain Inkscape metadata; canonical `png`
contains no inventoried icon files. **Operator correction:** `lp-network` and
`lp-outlet` are intentional layer-visibility exports from the single
`lp-combo-inkscape.svg` master, not missing-master defects; `lp-outlet` and
`lp-power` refer to the same visual icon and need a reviewed canonical name
plus legacy alias/reference handling. **Operator reports all remaining priority
corrections complete (2026-10-11); fresh file-level verification remains pending.**
The prior inventory is a before-correction baseline; do not treat its specific
repeater/Splitter/metadata flags as confirmed current defects.
Three subsequently supplied `(1)` inventory uploads were compared against the
baseline and found **byte-identical for all three reports**. They cannot be used
to verify post-correction artwork. Rerun with a fresh explicitly named output
directory and hand off that whole report folder before PNG export.
**Fresh 06:19 report subsequently verified:** the new, separate inventory ZIP shows
454 total files, **32 current Plain SVGs**, 31 Masters and **47 residual review
flags**. Splitter casing, LOR master spelling and the three Plain SVGs retaining
Inkscape metadata were corrected (source hashes/paths verified). The 47 flags
are mainly expected raw-hash variation plus a few historical/LP-Combo layer
naming hints. Structurally, PNG staging can now be attempted; actual raster
export, per-layer visual freshness, `star.svg` release inclusion, web/ExpertGPS
compatibility and downstream deployment remain separate pending gates.
See the chronological evidence and new file SHA-256 in the linked SOP.
**Uploaded 07:01 staged PNG ZIP independently audited:** 32/32 manifest PNG
SHA256s and 32/32 source SVG hashes match the fresh G: inventory; RGBA
canvases and original readme pass. Pixel comparison against prior 31-icon
archive: 30 unchanged, bare-pole `lp.png` visibly changed, and `star.png`
added. **Publication HOLD for icon semantics:** `manhole.png` visually repeats
the red/white fire-hydrant symbol (inherited artwork issue), and the intended
standalone LP change/new Star inclusion need operator approval. Fire Hydrant
and Manhole icons are also fully opaque despite RGBA encoding. Do not
promote to `Symbols\\png`, ExpertGPS or web assets solely on QA integrity.
See the linked GIS symbol engineering SOP for file hashes and review gates.
**Later operator correction and 07:24 follow-up:** the hydrant-looking
`manhole.png` in the 07:01 package resulted from a **wrong Plain manhole SVG**;
the operator supplied the correct `manhole.svg` for comparison. The current
**bare-pole `lp.svg` is explicitly approved**, distinct from the separately
layered LP Combo/network/outlet assets. The operator's newest 07:24 PowerShell
listing confirms `MSB_ExpertGPS_Current_Plain_Staged.zip` exists (39,370 bytes)
inside its staging folder. **That 07:24 ZIP has since been uploaded and
independently verified:** all 32 PNG SHA-256s/dimensions/manifest rows pass,
**only `manhole.png` changed** relative to the 07:01 batch, and its source
SHA-256 matches the operator-supplied corrected `manhole.svg` exactly. An
independent Inkscape raster rendering is **pixel-for-pixel identical** to the
new manhole PNG; the original mistaken fire-hydrant artwork is corrected. All
other 31 PNGs (including the operator-approved standalone bare LP) are unchanged.
**Final artwork-selection decision (operator, October 11): include `star.png`**
in the approved 32-icon release candidate, alongside the corrected manhole and
standalone LP. Complete staged ZIP/manifest/source integrity is PASS. **Only
staging/source scope is approved**; canonical `Symbols\\png` promotion, installed
ExpertGPS, web/Synology publication, legacy GPX aliases and draw.io's embedded
schematic artwork have not been migrated or accepted. **A controlled additive
canonical PNG promotion utility is now available**:
[Promote-ApprovedGISPNGs.ps1](../../../../Database/EngineeringTools/Promote-ApprovedGISPNGs.ps1).
**Newer October 11 source update:** the operator has added a left and right
Wi-Fi antenna as separate Inkscape masters and Plain SVG derivatives
(`antenna-l`, `antenna-r`), making the **intended current library 34 icons**.
The previous laptop preflight passed for the then-current **32-icon** ZIP
(32 missing/0 conflicts), but it is **stale for a complete release** after
these source additions. The promotion utility now rejects current Plain
filenames absent from its approved manifest, even when all older SVG hashes
still match. **Do not run the existing 32-icon `-Apply` until the complete
34-icon batch has been exported, reviewed, approved and pinned.** Existing
correct files must be preserved; no replacements/deletions are authorized.
The operator's 32-icon write status is not yet confirmed (receipt not supplied).
**Fresh 34-icon staging ZIP uploaded and independently checked:**
`MSB_ExpertGPS_Current_Plain_Staged(2).zip` contains all 34 PNGs,
manifest and original readme. ZIP CRC, 34/34 PNG hashes and RGBA dimensions
PASS. All previous 32 PNGs and their SVG manifest hashes are unchanged; only
new `antenna-l.png` and `antenna-r.png` are added. **Operator scale
correction completed in Inkscape:** the 121×121 px exports resulted from
source documents measured in **mm** rather than **px**; the operator reports
switching to px and resizing both antenna illustrations. The prior 34-icon ZIP
still contains the oversized old antenna outputs and is superseded as a
promotion candidate. New actual Plain SVG dimensions are **not yet verified**;
rerun the exporter on current G: Plain into a new stage, inspect the two new
antenna PNGs and confirm the other 32 unchanged. A fresh exact-SHA 34-icon
release review/promotion pin is required before writing to canonical `png`.
Live source SVG lineage and actual installed/published symbols remain separate
gates. The existing promoter is pinned to the older 32-icon ZIP and must not
be applied for the complete 34-item release. Govern each independently. Detailed source
triage and post-correction acceptance rules are in the linked GIS symbol contract.
No ExpertGPS, Synology, draw.io, or browser publishing has been verified. draw.io keeps `Network\MSB-icon-library.xml`, but
the existing `Network\Park Network Schematic 2026.drawio` embeds its own SVG/PNG
snapshots: file/library edits cannot automatically update already-placed icons.
The read-only source counts, hashes, and pending cross-application reconciliation
are in the linked GIS symbol maintenance contract. Do not replace any embedded
artwork, legacy ExpertGPS symbols or live web assets during inventory.

Operator-confirmed direction, 2026-10-08: ExpertGPS manages symbols by type
name. In that program the type name is the key and cannot be renamed; changing
it requires deleting and recreating the type. Preserve the exact source type
name during future import/reconciliation rather than treating it as an editable
presentation label. This is reported ExpertGPS behavior, not an implemented MSB
database constraint.

Consider a future reference table mapping feature type and, where applicable,
authoritative operational status to an icon asset path and presentation label.
Keep SVG artwork as separately maintained assets; do not require an icon
assignment on every Container or Display. Preserve source type names separately
if an internal identity or editable display label is introduced. Any type
replacement must deliberately reconcile existing mappings and source references.

For the first operational map overlay, a small replaceable configuration mapping
is sufficient. Greg supplied `container-loaded.svg`, `container-partial.svg`,
`container-empty.svg`, and `container-unknown.svg` (32 × 32 px), and selected the
existing T-Post symbol for independently located Displays. Status symbols must
consume accepted #88 evidence; assigned Display counts alone do not establish
physical load state. Displays WITH_CONTAINER remain in their Container popup
rather than producing overlapping Display pins.

The symbol reference table is deferred design work under #171. It must not delay
functional Container/Display overlays or imply authorization for a Production
schema change. Existing public compatibility symbols remain functional.

## Design Intent

PostgreSQL should provide durable identity, relationships, and useful location history for physical site infrastructure while preserving appropriate survey/GIS tools for collection and visualization.

For Setup/Deployment, GIS should answer questions such as:

- where is the intended park destination for this Display/Container;
- what permanent site/location identity represents that destination;
- what are the best current reference coordinates for it;
- how close is the operator/device/asset to that expected destination;
- is the observed GPS accuracy sufficient to make the requested confirmation meaningful.

GIS should not become a substitute for permanent Display or Container identity.

## Site Location Identity Requirement

Historical display/location data does not consistently use the Production Database permanent `display_id`. Future integration must reconcile to permanent Production Database identities rather than introduce another competing identity.

Likewise, a park destination should have a durable site/location identity when operational workflows require one. Raw GPS coordinates should not be the business key.

Why:

- coordinates can be refined after better survey evidence;
- device fixes vary by equipment and conditions;
- the same conceptual site location can remain stable across coordinate corrections;
- Setup history should refer to the location identity rather than a frozen coordinate string.

## GPS Evidence Classes

Future engineering should distinguish at least these location data classes.

### Reference / authoritative site coordinates

Coordinates established or validated through controlled GIS/survey sources such as Garmin field collection, ExpertGPS review, county imagery, or another approved reference process.

These describe the best known location of the permanent site feature/destination.

### Operational device coordinates

Coordinates produced by a phone/tablet or other field device during Setup/Deployment.

These are operational observations and may include accuracy/uncertainty metadata. They should not silently overwrite reference coordinates.

### Placement / proximity validation

A derived workflow result comparing an operational observation with the expected destination.

PostGIS may be useful for this comparison, but acceptable tolerances must come from the actual field process and location type—not from an arbitrary universal distance.

## Workshop Storage Boundary

### Home Container map anchor — operator requirement, 2026-10-10

Containers recorded at their Home storage location must be shown at the storage
Workshop's geographic location. The shared Workshop pin identifies the building;
the existing canonical Home/rack location (for example RC05-A-01) identifies where
to find the Container inside. Preserve those rack identities and display them in
search/details. This Workshop is **not** the Santa's Workshop display Stage.

This map position is derived from the Workshop reference and Home state, not a
new device GPS observation. Return Home remains usable inside the steel building
without obtaining GPS. Detached Displays remain at their own field locations;
returning an empty Container must not move them to the Workshop.

Greg supplied the Workshop reference again on 2026-10-10 at 10:28 CDT in
`image(20261010-152837).png`. Exact displayed projected coordinates:

| Axis | Value |
|---|---:|
| X / Easting | 213609.429 |
| Y / Northing | 186587.658 |

The screenshot shows feet. The existing project coordinate contract is
NAD83(HARN) / WISCRS Sheboygan County (US survey feet), EPSG:8158; the screenshot
does not independently display its CRS, so that interpretation comes from the
established project contract. Preserve these exact source values. Transform to
WGS84 for browser mapping using the established CRS; do not treat them as decimal
latitude/longitude. Machine-readable source:
[workshop_reference.json](workshop_reference.json).

The coordinate recovery gap is now resolved by this replacement source evidence.
V0.3.61 uses this anchor for confirmed Home returns, with canonical rack labels.
The transformed WGS84 anchor is 43.778402029, -87.733215490; it is reference-derived,
not captured movement GPS. The runtime copy is Setup/Application/setup_workshop_reference.json;
a regression check keeps it equal to this canonical record. Detached displays retain
their own park event coordinates. Browser acceptance and Production deployment remain pending.

Containers with no movement evidence must remain distinguishable as expected at
Workshop rather than confirmed Home. The map is a consumer of #88 state; #230 owns
future maintained site/reference editing. Controlling release issue: #122.


Workshop/rack storage is not primarily a GIS problem.

Precise rack locations and broader storage locations already exist as discrete Production Database location identities. High-volume workshop workflows are expected to use labeled rack/storage locations and the Zebra DS3678-HD scanner.

Do not replace practical rack identifiers with GPS coordinates merely to unify the data model.

The likely boundary is:

```text
Workshop / storage
    -> discrete rack/storage location identity
    -> barcode/QR scanning

Park / field
    -> durable site/location identity
    -> reference GIS coordinates
    -> mobile GPS/map context where useful
```

## Setup/Deployment Integration Direction

Likely park workflow:

```text
scan DISP:<id> or CONT:<id>
    -> resolve expected Setup destination
        -> resolve durable park site/location identity
            -> obtain current device GPS/accuracy when needed
                -> compare with expected site geometry/location
                    -> guide / validate / confirm according to workflow rules
```

The exact write event is not yet defined. Being physically near the expected coordinate does not automatically mean a Container or Display should be marked delivered or installed.

Setup/Deployment owns the movement/status business event. GIS owns spatial identity/evidence and spatial calculations.

For the 2026 launch, GIS/location integration is a **field-start gate**, not a reason to create the real 2026 Setup Session early. The reusable Catalog/task/material foundation and #122 scheduling launch remain separate from the later field-execution acceptance.

## Setup Layout and Ground-Penetration Locate Direction

2026 Setup reconnaissance established a second operational use for the existing GIS source set: **layout guidance and targeted underground locate decisions**.

MSB already has relative placement tracks plus buried network/power reference information outside the new Production Database. That information should be made useful to Setup rather than requiring crews to rely on memory.

The locate rule is not `locate every Stage`.

The operator-confirmed rule is:

> Locate/clear underground infrastructure only where planned ground penetration has a plausible chance of intersecting buried network/power infrastructure or where the risk remains unresolved.

Conceptually:

```text
planned Display / stake / anchor / rebar footprint
    + known buried power/network reference tracks
    -> plausible intersection / proximity risk?

NO
    -> no locate requirement for that work scope

YES / UNCERTAIN
    -> locate/clear the affected area before ground penetration
```

Do not spend field time locating areas where there is nothing underground to damage.

This may be a partial-area determination. One corner or one Display line may require locate/clearance while unrelated work in the same Stage can proceed.

`No locate required` is a derived or reviewed readiness fact. It is not another annual task someone must manually mark complete.

Issue #171 owns the independently actionable 2026 engineering work to inventory the existing GPX/ExpertGPS source set, reconcile useful tracks/features, verify current PostGIS state, and design the smallest useful Setup integration.

Site Infrastructure / GIS owns the spatial reference/evidence and spatial calculation. Setup owns whether the resulting readiness condition permits planned work to proceed.

## Field Correction / Continuous-Improvement Boundary

Spatial reference data will not always be perfect. If Production Crew discover a missing/wrong buried route, layout track, waypoint, or risk area while doing real work, the finding must be preserved rather than becoming verbal/chat-only knowledge.

For a **concrete wrong/missing condition that needs somebody to act later**, the connected field workflow may create a contextual Work Order directly, consistent with the Setup correction contract. Creating the Work Order must not silently overwrite controlled reference GIS data.

Issue #172 remains the broader cross-system observation/continuous-improvement path for findings where the correct owner/action is genuinely unclear or where the finding is an improvement observation rather than a concrete correction.

GIS should consume those common mechanisms rather than inventing an isolated correction queue.

## PostgreSQL / PostGIS Engineering Gate

Before implementing the park workflow:

1. verify the production PostGIS extension/version;
2. inventory current geometry/geography columns, spatial reference usage, indexes, and GIS-related tables/views if any;
3. inventory current Storage Location tables separately;
4. inventory GPX/ExpertGPS waypoint conventions and stable identifiers;
5. reconcile useful site features to Production Database identities;
6. define transformation from phone/tablet GPS coordinates to the working GIS coordinate contract;
7. define whether application proximity checks should use geography, projected geometry, or another controlled calculation;
8. define required device accuracy and location-specific tolerance rules;
9. define which observations/history are worth preserving.

Do not start by adding generic latitude/longitude columns throughout the Production Database.

## Current/Future Responsibilities

- permanent site/location identities;
- reference GPS waypoints and track history;
- operational GPS observations where a workflow needs them;
- spatial/proximity calculations;
- receptacles and power infrastructure;
- utility meters, panels, and circuits;
- seasonal energization requirements;
- relationships to Network Infrastructure, Wiring, Controller Inventory, Displays, Work Orders, and Setup/Deployment.

## Known Open Work

- inventory the existing GPX/ExpertGPS data and waypoint naming/identity rules;
- verify production PostGIS configuration and current spatial objects;
- define durable park Setup destination identities;
- reconcile park destinations with Stage/Scene/Display/Container relationships;
- integrate placement tracks and buried network/power reference data for targeted Setup layout/ground-penetration decisions under Issue #171;
- define meaningful proximity/risk uncertainty for `locate required` / `review required` decisions rather than applying locates everywhere;
- define mobile GPS accuracy and proximity-validation requirements;
- implement and accept mandatory offline map/reference access for incomplete park coverage;
- preserve the existing NAD83 HARN WISCRS Sheboygan County Feet contract during integration;
- use direct contextual Work Orders for concrete correction needs and #172 for broader/unclear observations rather than inventing a GIS-specific queue.

## Resume Development

For Setup/Deployment GIS work, begin only after the actual Setup movement/placement workflow and current launch priority are understood.

Then review:

1. [Setup and Deployment](../12_Setup_and_Deployment/README.md);
2. [Setup Task Supporting Information Contract](../12_Setup_and_Deployment/engineering/Setup_Task_Supporting_Information_Contract_2026-09-11.md);
3. GitHub Issue #171;
4. GitHub Issue #172;
5. GitHub Issue #175 where offline/field-document behavior is relevant;
6. [Scan Workflows and Forklift Operations](../07_Labeling_and_Scanning/Scan_Workflows_and_Forklift_Operations.md);
7. [Containers and Storage](../04_Containers_and_Storage/README.md);
8. existing GPX/ExpertGPS datasets and waypoint conventions;
9. the live PostgreSQL/PostGIS configuration.

Do not design the GIS database schema from assumptions.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)
