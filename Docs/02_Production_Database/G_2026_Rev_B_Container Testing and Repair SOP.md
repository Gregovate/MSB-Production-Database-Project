# MSB 2026 Container Testing and Repair SOP
System: my.sheboyganlights.org  
Audience: Volunteers  
Version: 2026 Go-Live
Updated: 2026-03-13 GAL

---

# 1. PURPOSE

This system replaces the legacy spreadsheet.

It ensures:

- Every container is tested
- Every display is accounted for and is on the correct container
- Every Display name label matches LOR Display Name
- Repairs are tracked
- Storage locations are accurate
- No tribal knowledge is required

If something moves physically,
it must be updated in the system.

# 2. KEY TERMS

## Container Status

- NOT STARTED – No testing has occurred.
- IN PROGRESS – Testing has begun but not complete.
  - Once a container it is changed to In Progress in cannot be changed back to Not Started.
- DONE – Testing complete, All displays present, Ready for Setup
- NOT REQUIRED – for containers for extension cords, T-Posts, etc

## Container Tag Status

- GREEN – Ready for show.
- YELLOW – Work remains or testing deferred.
- RED – Major repair required before installation.

## Home Location

The permanent storage location assigned to a container.

Represents one physical storage or zone location in the workshop.

There are two supported location types:

- **R = Rack Slot** (single-occupancy)
  - Rack slots represent precise physical positions in the rack system.
  - Only one container can fit into a rack location
  - Rack position Row, Column, Level, Slot
  - Examples:
    - RA-06-A-01 Row A, Column 6, On Floor, Position 1

  - 
- **Z = Zone** (multi-occupancy)
  - Zones represent logical or temporary storage areas.
  - More than one container can be stored in a Zone
  - Examples:
    - Bldg A - East
    - Bldg A - West
    - Bldg B - East
    - Bldg B - West
    - Mezzanine (Above Office)
    - FLOOR (Generic Work Area)

# 3. STARTING WORK – PULLING A CONTAINER

