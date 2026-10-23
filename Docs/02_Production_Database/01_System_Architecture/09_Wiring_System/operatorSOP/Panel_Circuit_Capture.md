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

Expand **Waypoint supply / OUT-Combo network box** and select a waypoint. Its
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

## OUT-Combo network-box inventory

The receptacle and larger network box share one OUT-Combo waypoint. The network
box section appears only for Combo waypoints. **Install inventory item** selects
an existing Controller Inventory ID; several repeaters, switches, adapters or power
supplies can be installed. Use the existing Controller Inventory screen to maintain
asset/model records. This screen does not create another equipment inventory.
Network-box placement and the controller's outlet connection are separate facts.
To move equipment, retire the old installation and install that same ID at the new
box. Record failures and repairs in existing Work Orders against that controller ID.
Network assignments and advanced intermediate electrical feeds remain separate.

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
