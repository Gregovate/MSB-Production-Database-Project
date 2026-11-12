# Shared Google Drive Server Access — Proof-of-Concept Plan

| Document control | Value |
|---|---|
| Status | RECONNAISSANCE / POC PLAN — no production change authorized |
| Date | 2026-08-21 |
| Applies to | FieldWiring, future Procedure systems, future database-backed field-document applications |
| Google authority | Google Workspace Shared Drive `Display Folders` |
| Server target | `msb-prod-db` |
| Production-change status | NONE |

## Success Requirement

The server-side document connection must behave, from the Google document repository's point of view, like another authorized MSB user with read-only access to the same Shared Drive hierarchy that authorized Windows users see through Google Drive for desktop.

Authorized MSB contributors must continue to create and maintain engineering documents in Google Workspace with familiar tools. PostgreSQL and Directus provide identity, relationships, application metadata, and field presentation support; they are not the normal authoring system for these engineering documents.

The server must expose a navigable filesystem-style view of the Shared Drive so FieldWiring, Procedure systems, and future consumers can traverse the approved folder hierarchy.

## Leading POC Architecture

```text
Google Workspace
        |
        | dedicated MSB server/document identity
        | Viewer access
        v
Shared Drive: Display Folders
        |
        | OAuth scope: drive.readonly
        v
rclone on msb-prod-db
        |
        | read-only mount
        v
/mnt/msb-display-folders
        |
        +--> FieldWiring
        +--> future Procedures applications
        +--> future approved field-document consumers
```

This is the leading proof-of-concept architecture, not yet an approved production installation.

## Why This Fits the Existing MSB Model

Windows authoring/operator machines currently use Google Drive for desktop to expose Google Drive as `G:`. The Linux server does not need to reproduce the Windows software itself; it needs to reproduce the useful behavior:

- authenticate as an authorized Google identity;
- see the same `Display Folders` Shared Drive hierarchy;
- list folders and files;
- descend through Stage/Sub-stage/Scene paths;
- read approved content; and
- remain unable to modify the Google source.

A filesystem-style mount allows existing and future applications to use the repository's established folder-resolution contracts instead of replacing them with one-file-at-a-time Google API logic.

## Proposed Google Identity

Use a dedicated Google Workspace identity for server-side engineering-document access.

The exact account name is not yet selected. Because the access is broader than FieldWiring and may survive a future server move, prefer a purpose-oriented identity over a FieldWiring-specific identity.

Examples for discussion only:

```text
msb-docs@sheboyganlights.org
msb-apps@sheboyganlights.org
```

Do not create or rename an account based on these examples without operator approval.

The Google identity should receive only the access required to read the `Display Folders` Shared Drive.

## Three Read-Only Layers

The POC should intentionally enforce read-only behavior at three layers.

### 1. Google Shared Drive role

The dedicated identity should be a `Viewer` on `Display Folders`.

A Viewer can view Shared Drive files and folders but cannot create, edit, move, or delete normal Shared Drive content.

The Shared Drive must permit Viewer download/copy access to the published files that applications need to read. If Viewer downloading has been disabled by a Shared Drive restriction, the mount may be able to list content but applications will not be able to read the published files.

### 2. Google OAuth scope

Configure rclone with the Google Drive OAuth scope:

```text
drive.readonly
```

This limits the OAuth token to read-only file metadata/content access.

### 3. Linux mount

Mount the filesystem with rclone's read-only mount option:

```text
--read-only
```

The normal field-presentation services therefore do not receive a write-capable mount even if another layer were accidentally loosened later.

## OAuth Client Requirement

Do not rely on rclone's shared Google Drive client ID.

Current rclone documentation states that its shared Google Drive client ID is being retired during 2026. The MSB deployment should therefore use an MSB-controlled Google OAuth client ID and client secret.

The OAuth client is infrastructure configuration. Secrets and refresh tokens must not be committed to Git.

## Headless Server Authorization

`msb-prod-db` is a headless Linux server, so the initial Google authorization does not require installing a browser on the server.

Rclone supports headless authorization using a separate browser-capable computer. The dedicated Google Workspace identity can be authorized in the browser, and the resulting credential material can be installed into the protected rclone configuration on the server.

