# Field Document Publication and Currentness Contract

| Document control | Value |
|---|---|
| Status | DRAFT — shared field-presentation architecture |
| Current revision | 2026-08-17 |
| Owner | MSB Database Administrator |
| Primary consumers | FieldWiring, Setup, Takedown, Testing procedures, future field-document functions |
| Schema/code status | Documentation only; no schema or application change authorized |

## Purpose

This document defines the common publication/currentness behavior for field documents reached through the shared Display scan/context workflow.

The shared Field Context resolver identifies the scanned asset and its current field hierarchy. The operator then chooses a task. The task-specific subsystem owns the content, while this contract defines the common rules for presenting and exporting current field documents.

The intended pattern is:

```text
Display QR
    -> permanent Display identity
    -> shared Field Context resolver
    -> operator chooses task
        -> task-specific current content
        -> browser presentation
        -> optional self-contained PDF field copy
```

The QR does not identify a particular document or report format.

## Shared Task Menu

A Display scan may lead to actions such as:

- Work Order;
- Field Wiring;
- Setup Instructions;
- Takedown Instructions;
- Testing Procedures; and
- future task-specific field functions.

The resolver and task menu are reusable. Each task retains its own content authority, folder branch, business rules, and appropriate scope.

## Content Ownership Remains Separate

This contract does not turn field documents into one generic document-management system.

Examples:

- Wiring owns wiring rows, wiring images, and wiring-context rules;
- Setup and Deployment owns Setup/Takedown procedures;
- Testing owns Testing procedures and testing workflow;
- Work Orders remain database-owned operational records rather than static procedure documents.

The shared presentation layer resolves and presents current information. It does not become the authority for the underlying content.

## Standard Folder Structure Is an Application Contract

The standardized Google Shared Drive Stage/Sub-stage/Scene folder structure is deliberately part of the engineering architecture.

Its consistency allows applications to combine a resolved physical scope with a known relative content branch instead of storing every field document or image inside PostgreSQL.

Conceptually:

```text
resolved Stage / Sub-stage / Scene
        |
        +--> Wiring\BackgroundStage
        +--> Wiring\MusicalStage
        +--> Procedures\Setup
        +--> Procedures\Takedown
        +--> Procedures\Inspection
        +--> other controlled helper branches
```

The exact task owns which branch is applicable, but the shared principle is that predictable folder organization remains the editable document/content layer.

Changing the standardized folder contract is therefore an application-impacting architectural change, not merely a cosmetic file-organization change.

## Do Not Turn PostgreSQL Into a Binary Document Store

PostgreSQL should store the durable identity, relationships, currentness metadata, and references needed to resolve field content. It should not become the editing/storage authority for copies of every procedure, PDF, wiring image, photograph, or other engineering file as opaque binary blobs.

The preferred separation is:

```text
PostgreSQL
    = identity + relationships + scope + currentness + durable references

Google Drive / controlled document storage
    = editable engineering documents + source images + published field assets

Browser application
    = resolution + presentation

Generated PDF
    = disposable/self-contained field publication
```

This preserves normal editing and document maintenance while allowing the database to determine what is current and applicable.

If implementation requires caching or generated-file storage for performance or offline delivery, that cache remains a derived delivery artifact. It must not silently become the authoritative editable source.

The database may store useful reference metadata such as a durable document/file/folder identifier, publication identity, revision, status, content hash, or generated-artifact reference when justified. Those references are not substitutes for the editable source content.

## Browser Presentation

When connected, the normal field experience should present the current approved content through `my.sheboyganlights.org` using the resolved Display/Scene/Stage context.

The operator should not need to understand:

- Google Drive folder paths;
- GitHub repository paths;
- Directus collection URLs;
- LOR Preview UUIDs; or
- source-document publishing mechanics.

When more than one current document applies to the resolved scope, the application may present a concise list of current documents.

Archive, SourceDocs, working material, and other non-current content must not appear as normal field choices.

## PDF Field Publication Direction

The preferred shared offline/print publication direction is a generated **PDF**.

PDF is being evaluated as the standard field-copy format because it can combine text, images, page layout, expiration information, and printing into one portable artifact.

This direction remains subject to implementation and field validation. The operational requirement is the field outcome, not the file extension by itself.

A generated field PDF should be:

- self-contained;
- viewable after Internet access is lost;
- printable without reconnecting to the server;
- tied to the exact resolved task/scope from which it was generated; and
- visibly controlled against stale reuse.

## Images Must Be Included in the Published PDF

When the source content references images needed to perform the field task, the generated PDF must contain those images in the actual PDF output.

