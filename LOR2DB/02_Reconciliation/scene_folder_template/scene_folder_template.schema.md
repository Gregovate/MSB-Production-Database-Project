# LOR2DB Scene Folder Create / Repair Interaction

This is the intended operator interaction for GitHub Issue #143.

## Trigger

Run this check when a frozen reconciliation candidate represents a **new Scene** or **Scene rename** that qualifies as a controlled Stage/Sub-stage/Scene documentation scope under the current LOR/Google Drive naming contract.

## Browser behavior

The LOR2DB browser shows one of these states:

```text
SCENE FOLDER STRUCTURE: PASS
```

or, when missing/incomplete:

```text
SCENE FOLDER STRUCTURE: ACTION REQUIRED
Expected: G:\Shared drives\Display Folders\<owning scope>\<Scene name>
Missing/invalid: <exact findings>

[ Create / Repair Scene Folder Structure ]
[ Defer / Correct Source ]
```

The operator is never asked to type or browse to a destination path.

## Approved create/repair action

`Create / Repair Scene Folder Structure` is an explicit filesystem mutation and therefore requires a deliberate operator action in the authenticated LOR2DB reconciliation UI.

After approval, the Linux backend sends only frozen reconciliation identity plus a fixed operation name to the paired Windows LOR runner. The runner derives the destination beneath its configured `Display Folders` root and consumes the controlled `scene_folder_template` manifest.

The runner:

1. validates that the owning Stage/Sub-stage resolves uniquely;
2. validates that the derived Scene name is the frozen reconciliation Scene name;
3. refuses any destination outside the configured Display Folders root;
4. creates only missing scaffold directories;
5. generates required marker files using the exact actual folder name/path and Scene identity;
6. never silently overwrites existing documents or unrelated files;
7. preserves existing marker `LOCAL NOTES` during an explicitly approved marker repair;
8. revalidates the complete scaffold and marker identity after the mutation;
9. returns a bounded structured result to LOR2DB;
10. leaves reconciliation blocked unless post-create validation is PASS.

## Rename

For a Scene rename, the reconciler must first distinguish:

- expected new folder already exists and is complete;
- old controlled Scene folder exists and may need an approved rename/migration;
- both old and new exist;
- neither exists;
- destination is ambiguous.

No automatic destructive rename or merge is permitted. If an approved rename operation is later implemented, it must preserve all existing Scene documentation and then regenerate/repair required marker identities to the new folder name/path before reconciliation may finish.

## Template boundary

The template defines directories and marker target locations. Marker bodies are generated dynamically; they are not copied static text because the marker must contain the correct folder identity.

See `scene_folder_template.json` and `marker_content_contract.md`.
