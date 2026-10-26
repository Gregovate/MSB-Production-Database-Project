# Record panel circuits and seasonal power activity

## Next disposable review — equipment and field test history

FieldWiring is the interim equipment model-entry surface. Additional Equipment starts without installed units. Select the waypoint, choose Install Equipment, choose a model, enter Quantity (default 1) and an optional note, then Save. This records individual units and installation history together; no prior spare-stock entry is required. Purchase totals do not automatically create inventory or installations. Use Manage equipment models to rename or delete an unused model; models already used by recorded equipment cannot be deleted. Cameras and MSB Blue/Green Splitters use this same workflow; controllers retain their CTRL inventory. Labels are deferred.

For cable tests select a network, type part of a test-point name in any letter case, then choose a waypoint from the visible matching list. Column headings sort the list. Compare tests opens only that segment's date/length/speed/result grid. Dates retain tester-local wall time. Unknown dates remain explicit and sort after dated records. Speed is the nominal rate of the saved test standard, not a new throughput measurement. Not decoded means the numeric FLW outcome still requires engineering verification; do not interpret it as PASS. Source files and provenance remain preserved outside this field grid.

Waypoint Connections shows recorded supply, controllers, equipment and test links. Connection engineering and recorded history is collapsed by default. Recorded state does not prove safe isolation.

Review fixed waypoint, quantity and specific units; create/change models, add a camera and a type, record failure/replacement; verify network-scoped search, sorting, segment-only history and readable dates. Retain preview reports and the FLW result-evidence notices. Exit the preview cleanly. Production release remains blocked pending verified outcome mapping and browser acceptance.

**Candidate procedure — not yet released to Production.** Authorized Production
Crew can maintain these records. Managers maintain waypoint names and positions.

## Define the panel and breaker

1. Open **Panel Circuits** and select the existing panel. Use **Add panel** only
   for an unrecorded panel. Its record owns the GPX waypoint, owner and meter.
2. Use **Meter / upstream supply** beside the main for meter changes or an actual
   supply panel and, when known, its feeder breaker. For FE-00 supplied by Panel 15,
   select Panel 15 even if the feeder breaker is not yet inventoried; leave that
   breaker unknown. Use **Record main breaker** for a local main.
3. Select an unrecorded position in the diagram to add a breaker. Set poles and
   whole-number amps; a two-pole selection proposes same-side positions such as
   18/20. Verify these against the installed panel before saving. Enter seasonal
   and non-seasonal desired ON/OFF on the breaker. Unknown remains UNKNOWN.
4. Save the breaker, then select **Circuit 18** (for example) on that breaker to
   check the waypoint(s) it supplies. Select Circuit 20 independently. Both can
   supply the same quad outlet; either can also supply additional waypoints.
5. **Breaker settings** changes amps/states without re-entering circuit names or
   waypoint selections. Existing circuit IDs and indirect feed paths remain intact.
   Unchecking a directly supplied waypoint retires its relationship with history.

One physical breaker spans vertically adjacent positions on one side. Unrecorded
positions are entry controls, not confirmation of empty installed slots. Unknown
or nonstandard positions remain in the reconciliation section. Legacy circuits
without breaker membership have a separate collapsed reconciliation workflow.
A5 fixture dimensions do not automatically create Production breaker records.

Matching panel-prefix waypoints (A5, CL, GG, FE, etc.) appear first in assignments.
Powered poles and other exceptions remain available. No prefix selects a circuit
automatically. Circuits without discovered waypoints are valid: describe security,
bathroom or other non-show lighting and record their seasonal instructions without
creating a dummy waypoint. Missing waypoint coverage does not mean no load.

## Outlet power and controller connections

Open **Waypoint Connections** and select a power outlet or any FLW-resolved network endpoint. Its
**Outlet circuits** show the recorded supplies; select one to correct assignments.
Use **Connect controller to outlet** to choose an existing inventory ID and the
actual supplying circuit leg. At a two-circuit outlet, choose the leg the plug uses;
do not select one merely because its name resembles the controller or waypoint.
A recorded feed to this outlet must exist first. Several controllers may plug into
one outlet. Breaker settings remain the owner of seasonal switching.

To move a controller connection, edit the old connection, clear **Active record**,
record the reason and save; then create its new connection. Retired rows and audit
history remain visible. Supply changes are rejected while a controller connection
still depends on that supply; reconcile the plug-in record first.

## Controller deployment and Combo equipment

