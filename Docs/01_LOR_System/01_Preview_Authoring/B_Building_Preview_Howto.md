---
title: Building a Preview (Operator How-To)
status: CURRENT
revision: 2026-08-17
author: Greg Liebig / Engineering Innovations, LLC
---

# Building a Preview (Operator How-To)

## Purpose

This guide explains the current operator workflow for creating, editing, and exporting Light-O-Rama (LOR) previews used by the MSB production workflow.

It covers Preview authoring. It does **not** redefine the Display design contract, Google Drive engineering-repository architecture, Preview Merger engineering, parser behavior, or FormView/FieldWiring implementation.

Use the specialized procedures linked below when the work reaches those boundaries.

## Current Workflow at a Glance

```text
Display Design Worksheet / approved design intent
        |
        v
Display artwork and LOR Preview work
        |
        v
external Preview / Scene background from the correct Google Drive scope
        |
        v
export candidate .lorprev
        |
        v
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
        |
        v
controlled Preview review / merger process
        |
        v
approved production Preview set
        |
        v
V7 parser -> LOR2DB ingest / reconciliation
```

The current Preview Merger implementation is still under engineering review for production `--apply`. Exporting a candidate to `UserPreviewStaging` does **not** authorize replacement of the controlled master.

---

# 1. Start with the Existing Display Design Worksheet

Preview authoring begins only after the Display concept and engineering intent are sufficiently defined.