Do not paste OAuth tokens, client secrets, refresh tokens, or the complete rclone configuration into repository documentation or chat transcripts intended for durable storage.

## Filesystem Root

The shared server-side document root should represent the whole authoritative Shared Drive hierarchy needed by current and future applications, not a FieldWiring-only image directory.

Leading mount-point convention for testing:

```text
/mnt/msb-display-folders
```

This is a proposed convention only until the live server inventory is reviewed against `MSB-Server-Management` standards and existing mounts.

## Required POC Tests Before FieldWiring Uses the Mount

The first proof must test Google/filesystem behavior independently of FieldWiring.

Read-only acceptance should include:

1. authenticate as the dedicated Google Workspace identity;
2. confirm the configured remote resolves the `Display Folders` Shared Drive;
3. list top-level Stage folders;
4. descend into a representative Stage;
5. descend into a representative Scene;
6. read the `_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt` marker in `Wiring`;
7. enumerate `Wiring/BackgroundStage` and `Wiring/MusicalStage`;
8. read a representative JPG/PNG wiring image;
9. read the `Procedures` source marker;
10. enumerate current published files under `Procedures/Setup`, `Procedures/Takedown`, and `Procedures/Inspection`;
11. read a representative published PDF;
12. confirm `SourceDocs` and `Archive` remain physically visible to the filesystem where present but are excluded by application logic, not hidden by an ad-hoc filesystem copy;
13. confirm an attempted local write through the mount cannot modify Google Drive;
14. confirm directory traversal notices a newly created/updated Google Drive item after the expected cache/poll interval; and
15. confirm the mount fails visibly when Google access is deliberately unavailable.

No FieldWiring code change is required to prove steps 1-15.

## Application Integration After POC

Only after the shared mount is proven should FieldWiring be changed to consume it.

FieldWiring then needs the already-identified deterministic root translation:

```text
G:\Shared drives\Display Folders\<relative path>
        ->
/mnt/msb-display-folders/<relative path>
```

Only the platform-specific root changes. Stored LOR/PostgreSQL path evidence and the relative Stage/Sub-stage/Scene hierarchy remain unchanged.

Future Procedure applications should receive the same shared root and enforce their own approved discovery/publication rules.

## Google Docs and Published Field Content

Google Workspace remains the human authoring environment.

For field presentation, the current repository contracts already distinguish working/source material from published field material. Current Setup/Takedown procedure publication is expected in the normal procedure branch while `SourceDocs` and `Archive` are excluded from normal field presentation.

The POC must therefore prove the file formats currently intended for application presentation first, especially JPG/PNG and PDF. Native Google Docs behavior through the Linux filesystem should be evaluated only where a task-specific contract actually requires the application to present the native Google document directly.

Do not redesign the authoring workflow merely to make the mount simpler.

## Live Server Inspection Still Required

Before installing rclone or creating a persistent mount/service on `msb-prod-db`, complete the previously defined read-only live inventory:

```bash
hostnamectl
ip -br addr
sudo ss -ltnp
systemctl --type=service --state=running
sudo docker ps
findmnt
df -hT
sudo systemctl status lor-preflight-api.service
curl -i http://192.168.5.9:8784/health
```

Then compare the desired service account, mount location, config/secrets location, startup ordering, monitoring, backup boundary, and recovery process against the current `MSB-Server-Management` repository and live host.

## Decision Gate

The direct read-only Google Shared Drive mount becomes the preferred production document-source architecture only if the POC proves all of the following:

- the dedicated Workspace identity can traverse the required hierarchy;
- published files can be read;
- read-only protection is effective;
- folder/file changes become visible within an acceptable interval;
- the mount is stable enough for normal field use;
- failures are visible and recoverable;
- the mount can be managed as a normal documented server service; and
- contributors can continue maintaining source material entirely through their existing Google Workspace workflow.

If those conditions fail, investigate a controlled local read-only replica without changing Google Workspace's role as the authoritative authoring repository.

## Related Documents

- `Docs/00_Project_Overview/00-Google_Drive.md`
- `Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md`
- `Docs/00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md`
- `Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md`
- `Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md`
- `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Document_Publication_and_Currentness_Contract.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Shared_Document_Filesystem_Traversal_Requirement_2026-08-21.md`
