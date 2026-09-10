# Scene Folder Marker Content Contract

The marker filename is fixed:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

The **marker body is not a static template** for new/renamed Scenes. LOR2DB reconciliation already knows the exact Scene identity and destination it is asking the Windows runner to create or repair. The runner must generate marker content from that evidence.

## Required generated identity

Every generated marker must contain at least:

```text
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

Folder name: <actual folder name>
Controlled path: <Display Folders-relative path>
Owning scope: <Stage/Sub-stage/Scene identity>
Folder role: <SCENE ROOT | PREVIEW BACKGROUND | PROCEDURES | WIRING>
```

For Scene `01-Front Gate` beneath Stage `01-Front Entrance-FE`, examples are:

```text
Folder name: 01-Front Gate
Controlled path: 01-Front Entrance-FE\01-Front Gate
Owning scope: 01-Front Gate
Folder role: SCENE ROOT
```

and:

```text
Folder name: Procedures
Controlled path: 01-Front Entrance-FE\01-Front Gate\Procedures
Owning scope: 01-Front Gate
Folder role: PROCEDURES
```

## Validation

The LOR2DB runner must verify after create/repair that:

1. the expected folder exists at the derived destination;
2. every required marker exists;
3. the marker's `Folder name` equals the actual containing folder name;
4. the marker's `Controlled path` equals the actual Display-Folders-relative path;
5. the marker's `Owning scope` equals the frozen reconciliation Scene identity;
6. the marker's `Folder role` matches its location;
7. no unrelated file was overwritten or deleted.

A mismatch is not silently rewritten unless the operator explicitly approved a repair action. Existing `LOCAL NOTES` must be preserved when repairing an existing marker.

## Rename behavior

When a Scene is renamed in LOR, LOR2DB must not consider only the folder name. If the controlled Scene folder is renamed or replaced as part of the approved reconciliation action, every required generated marker must also be checked and updated so its embedded identity agrees with the new folder/path.

The browser never accepts an arbitrary path from the user. The expected destination and identity come from frozen reconciliation evidence plus the controlled Stage/Sub-stage relationship.

## Authority

This contract implements the existing Google Drive marker/scaffold rules for LOR2DB reconciliation. It does not change which folders require markers. See:

- `Docs/00_Project_Overview/Google_Drive/operatorSOP/Add_Verify_Marker_Files.md`
- `Docs/00_Project_Overview/Google_Drive/operatorSOP/Create_Stage_Substage_Scene_Folder.md`
- GitHub Issue #143
