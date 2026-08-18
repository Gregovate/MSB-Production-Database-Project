# LOR Preview Authoring

This area contains the current operator-facing rules and procedures for creating and maintaining Light-O-Rama previews that can be safely used by the MSB production workflow.

## Start Here

| I want to... | Go to |
|---|---|
| Understand required Display and channel naming | [Naming Conventions](A_Naming_Conventions.md) |
| Build or update a Preview | [Building Preview How-To](B_Building_Preview_Howto.md) |
| Build or update the Master Musical Preview | [Master Musical Preview How-To](E_Master_Musical_Preview_Howto.md) |
| Create/publish Stage field-wiring images | [Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md) |
| Import the current approved Preview source before editing | [Preview Import Workflow](Preview_Import_Workflow.md) |
| Review the historical LOR-to-database naming contract | [Historical LOR Naming Data Contract](C_LOR_Naming_Data_Contract.md) |

The historical naming contract is preserved because it records early engineering decisions that connected LOR Comment naming, Stage codes, parser output, and Production Database ingestion. It is not the current authoring authority; current Display/channel naming rules are maintained in [Naming Conventions](A_Naming_Conventions.md).

---

## Current Authoring Model

The current musical workflow uses one annual/versioned **Master Musical Preview** rather than separate `RGB Plus Stage xx` musical previews.

Scene/documentation scope is resolved using the current deterministic naming and path rules:

```text
NN-Name-XY       -> Stage root
NNa-Name-XY      -> Sub-stage root
NN-Name          -> true Scene/documentation group
NNa-Name         -> true Scene/documentation group under the Sub-stage token
unprefixed name  -> Display/shared-group evidence
```

A sequencing Scene does **not** automatically create a Google Drive Scene folder.

For Master Musical Preview Scene backgrounds/path anchors, use the `PreviewBackground` helper under the scope that actually owns the background/documentation. See [Master Musical Preview How-To](E_Master_Musical_Preview_Howto.md).

---

## Google Drive Folder Boundary

Preview Authoring follows the current engineering-repository contract; it does not redefine it.

Key distinctions:

```text
PreviewBackground
    = normal Preview/Scene authoring background and scope evidence

Wiring\BackgroundStage
Wiring\MusicalStage
    = published field-wiring image directories
```

Stage, Sub-stage, and true Scene roots use the full helper structure. Existing Display folders use the smaller `PreviewBackground` / `Photos` structure. Not every LOR Display requires a dedicated Google Drive folder.

The controlled architecture is documented in:

- [Google Drive Folder Structure](../../00_Project_Overview/00-Google_Drive.md)
- [Folder Alignment Engineering Design](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)

---

## Preview Ownership and UserPreviewStaging

Programmers work from isolated working copies.

When authoring is complete, the candidate Preview is exported to:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

That is a candidate handoff location, not the controlled master.

The Preview Merger remains the required integrity-control design, but current production `--apply` is not yet approved. Do not overwrite the controlled master directly.

See [Preview Import Workflow](Preview_Import_Workflow.md) and [Preview Merger](../03_Preview_Merger/README.md).

---

## Important System Boundaries

Preview Authoring owns how operators create/edit Preview content and place the authoring/wiring assets required by the current contracts.

It does **not** own:

- Preview Merger implementation or production-apply approval;
- parser engineering or `.lorprev` XML interpretation;
- PostgreSQL ingest/reconciliation behavior;
- Google Drive folder redesign;
- FormView implementation; or
- the browser-based FieldWiring/FormView replacement.

Those remain separate controlled subsystems/projects.

The current FormView wiring workflow is intentionally preserved while the separate conversion project reconstructs and validates the successor. The wiring-background procedure documents only the operator-facing publication contract that Preview authors must continue to satisfy.

---

## Related Systems

- [Preview Merger](../03_Preview_Merger/README.md)
- [LOR Data Extraction](../02_Data_Extraction/README.md)
- [Folder Alignment](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [FormView](../04_FormView/README.md)
- [Wiring System Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md)

## Revision History

- 2026-08-17 — Reconciled navigation and subsystem boundaries with the current Display-folder hierarchy, Scene naming, Master Musical Preview, `PreviewBackground`, `UserPreviewStaging`, Preview Merger status, and separate Wiring/FormView conversion project.
