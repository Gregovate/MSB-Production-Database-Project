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
