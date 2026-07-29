# 00 - Google Drive Folder Structure

**Project:** Making Spirits Bright Production Database


| Item | Value |
|------|-------|
| Document | 00 - Google Drive Folder Structure |
| Revision | 1.1 Draft |
| Date | 2026-07-29 |
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
- V7 Import Parser
- Production PostgreSQL Database
- Operational Applications

Each system has a specific responsibility. Together they provide the complete engineering and operational information system used to design, build, install, maintain, and operate the annual display.

This document provides the architectural overview of those systems and establishes the governing principles used to organize engineering information. It defines where engineering information belongs rather than how individual engineering documents are created.

Detailed implementation standards are documented elsewhere.

---

# Governing Principles

The following principles apply throughout the project.

1. Organize by physical location first.
2. Documentation belongs with the asset it describes.
3. Every active display should have one authoritative Display Folder.
4. Stage wiring markups are stored in the standardized Wiring folder.
5. Historical information remains with the Stage or Display it documents.
6. The Production Database indexes engineering information but does not replace it.
7. New documentation should follow this organizational standard even when legacy material has not yet been reorganized.

---

# System Architecture

```text
Physical Park
      │
      ▼
Google Drive
      │
      ├──────────────────┐
      ▼                  │
LOR Preview Authoring    │
      │                  │
      ▼                  │
V7 Parser                │
      │                  │
      └─────────► Production Database
                         │
                         ▼
                   Applications
```

The Production Database serves as the integration point between the engineering repository and operational applications.

---

# Information Repositories on the Google Drive

The MSB project maintains two primary information repositories.

## Google Drive

The Google Drive is the permanent home for documentation related to the Making Spirits Bright display.

Although the shared drive is named **Display Folders**, it contains much more than individual display folders. It is organized to support the construction, installation, operation, and maintenance of the entire display.

Information stored in the Google Drive remains valid across multiple show seasons and serves as the permanent record for the display.

```text
Display Folders
└── Stage
    ├── Optional Substage
    │   └── Optional Scene
    └── Display Folders
```

### Google Shared Drive: Display Folders

The Engineering Repository is stored within the Google Shared Drive named **Display Folders**.

Although the shared drive retains its historical name, it serves as the primary engineering repository for the Making Spirits Bright project. It contains engineering information for the entire display system, including stage infrastructure, substages, scenes, display engineering records, wiring documentation, fabrication drawings, and shared engineering resources.

Information stored within the Engineering Repository evolves over many years and remains valid across multiple show seasons.

The repository is organized hierarchically:

- Stage
  - Optional Substage
  - Optional Scene
  - Display Folders

Both **Stages** and **Scenes** follow the same standardized organizational structure for shared documentation, including:

- Wiring
- Procedures
- Photos

Display Folders contain documentation specific to an individual physical display.

Additional engineering resources stored within the repository include:

- CAD drawings
- Inkscape artwork
- Visio diagrams
- Workshop drawings
- GPS information
- Arduino projects
- Logos
- Fonts
- Licenses
- Shared engineering resources

The Google Drive is the authoritative source for engineering documentation.

---

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

The physical display is organized by **Stages** (for example, `05-Festive Trees-FT`).

Large stages may optionally contain **Substages** and/or **Scenes**.

Stages and Scenes share the same standardized folder structure shown below.

```text
Stage / Scene
│
├── Wiring/
│   ├── BackgroundStage/
│   │   └── SourceDocs/
│   └── MusicalStage/
│       └── SourceDocs/
│
├── Procedures/
│   ├── Setup/
│   ├── Takedown/
│   ├── Maintenance/
│   ├── Operations/
│   └── SourceDocs/
│
├── Photos/
│   ├── Current/
│   ├── Setup/
│   ├── Takedown/
│   ├── Reference/
│   └── Historical/
│
└── Display Folders...
```

Each Stage represents a physical area within the park and serves as the primary organizational unit of the Engineering Repository.

Within a Stage may exist:

