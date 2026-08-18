# Preview Import Workflow

| Document control | Value |
|---|---|
| Status | CURRENT |
| System | LOR Preview Authoring |
| Revision | 2026-08-17 |

## Purpose

Use this procedure to obtain the current approved Preview source before beginning authoring work.

The latest completed LOR2DB reconciliation report identifies the Preview source used for the current approved production snapshot.

The report is available from the [LOR2DB Reporting portal](../../../LOR2DB/03_Reporting/README.md).

**Do not edit, overwrite, or save files in the approved source folder.** Import/copy from it into your own working environment.

---

## Step 1 — Find the Current Approved Preview Source

Open the latest completed reconciliation report.

Use the report's **Source folder** and Preview/revision information to identify the current approved production input set.

Do not assume an older local `Database Previews` folder is current merely because it exists on your PC.

---

## Step 2 — Import the Needed Preview

Import the required `.lorprev` file into LOR.

When LOR reports that the same Preview identity already exists:

- if the revision/content already matches the approved source, do not create an unnecessary duplicate;
- if the approved source is newer, update your local working copy from the approved source; and
- if the identity/revision relationship is unclear, stop and review it before authoring.

Do not deliberately create a second Preview identity merely to avoid an import/update warning.

---

## Step 3 — Verify the Preview

After importing, verify:

- Preview name;
- Preview revision;
- expected Preview identity/context; and
- any external background paths needed for the work you are about to perform.

For Master Musical Preview work, also follow [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md) before changing Scene names or Scene backgrounds.

---

## Step 4 — Work Only in Your Own Copy

The approved production source is read-only from the author's perspective.

Do not:

- edit files directly in the approved source folder;
- overwrite the controlled master;
- save experiments into the approved source folder; or
- point the production parser at your personal working/staging folder.

Make changes in your normal LOR working copy.

---

## Step 5 — Export the Candidate to UserPreviewStaging

When authoring is complete, export the candidate `.lorprev` to:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

Allow Google Drive synchronization to complete.

`UserPreviewStaging` is the controlled handoff point for a programmer candidate. It is not the approved production Preview set.

---

## Preview Merger Boundary

The Preview Merger remains the required integrity-control design for comparing independent programmer candidates against the controlled master.

Current production status:

- dry comparison/review principles are current;
- the recovered implementation is still being reviewed against the current Master Musical Preview model; and
- production `--apply` is **not yet approved**.

Therefore, exporting to `UserPreviewStaging` does not authorize the author to replace the master or run production apply.

Follow the current [Preview Merger documentation](../03_Preview_Merger/README.md) for status and stop conditions.

---

## Summary

1. Open the latest completed LOR2DB reconciliation report.
2. Identify the current approved source folder and Preview revision.
3. Import/copy the needed Preview without modifying the approved source.
4. Verify Preview identity/revision before editing.
5. Perform authoring work only in your own copy.
6. Export the finished candidate to `UserPreviewStaging\<username>`.
7. Do not overwrite the controlled master or run an unapproved merger apply.
8. Only the approved controlled Preview set may feed the production V7 parser.

## Related Documents

- [Building a Preview](B_Building_Preview_Howto.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)
- [Preview Merger](../03_Preview_Merger/README.md)
- [LOR2DB Reporting](../../../LOR2DB/03_Reporting/README.md)
