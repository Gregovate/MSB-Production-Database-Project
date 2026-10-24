# Record panel circuits and seasonal power activity

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