- Display folders
- Formal Substages
- Optional Scene folders
- Stage wiring
- Stage procedures
- Stage photographs
- Historical archives

Not every Stage currently follows the same internal organization.

This document defines the organizational standard toward which the repository will evolve.

---

# Stage

A Stage represents a physical location within the park.

Stages are permanent identities used throughout the engineering repository and production database.

---

# Substages

Some large stages are divided into formal physical substages.

Example:

07-Whoville-WV

contains

07a-Who Forest-WF

Substages represent real physical divisions.

---

# Scenes

Scenes are authoring and organizational units used by LOR.

Scenes are organizational workspaces that may represent:

- an entire Stage
- a formal Substage
- a logical grouping of displays

Examples include:

- Christmas Vacation
- Christmas Story
- Nightmare Before Christmas
- Throwing Bears
- Sliding Penguins

Scenes simplify preview authoring by dividing large or complex areas of the display into manageable workspaces.

As the engineering documentation continues to evolve, Scene folders also provide an appropriate location for scene-specific wiring documentation, background images, procedures, photographs, and other engineering information that applies to the scene as a whole rather than to an individual display.

Scenes improve preview authoring and documentation organization.

Scenes do not define physical display identity.

---

# Display Folders

Every active display should ultimately have a corresponding Display Folder.

The Display Folder is the engineering record for one physical display.

It may contain:

- engineering drawings
- fabrication information
- display-specific wiring
- display-specific procedures
- photographs
- manuals
- supporting documentation

Procedures should be stored at the organizational level to which they apply:

- Stage-wide procedures belong in the Stage folder.
- Substage-wide procedures belong in the Substage folder.
- Scene-specific procedures may belong in the Scene folder.
- Display-specific procedures belong in the Display folder.

Display folders may exist directly beneath a Stage, beneath a Substage, or within an optional Scene folder.

---

# Wiring

Each Stage contains a standardized Wiring folder.

Applications may rely upon this location. This location is intentionally standardized so software applications can reliably locate field wiring documentation.

The Wiring folder contains both published field documentation and the source documents used to generate those documents.

---

# Production Database

The Production Database indexes and relates information contained within the Google Shared Drive.

It does not replace engineering documentation.

Engineering drawings, wiring documentation, procedures, photographs, manuals, and other engineering records remain within the Google Shared Drive where they can be maintained independently of the database.

Instead, the Production Database provides operational access to that information through applications such as:

- QR scanning
- FormView
- Reports
- Work Orders
- Label Printing
- GPS

This approach allows engineering documentation and operational data to work together while preserving a single authoritative location for engineering information.

---

# Legacy Organization

The Engineering Repository has evolved over many years.

Existing stages may not fully conform to the standards described in this document.

Legacy structures remain valid until they can be reorganized without loss of historical information.

All new engineering documentation should follow the organizational principles defined herein.

---

# Related Documentation

- [LOR System Overview](01_LOR_System/00_Project_Overview/00_LOR_System_Overview.md)
- [Preview Authoring](01_LOR_System/01_Preview_Authoring/B_Building_Preview_Howto.md)
- [LOR Data Extraction and Troubleshooting](01_LOR_System/02_Data_Extraction/Troubleshooting.md)
- [Production Database System Blueprint](02_Production_Database/01_System_Architecture/A_System_Blueprint.md)
- [LOR Naming Data Contract](02_Production_Database/01_System_Architecture/C_LOR%20Naming%20Data%20Contract.md)
- [Production Database Structure](02_Production_Database/01_System_Architecture/D_Database_Structure.md)
- [Documentation Index](README.md)

---

---

# Summary

The Google Shared Drive provides the permanent engineering record for the Making Spirits Bright display.

The Light-O-Rama system provides preview authoring for the annual display.

The V7 Import Parser extracts authoritative preview information from LOR into the Production Database.

The Production Database integrates engineering information with operational data to support field applications, reporting, QR code access, labeling, maintenance, and future operational tools.

Together, these systems form the complete engineering information system used to design, build, install, maintain, and operate the Making Spirits Bright Christmas display.