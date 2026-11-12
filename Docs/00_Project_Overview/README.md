# MSB Production Database Project Overview

This area provides the high-level entry points for the MSB Production Database Project.

Operator procedures and engineering documentation are intentionally separated within subsystems that need both. The Project Overview itself remains a standalone overview/navigation area; it does not receive empty operator/engineering folders merely for consistency.

## Start Here

- [LOR System Overview](00_LOR_System_Overview.md) — high-level view of the LOR-to-Production-Database workflow.
- [Production Database System Overview](01_Production_Database_System_Overview.md) — purpose, authority boundaries, permanent identities, and major operational areas.
- [Google Drive / Display Folder Operations](Google_Drive/README.md) — operator portal for Stage/Scene folder repair, markers, Setup publishing, legacy alignment, and related document-maintenance work.
- [Folder Alignment](../01_LOR_System/02_Data_Extraction/Folder_Alignment/README.md) — operator portal for generating and reviewing the read-only Documentation Alignment Worklist.

## Google Drive / Display Folders

### Operator / Contributor

Use:

- [Google Drive / Display Folder Operations](Google_Drive/README.md)

for actual Google Drive folder/document maintenance tasks.

### Engineering

Use:

- [Google Drive Engineering](Google_Drive/engineering/README.md)

for filesystem contracts, resolver/path behavior, integration design, and technical handoff material.

The older Google Drive document paths are retained temporarily as compatibility pointers while current inbound links are repaired.

## Folder Alignment

Folder Alignment is a separate subsystem with its own owner boundary:

- [Folder Alignment Operator Portal](../01_LOR_System/02_Data_Extraction/Folder_Alignment/README.md)
- [Folder Alignment Engineering](../01_LOR_System/02_Data_Extraction/Folder_Alignment/engineering/README.md)

Folder Alignment produces/reviews the worklist. Google Drive procedures own the human folder/document changes made from that worklist.

## Other Current Engineering References

- [Google Workspace Application Read Identity](05-Google_Workspace_Application_Read_Identity.md) — shared Google Workspace read-identity purpose and permission boundary.
- [Operator UI Message Contract](06-Operator_UI_Message_Contract.md) — engineering/application contract for plain-language field-facing messages and technical-code separation.

## Related Systems

- [LOR System Documentation](../01_LOR_System/README.md)
- [Production Database Documentation](../02_Production_Database/README.md)
- [LOR2DB](../../LOR2DB/README.md)