Open **Controllers**, select the Controller, and use **Waypoint connections** to
view or change its network waypoint and actual power outlet/circuit. These are the
same records shown in **Waypoint Connections**. **Save connections** retires prior
associations and creates replacements atomically, retaining history. Choose
**Not connected** to disconnect. **Reload connections** retrieves changes made
from another screen; stale saves require a reload. After an uncertain response,
retry the same Save rather than creating a new connection.

If an outlet has **No supplying circuit recorded**, open **Manage panel / circuit
assignments**, assign that waypoint to its actual breaker leg, then return and
**Reload connections**. Do not guess a circuit from the waypoint name. A missing
network choice is reported separately: either current LOR programming is unresolved,
or the required network lacks resolved FLW endpoint records. Panel inventory may
be saved before those network records are resolved; Controller network placement
still requires them.

Network placement offers any uniquely resolved FLW endpoint carrying the current
LOR network, including panels and distribution points without power. GPX type
does not restrict network placement. The attachment waypoint can be the origin
of a Controller daisy chain; this screen does not record Controller order or
termination. Power outlet choices
are Power or Combo waypoints with a recorded supplying circuit. Network location
and actual plugged-in power outlet remain separate facts.

Open **Combo Equipment** for switches, power supplies, splitters, repeaters and
other installed gear. Select the Combo waypoint and **Add new equipment**.
Controllers remain in the existing Controller Inventory. Intermediate feed and
conductor records are available in the equipment screen's engineering disclosure.

Open **Cable Test History** and select the connected waypoint pair. Each physical
cable retains its separate test history, including retests, UUID, raw result code,
test standard, measured length and source hash. Unresolved bindings have their own
choice. Parsed FLW endpoint pairs and cable designations are also shown before
physical cable review, retaining the source labels and distinguishing AUX, SPARE,
E1.31 and other designations. These source-declared pairs do not approve a cable
identity or GIS route. This information is read-only and does not establish a network path or
prove electrical isolation.

Correct conflicting evidence without publishing competing active breaker supplies.
The database rejects such relationships even when they pass through equipment.
Retain the evidence for review; do not guess a valid assignment to bypass a denial.
Generic correction dialogs require evidence; verification defaults to UNVERIFIED.
Only assert VERIFIED when supported by reviewed evidence.

Use the header **Light mode / Dark mode** button; it shares the FieldWiring theme
preference and persists across reloads.

## Seasonal activity

Define the enduring activity, affected circuit/equipment, phase, responsible party,
instructions and any prerequisite activities. Select the correct **Season** before
recording progress or condition.

Use **Record seasonal activity / condition** to record the event actually known:
reported condition, field verification, started/completed work, utility request,
utility confirmation, or an exception. Include when it occurred and evidence.
A utility request is not confirmation of completed utility work. Completion does
not automatically create a field-verification record. Prerequisites apply within
the selected season; previous-year completion does not satisfy them.

Use **Correct this event** to append a correction without erasing the original.
Desired states and saved records are never physical proof of de-energization.
Follow the applicable authorized field procedure for the physical work.

## If a save fails

- Another edit was saved: retain/review your entered values, close the editor,
  reload current records and reconcile before trying again.
- Save outcome unknown: **Save** retries the same request safely. Alternatively,
  close and reload to inspect what was recorded before starting another edit.
- Missing waypoint: report it for Manager/GIS correction; do not create a guessed
  name or coordinate to complete an assignment.
- Capture unavailable: report the displayed error. The circuit database release
  and current GIS references must be installed before this workflow is usable.

[Operator procedures](README.md)

## Network, load and waypoint review — integrated candidate

- Controller installation offers only locations with the Controller's current LOR network recorded at either FLW cable endpoint. If none appear, resolve the source with the FLW/LOR owner. Crew cannot assign networks. A Combo label alone is insufficient. GPX route review is not required for this connection.
- Each branch leg shows its recorded Display-current subtotal and breaker rating. Open the load details for contributing Displays and gaps. INCOMPLETE means it is not verified usable capacity; missing or ambiguous demand is not zero.
- Edit the panel's planned show-season and off-season supply independently of breaker settings. Record actual panel switching or utility evidence under Seasonal power activities by selecting the panel target. A utility request is not confirmation.
- Open a waypoint's electrical-source section to see recorded supplying circuits, upstream panels/main breakers, ownership/meter information and dated evidence. Check unresolved sources and follow field isolation and testing procedures. Planned OFF is never proof of absence of voltage.
- Park Map opens the same selected waypoint in FieldWiring. Cable-test evidence remains measurement history, separate from route availability.

## Equipment expectations

The waypoint network section flags multiple same-network cable paths for LOR
branch/repeater verification. Multiple paths may instead be a continuing line;
check the actual topology. INET/E1.31 endpoints prompt switch/power-supply checks
at distribution points where runs approach 300 feet, and PoE checks for cameras.
These prompts never create installed inventory. Record only actual components.
The Racing Arch chain/termination remains unverified until checked in the field.

