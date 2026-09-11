# Publish a Current Setup Instruction

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders / Procedures |
| Task | Publish a current Stage or Scene Setup instruction |
| Audience | Production documentation maintainers and Setup-document contributors |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-09-10 |
| Keywords | Setup, publish PDF, Procedures, Google Drive, Stage Setup, SourceDocs, Archive |

[↑ Google Drive / Display Folder Operations](../README.md)

## Purpose

Use this procedure after a Setup instruction has been reviewed and is ready for field use.

The current field document must be placed where the **Procedures** system expects current Setup material. Working files and older source material stay separate.

During the 2026 migration, legacy Google-native Setup documents are being moved from historical `Archive` use into a new authoritative editable copy in `SourceDocs`. The archived original remains historical evidence; the `SourceDocs` copy becomes the file that is edited going forward.

## Before You Start

- Confirm the instruction belongs to the intended Stage, Sub-stage, or Scene.
- Confirm the Stage/Scene uses the current `Procedures` folder structure.
- Confirm the instruction has been reviewed for current field use.
- If you are working from an older Setup document, align the old document first using [Align a Legacy Setup Document](Align_Legacy_Setup_Documents.md).
- Use the approved Stage Setup Instruction format/template for new or rewritten field instructions.

## Correct Locations

Current published Setup document:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup\<current instruction>.pdf
```

Authoritative editable working/source file after migration:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup\SourceDocs\
```

Images used by the Setup instruction:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup\images\
```

Historical or superseded material:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup\Archive\
```

## Example

```text
01-Front Entrance-FE\
└── Procedures\
    └── Setup\
        ├── Archive\
        │   └── 01 - Front Arch.gdoc
        ├── images\
        │   └── Front-Arch-Anchor-Detail.jpg
        ├── SourceDocs\
        │   └── Front Entrance Setup.gdoc
        └── Front Entrance Setup.pdf
```

The PDF directly in `Procedures\Setup` is the current field instruction.

The Google-native document in `SourceDocs` is the authoritative editable working copy after migration and should not be expected to appear as the current field instruction.

The document in `Archive` is the historical/original source and should not be edited after a SourceDocs copy has been created.

## Migrating a Legacy Google Doc into SourceDocs

When the only editable Setup procedure is a legacy `.gdoc` in `Procedures\Setup\Archive`, do **not** migrate it by copying or moving the `.gdoc` shortcut file in Windows Explorer. A `.gdoc` file is only a Google Drive shortcut/metadata file; copying it does not create the new Google-native document that is required for the new editable source.

Use this workflow instead:

1. Open the archived `.gdoc` in Google Docs.
2. In Google Docs, choose **File → Make a copy**.
3. Save the new Google-native copy into the same Stage/Sub-stage/Scene `Procedures\Setup\SourceDocs` folder.
4. Give the new copy the intended current working filename if a rename is needed.
5. Leave the archived original in `Archive` as historical evidence.
6. From that point forward, make all edits in the `SourceDocs` copy only.
7. When the edited procedure is approved for field use, publish/export the approved PDF directly into `Procedures\Setup`.

The Setup Manager application follows the same migration rule: it prefers an editable Google-native source in `SourceDocs`; only when no editable SourceDocs `.gdoc` exists does it fall back to the legacy `Archive` source.

## Procedure

1. Open the correct Stage, Sub-stage, or Scene folder.
2. Open `Procedures\Setup`.
3. Confirm the `Procedures` root has the required MSB marker file.
4. If the current editable source exists only in `Setup\Archive`, use the **Migrating a Legacy Google Doc into SourceDocs** procedure above before editing.
5. Keep the authoritative editable working/source file in `Setup\SourceDocs`.
6. Keep Setup-specific instruction images in `Setup\images`.
7. Keep older/superseded source material in `Setup\Archive`.
8. Place the approved current field PDF directly in `Procedures\Setup`.
9. Remove or archive any superseded current PDF that would otherwise look like another current instruction, unless more than one current Setup instruction is intentionally required for that scope.
10. Open the **Procedures** system:

```text
https://my.sheboyganlights.org/procedures/
```

11. Search/browse to the intended Stage/Scene.
12. Select **Setup**.
13. Confirm the newly published PDF appears.
14. Open it and verify the correct current document is displayed.
15. Confirm no archived/source file appears as a current instruction.

## More Than One Current Setup Instruction

A Stage or Scene may legitimately have more than one current Setup instruction.

Keep each current field document directly in `Procedures\Setup` only when the crew is expected to choose among those current instructions.

Do not leave old versions beside the current one merely because deleting or archiving them was inconvenient.

## Important Warnings

- **Do not edit the archived Google Doc after a SourceDocs copy exists.** `SourceDocs` is the authoritative editable location after migration.
- **Do not migrate a `.gdoc` by Explorer copy/paste.** Open it in Google Docs and use **File → Make a copy** so a new Google-native document is created in `SourceDocs`.
- **Do not put the current PDF in `Archive`.** It will not be treated as the current field instruction.
- **Do not put the current PDF in `SourceDocs`.** That folder is for working/source material.
- **Do not put Setup instruction images in the general Stage `Photos` folder.** Use `Procedures\Setup\images`.
- **Do not duplicate a shared Stage/Scene instruction under every Display.** Keep it at the scope that owns the instruction.

## Expected Result

The authoritative editable Setup source is in `Procedures\Setup\SourceDocs`, the historical original remains in `Procedures\Setup\Archive`, and the approved current field PDF is directly in the correct Stage/Sub-stage/Scene `Procedures\Setup` folder and appears in the Procedures system for that same scope.

Source, image, historical material, and the published field document remain separated into their correct locations.

## If Something Is Wrong

- **Setup Manager still opens the Archive source:** verify that the new document was actually created as a Google-native document in `Procedures\Setup\SourceDocs`, not merely copied as a `.gdoc` shortcut file.
- **PDF does not appear in Procedures:** first verify it is directly in `Procedures\Setup`, not `SourceDocs` or `Archive`; then verify the required root and `Procedures` markers.
- **Wrong Stage/Scene appears:** do not move folders by guesswork. Review Folder Alignment and ownership first.
- **An old PDF also appears as current:** move the superseded copy to `Archive` after confirming it is no longer current.
- **Images in the PDF are missing:** verify the published PDF itself contains the needed images; `Setup\images` is the controlled supporting location for source/linked assets, not a substitute for checking the final field document.

## Related Documents

- [Align a Legacy Setup Document](Align_Legacy_Setup_Documents.md)
- [Add and Verify MSB Display Folder Marker Files](Add_Verify_Marker_Files.md)
- [Google Drive Engineering](../engineering/README.md)
