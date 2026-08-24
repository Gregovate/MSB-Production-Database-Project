# Google Drive Engineering

This is the engineering starting point for the Google Shared Drive **Display Folders** integration.

Use this area when changing, troubleshooting, validating, or recovering the filesystem/path behavior used by Folder Alignment, Preview Authoring, Field Wiring, Procedures, and related Production Database integrations.

Ordinary document-maintenance work belongs in the [Google Drive / Display Folder Operations](../../README.md) operator portal.

## Current Engineering Authorities

The current technical documents are still at their established paths while inbound links are repaired. They remain engineering references during this migration:

- [Google Drive Folder Structure — Engineering Overview](../../../00-Google_Drive.md)
- [Google Drive Path Resolution Contract](../../../02-Google_Drive_Path_Resolution_Contract.md)
- [Google Workspace Application Read Identity](../../../05-Google_Workspace_Application_Read_Identity.md)
- [Folder Alignment Engineering Design](../../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [FieldWiring Engineering](../../../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [Setup and Deployment Engineering](../../../../02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md)
- [Shared Field Context Resolution Contract](../../../../02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)

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

## Current Migration Note

The Google Drive documentation is being separated into:

```text
Google_Drive/
├── README.md                  operator portal
└── docs/
    ├── operatorSOP/           task procedures
    └── engineering/           engineering handoff and contracts
```

The older engineering documents remain at their existing paths during the link-repair phase. Do not create duplicate edited copies of those contracts here until the move is done deliberately and inbound links are updated.

## Related Governance

- [Production Operational Documentation Rule](../../../../../System_Documentation/Project_Rules/Operational_Documentation_Rule.md)
- [Documentation Standards](../../../../../System_Documentation/Standards/Documentation_Standards.md)
- [Document Control Standard](../../../../../System_Documentation/Standards/Document_Control_Standard.md)
