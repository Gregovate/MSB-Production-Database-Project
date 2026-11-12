# Site-wide Setup Procedure Root Design — 2026-09-07

| Document control | Value |
|---|---|
| Status | DESIGN DIRECTION — Issue #122; not yet Production deployed |
| Owner | Setup and Deployment |
| Scope | Non-LOR Setup work such as park-wide site power, street lights, breakers, and other infrastructure tasks with no appropriate Stage/Scene owner |

## Problem

Setup Session has a demonstrated class of critical reusable work that does not belong to any LOR Stage or Scene and must not be forced into one merely to obtain a Procedure path.

Examples identified during Manager review include:

- remove street lights where required for show operation;
- convert street-light circuits to show power by switching approved fuses;
- turn on site breakers; and
- other genuinely park-wide infrastructure work with no appropriate Stage/Scene owner.

These are real Setup tasks because they require intentional planning, may have prerequisites/resources, can be missed, and produce useful annual execution history. They are not LOR-authored work and should not derive identity or filesystem placement from LOR Preview/Scene evidence.

A task does **not** become Site-wide merely because it has no wired inventory items. `40-CommandCenter`, for example, is a legitimate Stage with its own current LOR Preview even though that Preview may contain no wired inventory items. Command Center Setup tasks and Procedures remain Stage-40 work when Stage 40 is the correct operational owner.

## Required boundary

The existing Stage/Scene Procedure contract remains authoritative for LOR/physical-area-scoped documentation:

```text
<Stage / Sub-stage / Scene root>/
    marker
    Procedures/
        marker
        Inspection/
        Setup/
            Archive/
            images/
            SourceDocs/
        Takedown/
            Archive/
            images/
            SourceDocs/
```

Site-wide/infrastructure Setup work needs the **same Procedure subsystem structure and marker behavior**, but its documentation root must be resolved from explicit Setup task scope rather than from LOR Stage/Scene context.

Do not create a fake Stage, fake Scene, fake LOR Preview, or LOR-derived folder merely to host these documents.

## Approved controlled non-LOR root

Keep the documentation in the existing Google Shared Drive `Display Folders` repository so Setup does not create a second unrelated document repository.

The approved folder is:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI\
    _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    Procedures\
        _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
        Inspection\
        Setup\
            Archive\
            images\
            SourceDocs\
        Takedown\
            Archive\
            images\
            SourceDocs\
```

The leading `41` keeps this folder adjacent to the existing numbered park-area folders in normal Windows/Google Drive sorting. **The space after `41` is deliberate.**

Current Folder Alignment recognizes top-level Stage candidates using the `NN-...` form. Therefore:

```text
41 Park Infrastructure-PI
```

remains outside the Stage-folder classifier while still sorting in the intended location.

`PI` is a human-facing Park Infrastructure code only. It is not an LOR Stage short code and does not establish Stage 41.

The shared FieldWiring/Procedure structured-scope resolver remains unchanged. It starts from known database/LOR Stage context and does not enumerate the Display Folders root looking for this folder.

## Resolution model

For site-wide Setup tasks, the flow is:

```text
Reusable Setup task
    -> explicit Site-wide / Infrastructure scope
    -> controlled 41 Park Infrastructure-PI root
    -> validate root marker
    -> validate Procedures marker
    -> fixed Procedures/Setup branch
    -> current direct published PDF(s)
    -> Captain / Perform Work screen
```

The non-LOR root is selected server-side from governed Setup context. Browser input must not become an arbitrary filesystem path.

This is an extension of the Procedure-root contract, not a second generic filesystem resolver. The existing Stage/Sub-stage/Scene resolver remains unchanged for LOR/area-scoped work.

## Procedure ownership and field presentation

Site-wide Setup Procedures remain field-facing Setup Instructions and use the same source/published rules as Stage/Scene Setup Instructions:

- current published PDF/rendered document is the normal Captain/field copy;
- editable Google Doc or other source remains Manager/contributor maintenance material;
- `Archive` and `SourceDocs` remain outside normal field presentation;
- Setup-local `images` remains the supporting image location; and
- multiple current PDFs may exist when that is genuinely useful, but the Setup application should present the Procedure(s) applicable to the selected task rather than requiring the Captain to browse unrelated documents.

## Integration with Setup Session

Site-wide/infrastructure tasks participate in the normal Setup model:

- reusable task identity and ordering;
- reusable global Setup planning baseline;
- annual planned-order override;
- prerequisites;
- resources/equipment;
- rolling-horizon scheduling;
- parallel crew lanes;
- Captain progress/completion;
- current material/location context where applicable; and
- annual historical learning.

They do **not** require LOR membership.

Scheduling remains fully available because Setup Session schedules reusable/annual task records, not LOR folders.

## Engineering work still required

Before Production deployment:

1. create and mark `41 Park Infrastructure-PI` according to the Google Drive operator procedure;
2. verify Setup task scope identifies park-wide/no-Stage work without inventing a Stage/Scene;
3. verify Procedure-root resolution safely consumes only the approved non-LOR root;
4. keep tests proving LOR Stage/Scene resolution remains unchanged;
5. keep tests proving arbitrary browser filesystem paths cannot select a non-LOR root;
6. validate Captain-screen current published PDF presentation from a site-wide task; and
7. update any remaining documentation authority that still assumes all Setup Procedure roots are Stage/Scene roots.

## Related authority

- `Docs/00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md`
- `Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/engineering/Park_Infrastructure_Non_LOR_Root_2026-09-07.md`
- `System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md`
- `Docs/00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md`
- `Procedures/Application/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/10_Setup_Resolver_Canonical_Documentation_Root_2026-08-28.md`
- Issue #122
