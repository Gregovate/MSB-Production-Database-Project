# Restorable parser checkpoints

Issue #299 / PR #300. Every successful current parser run retains the complete
exact .lorprev set before its validation activity completes. An immutable ZIP is
keyed by source-manifest SHA256; a hashed record binds the ZIP hash, SQLite hash,
original filenames, UUIDs, revisions, approved version, source folder and capture
time. Repeated identical exports reuse the ZIP; changed exports retain another.

Storage on PRINT-SERVER under Print Service:
%LOCALAPPDATA%\MSB\LORRunner\preview-catalog\preview-history\archives
Records reside in sibling records folder. Existing checkpoints are never pruned.
Archives contain external-link XML only. Linked image contents are not backed up.
Overwritten exports predating installation cannot be recovered by this feature.

Parser approval remains independent of ingest. Capture does not publish, restore,
modify PostgreSQL, or rename master previews. Restore UI and an automated
transactional master-set restore are not supplied by this change. The ZIPs are
ordinary restorable source copies for administrator-controlled recovery. Back up
the current master before restoring; retain filenames/UUIDs, rerun parser for the
restored set, then explicitly approve distribution. Never auto-publish a restore.

Validation: four history tests verify exact old bytes and UUID preservation,
idempotent capture/new versions, changed-source rejection, and refusal to replace
corrupt history. Existing catalog and parser-authority tests passed. Native
Windows preflight and first production checkpoint remain operator pending.
