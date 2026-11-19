# Updater 1.1.2: linked backgrounds and sequencing presentation

Source runtime: 86744ebb4eb4d3bc2b9f5b0e27c9e59ab2e9704b.
Windows functions-only validation at f1db9d726ff2e08bb35f31229b34e94ec689254e passed on PRINT-SERVER under Print Service on October 31, 2026. Runtime PowerShell files are unchanged in the package source; subsequent source changes are README and webpage instructions.

## Behavior

Backgrounds remain external file links. Publication captures each referenced image's path, byte length and SHA256, including changes to image bytes at the same path. Review identity includes image evidence; changes after review invalidate publication. First adoption verifies the existing images without claiming knowledge of prior image contents.

Only G:\Shared drives\Display Folders image links are permitted, with PNG/JPEG/BMP/GIF extensions and a 64 MiB per-file limit. Missing/unreadable/empty images, embedded backgrounds, traversal paths and alternate data streams block publication. Images are not copied or embedded by this release; Google Drive remains responsible for delivering them.

Catalog schema 3 requires updater 1.1.2. Older updaters reject the new schema. The client checks image bytes before review and again before applying preview changes. Unsynced or changed files identify the path and block application. This is byte verification, not an image decoder or a replacement for Google Drive sync.

Known geometry attributes, background references, motion-effect row definitions, preview groups/views and preview label changes are outside the database comparison contract. Physical prop identities, Comment associations, wiring, Scene membership and derived Stage ID remain protected. Unexpected descendants in sequencing-only branches remain protected. Root Brightness and LastSelectedSceneId remain local user preferences.

The programmer window summarizes props added/removed, network/channel changes, dimming, layouts, motion rows, groups/views and background references. Full details remain available. Background byte-only updates use the same external link and require no XML replacement; the current-results message reports verified image count. Per-preview rows list verified external paths. This release does not download images independently.

## Validation and rollout

Python catalog suite: 64 test executions passed, including same-path image replacement, stale publication rejection, legacy comparison evidence and database-contract protection. Windows functions-only suite passed, including C# compilation, image size/hash rejection, duplicate asset evidence and plain-language summaries. ZIP has only Setup and README at its root; embedded runtime hashes and ZIP integrity verified. Full installed-package UI acceptance remains required after installation.

1. Run deployment/Release-LOR2PC-112.py on Linux through sudo. It pins exact candidate and prior website hashes, backs up both pages, installs the immutable ZIP before linking it, and rolls back its own page changes on failure. No restart, parser, ingest or catalog publication.
2. Install the linked-image catalog module on PRINT-SERVER with deployment/Update-Catalog-Linked-Images.ps1 -CandidateCommit 86744ebb4eb4d3bc2b9f5b0e27c9e59ab2e9704b. It allows only the known installed V2 module hash, preserves pairing/task credentials and catalog history, uses managed Stop/Start and restores its backup on failure. Runner stays V1.8.0.
3. Install updater 1.1.2 from https://my.sheboyganlights.org/lor2db/pc/ under the normal LOR account. Keep the existing catalog unpublished until these steps pass.
4. Export the intended approved previews to the existing master folder. Remove superseded exports with the same UUID from that folder. Review and publish in LOR2DB. No database ingest for permitted sequencing/presentation changes.
5. Review on a programmer PC, apply approved changes, reopen LOR, and repeat to confirm ADD 0 / REPLACE 0. Retain backup and audit paths. Do not overwrite local Winter Wonderland 193 or Tunnel 131 with the old catalog while awaiting the new publication.

Immutable installer SHA256: 54f22811360165d025186f572585e0b37ea3a63a18c110603969d9f58f0e7e06.

No production installation or new catalog publication is claimed by the source commit. Greg executes the production steps and retains their receipts. PR300 / issue299 track this release.
