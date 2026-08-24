# Publish a Current Setup Instruction

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders / Procedures |
| Task | Publish a current Stage or Scene Setup instruction |
| Audience | Production documentation maintainers and Setup-document contributors |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-23 |
| Keywords | Setup, publish PDF, Procedures, Google Drive, Stage Setup, SourceDocs, Archive |

[↑ Google Drive / Display Folder Operations](../README.md)

## Purpose

Use this procedure after a Setup instruction has been reviewed and is ready for field use.

The current field document must be placed where the **Procedures** system expects current Setup material. Working files and older source material stay separate.

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

Editable working/source files:

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
        │   └── Front Entrance Setup.docx
        └── Front Entrance Setup.pdf
```

The PDF directly in `Procedures\Setup` is the current field instruction.

The document in `SourceDocs` is editable working material and should not be expected to appear as the current field instruction.

The document in `Archive` is historical/superseded material and should not be expected to appear as current.

## Procedure

1. Open the correct Stage, Sub-stage, or Scene folder.
2. Open `Procedures\Setup`.
3. Confirm the `Procedures` root has the required MSB marker file.
4. Keep editable working/source files in `Setup\SourceDocs`.
5. Keep Setup-specific instruction images in `Setup\images`.
6. Keep older/superseded source material in `Setup\Archive`.
7. Place the approved current field PDF directly in `Procedures\Setup`.
8. Remove or archive any superseded current PDF that would otherwise look like another current instruction, unless more than one current Setup instruction is intentionally required for that scope.
9. Open the **Procedures** system:

```text
https://my.sheboyganlights.org/procedures/
```

10. Search/browse to the intended Stage/Scene.
11. Select **Setup**.
12. Confirm the newly published PDF appears.
13. Open it and verify the correct current document is displayed.
14. Confirm no archived/source file appears as a current instruction.

## More Than One Current Setup Instruction

A Stage or Scene may legitimately have more than one current Setup instruction.

Keep each current field document directly in `Procedures\Setup` only when the crew is expected to choose among those current instructions.

Do not leave old versions beside the current one merely because deleting or archiving them was inconvenient.

## Important Warnings

- **Do not put the current PDF in `Archive`.** It will not be treated as the current field instruction.
- **Do not put the current PDF in `SourceDocs`.** That folder is for working/source material.
- **Do not put Setup instruction images in the general Stage `Photos` folder.** Use `Procedures\Setup\images`.
- **Do not duplicate a shared Stage/Scene instruction under every Display.** Keep it at the scope that owns the instruction.

## Expected Result

The approved current Setup PDF is directly in the correct Stage/Sub-stage/Scene `Procedures\Setup` folder and appears in the Procedures system for that same scope.

Source, image, and historical material remain separated into their correct support folders.

## If Something Is Wrong

- **PDF does not appear in Procedures:** first verify it is directly in `Procedures\Setup`, not `SourceDocs` or `Archive`; then verify the required root and `Procedures` markers.
- **Wrong Stage/Scene appears:** do not move folders by guesswork. Review Folder Alignment and ownership first.
- **An old PDF also appears as current:** move the superseded copy to `Archive` after confirming it is no longer current.
- **Images in the PDF are missing:** verify the published PDF itself contains the needed images; `Setup\images` is the controlled supporting location for source/linked assets, not a substitute for checking the final field document.

## Related Documents

- [Align a Legacy Setup Document](Align_Legacy_Setup_Documents.md)
- [Add and Verify MSB Display Folder Marker Files](Add_Verify_Marker_Files.md)
- [Google Drive Engineering](../engineering/README.md)
