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

This document provides the architectural overview of the Google Drive engineering repository and establishes the governing principles used to organize and locate engineering information. It defines where engineering information belongs and the filesystem contracts that applications may rely upon. It does not define the detailed content of individual engineering documents.

---

# Governing Principles

The following principles apply throughout the project.

1. Organize by physical location first.
2. Documentation belongs at the organizational level to which it applies: Stage, Substage, Scene, shared Display group, or individual Display.
3. Not every LOR Display requires its own Google Drive folder. Multiple Displays may legitimately use one shared documentation folder, and some Displays may require no dedicated folder.
4. Stage, Substage, and Scene roots use the same standardized helper-folder structure so applications can locate published documentation reliably. Display folders use a smaller standardized helper structure.
5. Stage wiring markups are stored in the standardized `Wiring` structure.
6. Procedures are stored in the standardized `Procedures` structure.
7. Photographs are stored in the standardized `Photos` structure.
8. Historical information remains with the Stage, Scene, shared group, or Display it documents until it can be reorganized safely.
9. The Production Database indexes identities, relationships, and document access information but does not replace the Google Drive engineering repository.
10. QR codes identify stable MSB records; they must not encode fragile Google Drive paths or individual document URLs.
11. New documentation should follow this organizational standard even when legacy material has not yet been reorganized.

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

The QR code is the stable entry point into that system. It is not the document locator itself.

---

# Information Repositories on the Google Drive

## Google Shared Drive: Display Folders

The Engineering Repository is stored within the Google Shared Drive named **Display Folders**.

Although the shared drive retains its historical name, it contains much more than individual Display folders. It is the primary engineering repository for the Making Spirits Bright project and contains engineering information for Stages, Substages, Scenes, shared Display groups, individual Displays, wiring documentation, procedures, photographs, fabrication drawings, and supporting engineering resources.

Information stored within the Engineering Repository evolves over many years and remains valid across multiple show seasons.

At a high level:

```text
Display Folders
└── Stage
    ├── Standard Stage structure
    ├── Optional Substage using the same structure
    ├── Optional Scene using the same structure
    ├── Shared documentation folders when required
    └── Individual Display folders using the Display structure when required
```

The Google Drive is the authoritative source for engineering documentation.

## Seasonal Repository - Shared Drive - Seasonal Folders

The Seasonal Repository contains information specific to an individual operating season.

Examples include:

- LOR Sequences
- Show Videos
- Car Counter Data
- Annual statistics
- Event planning
- Other seasonal operational files

Unlike the Engineering Repository, these assets naturally belong to a specific show year.

---

# Physical Organization

The physical display is organized by **Stages** such as `05-Festive Trees-FT`.

Large Stages may optionally contain **Substages** and/or **Scenes**.

Stages, Substages, and Scenes use the same standardized helper-folder structure:

```text
Stage / Substage / Scene
│
├── PreviewBackground/
│
├── Photos/
│   ├── Current/
│   └── Historical/
│
├── Procedures/
│   ├── Inspection/
│   ├── Setup/
│   │   ├── Archive/
│   │   ├── images/
│   │   └── SourceDocs/
│   └── Takedown/
│       ├── Archive/
│       ├── images/
│       └── SourceDocs/
│
├── Wiring/
│   ├── BackgroundStage/
│   │   └── SourceDocs/
│   └── MusicalStage/
│       └── SourceDocs/
│
└── Display / shared-documentation folders as required
```

`Procedures\Inspection` is intentionally unstructured.

Display folders use the smaller standardized helper structure:

```text
Display
│
├── PreviewBackground/
└── Photos/
    ├── Current/
    └── Historical/
```

Each Stage represents a physical area within the park and serves as the primary organizational unit of the Engineering Repository.

Within a Stage may exist:

- individual Display folders
- shared Display/documentation folders
- formal Substages
- optional Scene folders
- Stage wiring
- Stage procedures
- Stage photographs
- historical archives

Not every Stage currently follows the same internal organization. The repository contains historical structures accumulated over many years. Those structures remain evidence and must not be reorganized automatically.

---

# Stage

A Stage represents a physical location within the park.

Stages are durable identities used throughout the engineering repository and production database.

Stage-level documentation applies to the Stage as a whole and should be accessible from any Display currently assigned to that Stage.

---

# Substages

Some large Stages are divided into formal physical Substages.

Example:

```text
07-Whoville-WV
└── 07a-Who Forest-WF
```

Substages represent real physical divisions and use the same standardized helper-folder structure as Stages and Scenes.

---

# Scenes

Scenes are authoring and organizational units used by LOR.

Scenes may represent:

- an entire Stage
- a formal Substage
- a logical grouping of Displays

Examples include:

- Christmas Vacation
- Christmas Story
- Nightmare Before Christmas
- Throwing Bears
- Sliding Penguins