## Wire controller IN and OUT (V0.4.17 candidate)

The Controller screen and **Edit IN / OUT** at a waypoint use the same editor.
Stage selection still filters the Controller list. Network wiring can continue
across stages; the LOR network and FLW origin determine eligible connections.

1. Select the **Network origin waypoint**.
2. Set **IN — cable comes from** to the named waypoint or preceding Controller.
3. Set **OUT — cable goes to** to the next Controller, **Terminating resistor**,
   or the named waypoint's **return cable**. An unassigned next Controller is
   selectable when its current LOR network and origin agree.
4. Save. Choosing 1002 as 1001's OUT also records 1001 as 1002's IN, in the same
   transaction. Open either controller or the waypoint to see the same connection.
5. Power outlet can stay **Not connected** until its supplying circuit is entered.

Examples supplied by Greg: Racing Arches RA-00 → 1001 → 1002 → 1003 → 1004,
probably ending with a terminating resistor (UNVERIFIED). Elf Choir ST-01 → 1005
→ 1006 → 1036 → ST-01, returning for continuation toward the Stars. Do not treat
this return as the network's end. These examples are not automatically installed
records or field verification. Save the actual observation; new/corrected wiring
remains UNVERIFIED.

Changing OUT releases the old next-controller IN to **Not recorded** without
inventing a waypoint connection or deleting the remaining chain. Changing IN
updates the former and new predecessor's displayed OUT. Occupied ports cannot be
silently taken from another connection: reconcile those first. A return cable is
not a controller dependency loop. Different LOR networks/origins, controller loops
and multiple connections from one controller OUT are rejected. Save failures roll
back both ends; stale edits require reload; uncertain saves retain an identical
retry request. Before/after audit history covers all affected controllers.

### Identify displays while building a chain

The IN / Controller / OUT table shows the physical display name below each asset
ID, for example CTRL 1094 with WF-Tree-08. Controller choices and the chain include
both ID and name. Names come from current Display assignments, not controller-number
order or the reusable wiring-source template. Multiple assignments are listed;
**No display assigned** is explicit. These labels do not alter any wiring or assignment.


### Controller list order

Use **Sort by** above the left Controller list to switch between **Controller ID**
and **Display name**. Display names use natural order (Tree 2 before Tree 10);
unassigned controllers appear last. Stage/search filters still apply. Changing
the sort keeps the selected controller and unsaved connections open and does not
change the network chain. The choice remains active until the page is reopened.

The IN/OUT controller pickers follow this same sort choice immediately. Special
choices (waypoint, terminating resistor, not recorded) remain first. Pickers retain
eligible controllers from other stages so the network can continue across stages;
sorting never changes the recorded chain or a pending selection.


## Pending panel-entry correction — V0.4.22 candidate

In Panel setup, **Number of slots** is the actual numbered branch-position count,
excluding the main breaker. A two-pole breaker occupies two slots. Enter the
panel's actual count (for example 18, 20, 40 or 42); the main amperage does not set
it. Leave unknown counts blank. Empty slots are places to add a breaker, not
installed breakers. The system rejects reductions below an occupied slot.

The panel list labels MSB ownership in light blue and City ownership in light
orange. The selected panel has a separate outline. Blue Save/Add buttons perform
primary actions; outlined pale-blue circuit buttons open waypoint assignments;
light-gray buttons open settings or cancel; teal buttons open waypoint/equipment details. Breaker cards group their
circuit legs. Load and connection details remain available in disclosures.
Colors never establish electrical state or safe isolation. This correction is
pending candidate review and deployment; the current live release is V0.4.20.

The breaker rating picker includes 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70,
80, 90, 100, 110, 125, 150, 175 and 200 A, plus existing saved ratings without
duplicates. Back to panel and browser Back restore the selected panel, filter,
expanded details and scroll position within the same browser tab.


### Seasonal breaker work — PR457 deployed V0.4.26, Production browser spot check pending

