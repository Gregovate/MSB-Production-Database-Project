# Preview Import Workflow

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | LOR Preview Authoring |
| Task | Get the current approved Preview before editing |
| Audience | Preview authors and programmers |
| Status | CURRENT |
| Owner | MSB Production Crew |
| Last Reviewed | 2026-08-22 |

## Purpose

Use this procedure before changing an existing LOR Preview.

The goal is to make sure you start with the current approved copy instead of an older file from your computer.

---

# 1. Find the Current Approved Preview Source

Open the latest completed LOR2DB reconciliation report.

The report identifies the source folder used for the current approved Preview set and lists the Preview revisions included in that run.

Use the report as the current reference.

Do not assume an older `Database Previews` folder on your computer is current just because it exists.

[LOR2DB Reporting](../../../LOR2DB/03_Reporting/README.md)

---

# 2. Import the Preview into LOR

Import the `.lorprev` file you need from the approved source.

If LOR tells you the Preview already exists:

- if your copy is already the current approved version, do not create another duplicate;
- if the approved copy is newer, update your working copy from the approved source; and
- if you are not sure which copy is correct, stop and ask before editing.

Do not create a second Preview just to get around an import warning.

---

# 3. Check the Preview Before Editing

Open the Preview and check:

- the Preview name;
- the revision number; and
- the background image if the work you are doing depends on it.

For Master Musical Preview work, also review:

[Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)

before changing Scene names or Scene backgrounds.

---

# 4. Work Only in Your Own Copy

The approved source folder is read-only from the Preview author's point of view.

Do not:

- edit the file directly in the approved source folder;
- overwrite the approved master;
- save experiments into the approved source folder; or
- use your personal staging folder as the production Preview source.

Make your changes in your normal LOR working copy.

---

# 5. Export Your Finished Candidate

When your work is complete, export the candidate `.lorprev` file to:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

Allow Google Drive to finish synchronizing.

`UserPreviewStaging` is the handoff location for your finished candidate. It is not the approved master.

---

# Stop Here

Do not replace the approved master yourself.

The review/master-update process is controlled separately.

Your operator task is complete when the correct candidate file is safely in your `UserPreviewStaging` folder.

---

## Expected Result

You started from the current approved Preview, made changes only in your own working copy, and exported the finished candidate to your personal staging folder.

## If Something Is Wrong

If the Preview name, revision, or import message does not match what you expect, stop before editing and ask for review. Do not create a new Preview or overwrite another file to force the import to work.

## Related Operator Documents

- [Preview Authoring Home](README.md)
- [Building a Preview](B_Building_Preview_Howto.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)

## Related Engineering

- [Preview Merger](../03_Preview_Merger/README.md)
- [LOR2DB Reporting](../../../LOR2DB/03_Reporting/README.md)

## Revision History

- 2026-08-22 — Rewritten as a plain-language operator procedure while preserving the approved-source, personal-copy, and `UserPreviewStaging` boundaries.