Scenes simplify Preview authoring and provide a useful documentation scope when wiring, procedures, photographs, or other engineering information applies to a Scene as a whole rather than to one Display.

Scenes do not define physical Display identity.

---

# Display and Shared Documentation Folders

An individual Display folder is the engineering record for one physical Display when that Display requires dedicated documentation.

The standardized Display helper structure is intentionally smaller than the Stage / Substage / Scene structure:

```text
Display
│
├── PreviewBackground/
└── Photos/
    ├── Current/
    └── Historical/
```

Display folders do not receive the standardized `Procedures` or `Wiring` helper trees.

Existing Display-specific engineering drawings, fabrication information, manuals, supporting documentation, or other historical material remain valid engineering records and must not be deleted merely because the standardized Display helper structure is smaller.

However, the repository must **not** assume a one-to-one relationship between an LOR Display and a Google Drive folder.

Valid cases include:

1. one Display with one dedicated folder;
2. multiple Displays sharing one documentation folder;
3. a Display documented entirely at Stage or Scene level and therefore requiring no dedicated folder.

This distinction is important for repeated or highly similar elements such as large groups of tree wraps or other components that are individual LOR Displays but are installed and documented as one Stage-level system.

Folder paths must therefore not be treated as Display identity.

---

# Standard Helper Folders Are Application Contracts

The standardized `PreviewBackground`, `Wiring`, `Procedures`, and `Photos` structures are not merely organizational preferences. They are application-facing filesystem contracts.

Applications may use a known Stage or Scene context together with these standardized relative locations to discover the engineering material that applies to that context.

The general pattern is:

```text
known Stage / Scene context
        |
        v
standard helper folder
        |
        v
published engineering material
```

This allows software to locate documentation without storing a fragile full Windows path for every file.

## PreviewBackground helper path

`PreviewBackground` is the stable location for images intentionally used as LOR Preview/Scene background files.

It exists at every scope that may own a preview background:

```text
<Stage>\PreviewBackground\
<Substage>\PreviewBackground\
<Scene>\PreviewBackground\
<Display>\PreviewBackground\
```

The purpose is to prevent LOR `BackgroundFile` paths from depending on arbitrary loose images that may later be renamed, deleted, or relocated.

## Wiring helper paths

FormView established the proven wiring-location contract.

The LOR Preview contains a `BackgroundFile` reference. The parser preserves that value. FormView uses the selected Preview and `BackgroundFile` to resolve the active published wiring-image directory.

The standardized wiring branches are:

```text
<Stage or Scene>\Wiring\BackgroundStage\
<Stage or Scene>\Wiring\MusicalStage\
```

`SourceDocs` contains working/source material and is not part of the published field-image set.

Wiring remains context-specific because Background/Static and Musical wiring can legitimately be different.

## Procedure helper paths

Procedure discovery follows the same location-contract principle, but procedures normally apply to the physical Stage or Scene rather than to an LOR Preview type.

Standard procedure locations are:

```text
<Stage or Scene>\Procedures\Inspection\
<Stage or Scene>\Procedures\Setup\
<Stage or Scene>\Procedures\Takedown\
```

There may be more than one procedure document in any of these folders.

The system must support a **list of applicable documents**, not a single Setup/Takedown/Inspection URL field.

`Procedures\Inspection` is intentionally unstructured.

Setup and Takedown source material belongs under the corresponding branch:

```text
<Stage or Scene>\Procedures\Setup\SourceDocs\
<Stage or Scene>\Procedures\Takedown\SourceDocs\
```

`SourceDocs` material is not intended for direct presentation to field users.

## Photo helper paths

The standardized photo locations are:

```text
<Stage or Scene>\Photos\Current\
<Stage or Scene>\Photos\Historical\
```

Display folders use the same two photo categories:

```text
<Display>\Photos\Current\
<Display>\Photos\Historical\
```

These paths allow applications and operators to distinguish current field references from historical material.

---

# Google Docs: Authoring vs Presentation

Google Docs are currently useful as the collaborative authoring format for many procedures. They are not the presentation standard for the future field application.

The architecture separates those responsibilities:

```text
Google Doc
    = editable source/published document

Standard Procedures folder
    = discovery/location contract

my.sheboyganlights.org
    = standardized field presentation and navigation
```

A procedure may remain a Google Doc while the application presents a consistent Stage/Scene page containing links to all applicable procedures.

Document formatting inside Google Docs may be standardized separately. The ability to find and present the correct document must not depend upon perfect Google Doc formatting.

---

# QR-Based Internet Access Requirement

A primary project goal is to make engineering records available through `my.sheboyganlights.org` from the park or anywhere Internet access is available.

Each physical Display may carry a QR code representing its stable MSB Display identity.

The QR code shall **not** encode:

