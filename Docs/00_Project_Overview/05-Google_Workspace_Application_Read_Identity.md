# Google Workspace Application Read Identity

| Document control | Value |
|---|---|
| Status | CURRENT DESIGN / IMPLEMENTATION IN PROGRESS — Google Workspace identity, Shared Drive Viewer access, interactive Drive hierarchy access, and dedicated Google Cloud project verified; Drive API/OAuth/server authorization still pending |
| Date | 2026-08-21 |
| Owner | MSB Database Administrator / Google Workspace Administrator |
| Applies to | `Display Folders` Shared Drive, FieldWiring, future Procedures applications, future approved database-backed field-document consumers |
| Production-change status | Google Workspace identity created and added to `Display Folders` as Viewer; interactive Drive access verified; dedicated Google Cloud project created; no OAuth client, server mount, or runtime service created yet |

## Purpose

This document defines the ownership and documentation boundary for the dedicated Google Workspace identity that will allow MSB server-side applications to read the authoritative Google Shared Drive `Display Folders` hierarchy.

The identity is part of the shared MSB engineering-document architecture. It is **not** a FieldWiring-only account and it is **not** an Ubuntu/Linux user account.

The intended model is:

```text
Authorized MSB contributors
    -> Google Workspace / Shared Drive
    -> create and maintain engineering documents using familiar tools

Dedicated MSB application read identity
    -> authorized Google Workspace identity
    -> read-only access to the same `Display Folders` hierarchy

msb-prod-db and approved applications
    -> use that identity through documented server-side access
    -> traverse and read the approved document tree
    -> do not become the authoring authority
```

Google Workspace remains the human authoring and maintenance environment for the engineering documents. PostgreSQL and Directus remain responsible for database-owned identities, relationships, application metadata, and operational workflows; they do not replace Google Workspace as the normal document-authoring system.

## Why This Document Belongs in the Production Database Repository

The Production Database repository already owns the cross-system Google Drive architecture and path-resolution contracts used by Folder Alignment, FieldWiring, Setup, Takedown, Inspection, and future field-document applications.

The dedicated Google Workspace identity exists because of that shared application/document contract. Its purpose and permission boundary therefore belong with the Production Database Google Drive documentation rather than inside one deployed server's operating manual.

The Production Database repository owns documentation for:

- why the application read identity exists;
- which Google Shared Drive it is intended to access;
- the required Google-side permission level;
- the rule that the identity is shared document-access infrastructure rather than FieldWiring-specific infrastructure;
- the requirement that normal application access be read-only;
- the requirement that authorized contributors continue maintaining source documents in Google Workspace;
- which applications are permitted consumers of the shared document hierarchy; and
- the cross-repository contract with server infrastructure.

## Google Workspace Administrative Procedure Ownership

The procedure for creating and maintaining the dedicated Google Workspace identity belongs with this Google Drive/application architecture.

This documentation records, without storing secrets:

- approved account name;
- account purpose;
- responsible administrative owner;
- membership/permission granted on the `Display Folders` Shared Drive;
- whether the account is permitted to download/read published content;
- any required Google Workspace policy exception or restriction;
- lifecycle expectations if the server or application stack later moves; and
- how another administrator can identify the account's purpose without reconstructing it from conversation history.

Do not record passwords, recovery codes, OAuth client secrets, refresh tokens, or other credentials in Git.

## Implemented Google Workspace Identity

The dedicated Google Workspace identity was created on 2026-08-21 as:

```text
Display name: Engineering Documentation
Account:      msb-docs@sheboyganlights.org
Status:       Active
```

Google Admin evidence at creation showed:

```text
Admin roles assigned: 0
```

This is intentional. The account is an application/document read identity and must not receive Google Workspace administrative roles merely because it is used by server infrastructure.

## Verified Shared Drive Membership

On 2026-08-21, the account was added to the Google Shared Drive:

```text
Shared Drive: Display Folders
Member:       Engineering Documentation
Account:      msb-docs@sheboyganlights.org
Role:         Viewer
```

The membership was subsequently verified in the `Display Folders` Manage members view, where `Engineering Documentation` appeared with role `Viewer`.

This completes the Google-side identity and Shared Drive membership step. The account now has the intended Google-side read-only role for the authoritative engineering-document repository.

Viewer membership must still be validated during the server proof-of-concept for actual file-download/read behavior, including representative JPG/PNG/PDF content. If a Shared Drive policy prevents Viewer downloads, that must be treated as an implementation blocker rather than solved by granting broader edit permissions without review.

## Interactive Google Drive Access Validation

As an additional pre-server check on 2026-08-21, a normal Google browser profile was created for the `Engineering Documentation` identity and used to sign in to `drive.google.com`.

The account successfully opened the `Display Folders` Shared Drive and displayed the expected top-level engineering hierarchy, including current Stage folders such as:

```text
00-HWY 42-HW
01-Front Entrance-FE
02-Triangle-TR
03-Welcome Area-WA
```

as well as current shared/support roots such as:

```text
_Folder_Structure_Logs
_Templates
000-Instructions
```

This validates that:

- the Workspace identity can authenticate normally;
- the `Display Folders` Viewer membership is effective;
- the account can browse the authoritative Shared Drive hierarchy; and
- the user-side Google access model behaves like the intended authorized-PC/user model.

