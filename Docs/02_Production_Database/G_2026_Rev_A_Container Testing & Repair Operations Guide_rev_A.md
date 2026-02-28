# MSB 2026 Container Testing & Repair Operations Guide
System: my.sheboyganlights.org  
Audience: Volunteers  
Version: 2026 Go-Live

---

# 1. PURPOSE

This system replaces the legacy spreadsheet.

It ensures:

- Every container is tested
- Every display is accounted for
- Repairs are tracked
- Storage locations are accurate
- No tribal knowledge is required

If something moves physically,
it must be updated in the system.

---

# 2. KEY TERMS

## Container Status
- NOT STARTED – No testing has occurred.
- IN PROGRESS – Testing has begun but not complete.
- COMPLETE – All required testing finished for the season.

## Container Tag State
- GREEN – Ready for show.
- YELLOW – Work remains or testing deferred.
- RED – Major repair required before installation.

## Home Location
The permanent storage location assigned to a container.

Examples:
- Rack position
- Mezzanine zone
- Trailer
- Building A – East side

Home Location answers:
> “Where should this container live when not being worked on?”

---

# 3. STARTING WORK – PULLING A CONTAINER

## Physical Action
Forklift Operator:
- Pull container from its Home Location.
- Move container to designated work area.

## Required System Action

In my.sheboyganlights.org:

1. Open Container Testing.
2. Select the container.
3. Click **Start Testing**.
4. Confirm Work Location.

This marks the container:
- IN PROGRESS
- Actively being worked

If this is skipped, the system will not reflect reality.

---

# 4. TESTING DISPLAYS

Each container screen lists expected displays.

For each display:

- Confirm it is physically present.
- Select a result:
  - PASS
  - FAIL
  - DEFERRED
  - NOT PRESENT
  - REMOVED FOR REPAIR
- Add notes if needed.
- Update amps if lights were replaced.

---

# 5. DEFERRED STATUS (Important)

DEFERRED means:

> Testing is intentionally paused because it requires different tools, equipment, time, or personnel.

Examples:
- Controller requires programming equipment.
- RGB testing needs special hardware.
- Lift or additional setup required.
- A different skill set is needed.

DEFERRED is not a failure.
It is a pause for proper completion.

Containers with deferred items:
- Remain IN PROGRESS
- Are tagged YELLOW

---

# 6. SIMPLE REPAIRS (DONE IN PLACE)

If a repair can be completed immediately:

1. Fix the issue.
2. Update result to PASS.
3. Record what was replaced.
4. Update amp reading if required.

Container may still become GREEN if all displays pass.

---

# 7. REMOVING A DISPLAY FOR REPAIR

If a display must leave the container:

## Physical Action
- Remove display.
- Tag display with red tag and note what is wrong.
- Move it to repair area.

## Required System Action
- Mark display as REMOVED FOR REPAIR.
- Add clear repair notes.

Container will:
- Remain IN PROGRESS.
- Be tagged YELLOW or RED.

---

# 8. WHEN A REPAIR IS COMPLETE

## Physical Action
Repair Volunteer:
- Confirm display is fully repaired.
- Return display to its correct container.

If container is in storage:
- Forklift Operator pulls container back to work area.

## Required System Action
1. Open the container.
2. Locate the display.
3. Change result to PASS.
4. Add repair notes.
5. Update amps/light count if changed.

Container readiness will update automatically.

---

# 9. WHEN IS A CONTAINER COMPLETE?

A container is COMPLETE when:

- All required (non-spare) displays have been evaluated.
- No FAIL items remain.
- No REMOVED FOR REPAIR items remain.
- No DEFERRED items remain.

When complete:
- Status = COMPLETE
- Tag = GREEN

If issues remain:
- Tag = YELLOW or RED
- Status stays IN PROGRESS

---

# 10. RETURNING A CONTAINER TO STORAGE

When stopping work:

## Required System Action FIRST
In container screen:

- Click **Pause Work** if incomplete.
OR
- Click **Mark Complete** if finished.

## Then Physical Action
Forklift Operator:
- Return container to its Home Location.

The system must reflect the final location.

---

# 11. IF A CONTAINER IS STORED IN A NEW LOCATION

Sometimes containers are moved to a new rack, zone, or trailer.

If a container’s storage location changes:

1. Physically place container in new location.
2. Immediately update Home Location in the system.
   - Open container record.
   - Edit Home Location.
   - Save.

Failure to update Home Location causes lost containers.

Home Location must always match physical storage.

---

# 12. SPARE DISPLAYS

Displays marked SPARE:

- Do not block completion.
- May be tested optionally.
- Are excluded from readiness calculations.

---

# 13. MULTI-DAY WORK

Containers may be worked across multiple days.

If stopping:
- Use Pause Work.
- Resume later from the same screen.

All entries remain saved.

---

# 14. RESPONSIBILITY SUMMARY

Forklift Operator:
- Moves containers.
- Returns containers to storage.

Testing Volunteer:
- Tests displays.
- Records results accurately.

Repair Volunteer:
- Fixes removed displays.
- Updates results when returned.

Manager:
- Resolves location corrections.
- Reviews container readiness.
- Approves assignment changes.

---

# 15. FINAL RULE

If something moves physically,
update it in the system immediately.

The system must always match the floor.

---

END OF DOCUMENT