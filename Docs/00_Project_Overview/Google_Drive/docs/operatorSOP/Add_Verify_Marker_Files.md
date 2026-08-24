# Add and Verify MSB Display Folder Marker Files

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders |
| Task | Add and verify controlled source-folder markers |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-23 |
| Keywords | marker, Display Folders, Field Wiring, Procedures, PreviewBackground, Google Drive, Folder Alignment |

[↑ Google Drive / Display Folder Operations](../../README.md)

## Purpose

Use this procedure when adding or checking marker files in Google Drive folders used by the current **Field Wiring** or **Procedures** systems.

The marker tells people and the MSB field-document systems that the folder is part of the controlled current structure.

You do **not** need to understand how the applications resolve paths to use this procedure.

## Standard Marker File Name

Use this exact filename:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not shorten, rename, move, or delete an approved marker.

## Before You Start

- Work from an already-reviewed Stage, Sub-stage, or Scene location.
- Do not rename or move the Stage/Scene root as part of adding a marker.
- Do not add marker files to every folder just because the folder exists.
- If you are unsure whether a folder is a current Stage/Scene source, stop and check the Folder Alignment worklist before marking it.

## Field Wiring Marker Locations

```text
<Stage / Sub-stage / Scene root>     YES
PreviewBackground                    YES, when used as a current LOR/application source
Wiring                               YES
Wiring\BackgroundStage              NO
Wiring\MusicalStage                 NO
SourceDocs                           NO
```

Example:

```text
15-Church-Bells-CH\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── PreviewBackground\
│   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
└── Wiring\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    ├── BackgroundStage\
    └── MusicalStage\
```

Do **not** add separate markers to `Wiring\BackgroundStage` or `Wiring\MusicalStage`.

Do **not** mark `SourceDocs` as current field content.

## Procedures Marker Locations

```text
<Stage / Sub-stage / Scene root>     YES
Procedures                           YES
Procedures\Inspection               NO
Procedures\Setup                    NO
Procedures\Takedown                 NO
Procedures\Setup\images             NO
Procedures\Takedown\images          NO
Archive                              NO
SourceDocs                           NO
```

Example:

```text
15-Church-Bells-CH\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
└── Procedures\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    ├── Inspection\
    ├── Setup\
    │   ├── Archive\
    │   ├── images\
    │   └── SourceDocs\
    └── Takedown\
        ├── Archive\
        ├── images\
        └── SourceDocs\
```

Do **not** add separate markers to `Inspection`, `Setup`, `Takedown`, or their `images` folders.

Do **not** mark `Archive` or `SourceDocs` as current field content.

## Photos

The general `Photos` folder is not currently a Field Wiring or Procedures source folder.

Do not add a field-source marker to `Photos` merely because the folder exists.

## Procedure

1. Open the reviewed Stage, Sub-stage, or Scene folder.
2. Confirm the folder name matches the intended location from Folder Alignment.
3. Check whether the marker already exists in the root.
4. If the root is a current controlled Stage/Sub-stage/Scene source and the marker is missing, add the exact marker filename.
5. If the folder uses Field Wiring, open `Wiring` and verify the same marker exists directly in `Wiring`.
6. Do **not** add markers inside `BackgroundStage`, `MusicalStage`, or their `SourceDocs` folders.
7. If the folder uses Procedures, open `Procedures` and verify the marker exists directly in `Procedures`.
8. Do **not** add markers inside `Inspection`, `Setup`, `Takedown`, their `images` folders, `Archive`, or `SourceDocs`.
9. If `PreviewBackground` is being used as a current LOR/application source, verify the marker exists directly in that `PreviewBackground` folder.
10. Leave unrelated legacy folders unmarked unless they are deliberately reviewed and brought into the current controlled structure.
11. Verify the final placement using the checklists below.

## Local Notes Inside a Marker

A marker may contain a short `LOCAL NOTES` section for factual warnings such as:

- a known legacy exception;
- pending Folder Alignment work;
- a stale LOR background reference that still needs correction;
- a missing field image; or
- another temporary migration condition.

Do not place passwords, credentials, API keys, or private personal information in a marker file.

## Field Wiring Verification Checklist

- [ ] Stage/Sub-stage/Scene root marker is present.
- [ ] Active `PreviewBackground` source folder is marked when applicable.
- [ ] `Wiring` marker is present.
- [ ] `Wiring\BackgroundStage` has no separate marker requirement.
- [ ] `Wiring\MusicalStage` has no separate marker requirement.
- [ ] `SourceDocs` is not marked as current field content.
- [ ] No approved marker was renamed or deleted.

## Procedures Verification Checklist

- [ ] Stage/Sub-stage/Scene root marker is present.
- [ ] `Procedures` marker is present.
- [ ] `Inspection`, `Setup`, and `Takedown` are the controlled child names when that structure is used.
- [ ] Those task folders do not have separate marker requirements.
- [ ] Setup/Takedown `images` folders do not have separate marker requirements.
- [ ] `Archive` and `SourceDocs` are not marked as current field content.
- [ ] No approved marker was renamed or deleted.

## Expected Result

The Stage/Scene root and the applicable subsystem root are marked exactly as shown above, without extra marker files in the fixed child branches.

## If Something Is Wrong

- **A marker exists in `BackgroundStage`, `MusicalStage`, `Setup`, `Takedown`, `Inspection`, or an `images` folder:** do not use that extra marker as authority. Flag it for cleanup/review.
- **A root, `Wiring`, or `Procedures` marker is missing:** add it only after confirming that the folder is the correct current controlled location.
- **You are unsure whether the folder is a Scene, Display/group, or legacy folder:** do not add a marker based on guesswork. Review Folder Alignment first.
- **A marker utility gives instructions different from this procedure:** stop and do not run it until the utility has been reviewed against the current marker rule.

## Related Documents

- [Repair or Organize an Existing Stage / Scene](Repair_Existing_Stage_Scene.md)
- [Create a New Stage / Sub-stage / Scene Documentation Folder](Create_Stage_Substage_Scene_Folder.md)
- [Google Drive Engineering](../engineering/README.md)
