# Stage Setup Documentation Standard

## Purpose

This project rule defines how field-facing Stage and Scene setup instructions are governed within the MSB Production Database Project.

Stage Setup Instructions are not the same document class as repository Operator SOPs. They are field-use documents for volunteers physically installing displays and Stage infrastructure in the park. They may consume Production Database information and be discovered through MSB applications, but their normal user experience must remain simple and Stage-oriented.

This rule governs ownership, source/published relationships, document identity, archive behavior, template use, and integration boundaries. It does not redesign the established Google Shared Drive Stage folder structure.

## Document Class

Use **Stage Setup Instruction** for documents that tell field volunteers how to physically install, position, assemble, connect, or verify a Stage, Scene, or applicable group of Displays during setup.

Do not classify these documents as repository Operational SOPs merely because they describe a procedure.

Repository Operator SOPs govern tasks performed inside MSB applications, database workflows, administrative systems, or other repository-owned operational processes. Stage Setup Instructions are field-facing documentation attached to the physical Stage/Scene organization.

## Existing Stage Folder Structure Is Authoritative

The existing Google Shared Drive **Display Folders** structure remains the organizational home for current field Setup documentation.

The exact Stage/Scene folder layout and migration procedure are governed by the current Google Drive document-organization procedure and Folder Alignment work. This standard does not authorize renaming, moving, or redesigning that structure.

Current Setup instructions belong in the established Stage or Scene `Procedures\Setup` location appropriate to what the instruction actually describes.

Legacy documents are being reconciled into the established current/archive structure through the separate document-alignment process. Do not independently move legacy documents based only on this standard.

## Stage, Scene, and Display Scope

Store and present a document at the smallest established physical/organizational scope that accurately owns the instruction:

- Stage-wide instruction -> Stage Setup location;
- Scene-specific instruction -> Scene Setup location;
- Display-specific engineering instruction -> the responsible Display documentation location when it truly applies only to that Display.

Do not create duplicate copies solely so each Display has its own copy of a shared Stage or Scene instruction.

A Stage or Scene may have more than one current Setup instruction.

## Source and Published Field Copy

Every current Setup instruction must have a clearly understood editable source and field-use presentation.

The preferred field experience is a simple current PDF or equivalent rendered document that volunteers can open without understanding Google Drive editing, Markdown, GitHub, repository structure, or database internals.

Where Markdown is used as the controlled template or source structure, the Markdown source remains a maintainable engineering/contributor artifact and the PDF is the field-use publication unless the project explicitly designates another source relationship.

Where a Google Doc remains the editable source, the system must identify it by a durable Google document identifier rather than depending on a copied `.gdoc` shortcut file or a fragile full URL embedded throughout the system.

Do not allow an exported PDF, Google Doc, Markdown file, and intranet rendering to silently become competing authorities. The owning workflow must identify which representation is edited and which is published/derived.

## Setup Instruction Template

Stage Setup Instructions use their own project-specific template rather than the generic repository Operational SOP format.

The controlled template lives under:

```text
System_Documentation/Templates/
```

The template should favor field usability:

- approved MSB branding/logo from a reusable public location;
- clear title and Stage/Scene identity;
- step-by-step numbered instructions;
- images adjacent to the steps they explain;
- warnings or important notes where needed;
- completion/verification guidance where useful;
- references/related documents when they materially help the crew;
- concise change history/document control appropriate to the published instruction.

Do not force engineering architecture, database detail, contributor workflow, or repository navigation into the field instruction.

A separate contributor/operator procedure must explain how to create, revise, archive, publish, and verify Stage Setup Instructions using the controlled template.

## Images and Supporting Assets

Setup-document images must have one predictable home associated with the Setup documentation they support so contributors do not have to guess among unrelated repository or Stage image locations.

For Setup-specific document assets, use the established Setup-local image location approved for the Stage documentation workflow. Do not create additional competing image folders for the same document family.

Reusable organization branding such as the MSB logo should come from one approved publicly accessible reusable asset location rather than being copied into every Stage Setup folder.

Images should appear next to the instruction step they clarify whenever practical.

The exact physical folder path for Setup images must remain aligned with the Stage-folder procedure being completed in the document-alignment work; this standard does not independently change that structure.

## Database Ownership and Document Resolution

