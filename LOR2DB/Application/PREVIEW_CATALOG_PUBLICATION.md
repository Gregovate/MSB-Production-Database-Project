# Official preview catalog — #81 publication / #299 PC consumption

Implementation candidate: API V0.6.7, Windows runner V1.8.0, PC updater 1.1.0.
Status: repository/disposable validation only; NOT deployed or production accepted.

## Operator workflow

Greg keeps exporting directly to the approved version's master folder. Export
alone never approves new bytes. Production Crew can consume but cannot publish.

1. Before the first changed export, the designated publisher opens LOR2DB and
   selects **Review and Update Official Catalog** while the master still matches
   the completed source. This registers the immutable database baseline. Review
   records baseline evidence without requiring publication yet.
2. Greg exports the changed preview into the same master folder.
3. Greg selects **Review and Update Official Catalog** again, reviews filenames,
   changed prop metadata and exact source digest, checks approval, and selects
   **Publish Approved Catalog**.
4. Programmer PCs consume the new accepted catalog. A changed master that has
   not been approved blocks synchronization. There is no silent regeneration.

No database ingest/reconciliation is required for the proven exceptions below.
No additional staging folder or program installation is required for publishing.
The site action uses the existing Windows runner's approved-folder access.

## Contract and ownership

#81 owns accepted-source baseline and catalog publication. #299 owns consumer
validation and merge. A catalog is NOT a completed reconciliation. Schema2 source
status ACCEPTED/acceptance_kind PREVIEW_CATALOG carries a new evidence_id, parent
publication, actor/time, exact captured-byte manifest, current per-preview
Revision inventory, and database_baseline_evidence_id. Inherited Run/ingest/report
and SQLite digest describe the database baseline, not a new ingest.

The no-ingest proof uses ordered XML structure and every setting by default.
Only these proven exceptions are excluded from the database-contract comparison:

- Root Revision, Brightness and LastSelectedSceneId.
- Direct PropClass MasterDimmable.
- Direct PropClass Name ONLY when its nonblank Comment supplies Display identity.

Preview UUID/name, prop UUIDs, Display Comments, network/controller/channel
assignments, device type, master relationships, scene definitions/membership,
ordering and all unknown fields remain protected. A change outside the narrow
exceptions requires database-contract review; the service does not automatically
run a parser, ingest, promote or guess that a field is safe. This is intentionally
conservative, not a claim that every retained XML field affects physical data.
Channel names remain metadata, not Display identity. Missing Display Comments
cannot silently switch identity through parser Name fallback.

PC comparison continues to preserve local root background brightness and scene
selection. MasterDimmable remains controlled PC content, so publication distributes
Greg's approved False flags rather than reverting them to the prior True values.

## Evidence, concurrency and failure rules

Catalog state is on protected LOCAL Windows storage, not programmer-writable G:.
Baseline registration verifies captured bytes and complete inventory against the
latest completed source before recording its protected contract. It cannot be
bootstrapped from already-modified files. Evidence records have content digests;
published records are immutable by content identity, with one atomic pointer.
Service-account/local administrator filesystem access remains a trust boundary;
these hashes are integrity checks, not an independent signing authority.

Runner uses the existing global operation lock, serializing review/publication
with parser/ingest/version operations. Two complete captures must agree. Review
identity binds files, publisher, database baseline, comparison policy and parent
catalog. Publish repeats capture and authorization; any drift, newer baseline,
parent publication or missing/corrupt evidence blocks. The backend derives source
and publisher itself; browser-supplied folders/source documents are ignored.
Current-source Crew authorization remains in force. Configured catalog reads
fail closed when runner/catalog evidence is unavailable; no stale report fallback.
A later completed database source gets its own catalog namespace; earlier catalog
publications cannot override a newer completed baseline.

Catalog hashes cover actual master bytes, including presentation fields. These
are separate from the PC semantic exclusions. No master writes, production SQLite
writes, ingest, ref-data writes or schema migration are performed by this service.
Local preferences in an approved export can differ without a database ingest.

## Deployment contract — pending Server Management review/approval

This is NOT an instruction to modify production now. Deploy from an exact
committed checkpoint under the existing Server Management change process.

