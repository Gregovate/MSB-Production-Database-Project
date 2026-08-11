# Google Drive Document Organization Procedure

## Purpose

Use this procedure when organizing MSB engineering documents in the Google Shared Drive named **Display Folders**.

The goal is simple:

> Put current, usable information in a predictable location so volunteers and future MSB applications can find it.

You do not need to understand LOR programming, PostgreSQL, QR-code software, or the database design to use this procedure.

The Shared Drive is the permanent home for MSB engineering documents. Applications such as the future setup-instructions and wiring tools will use this folder structure to locate the correct information for volunteers in the field.

---

# Start With the Current Documentation Alignment Worklist

**Do not begin by wandering through the Shared Drive and guessing what should be there.**

Before organizing a Stage, use the current **Documentation Alignment Worklist** produced by the Folder Alignment tool. The worklist is generated from the current LOR parser SQLite snapshot and the current Google Shared Drive folder tree.

The worklist is your roadmap. For each Stage it should tell you:

- the Stage LOR currently expects;
- the Scenes LOR currently expects;
- the standard documentation helper folders that should exist;
- whether the current `Procedures\Setup` folder exists;
- the current published files already found there;
- a link to open the applicable Stage, Scene, or helper folder; and
- legacy instruction locations such as `000-Instructions` that need review.

The report is a **snapshot**. If LOR Stage or Scene organization changes, the parser and Folder Alignment report must be run again before relying on it as the current roadmap.

The normal operator workflow is:

```text
Current LOR previews
        ↓
run_parse_props.ps1
        ↓
current SQLite snapshot
        ↓
run_folder_check.ps1
        ↓
Documentation Alignment Worklist
        ↓
organize the Shared Drive using this procedure
```

The report is read-only. It does not move, rename, create, or delete any Google Drive folders or documents.

---

## What You Need Before Starting

You should have:

- access to the Google Shared Drive named **Display Folders**;
- the current Documentation Alignment Worklist;
- the Stage you are working on;
- the Google Docs or other engineering files that belong to that Stage; and
- enough knowledge of the Stage to know whether an instruction applies to the whole Stage, to one Scene, or to one individual Display.

If you are not sure where a document belongs, **do not guess**. Leave it where it is and flag it for review.

---

## Words Used in This Procedure

### Stage

A **Stage** is a physical area in the park.

Example:

```text
13-Winter Wonderland-WW
```

### Scene

A **Scene** is a grouping of Displays within a Stage.

Examples may include groups such as:

```text
Christmas Story
Christmas Vacation
```

A Scene may have its own shared Wiring, Procedures, and Photos when information applies to that Scene as a whole.

### Display

A **Display** is a physical item or group identified as a Display by MSB.

A Display may have its own folder when it has drawings, instructions, photos, or other information that applies specifically to that Display.

Not every LOR Display requires its own Google Drive folder. Some simple Displays are documented together at the Stage or Scene level.

### Published document

A **published document** is a current document that volunteers are expected to use.

For Procedures, published documents belong directly in the appropriate folder such as:

```text
Procedures\Setup
Procedures\Takedown
Procedures\Maintenance
Procedures\Operations
```

### SourceDocs

`SourceDocs` is for source or working material that volunteers should not normally be presented as the current field instruction.

### Legacy instruction folder

Older Stages may contain a folder named something like:

```text
000-Instructions
```

This is a historical location, not the current standard. The Documentation Alignment Worklist may identify these folders so you know where older instructions are currently stored.

**Do not delete or empty a legacy instruction folder simply because the report found it.** Review the documents and move only material whose current purpose and correct destination are understood.

---

# Standard Stage and Scene Folders

A Stage or Scene can use the following standard structure:

```text
Stage or Scene
│
├── Wiring
│   ├── BackgroundStage
│   │   └── SourceDocs
│   └── MusicalStage
│       └── SourceDocs
│
├── Procedures
│   ├── Setup
│   ├── Takedown
│   ├── Maintenance
│   ├── Operations
│   └── SourceDocs
│
└── Photos
    ├── Current
    ├── Setup
    ├── Takedown
    ├── Reference
    └── Historical
```

These folder names are standardized. Do not rename them for personal preference.

---

# How to Use the Worklist for One Stage