The Production Database owns the durable identities and relationships needed to determine which Setup information applies to a scanned physical asset.

The database does not become the content-editing system for the field instructions merely because it can resolve them.

The intended relationship is:

```text
Display QR
    -> permanent Display identity
    -> Production Database relationships
    -> applicable Stage / Scene context
    -> durable Setup document reference(s)
    -> user-facing presentation
```

The exact database field/table used to store or resolve Google document IDs, published PDF references, or other durable document references must be engineered from the current schema and approved separately. This standard does not create or approve a new schema field by itself.

Do not derive document identity from a user-visible filename alone.

Do not require a QR code to contain a Google Drive folder path or direct document URL. The QR identifies the asset; the system resolves the current applicable documentation.

## my.sheboyganlights.org Presentation Boundary

`my.sheboyganlights.org` is the intended normal user-facing navigation layer for field access to this information.

The intranet may consume Production Database project metadata, README-driven navigation, database relationships, and document references, but it must present a simplified user experience appropriate to field volunteers.

For normal field use:

- do not require users to browse the GitHub repository;
- do not expose repository hierarchy unless the user deliberately enters a contributor/engineering path;
- present current Stage/Scene Setup documents, not archive material, by default;
- prefer a direct current PDF/rendered document or a simple list of current instructions when more than one applies;
- preserve a clear way back to the Stage/Display context rather than allowing ordinary navigation to strand the user in source-control views.

Repository organization and field navigation are related but are not required to look identical.

## Archive and Legacy Material

Legacy Setup documents are historical evidence until they have been reviewed.

The ongoing document-alignment procedure controls how legacy material is moved into the applicable archive location. Do not delete an older instruction simply because a current replacement exists or because its purpose is unclear.

Archived Setup documents:

- are not current field authority;
- should not appear in normal volunteer navigation;
- should remain recoverable for historical/reference purposes where useful;
- should retain enough identity to understand the Stage/Scene and what replaced them when known.

## Relationship to Wiring

Setup and Wiring share the established Stage-oriented documentation model but remain different document systems.

Wiring has its own LOR/FormView-derived contracts and `BackgroundStage` / `MusicalStage` behavior. Setup instructions must not be reorganized as Wiring documents, and Wiring must not be simplified into ordinary Setup procedure folders.

The proven reusable architectural idea is that structured system identity can resolve the correct field documentation without requiring the volunteer to understand where that documentation is stored.

## Navigation and Discovery

README portals and project engineering documentation may describe and index this system for contributors, but the field-user experience should be delivered through the intranet/QR workflow rather than normal GitHub browsing.

A field user scanning a Display should be able to reach the current applicable Setup instruction with minimal navigation.

A contributor should be able to determine from the repository:

- the governing standard;
- the current template;
- the procedure for creating/updating Setup instructions;
- the engineering contract for database/QR resolution;
- the responsible Google Drive organization procedure.

## Current Engineering Boundary

The following are agreed project direction, not authorization to invent implementation details:

- keep the established Stage/Scene Google Drive folder structure;
- continue legacy-document alignment through the existing Folder Alignment/document-organization work;
- use a dedicated Stage Setup Instruction template;
- maintain a separate contributor/operator procedure for using that template;
- keep field-facing Setup Instructions distinct from repository Operational SOPs;
- use Production Database identity/relationships to resolve applicable instructions;
- use `my.sheboyganlights.org` as the normal simplified field presentation layer;
- prefer current PDF/rendered field documents for UX when practical;
- preserve durable external document identity rather than depending on filenames, `.gdoc` pointer files, or manually maintained direct links.

Still unresolved and requiring engineering review:

- exact Google Doc / published PDF reference storage in PostgreSQL;
- exact current-vs-published relationship when a Google Doc and PDF both exist;
- exact scraper/API contract used by `my.sheboyganlights.org`;
- final Setup image-path rule as the Stage folder-alignment procedure is completed;
- final contributor workflow for generating/publishing PDFs from the controlled template/source.

## Related Documents

- [Document Control Standard](../Standards/Document_Control_Standard.md)
- [Linking and Navigation Standard](../Standards/Linking_and_Navigation_Standard.md)
- [Templates](../Templates/README.md)
- [Google Drive Document Organization Procedure](../../Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
- [Setup and Deployment Engineering](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../../Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/README.md)
- [Wiring System](../../Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
