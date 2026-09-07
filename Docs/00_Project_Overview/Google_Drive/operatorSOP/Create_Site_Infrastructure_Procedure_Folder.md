# Create the Park Infrastructure Procedure Folder

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders |
| Task | Create the controlled non-LOR Procedure root for park-wide Setup work |
| Audience | Production documentation maintainers and Setup Managers |
| Status | CURRENT FOR SETUP V0.3 BUILD-OUT |
| Owner | Setup and Deployment / Production documentation owner |
| Last Reviewed | 2026-09-07 |
| Keywords | Park Infrastructure, site-wide, Setup, Procedures, Google Drive, non-LOR, street lights, breakers, power |

[↑ Google Drive / Display Folder Operations](../README.md)

## Purpose

Use this procedure to create and maintain the controlled Google Drive folder that owns **park-wide / infrastructure Setup Procedures** which do not belong to any existing LOR Stage, Sub-stage, or Scene.

Examples include:

- remove street lights where required for show operation;
- convert street-light circuits to show power by switching the approved fuses;
- turn on site breakers; and
- other park-wide infrastructure work that has no appropriate Stage/Scene owner.

These are real Setup tasks, but they are **not LOR tasks** and must not be assigned to a fake Stage or Scene merely to obtain a Procedure path.

Do not use this folder merely because a Stage has no wired inventory items. `40-CommandCenter`, for example, is a real Stage with its own current LOR Preview even though that Preview may contain no wired inventory items. Command Center Setup tasks and Procedures remain Stage-40 work when Stage 40 is the correct operational owner.

## Approved Folder Name and Location

Create this folder directly under the existing Google Shared Drive **Display Folders** root:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

The leading `41` keeps this operational folder beside the numbered park-area folders in normal Windows/Google Drive sorting.

The space after `41` is intentional. The active Folder Alignment Stage inventory recognizes top-level Stage candidates in the `NN-...` form, so:

```text
41 Park Infrastructure-PI
```

remains outside that Stage pattern.

`PI` is a human-facing Park Infrastructure code only. It is not an LOR Stage short code and does not create Stage 41.

Do not create an LOR Preview, Stage, Scene, `PreviewBackground`, or `Wiring` branch for this folder merely to satisfy another system.

## Create This Folder Structure

```text
41 Park Infrastructure-PI/
│
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
└── Procedures/
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    │
    ├── Inspection/
    │
    ├── Setup/
    │   ├── Archive/
    │   ├── images/
    │   └── SourceDocs/
    │
    └── Takedown/
        ├── Archive/
        ├── images/
        └── SourceDocs/
```

This intentionally reuses the existing Procedure subsystem structure while omitting Stage/LOR-only helpers that do not apply.

There is no generic `Procedures\SourceDocs` folder. Setup and Takedown each own their own `SourceDocs` folder.

## Marker Locations

Use the exact standard marker filename:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Required markers:

```text
41 Park Infrastructure-PI root       YES
Procedures                           YES
Procedures\Inspection               NO
Procedures\Setup                    NO
Procedures\Takedown                 NO
Procedures\Setup\images             NO
Procedures\Takedown\images          NO
Archive                              NO
SourceDocs                           NO
```

The root marker identifies the approved controlled non-LOR documentation root. The `Procedures` marker guards the Procedure subsystem branch.

Do not add markers to every child folder.

## What Goes Where

### Current published field PDFs

Put the current PDFs directly in:

```text
41 Park Infrastructure-PI\Procedures\Setup
```

Examples may eventually include:

```text
Street Light Removal.pdf
Street Light Power Conversion.pdf
Site Power and Breaker Setup.pdf
```

The exact current document names may evolve. The folder contract is authoritative; this procedure does not require those literal PDFs to exist.

### Editable source documents

Put editable working/source material in:

```text
41 Park Infrastructure-PI\Procedures\Setup\SourceDocs
```

A Google Doc may remain the editable source while its published PDF is the normal Captain/field copy.

### Historical or superseded material

Put superseded Setup material in:

