# Preview Import Workflow

Use the **latest LOR2DB reconciliation report** to identify the current approved show-preview source before importing previews.

The report is available from the [LOR2DB Reporting portal](../../../LOR2DB/Reporting/README.md).

⚠️ The approved Source folder is the production preview set. **Do not edit, overwrite, or save files in that folder.** Make changes only in your own working copy.

---

## Step 1 – Find the Current Approved Preview Source

Open the latest reconciliation report.

Section 3 identifies the **Source folder** used for the current approved production import.

Use that Source folder when importing the current show previews.

The report also lists the approved revision of each preview included in that reconciliation.

---

## Step 2 – Import a Preview

When you import a `.lorprev` file, LOR will prompt you depending on whether your system already has that preview:

- **Case A – Same Version (No Update Needed)**  
  You’ll see a message like this:  
 ![Import – Same Version](images/import_01.png) 
  ➡️ If the version matches, no action is needed. Click **Cancel** to avoid creating duplicates.

- **Case B – Newer Version (Update Recommended)**  
  If the approved preview has a newer revision, you’ll see:  
  ![Import – Newer Version](images/import_02.png)  
  ➡️ Click **Yes** to update your existing preview with the latest data.  
  ➡️ Click **No** only if you need to keep your older version as a separate copy (rare).

---

## Step 3 – Verify Revision Numbers

After importing, open the preview. The **revision number** is displayed in the upper right corner:  
![Preview Revision](images/import_03.png)

- Confirm the revision matches the latest reconciliation report.
- This ensures you are sequencing with the latest approved design.

---

## Important – Do Not Save to the Approved Source Folder

The Source folder shown in the reconciliation report contains the approved production preview set.

- Import or copy previews from that folder.
- Do **not** edit files in that folder.
- Do **not** overwrite files in that folder.
- Do **not** save new or experimental previews in that folder.
- Make all changes in your own working location.

The Preview Merger system is under development and is not yet part of the production workflow.

---

## Summary

1. Open the latest LOR2DB reconciliation report.
2. Use Section 3 to find the current approved Source folder.
3. Import previews from that folder without modifying it.
4. Verify preview revisions against the reconciliation report.
5. Make any changes only in your own working copy.

Keeping previews aligned avoids mismatches in sequencing and database exports.
