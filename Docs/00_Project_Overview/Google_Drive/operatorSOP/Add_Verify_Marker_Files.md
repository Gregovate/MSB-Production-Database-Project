# Add and Verify MSB Display Folder Marker Files

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders |
| Task | Add and verify controlled source-folder markers |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-09-10 |
| Keywords | marker, Display Folders, Field Wiring, Procedures, PreviewBackground, Google Drive, Folder Alignment, Park Infrastructure |

[↑ Google Drive / Display Folder Operations](../README.md)

## Purpose

Use this procedure when adding or checking marker files in Google Drive folders used by the current **Field Wiring** or **Procedures** systems, including the controlled non-LOR `41 Park Infrastructure-PI` Procedure root used by Setup Session.

The marker tells people and the MSB field-document systems that the folder is part of the controlled current structure.

You do **not** need to understand how the applications resolve paths to use this procedure.

## Standard Marker File Name

Use this exact filename:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not shorten, rename, move, or delete an approved marker.

## Marker Identity Must Match Its Folder

The marker is controlled metadata, not merely a magic filename. Its standard content must identify the actual folder in which it lives.

For generated/new markers, include the exact current folder name and controlled Display-Folders-relative path. For Stage/Sub-stage/Scene helper markers, also identify the owning structured scope and helper role.

Example Scene root:

```text
Folder name: 01-Front Gate
Controlled path: 01-Front Entrance-FE\01-Front Gate
Owning scope: 01-Front Gate
Folder role: SCENE ROOT
```

Example Procedures marker:

```text
Folder name: Procedures
Controlled path: 01-Front Entrance-FE\01-Front Gate\Procedures
Owning scope: 01-Front Gate
Folder role: PROCEDURES
```

If a folder is renamed, the marker content must be reviewed as part of the same controlled change. A marker whose embedded folder name/path no longer agrees with its containing folder is **not valid** merely because the filename is present.

For new/renamed controlled LOR Scenes, this verification belongs in the LOR2DB reconciliation workflow. LOR2DB knows the expected Scene name and owning Stage/Sub-stage and can generate the correct marker identity rather than asking an operator to type it manually. See Issue #143.

## Before You Start

- For Stage/Sub-stage/Scene material, work from an already-reviewed structured location.
- For park-wide/no-Stage Setup Procedures, work only from the approved `Display Folders\41 Park Infrastructure-PI` root.
- Do not rename or move an approved root as part of adding a marker.
- Do not add marker files to every folder just because the folder exists.
- If you are unsure whether a folder is a current controlled source, stop and check the applicable operator procedure before marking it.

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

## Stage / Scene Procedures Marker Locations

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

## Park Infrastructure Procedures Marker Locations

The non-LOR Setup Procedure root uses the same Procedure marker pattern without pretending to be a Stage or Scene:

```text
41 Park Infrastructure-PI                        YES
41 Park Infrastructure-PI\Procedures             YES
Procedures\Inspection                            NO
Procedures\Setup                                 NO
Procedures\Takedown                              NO
Procedures\Setup\images                          NO
Procedures\Takedown\images                       NO
Archive                                           NO
SourceDocs                                        NO
```

Expected structure:

