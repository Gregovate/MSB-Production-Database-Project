# Park Infrastructure Non-LOR Root — Folder Alignment Boundary — 2026-09-07

| Document control | Value |
|---|---|
| Status | CURRENT DESIGN BOUNDARY |
| Owner | Folder Alignment / Google Drive / Setup and Deployment |
| Folder | `G:\Shared drives\Display Folders\41 Park Infrastructure-PI` |
| Issue | #122 |

## Purpose

Document the controlled top-level Google Drive folder used for Setup work that has no appropriate LOR Stage/Sub-stage/Scene owner.

```text
41 Park Infrastructure-PI
```

This folder is part of the governed `Display Folders` repository but is intentionally **outside the LOR Stage/Sub-stage/Scene hierarchy**.

## Why the Name Looks This Way

The leading `41` exists only to keep the folder in the useful human sort position after the existing numbered park areas.

The space after `41` is deliberate:

```text
41 Park Infrastructure-PI
```

The active Folder Alignment implementation recognizes top-level Stage-folder candidates with:

```text
NN-...
```

Therefore `41 Park Infrastructure-PI` does not match the Stage-folder classifier.

`PI` is a human-facing Park Infrastructure abbreviation only. It is not an LOR Stage short code.

## LOR Boundary

No LOR Preview is created for this folder and there is no Stage 41 identity derived from it.

Folder existence alone does not create an LOR Stage.

Setup scheduling for tasks assigned to this scope is owned by Setup Session reusable/annual task records and does not require LOR membership.

Procedure lookup for no-Stage Setup tasks explicitly targets this governed folder and validates its marker plus its `Procedures` marker before exposing current Setup PDFs.

## What Belongs Here

Examples include genuinely park-wide/no-owner Setup work such as:

- removing street lights where needed for show operation;
- converting street-light circuits to show power by switching approved fuses;
- turning on site breakers;
- other park-wide infrastructure tasks that do not belong to one existing Stage or Scene.

Do not move a task here merely because it has no wired inventory items.

## Important Counterexample — Stage 40 Command Center

`40-CommandCenter` is a legitimate field Stage and remains part of the Stage hierarchy.

A current LOR Preview exists for Command Center even though that Preview may contain no wired inventory items. That does not invalidate Stage 40 and does not move Command Center Setup work into Park Infrastructure.

Command Center Setup tasks and Procedures should use Stage 40 when that is their appropriate operational owner.

## Folder Alignment Behavior

Folder Alignment should:

- continue classifying actual Stage roots from the established `NN-...` contract;
- ignore `41 Park Infrastructure-PI` as an LOR Stage candidate;
- not report its absence from LOR as a defect;
- not recommend renaming it into a Stage form; and
- leave Setup/Procedure ownership of this non-LOR root to Setup and Google Drive governance.

If a future Folder Alignment implementation widens its top-level folder classifier, this reserved non-LOR root must remain explicitly protected.

## Controlled Structure

The Google Drive operator procedure owns the folder structure:

- [Create the Park Infrastructure Procedure Folder](../../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md)

Current root:

```text
41 Park Infrastructure-PI\
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

No LOR Preview, `PreviewBackground`, or Wiring branch is required merely because the folder exists.

## Related Authority

- [Folder Alignment](../README.md)
- [Folder Alignment Engineering Design](Folder_Alignment_Engineering_Design.md)
- [Google Drive / Display Folder Operations](../../../../00_Project_Overview/Google_Drive/README.md)
- [Setup and Deployment](../../../../02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md)
- Issue #122
