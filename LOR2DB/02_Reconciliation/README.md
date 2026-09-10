# LOR Reconciliation

This directory is the operator and engineering home for routine **LOR -> Production Database reconciliation** after a validated V7 parser snapshot has been ingested.

## Current operator authority

Use:

- [LOR Production Import and Reconciliation Procedure](00_LOR_Production_Import_and_Reconciliation_Procedure.md)
- [LOR Manual Reconciliation Runbook](02_LOR_Manual_Reconciliation_Runbook.md) only when the normal browser workflow cannot be used and the runbook explicitly applies.

The normal browser entry point is the protected LOR2DB application documented under `LOR2DB/Application/`.

## Scene documentation structure integrity

A Scene addition or Scene rename is not complete merely because the LOR Scene row can be promoted to PostgreSQL. The Scene may also be a controlled Google Drive documentation scope used by Setup, Procedures, FieldWiring, and other consumers.

The **primary gate for new/renamed Scene folder integrity belongs in LOR2DB reconciliation** because this is the workflow where the Scene change is discovered, reviewed, and promoted.

Required direction:

```text
validated V7 snapshot
    -> reconciliation identifies new/renamed Scene
    -> LOR2DB asks the paired Windows LOR runner to inspect G:\Shared drives\Display Folders
    -> determine whether this Scene is a controlled Scene documentation scope
    -> when controlled Scene scope is required:
         verify expected Scene folder
         verify required source-folder markers
         verify current Stage/Sub-stage/Scene scaffold
    -> PASS: Scene may continue through reconciliation
    -> FAIL: reconciliation remains blocked with a direct folder/marker repair action
```

The Linux LOR2DB API must not attempt to inspect the workstation `G:` path directly. The existing paired Windows LOR runner is the established boundary for authenticated Google Drive filesystem access.

A controlled reusable `scene_folder_template` is required so an approved missing/new Scene scope can be created consistently rather than hand-building every folder and marker. The template and any create/repair command must follow the current Google Drive Stage/Sub-stage/Scene scaffold and marker SOP; it must not invent a second folder standard.

Folder Alignment remains useful as a secondary read-only audit and broader documentation worklist, but it is **not** the primary reconciliation gate for Scene additions/renames.

Tracked in GitHub Issue #143.

## Reconciliation implementation

Current promotion procedures and migrations live under `reconciliation/`. In particular:

- `current_procedures/P1_stage_promotion.sql`
- `current_procedures/P2_display_promotion.sql`
- `current_procedures/P3_scene_promotion.sql`
- `current_procedures/P4_scene_display_promotion.sql`

The browser/API remains the normal operator interface; PostgreSQL procedures remain the governed Production writers.

## Safety boundary

Reconciliation changes Production identity and relationships. Follow the current reconciliation procedure and database/runbook gates. Do not improvise direct writes merely to make a folder or Scene appear to line up.
