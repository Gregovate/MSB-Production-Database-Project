# Folder Alignment Engineering

This is the engineering starting point for the Folder Alignment subsystem.

Use this area when changing, troubleshooting, validating, or recovering Folder Alignment classification, parser-snapshot input handling, Google Drive comparison behavior, report generation, safety rules, or updater behavior.

Ordinary operation belongs in the [Folder Alignment](../README.md) operator portal.

## Current Engineering Authority

- [Folder Alignment Engineering Design](Folder_Alignment_Engineering_Design.md)
- [Park Infrastructure Non-LOR Root — Folder Alignment Boundary](Park_Infrastructure_Non_LOR_Root_2026-09-07.md)

## Implementation

The current implementation remains in the subsystem root, including:

- `folder_alignment.py`
- current report-generation code
- PreviewBackground updater code
- repository-root launchers such as `run_folder_check.ps1`

Do not move or rewrite working implementation merely to make the documentation tree look uniform.

## Engineering Boundary

Folder Alignment owns:

- parser-snapshot evidence used for alignment;
- deterministic Stage/Sub-stage/Scene classification;
- conflict/ambiguity reporting;
- read-only Google Drive inventory/comparison behavior;
- worklist/report behavior; and
- the bounded additive PreviewBackground updater contract.

The controlled top-level folder:

```text
41 Park Infrastructure-PI
```

is an intentional **non-LOR** Setup/Procedure root under `Display Folders`. It must remain outside Stage/Sub-stage/Scene classification. Its leading `41` is a human sort aid only; the space after `41` deliberately avoids the active top-level `NN-...` Stage candidate pattern.

Do not infer Stage 41 from this folder, and do not use lack of wired inventory as evidence that an existing Stage belongs here. `40-CommandCenter`, for example, remains a real Stage even when its Preview has no wired inventory items.

Google Drive / Display Folder maintenance procedures own the human document/folder changes performed after review. Setup and Deployment owns which reusable tasks are assigned to Stage/Scene versus Site-wide / Infrastructure scope.

## Documentation Layout

```text
Folder_Alignment/
├── README.md                  operator/user portal
├── operatorSOP/
├── engineering/
│   ├── README.md              this engineering handoff
│   ├── Folder_Alignment_Engineering_Design.md
│   ├── Park_Infrastructure_Non_LOR_Root_2026-09-07.md
│   └── Internal_Web_Backbone_Handoff.md
└── images/                    subsystem documentation images when needed
```

## Intranet Integration

Every converted subsystem must provide a handoff to `Gregovate/MSB-Internal-Web-Backbone` so `my.sheboyganlights.org` can be repaired when authoritative operator navigation changes.

See [Internal Web Backbone Handoff](Internal_Web_Backbone_Handoff.md).

## Related Systems

- [Google Drive / Display Folder Operations](../../../../00_Project_Overview/Google_Drive/README.md)
- [Google Drive Engineering](../../../../00_Project_Overview/Google_Drive/engineering/README.md)
- [LOR Data Extraction](../../README.md)
