# Garmin GPSMAP 66sr — Record a Cable Route and Clear Old Tracks

[↑ Garmin and GIS procedures](README.md)

| Document Control | Value |
| --- | --- |
| Document Type | Operator SOP |
| Equipment | Garmin GPSMAP 66sr |
| Task | Stop automatic recording, remove old tracks, record one cable route |
| Audience | MSB field technicians |
| Owner | MSB Site Infrastructure / GIS |
| Status | **DRAFT — button steps from Garmin instructions; check on our device before crew use** |
| Last Reviewed | 2026-10-14 |

## What you will do

Use the Garmin to save **one cable route at a time**. Keep the park picture and the named location points on the map. Remove old tracks that MSB has already saved in its master map file.

**Know these buttons:** **MENU** opens a list of choices. Press **MENU twice** to open the main menu. Use the **arrow buttons** to move through a list. Press **ENTER** to choose. Press **QUIT** to go back.

> **Do not choose Delete All, Delete All Waypoints, or Reset All Settings.** Those are NOT steps in this job. Do not erase the park map or the named points.

## A. Turn off automatic recording

Do this once before collecting routes.

1. Turn on the Garmin.
2. Press **MENU** twice.
3. Select **Setup**. Press **ENTER**.
4. Select **Recording**. Press **ENTER**.
5. Select **Auto Start**. Press **ENTER**.
6. Select **Off**. Press **ENTER**.
7. Press **QUIT** to return to the main menu.

**Check:** The Garmin should not begin a new track on its own after you finish or clear a recording.

## B. Set the Garmin to save GPX tracks

Do this once. It makes saved tracks easier to bring into ExpertGPS.

1. Press **MENU** twice.
2. Select **Setup** → **Recording** → **Advanced Setup**.
3. Select **Output Format**.
4. Select **FIT and GPX** (the device may show **GPX/FIT**).
5. Press **QUIT** to return to the main menu.

**Do not** change the map, coordinates, waypoint names, or symbols.

## C. Remove old saved tracks

**MSB has already brought the old Garmin tracks into the master map.** You do not need to copy those old tracks again. Only delete old tracks. **If you just recorded a new cable route that has NOT been handed in, stop and ask the crew lead before deleting anything.**

1. Press **MENU** twice.
2. Select **Recorded Activities**. Press **ENTER**.
3. Select one **old** activity that has already been used. Press **ENTER**.
4. Press **MENU**.
5. Select **Delete**. Press **ENTER**.
6. Confirm the delete choice shown on the Garmin.
7. Repeat for the other old activities.

If you also see **Saved Tracks**, ask the crew lead which old tracks to remove. For an old saved track approved for deletion: select **Saved Tracks** → select the track → **MENU** → **Delete**, then confirm.

### Clear the track being recorded now

**Only do this if there is no new route that still needs to be handed in.**

1. Press **MENU** twice.
2. Select **Recording Controls**. Press **ENTER**.
3. Use the arrow buttons to choose the recording-controls tab.
4. Select the **trash can** or **Discard** option.
5. Select **Clear** to confirm.

**Check:** The old track lines are gone. Your park picture and named points are still there.

## D. Record one cable route

At the **start** of the cable:

1. Go to the starting point.
2. Wait for the Garmin to show a good GPS location.
3. Press **MENU** twice.
4. Select **Recording Controls**. Press **ENTER**.
5. Choose **Start** (green play symbol). Press **ENTER**.
6. Walk the cable path toward the other end.

At the **end** of the cable:

7. Stop walking.
8. Open **Recording Controls** again.
9. Choose **Stop** (red stop symbol). Press **ENTER**.
10. Choose **Save** (disk symbol). Press **ENTER**.
11. Give the recording a name, then select **Done** or **Save**, as shown.

**Use the exact names of the starting and ending points:**

| Cable | Name to type | Example |
| --- | --- | --- |
| Power | `HV first-point to second-point` | `HV PANEL 09 to LPFC-01` (only if it is a power cable) |
| Network | `NET first-point to second-point` | `NET PANEL 09 to LPFC-01` |

If you are not sure of either point name, **do not guess**. Tell the crew lead where the cable begins and ends.

**Check:** Find the new recording under **Recorded Activities**. Make sure it was saved before starting the next cable.

## E. Give the recording to the GIS engineer

1. Leave the park picture, waypoint list, and custom icons on the Garmin.
2. Tell the GIS engineer that the new route is ready.
3. The GIS engineer copies the saved recording into ExpertGPS.
4. The engineer cleans up the track and puts the approved route into the master map.

**Do not** delete the new recording until the GIS engineer confirms it was received.

## If something goes wrong

- **The Garmin starts recording by itself:** Go back to Section A and check **Auto Start = Off**.
- **You cannot find Stop or Save:** Open **Recording Controls**. Do not clear the track. Ask the crew lead.
- **You see the wrong waypoint icon:** Do not rename the waypoint. Tell the GIS engineer.
- **A waypoint or the park picture is missing:** Stop. Do not reset the Garmin.
- **You are unsure which old track to delete:** Leave it alone and ask the crew lead.

## Before giving this SOP to technicians

**Field check still required:** The MSB GIS lead must confirm on the actual GPSMAP 66sr that Section A disables automatic recording, Sections C and D show the named buttons, and a sample track can be started, stopped, saved and found under Recorded Activities. Do not mark this SOP CURRENT until that check passes.

## Related documents

- [Garmin engineering field workflow](../engineering/Garmin_Field_Survey_Workflow.md) — engineering rules behind this procedure.
- [Site Infrastructure / GIS](../README.md) — return to the GIS project.
