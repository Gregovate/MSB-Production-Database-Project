# MSB #171 / #319 / #230 — Site-source synchronization implementation contract

**Status:** Engineering candidate. Neither migrated nor deployed. Governed by #122 and existing Server Management runbooks.

## Three required production interfaces

| Data | Direction | Authority and guardrails |
|---|---|---|
| ExpertGPS GPX waypoint/track | **Bidirectional** ExpertGPS ↔ PostgreSQL | `ExpertGPS Label on Map` (`<label_text>`) is canonical. `<name>` remains Garmin/provenance, not comparison authority. Keep GPS shape, extensions, type/icon metadata, original traces, dates. DB becomes maintenance authority after initial reviewed promotion. Detect concurrent changes by baseline source SHA; do not overwrite conflicting edits. |
| LinkIQ FLW | **One-way** tester/LinkWare → PostgreSQL | Source `.flw` is SQLite and read **only**. Preserve every raw test UUID/payload; corrected LinkWare `Records.CableId` is distinct from immutable embedded `metadata.testId`. Preserve test appearance in all projects. Repeated UUID is one test, not two cables. Match tested cables to reviewed physical cable identities; never infer physical identity from name alone. No tester writeback dependency. |
| 19×13 Super B printable schematic / draw.io | **DB → diagram** | Keep operator-arranged layout and stable draw.io object IDs; update attributes via maintained `site_cable_id`→`drawio_object_id` binding. Circuit/topology and cable connection are DB-owned; schematic display coordinates are not GPS. A generated diagram is an output, not a manually maintained second source. |

## Canonical Shared Drive source locations — operator-confirmed 2026-10-11

Greg selected the following **current live Shared Drive source files** on the laptop and successfully validated them read-only. Use these exact Shared Drive-relative folders and filenames as the common starting locations for all authorized users; do not treat a local Downloads copy or a prior ChatGPT upload as the current source.

| Source | Current Windows `G:` path |
|---|---|
| ExpertGPS / GPX | `G:\Shared drives\Display Folders\Park Drawings\GPS Data\2026 Updates and DB connection\2026_msb_FRESH_START_CLEANED_2026-10-06.gpx` |
| LinkIQ / LinkWare FLW | `G:\Shared drives\Display Folders\Park Drawings\Network\LinkIQ Data Files\LinkIQ Data Import for DB with corrected names.flw` |

The stable shared-folder identity is the path **beneath `Shared drives\Display Folders`**, not an assumption that every user's Shared Drive is mounted as drive `G:`. A user with another mount or drive letter must resolve that same shared location explicitly. Do not silently choose a similarly named local file or substitute a prior export. Never hard-code an operator's `C:\Users\...` profile path in shared repository code.

Each operator may store their resolved absolute file paths and **current source SHA-256 fingerprints** in a local per-workstation configuration outside every Git checkout. Greg's laptop testing configuration is `C:\lor\ImportExport\MSB-319-local\source-paths.json` (a **local example, not a shared master**). The present scripts accept explicit paths; the JSON location is not yet an implemented automatic config loader, so do not claim subsequent commands read it unless wired/tested. Never commit local configuration, raw binary FLW files, or mutable source snapshots as an apparent shared master.

On each run, verify file existence and calculate the fresh SHA-256 before inspection/import. Compare with any saved baseline and fail with a review-required message if it changed; an intentional new ExpertGPS/LinkWare export can advance the baseline after source reconciliation and acceptance. Always inspect FLW read-only and write GPX/draw.io edits to separate reviewed outputs, not directly into shared source files.

**Actual laptop validation:** `2026_msb_FRESH_START_CLEANED_2026-10-06.gpx` contained 233 Label-on-Map waypoints and 181 tracks; `LinkIQ Data Import for DB with corrected names.flw` contained 684 project appearances, 476 unique test UUIDs, 208 duplicate appearances, and zero reported cross-project measurement conflicts. Both file hashes were identical before and after read-only inspection. This proves extraction/source conservation, not yet database import or full reference-link correctness.

## Source validation already executed

On `LinkIQ Data Import for DB with corrected names(5).flw`: **684** LinkWare project representations, **476** distinct UUIDs, **208** duplicate project appearances; original FLW remains read-only. On latest ExpertGPS `(20261011-023933).gpx`: **233** distinct nonempty Label on Map values, **181** tracks. Local pytest tests cover these exact inputs as well as synthetic fail-closed fixtures.

The normalized schema is proposed in `sql/171_site_infrastructure_schema_candidate.sql`. It contains maintained waypoint aliases, tracks, cable identities/network assignments, source observation provenance and test UUID history. It has **not** been installed or validated against a live current PostgreSQL schema. No Production privileges/grants are created.

## Immediate implementation path

- `site_source_sync.py gpx-inspect file.gpx --output snapshot.json` gives a source-preserving manifest and explicit display labels.
- `site_source_sync.py flw-inspect file.flw --output evidence.json` gives test UUID/appearance groups with current LinkWare and original tester labels. No physical cable ID is inferred.
- `site_source_sync.py gpx-export previous.gpx approved_db_projection.json --output revised.gpx` patches a **copy**, only when the GPX hash equals the reviewed DB baseline. Preserve Garmin names and track geometry. Test final import/export in ExpertGPS before full two-way activation; confirm unknown extensions survive application save.
- `site_source_sync.py schematic-export template.drawio approved_db_bindings.json --output new_schematic.drawio` refreshes only bound cable fields in a copy, preserving layout and object IDs. Open/review in draw.io before acceptance.

For GPX bidirectional production mode, persist the last imported/exported source hash and stable waypoint IDs, compare both versions of edited properties, and present *conflicts* rather than last-write-wins. If source identity is ambiguous (old label/coordinates both changed) require explicit review; do not silently create a duplicate waypoint. A GPX plugin MSB-ID extension is optional only after verified ExpertGPS save/roundtrip preserves it.

For the LinkIQ production importer, the database writer must run in one transaction, save the original source SHA, append `(source SHA, project row, UUID)` evidence, insert a unique test only once by UUID, and **never** update a previously reviewed `physical_site_cable_id` based on imported cable text. Status, lengths and speed qualification come from original tester data. Qualification to 1000BASE-T is *not* actual negotiated link speed. Raw data including NVP must remain accessible for audit. Unknown timezone must not be invented. Maintain all spare-cable designations without forcing a network membership.

## Release gates still required

1. Review latest live schema and existing #171/#230 object inventory, reconcile migration number, and complete SQL PostgreSQL disposable tests with current clone. Do not replay Setup migrations 070/071/072.
2. Implement and test a transactionally idempotent PostgreSQL import writer and #230 governed maintenance/approval actions. Read-only extraction alone is not a production importer.
3. Demonstrate `ExpertGPS → DB → GPX → ExpertGPS` roundtrip with unchanged extension metadata and no lost unrelated tracks; demonstrate independent DB/GPX changes trigger conflict.
4. Validate draw.io generation opened, rendered, and printed at 19×13 Super B; verify no lost labels or network routes. Keep accessible print output independently of tablet map.
5. Match reviewed physical cable identities and network taxonomy, accept unresolved candidates explicitly. Test a second FLW containing one new test and a changed label of an old UUID: one appended test, zero duplicated UUIDs, no regression of reviewed cable identities.
6. Complete #122 shared disposable/browser acceptance, explicit Production authorization, Server Management maintenance/freeze/snapshot/deploy/online proof, exact release log, and #230 application acceptance. **No Production data or schema modified during preparation.**
