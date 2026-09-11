# Align a Legacy Setup Document

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders / Folder Alignment |
| Task | Assign a legacy Setup document to the correct Stage, Sub-stage, or Scene |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-09-10 |
| Keywords | legacy Setup, Google Drive, Archive, SourceDocs, Folder Alignment, Stage, Scene |

[↑ Google Drive / Display Folder Operations](../README.md)

## Purpose

Use this procedure when reviewing an older Setup document from the central legacy Setup collection and assigning it to the correct current Stage, Sub-stage, or Scene.

This task records **where the old document belongs**. It does not make the old document the current field instruction.

During the 2026 migration, the reviewed legacy document is preserved in `Archive`. If it is still useful as the basis for current editing, a new Google-native working copy is then created in `SourceDocs` using Google Docs **File → Make a copy**. The archived original remains historical and is not the file edited going forward.

## Before You Start

- Open the current [**Documentation Alignment Worklist**](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Review_Folder_Alignment_Worklist.md). If you need a fresh worklist, use [Run Folder Alignment](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Run_Folder_Alignment.md).
- Work on one Stage at a time.
- Use the real current Stage/Scene organization, not only a similar filename.
- If ownership is uncertain, leave the document where it is and flag it for review.

The current central legacy source is:

```text
G:\Shared drives\Display Folders\000-Instructions\0 - Setup Procedures
```

## Correct Archive Destination

After a human reviewer confirms ownership, move the original legacy document to:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup\Archive\
```

Example:

```text
01-Front Entrance-FE\Procedures\Setup\Archive\01 - Front Arch.gdoc
```

Putting the old document in `Archive` records the reviewed ownership while keeping it out of the current field instructions.

`Archive` remains the location of the historical original. Do not later move that same original into `SourceDocs` and do not edit it after a new SourceDocs copy has been created.

## Procedure

1. Open the current Folder Alignment worklist.
2. Choose one legacy Setup document to review.
3. Read enough of the document to understand what physical Stage, Sub-stage, Scene, or group it describes.
4. Compare that information with the current Stage/Scene organization.
5. Do **not** accept a filename-only or fuzzy-name match as final ownership.
6. When ownership is clear, open the matching current Stage/Sub-stage/Scene folder.
7. Open `Procedures\Setup\Archive`.
8. Move the original legacy document into that `Archive` folder.
9. Preserve the original document; do not delete it merely because a newer instruction will eventually replace it.
10. If the old filename contains an obsolete Stage number, correct the filename only when the correct current Stage number is known.
11. Leave uncertain documents in the central legacy source and flag them for review.
12. Re-run Folder Alignment when you want the worklist to show the updated migration progress.
13. If the archived Google Doc is still useful for current editing, continue with the SourceDocs migration workflow in [Publish a Current Setup Instruction](Publish_Current_Setup_Instruction.md): open the archived document in Google Docs, use **File → Make a copy**, and save the new Google-native working copy in `Procedures\Setup\SourceDocs`.

## Stage Number Example

If an old file says:

```text
25 - Magic Igloo.gdoc
```

and human review confirms the current Stage is 26, it may be renamed during the reviewed move to:

```text
26-Magic Igloo.gdoc
```

Do not change Stage numbers based only on guesswork.

## What Not To Do

Do not:

- move a legacy document based only on a fuzzy filename match;
- place an old `.gdoc` directly in `Procedures\Setup` and treat it as current;
- copy/paste an archived `.gdoc` shortcut file into `SourceDocs` and treat that as a migrated Google Doc;
- edit the archived original after a new SourceDocs copy has been created;
- delete the old source after moving it to `Archive`;
- duplicate one shared Stage/Scene instruction under every Display;
- reorganize unrelated loose files while doing this task; or
- move uncertain material merely to make the legacy backlog smaller.

## Expected Result

A reviewed legacy Setup document is either:

- safely moved into the correct Stage/Sub-stage/Scene `Procedures\Setup\Archive` folder; or
- left in the legacy source and clearly identified as still needing review.

When a reviewed archived document is carried forward for current editing, a separate Google-native copy is created in `Procedures\Setup\SourceDocs` and all subsequent edits occur there.

The archived document remains historical/source evidence, not current editable or field authority.

## Next Step

When the archived procedure contains information that is still useful for current setup, continue with:

- [Publish a Current Setup Instruction](Publish_Current_Setup_Instruction.md)

That procedure contains the required Google Docs **File → Make a copy** migration into `SourceDocs`, along with publication of the current field PDF.

## If Something Is Wrong

- **Two Stages seem plausible:** do not move the file; flag it for review.
- **The expected Stage/Scene folder does not exist:** do not create a folder just to receive the legacy document. Review Folder Alignment first.
- **The correct destination exists but lacks the standard Procedure structure:** repair the Stage/Scene structure before publishing current material.
- **A `.gdoc` was copied into SourceDocs using Explorer:** do not treat that as the migrated editable source. Open the archived document in Google Docs and use **File → Make a copy** into `SourceDocs`.

## Related Engineering

- [Google Drive Engineering](../engineering/README.md)