1. On Panel Circuits, choose Season **2026** and Season mode **ON** (show targets) or **OFF** (off-season targets). Panelboard green **Recorded ON** and red **Recorded OFF** show the last observation, with the person's name and time. Gray means no known recorded position.
2. After physical work, press **Record ON** or **Record OFF** once. There is no confirmation dialog. The whole grouped breaker is recorded, including a two-pole breaker, and no waypoint is required. These buttons record observations; they do not remotely switch equipment or establish isolation. If confirmation is lost, **Retry recording** safely resends the same observation.
3. **Breaker reports** covers ALL active breakers, including ON/ON and OFF/OFF targets. Select **Exceptions / missing work**, **All breakers**, or **Completed**. **Show report** displays the table; a panel/breaker button opens its board. **Download PDF report** downloads the selected report with required state, recorded state, person/time and a specific exception reason.
4. A wrong position, missing observation, older season, different season mode, or unconfigured required state remains an exception. A recorded OFF breaker required ON is included even if its seasonal targets are ON/ON. Reports do not infer work from photos or update task57's historical percentage.
5. The collapsible **Seasonal breaker checklist** retains the change-only workflow: equal known targets are omitted there. Use its Completed and Needs configuration views as needed. Locate links open the maintained panel waypoint on Park Map.
6. Panel **Number of slots** accepts whole numbers 1–200; **8** is offered for small panels such as FE-00. Existing occupied positions must fit within the selected count. Do not delete real breakers to force a smaller count.
7. Correct mistaken historical observations through Seasonal power activities / Correct this event. The audit history remains append-only.


### Unassigned breaker correction — deployed V0.4.29; protected browser check pending

Open **Breaker settings**, correct **Positions / circuits** and **Poles**, then Save. A mistaken 2/4 two-pole entry can become position2 with one pole when no active connections exist. Its retained circuit ID and notes remain; the unused leg is retired and position4 becomes available.

To remove an entire mistaken entry, choose **Remove mistaken breaker**, review the removal summary, and Save. This frees its positions and retires unused circuit records; history is retained. If blocked, the message identifies feeds, controllers, conductor memberships, remote panels or activities requiring reassignment. Automatic position-observation history is preserved. Do not delete a panel or recreate valid inventory to correct a breaker.

### V0.4.30 disposable review — setup equipment and cable tests (not Production)

1. In Additional Equipment, choose any applicable waypoint, or Uninstalled / spares. Add equipment records one physical item; the model field offers existing suggestions and accepts an unknown model. Select its type and record ratings/notes when known. Controllers remain in the existing Controller inventory with unchanged CTRL identity.
2. Record test / failure opens UNTESTED, WORKING or FAILED, test date/time and notes. Leave the date blank when unknown. History retains actor and entry time. Correct test appends a correction; it does not erase the original.
3. Move / remove changes an existing item's current waypoint or returns it to spares. Replace selects a different existing spare and records the old/new relationship. Add an unrecorded spare first. Both items and their history remain. Active electrical feed references must be reconciled before movement/replacement; the application does not silently transfer connections.
4. Cable Test History initially shows all retained tests, grouped by cable/network with latest reliable dates first. Filter by Network and/or Waypoint. Expand All tests for provenance and older/undated observations. Unknown network matches remain visible under All; an undated test prevents a claim that chronological order is certain. Speed is unknown where no measured speed is stored; the source test standard is shown separately, not converted to measured throughput. Recorded result codes remain source evidence, not an invented pass/fail interpretation.
5. Controller Save connections is blue; Reload connections is gray. Network fields are light blue and power fields light red, with text labels. The ordered chain highlights the selected controller and preserves the recorded origin/ending.

Review only in the disposable clone. Check that existing chains, outlet assignments, panel notes/states and reports remain intact. End through the reusable preview's cleanup and retain its report. Equipment labels are low priority and not required for recording data.


## Pending controller performance review

On the next pinned disposable candidate, open Racing Arches or Who from a fresh controller page, then select several controllers in the same chain. Record first-load time separately from subsequent selections. Confirm network light blue, power light red, Save blue, Reload gray, correct chain/display names and recorded power source. Reload connections must fetch current records; test one connection edit only in the disposable clone and confirm retained chain behavior. The existing read-only transport script compares full and controller-scoped response bytes and timings. Retain reports and finish the original preview runner's CLEAN EXIT. These are acceptance steps, not Production release authorization.


## Equipment and cable correction review

On the pinned replacement preview, confirm Additional Equipment and Cable Test History contain no breaker report, season selector or seasonal checklist, including after Reload and navigation from a selected panel. Equipment location/Add/Move should offer power/network/combo locations plus spares, excluding Stage points. Infrastructure types such as light poles and disconnects are not Additional Equipment choices. Existing equipment at a legacy location remains visible for reconciliation; new installs there are disabled.

Check a cable result such as1000BASE-T: Test speed / standard should show1000Mbps with the original standard. This is the saved test standard's rate; it is not measured throughput or a claim that the cable passed. Missing standards display Not recorded, unsupported standards remain verbatim, and result codes remain as captured. Confirm lengths, latest dates, network/test-point filters and older history remain intact.
