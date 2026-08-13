# 00 - Google Drive Folder Structure

**Project:** Making Spirits Bright Production Database

| Item | Value |
|------|-------|
| Document | 00 - Google Drive Folder Structure |
| Revision | 1.3 Draft |
| Date | 2026-08-12 |
| Author | Greg Liebig |
| Status | Draft |

---

# Purpose

The Light-O-Rama (LOR) system is the primary authoring environment used to design and maintain the annual Making Spirits Bright Christmas display.

LOR is **not** the production database, nor is it the authoritative location for engineering documentation.

Instead, LOR is one component of a larger engineering information system consisting of:

- Google Shared Drive – Display Folders
- Google Shared Drive – Seasonal Folders
- LOR Preview Authoring
- V7 Parser
- Production PostgreSQL Database
- Operational Applications
- `my.sheboyganlights.org` field access

Each system has a specific responsibility. Together they provide the complete engineering and operational information system used to design, build, install, maintain, and operate the annual display.

This document provides the architectural overview of the Google Drive engineering repository and establishes the governing filesystem contracts used to organize and locate engineering information.

---

# Governing Principles

1. Organize by physical location first.
2. Stage, Sub-stage, and Scene roots use one identical standardized structure.
3. Display folders use a smaller standardized structure.
4. `PreviewBackground` is a stable LOR preview-background asset location and is expected at Stage, Sub-stage, Scene, and Display scope.
5. Stage/Scene helper folders use standardized locations so applications can locate published documentation reliably.
6. Stage wiring markups are stored in the standardized `Wiring` structure.
7. Procedures are stored in the standardized `Procedures` structure.
8. Photographs are stored in the standardized `Photos` structure.
9. Historical information must be preserved while the legacy Google Drive tree is reconciled. Existing files must not be deleted merely because an older folder no longer belongs to the current standard.
10. The Production Database indexes identities, relationships, and document access information but does not replace the Google Drive engineering repository.
11. QR codes identify stable MSB records; they must not encode fragile Google Drive paths or individual document URLs.
12. New documentation should follow this organizational standard even when legacy material has not yet been reorganized.

---

# System Architecture

```text
Physical Display / QR code
        |
        v
my.sheboyganlights.org
        |
        v
Production Database
        |
        +-----------------------------+
        |                             |
        v                             v
LOR-derived relationships      Google Drive document index
                                      |
                                      v
                           Google Drive engineering documents
```

LOR remains the authoring source for current Stage / Scene / Display organization. The Google Shared Drive remains the permanent engineering-document repository. PostgreSQL provides stable identities and relationships needed by operational applications. `my.sheboyganlights.org` is the field-access presentation layer.

---

# Information Repositories on the Google Drive

## Google Shared Drive: Display Folders

The Engineering Repository is stored within the Google Shared Drive named **Display Folders**.

Although the shared drive retains its historical name, it contains engineering information for Stages, Sub-stages, Scenes, individual Displays, wiring documentation, procedures, photographs, fabrication drawings, and supporting engineering resources.

At a high level:

```text
Display Folders
└── Stage
    ├── Standard Stage structure
    ├── Optional Sub-stage using the same structure
    ├── Optional Scene using the same structure
    └── Display folders using the Display structure
```

The Google Drive is the authoritative source for engineering documentation.

## Seasonal Repository - Shared Drive - Seasonal Folders

The Seasonal Repository contains information specific to an individual operating season, such as sequences, videos, statistics, event planning, and other annual operational files.

---

# Standard Stage / Sub-stage / Scene Structure

A Stage, formal Sub-stage, and real Scene use the **same root-level structure**.

```text
<Stage / Sub-stage / Scene>\
│
├── PreviewBackground\
│
├── Photos\
│   ├── Current\
│   └── Historical\
│
├── Procedures\
│   ├── Inspection\
│   │
│   ├── Setup\
│   │   ├── Archive\
│   │   ├── images\
│   │   └── SourceDocs\
│   │
│   └── Takedown\
│       ├── Archive\
│       ├── images\
│       └── SourceDocs\
│
└── Wiring\
    ├── BackgroundStage\
    │   └── SourceDocs\
    └── MusicalStage\
        └── SourceDocs\
```

`Procedures\Inspection` is intentionally unstructured. Standard child folders are not defined beneath it.

