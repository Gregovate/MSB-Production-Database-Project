# LOR2DB Controlled Scene Folder Template

This directory is the repository-controlled definition used when LOR2DB reconciliation detects that a new or renamed controlled Scene is missing required Google Drive structure.

The normal operator workflow is:

```text
new / renamed controlled Scene
    -> LOR2DB validates expected Google Drive structure through paired Windows runner
    -> PASS: continue reconciliation
    -> ACTION REQUIRED: show exact missing/invalid items
         [ Create / Repair Scene Folder Structure ]
         [ Defer / Correct Source ]
    -> operator explicitly approves Create / Repair
    -> runner derives destination from frozen reconciliation evidence
    -> runner creates only missing approved scaffold items
    -> runner generates required marker files using the exact expected folder identity
    -> runner revalidates
    -> reconciliation continues only after PASS
```

The browser never accepts an arbitrary filesystem path. The destination is derived from the frozen Scene identity and its owning Stage/Sub-stage.

## Template boundary

`scene_folder_template.json` defines the directory skeleton and marker target locations. The template does **not** contain finished marker files. Marker text must be generated because LOR2DB already knows the exact Scene/folder name that belongs in the marker.

The template must never be copied into `Display Folders` under its literal repository name and must never be interpreted as a live Stage/Scene.

## Marker identity

For every marker created or checked during a Scene create/repair, the marker's embedded folder identity must agree with the actual folder and the frozen reconciliation identity.

For Scene `01-Front Gate`, the Scene-root marker must identify `01-Front Gate`, not a placeholder or an old Scene name. A Scene rename is therefore incomplete until its required markers have also been validated against the renamed folder.

The exact marker body must remain aligned with the current approved marker format. Do not invent a second marker format inside LOR2DB. Existing `LOCAL NOTES` must be preserved during an explicitly approved repair.

## Safety

- no silent Google Drive mutation;
- no arbitrary destination supplied by browser/API input;
- reject any derived destination outside the configured Display Folders root;
- create only missing scaffold items during ordinary repair;
- preserve existing documents;
- conflicting existing folders or marker content require review rather than guessing;
- revalidate after every approved create/repair;
- reconciliation Finish remains blocked until validation passes.

## Authority

Folder and marker placement remains governed by:

- `Docs/00_Project_Overview/Google_Drive/operatorSOP/Create_Stage_Substage_Scene_Folder.md`
- `Docs/00_Project_Overview/Google_Drive/operatorSOP/Add_Verify_Marker_Files.md`

Tracked in GitHub Issue #143.