All containers for the season start off in the [Containers Not Started](https://db.sheboyganlights.org/admin/content/test_session?bookmark=64) list.

## Physical Action
Forklift Operator:
- Pull container from its Home Location.
- Move container to designated work area.

## Required System Action


1. Open [Containers Not Started](https://db.sheboyganlights.org/admin/content/test_session?bookmark=64) list.
2. Select the container to be tested.
   1. You can scroll through the list
   2. You can use the search box in the upper right corner and type
      1. The container number or
      2. Type in something in the container description
3. Single Click on the container to open it
4. Choose **In Progress** in the Container Test Status Field
5. Choose the Work Location (Cannot be blank) In the Work Location Field
6. Save Record

This marks the container:
- IN PROGRESS
- Removes the container from [Containers Not Started](https://db.sheboyganlights.org/admin/content/test_session?bookmark=64) to [Containers In Progress](https://db.sheboyganlights.org/admin/content/test_session?bookmark=63)
- The system Looks up the displays that are assigned to that container
- The system builds testing records for each display
- Now the container is ready for testing and inspection

If this is skipped, the system will not show any display test records.

# 4. TESTING DISPLAYS

[Containers In Progress](https://db.sheboyganlights.org/admin/content/test_session?bookmark=63) shows all containers that have been pulled for testing and not completed.

1. Find the container you are working on in this list anc single click it
2. It will open the container record where some container information can be updated
3. Scroll down to the Display Checks Box listing all the displays the system thinks are on that container
4. Click on a single display
   1. Confirm it is physically present.
   2. After testing select the result
      1. OK
      2. OK-REPAIRED
      3. REPAIR W/O
      4. DEFER
      5. WRONG CONTAINER
   3. Add additional notes if needed
   4. Update amps (Optional)
   5. Update Light Count (Optional)
5. Save the test record
6. Repeat for every display on the container
Save

# 5. Display Test Status -  Definitions

- **OK**

  - Means the display works as designed and no further Action Needed
  - Display is ready for setup

  - No problems found
  
- **OK-REPAIRED**
  - If a repair can be completed immediately like replacing string lights
    - Fix the issue.
    - Update result to OK REPAIRED.
    - A Note is REQUIRED
      - Example:
        - Replaced 3 red string lights
  - When a work order for a REPAIR Item has been completed
    - The system will find the original test record
    - And the system will update it from REPAIR to OK REPAIRED

- **REPAIR W/O**
  - Complicated repairs like rope light repairs, Broken Frames
  - A Note is required
  - Work Order automatically generated when test record is saved

- **DEFERRED**

  - > Testing is intentionally paused because it requires different tools, equipment, time, or personnel.

  - Examples:
    - Controller requires programming equipment.
    - RGB testing needs special hardware.
    - Lift or additional setup required.
    - A different skill set is needed.
  - DEFERRED is not a failure.
    - It is a pause for proper completion.
  - Containers with deferred items:
    - Remain IN PROGRESS
    - Are tagged YELLOW

- **WRONG CONTAINER**
  - A Test record was recreated for a display not belonging on that container
  - Further investigation required to fix display assignment
  - DO NOT MARK the diplay present

# 6. REMOVING A DISPLAY FOR REPAIR REPAIR W/O

If a display must leave the container

- Examples:
  - Rope Light Repairs
  - Frame / wire backing re-weld

## Physical Action
- Mark the Display Present
- Mark Test Staus REPAIR W/O

- Remove display.
  - Tag display with YELLOW tag and note what is wrong.
  - Move it to repair area.
- Place yellow tag on the container
  - Mark the tag with the display name REMOVED FOR REPAIR.

## Container will:
- Remain IN PROGRESS.
- Be tagged YELLOW .

# 7. REPAIRING DISPLAYS WITH WORK ORDERS (W/O)

## Physical Action
Repair Volunteer:
- Make the repairs
- Open [Aging Repair Work Orders](https://db.sheboyganlights.org/admin/content/test_session?bookmark=72)
- Find the work order generated for the display and single click on it
- Scroll down to Completion data
- Record what was done in Completion Notes (REQUIRED)
- Check Repair Complete and save record
  - If the work order is not completed, the container test status cannot be marked DONE.
- Return display to its correct container.
- Container may be in the WORK LOCATION or HOME LOCATION

If container is in storage:
- Forklift Operator pulls container back to work area.
- Put repaired display on container
- Check Yellow Tag
  - If this is the repaired display is the last thing left on the yellow ticket. Remove Yellow Ticket and mark container DONE (FIX WORDING)


## System Action

1. Opens the container.
2. Locates the display with REPAIR W/O.
3. Changes result to OK REPAIRED.
4. Prepend existing notes with Repair Notes


Container readiness will update automatically. (NEED TO VERIFY)

# 8. WHEN IS A CONTAINER COMPLETE?

A container is COMPLETE when:

- All required displays have been evaluated.
- No REPAIR W/O items remain.
- No DEFERRED items remain.
- No WRONG CONTAINER items remain
- All Displays Marked Present

When complete:
- Status = DONE
- Tag = GREEN

If issues remain:
- Tag = YELLOW
- Status stays IN PROGRESS

# 9. RETURNING A CONTAINER TO STORAGE

When stopping work when something is deferred:
- Return container to its Home Location or Leave in Work Location.
- YELLOW tag remains on container
- Container Status remains IN PROGRESS

# 10. IF A CONTAINER IS STORED IN A NEW LOCATION

Sometimes containers are moved to a new rack, zone, or trailer.

If a container’s storage location changes:

1. Physically place container in new location.
2. Immediately update Home Location in the system.
   - Open container record.
   - Edit Home Location.
   - Save.

Failure to update Home Location causes lost containers.

Home Location must always match physical storage.

# 11. MULTI-DAY WORK

Containers may be worked across multiple days.

If stopping:
- Be sure to save all records
- Resume later from the [Containers In Progress](https://db.sheboyganlights.org/admin/content/test_session?bookmark=63) list

# 12. RESPONSIBILITY SUMMARY

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

# 13. FINAL RULE

If something moves physically,
update it in the system immediately.

The system must always match the floor.

---

END OF DOCUMENT