`Procedures\SourceDocs` does not exist as a generic Procedures-root contract. Source documents that belong to Setup or Takedown belong inside that procedure branch.

Stage, Sub-stage, and Scene may also contain child Display folders.

---

# Standard Display Structure

A Display folder uses a smaller standard structure and does **not** automatically receive the Stage/Scene `Procedures` or `Wiring` trees.

```text
<Display>\
├── PreviewBackground\
└── Photos\
    ├── Current\
    └── Historical\
```

A Display may exist directly beneath a Stage or beneath a real Scene/Sub-stage.

A Display's parent scope determines where shared Stage/Scene procedures and wiring are resolved. The Display folder itself remains lightweight unless a future approved contract adds other Display-specific branches.

---

# Example Complete Hierarchy

One Stage with one Stage-level Display, one Scene, and one Display inside that Scene looks like this:

```text
24-Traditional Christmas-TC\
│
├── PreviewBackground\
├── Photos\
│   ├── Current\
│   └── Historical\
├── Procedures\
│   ├── Inspection\
│   ├── Setup\
│   │   ├── Archive\
│   │   ├── images\
│   │   └── SourceDocs\
│   └── Takedown\
│       ├── Archive\
│       ├── images\
│       └── SourceDocs\
├── Wiring\
│   ├── BackgroundStage\
│   │   └── SourceDocs\
│   └── MusicalStage\
│       └── SourceDocs\
│
├── Stage-Level Display\
│   ├── PreviewBackground\
│   └── Photos\
│       ├── Current\
│       └── Historical\
│
└── 24-Example Scene\
    ├── PreviewBackground\
    ├── Photos\
    │   ├── Current\
    │   └── Historical\
    ├── Procedures\
    │   ├── Inspection\
    │   ├── Setup\
    │   │   ├── Archive\
    │   │   ├── images\
    │   │   └── SourceDocs\
    │   └── Takedown\
    │       ├── Archive\
    │       ├── images\
    │       └── SourceDocs\
    ├── Wiring\
    │   ├── BackgroundStage\
    │   │   └── SourceDocs\
    │   └── MusicalStage\
    │       └── SourceDocs\
    └── Scene-Level Display\
        ├── PreviewBackground\
        └── Photos\
            ├── Current\
            └── Historical\
```

---

# PreviewBackground Contract

`PreviewBackground` is the stable location for images intentionally used as LOR Preview/Scene background files.

It is expected at all four scope types:

```text
Stage\PreviewBackground\
Sub-stage\PreviewBackground\
Scene\PreviewBackground\
Display\PreviewBackground\
```

The purpose is to prevent LOR `BackgroundFile` paths from depending on arbitrary loose images that may later be renamed, deleted, or relocated.

`PreviewBackground` is a local asset folder. Its presence on a Display does **not** make that Display a full documentation scope and does not imply `Procedures` or `Wiring` beneath the Display.

The current additive updater may create a missing `PreviewBackground` folder only inside an already-existing deterministically resolved Stage, Sub-stage, Scene, or Display folder. It must never create the parent scope, move content, rename content, delete content, or overwrite content.

---

# Stage

A Stage represents a physical location within the park and serves as the primary organizational unit of the Engineering Repository.

Stage-level documentation applies to the Stage as a whole and should be accessible from any Display currently assigned to that Stage.

---

# Sub-stages

Some large Stages are divided into formal physical Sub-stages.

Example:

```text
07-Whoville-WV
└── 07a-Who Forest-WF
```

A Sub-stage uses the same standardized root structure as a Stage and Scene.

---

# Scenes

Scenes are authoring and organizational units used by LOR. A real Scene may be a useful engineering-documentation scope when wiring, procedures, photographs, or preview-background assets apply to the Scene as a whole.

Scenes do not define physical Display identity.

The current deterministic Scene naming/resolution contract is being validated by Folder Alignment before it is promoted into parser or broader naming standards.

---

# Display Folders

A Display folder represents one physical Display when a dedicated folder exists.

The standard Display root is intentionally small:

```text
PreviewBackground\
Photos\Current\
Photos\Historical\
```

Not every LOR Display is required to have a Google Drive folder. The system must not create a Display folder merely because the parser contains a Display identity.

When a Display folder already exists, the standardized Display structure may be validated and added according to controlled migration rules.