The existing [Display Design Worksheet](https://docs.google.com/spreadsheets/d/1Pw91W724KTUcvG1HdSYsTuLY1Mo-2JRPdKq7nziDz8M/edit?usp=sharing) is the upstream prerequisite/prototype for that work.

This Preview Authoring procedure does not redesign the worksheet or create a competing Display contract. Use the worksheet and the established design process to determine the intended Stage, controller/channel plan, lighting type, colors, and other design inputs needed to build the LOR Preview.

---

# 2. Work from the Current Approved Preview Source

Before editing an existing Preview, use [Preview Import Workflow](Preview_Import_Workflow.md) to identify and import the current approved source.

Rules:

- do not edit the approved production source folder;
- do not overwrite the controlled master;
- make changes only in your own working copy;
- verify the Preview revision before beginning work; and
- preserve the existing Preview identity unless there is an intentional engineering reason to replace it.

Each programmer's copy is an isolated working copy. Another programmer may have valid changes that are not present in yours.

---

# 3. Use the Current Google Drive Scope and Helper Folders

The Google Shared Drive named **Display Folders** is the engineering-document repository.

Do not assume that every LOR Display must have a dedicated Google Drive Display folder.

Valid documentation ownership can be:

1. the Stage root;
2. an established Sub-stage root;
3. an established Scene root;
4. an existing shared Display/group folder; or
5. an existing individual Display folder.

A Display may also be documented entirely at Stage or Scene level and therefore have no dedicated folder.

See [Google Drive Folder Structure](../../00_Project_Overview/00-Google_Drive.md) and [Folder Alignment Engineering Design](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md) for the controlled folder and path-resolution contracts.

## Stage / Sub-stage / Scene helper structure

Stage, Sub-stage, and true Scene roots use the full helper structure, including:

```text
<Stage / Sub-stage / Scene>\
├── PreviewBackground\
├── Photos\
├── Procedures\
└── Wiring\
    ├── BackgroundStage\
    │   └── SourceDocs\
    └── MusicalStage\
        └── SourceDocs\
```

## Display helper structure

An existing Display folder uses the smaller contract:

```text
<Display>\
├── PreviewBackground\
└── Photos\
```

Do **not** add `Procedures` or `Wiring` to a Display folder merely because a Display exists in LOR.

---

# 4. Choose the Correct Background Location

LOR background paths are external filesystem references. Do not embed the image into the Preview.

The correct location depends on what the image is for.

| Use | Current location | Notes |
|---|---|---|
| Individual Display/Prop authoring background | `<resolved scope>\PreviewBackground\` | Use the scope that actually owns the Display documentation. |
| Master Musical Preview Scene background / scope anchor | `<resolved Stage/Sub-stage/Scene/Display scope>\PreviewBackground\` | Follow the dedicated Master Musical procedure and Scene naming rules. |
| Show Background Stage field-wiring background used by current FormView | `<Stage or Scene>\Wiring\BackgroundStage\` | The primary image must be in the published wiring-image directory; working material belongs in `SourceDocs`. |
| Current published Musical wiring images | `<Stage or Scene>\Wiring\MusicalStage\` | This is the field-wiring publication branch. Do not treat it as the general-purpose Preview-background folder. |

The old `Wiring\Props-Displays` location is not the current Display background contract.

The distinction matters:

- `PreviewBackground` is the stable scope-local location for authoring backgrounds and filesystem-resolution evidence;
- `Wiring\BackgroundStage` and `Wiring\MusicalStage` are published field-wiring image directories; and
- current FormView depends on its documented Wiring-folder behavior until the separate FieldWiring/FormView conversion is proven.

---

# 5. Prepare Display Artwork

A physical Display normally begins with a scalable drawing that can support fabrication and later documentation.

Use vector artwork for work that must scale accurately, such as:

- CNC cutting;
- plotting;
- full-scale panel layouts;
- wiring overlays; and
- dimensional fabrication work.

Bitmap images such as JPG/PNG remain useful for:

- LOR Preview backgrounds;
- documentation;
- tracing source artwork;
- wiring references; and
- web/printed reference images.

## Inkscape file convention

When Inkscape is used, preserve both:

```text
DisplayName-inkscape.svg
```

for the editable Inkscape master, and:

```text
DisplayName-plain.svg
```

for the simplified production/compatibility export.

Keep source/fabrication files with the engineering scope that owns them. Do not place general artwork or fabrication files into published `Wiring` image directories.

---

# 6. Create a Single-Display / Prop Preview

## Background image

Typical image guidance:

- single horizontal panel: approximately `800 x 600`;
- single vertical panel: approximately `600 x 800`;
- full Stage reference image: approximately `3840 x 2160`;
- maximum historical guidance: approximately `4000 x 3000`.

Use JPG for normal Preview background images.

Place the image in the correct scope's `PreviewBackground` folder, then in LOR use:

```text
Background -> Set Image
```

Select the external shared-drive image. Do **not** embed it.

## Draw and assign channels

1. Draw the strings/elements required to represent the Display.
2. Assign the correct controller/network/channel information from the approved design intent.
3. Verify scaling and placement.
4. Apply the current [Prop and Display Naming Conventions](A_Naming_Conventions.md).
5. Keep the LOR `Comment` value aligned with the physical Display Name.
6. Use the required padded controller-channel naming in the LOR `Name` field.
7. Include unused controller channels as explicit SPARE channels following the naming procedure.

When a Display moves away from an old channel, follow the SPARE recreation rule in the naming document. Do not simply rename or hide the old PropClass and leave its UUID behind.

---

# 7. Export Reusable `.leprop` Files When Needed

When a reusable LOR Prop is required:

1. select the completed channels/elements;
2. create the appropriate group/Prop;
3. export the `.leprop` file;
4. retain the Preview/Prop identity intentionally; and
5. place the approved reusable Prop file in the established shared Prop location:

```text
G:\Shared drives\MSB Database\Database Previews\PreviewsForProps
```

Do not use reusable Prop files as a way to create accidental duplicate physical identities.

## Duplicate physical Displays

Where several identical physical Displays must exist, create them intentionally so each physical instance receives its own LOR identity.

Do not blindly copy one `.leprop` object between unrelated Preview contexts when that would duplicate the same PropClass identity for different physical Displays.

---

# 8. Current Preview Classes

The current workflow includes several independently managed Preview classes.

## Master Musical Preview

The **Master Musical Preview** is the musical programming authority. The former model of maintaining separate `RGB Plus Stage xx` musical previews is obsolete as the current authoring model.

Use [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md) for:

- Scene naming;
- Stage/Sub-stage/Scene classification;
- Scene `BackgroundFile` scope anchors; and
- the rule that not every sequencing Scene creates a Google Drive Scene folder.

## Show Background Stage previews

These remain independently managed Stage previews used for background/static show operation and the current FormView background-wiring workflow.

Their field-wiring background is prepared under:

```text
<Stage or Scene>\Wiring\BackgroundStage\
```

Follow [Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md).

## Show Animation previews

Show Animation previews remain independently managed where required by the current show workflow.

## Engineering exceptions

Specialized approved Previews such as the Parade Float remain separate when the current Preview Merger documentation identifies them as engineering exceptions.

Do not fold an exception into another Preview class merely to make the naming pattern look uniform.

---

# 9. Editing an Existing Preview

1. Import the current approved Preview using [Preview Import Workflow](Preview_Import_Workflow.md).
2. Work only in your own copy.
3. Preserve Preview identity unless an intentional engineering change requires otherwise.
4. Make the required Prop/channel/Scene/background changes.
5. Verify all external background paths still resolve to the intended Google Drive scope.
6. For wiring-image changes, verify only current published field images are present in the applicable Wiring branch.
7. Save your working Preview.
8. Export the candidate `.lorprev` to your user staging folder.

Do not save the edited file back into the approved source folder.

---

# 10. Create or Update Stage Wiring Images

Stage field-wiring diagrams are a separate publication workflow from ordinary Display/Scene `PreviewBackground` images.

For current operator steps, use:

[Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md)

That procedure owns:

- `Wiring\BackgroundStage`;
- `Wiring\MusicalStage`;
- `SourceDocs` separation;
- tagged wiring diagrams;
- additional published wiring images; and
- the current FormView filesystem dependency.

Detailed FormView engineering and the browser-based FieldWiring conversion remain separate projects.

---

# 11. Export the Candidate to UserPreviewStaging

When authoring is complete, export the candidate `.lorprev` to:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

Then allow Google Drive synchronization to complete.

This folder is a **candidate staging area**, not the production master.

Current rules:

- never overwrite the controlled master from your local copy;
- do not point the production parser at `UserPreviewStaging`;
- use the Preview Merger dry-review process to inspect candidate differences; and
- do not run production merger `--apply` until the Preview Merger engineering review explicitly approves it.

See [Preview Merger](../03_Preview_Merger/README.md) for the current status and stop conditions.

---

# 12. Downstream Production Handoff

Only after a candidate has become part of the **approved controlled Preview set** through the currently approved master-update process may it feed the production parser.

The downstream database workflow is separate from authoring:

```text
approved controlled Preview set
    -> V7 parser
    -> reviewed SQLite snapshot
    -> PostgreSQL ingest
    -> reconciliation
    -> production promotion/reporting
```

Use the current LOR2DB procedure for the exact parser/ingest/reconciliation steps and stop conditions.

Preview authors should not treat successful export to staging as proof that a production database update has occurred.

---

# Authoring Checklist

Before exporting a candidate Preview, verify:

- [ ] The work began from current approved design/Preview inputs.
- [ ] The Display Design Worksheet was treated as the existing upstream design prerequisite rather than recreated here.
- [ ] Display and channel names follow the current naming rules.
- [ ] Any moved Display channels were deleted/recreated correctly rather than leaving stale UUIDs behind.
- [ ] The selected Google Drive scope already exists or has been intentionally established outside this procedure.
- [ ] Normal authoring backgrounds are stored in the correct `PreviewBackground` helper folder.
- [ ] Stage field-wiring images are stored only in the applicable published Wiring branch.
- [ ] Background images are external references, not embedded.
- [ ] Master Musical Scene names follow the current Scene classification rules.
- [ ] No unnecessary Google Drive Scene/Display folder was created merely because an LOR object exists.
- [ ] The candidate was exported to `UserPreviewStaging\<username>`.
- [ ] The controlled master was not overwritten.
- [ ] Production parser/ingest work will use only the approved controlled Preview set.

---

## Related Documents

- [Prop and Display Naming Conventions](A_Naming_Conventions.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)
- [Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md)
- [Preview Import Workflow](Preview_Import_Workflow.md)
- [Preview Merger](../03_Preview_Merger/README.md)
- [Google Drive Folder Structure](../../00_Project_Overview/00-Google_Drive.md)
- [Folder Alignment Engineering Design](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [FormView](../04_FormView/README.md)

# Changelog

- 2026-08-17 — Reconciled the operator workflow with the current Display-folder hierarchy, `PreviewBackground` contract, Master Musical Preview model, Scene naming/path-resolution rules, `UserPreviewStaging` boundary, Preview Merger production status, and current FormView wiring-image workflow.
- 2026-08-11 — Added Master Musical Preview authoring handoff and documentation-root rule.
- 2026-05-10 — Updated recommended software tools.
- 2025-10-05 — Initial release.
