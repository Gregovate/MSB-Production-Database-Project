# Review the Folder Alignment Worklist

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Folder Alignment |
| Task | Review the current Documentation Alignment Worklist and choose the next human action |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-24 |
| Keywords | Folder Alignment, worklist, Stage, Scene, Google Drive, review |

[↑ Folder Alignment](../README.md)

## Purpose

Use this procedure after Folder Alignment has generated the current HTML worklist.

The goal is to choose one reviewed, understandable task at a time. The report is evidence and a worklist; it is not permission to bulk-move or rename Google Drive content.

## Procedure

1. Open the HTML worklist created by the current Folder Alignment run.
2. Confirm the report timestamp/current run before using it.
3. Choose one Stage or one clearly bounded issue.
4. Review the Stage/Sub-stage/Scene result and any path/naming notes shown for that item.
5. If the report identifies a straightforward Google Drive maintenance task, open the [Google Drive / Display Folder Operations](../../../../00_Project_Overview/Google_Drive/README.md) portal and choose the matching procedure.
6. If the report shows ambiguous ownership, conflicting evidence, or more than one plausible path, do not guess. Leave the Drive item unchanged and flag it for engineering review.
7. Work one Stage/issue at a time rather than treating the report as a bulk migration list.
8. Re-run Folder Alignment after enough changes have been made that the current report no longer represents the Drive state.

## Common Next Actions

| Worklist finding | Next procedure |
|---|---|
| Existing Stage/Scene needs standard structure cleanup | [Repair or Organize an Existing Stage / Scene](../../../../00_Project_Overview/Google_Drive/operatorSOP/Repair_Existing_Stage_Scene.md) |
| Required marker missing or questionable | [Add and Verify MSB Display Folder Marker Files](../../../../00_Project_Overview/Google_Drive/operatorSOP/Add_Verify_Marker_Files.md) |
| New real Scene documentation scope is needed | [Create a New Stage / Sub-stage / Scene Documentation Folder](../../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Stage_Substage_Scene_Folder.md) |
| Legacy Setup document ownership is clear | [Align a Legacy Setup Document](../../../../00_Project_Overview/Google_Drive/operatorSOP/Align_Legacy_Setup_Documents.md) |
| Current Setup instruction is ready | [Publish a Current Setup Instruction](../../../../00_Project_Overview/Google_Drive/operatorSOP/Publish_Current_Setup_Instruction.md) |

## Expected Result

You have selected one clear next action, used the owning subsystem's procedure, and left ambiguous items unchanged for review.

## If Something Is Wrong

- **The report conflicts with what you see in Drive:** stop and re-run/verify the current inputs before changing Drive content.
- **Two folders appear to match:** do not choose one by similarity alone; flag it for engineering review.
- **A task does not fit any operator procedure:** do not improvise a new rule in Drive. Record the gap for documentation/engineering review.

## Related Engineering

- [Folder Alignment Engineering](../engineering/README.md)