This interactive browser validation does **not** yet prove Linux/rclone OAuth behavior, mount traversal semantics, cache visibility, or programmatic reading/downloading of representative published JPG/PNG/PDF content. Those remain explicit proof-of-concept tests on the server-side implementation.

## Dedicated Google Cloud Project

On 2026-08-21, a separate Google Cloud project was created for the server-side engineering-document access integration:

```text
Project name: MSB Engineering Docs Access
Organization: sheboyganlights.org
```

This project is intentionally separate from existing Google Cloud projects such as `MSB Directus SSO`, `ActiveBackupforGoogleWorkspace`, and `Cloudflare-Access-My MSB`.

The dedicated project exists so the Google Drive API and OAuth client used by the shared engineering-document filesystem can be managed independently without changing unrelated SSO, backup, or access integrations.

Creation of the project does not itself grant Drive access. The next configuration steps are to select this project, enable the Google Drive API, and then configure the Google Auth/OAuth client under the approved read-only access model.

Do not store OAuth client secrets, authorization tokens, or refresh tokens in Git.

## Required Google-Side Access Boundary

The dedicated identity should behave like another authorized MSB user of the `Display Folders` Shared Drive, except that normal application use is read-only.

The implemented Google-side permission is:

```text
Display Folders Shared Drive
    -> msb-docs@sheboyganlights.org
    -> Viewer
```

The account must be able to:

- list the Shared Drive hierarchy;
- traverse Stage/Sub-stage/Scene/Display folders;
- read approved source-folder marker files;
- read published wiring images;
- read published procedure documents and required assets; and
- support future approved application-source branches without changing the human authoring model.

The account must not be used by normal field applications to:

- create source folders;
- upload replacement source content;
- edit documents;
- rename or move source material;
- delete source material; or
- modify database-source marker files.

## Human Authoring Requirement

Successful implementation requires preserving the existing contributor workflow.

Authorized teammates must continue to use Google Workspace, Google Drive folders, Google Docs, PDFs, images, and other familiar approved tools to maintain engineering documentation.

They must not be required to understand or use:

- PostgreSQL;
- Directus collections;
- Linux mount points;
- OAuth configuration;
- rclone;
- server service accounts;
- application APIs; or
- database identifiers

merely to update the engineering information they are responsible for.

The technical infrastructure exists to find and present the correct material. It must not move normal document authoring into a database or server-management interface.

## Server Management Repository Boundary

`Gregovate/MSB-Server-Management` owns the deployed runtime implementation that uses the approved Google Workspace identity on `msb-prod-db`.

The Server Management repository should document, after live inspection and implementation approval:

- Linux package/tool used to access Google Drive;
- server-local service account used to run the mount/service;
- OAuth client configuration procedure as it applies to the host;
- protected location of credential/configuration files without recording secret values;
- filesystem mount point;
- read-only mount options;
- systemd service/unit configuration;
- startup ordering;
- health/status checks;
- logs and troubleshooting;
- restart/recovery procedure;
- failure behavior when Google is unavailable;
- rollback/removal procedure; and
- any host-specific firewall, permissions, or filesystem dependencies.

The server repository must link back to this Production Database Google Workspace identity/document-access contract rather than redefining its purpose or permissions.

## Do Not Duplicate Authority Across Repositories

Use the following split:

```text
MSB-Production-Database-Project
    owns:
        Google document authority
        application read-identity purpose
        Google-side permission contract
        human authoring boundary
        shared filesystem/application consumption contract

MSB-Server-Management
    owns:
        how msb-prod-db authenticates
        how the filesystem is mounted
        runtime service/configuration
        protected credential locations
        health/recovery/rollback
```

If `msb-prod-db` is replaced in the future, the Google Workspace identity may remain valid because its purpose is shared MSB document access, while the server-specific implementation documentation changes with the host.

## Current Decision State

As of 2026-08-21:

- the approved Google Workspace application-read identity is `msb-docs@sheboyganlights.org`;
- the account display name is `Engineering Documentation`;
- the account is active;
- the account has no Google Workspace administrative roles assigned;
- the identity is intended for shared MSB engineering-document access, not only FieldWiring;
- `msb-docs@sheboyganlights.org` is a verified `Viewer` member of the `Display Folders` Shared Drive;
- interactive sign-in at `drive.google.com` successfully exposes the expected `Display Folders` hierarchy to the account;
- the dedicated Google Cloud project `MSB Engineering Docs Access` has been created under `sheboyganlights.org`;
- the Google Drive API still needs to be enabled in that project;
- the `Display Folders` Shared Drive remains the authoritative editable repository;
- server/application access must remain read-only;
- the server-side filesystem must preserve normal folder traversal;
- actual server-side OAuth, mount traversal, and representative published-file read/download behavior still require proof during the server POC; and
- no OAuth client, rclone configuration, mount, or server service has yet been created as part of this work.

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Stage / Sub-stage / Scene Folder Scaffold](04-Stage_Substage_Scene_Folder_Scaffold.md)
- `../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Shared_Document_Filesystem_Traversal_Requirement_2026-08-21.md`
- `../02_Production_Database/01_System_Architecture/09_Wiring_System/Shared_Google_Drive_Server_Access_POC_Plan_2026-08-21.md`
- `../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md`
