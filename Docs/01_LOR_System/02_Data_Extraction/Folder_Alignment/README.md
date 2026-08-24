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

## Engineering

For design, resolver/classification behavior, report model, regression fixtures, or code changes, use:

- [Folder Alignment Engineering](engineering/README.md)

## Important Boundary

Folder Alignment owns the **read-only comparison and worklist**.

Google Drive / Display Folder procedures own the human changes made after reviewing the worklist. Do not duplicate those maintenance procedures here.