Work through one Stage at a time.

1. Find the Stage in the Documentation Alignment Worklist.
2. Review the **LOR Scenes** shown for that Stage. These are the current Scene names to expect.
3. Use the report's **Open Folder** links to open the Stage, Scene, or `Procedures\Setup` location instead of searching the entire Shared Drive manually.
4. Review the **Published Setup Documents** inventory already found in the standard folder.
5. Review any **Legacy Instructions** locations reported, including `000-Instructions`.
6. Decide which legacy Google Docs are current setup instructions.
7. Move only clearly current Stage-wide instructions to the Stage `Procedures\Setup` folder.
8. Move only clearly current Scene-specific instructions to that Scene's `Procedures\Setup` folder.
9. Leave uncertain, historical, duplicate, or source material in place and flag it for review.
10. When the Stage is complete, regenerate the report if you need a fresh verification of the resulting folder structure.

The worklist tells you what to look for. This procedure tells you what to do with what you find.

---

# Where a Document Belongs

Use the smallest physical or organizational area that the document actually describes.

## If it applies to the whole Stage

Put it in the Stage helper folder.

Example:

```text
13-Winter Wonderland-WW\Procedures\Setup
```

This is the correct location for a setup instruction that applies to the entire Winter Wonderland Stage.

## If it applies to one Scene

Put it in that Scene's helper folder.

Example:

```text
13-Winter Wonderland-WW\Christmas Story\Procedures\Setup
```

This is the correct location for instructions that apply to the Christmas Story group rather than the entire Stage.

## If it applies to one Display only

Keep it with that Display's engineering records.

Do not move a Display-specific document into a Stage-wide folder merely because it is easier to find there.

## If several Displays share the same instructions

They may share one Stage-level or Scene-level instruction.

Do **not** make duplicate copies simply so every Display has its own copy.

The future field application is intended to show the appropriate Stage and Scene documents after a Display QR code is scanned.

---

# Organizing Setup Instructions

Setup instructions are normally viewed as **Stage information** by field volunteers.

A Stage may have more than one setup instruction. That is expected.

For example:

```text
13-Winter Wonderland-WW\Procedures\Setup\
    General Winter Wonderland Setup
    Controller Placement
    Traffic Flow During Setup
```

These may remain separate Google Docs when they describe different setup tasks.

The future setup application will present a list of available instructions. It is not limited to one instruction per Stage.

## What to do

1. Use the Documentation Alignment Worklist to open the Stage's current Setup destination.
2. Review the published documents the report already found in `Procedures\Setup`.
3. Open any reported legacy `000-Instructions` folder and compare its contents with the current published inventory.
4. Identify the current Google Docs that volunteers should use during setup.
5. Move those current documents into `Procedures\Setup` when they belong to the whole Stage.
6. If an instruction applies only to a Scene, place it in that Scene's `Procedures\Setup` folder instead.
7. Leave source material, drafts, obsolete copies, or working files out of the published `Setup` folder.
8. If you cannot determine whether a document is current, leave it in place and flag it for review.

---

# Organizing Other Procedures

Use the same rule for the other procedure folders.

### Takedown

Current takedown instructions belong in:

```text
Procedures\Takedown
```

### Maintenance

Current repair, service, or maintenance instructions belong in:

```text
Procedures\Maintenance
```

### Operations

Current instructions used while operating the display belong in:

```text
Procedures\Operations
```

### Source material

Working files and source material that should not appear as the current volunteer instruction belong in:

```text
Procedures\SourceDocs
```

---

# Wiring Is Different From Setup Instructions

Do not reorganize Wiring as though it were a normal setup procedure.

Wiring has two separate published contexts:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

These are important because the electrical wiring can be different depending on the LOR context.

Field volunteers may not know the difference between a Background sequence and a Musical sequence. The future field application will present these choices in plain language.

For folder organization, preserve the standard folder names exactly.

### BackgroundStage

Contains the published wiring images used for the Background / Static wiring context.

### MusicalStage

Contains the published wiring images used for the Musical wiring context.

### SourceDocs

Working drawings and source material belong under the corresponding `SourceDocs` folder and should not be mixed with published wiring images.

The existing FormView application already depends on this separation.

---

# Photos

Use the standard Photos folders according to how the photo is used.

