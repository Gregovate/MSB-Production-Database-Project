# Shared Google Drive Filesystem Traversal Requirement — 2026-08-21

| Document control | Value |
|---|---|
| Status | RECONNAISSANCE REQUIREMENT — deployment architecture must preserve filesystem traversal |
| Applies to | FieldWiring, future Procedures applications, Folder Alignment-related server consumers, future database-backed field-document applications |
| Source repository | `Gregovate/MSB-Production-Database-Project` |
| Production-change status | NONE |

## Purpose

This document records a deployment requirement established during FieldWiring server reconnaissance:

> FieldWiring and future Procedure systems must be able to walk the structured Google Shared Drive `Display Folders` hierarchy as a filesystem.

The server-side Google Drive integration must therefore expose a stable directory tree with normal read/list/stat semantics. It must not be designed only as a narrow API that retrieves one pre-known file at a time.

## Existing Repository Contract

The Google Shared Drive named `Display Folders` is the authoritative engineering-document repository.

Current structured Stage/Sub-stage/Scene roots contain standardized helper folders including:

```text
PreviewBackground
Procedures
Wiring
Photos
```

The current approved database/application source roots are:

```text
PreviewBackground
Procedures
Wiring
```

Each approved source root is identified by:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

`Photos` is not a database/application source root under the current contract.

Applications must preserve the real hierarchy and apply the task-specific rules for the branch they own.

## Human Authoring and Maintenance Boundary

The server-side document filesystem exists to let database-backed applications **read and present** engineering information that people continue to author and maintain in Google Workspace.

Normal authorized MSB users should continue using the tools they already know, including Google Drive, Google Docs, normal folders, PDFs, images, and other approved document formats. They should not need to understand PostgreSQL, Directus, application APIs, filesystem mounts, or server internals merely to maintain field documentation.

The intended separation is:

```text
Authorized MSB users
    -> Google Workspace / Shared Drive
    -> create and maintain engineering documents in the controlled folder structure

Production Database
    -> stores permanent identities, relationships, scope, and application metadata

Server-side document filesystem
    -> behaves like another authorized read-only user of the same Shared Drive hierarchy

Field applications
    -> resolve the correct scope and present only the approved current content
```

PostgreSQL and Directus must not become the normal authoring environment for wiring images, procedures, Preview backgrounds, or other engineering documents merely because applications consume those documents.

The server-side Google identity should therefore behave, from the document repository's point of view, like an authorized MSB user with only the permissions required for application presentation. The implementation mechanism may differ from Windows Google Drive for desktop, but the visible source hierarchy and document ownership model must remain the same.

This boundary is intentional because many MSB contributors are not computer-science users. The engineering system must preserve familiar document-maintenance workflows rather than require volunteers to learn database or server terminology to update field information.

## Why Filesystem Traversal Is Required

### FieldWiring

FieldWiring resolves wiring/context images by combining current Production Database/LOR context with the actual folder structure.

It may need to:

- locate the current Stage root;
- locate a Scene beneath that Stage;
- verify source-folder markers;
- select `Wiring/BackgroundStage` or `Wiring/MusicalStage`;
- enumerate published images in the applicable branch;
- inspect `PreviewBackground` when no wiring image exists; and
- stop traversal at excluded boundaries such as `SourceDocs`.

The existing FieldWiring implementation already uses directory enumeration and bounded hierarchy traversal for this behavior.

### Procedures

The future procedure systems must use the same resolved Stage/Sub-stage/Scene hierarchy and then discover current published procedure content beneath branches such as:

```text
Procedures/Setup
Procedures/Takedown
Procedures/Inspection
```

There may be more than one applicable current procedure document. The application must therefore be able to enumerate directory contents rather than depend on one hard-coded document path.

Normal field presentation must exclude support/source content such as:

```text
Archive
SourceDocs
```

according to the responsible subsystem contract.

### Future applications

