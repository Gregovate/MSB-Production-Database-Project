# Review the Folder Alignment Worklist

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Folder Alignment |
| Task | Review the current Documentation Alignment Worklist and choose the next human action |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-09-07 |
| Keywords | Folder Alignment, worklist, Stage, Scene, Google Drive, review, Park Infrastructure |

[↑ Folder Alignment](../README.md)

## Purpose

Use this procedure after Folder Alignment has generated the current HTML worklist.

The goal is to choose one reviewed, understandable task at a time. The report is evidence and a worklist; it is not permission to bulk-move or rename Google Drive content.

## Known Non-LOR Top-Level Folder

The following folder is an approved controlled exception under `Display Folders`:

```text
41 Park Infrastructure-PI
```

It is **not Stage 41** and must not be treated as missing/incorrect LOR hierarchy merely because it is stored beside numbered Stage folders. It intentionally has no LOR Preview/Stage identity. The leading `41` is only a human sort aid, and the space after `41` keeps it outside the current `NN-...` Stage-folder pattern.

If a future Folder Alignment report unexpectedly presents `41 Park Infrastructure-PI` as a Stage/Scene target, treat that as a Folder Alignment defect/review finding. Do not rename the folder to make the report happy.

This exception does not apply to `40-CommandCenter`, which is an actual Stage and may have Setup work even when its Preview has no wired inventory items.

## Procedure

1. Open the HTML worklist created by the current Folder Alignment run.
2. Confirm the report timestamp/current run before using it.
3. Choose one Stage or one clearly bounded issue.
4. Review the Stage/Sub-stage/Scene result and any path/naming notes shown for that item.
5. If the report identifies a straightforward Google Drive maintenance task, open the [Google Drive / Display Folder Operations](../../../../00_Project_Overview/Google_Drive/README.md) portal and choose the matching procedure.
6. If the item is `41 Park Infrastructure-PI`, use the dedicated [Park Infrastructure Procedure Folder](../../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md) guidance rather than treating it as an LOR Stage.
7. If the report shows ambiguous ownership, conflicting evidence, or more than one plausible path, do not guess. Leave the Drive item unchanged and flag it for engineering review.
8. Work one Stage/issue at a time rather than treating the report as a bulk migration list.
9. Re-run Folder Alignment after enough changes have been made that the current report no longer represents the Drive state.

## Common Next Actions

| Worklist finding | Next procedure |
|---|---|
| Existing Stage/Scene needs standard structure cleanup | [Repair or Organize an Existing Stage / Scene](../../../../00_Project_Overview/Google_Drive/operatorSOP/Repair_Existing_Stage_Scene.md) |
| Required marker missing or questionable | [Add and Verify MSB Display Folder Marker Files](../../../../00_Project_Overview/Google_Drive/operatorSOP/Add_Verify_Marker_Files.md) |
| New real Scene documentation scope is needed | [Create a New Stage / Sub-stage / Scene Documentation Folder](../../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Stage_Substage_Scene_Folder.md) |
| `41 Park Infrastructure-PI` Setup/Procedure structure needs maintenance | [Create the Park Infrastructure Procedure Folder](../../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md) |
| Legacy Setup document ownership is clear | [Align a Legacy Setup Document](../../../../00_Project_Overview/Google_Drive/operatorSOP/Align_Legacy_Setup_Documents.md) |
| Current Setup instruction is ready | [Publish a Current Setup Instruction](../../../../00_Project_Overview/Google_Drive/operatorSOP/Publish_Current_Setup_Instruction.md) |

## Expected Result

You have selected one clear next action, used the owning subsystem's procedure, and left ambiguous items unchanged for review.

## If Something Is Wrong

- **The report conflicts with what you see in Drive:** stop and re-run/verify the current inputs before changing Drive content.
- **`41 Park Infrastructure-PI` appears as an LOR Stage/Scene target:** do not rename it; record a Folder Alignment defect/review item.
- **Two folders appear to match:** do not choose one by similarity alone; flag it for engineering review.
- **A task does not fit any operator procedure:** do not improvise a new rule in Drive. Record the gap for documentation/engineering review.

## Related Engineering

- [Folder Alignment Engineering](../engineering/README.md)
