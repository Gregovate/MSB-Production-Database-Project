# Align a Legacy Setup Document

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders / Folder Alignment |
| Task | Assign a legacy Setup document to the correct Stage, Sub-stage, or Scene |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-23 |
| Keywords | legacy Setup, Google Drive, Archive, Folder Alignment, Stage, Scene |

[↑ Google Drive / Display Folder Operations](../../README.md)

## Purpose

Use this procedure when reviewing an older Setup document from the central legacy Setup collection and assigning it to the correct current Stage, Sub-stage, or Scene.

This task records **where the old document belongs**. It does not make the old document the current field instruction.

## Before You Start

- Open the current **Documentation Alignment Worklist**.
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
- delete the old source after moving it to `Archive`;
- duplicate one shared Stage/Scene instruction under every Display;
- reorganize unrelated loose files while doing this task; or
- move uncertain material merely to make the legacy backlog smaller.

## Expected Result

A reviewed legacy Setup document is either:

- safely moved into the correct Stage/Sub-stage/Scene `Procedures\Setup\Archive` folder; or
- left in the legacy source and clearly identified as still needing review.

The archived document is historical/source evidence, not current field authority.

## Next Step

When the archived procedure contains information that is still useful for current setup, continue with:

- [Publish a Current Setup Instruction](Publish_Current_Setup_Instruction.md)

## If Something Is Wrong

- **Two Stages seem plausible:** do not move the file; flag it for review.
- **The expected Stage/Scene folder does not exist:** do not create a folder just to receive the legacy document. Review Folder Alignment first.
- **The correct destination exists but lacks the standard Procedure structure:** repair the Stage/Scene structure before publishing current material.

## Related Engineering

- [Google Drive Engineering](../engineering/README.md)