The server-side document source is shared infrastructure. Other future database-backed field/document applications may consume additional approved source branches without changing the physical Display QR identity or duplicating the Google hierarchy.

## Required Filesystem Behavior

The chosen server-side Google Drive mechanism must support, at minimum:

- directory existence tests;
- directory enumeration;
- bounded traversal beneath a known Stage/Sub-stage/Scene root;
- file existence/stat checks;
- normal file reads for published content;
- stable relative path construction;
- preservation of folder and file names;
- access to marker `.txt` files;
- access to current published JPG/PNG/PDF and other approved field-document formats as required by each subsystem; and
- deterministic failure when the Google source is unavailable.

The mount or synchronized local representation must preserve the source hierarchy closely enough that the existing Google Drive Path Resolution Contract remains valid after translating only the platform-specific root.

## Security and Access Boundary

The shared server-side document filesystem should be read-only from the perspective of normal field-presentation services.

The deployment must not allow FieldWiring or a normal Procedure presentation service to:

- rename Google Drive folders;
- move files;
- delete files;
- upload replacement files;
- create new source folders; or
- modify source-folder marker files.

Separate engineering/alignment tools that intentionally perform an approved additive update remain separate workflows and must not gain write permission merely because the field-presentation mount exists.

## Root Translation

Current LOR and Production Database path evidence may contain the Windows root:

```text
G:\Shared drives\Display Folders\...
```

A Linux server may expose the same logical tree at a root such as:

```text
/mnt/msb-display-folders/...
```

The application layer must translate only the known platform-specific root and preserve the remaining relative hierarchy.

Conceptually:

```text
G:\Shared drives\Display Folders\05-Festive Trees-FT\Wiring\BackgroundStage\image.png

                    -> relative hierarchy ->

05-Festive Trees-FT/Wiring/BackgroundStage/image.png

                    -> server root ->

/mnt/msb-display-folders/05-Festive Trees-FT/Wiring/BackgroundStage/image.png
```

Stored LOR/PostgreSQL path evidence must not be rewritten merely to accommodate Linux deployment.

## Architecture Consequence

The Google Drive connection should be treated as shared MSB engineering-document infrastructure rather than a FieldWiring-only image feed.

Conceptually:

```text
Google Workspace / Shared Drive: Display Folders
                    |
                    v
       shared read-only filesystem view
          on server infrastructure
                    |
       +------------+-------------+
       |            |             |
       v            v             v
 FieldWiring    Procedures     future apps
       |            |
       v            v
  Wiring /      Procedures /
PreviewBackground   task branches
```

Each application must still enforce its own source-marker, scope, publication, currentness, and exclusion rules.

## Relationship to Folder Alignment

Folder Alignment remains its own controlled engineering workflow and currently operates from the V7 parser SQLite snapshot plus the Google Drive tree.

This traversal requirement does not move Folder Alignment into PostgreSQL and does not authorize changing its read-only contract.

It establishes only that any future server-hosted consumer of the same Google Drive structure must receive a complete navigable hierarchy rather than a flattened or FieldWiring-specific file subset.

## Acceptance Requirement

Before accepting the server-side Google Drive mechanism, test that a read-only service account can:

1. list top-level Stage folders;
2. descend into one Stage and one Scene;
3. detect the marker in `Wiring`;
4. enumerate `Wiring/BackgroundStage` and `Wiring/MusicalStage` without entering `SourceDocs`;
5. detect the marker in `Procedures`;
6. enumerate current files in `Procedures/Setup`, `Procedures/Takedown`, and `Procedures/Inspection` while excluding source/archive branches from normal presentation;
7. read a representative wiring image and published procedure file; and
8. fail visibly and safely when the Google filesystem is unavailable.

No write operation is part of this acceptance test.

## Related Documents

- `Docs/00_Project_Overview/00-Google_Drive.md`
- `Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md`
- `Docs/00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md`
- `Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md`
- `Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md`
- `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Document_Publication_and_Currentness_Contract.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md`