```text
41 Park Infrastructure-PI\Procedures\Setup\Archive
```

Archived files are not current field authority.

### Procedure images

Put Setup Procedure images in:

```text
41 Park Infrastructure-PI\Procedures\Setup\images
```

Do not create a separate competing image folder for the same Procedure family.

## Procedure

1. Open `G:\Shared drives\Display Folders`.
2. Confirm there is not already another reviewed Park Infrastructure root.
3. Create or use `41 Park Infrastructure-PI` exactly as shown.
4. Create the complete `Procedures` structure shown above.
5. Add the standard marker directly in the `41 Park Infrastructure-PI` root.
6. Add the standard marker directly in `41 Park Infrastructure-PI\Procedures`.
7. Do **not** add markers to `Inspection`, `Setup`, `Takedown`, `images`, `Archive`, or `SourceDocs`.
8. Put current published Setup PDFs directly in `Procedures\Setup`.
9. Put editable Setup source documents in `Procedures\Setup\SourceDocs`.
10. Put superseded/historical Setup material in `Procedures\Setup\Archive`.
11. Put Procedure-local Setup images in `Procedures\Setup\images`.
12. Do not create an LOR Preview, fake Stage/Scene, `PreviewBackground`, or `Wiring` branch for this root unless a later approved use independently requires one.
13. Verify the completed structure against the checklist below.

## Build Checklist

- [ ] `G:\Shared drives\Display Folders\41 Park Infrastructure-PI` exists.
- [ ] The root marker is present.
- [ ] `Procedures` exists and has its marker.
- [ ] `Inspection`, `Setup`, and `Takedown` exist.
- [ ] `Setup\Archive`, `Setup\images`, and `Setup\SourceDocs` exist.
- [ ] `Takedown\Archive`, `Takedown\images`, and `Takedown\SourceDocs` exist.
- [ ] No extra child-folder markers were added.
- [ ] No fake Stage, Scene, Preview, or LOR naming was introduced.
- [ ] Current PDFs will be stored directly in `Procedures\Setup`.
- [ ] Editable Setup sources will be stored in `Procedures\Setup\SourceDocs`.
- [ ] Historical/superseded Setup material will be stored in `Procedures\Setup\Archive`.

## Setup Application Boundary

The Setup Session application identifies tasks assigned here as **Site-wide / Infrastructure** work.

The intended resolution path is:

```text
Reusable Setup task
    -> Site-wide / Infrastructure scope
    -> controlled 41 Park Infrastructure-PI root
    -> validate root marker
    -> validate Procedures marker
    -> Procedures\Setup
    -> current published field PDF(s)
```

LOR Stage/Scene resolution is not involved in this path.

Scheduling is still fully available because Setup Session schedules reusable/annual task records; scheduling does not require an LOR Stage.

The browser must never accept an arbitrary filesystem path from an operator to select a Procedure root.

## If Something Is Wrong

- **A task already has a legitimate Stage/Scene owner:** use that existing Stage/Scene scope instead of moving the task here merely because it lacks wired inventory.
- **A Stage/Scene folder was created for Park Infrastructure:** stop; do not add fake LOR context. Use this non-LOR root.
- **The folder already exists with legacy material:** do not overwrite or bulk-move files. Review the material before restructuring it.
- **A current PDF is in `Archive` or `SourceDocs`:** it will not be treated as the normal current field publication; move/re-publish only after review.
- **You are unsure whether a task is park-wide or Stage/Scene work:** keep the task unscope-corrected and review it before moving documentation.

## Related Documents

- [Add and Verify MSB Display Folder Marker Files](Add_Verify_Marker_Files.md)
- [Publish a Current Setup Instruction](Publish_Current_Setup_Instruction.md)
- [Folder Alignment Park Infrastructure non-LOR boundary](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/engineering/Park_Infrastructure_Non_LOR_Root_2026-09-07.md)
- [Site-wide Setup Procedure Root Design](../../../02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/11_Site_Wide_Setup_Procedure_Root_Design_2026-09-07.md)
- [Google Drive Engineering](../engineering/README.md)
