# Record panel circuits and seasonal power activity

**Candidate procedure — not yet released to Production.** Authorized Production
Crew can maintain these records. Managers maintain waypoint names and positions.

## Define the panel and breaker

1. Open **Panel Circuits** from Field Wiring and select the existing panel. Use
   **Add panel** only when the panel is not already recorded.
2. Beside **Main disconnect**, use **Meter / upstream supply** to enter known meter
   information. For a remote main, select the actual supplying breaker in another
   defined panel. A panel name alone does not identify that breaker. Leave an
   unknown supply blank; do not guess the FE-00 / Panel 15 relationship.
3. Use **Record main breaker** for a local main, or **Add branch breaker** for an
   individual breaker. Enter known positions, such as `18/20` or `18,20`; the form
   creates one circuit-leg section per position. If positions are unknown, enter
   the pole count and explicit circuit designations. Existing designations and
   permanent circuit IDs are retained on edits.
4. Enter whole-number amps, breaker notes if useful, and **Show ON / OFF** and
   restoration state. A two-pole 20 A breaker is 20 A per pole, not 40 A.
5. For each circuit leg, search current waypoint names or retained aliases and
   check what it feeds. Both legs of one breaker may supply the same quad box,
   such as A5-18/20, and either may supply additional waypoints. An OUT-Combo
   cannot have supplies from two different breakers.
6. **Save** once. The breaker, circuit legs and direct waypoint assignments commit
   together or all roll back. Entry remains UNVERIFIED pending field review.
   Existing IDs, indirect equipment paths and correction history are retained.
7. Use the breaker's **Edit / correct** to change these records together. Clearing
   a waypoint retires that direct relationship. Reducing pole count cannot silently
   remove existing legs; reconcile their dependent records first.

The schedule uses conventional odd-left / even-right positions; verify installed
numbering. Unknown positions do not prove empty slots. For older records without
breaker membership, expand **Reconcile circuits with unknown breaker membership**.
That exception workflow is separate from normal combined breaker entry.

## Waypoint equipment and networks

Expand **Waypoint / OUT-Combo equipment and networks** and select the waypoint.
Use **Add equipment**, **Add feed relationship** or **Assign network** for known
intermediate equipment and networks. Cable/conductor engineering is separately
collapsed there. These are not required breaker-entry fields. Controller channels
and network assignments remain independent of electrical circuit identity.

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