Folder paths must not be treated as permanent Display identity.

---

# Procedures Contract

Standard procedure locations at Stage/Sub-stage/Scene scope are:

```text
Procedures\Inspection\
Procedures\Setup\
Procedures\Takedown\
```

`Inspection` is intentionally unstructured.

Setup and Takedown use the same internal pattern:

```text
Setup\
├── Archive\
├── images\
└── SourceDocs\

Takedown\
├── Archive\
├── images\
└── SourceDocs\
```

Current approved field-facing files belong directly in the applicable `Setup` or `Takedown` folder. `Archive`, `images`, and `SourceDocs` are support/source areas and are not the normal field presentation set.

Legacy folders named `Maintenance`, `Operations`, generic `Procedures\SourceDocs`, or older Photo categories may still exist. They must be preserved until their contents are reviewed. The current standard does not authorize automatic deletion or relocation of those files.

---

# Wiring Contract

The standardized wiring branches remain:

```text
<Stage / Sub-stage / Scene>\Wiring\BackgroundStage\
<Stage / Sub-stage / Scene>\Wiring\MusicalStage\
```

Each branch may contain a `SourceDocs` subfolder for working/source material.

FormView established the proven pattern of resolving wiring from structured LOR context and stable Google Drive locations.

---

# Photo Contract

The standardized photo structure is intentionally simple.

For Stage/Sub-stage/Scene and Display:

```text
Photos\Current\
Photos\Historical\
```

Legacy `Photos\Setup`, `Photos\Takedown`, `Photos\Reference`, or other historical categories may remain during migration and must not be deleted automatically.

---

# Legacy Organization and Migration Safety

The Engineering Repository has evolved over many years. Existing Stages may contain historical folder names, nested groupings, archived material, and earlier standardized structures that no longer match the current contract.

The migration principle is:

> Add the new canonical structure where safe; preserve existing material until its contents are reviewed.

Current automation may therefore create an approved missing folder such as `PreviewBackground` without deleting any old folder.

Any later cleanup of obsolete folder names must be content-aware and separately reviewed.

---

# Google Docs: Authoring vs Presentation

Google Docs remain useful as collaborative authoring material. The architecture separates editable source documents, standardized filesystem discovery, and future field presentation through `my.sheboyganlights.org`.

Normal field users should not need to know the Google Drive hierarchy.

---

# QR-Based Internet Access Requirement

Each physical Display may carry a QR code representing its stable MSB Display identity.

The QR code shall not encode a mapped-drive path, current Google Drive folder path, individual Google Doc URL, or LOR Preview filename.

Instead:

```text
QR code
    |
    v
stable Display identity
    |
    v
current database relationships
    |
    +--> Display record
    +--> current Stage
    +--> applicable Scene/Sub-stage when relevant
    |
    v
my.sheboyganlights.org documentation page
```

Moving or renaming a folder must not invalidate the physical QR code.

---

# Production Database

The Production Database indexes and relates information contained within the Google Shared Drive. It does not replace engineering documentation.

Where Google Drive documents are exposed through the web application, the database may maintain stable identifiers or an index required for Internet access. Fragile full mounted-drive paths must not become the primary relational identity.

---

# Related Documentation

- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [LOR System Overview](01_LOR_System/00_Project_Overview/00_LOR_System_Overview.md)
- [Preview Authoring](01_LOR_System/01_Preview_Authoring/B_Building_Preview_Howto.md)
- [V7 LOR Data Extraction](01_LOR_System/02_Data_Extraction/README.md)
- [Folder Alignment Engineering Design](../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [FormView](01_LOR_System/04_FormView/README.md)
- [Production Database System Blueprint](02_Production_Database/01_System_Architecture/A_System_Blueprint.md)
- [Documentation Index](README.md)

---

# Summary

The Google Shared Drive provides the permanent engineering record for Making Spirits Bright.

Stage, Sub-stage, and Scene roots use one standard structure containing `PreviewBackground`, `Photos`, `Procedures`, and `Wiring`. Display folders use the smaller `PreviewBackground` plus `Photos\Current` and `Photos\Historical` structure.

`PreviewBackground` gives LOR a stable background-image location at every scope that may own a Preview/Scene background. Existing historical folders and files remain protected during migration; additive automation must not delete or reorganize them automatically.