Linux API:
- Install updated backend.py and current_source.py.
- Set LOR_PREVIEW_CATALOG_ENABLED=true only after both ends are ready.
- Set LOR_CATALOG_PUBLISHERS to Greg's explicitly selected existing Access email;
  do not infer publication permission from Production Crew or parser roles.
- Set LOR_CATALOG_ORIGIN=https://my.sheboyganlights.org (exact Origin match).

Existing Windows runner:
- Install updated lor_operator_runner.py plus preview_catalog.py in its existing
  managed source directory; retain configured task identity/profile/state.
- Set LOR_CATALOG_ROOT to an absolute local persistent evidence directory with
  write access only for the runner identity and administrators. Retain it/back it
  up; do not place it in the shared master or staging folder.
- Set the same explicit LOR_CATALOG_PUBLISHERS allowlist.
- No re-pairing, new service credentials, or parser/ingest action is required.

Website/PC:
- Publish landing index.html and catalog.js together with existing protected
  routes. Verify Cloudflare POST routing covers catalog/review and catalog/publish.
- Distribute updater1.1.0 only after reviewed native installation/authority tests.
- Old1.0.x updaters reject schema2 rather than guessing. Required app update check
  remains separate work; do not claim all programmers update automatically.
- Upgrade all participating PCs to1.1.0 before first schema2 publication. The
  first unchanged-master Review can register baseline without clicking Publish.

Master-folder ACLs must restrict master writes to the authoring authority; the
catalog cannot enforce Google Drive permissions. Check this before general
rollout. Unexpected writes block hash validation but can still interrupt service.

## Acceptance still required

Disposable tests cover bootstrap parity, unchanged inventory, allowed metadata,
protected/unknown fields, stale review, actor mismatch, corrupted evidence,
concurrent capture, parent change, API authorization/origin/server-derived source,
actual runner dispatch/lock, mocked page approval and PC schema2 validation.

Before production acceptance: isolated full browser/API/runner review, approved
source-only deployment, real publisher and negative Crew authorization, initial
unchanged-source registration, Greg's export/review/publish, PC retrieval of new
catalog, controlled Show PC apply, LOR reopen/usability and repeat0/0 with backups.
No new Production catalog, live source export or PC apply was performed here.


## Disposable review handoff

Engineering launcher: LOR/preview_sync/production/deployment/Review-LOR2PC-Catalog.ps1.
Build from a clean committed source using Build-Catalog-Review.py beside it.
Review archive: LOR/preview_sync/artifacts/LOR2PC-Catalog-Review-1.1.0-r3.zip.
The first review HOLD exposed a wrong digest reference; r2 matches the actual
parser source_manifest_sha256 and passed initial unchanged-master registration;
its browser upload failed with unproven transport cause. r3 uses native Windows
selection and explicit source/disposable-destination form confirmation.
This is an engineering review bundle, not the two-file programmer installer.
It copies the unchanged master exports read-only, restores a disposable DB clone,
and serves the real catalog API/runner against the copies. Select the local new export in the launcher
(native picker at C:\LOR\ImportExport), then confirm the copy at /review/; never copy it to G: during this review.
Only the clone/copies change. Exact steps are in READ ME - Catalog Review.txt.


## Persistent Windows launch configuration

The updated repository-root run_lor_runner.ps1 loads
%LOCALAPPDATA%\MSB\LORRunner\catalog-settings.json each Start. Configuration:
{"schema_version":1,"enabled":true,"publishers":["gliebig@sheboyganlights.org"]}.
Use the explicitly approved account; this example does not grant anyone access.
Evidence is fixed at preview-catalog below that same local profile directory.
The release installer must provision protected settings/evidence ACLs first.
No ambient interactive environment is accepted as persistent catalog authority.
Malformed enabled settings, redirected paths or unauthorized writable ACLs block
runner Start. No changes to existing DPAPI/pairing/task registration are required.

Actual r3 single-preview browser publication passed; completion feedback was
inadequate and is now a prominent focused receipt panel. Automated three-preview
batch and whole-batch rejection tests pass. Native batch, Print Service config,
actual ACL, production Source/Windows/Web/PC and Cloudflare acceptance remain.
