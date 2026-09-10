# Controlled `scene_folder_template`

This directory is the repository-controlled definition of the folder skeleton used by the LOR2DB reconciliation system when an operator approves **Create / Repair Scene Folder Structure** for a new or renamed controlled Scene.

It is **not** a live Scene and must never be copied beneath `Display Folders` with the literal name `scene_folder_template`.

## Operator workflow

LOR2DB must validate the expected Scene structure during reconciliation. If the structure is missing or incomplete, the browser shows the exact findings and prompts the operator to approve a governed create/repair action.

The system must **not** silently create Google Drive content merely because a new Scene appeared in LOR.

```text
new / renamed controlled Scene
    -> validate expected Google Drive structure
    -> PASS: continue
    -> ACTION REQUIRED:
         show exact missing/invalid items
         [ Create / Repair Scene Folder Structure ]
         [ Defer / Correct Source ]
    -> operator approves Create / Repair
    -> paired Windows runner performs the fixed template-based operation
    -> revalidate
    -> continue only after PASS
```

## Runtime rule

The LOR2DB paired Windows runner derives the destination from frozen reconciliation evidence. The browser never supplies an arbitrary filesystem path.

The runner creates only the missing expected folders and marker files after explicit operator approval. Existing files/folders are preserved. Existing marker files are not silently overwritten; if marker identity/content is inconsistent with the actual folder, the condition is reported for deliberate repair.

The folder structure is defined by `scene_folder_template.json` in this directory. Empty folders are represented in that manifest rather than with `.gitkeep` files so repository artifacts are never copied into Google Drive.

## Marker identity

Marker files are **generated**, not copied as static files. The generated marker must include the exact actual folder identity that owns it. This is important when a Scene is newly created or renamed: the marker text must agree with the folder name/path the reconciliation system derived.

For example, when the Scene is:

```text
01-Front Gate
```

under:

```text
G:\Shared drives\Display Folders\01-Front Entrance-FE
```

LOR2DB derives:

```text
G:\Shared drives\Display Folders\01-Front Entrance-FE\01-Front Gate
```

and generates required markers whose embedded folder identity matches the actual root/helper folder in which each marker is written.

See `marker_content_contract.md` for the generated marker identity fields and rename behavior.

## Authority

The current folder/marker structure remains governed by:

- `Docs/00_Project_Overview/Google_Drive/operatorSOP/Create_Stage_Substage_Scene_Folder.md`
- `Docs/00_Project_Overview/Google_Drive/operatorSOP/Add_Verify_Marker_Files.md`

The LOR2DB implementation must consume this controlled definition; it must not establish a second competing scaffold.

Tracked in GitHub Issue #143.
