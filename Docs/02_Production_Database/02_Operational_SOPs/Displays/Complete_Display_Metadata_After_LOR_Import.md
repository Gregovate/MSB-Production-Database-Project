# Complete Display Metadata After LOR Import

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Displays |
| Task | Complete Production Database metadata for a display after LOR/LOR2DB ingest |
| Audience | Production Database operators and managers |
| Status | DRAFT |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-08-09 |
| Keywords | display metadata, new display, LOR ingest, Directus, year built, frame, designer, theme, container |

## Purpose

Use this procedure after a new display has been created in LOR and successfully imported into the Production Database through LOR2DB.

LOR and LOR2DB create the database identity and LOR-derived information. This procedure adds the Production Database metadata that is not maintained in LOR.

Do not use this procedure to rename a display or redefine LOR show topology.

## Before You Start

Before completing the metadata:

- The new display must already exist in LOR.
- The LOR2DB ingest/reconciliation process must already have created the display in the Production Database.
- You must have permission to edit Display records in Directus.
- Have the known physical/production information for the display available, such as year built, frame type, designer, theme, and container assignment.

## Procedure

### 1. Open the Display area

In Directus, locate the **Display** section in the left menu.

![Directus main menu showing Display](/Docs/images/directus_menu_full.jpg)

The Display section currently includes operator bookmarks such as **Print Display Labels** and **Sorted by Display Name**.

![Directus Display menu](/Docs/images/directus_menu_container-displays.jpg)

Open **Sorted by Display Name** or the Display collection so you can locate the new display.

### 2. Find the new display

Use the search control in the upper-right corner of the Display list to search for the new display by name or ID.

![Directus Display search and list](/Docs/images/directus_display_search.png)

Open the correct display record.

### 3. Verify the imported identity fields

At the top of the display record, verify:

- **Display ID** — assigned automatically by the Production Database.
- **Display Name** — defined from the LOR source data.

![Directus display identity fields](/Docs/images/directus_display_section_01.png)

Do not change these fields as part of metadata entry.

Also verify the label controls:

- **Label Required** should normally remain enabled for a new physical display that requires an MSB display label.
- **Print Label** is not part of this procedure. Label printing is handled through the Label Printing procedure.

### 4. Confirm status and container assignment

Open **Display Status and Container Assigned**.

![Directus display status and container assignment](/Docs/images/directus_display_section_02.png)

For a new display that is part of the current show:

1. Confirm **Display Status ID** is **ACTIVE**.
2. Set **Container ID** to the container where the display is physically stored, if the correct container is known.

The container assignment must match the physical location of the display. Do not guess a container.

If the correct container is not known, leave the assignment for a manager or responsible operator to resolve rather than assigning an incorrect container.

### 5. Complete Display Details

Open **Display Details** and enter the known Production Database metadata.

![Directus Display Details fields](/Docs/images/directus_display_section_03.png)

Complete the applicable fields:

- **Year Built** — year the display was first introduced into the show.
- **Frame ID** — select the correct physical frame type.
- **Designer ID** — select the person who designed the display.
- **Theme ID** — select the appropriate display theme/category.
- **Amps Measured** — enter when a measured value is available.
- **Est Light Count** — enter when an estimated light count is available.
- **Dumb Controller** — complete only when applicable to a display animated without a normal controller.
- **Notes** — add useful Production Database information that does not belong in LOR naming/topology fields.

If a required Frame, Designer, Theme, or other reference value does not exist in the selection list, do not substitute an incorrect value. Have the missing reference value added by the database administrator or responsible manager.

### 6. Save the display record

Review the record for obvious errors, then save it in Directus.

## Expected Result

The new display should now have:

- its permanent database-assigned Display ID;
- its LOR-defined Display Name unchanged;
- ACTIVE status when appropriate;
- the correct container assignment when known;
- the available year, frame, designer, theme, electrical/light-count, controller, and notes metadata completed;
- Label Required set appropriately for later label printing.

The display is now ready for the next applicable operational tasks, such as label printing, container testing, or later setup work.

## If Something Is Wrong

### The display is not in Directus

Do not manually create a duplicate Display record.

Verify that the LOR2DB ingest/reconciliation process has completed successfully for the LOR source containing the display.

### The Display Name is wrong

Do not correct the LOR-defined name here as routine metadata.

The source name should be corrected through the responsible LOR/LOR2DB process so the authoritative source and Production Database remain aligned.

### The correct container is not listed

Do not choose a different container just to complete the field. Have the container/reference data reviewed.

### A Frame, Designer, or Theme value is missing

Do not use a near match. Ask the database administrator or responsible manager to add the missing reference value.

## Related Documents

- [Display Operational SOPs](README.md)
- [Production Database Operational SOPs](../README.md)
- [Label Printing](../Label_Printing/)
- [LOR2DB Ingest Engineering Handoff](../../01_System_Architecture/02_LOR2DB_Ingest/README.md)
- [Containers and Storage Engineering Handoff](../../01_System_Architecture/04_Containers_and_Storage/README.md)
