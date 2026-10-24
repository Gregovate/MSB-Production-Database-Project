# Record panel circuits and seasonal power activity

**Candidate procedure — not yet released to Production.** Authorized Production
Crew can maintain these records. Managers maintain waypoint names and positions.

## Define the panel and breaker

1. Open **Panel Circuits** and select the existing panel. Use **Add panel** only
   for an unrecorded panel. Its record owns the GPX waypoint, owner and meter.
2. Use **Meter / upstream supply** beside the main for meter changes or an actual
   supplying breaker in another panel. Use **Record main breaker** for a local main.
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

## Outlet power and controller connections

Open **Waypoint Connections** and select a Power, Network or Combo waypoint. Its
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

Network placement offers Network or Combo waypoints only when current LOR
programming and reviewed GIS paths establish eligibility. Power outlet choices
are Power or Combo waypoints with a recorded supplying circuit. Network location
and actual plugged-in power outlet remain separate facts.

Open **Combo Equipment** for switches, power supplies, splitters, repeaters and
other installed gear. Select the Combo waypoint and **Add new equipment**.
Controllers remain in the existing Controller Inventory. Intermediate feed and
conductor records are available in the equipment screen's engineering disclosure.

Open **Cable Test History** and select the connected waypoint pair. Each physical
cable retains its separate test history, including retests, UUID, raw result code,
test standard, measured length and source hash. Unresolved bindings have their own
choice. This information is read-only and does not establish a network path or
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

- Controller installation offers only locations with the Controller's current LOR network confirmed by a reviewed GIS route. If none appear, resolve the source with the GIS/LOR owner. Crew cannot assign networks. A Combo label or a passing cable test alone is insufficient.
- Each branch leg shows its recorded Display-current subtotal and breaker rating. Open the load details for contributing Displays and gaps. INCOMPLETE means it is not verified usable capacity; missing or ambiguous demand is not zero.
- Edit the panel's planned show-season and off-season supply independently of breaker settings. Record actual panel switching or utility evidence under Seasonal power activities by selecting the panel target. A utility request is not confirmation.
- Open a waypoint's electrical-source section to see recorded supplying circuits, upstream panels/main breakers, ownership/meter information and dated evidence. Check unresolved sources and follow field isolation and testing procedures. Planned OFF is never proof of absence of voltage.
- Park Map opens the same selected waypoint in FieldWiring. Cable-test evidence remains measurement history, separate from route availability.