The PDF must not require the field device to reconnect to:

- Google Drive;
- a mapped `G:` drive;
- `my.sheboyganlights.org`;
- another web server; or
- a local `file:///` path

after the PDF has been generated.

The image source files remain maintained in the folder structure owned by the responsible subsystem. PDF generation does not change image ownership or create a second editing source.

For procedures, images should remain adjacent to the steps they explain when the source/template supports that layout.

For Wiring, all wiring images belonging to the resolved wiring package should be included in the PDF in deterministic order.

## Source Versus Published Copy

A PDF is a derived field publication unless a subsystem explicitly establishes otherwise.

The editable/current source may remain, for example:

- a Google Doc;
- controlled Markdown/template source;
- LOR/PostgreSQL wiring data plus published wiring images; or
- another approved subsystem-owned source.

The generated PDF must not silently become a competing editing authority merely because it is convenient to download or print.

The system should preserve enough durable source identity to determine what produced the PDF.

## Common Currentness Metadata

Every generated field PDF must prominently display at least:

```text
Generated: <absolute local date/time>
Expires:   <absolute local date/time>
```

Where useful, it should also identify:

- resolved Stage/Sub-stage/Scene;
- task/document title;
- source revision/version;
- source document identifier or current publication identifier;
- applicable season/year;
- source snapshot/import run for data-driven outputs such as Wiring; and
- other provenance needed to determine what produced the field copy.

The currentness notice must be visible in the PDF itself. It must not exist only in browser metadata or database fields.

## Expiration Is Shared; Duration Is Task-Specific

The expiration mechanism is shared across field publications, but the expiration interval does not need to be identical for every task.

Examples:

- Wiring may require a very short validity window because controller/channel information can change with a new approved LOR build;
- a Setup/Takedown procedure may remain valid longer when its approved procedure has not changed;
- Testing procedures may follow the validity rules owned by the Testing subsystem.

Therefore each task-specific presenter must define or obtain its approved expiration policy rather than hard-coding one universal duration for every field document.

Regardless of the nominal expiration timestamp, a generated field copy becomes stale immediately when a newer approved publication/snapshot supersedes the source from which it was generated.

## Supersession Rule

A field PDF is never the durable proof that its content remains current.

If a newer approved source or publication exists, an older field PDF is superseded even if its printed `Expires` timestamp has not yet been reached.

The live connected application should always resolve the current approved content.

Offline users cannot be expected to learn about a superseding publication while disconnected; the explicit expiration timestamp is therefore the practical stale-copy guard for offline use.

## Offline Use

Offline capability is a first-class requirement because Internet coverage is not reliable in every part of the park.

The expected field workflow may be:

```text
while connected
    -> scan Display / resolve context
    -> choose task
    -> open current content
    -> Save / Print PDF

later without Internet
    -> open saved PDF
    -> use included text/images
    -> verify visible expiration
```

The PDF should not depend on a live session token or server request merely to render content already included in the file.

## Scope Consistency

A generated PDF must represent the same resolved scope shown to the operator when the PDF was requested.

Examples:

- Scene-scoped Field Wiring -> Scene-scoped wiring PDF;
- Stage-scoped Field Wiring fallback -> Stage-scoped wiring PDF;
- Scene Setup instructions -> Scene Setup PDF;
- Stage Setup instructions -> Stage Setup PDF.

The exporter must not silently widen a Scene result to an entire Stage or narrow a shared Scene procedure to only the scanned Display.

## Task-Specific Rules Still Apply

This shared contract does not replace subsystem rules.

FieldWiring still owns:

- field-lead reduction;
- controller/channel/network presentation;
- wiring-context selection;
- multi-image wiring packages; and
- wiring-specific expiration/currentness policy.

Setup/Takedown still own:

- procedure source/template;
- current-versus-archive state;
- procedure images;
- approval/publication workflow; and
- procedure-specific expiration/currentness policy.

Testing owns its own procedure/workflow rules.

## Acceptance Requirements

A shared field-publication implementation should be tested for at least:

1. a generated PDF opened with network access disabled;
2. a PDF containing all required images with no broken external image dependency;
3. visible Generated and Expires information;
4. correct task/scope identity in the PDF;
5. current live content replacing a superseded publication;
6. more than one applicable procedure presented as separate current choices where appropriate;
7. Scene-scoped and Stage-scoped examples; and
8. printing from a phone/tablet/laptop without requiring access to a mapped drive.

## Related Documents

- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [FieldWiring Scene Scope and Offline Report Requirements](../09_Wiring_System/FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](../09_Wiring_System/FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Stage Setup Documentation Standard](../../../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md)
