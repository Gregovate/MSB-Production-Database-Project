# Panelboard and Controller Install Part 2 — new-thread starter

## Current Production receipt — PR460, October 25

Greg supplied `STAGE server deployment PASS; protected browser and documentation closeout pending` and the wrapper's `#171 PERFORMANCE SERVER DEPLOYMENT PASS` after SSH cleanly returned. Report: `/home/msbadmin/setup-deployment-reports/PR460-Performance-20261025T152418Z`.

The accepted release profile promotes FieldWiring to `875003c504e8a60c5851c530ec6496e4430945d9`, V0.4.27-panel-performance, and leaves Setup at `72a94be772f2e4ae8bfaed74051f667fc87201a6`, V0.3.91-integrated-power. Post-deployment screenshots display V0.4.27 and revision421. PR460 merge is `6cc1f9377c7faa7c7547793a55966b59f2b742cf`; tooling PR461 merge is `8836efaa213006f84fc67d9713c6cbf9d382173a`. Documentation commits are not deployed application identities.

Only `171_power_snapshot_performance.sql` belongs to this release. Do not rerun it, PR457, slot-count migrations or initial imports. The pasted final receipt does not supply the rollback snapshot path/hash; retain the server report as the source for those details rather than guessing. The prior ~6→2-second breaker save and improved controller assignments were disposable acceptance observations, not new measured Production SQL timings.

Server deployment is PASS. Screenshots provide post-deployment UI evidence but do not close the full protected browser acceptance checklist. Protected browser acceptance and remaining release documentation closeout stay pending. #171/#230 under #122 remain open for the remaining scope. Earlier release-preparation and PR457-only baseline statements below are historical and superseded by this disposition.

Read the [current Part 2 field-review requirements](FieldWiring_Panel_Circuit_Design.md#october-25-part-2-field-review--current-engineering-scope) before continuing. They include all controller button/color/chain corrections, equipment replacement and the incomplete cable-history browsing workflow. Earlier baseline statements below are historical. On Greg's laptop, main was confirmed in `C:\lor\ImportExport\MSB-Main`; `VSCode` contains unrelated branch/local work. Check the latest prompt and worktree state; do not switch or pull that unrelated branch to run main tooling.


Continue #171/#230 under commanding #122 in `Gregovate/MSB-Production-Database-Project`. Engineering is authorized; preserve Production and original GIS/FLW source files. Reuse existing schemas, application commands, inventory, release mechanisms and review worktree. Do not repeat settled design decisions or ask Greg to program.

Read repository instructions, `FieldWiring_Panel_Circuit_Design.md`, and `FieldWiring_Panel_Circuit_Capture_Checkpoint.md` in this directory, especially the October24 integrated design, subsequent field corrections, and October25 Production receipt. Read `operatorSOP/Panel_Circuit_Capture.md` and the Production deployment log. Consult current server-owned runtime/review/maintenance runbooks before any corresponding operation.

## Installed baseline and acceptance boundary

PR457 server deployment PASS: both `/opt/fieldwiring` and `/opt/msb-setup` are `72a94be772f2e4ae8bfaed74051f667fc87201a6`. FieldWiring is `V0.4.26-breaker-reports`; Setup is `V0.3.91-integrated-power`. PR457 merged as `c56e3a63c6ad3c0c0d21618a0ef65ec865b25c2c`; release tooling PR458 merged as `c6e88f8a6b81836ec6e38467bc3e4b153ecc4161`. Later documentation commits do not change installed source.

Report: `/home/msbadmin/setup-deployment-reports/PR457-Breakers-20261025T134723Z`. Snapshot path/hash and full receipt are in the checkpoint. Only `171_breaker_state.sql` was applied. Do not replay this completed release, slot-count migrations, initial GIS imports or seed observed states.

Disposable feature acceptance PASS and CLEAN EXIT were reported. **Protected Production browser spot check remains pending.** Obtain/record that result without claiming it from the server receipt; continue independent authorized engineering. Do not close #171/#230/#122 as fully complete.

## Field verification now underway

Greg has entered many panels; outlet/waypoint assignments are not yet verified. Technicians must verify actual supplying panel/breaker and physical outlet labels against the current Park Map, recording discrepancies. Initial breaker positions are unknown until observed; Greg will begin recording them. Required Season2026 ON/OFF targets are separate from observed positions. Preserve reusable task57's October9 80% crew report as history, never infer individual breaker work from it. Local receptacles and fixed loads without waypoints are valid.

## Part 2 priorities

1. Reconcile existing controller power/plug assignment implementation against real installation data; distinguish missing data or untested behavior from missing engineering. Preserve accepted reciprocal controller IN/OUT, same-network cross-stage chains, display names and consistent sorting. Finish the physical power-to-controller-to-display relationship.
2. Reconcile panel/circuit amperage reporting and Display→Controller→Circuit lineage with existing nominal rollups. Show incomplete load basis explicitly; do not present unknown auxiliary/controller consumption as verified capacity or headroom.
3. Extend existing REF inventory for Combo equipment and replacement of failed switches, power supplies, splitters and LOR repeaters. Topology/distance expectations flag inventory to verify; never automatically create installed components. Future24mm equipment labels remain deferred unless explicitly scoped.
4. Simplify FLW cable history to passing speed and footage. A/B and B/A on the same network identify the same cable unless replaced. Use latest recorded test even if years old; retain known2/10/1970 tester-date defects and provenance rather than invent dates. FLW is physical cable/endpoint/network authority; GPX supplies route geometry.
5. Reconcile panel-versus-breaker seasonal behavior and waypoint electrical safety information against actual inventory. Preserve accepted notes, flexible slots including8, breaker sizes, one-click state observations with names/time, change-only checklist, all-breaker/exception/completed PDFs and map links.

Future incremental FLW ingest preserving prior tests and governed GPX compare/snapshot/ingest remain explicitly deferred from the released slice. Keep their backlog visible; do not make them prerequisites for controller installation. Current PostgreSQL map has known inaccuracies; do not silently replace the accepted master. QGIS/basemap calibration stays with its existing owner.

## Nonnegotiable relationships

- One breaker may feed multiple waypoints; one waypoint cannot be supplied by different breakers. Multipole legs and extensions must stay within the same breaker feed.
- FLW supplies valid network endpoints, including panel locations RA-00/CL-00 and network-only distribution points such as SW/PO. Controller network identity remains LOR-authoritative.
- Controller chain IN/OUT relationships must remain reciprocal and readable; a tail may terminate or return to its starting waypoint. Do not infer termination or a closed loop from a remembered example.
- Branching LOR requires repeater verification; long contiguous Ethernet requires switch/power-supply verification, with PoE where applicable. Expectations are not installed inventory evidence.

Run existing engineering tests appropriate to each change and prepare an exact governed disposable candidate for operator review. Reuse `C:\Users\greg\Github\MSB-Production-Database-Project-171-gis-circuits-review`; do not create another laptop worktree. Last review released8898 and GIS source lock, but check current availability/ownership before a new launch. Preserve saved source paths, original files and Production writes. Return the operator shell to `C:\lor\ImportExport\VSCode`. New Production changes require their accepted candidate and governed release; this starter does not authorize replaying earlier migrations.