```text
41 Park Infrastructure-PI\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
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

Do not add `PreviewBackground` or `Wiring` merely because normal Stage folders have those branches. `41 Park Infrastructure-PI` is not LOR-derived.

Use [Create the Park Infrastructure Procedure Folder](Create_Site_Infrastructure_Procedure_Folder.md) for the complete build checklist.

## Photos

The general `Photos` folder is not currently a Field Wiring or Procedures source folder.

Do not add a field-source marker to `Photos` merely because the folder exists.

## Procedure

1. Open the reviewed controlled root.
2. Confirm the folder is the intended Stage/Sub-stage/Scene or the approved `41 Park Infrastructure-PI` root.
3. Check whether the marker already exists in the root.
4. If the root is a current controlled source and the marker is missing, add the exact marker filename and verify its embedded folder identity matches the actual folder.
5. If the folder uses Field Wiring, open `Wiring` and verify the same marker exists directly in `Wiring` and identifies that helper path/owning scope.
6. Do **not** add markers inside `BackgroundStage`, `MusicalStage`, or their `SourceDocs` folders.
7. If the folder uses Procedures, open `Procedures` and verify the marker exists directly in `Procedures` and identifies that helper path/owning scope.
8. Do **not** add markers inside `Inspection`, `Setup`, `Takedown`, their `images` folders, `Archive`, or `SourceDocs`.
9. For Stage/Sub-stage/Scene roots, if `PreviewBackground` is being used as a current LOR/application source, verify the marker exists directly in that `PreviewBackground` folder and identifies that helper path/owning scope.
10. For `41 Park Infrastructure-PI`, do not create or mark a `PreviewBackground` merely to imitate Stage structure.
11. Leave unrelated legacy folders unmarked unless they are deliberately reviewed and brought into the current controlled structure.
12. Verify both marker placement and marker identity content using the checklists below.

## Local Notes Inside a Marker

A marker may contain a short `LOCAL NOTES` section for factual warnings such as:

- a known legacy exception;
- pending Folder Alignment work;
- a stale LOR background reference that still needs correction;
- a missing field image; or
- another temporary migration condition.

Do not place passwords, credentials, API keys, or private personal information in a marker file.

When a governed utility repairs marker identity, preserve existing `LOCAL NOTES` unless the operator deliberately changes them.

## Field Wiring Verification Checklist

- [ ] Stage/Sub-stage/Scene root marker is present.
- [ ] Marker embedded folder name/path matches the folder in which it lives.
- [ ] Active `PreviewBackground` source folder is marked when applicable.
- [ ] `Wiring` marker is present.
- [ ] `Wiring\BackgroundStage` has no separate marker requirement.
- [ ] `Wiring\MusicalStage` has no separate marker requirement.
- [ ] `SourceDocs` is not marked as current field content.
- [ ] No approved marker was renamed or deleted.

## Procedures Verification Checklist

- [ ] Controlled root marker is present.
- [ ] Marker embedded folder name/path matches the folder in which it lives.
- [ ] `Procedures` marker is present.
- [ ] `Inspection`, `Setup`, and `Takedown` are the controlled child names when that structure is used.
- [ ] Those task folders do not have separate marker requirements.
- [ ] Setup/Takedown `images` folders do not have separate marker requirements.
- [ ] `Archive` and `SourceDocs` are not marked as current field content.
- [ ] `41 Park Infrastructure-PI`, when used, has no fake Stage/Scene/LOR helpers added solely for Procedure resolution.
- [ ] No approved marker was renamed or deleted.

## Expected Result

The controlled root and applicable subsystem roots are marked exactly as shown above, each marker identity agrees with its actual containing folder/path, and no extra markers exist in fixed child branches.

## If Something Is Wrong

- **Marker filename exists but its embedded folder name/path is stale or wrong:** treat the marker as invalid. For a new/renamed LOR Scene, return to LOR2DB reconciliation and use the governed repair workflow when available.
- **A marker exists in `BackgroundStage`, `MusicalStage`, `Setup`, `Takedown`, `Inspection`, or an `images` folder:** do not use that extra marker as authority. Flag it for cleanup/review.
- **A controlled root, `Wiring`, or `Procedures` marker is missing:** add it only after confirming that the folder is the correct current controlled location.
- **You are unsure whether a folder is a Scene, Display/group, legacy folder, or `41 Park Infrastructure-PI`:** do not add a marker based on guesswork. Review the applicable folder-creation/alignment procedure first.
- **A marker utility gives instructions different from this procedure:** stop and do not run it until the utility has been reviewed against the current marker rule.

## Related Documents

- [Repair or Organize an Existing Stage / Scene](Repair_Existing_Stage_Scene.md)
- [Create a New Stage / Sub-stage / Scene Documentation Folder](Create_Stage_Substage_Scene_Folder.md)
- [Create the Park Infrastructure Procedure Folder](Create_Site_Infrastructure_Procedure_Folder.md)
- [Folder Alignment Park Infrastructure non-LOR boundary](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/engineering/Park_Infrastructure_Non_LOR_Root_2026-09-07.md)
- [Google Drive Engineering](../engineering/README.md)
- GitHub Issue #143