- a mapped-drive path;
- a current Google Drive folder path;
- an individual Google Doc URL; or
- an LOR Preview filename.

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
    +--> applicable Scene/Substage when relevant
    |
    v
my.sheboyganlights.org documentation page
```

Moving or renaming a folder must not invalidate the physical QR code.

## Stage-level inheritance

Scanning the QR code on any Display assigned to a Stage shall provide access to the applicable Stage-level engineering records.

For Setup and similar procedures, the volunteer normally thinks in terms of the entire physical Stage. The application shall therefore present Stage-level Setup information without requiring the volunteer to understand the distinction between LOR Musical and Background Preview types.

Multiple Setup instructions are valid and shall be presented as a list.

## Wiring context

Wiring is more specific.

When both wiring contexts exist, the field interface shall present a plain-language choice rather than requiring the volunteer to understand LOR Preview terminology.

Conceptually:

```text
Wiring
├── Background / Static Displays
│   └── uses the BackgroundStage wiring context
└── Musical Displays
    └── uses the MusicalStage wiring context
```

Internal engineering names such as `BackgroundStage` and `MusicalStage` may remain in the filesystem and data model, but the field UI should explain the choice in task-oriented language.

A single Display QR code is sufficient. The user selects the applicable wiring context after reaching the Stage documentation interface.

---

# Procedures: Publishing Rule

For the standardized procedure structure, files placed directly in the applicable operational folder are considered published procedure material for that scope:

```text
Procedures\Inspection
Procedures\Setup
Procedures\Takedown
```

`Procedures\Inspection` is intentionally unstructured.

Working/source material for Setup and Takedown belongs under:

```text
Procedures\Setup\SourceDocs
Procedures\Takedown\SourceDocs
```

Applications should not present `SourceDocs` as normal field instructions.

This rule allows volunteers to maintain multiple procedure documents while giving applications a predictable discovery boundary.

---

# FormView as the Proven Predecessor

FormView is the proven predecessor for filesystem-assisted field documentation.

Its important architectural pattern is not its Windows desktop interface. The reusable pattern is:

```text
structured LOR context
        +
standardized Google Drive helper location
        |
        v
field-oriented presentation
```

The future Internet-accessible applications should preserve this successful separation while removing FormView's dependency on a mapped `G:` drive and direct local SQLite access.

The FormView engineering contract is documented under:

`Docs/01_LOR_System/04_FormView/`

---

# Production Database

The Production Database indexes and relates information contained within the Google Shared Drive.

It does not replace engineering documentation.

Engineering drawings, wiring documentation, procedures, photographs, manuals, and other engineering records remain within the Google Shared Drive where they can be maintained independently of the database.

The database provides stable identities and relationships needed by operational applications such as:

- QR scanning
- Internet-accessible field documentation
- FormView successor functionality
- Setup/Procedure access
- Reports
- Work Orders
- Label Printing
- GPS

Where Google Drive documents are exposed through the web application, the database may maintain stable document/folder identifiers or an index required for Internet access. Fragile full mounted-drive paths must not become the primary relational identity.

---

# Legacy Organization

The Engineering Repository has evolved over many years.

Existing Stages may contain historical folder names, nested groupings, archived material, and older organizational patterns that do not fully conform to the current standard.

Legacy structures remain valid evidence until they can be reorganized without loss of historical information.

Folder-alignment tools may identify and recommend changes, but filesystem changes remain human decisions.

All new engineering documentation should follow the organizational principles defined here.

---

# Related Documentation

- [LOR System Overview](01_LOR_System/00_Project_Overview/00_LOR_System_Overview.md)
- [Preview Authoring](01_LOR_System/01_Preview_Authoring/B_Building_Preview_Howto.md)
- [V7 LOR Data Extraction](01_LOR_System/02_Data_Extraction/README.md)
- [FormView](01_LOR_System/04_FormView/README.md)
- [Production Database System Blueprint](02_Production_Database/01_System_Architecture/A_System_Blueprint.md)
- [Documentation Index](README.md)

---

# Summary

The Google Shared Drive provides the permanent engineering record for Making Spirits Bright.

LOR provides the current authoring organization for Stages, Scenes, and Displays. The parser materializes that structure for downstream systems. The Production Database provides stable identities and relationships. `my.sheboyganlights.org` provides the field-access presentation layer.

Standard `PreviewBackground`, `Wiring`, `Procedures`, and `Photos` helper folders form a deliberate application-facing location contract. They allow software to discover the correct engineering material without treating human-readable full paths as permanent identity.

A Display QR code is the stable entry point. Stage-level Setup information is presented as a Stage-oriented list. Wiring remains context-specific and presents a plain-language Background/Static versus Musical choice when both contexts exist.

Together these rules preserve the useful engineering-document architecture proven by FormView while making the system suitable for Internet-accessible field use.