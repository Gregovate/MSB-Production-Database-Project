# Google Drive Engineering

This is the engineering starting point for the Google Shared Drive **Display Folders** integration.

Use this area when changing, troubleshooting, validating, or recovering the filesystem/path behavior used by Folder Alignment, Preview Authoring, Field Wiring, Procedures, and related Production Database integrations.

Ordinary document-maintenance work belongs in the [Google Drive / Display Folder Operations](../README.md) operator portal.

## Current Engineering Authorities

- [Google Drive Engineering Overview](Google_Drive_Engineering_Overview.md)
- [Google Drive Path Resolution Contract](Google_Drive_Path_Resolution_Contract.md)
- [Google Workspace Application Read Identity](../../05-Google_Workspace_Application_Read_Identity.md)
- [Folder Alignment Engineering](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/engineering/README.md)
- [FieldWiring Engineering](../../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [Setup and Deployment Engineering](../../../02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md)
- [Shared Field Context Resolution Contract](../../../02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)

The former Project Overview paths for the Google Drive overview and path contract are compatibility pointers only. Do not add new engineering links to those old paths.

## Authority Boundary

Engineering documentation owns subjects such as:

- Stage/Sub-stage/Scene/Display path classification;
- LOR `BackgroundFile` interpretation;
- filesystem/path-resolution rules;
- marker-validation behavior;
- Field Context resolution;
- application discovery/exclusion rules;
- Production Database identity relationships;
- read-only Google filesystem integration;
- implementation dependencies and failure behavior; and
- accepted architecture and recovery/acceptance evidence.

Operator SOPs should state the required folder, filename, warning, or verification step without reproducing this engineering explanation.

## Current Subsystem Layout

```text
Google_Drive/
├── README.md                  operator/user portal
├── operatorSOP/
│   ├── README.md              operator procedure index
│   └── ...
├── engineering/
│   ├── README.md              this engineering handoff
│   ├── Google_Drive_Engineering_Overview.md
│   ├── Google_Drive_Path_Resolution_Contract.md
│   └── Internal_Web_Backbone_Handoff.md
└── images/                    repository documentation images owned by this subsystem
```

## Image Ownership

Repository screenshots, diagrams, and other documentation images that belong specifically to Google Drive / Display Folder documentation should be stored under this subsystem's `images/` folder rather than a global `Docs/images/` collection.

The current Google Drive overview, path contract, and converted operator procedures were checked during this proof conversion and do not currently embed Markdown images, so no existing image asset needed to move for this subsystem.

This repository `images/` folder is **not** the same thing as runtime Google Drive folders such as `Procedures\Setup\images`.

## Intranet Integration

See [Internal Web Backbone Handoff](Internal_Web_Backbone_Handoff.md). The source documentation conversion and the deployed intranet repair are tracked separately.

## Related Governance

- [Production Operational Documentation Rule](../../../../System_Documentation/Project_Rules/Operational_Documentation_Rule.md)
- [Documentation Conversion Tracker](../../../../System_Documentation/Project_Rules/Documentation_Subsystem_Conversion_Tracker.md)
- [Documentation Standards](../../../../System_Documentation/Standards/Documentation_Standards.md)
- [Document Control Standard](../../../../System_Documentation/Standards/Document_Control_Standard.md)
