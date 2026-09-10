# Folder Alignment

This is the operator/user starting point for **Folder Alignment**.

Folder Alignment compares the current V7 parser snapshot with the Google Shared Drive **Display Folders** and produces a read-only Documentation Alignment Worklist. It does not move, rename, create, or delete Google Drive content.

## What Do You Need To Do?

- [Run Folder Alignment](operatorSOP/Run_Folder_Alignment.md)
- [Review the Folder Alignment Worklist](operatorSOP/Review_Folder_Alignment_Worklist.md)
- [Google Drive / Display Folder Operations](../../../00_Project_Overview/Google_Drive/README.md) — use after the worklist identifies a folder/document task that needs human action.

For the procedure index, see [Folder Alignment Operator Procedures](operatorSOP/README.md).

## Simple Workflow

```text
Current V7 parser snapshot
        |
        v
Run Folder Alignment
        |
        v
Review current HTML worklist
        |
        v
Choose one Stage / issue
        |
        v
Use the responsible Google Drive operator procedure
        |
        v
Run Folder Alignment again when a fresh worklist is useful
```

## LOR2DB Reconciliation Boundary

Folder Alignment is a **secondary read-only audit** for Stage/Sub-stage/Scene documentation structure. It is not the primary gate for a new or renamed LOR Scene.

When routine LOR reconciliation identifies a Scene addition or Scene rename, the mandatory structure check belongs in the **LOR2DB reconciliation system**. LOR2DB should use its paired Windows LOR runner to inspect the authenticated Google Drive `G:` mount and verify the expected Scene documentation root, required marker files, and current scaffold before Scene promotion/Finish is allowed.

Folder Alignment may report the same missing-folder/marker condition later as drift, but an operator should not first discover a broken Scene structure through Setup, FieldWiring, Procedures, or a later Folder Alignment report.

See GitHub Issue #143 for the tracked LOR2DB Scene-folder/template gate.

## Reserved Non-LOR Top-Level Folder

The Google `Display Folders` root now also contains this controlled Setup/Procedure root:

```text
41 Park Infrastructure-PI
```

This folder is **not** an LOR Stage, Sub-stage, or Scene. It intentionally has no LOR Preview and no Stage 41 database/LOR identity.

The leading `41` exists only to keep the folder in a useful human sort position next to the numbered park areas. The space after `41` is deliberate: the active Folder Alignment Stage inventory recognizes top-level Stage candidates using the `NN-...` form, so `41 Park Infrastructure-PI` remains outside that Stage pattern.

Folder Alignment must not suggest converting, renaming, or promoting this folder into a Stage merely because it is stored beside numbered Stage folders.

Use the Google Drive procedure [Create the Park Infrastructure Procedure Folder](../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md) for its controlled structure.

This does **not** change Stage 40 Command Center. `40-CommandCenter` remains a legitimate Stage and may own Setup tasks/Procedures even when its LOR Preview contains no wired inventory items.

## Engineering

For design, resolver/classification behavior, report model, regression fixtures, or code changes, use:

- [Folder Alignment Engineering](engineering/README.md)

## Important Boundary

Folder Alignment owns the **read-only comparison and worklist** for LOR-aligned Stage/Sub-stage/Scene documentation.

`41 Park Infrastructure-PI` is a governed non-LOR exception outside that hierarchy. Setup and Deployment owns the tasks assigned to that scope, while Google Drive / Display Folder procedures own its physical documentation structure.

Google Drive / Display Folder procedures own the human changes made after reviewing the worklist. Do not duplicate those maintenance procedures here.