```text
Photos\Current
Photos\Setup
Photos\Takedown
Photos\Reference
Photos\Historical
```

### Current

Current general photographs of the Stage or Scene.

### Setup

Photos specifically useful while installing or setting up the Stage.

### Takedown

Photos specifically useful while removing or storing the Stage.

### Reference

Reference images that are still useful but are not normal current-condition photos.

### Historical

Older photographs retained as historical records.

Do not delete historical photographs simply because newer photos exist.

---

# Important Rules

1. **Use the current Documentation Alignment Worklist as your roadmap.** Do not reorganize from memory.
2. **Do not rename Stage folders.**
3. **Do not invent or rename Scene folders unless the current LOR structure has been confirmed.**
4. **Do not rename the standard `Wiring`, `Procedures`, or `Photos` helper folders.**
5. **Treat `000-Instructions` as a legacy review location, not the current standard.**
6. **Do not delete old engineering information merely because it looks outdated.** Move or classify it only when its purpose is understood.
7. **Do not create duplicate copies of the same current instruction just to place it under several Displays.**
8. **Do not assume every LOR Display needs its own Google Drive folder.**
9. **Do not place drafts or source material among the current published instructions.**
10. **Do not change BackgroundStage and MusicalStage wiring organization without review.**
11. **Do not worry about QR codes, database links, or web URLs while organizing the files.** The system will use the standardized structure to find the documents later.
12. **When unsure, stop and flag the item for review rather than guessing.**

---

# What the Future System Will Do

The long-term goal is for a volunteer to scan the QR code on a physical Display and open its records through:

```text
my.sheboyganlights.org
```

The QR code identifies the Display. The system will then determine its Stage and other relationships and present the applicable engineering information.

For Setup, this normally means the volunteer will see the Stage's setup instructions regardless of which Display in that Stage was scanned.

For Wiring, the application will keep the Background / Static and Musical wiring contexts separate because those wiring instructions can differ.

The QR code will not depend on a Google Drive folder path. Your job while organizing documents is therefore to put the information in the correct standardized location, not to create or maintain links manually.

---

# Before You Finish a Stage

Check the following:

- [ ] The Stage and Scenes were checked against the current Documentation Alignment Worklist.
- [ ] Current Stage-wide setup instructions are in `Procedures\Setup`.
- [ ] Current Stage-wide takedown instructions are in `Procedures\Takedown`.
- [ ] Current Stage-wide maintenance instructions are in `Procedures\Maintenance` when applicable.
- [ ] Current Stage-wide operating instructions are in `Procedures\Operations` when applicable.
- [ ] Reported legacy `000-Instructions` material was reviewed without deleting uncertain records.
- [ ] Source or working procedure files are not mixed with current published instructions.
- [ ] Scene-specific information is stored under the correct Scene when known.
- [ ] Display-specific engineering records remain with the Display they describe.
- [ ] Wiring published images remain separated between `BackgroundStage` and `MusicalStage`.
- [ ] Working wiring files remain under `SourceDocs`.
- [ ] Current, setup, takedown, reference, and historical photos are separated where practical.
- [ ] Nothing was deleted simply because its purpose was unclear.
- [ ] Any uncertain folders or documents have been flagged for review.

---

# If the Existing Stage Is Messy

Many Stage folders contain engineering information collected over many years. Older folders may not follow the current standard. In particular, many instructions were historically collected together under folders such as `000-Instructions`.

Do not try to make an entire Stage look perfect in one pass.

Start with the information volunteers need now:

1. use the report to identify the current Stage, Scenes, and standard Setup destinations;
2. use the report to find any legacy `000-Instructions` folder and see what it contains;
3. identify the current setup instructions;
4. place only clearly current instructions in the correct `Procedures\Setup` location;
5. identify other clearly current procedures and place them in their proper helper folders;
6. leave uncertain historical information alone; and
7. record anything that needs review.

The Folder Alignment report remains the roadmap for reconciling the remaining historical structure.

---

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md) — engineering architecture and folder-location contract.
- [LOR System Documentation](../01_LOR_System/README.md) — LOR-side system documentation.
- [FormView](../01_LOR_System/04_FormView/README.md) — proven field-wiring application and the existing wiring-folder contract.
