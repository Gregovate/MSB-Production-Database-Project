# Site-wide Setup Procedure Root Design — 2026-09-07

| Document control | Value |
|---|---|
| Status | DESIGN DIRECTION — Issue #122; not yet Production deployed |
| Owner | Setup and Deployment |
| Scope | Non-LOR Setup work such as Command Center, WiFi, site power, street lights, and other site-wide/infrastructure tasks |

## Problem

Setup Session now has a demonstrated class of critical reusable work that does not belong to any LOR Stage or Scene and must not be forced into one merely to obtain a Procedure path.

Examples identified during Manager review include:

- deliver and set up the Command Center trailer;
- install the WiFi antenna in the tree, including boom-lift work and aiming toward the remote endpoint;
- install the gateway and test the internet connection;
- deploy hotspots after internet connectivity is verified;
- remove street lights;
- convert street lights to show power by switching fuses; and
- turn on breakers / perform other site-wide power-enablement work.

These are real Setup tasks because they require intentional planning, may have prerequisites/resources, can be missed, and produce useful annual execution history. They are not LOR-authored work and should not derive identity or filesystem placement from LOR Preview/Scene evidence.

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

## Proposed controlled non-LOR root

Keep the documentation in the existing Google Shared Drive `Display Folders` repository so Setup does not create a second unrelated document repository.

The working folder direction is:

```text
G:\Shared drives\Display Folders\Site Infrastructure\
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

`Site Infrastructure` is intentionally not named like an `NN-Name-XY` Stage and is not part of LOR hierarchy classification.

The final folder name must be accepted as part of Folder Alignment / Google Drive governance before Production use. The important contract is the **non-LOR controlled root**, not this literal display name alone.

## Resolution model

The current Procedure application correctly appends only the fixed Procedure branch after a structured Stage/Scene root has been resolved. That behavior should be reused.

For site-wide Setup tasks, the intended flow is instead:

```text
Reusable Setup task
    -> explicit Site-wide / Infrastructure scope
    -> controlled non-LOR documentation root
    -> validate root marker
    -> validate Procedures marker
    -> fixed Procedures/Setup branch
    -> current direct published PDF(s)
    -> Captain / Perform Work screen
```

The non-LOR root must be selected server-side from governed Setup context. Browser input must not become an arbitrary filesystem path.

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

## Engineering work still required

Before Production deployment:

1. accept the controlled non-LOR folder name/location through Google Drive / Folder Alignment governance;
2. extend the Setup task-scope contract to identify site-wide/infrastructure work without inventing a Stage/Scene;
3. extend Procedure-root resolution so approved Setup-only roots can reuse the existing marker + `Procedures/<task>` adapter safely;
4. add tests proving LOR Stage/Scene resolution remains unchanged;
5. add tests proving arbitrary browser filesystem paths cannot select a non-LOR root;
6. add Captain-screen tests for current published PDF presentation from a site-wide task; and
7. update the Stage Setup Documentation Standard / Google Drive Path Resolution Contract to recognize approved non-LOR Setup Procedure roots.

## Related authority

- `System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md`
- `Docs/00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md`
- `Procedures/Application/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/10_Setup_Resolver_Canonical_Documentation_Root_2026-08-28.md`
- Issue #122
