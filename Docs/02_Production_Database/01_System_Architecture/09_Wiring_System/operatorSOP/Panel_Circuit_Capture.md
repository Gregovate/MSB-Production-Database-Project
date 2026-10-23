# Record panel circuits and seasonal power activity

**Candidate procedure — not yet released to Production.** Authorized Production
Crew can maintain these records. Managers maintain waypoint names and positions.

## Define the panel and circuit

1. Open **Panel Circuits** from Field Wiring.
2. Select the existing panel. Use **Add panel** only if it is not already recorded.
3. Record the readable panel identification and any known owner, meter or waypoint
   information. Leave unknown fields empty.
4. Use **Record main breaker** for the panel's main disconnect. Record its marked
   amperage and pole count when known. Main ratings are not branch circuit ratings.
5. Use **Add branch breaker** and enter its marked rating, pole count and known
   panel positions in pole order, for example `18,20`. The conventional display
   puts odd positions left and even positions right; verify the installed numbering.
   Leave unknown positions blank. An unrecorded position does not prove an empty slot.
6. From that breaker use **Add circuit to breaker**. Enter the circuit designation,
   description and pole within the breaker (1 or 2 for a two-pole breaker).
   Pole ordinal is not the physical panel position. Both legs share one breaker
   identity/rating. A two-pole 20 A breaker is not recorded as 40 A.
7. **Add circuit** remains available when its breaker is unknown. These records
   stay visible separately until their supplying breaker is established.
8. Record desired show/restoration states separately. Enter source/evidence and
   verification status for each saved record. These are plans and recorded facts,
   not proof of current physical condition.

## Assign or correct waypoints

1. Open the circuit and select **Assign multiple waypoints**.
2. Search using the current waypoint name or an old retained alias.
3. Check all waypoints supplied directly by the circuit. Clear an incorrect
   direct assignment to retire it while retaining its history.
4. Record supporting evidence and verification status, then **Save**.
5. Return to the panel to retrieve the saved assignments.

For a fuse, disconnect or other intermediate device, use **Add equipment** and
**Add feed relationship** to record each known connection. Choose one source and
one destination per connection. Multiple documented feeds are allowed. A
conflicting relationship should be marked **CONFLICTING**, not guessed away.

Use **Assign network** for each network carried by a waypoint. Network assignment
is independent of its supplying electrical circuit; OUT-Combo can have both and
several networks. Controller channels are not panel circuits.

Use **Edit / correct** with evidence for corrections. Clear **Active record** to
retire a mistaken relationship. When editing verified reference information,
verification defaults to **UNVERIFIED**; explicitly select **VERIFIED** only when
supported by your evidence. The correction history retains previous values.

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
