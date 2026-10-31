## October 27 PR470 map-return correction

Greg reports CLEAN EXIT for 822a96a2; panel/cable browsing PASS. Remaining corrections: actual recorded-by name/email, tab-local center/zoom/layer restoration and independent controller visibility. Correction: cable navigation passes; associated power-panel navigation fails. Removed the proposed FLW-derived panel shortcut. Investigate the power association and panel selection separately, using power records only. Setup V0.3.95-map-return distinguishes the new navigation and audit display; FieldWiring V0.4.35-power-panel-link carries the waypoint into the existing power page. No additional migration or Production writes. Exact tests and new operator review pending.

## October 27 PR470 navigation review remains open

Greg reports Cable details appears inert and unassociated WW waypoints lack panel access; PO with a recorded association works. Make Cable details a direct link to existing waypoint-filtered cable history. Preserve exact-panel links and add Find panel to the existing panel browser when no association exists; never infer a supply. Video still shows the old Record details control, absent from the corrected source. Add actual asset-popup browser coverage for visible latest records, not only the generic disclosure helper. No CLEAN EXIT yet for this review.

## October 27 PR470 combo-box network regression

Greg reports previously visible combo-box networks missing. The popup depended exclusively on membership-to-catalog lookup although memberships already supply network_code and FLW tests supply resolved waypoint endpoints/network_key. Preserve membership names directly and include the current FLW endpoint networks independently of physical cable inventory, deduplicated. Do not infer from track geometry, rename SPARE designations, or associate unresolved endpoints. Exact failing live payload is unavailable; operator preview must confirm affected combo boxes.

## October 27 PR470 popup follow-up — CLEAN EXIT with defects

Greg reports CLEAN EXIT and confirms Record details resets for independent displays too. This closes the running preview, not acceptance of its defects. All asset popups must show their latest record directly. Root cause: shared disclosure toggle calls Leaflet update(), which reparses string popup content and loses open state. Bind a persistent DOM content node so refresh/disclosure and asynchronous icon updates preserve state. Keep icon-top placement and existing latest-record selection.

## October 27 PR470 controller popup correction — review OPEN

Greg requests controller names and visible latest record details. Use existing display assignments and configured network/unit ID for labels, keeping CTRL ID secondary. Preserve latest observation ordering and show that single record directly. Review is not complete until Greg posts CLEAN EXIT; no Production acceptance implied by screenshots or partial positive feedback.

## October 27 PR470 sixth candidate — compact labels restored

Greg confirms poles render in the 99f40923 preview but rejects the larger white track-label boxes. Restore the previous compact 12px haloed track labels and centered alignment, keeping the symbol fixes and zoom-dependent labels. No additional SQL or source-import changes. Production unchanged; exact candidate validation pending.

## October 27 PR470 fifth candidate — review corrections

CLEAN EXIT confirmed for 977172b66a50cfb796b4eec3eb5c5396b3bfa04a. Restore documented Display Anchor and Tower symbol mappings, include symbols in offline package, offset/larger track text with light backing. Presentation-only versions retained; exact SHA/cache identities change. Main unchanged00284c290ca30dbaaba7cc240b6db2fe81ad0fd6. Validation and operator acceptance pending; no Production write. WW-10 master correction to OUT-Combo remains pending source reconciliation, alongside erroneous0625 deletion and ingest controls. Never disguise these as renderer fixes.

## October 27 PR470 fourth candidate — map label review

Operator reports CLEAN EXIT for f79b62e30c6213c258dd74e80dcb9359075c310d. Incorporate zoom-dependent waypoint/track labels, upright route alignment and overlap suppression; compact duplicate FLW identifiers, plain sort headings and responsive history rows. Unmatched networks identify the source designation without changing matching rules. Same presentation-only versions V0.4.34-test-identifiers / V0.3.94-map-navigation; exact SHA/cache pins change. Existing uninstalled migration and validation only, fresh current-Production clone. Current main refreshed: 00284c290ca30dbaaba7cc240b6db2fe81ad0fd6. Local 916 Setup/reference contracts, 232 FieldWiring tests and JavaScript label/history checks PASS. Exact CI/browser and next operator review pending. No Production writes.

Source integrity is an open separate workflow gap, not solved by this release: source comparison intentionally retains unmapped existing records (`UNMAPPED_EXISTING_RETAINED`); database network normalization only normalizes AUX separators, so SPARE-01 does not equal SPARE-1. Greg confirms stray0625 must be deleted as erroneous, not retired. No supplied current master/database dependency proof here; no hardcoded map suppression or blind deletion. Owning design records required ingest review/deletion behavior.

## October 27 third PR470 candidate — source IDs and direct navigation

Greg confirms breaker-outlet display is much better; preserve it. d9587b54 preview returned CLEAN EXIT, with remaining changes: unmatched FLW records need source Cable ID/Test ID, popup must lead directly to the panel, and map header needs an origin-aware return button. No Production acceptance/deployment yet.

Expose existing source_pair.display_label (Records.CableId) and original_name (BinRec metadata.testId) in cable list/comparison and add case-insensitive ID search. No UUID/database ID substitution or inferred endpoint association. Open panel links use explicit panel IDs, including supplying panels of remote points; retain Cable details separately. Back to FieldWiring or Back to Setup sits left of Collapse and uses the existing view flag with fixed local destinations. Preserve accepted breaker designation/migration without additional SQL changes or source imports.

Versions: FieldWiring V0.4.34-test-identifiers; Setup V0.3.94-map-navigation. Local 906 Setup +10 reference contracts, 232 FieldWiring and JS map/navigation/source-ID checks PASS. Full CI/browser and new operator review pending. Reuse the same PR/branch, preview worktree, runner and8898. Apply only existing pending 171_panel_receptacles.sql to a fresh current-Production clone and its read-only validator; no migration replay on Production. Previous CLEAN EXIT is recorded.

## October 27 PR470 browser findings — revised candidate, Production unchanged

Greg returned CLEAN EXIT for e25f3fd913bb5363e88f40b43cee3431d473eb58. Supplying circuits now appear, but the candidate is not accepted: map network names/tests were hidden, details were overly technical, existing 1/3 and 2/4 panel-outlet notes were replaced by unknown destinations, and the separate receptacle-creation workflow duplicated existing breakers.

Revised design removes the uninstalled device/feed model entirely. One boolean designation on the existing branch breaker is saved through Breaker settings and the existing breaker_schedule command. Bottom/Top Panel Outlets notes, identities, circuit legs, observations and remote assignments remain. Map shows notes even before designation; does not infer the designation or create records. MAIN designation is rejected. Fresh disposable clone only; do not apply an earlier PR470 migration first.

Networks already derive from FLW through site_network_availability. Correct the network lookup to site_network_id, deduplicate names, and expose existing resolved site_flw_cable_test rows without requiring physical cable binding. Map Show details opens/focuses/scrolls to concise power/network/test information and links to panel circuits/test history. No raw UUIDs, DB revision, hashes or source-review jargon in the normal waypoint view.

Revised versions: FieldWiring V0.4.33-breaker-outlets; Setup V0.3.93-map-details. Local 906 Setup + 10 reference contracts and 232 FieldWiring checks PASS; actual map rendering/navigation and SQL auth/retry/rollback/preservation/FLW-only evidence regressions PASS. Exact CI/browser and fresh current-clone review pending. Prior CI/browser results below apply only to the rejected old candidate. Same PR470, same existing preview runner/8898, revised 171_panel_receptacles.sql and read-only validation; no completed Production migrations replayed. Live Scan acceptance remains deferred.

## October 27 post-install correction — candidate, not deployed

Greg's field evidence shows Panel 42-00 circuits 8/10 supplying 42-03S while the destination map popup reports no circuits. Root cause: matchingCircuits used the default `id` key against circuit records keyed by `site_power_circuit_id`. Fix the lookup without rewriting existing assignments. Separately, named OUTLET devices can now belong directly to a panel with nullable `site_panel_id`, inheriting its location and retaining individual circuit feeds; no overlapping synthetic waypoints. Creation, rename, source reassignment and retirement use the existing authorized revision/idempotency/audit command. Guards protect all generic mutation paths as well.

Candidate versions: FieldWiring V0.4.32-panel-receptacles and Setup V0.3.92-panel-supplies. Existing equipment, controller and remote waypoint records are preserved. Local regressions: 906 Setup tests, 232 FieldWiring tests, actual map JavaScript and isolated SQL acceptance PASS, including six outlets on two distinct breakers, authorization, retry/conflict, atomic rollback and retained retirement history. Browser download is unavailable in this workspace; the existing CI browser workflow includes create/reload/rename/remove coverage. CI and current-clone operator acceptance must finish before any readiness claim.

Reuse `Setup/Acceptance/run_setup_disposable_browser_preview.ps1` with port 8898, exact correction SHA/ref and expected Setup version. Apply ONLY `Database/EngineeringTools/sql/171_panel_receptacles.sql`; validate with `Database/Acceptance/171_panel_receptacles_validation.sql`. The existing reference-data allowlist includes these exact files. PR463 migrations are already installed and must not replay. No GPX/FLW reimport, new infrastructure, Scan installation or Production changes. Authority: Server Management Pre_Production_Browser_Review_Runbook, PostgreSQL_Disposable_Acceptance_Standard and Application_and_Test_Port_Register, reread October 27.

Operator review: 42-03S popup shows panel 42-00 circuits 8 and 10; existing panel destinations remain. Add named panel receptacles on different supplying circuits, reload, rename/reassign/remove in the disposable clone, verify their labels under the existing panel marker and absence of new map points. Unrecorded relationships remain unknown. Retain the runner report and CLEAN EXIT before requesting Production approval. Live Scan acceptance remains a separate deferred field gate.

## October 26 PR463 Production server PASS — browser/Scan acceptance pending

Operator-returned receipt `PR463-Equipment-Location-20261026T155409Z` confirms accepted `820b154cd664f0cac0d1d8dfd38e47b4fe19df9c` installed in FieldWiring and Setup, all four pending migrations committed/validated, preserved business data, return ONLINE and matching Scan installation gates PASS. Full report, rollback snapshot/hash, tooling identities and the corrected Windows archive failure are recorded newest-first in `System_Documentation/Production_Deployment_Change_Log.md`. Do not replay this release. Protected browser and physical live Scan acceptance remain pending; earlier preparation/pending-deployment notes below are historical.

## October 26 PR463 release preparation — not deployed

Accepted application: `820b154cd664f0cac0d1d8dfd38e47b4fe19df9c`; all CI PASS; operator CLEAN EXIT. Greg authorized the two final UI corrections and migration, with live Scan acceptance deferred. Read-only operator evidence confirms shared `2548edd130b5cebad33a44786bc1811c2b089bf8`, Setup `72a94be772f2e4ae8bfaed74051f667fc87201a6`, Scan SHA256 `c2bc2d4e7d9d7ff86c57a7d30a52d427f9897f538aa2ce68c5ffc4f0a305bfea`, healthy real ONLINE and current NAS replication.

Reuse the existing maintenance Deploy orchestrator/lock/snapshot/journal with a bounded PR463 profile. Apply only equipment lifecycle, equipment catalog, Setup077 and Setup078 in order. Preserve all existing business rows; exclude only the new nullable model/controller columns from before/after comparisons, prove those columns remain NULL, and prove the new event tables remain empty before reopening. New reference types/models are intentional seeds, not installed equipment. Partial SQL failure retains maintenance and snapshot; no replay/inverse SQL/automatic OFF.

Promote exact accepted Setup and FieldWiring source under the same fence. Before entry run the unchanged Server Management isolated Scan runner from pinned source. After ONLINE proof use its unchanged Scan deployment runner with new candidate/current-live pins; retain its immediate Scan rollback and report. Never deploy Scan before its Setup routes exist. Scan failure leaves the validated database/apps installed and the prior Scan artifact restored by the established Scan runner; report the separate failure, do not replay migrations. Package exact committed bytes and pinned external helpers in one SCP bundle/foreground SSH. Live route checks prove handoffs only; physical Scan acceptance remains deferred.

Authority: Server Management Production_Database_Change_Deployment_Runbook.md, Production_Database_Maintenance_Mode.md, Display_Scan_Extension_Deployment_and_Recovery.md and Directus_Endpoint_Extension_Isolated_Preproduction_Validation.md, read in this workstream. No new maintenance or Scan deployment mechanism.

# FieldWiring panel circuit capture — implementation checkpoint

Controller location implementation: original /scan/CTRL route retained; inventory offers Record Location; compact/full URL identity, API, shared movement audit, type-separated offline context and latest-observation reads implemented. Park map uses the existing Controller → lor-controller.svg symbol and a Controllers layer; failed refresh clears controller markers along with other live assets. No GPS means unlocated. Local 904 Setup and 232 FieldWiring tests PASS; controller SQL fixture and real mounted static routing PASS. Exact-head browser/CI and fresh disposable controller-location review pending. Pending migration list adds Setup/Database/077_add_setup_controller_location.sql, with read-only setup_88_controller_location_validation.sql. Solid blue default/action fills supersede the failed pale-fill preview; no Production changes.

## October 26 urgent controller location extension — #88/#171 under #122

Controller QR identification already works: Scan CTRL routes to the permanent Controller Inventory. Add a Record Location action there; preserve the existing route and labels. Setup Record Location must accept compact CTRL:id and full /scan/CTRL/id URLs via HID, camera, manual entry and deep link. Reuse its authenticated movement API, explicit location confirmation, GPS/named evidence, training write prohibition, offline queue and client-event retry identity.

Extend the existing ops.setup_movement_event audit with a nullable controller FK and CONTROLLER_MOVE. Keep existing Display/Container commands and histories unchanged; dispatch controller observations to a narrowly scoped authorized SQL command with the same transport contract. No new controller inventory or inferred power/network placement. Latest controller state is derived by observation time then event ID, so delayed offline replay never replaces newer evidence. Exact retries return the original event; changed payload reuse is rejected. Add search/state reads and a type-qualified offline context key to prevent CTRL/DISP numeric-ID collisions. Preserve permanent inventory location fields and accepted controller chains.

Only pending migration 077_add_setup_controller_location.sql applies alongside pending equipment lifecycle/catalog in the existing disposable runner. No completed migrations replayed. Current-clone validation is read-only; fixture writes remain isolated. Test authorization, unknown identities, cross-asset requests, missing/invalid location, exact/conflicting retries, out-of-order capture, training/offline behavior, and existing Display/Container regression before operator acceptance and Production release.

## October 26 button contrast — screenshot133009

Equipment table/functionality are operator PASS on 101c0f99, except button contrast. Cable Table/Search remain PASS. Preview CLEAN EXIT confirmed. Apply the established shared FieldWiring action palette to equipment installation, model management, row actions and dialogs: filled blue-gray secondary actions, blue Save, neutral Reload/Cancel, darker hover and visible keyboard focus in light/dark themes. Reuse connection_controls.css rather than another equipment-only palette. This follows the requested cross-application semantic hierarchy; a repository-wide theme rollout is not claimed by this bounded correction. Preserve accepted layout, controller connection colors, panels, cable results and command behavior. Validate computed button states/contrast in both themes, then prepare the same governed disposable preview. No database change.

## October 26 equipment table correction — screenshot131858

Cable Test Table and Search are operator PASS on ed9113b3; preserve their accepted behavior. Additional Equipment list presentation fails field acceptance: oversized per-device blocks obscure basic inventory. Replace these blocks with a compact semantic table, one row per tracked unit: equipment number, model/name, condition and actions. Keep Edit, Record test/failure, Move/remove, Replace and collapsed history on the same row. Remove repeated Active/UNVERIFIED/source boilerplate and raw type codes from the main list, retaining underlying evidence and command behavior. No schema changes, inventory resets, grouping of distinct units or Production writes. Validate the installed and unassigned tables, lifecycle actions and tablet layout before a fresh disposable candidate.

## October 26 direct-install and cable review corrections

User confirms this is brand-new Additional Equipment with no installations. Remove the stock-first prerequisite: selected waypoint/model/quantity(default1)/single note directly records individual units plus installation events in one revisioned transaction. Model seeds create zero physical units; purchase quantities remain reference evidence only. Models now use supplied names, including LOR RS485 Repeater, MSB Blue/Green Splitters, REOLINK camera, LiteBeam and TEX-200. Remove generic Other equipment/RS485 splitter seed placeholders and raw type suffixes. Manage equipment models supports audited rename and delete before a model is referenced by any equipment record; used identities/history remain protected.

Cable sorting is operator PASS. Search now shows matching waypoint choices while typing, case-insensitively, then filters tests by the selected point. Main/comparison tables wrap to available width; Compare brings the detail into view. Regression covers 1280/768/390px table fit, mixed-case choices, direct installation without stock, model cleanup, audit, permissions and retry. Resolved by direct read-only inspection of the original FLW: 1=PASS, 6=FAIL, 8=INFO, with zero mismatches across 725 appearances / 517 unique tests against embedded metadata.status. Source SHA256 and exact LinkWare anchors are recorded in the design and regression fixture. Same network/unordered accepted endpoints now group together regardless of retained cable ID, direction or length; unknown pairs remain separate. Earlier numeric-code holds below are superseded. Operator reports previous preview CLEAN EXIT.

Pending migration order remains lifecycle then catalog on a fresh disposable current-Production clone only. Final command hash is now bfe6d9975b672fcbd6ec5506110007d2; snapshot remains ff77cdf2081a3828996e67f452acb7ba. Do not replay deployed migrations or reset shared existing infrastructure. Earlier stock-first instructions below are superseded. Current operator preview must finish through its own runner before a replacement preview starts. No Production changes.

## Screenshot100436 — supplied model list restored

The V0.4.31 review omitted the prior equipment picker model vocabulary when introducing the shared catalog; Install Equipment also hid catalog entries without recorded spare units. Correct the pending catalog migration to carry forward supplied model references, including documented 10/100 switch, RS485 splitter and PixieLink choices. Install lists all catalog models plus retained legacy stock descriptions, with an explicit no-recorded-spares message. No stock quantities, physical identities or installations are invented. Added zero-stock model-presence SQL/browser regression. Current preview remains disposable; finish its original runner with CLEAN EXIT before starting the corrected candidate. Production unchanged.

## October 26 next candidate — V0.4.31-field-review (PR463)

Implements the accepted feedback in FieldWiring: separate inventory and fixed-location Install Equipment, quantity 1 by default, selectable individual spare units, changeable model selector, new models/types including Camera, one Notes field and automatic MSB ownership. Existing units/controllers are preserved. Shared type/model catalogs are vocabulary only; #230 may take over their maintenance through its explicit allowlist later. No additional equipment inventory master is created.

Cable History adds network-scoped text search, canonical/accepted-alias deduplication, explicit unresolved labels, sortable headers, human-readable tester-local timestamps and a separate selected-segment comparison grid without source SHA/UUID/standard. Nominal saved test rate is displayed; no negotiated throughput is invented. Numeric FLW result decoding is still a release blocker: the UI says Not decoded rather than guessing PASS. A bounded read-only retained-original-result inspection is included in the disposable validation list to collect the missing evidence automatically.

Waypoint Connections adds a compact field overview and moves detailed records under a collapsed engineering disclosure. Controller scoped payload/caching and deployed SQL materialization are retained. Local 232 application checks and SQL/helper regressions run for this candidate; exact-head CI and protected disposable browser review are required before acceptance. Production protected-browser closeout remains separately pending.

Fresh current-Production clone migration order: `171_equipment_lifecycle.sql`, then `171_equipment_catalog.sql`. Validate with `171_equipment_catalog_validation.sql` (includes retained lifecycle, network, eligibility, authorization and breaker-index checks), then `171_cable_result_evidence.sql`. Do not run the older lifecycle hash validation after the catalog extension; it belongs before that extension. New final snapshot hash `ff77cdf2081a3828996e67f452acb7ba`; command hash `43bed006ec8402b74fd3e27d006b6e06`. Completed Production migrations are never replayed. No original GPX/FLW or Production changes.

Earlier entries below are chronological and superseded where this candidate changes the workflow.

## Segment test comparison requirement added

Greg's screenshot091014 rejects All tests as a raw evidence dump. Required replacement: selected-segment comparison grid with Date/time, Length(ft), Speed(Mbps), PASS/FAIL; one row per field test, latest reliably dated first, readable local dates and no SHA/UUID/import metadata. Source provenance remains stored. Expanded comparison must not squeeze the main segment columns into one-word fragments. Recorded in the owning design; implementation and verified result-code mapping remain pending. No Production changes or new candidate in this documentation update.


## October 26 second field review — e73fcb7e changes required

Greg marks equipment waypoint lookup PASS. The active review still requires Install Equipment terminology and fixed waypoint context, quantity default1, separate Add new item to existing inventory, a reopenable model selector, future governed equipment-type additions, MSB ownership without owner/utility/rating controls, and one Notes field. Current form conflates new device creation and installation; its description and source_evidence controls both display Notes.

Cable History requires verified PASS/FAIL rather than numeric codes, speed only in the main table, network-scoped canonical waypoint choices without duplicate ID/raw-label entries or misleading BELLS, and human-readable local timestamps. Source inspection confirms pointOptions(all) uses all networks and keys resolved IDs/raw labels separately. Numeric TestStatus mapping is still unverified; do not guess from code1 or the saved standard.

Waypoint Connections requires a field-oriented location overview rather than a topology/evidence dump. Purpose: identify supplying panel/breaker/circuits, plugged controllers, installed equipment and network/tests at a selected waypoint. Retain compact verification state and owning-screen links; collapse raw engineering/history. The owning design now specifies these boundaries. No application changes or replacement candidate in this checkpoint update. Existing preview lifecycle remains with its original runner; no new CLEAN EXIT has been supplied for this review. Production unchanged, full acceptance/release pending.


## Equipment/cable correction implemented — disposable acceptance pending

Greg supplied reusable preview CLEAN EXIT. Refreshed main remains d2bc9d02; changes preserve controller application572c3e1e and Production PR464. Screen visibility now precedes focused renders, removing breaker reports, season controls/checklist and power-only guidance from equipment/history. Independent screens retain the panel navigation link/context without the separate return banner. Additional Equipment filters infrastructure types/models and uses one maintained-type waypoint filter for location/Add/Move; legacy recorded locations remain available for reconciliation with new installs blocked. Shared inventory/schema and command enforcement are unchanged.

Cable History displays FLW Records.Standard as a labeled test-standard speed (for example1000Mbps /1000BASE-T), with no absent measured-speed property or invented Unknown prefix. Original standard text and numeric result codes remain; undocumented raw-result qualification/negotiated-speed interpretation is not claimed. Original files and database evidence are unchanged. No new SQL migration.

Local232 application tests, shared equipment-choice regression, cable-history mapping/filter regression, JS syntax and diff checks PASS. Browser regression now covers unwanted controls on initial load/reload, Stage exclusion in location/Add/Move, infrastructure type/model exclusion, network-type locations without LOR evidence, retained legacy locations and standard speed display. Exact-head CI and operator acceptance pending; next pinned SHA/complete launch block belongs in PR463. Only equipment lifecycle migration applies to a fresh current-Production clone; completed migrations are not replayed.


## October 26 current status — controller improved; equipment/cable rejected

Application reviewed:572c3e1ed53cf8d4f4d1521aefe6eabb6f419764. Controller_Preview_Transport_20261026T074049Z.json: full payload2,366,425B/2178ms total/700ms body; controller payload164,801B/1686 and1421ms total/224 and43ms body; headers1462/1378ms; PowerShell parse23/22ms. This is93% fewer bytes. The unchanged full payload also transferred much faster than the preceding23–25seconds, so the full improvement cannot be attributed to application changes. Greg confirms a noticeable browser improvement. This is not full candidate acceptance or Production release authorization.

Six later screenshots confirm unresolved equipment/cable defects: Stage/unrelated waypoints in equipment location and Add; infrastructure types in Add equipment; breaker reports, seasonal selectors/checklist and unrelated panel/power context on equipment and cable history; repeated Unknown speeds alongside retained test standards. Source inspection confirms unfiltered waypoint/type choices, early-return rendering bypassing breaker visibility setup, and the cable renderer reading a measured speed field absent from the power snapshot. Actual FLW raw-result speed/status mapping remains to be inspected, using retained evidence rather than reimporting sources.

The owning design now records the correction contract. No application changes in this checkpoint update. Keep the current preview under its existing runner; no replacement candidate/retest is requested yet. PR463 remains DRAFT/changes required. Remaining broader work includes equipment lifecycle acceptance, cable data correctness, panel/circuit amperage review and technician outlet/physical-label/breaker verification. Labels remain low priority; breaker observations remain unknown until observed. Protected Production browser closeout remains separately pending.


## Controller transport evidence and scoped response — October 26

Report Controller_Preview_Transport_20261026T010158Z.json: detail 136ms/1,886B; full power headers 1,814/2,400ms, body 24,734/22,952ms, total 26,548/25,352ms, parse187/210ms, 2,366,425B. The measured dominant delay is payload transfer through this preview path. Earlier next-diagnostic instructions below are completed; no repeat broad profiling.

Candidate controller deployment now requests `/api/power?view=controller`, a field projection after the identical authorized read-only snapshot call. Default full snapshot, SQL, command validation, all eligibility rows, recorded connections and save retry behavior remain. No new migration. Scale fixture transfers150,039B instead of1,124,593B (87% reduction); 240 waypoints /182 requirements /890 eligibility rows preserved with content/order/multiplicity checks. This is synthetic payload evidence, not the actual preview size or field speed. Local232 application tests PASS. Exact-head Chromium/CI and renewed cold-load field acceptance remain required.

Use the existing disposable runner after the prior preview's CLEAN EXIT; apply only equipment lifecycle migration to a fresh current-Production clone. The transport script now compares one full response with two scoped responses and controller detail. Production unchanged; protected Production browser closeout remains pending.


## Server diagnostic received — initial-load isolation

Report Controller_Initial_Load_Diagnostic_20261026T005419Z.json on preview0e53d5c6 PASS (diagnostic only). HTTP controller list/detail11–19ms; power1211.6/1213.0ms and2,366,425bytes. Snapshot SQL1175.652ms; primary controller list3.097ms; detail queries each below0.21ms. The 15-second field delay is not reproduced by loopback server timing. Remaining unmeasured boundary: laptop/tunnel transfer and browser work. Added `measure_171_controller_transport.ps1` for three read-only GETs through the existing localhost8898 tunnel, separating headers/body/PowerShell parsing. Do not close/restart preview or rerun migrations. Initial-load acceptance remains FAIL; no network/hardware blame inferred.


## Current field result and diagnostic handoff

On observer-corrected preview 0e53d5c6, Greg reports first load 15 seconds, then fast selections. Warm selection improved; initial-load acceptance remains FAIL. No more browser retest requests before measured evidence. Added one read-only diagnostic using the existing preview's recorded state and exact SHA, documented server Python and container-local psql. It reports HTTP timing/size/status, repeated detail/snapshot requests, and read-only actual candidate list/detail/snapshot SQL plans. No Production connection or mutation; no preview rebuild, migrations or source imports. Guard/query-capture tests cover Production-target rejection, data-only state parsing, binding and read-only SQL construction. Operator runs from a second PowerShell window while the preview stays open; retrieve the JSON report for analysis.


## Field latency remains FAIL — management-enabled observer correction

Greg's Racing Arches timings: first 12–13 seconds, then 9/12/11 seconds. Prior CI fixture timings are not field acceptance. The prior controller test fixture did not enable controller-management controls; it missed repeated detail GETs from a page-wide assignment-capability MutationObserver. That observer now consumes the existing selected-detail payload with identity guards instead of issuing requests. The fixture now enables Crew management controls, denies assignment capability for one device, and asserts bounded detail request counts even after 30 unrelated DOM mutations per selection. Existing snapshot reuse, safe-save gates and Production panel correction remain. Exact-head CI and renewed field timings are still required; no Production changes or new migration.


## Controller selection performance — further review HOLD

Greg reports 6–9 seconds switching controllers within the same Who chain on 6963b639; candidate remains unaccepted. Controller deployment now reuses one page-local connection snapshot and shares overlapping reads. Reload, save attempts (including uncertain outcomes), inventory/assignment writes and page hiding invalidate it. Server revision/authorization and exact retry handling are retained. Main controller detail and label rendering share an in-flight detail GET. Cold opening still needs the initial snapshot; no cold-load improvement is claimed. Browser regression records warm selection times, requires zero additional power reads for four same-chain selections, one detail request per selection, a fresh Reload, and correct selection after overlapping responses. Existing stale-save/uncertain-retry/chain tests remain required. No SQL or Production changes.


## PR463 reconciled candidate — V0.4.30-setup-equipment

Reconciled with current main d2bc9d02 (PR464 deployed; PR465 tooling; PR466 receipt). Existing breaker correction/removal, dependency protection, observation history and active-only circuit-name uniqueness are retained. Only pending `171_equipment_lifecycle.sql` is applied to a new current-Production clone; its baseline guard now requires deployed command MD5 `906289a801cae2e2d85957898984f031`. Combined command MD5 `7c6df16cea62a5635db1579d8dfeacb8`; snapshot MD5 `7458c9499a05bf53ad6dc585b369c1f9`. Earlier PR463 hashes/builds and PR460-baseline handoffs are superseded. Setup expected version remains V0.3.91-integrated-power. Never replay installed migrations or reuse a stale point-in-time clone to verify the new Production panel edits.

The pre-reconciliation equipment-screen candidate 7cba2388 passed Setup/Chromium 40224595870, native site checks 40224595883 and compliance 40224595910. Reconciliation requires its own exact-head CI and renewed disposable acceptance. No Production mutation performed.


## Additional equipment simplification — October 25 review

Greg's equipment screenshot is further changes-required evidence. Additional Equipment now focuses on location/spares, existing device records and lifecycle actions. Controller guidance, the global safety banner and global correction history are removed from this route's visible content. Selected-waypoint Connection details retain network/feed/safety context collapsed by default; spares have no network warning. A focused equipment renderer skips unrelated panels/reports/controllers and builds secondary engineering only when expanded. No inventory, command, schema or Production changes. Browser regression now checks focused visibility, spares and retained expandable engineering alongside existing add/failure/retry/move/replace coverage. Renewed disposable acceptance remains pending.

The preceding cable correction f25b70ae passed exact-head Setup/Chromium (40222247790), native site acceptance (40222247848) and Engineering Compliance (40222247768). That evidence does not certify this additional presentation change.

## PR463 disposable review — changes required

Greg rejected the ea080130 cable-history experience: poor browser response, nonexistent AUX-1/AUX-2 network choices, and unrelated site entries in the waypoint filter. This is not browser acceptance. The correction uses unambiguous existing network catalog matches, cable-test endpoint choices including unresolved source labels, cached/indexed evidence projection, lazy history details, and a Cable History-only render path. It changes no SQL or Production data. Invalid source designations remain evidence under Unresolved; no alias conversion or import is performed.

Local filter/identity/cache regressions and JS syntax checks pass. A synthetic 240-waypoint/475-FLW/517-evidence Node benchmark of 100 repeated projections measured 351.76 ms before and 2.45 ms after (cache reuse included); this is not browser load latency or Production timing. Local Chromium execution was blocked by a missing Playwright browser executable; exact-head CI and renewed disposable browser review remain required. Retain the active preview's cleanup report before starting a replacement preview. PR460 protected Production acceptance remains pending independently.

## PR463 — V0.4.28 setup/test recording candidate

Implemented on feature/171-setup-equipment-review for disposable review only. Exact SHA and CI evidence are pinned in PR463. Reuses existing controller/site-device inventories and adds one append-only site-device event history (not another inventory). Controller lifecycle and label behavior remain with the existing controller subsystem. TEST/correction, MOVE/remove and replacement from an existing spare are covered; current installation changes are timestamped now, not backdated. Labels remain low priority.

Incremental clone migration: `Database/EngineeringTools/sql/171_equipment_lifecycle.sql`; read-only gate: `Database/Acceptance/171_equipment_lifecycle_validation.sql`. Requires deployed PR460 function hashes. Do not replay PR460/PR457/initial migrations or ingest source files. Reuse the existing disposable wrapper and review worktree; Setup expected build is V0.3.91-integrated-power, mounted FieldWiring candidate is V0.4.28-setup-equipment. No Production mutation.

Operator review: controller buttons/colors/long chain; add two same-model devices without labels; record failure and correction; move one to spares; replace another with an existing spare and inspect both histories; browse all/network/waypoint cable tests and older/undated evidence; spot-check retained panel/season/report behavior. The source schema does not currently expose measured link speed, so it stays Unknown alongside the recorded test standard; result codes remain explicit until source semantics are validated. Further panel-load reconciliation and technician field verification remain open. PR460 protected browser/documentation closeout is not inferred from this candidate's tests.

Current equipment priority: [setup equipment recording design](FieldWiring_Panel_Circuit_Design.md#setup-equipment-recording--engineering-decision-october-25). Reuse existing controller and shared site-device inventories; preserve `CTRL:` as a special case. Capture installation, dated tests, failures and replacements now. Do not create separate inventories by device type. Labels are low priority (maximum24mm, likely12mm) and do not block entry. Exact schema changes remain a pre-implementation design step.

## Current Production receipt — PR460, October 25

Greg supplied `STAGE server deployment PASS; protected browser and documentation closeout pending` and the wrapper's `#171 PERFORMANCE SERVER DEPLOYMENT PASS` after SSH cleanly returned. Report: `/home/msbadmin/setup-deployment-reports/PR460-Performance-20261025T152418Z`.

The accepted release profile promotes FieldWiring to `875003c504e8a60c5851c530ec6496e4430945d9`, V0.4.27-panel-performance, and leaves Setup at `72a94be772f2e4ae8bfaed74051f667fc87201a6`, V0.3.91-integrated-power. Post-deployment screenshots display V0.4.27 and revision421. PR460 merge is `6cc1f9377c7faa7c7547793a55966b59f2b742cf`; tooling PR461 merge is `8836efaa213006f84fc67d9713c6cbf9d382173a`. Documentation commits are not deployed application identities.

Only `171_power_snapshot_performance.sql` belongs to this release. Do not rerun it, PR457, slot-count migrations or initial imports. The pasted final receipt does not supply the rollback snapshot path/hash; retain the server report as the source for those details rather than guessing. The prior ~6→2-second breaker save and improved controller assignments were disposable acceptance observations, not new measured Production SQL timings.

Server deployment is PASS. Screenshots provide post-deployment UI evidence but do not close the full protected browser acceptance checklist. Protected browser acceptance and remaining release documentation closeout stay pending. #171/#230 under #122 remain open for the remaining scope. Earlier release-preparation and PR457-only baseline statements below are historical and superseded by this disposition.

Current remaining requirements are controlled by [Part 2 field review in the design](FieldWiring_Panel_Circuit_Design.md#october-25-part-2-field-review--current-engineering-scope): controller styling/readable chains; waypoint equipment and replacement; All/Network/Waypoint cable-test history with latest results, lengths, speeds and dates; power/load reporting and technician verification. These changes are not yet implemented or accepted.


| Document control | Value |
|---|---|
| Status | PR464 SERVER DEPLOYMENT PASS — protected Production browser check pending |
| Owner | #171 / #230 under #122 |
| Reviewed | 2026-10-25 |

## October 25 — PR464 Production server deployment PASS

Greg returned the reviewed release runner's server PASS receipt. This is operator-returned evidence; no independent live host probe or protected Production browser acceptance is claimed.

- FieldWiring installed: `2548edd130b5cebad33a44786bc1811c2b089bf8` / `V0.4.29-breaker-correction`.
- Setup verified unchanged: `72a94be772f2e4ae8bfaed74051f667fc87201a6` / `V0.3.91-integrated-power`.
- Application PR464 merge: `af8b6efc0c7a57975071b32fd46bd784e077f2b2`. Release tooling `d339f3cf0956b54f51a464e5c372a5163bc35cb3`; PR465 merge `b8763948b422b9f6fd2f0e39444a8c703b24d2ce`.
- Report: `/home/msbadmin/setup-deployment-reports/PR464-Breaker-Correction-20261025T225218Z`.
- Validated rollback snapshot: `/home/msbadmin/backups/setup-205/msb-pre-pr464-breaker-correction-PR464-Breaker-Correction-20261025T225218Z.dump`.
- Snapshot SHA256: `c3a63d77cfb0a49bfec2dc85a634c4707a5c9e954149622bc9383a0d28b217ce`.
- Only `Database/EngineeringTools/sql/171_unassigned_breaker_correction.sql` applied, with `Database/Acceptance/171_unassigned_breaker_correction_validation.sql`. Command body MD5 is `906289a801cae2e2d85957898984f031`; optimized snapshot remains `1409b5a8bada107ecfd5954c8f49a18d`. Circuit designation uniqueness now applies only to active rows.
- The reviewed runner's PASS contract proves maintenance/freeze, validated snapshot, migration/validation, existing-row preservation, FieldWiring promotion while fenced and return ONLINE with health/source/negative-auth checks. Detailed evidence remains in the retained report.

Disposable operator acceptance: ST-00 correction/deletion and four recreated single-pole Milbank entries PASS; CLEAN EXIT released8898/source lock and restored the other review branch. No panel records were automatically repaired during deployment. Greg must repeat desired corrections in Production. **Protected Production browser spot check remains pending.** Do not replay this successful migration or restore the snapshot as routine cleanup.

PR463 equipment/cable work is not installed by this release. Its later command migration must reconcile the new installed command body and preserve this correction before review/release; do not weaken the baseline guard. #171/#230 under #122 remain open for Part2 work. Earlier pending-release entries below are historical and superseded by this receipt.


## October 25 — PR457 Production receipt / current Part 2 starting point

**Server deployment PASS; protected Production browser spot check pending.** Greg returned the reviewed maintenance runner's successful receipt. This is operator-returned execution evidence, not an independent host probe. Earlier candidate/pending-release sections below are historical and superseded by this receipt.

- Both `/opt/fieldwiring` and `/opt/msb-setup`: `72a94be772f2e4ae8bfaed74051f667fc87201a6`.
- FieldWiring `V0.4.26-breaker-reports`; Setup `V0.3.91-integrated-power` (source advanced for the panel map deep link).
- Application PR457 merge: `c56e3a63c6ad3c0c0d21618a0ef65ec865b25c2c`. Release tooling `7175d3c01f6e3eae218c47d198db7cec5a8cf484`, PR458 merge `c6e88f8a6b81836ec6e38467bc3e4b153ecc4161`. Documentation commits are not deployed source identities.
- Report: `/home/msbadmin/setup-deployment-reports/PR457-Breakers-20261025T134723Z`.
- Validated rollback snapshot: `/home/msbadmin/backups/setup-205/msb-pre-pr457-breakers-PR457-Breakers-20261025T134723Z.dump`.
- Snapshot SHA256: `497c958d8bcf9737bcc91af9190461ff6a3da154834f55c24650df8dba7e1002`.
- Receipt: preflight, maintenance/freeze, snapshot, migration commit, database validation, both source promotions while fenced, and return to service PASS. The reviewed runner's success contract includes controller ONLINE, health, preservation and negative authorization checks; detailed evidence remains in the report.
- Applied only `Database/EngineeringTools/sql/171_breaker_state.sql`; validated with `Database/Acceptance/171_breaker_state_validation.sql`. No GPX/FLW import, slot-count migration replay or initial-state seeding. **Do not rerun the completed release.**

Greg accepted the disposable candidate and authorized release. Initial breaker states remain unknown until observed; Greg will start recording them. Many panels have been entered, but outlet/waypoint assignments are not field-verified. Technicians must verify the supplying panel/breaker and match physical outlet labels to the current Park Map, recording discrepancies instead of guessing. Local receptacles and fixed loads without waypoints are valid. Desired seasonal state, photographs and reusable task57's October9 80% report do not establish current observed state or verified outlet assignments.

Next: protected Production spot check of retained notes, eight-slot FE-00, observed-state recording/name/time, reports and panel map links; record actual results without converting server PASS into assumed feature acceptance. Keep #171/#230 and commanding #122 open for the remaining scope below. The technician email was drafted for Greg; no email was sent.

Read [Part 2 new-thread starter](FieldWiring_Panelboard_Controller_Install_Part_2_Starter.md) and the integrated design before further engineering. Last disposable review ended CLEAN EXIT with port8898/source lock available; recheck current ownership before any new review. Preserve the existing laptop worktree and Production data/source files.

## October 23 panel-diagram candidate — supersedes V0.4.8

V0.4.8 operator review is CHANGES REQUIRED. V0.4.9-panel-diagram remains in #319:
compact same-side spanning breakers, circuit-click waypoint assignments, existing
controller inventory linked to network-box placement and independent outlet plugs.
The two association tables preserve retired rows and audit history; controller IDs
and catalogs are reused. Power-only waypoints expose circuit/plug controls without
network-box fields. A5 is disposable validation evidence, not a Production seed.

Main baseline remains e3590c264da048bdd8ffb5f368fd3f928e15d71a; parent candidate
1197f4f19fc32d61ebae5e6db5db7cbef3c919ad. Design commits precede implementation.
Exact published SHA and CI results belong in #319 before the unchanged cached-path
preview handoff is enabled. Current-clone/operator acceptance and Production remain
open. No new importer, inventory service, workflow or test procedure is introduced.

Local validation: FieldWiring 220 PASS; Setup 901 PASS; source/allowlist 44 PASS
and one real-PostGIS test reserved for existing CI; PGlite 130 command/denial checks
PASS. Actual Chromium page PASS includes 18 two-pole A5 blocks (nine each side),
200 A fixture main, per-leg waypoint assignment, retained IDs/exact retry, Power
outlet controller connection, two Combo inventory installations, light/dark, mobile
width and read-only policy. No Production connection was used for these checks.
The browser runtime was installed only in the engineering environment; operator
PC prerequisites and the existing PowerShell preview procedure are unchanged.

## October 23 integrated continuation (supersedes branch/gap status below)

Work is integrated in existing PR #319, `feature/171-cableiq-import-validation`;
there is one GIS/power schema candidate and one reusable disposable preview.
V0.4.8-breaker-schedule implements the operator's combined breaker entry, whole
amps, show/restoration state, same-breaker multiple outlets, exclusive OUT-Combo
supply, panel meter/remote-main relationship and separate waypoint equipment view.
The [controlled design](FieldWiring_Panel_Circuit_Design.md) records the command
contract and tests; the [candidate SOP](operatorSOP/Panel_Circuit_Capture.md) matches
this workflow. Earlier branch/gap and test entries below are historical evidence.

Current-clone/operator review and Production approval remain open. The supplied
CLEAN EXIT confirms port/source-lock release only. Recurring GPX review/apply and
PC ingestion contracts retain their existing #319/#378 ownership and open gates.

## Controlling requirements

Use [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md), particularly
Required panel, circuit and seasonal power records, October 10 editing ownership,
and OUT-Combo assignments. The October 22 request activates implementation of the
previously deferred panel detail workflow in the existing FieldWiring application.
Production Crew may identify/correct circuits and assign existing waypoints;
Managers retain waypoint identity/coordinate maintenance. Directus remains role
authority. The separate GIS thread owns approved Master GPX synchronization.

## Verified source state

Current main inspected: `e3590c264da048bdd8ffb5f368fd3f928e15d71a`.
FieldWiring backend is `V0.4.2-controller-uid-explorer`; its routes provide wiring,
Controller Inventory and Controller commands, but no panel circuit capture API/page.
This is repository evidence, not a fresh verification of installed Production.

[Existing draft PR #319](https://github.com/Gregovate/MSB-Production-Database-Project/pull/319)
head inspected: `bbbdf25ff6f6b0294eef845ad24f1fafea37d7c6`, branch
`feature/171-cableiq-import-validation`. It is open/unmerged and explicitly lacks
current accepted Production-clone/editor acceptance. Do not merge that stale branch
wholesale or assume its schema is installed.

The draft's `Database/EngineeringTools/sql/171_site_infrastructure_schema_candidate.sql`
defines stable `ref.site_waypoint` / `site_waypoint_alias` identities. Its
`171_site_reference_operations_candidate.sql` proposes `site_panel`,
`site_power_circuit`, `site_circuit_destination`, `site_waypoint_network`, revision
and audit records. These are reuse candidates, not verified live contracts.

## Gaps that must be reconciled

- Draft authorization uses independent email-based `ref.site_editor_grant` records.
  Its Setup HTTP adapter adds a Directus read check, but SQL commands rely on that
  separate grant. Circuit capture must use current Directus authorization in the
  governed command path and preserve authenticated actor attribution. Do not copy
  the grant table as an independent role authority.
- Draft panel identity requires an existing waypoint; verify how permanent panels
  with unknown location are captured without fabricated waypoint or coordinates.
- Draft owner enum only permits UNKNOWN/MSB/CITY. Required responsible utility
  information, including Alliant, is not represented by that enumeration.
- Draft meter field is one text value; it does not establish meter-to-panel
  cardinality. Do not assume one unique meter per panel.
- Draft circuit/destination evidence lacks the full explicit verification/conflict
  contract and intermediate fuse/disconnect/feed relationships.
- Draft seasonal switching records contain instruction text by year. They do not
  implement separate structured show/off-season desired states, reported condition,
  field-verified condition, utility request versus completion, or Setup-owned
  seasonal activity evidence.
- Reuse many-to-many circuit destinations and independent network memberships.
  Search current labels and retained accepted aliases; selection stores stable IDs.
  Renaming a waypoint must not break relationships or change circuit identity.

## Live inventory received and implementation continuation

The operator supplied the complete read-only inventory from `msb`, captured
2026-10-22T23:45:38.139501-05:00: PostgreSQL 16.9/PostGIS 3.5.2; only `ref.season`
and `ref.site_network` among the queried relations; the three existing Directus
capability/actor functions returned. No waypoint/panel/circuit tables were present.
This resolves the initial catalog prerequisite, without establishing GPX data or
an installed circuit editor. The original [inventory query](Queries/02_Panel_Circuit_Schema_Inventory.sql)
is retained for repeatable comparison.

[Panel Circuit Design](FieldWiring_Panel_Circuit_Design.md) now controls the source
candidate. Existing FieldWiring hosts `/circuits` and guarded `/api/power` routes.
The candidate migration requires #319's waypoint/alias foundation. It replaces
the uninstalled draft POWER definitions, not the source synchronization work.
The two migration paths must be reconciled before combined disposable/Production
release; do not apply both proposed power schemas.

Continue on `engineering/171-230-circuit-capture`. Refreshed #319 head during this
implementation: `ac7b6933af9acb2f97d91012e7385948cca83a75`, now reconciled with
main by that owning thread; its recurring source promotion remains incomplete.

Required subsequent acceptance: real PostgreSQL command/authorization and audit
regression, concurrent correction protection, multiple destinations and networks,
unknown/conflicting feeds, seasonal state separation, current-clone browser
preview, and crew/Manager permission tests. A saved state or completed task never
proves physical de-energization. Production release requires separate accepted
candidate and governing Server Management procedure/authorization.

## Related documents

- [Wiring System](README.md)
- [FieldWiring Application](../../../../FieldWiring/Application/README.md)
- [Reference-data issue #230](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230)

## Source acceptance — October 22 candidate

- Shared FieldWiring/Procedures: **274 passed**, including 11 new transport/atomicity checks.
- Isolated PGlite PostgreSQL: **43 command/denial checks passed**, plus snapshot,
  audit, seasonal separation, prerequisite, replay and transaction rollback assertions.
  This uses synthetic waypoint/Directus fixtures and actual repository capability/
  actor SQL; it is not a PostgreSQL 16 current-Production-clone acceptance run.
- Actual Chromium page: panel/circuit creation, retained-alias search, multiple
  waypoint selection, assignment retirement, two networks on one waypoint,
  utility request without fabricated confirmation, retry after committed save/lost
  confirmation, read-only user and 390px mobile width passed. Mobile screenshot
  inspected; no horizontal overflow. This is local fixture browser acceptance,
  not protected Production or real crew/operator acceptance.
- SQL syntax, JavaScript syntax, affected documentation links and diff whitespace
  checks passed. Existing CI FieldWiring job now runs the new isolated checks;
  remote CI status must be recorded separately.

**Still open:** combine the approved #319 waypoint/source foundation with the
single power schema and update its old map/operations power consumers; current
PostgreSQL 16 Production-clone migration/grant checks; protected role and operator
review; release approval; governed migration/source deployment; live field check.
No schema migration has been run on Production, no GPX source was changed, and
no issue is closed. No operator deployment command is ready yet.


## October 24 operator simplification integrated with #319 grouped breaker

This candidate reuses #319's permanent breaker/pole/circuit design; #454's older circuit-owned breaker schema is **not** an additional install step. Field entry uses existing identity selectors and dropdowns for amp rating, pole count, equipment owner, and equipment category. Routine site-reference records and controller/waypoint assignments require no manually selected verification or free-form evidence; a blank optional note is valid and saves as UNVERIFIED. Security-definer command attribution, revision/audit trail, role restrictions and append-only seasonal work observations remain authoritative. Only observed work evidence retains its mandatory description; blank reference notes are not fabricated.

**Combo is a power-plus-network capability**, not a physical-box class. The existing `ref.site_waypoint.waypoint_type` is structured source classification: controller installation and supplied-power eligibility recognize an independent `combo` type token on OUT-Combo boxes or Combo poles. They never inspect the human waypoint name. Actual production waypoint type labels are a field validation gate; unrecognized classifications must remain unselectable instead of guessing.

Electronic equipment types include DIN power supply, Ethernet switch, PoE switch, extender, splitter and RS485 repeater as separate typed options, without creating inventory records from example purchase links. Actual network/electrical details remain optional until observed.

Source commits on PR319 incorporate the #454 low-friction improvements and isolated regression cases. **Do not deploy #454's older power DDL alongside the #319 canonical migration.** Operator disposable/browser acceptance, current main currency, source lock/review ownership and governed deployment are separate pending gates; passing GitHub CI is not permission to mutate Production.


## October 24 integrated engineering gate — exact source CI

The canonical grouped-breaker #319 branch incorporates the tested low-friction editing correction from draft #454, but **not #454's competing older DDL**. Exact application/SQL/test candidate `75a9bc204be983eac8c0879cc2c7eaa0177356e6` completed all seven GitHub checks **SUCCESS**: FieldWiring full (includes isolated PGlite and Chromium), Setup full, Windows transport, safety, Engineering Compliance and both candidate checks. These checks prove source/fixture behavior, not current-Production-clone or operator acceptance.

The final source fixes:
- regular reference saves succeed without mandatory typed evidence or manual verification;
- stored status defaults to UNVERIFIED; a routine change to a previously verified reference demotes it to UNVERIFIED instead of falsely inheriting old verification;
- audit saves the original command payload so a lost-response retry is exactly idempotent, even when the database supplies defaults;
- breaker rating/pole count and equipment owner/kind are curated dropdowns, while existing nonstandard ratings and owner names remain selectable to avoid accidental loss;
- empty notes are not synthesized into fake field evidence; real seasonal events continue requiring an observation;
- controller placement and power paths use Combo capability from the structured waypoint type, including Combo light poles, never from human display-name substrings;
- new-record forms hide the irrelevant retirement checkbox. Existing records retain governed retirement and audit controls.

No current-Production clone, browser/physical operator acceptance, PR merge, migration or live server/source publication has occurred. The previously recorded GIS source lock must be owner-verified before any new review. Release gate: exact #319 source identity, existing disposable runner/port ownership, current PG16+PostGIS clone, protected Crew/Manager behavior and operator acceptance, then separate authorized #37 Production boundary. Retain #454 draft as reconciliation evidence, but never install its old power migration with this canonical candidate.


## October 24 follow-up: operator feedback corrections to previous browser candidate

The operator rejected another source-only handoff because it had omitted changes already requested from the previous on-screen review. Source engineering continues within the **existing #319 grouped-breaker candidate**, not a new deployment, separate schema or duplicate app.

Actual operator requests and current candidate response:

- **Panel:** optional installation year (4-digit whole-year, unknown blank), selected owner **City Owned / MSB Owned** (retained legacy values remain selectable). Panel meter remains panel-owned.
- **Circuit picker:** use structured power-capable waypoint classification; hide Panel/Stage and other non-endpoint types from ordinary assignment, while retaining already-recorded exceptional legacy assignments for reconciliation. Combo means both power and network and can apply to either a box or a light pole, not a name-substring test.
- **Grouped 2-pole breaker:** offer explicit **also add selected waypoint(s) to the other leg**, default OFF. Preserve the other leg's unrelated waypoints and distinct permanent circuit identities. Never parse a location name as verified physical wiring. Different endpoints per leg remain supported.
- **Waypoint/equipment navigation:** a direct **Open waypoint / equipment** control next to recorded circuit destinations expands the correct existing section and selects that waypoint without forcing a search below the panel board.
- **Add new equipment:** a visible action at the selected Combo location is separate from **Install existing controller**. Use the existing `ref.site_power_device` identities and category choices for DIN power supplies, industrial Ethernet/PoE switches, VDSL extenders, RJ45 splitters and RS485 repeaters. Model selections are dropdowns of supplied example models and retained records; selecting one supplies the category automatically. These are catalog choices, not fabricated installed stock. Physical instance IDs are database-generated. A free-text description is optional Notes.
- **Routine save:** no mandatory verification or evidence text, and no fictitious auto-generated evidence. Existing role, append-only audit, safe idempotent retry, season event verification boundaries and restored current power references remain authoritative.

Mandatory stable identities such as a new panel designation and meter identifier still require factual operator input; the general target remains dropdown-based selection plus optional notes rather than redundant free-form fields. Equipment catalogs can evolve through a later governed reference editor, not a new parallel ownership system.

As of this checkpoint, source changes and browser regression tests have been committed on #319. **This is engineering source, not accepted Production review.** Exact-head GitHub CI completion, current-Production PostgreSQL 16 disposable validation, protected operator acceptance, and #37 authorized release are separate gates. Never launch an overlapping preview while source-lock ownership is unresolved.

## New-thread handoff — final integrated design / October 24, 2026

**Authoritative design:** [FieldWiring_Panel_Circuit_Design.md](FieldWiring_Panel_Circuit_Design.md), heading **Final integrated system design — October 24, 2026**. Follow the controlling section rather than earlier abandoned assumptions about network ownership or Crew network editing.

**One project model, seven required capabilities:** Controller assignment to physically eligible waypoint; true network availability by reviewed GIS route at waypoint; surveyed power/network tracks; FLW LinkIQ cable tests between same permanent waypoint endpoints; Display→Controller→actual circuit demand versus branch breaker capacity; panel/meter/owner/position and source-aware waypoint safety; panel-level versus breaker-level show/off-season planned/actual states. These relationships are cumulative; do not replace existing identifiers/audits with new catalogs.

**Authority:** LOR sets Controller→network and Display→Controller; GPX/GIS reviewed trace/waypoint endpoints define network physical availability and power/network route; FLW is measured link evidence, not route geometry; Controller location/circuit plug associations are Crew-capturable subject to required LOR network availability; Crew **cannot edit networks or GIS traces**. Normal GIS/FieldWiring projection is read-only for network membership. Combo means both power and network facilities, not a specific network.

**Current code status:** #319 remains open with source changes to panel/branch breaker/editor/Combo and optional notes. Earlier exact SHA `f3588c27999333eb8c0be9546cfd72a27556973c` passed 7 GitHub CI checks, but **predates this final integrated design**. Latest checkpoint SHA must be refreshed and checked; don't quote the prior SHA as acceptance for new requirements. Draft #454 has an older incompatible power migration — never deploy both. The final Controller network availability gate, derived circuit amperage rollup, separate panel off-season supply state, safety projection, and network editor/API write denial are **not yet accepted as implemented**. Need reconcile current application and schemas, then implement and test.
 
**Operator preview cleanup receipt:**
```text
Setup REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
PASS: preview port and GIS source lock are available.
Connection to 192.168.5.9 closed.
PASS: preview exited; port and GIS source lock available.
```
Interpretation: disposable browser preview teardown and postflight resource release PASS; **feature acceptance not granted** and no Production deployment. No remote report path shown. Another review requires fresh port/lock ownership check. The operator had identified CHANGES REQUIRED while reviewing.

**Next thread engineering order:** refresh main/#319/#171/#230/#122 and current Server Management runbooks; inventory installed/pending LOR Controller-network/Display load/circuit mappings and GIS source/FLW IDs; resolve schema joins and source-of-truth boundaries; update controlled design before new migrations; implement network availability restriction + deny Crew network-write UI/API, per-leg capacity rollup, panel-level seasonal state/safety and comprehensive tests; run exact-head GitHub checks; prepare and execute only existing disposable PG16/PostGIS/port8898 protected browser review after an actual preflight; retain report; coordinate release under #122/#37. No new parallel app, runtime, mailer, waypoint authority or duplicate migration. No operator technical design or repeated approval request; only request a bounded test or actual release authorization at its proper gate.


## October 24 integrated implementation continuation

Continued existing #319 from e97ab34, with design reconciliation committed first as a2a4347c24d8bb530d97734e3536486038dae131. Main baseline e3590c264da048bdd8ffb5f368fd3f928e15d71a remains contained. Candidate versions: FieldWiring **V0.4.10-integrated-power**, Setup **V0.3.91-integrated-power**.

Implemented in the same uninstalled power migration: derived reviewed route availability, stable-ID LOR prop/subprop requirement corroboration, database Controller placement denial for missing/stale/conflicting sources, read-only physical Display load lineage and per-pole recorded-current subtotal, independent panel plans and panel-targeted existing seasonal activities. Snapshot joins retained FLW UUID/provenance to the same cable endpoints. Waypoint safety follows stored feeds and upstream panels, shows planned targets separately from timestamped field/utility evidence, and never certifies isolation. GIS and FieldWiring use the same availability projection; Crew network assignment/removal controls are removed and the SQL network command is denied even for replay. Existing source bytes/geometry, inventory identities and history remain unchanged.

**Known evidence limits:** recorded Display amps have no verified branch voltage/basis/estimate flag or controller self-load. Rollup is always INCOMPLETE until the owning sources establish these facts; ambiguous multi-controller loads are excluded and listed. Absence of reviewed route provenance intentionally holds placement. E1.31/DMX physical partition remains unresolved by existing LOR Controller inventory and cannot be guessed into eligibility. Existing installation history remains visible when later source changes make it ineligible.

Validation uses existing FieldWiring/Setup suites, expanded PGlite command/denial cases, expanded existing browser script, and the existing PostGIS rollback validation. No new runner, clone sequence, infrastructure service or migration path. Local Chromium launch was blocked by environment socket restrictions; local browser success is NOT claimed. Exact published SHA/CI results are recorded on #319; current Production-clone and protected operator acceptance remain pending.

Browser preparation reuses `Setup/Acceptance/run_setup_disposable_browser_preview.ps1` with the existing three migration paths and two validation paths, port **8898**, original cached GPX/FLW sources, and ExpectedVersion **V0.3.91-integrated-power**. Select the exact final #319 SHA only after its CI passes. The launcher must recheck port/source-lock ownership; the earlier CLEAN EXIT is not a current preflight. Do not run #454's competing power migration. Production remains unchanged; separate #37 release gate still applies.

## October 24 deployment feedback continuation

Operator requirements add focused Panel Circuits, shared Controller Inventory waypoint editing, separate Combo Equipment, and read-only endpoint-pair FLW history. Design recorded first in 0a0baae1; those application changes are still pending. The further cardinality correction is implemented in the existing power command guard: every waypoint permits multiple legs of one breaker but rejects different breakers, including equipment feed paths. Assignment selection marks competing supplies unavailable and retains retirement history. FieldWiring version V0.4.11-waypoint-breaker. Local SQL regression: 193 checks; FieldWiring Python: 220 passed. Production and GIS source files were not accessed or modified. This is an engineering checkpoint, not a replacement browser-ready candidate or feature acceptance. Complete focused screens and exact-head CI before updating the governed disposable handoff.

### Explicit circuit continuation acceptance cases

The design now explicitly describes single-pole and two-pole continuation: both circuits of one two-pole breaker may reach the same waypoint and extend independently to additional waypoints; a single-pole circuit may likewise extend. Every reached waypoint remains exclusive to that supplying breaker. Existing recursive enforcement already supports this; no schema change was needed for this clarification. Expanded existing regression verifies two-pole continuation retains both circuit IDs, single-pole continuation retains its circuit ID, and competing direct/indirect feeds are rejected in both directions. Isolated SQL regression: 203 checks PASS. Browser feature acceptance and remaining focused deployment screens remain pending.

## October 24 deployment screen implementation

FieldWiring V0.4.12-deployment-connections implements focused Panel Circuits, Waypoint Connections, Combo Equipment and Cable Test History routes on the existing host/snapshot/command layer. Controller Inventory now displays and edits the same installation and power-connection rows; moves retire prior rows and create replacements in one existing revision-checked transaction, with exact request replay after an uncertain response. Network-only placement uses the same LOR/GIS gate as Combo placement. Deployment selectors use structured capability types. FLW history groups by stable endpoint pair then physical cable, preserves retests and unresolved bindings, and is read-only. No new tables, migration mechanism or source-file edits. Operator SOP updated. Exact-head regression and disposable candidate preparation are in progress; feature acceptance remains pending.

Deployment regression evidence: local FieldWiring 220 passed; Setup/application-preview 902 passed; source 87 passed/2 skipped; isolated PGlite 207 checks passed. Candidate d33b5705 passed the existing actual Chromium workflow (including shared-record edits, exact replay, stale denial and endpoint-pair history) and real PostGIS/source and release-tooling workflows. Final route isolation follow-up keeps breaker assignment dialogs on Panel Circuits, with waypoint links opening that route. Exact final SHA and CI results belong to the existing #319 handoff comment. Production-clone and protected operator feature acceptance remain pending; no preview was launched here.

## October 24 review follow-up: FE-00 feeder and FLW source pairs

Screenshots confirm the panel inventory/waypoint assignment and outlet choices work. Remaining review corrections implemented as FieldWiring V0.4.13-feeders-flw-pairs: source-declared endpoint labels/designations from the existing LinkIQ intake parser/proposals are visible before physical cable review; remote panels can record their known upstream panel with a nullable feeder breaker; matching panel-prefix waypoint choices sort first, while powered poles and other exceptions remain available. Empty circuit waypoint assignments remain valid for undiscovered/non-show lighting. Existing site_panel is extended, not replaced; no duplicate source parser or physical-cable authority is introduced. Active upstream consistency/cycle protection and unknown-isolation warnings remain. Operator feature acceptance is pending; the current browser review is not assumed closed. Prepare a replacement candidate only after its engineering gates pass; do not disturb port 8898 or the source lock.

## October 24 bounded deployment release scope

Greg directs proceeding with panels, breakers, meters, waypoint assignments **and Controller network placement and actual outlet/circuit assignments** so panel inventory can precede field deployment. The cleaned current master is the initial source; preserve its bytes, provenance and permanent waypoint identities. Later corrections must preserve existing panel/controller relationships. Do not require the later GPX synchronization interface before this release. This supersedes the earlier all-capabilities acceptance requirement only for the explicitly deferred work, not the shared schema or authorization boundaries.

Operator PASS: panel, breaker, waypoint assignment and existing Combo equipment screens on V0.4.13. Controller assignment remains incomplete operator acceptance. Existing model/instance inventory enhancement, failed component replacement and future 24 mm labels, cable-history simplification and direction-independent retest presentation, and GPX ingest/reconciliation workflow remain deferred. The current master is accepted for starting inventory; it does not certify all database geometry or reviewed network routes. No bypass of the LOR/GIS placement gate is authorized.

Controller empty selectors must explain the actual prerequisite from the existing snapshot: unresolved current LOR requirement versus confirmed network with no eligible reviewed route. An outlet with no active recorded supply must explicitly say so and link to Panel Circuits for assignment. Preserve two-pole selection and never choose a circuit from a similar name. Add no records from guesses or browser tests. Inventory may be recorded UNVERIFIED before technicians confirm physical associations.

Use the same canonical migration chain and application host, without competing tables or a new deployment runner. Deferred workflows are not declared accepted merely because their schema/read-only views are shared dependencies. Before Production: exact candidate checks, targeted Controller browser acceptance, current source import/reconciliation evidence, current live checkout preflight and the Server Management database-changing release procedure. No Production deployment has occurred.

### Controller selector prerequisite correction

The existing Controller screen now distinguishes unresolved current LOR programming from a confirmed network without eligible reviewed GIS paths. An outlet with no active recorded circuit displays that fact and links to the existing Panel Circuits editor. This is a presentation correction, not a relaxation of the database gate; V0.4.13 is retained per release identity policy. Existing browser regression now covers both missing-network prerequisites and an unassigned outlet. Local FieldWiring Python 220 passed; isolated PGlite 218 checks passed. Local Chromium could not start (SIGABRT in the restricted runtime); actual Chromium CI remains required. No current-clone data diagnosis, Production deployment, or full Controller operator acceptance is claimed.

## October 24 FLW authority correction — controlling release decision

Greg establishes LinkWare/FLW as physical cable, endpoint and network authority; GPX supplies cable-run geometry only. This supersedes the earlier requirement for reviewed GIS paths before Controller placement. Derive network membership at BOTH uniquely resolved endpoints from existing immutable FLW intake proposals/tests; normalize REG and AUX letter spellings (Aux E / AUX-E) against the existing network catalog. Do not permit Crew network editing or infer connections from waypoint prefixes. Multiple networks may belong to one waypoint. Retain current LOR programming validation and Network/Combo capability checks.

Cable retests group by unordered permanent endpoint pair and normalized network/designation, with recorded physical cable identity separating replacements. Newer reliable tester timestamps win regardless of age; never fall back to an older pass after a newer failure. Preserve known unset tester dates (2/10/1970) and other invalid/missing dates as raw evidence. Without reliable ordering, mark chronology uncertain instead of treating import order or UUID as physical test order. Such uncertainty does not erase endpoint/network evidence. Display test result separately from membership; a past test is not today's live-link proof.

This release reads existing imported records only. No test UPDATE/DELETE, new intake workflow, invented cable binding, duplicate inventory or GPX rewrite. Future incremental FLW ingestion and expanded cable-history presentation are deferred. Controller field acceptance is still required. Operator reports the latest preview CLEAN EXIT with port 8898 and source lock available; next launch must recheck them.

### FLW network implementation checkpoint

FieldWiring V0.4.14-flw-networks replaces the GIS-route prerequisite with FLW-derived endpoint/network membership in the existing site_network_availability projection. Geometry evidence remains separately queryable. Normalized Aux E/AUX-E joins to the existing catalog; both uniquely resolved endpoints participate, and conflicting/deleted source proposals are withheld. Existing LOR/UID checks, typed Network/Combo placement, command audit and shared Controller/Waypoint records remain. No imported test/source rows are modified. Read-only per-cable chronology groups reverse endpoint pairs, selects newest reliable timestamps without an age cutoff, retains newer failures, and marks 1970/missing dates and tied latest times uncertain. Known retired/replaced cable instances do not supply current membership.

Local validation: FieldWiring 220 tests, FLW intake 20 tests, isolated PGlite 219 SQL checks PASS. Exact-head real PostGIS and Chromium checks pending at commit preparation. No new ingestion interface, Production mutation, or operator acceptance claimed.

## October 24 panel endpoints and LOR topology clarification

Greg confirms all panel locations have network facilities, including RA-00 and CL-00. SW and PO are network distribution boxes without power. A GPX waypoint type that lacks Network/Combo must not hide an endpoint established by FLW; use the existing FLW network-membership projection for Controller placement on both screens and at the database boundary. Keep actual outlet power separate: network capability does not establish a power outlet. Specific Controller placement still requires its LOR network to match FLW evidence; do not assign every network to every panel.

LOR topology requirement: branching from one waypoint to two different waypoints uses a LOR repeater at that distribution point. Controllers on a branch are daisy-chained controller-to-controller. Record the end as a terminating resistor, or a return cable to the originating point that continues toward the next waypoint. A return-to-origin continuation must not be represented as an assumed closed electrical ring. Do not manufacture installed repeater inventory or verified branch/termination facts from graph degree alone. Existing RS485_REPEATER equipment classification remains the inventory owner.

The four Racing Arch Controllers are reported from memory as a waypoint-fed controller chain ending there; this is UNVERIFIED field evidence, including the actual termination. The current controller_installation record captures the network attachment waypoint, not Controller predecessor/successor order or branch termination. These are additional topology requirements, not capabilities already implemented or tested. Preserve them for the existing model's topology extension; do not claim complete topology capture from the endpoint fix.

### Endpoint authority and equipment expectations — final clarification

Every uniquely resolved FLW endpoint carrying the required network is eligible regardless of GPX waypoint type. No Panel, SW, PO or other name-based exceptions are needed. Power outlet eligibility remains a separate fact. The waypoint projection exposes FLW-derived network capability so Controller Inventory and Waypoint Connections use the same rule as the command guard. An attachment waypoint may be the origin of a Controller daisy chain; assigning it does not assert a direct cable from each Controller to that waypoint or record chain order.

At INET/E1.31 distribution points, prompt inventory/verification of switches and power supplies where contiguous runs approach roughly 300 feet, and PoE for any security cameras on the line. Multiple same-network neighboring endpoints flag possible LOR branching for repeater verification, not a proven branch or installed repeater. These are read-only equipment expectations. Do not create installed equipment from length, graph shape or network membership. Existing actual inventory is entered only from known equipment. Preserve the Racing Arch chain as unverified recollection.

Operator confirms the latest disposable review CLEAN EXIT and port/source-lock release. Next candidate needs exact-head tests and a fresh lock/port preflight; this is not Production deployment approval.

### V0.4.15 endpoint correction implemented

The snapshot now exposes network_capable from FLW membership. Both Controller and Waypoint selectors consume it, and the redundant database GPX-type veto is removed. Specific LOR/FLW matching remains mandatory, while power connection eligibility remains separate. Panel, SW, PO and arbitrary unclassified FLW endpoints are exercised without name exceptions. Read-only waypoint prompts identify possible LOR branches and INET/E1.31 switch/power/PoE expectations; no installed records are created. Local FieldWiring 220 tests and PGlite 232 SQL checks PASS. Existing browser regression includes panel placement and expectation-without-inventory-mutation checks. Exact-head Chromium/PostGIS gates pending at preparation. Production and immutable source tests remain unchanged. Chain-order/termination capture is not implemented by this endpoint correction; that limitation remains explicit.

## October 24 controller chain order — required before release

Greg requires the physical order, not only the shared network origin. Extend the existing
`ref.site_controller_installation` with `upstream_kind` (UNKNOWN, WAYPOINT,
CONTROLLER), nullable `upstream_controller_id`, and `chain_end` (UNKNOWN,
TERMINATOR, RETURN_TO_ORIGIN). The existing waypoint remains the chain origin.
UNKNOWN preserves incomplete observations; never infer a direct connection from
an older origin-only record. A controller predecessor is an existing inventory ID,
not another inventory or wiring system. Controller-to-display wiring is unchanged.

Both supported endings are explicit: RA-00 → 1001 → 1002 → 1003 → 1004 → RA-00
(return cable for onward continuation), or the same chain ending in a terminating
resistor. Return is an end designation at the origin, not a controller dependency
and not an inferred closed electrical ring. Only a last controller may have a
recorded ending. UNKNOWN allows incomplete inventory and is never called verified.

A predecessor must be active, have recorded upstream order, share the origin and
confirmed current LOR network, and have no other downstream controller. Every
member retains the existing FLW/LOR placement gate. Reject self-links, controller
cycles, controller branching, mixed networks/origins, and dangling dependencies.
Multiple independent chains at a waypoint are allowed; repeater equipment remains
a field verification expectation, never automatically installed inventory.

Use the existing serialized revision-checked command and audit history. Topology
corrections on an existing installation retain before/after audit evidence. Changing
origin continues to retire/create installations. Rewire or disconnect downstream
controllers first before retiring/moving their predecessor. Clear a recorded chain
ending before extending it. Do not silently cascade moves, change downstream wiring,
or invent termination. Controller Inventory and Waypoint Connections edit the same
fields; power remains independent and network-only saves remain possible.

Required regression: a four-controller ordered chain and both endings; mixed network,
self/cycle/fanout, wrong origin, terminated predecessor and retirement denial;
reordering, stale edits, exact replay, rollback, shared-screen persistence, unknown
order display and authorization. Reuse the current disposable runner and migration
chain. Current review exited cleanly; new exact-head browser acceptance is pending.

### V0.4.16-controller-chains implementation checkpoint

The existing installation now records upstream kind/controller and chain ending.
Controller Inventory shows the ordered chain and edits the same fields as Waypoint
Connections. Network-only saves remain possible without an outlet/circuit. Database
commands reject controller loops, fanout, terminated predecessors, dangling children
and different origins/current LOR networks. Return-to-origin is explicitly accepted.
Rewiring is audited; origin moves retain retire/create history and dependent children
must be reconnected first. Old origin-only records remain UNKNOWN, not inferred direct.

Local FieldWiring 220 tests and isolated PostgreSQL 257 command/denial checks PASS,
including four controllers, both endings, reordering, rollback, roles, stale/replay
and prior power/FLW protections. Existing actual-browser suite now exercises shared
screen topology persistence and four-controller order; exact-head CI is pending at
preparation. Use the existing PR #319 handoff for final SHA/status, not an older
candidate. Operator supplied CLEAN EXIT and port/source-lock release before this
work. Production and source files unchanged; no new preview launched here.

## October 24 reciprocal IN / OUT correction — controlling operator requirement

V0.4.16 is not accepted: recording only a predecessor and a terminal selector does
not expose the physical controller ports. Both screens must present editable IN and
OUT. OUT includes eligible controllers, terminating resistor and the named return
waypoint. Saving A OUT → B establishes B IN ← A; editing B IN establishes the same
relationship and A's displayed OUT. Store one edge using the existing predecessor
field; do not add a second independently editable successor column or another schema.

Extend the existing audited command boundary with an atomic controller_ports command.
It changes the selected installation and, if needed, the previous/new downstream
installation under the existing revision lock. Validate the completed graph before
commit. Retain audit before/after for every affected controller and preserve retired
origin records. Detaching an edge makes the released port UNKNOWN, never invents a
new waypoint cable or deletes the remaining chain. A known OUT may coexist with an
unknown IN; this supersedes V0.4.16's requirement for a known predecessor input.
Occupied controller ports must not be silently stolen: reconcile an existing input
or output explicitly. Reject self/circular links, fanout, different current LOR
networks/origins and ineligible FLW origins. Network and power remain independent.

Required operator examples (not automatically installed or verified):
RA-00 → 1001 → 1002 → 1003 → 1004 → resistor OR return to RA-00 (unverified);
ST-01 → 1005 → 1006 → 1036 → return to ST-01 (unverified).
Show each controller's IN and OUT with names and verification status, including
both ends when the operator navigates to the neighboring controller. Use the same
port editor from Controller Inventory and Waypoint Connections. Tests must start
with an unassigned next controller and prove it is selectable from OUT, persisted
reciprocally, replaceable without invented wiring, and protected on stale/replay,
invalid graphs, existing occupied ports and rollback. No replacement preview may
be started while the current review holds port 8898/source lock; current V0.4.16
review has no subsequent clean-exit receipt yet. Production unchanged.

### V0.4.17 reciprocal ports implementation / latest field clarification

The shared editor presents IN → Controller → OUT and allows selecting an unassigned
next controller from OUT. The atomic controller_ports command maintains one stored
edge, updates both screen views, preserves released chains with unknown input,
rejects occupied ports/cycles/network mismatches and records affected rows in audit.
No second successor column or duplicate inventory was introduced. Both screens now
use this same editor rather than separate topology forms. Stage filtering is unchanged.

Greg confirms stage filtering works. Racing Arches probably ends with a resistor;
that remains UNVERIFIED. Elf Choir returns via ST-01 for continuation toward Stars;
do not label it a terminated network. These are documentation/test examples only,
not seeded installed wiring. Latest operator receipt after V0.4.16 review confirms
CLEAN EXIT and free port 8898/GIS source lock. Next launch still rechecks both.

Local FieldWiring 220 tests and isolated SQL 281 command/denial checks PASS, including
both supplied controller sequences, reciprocal saves, released input, occupied
ports, known termination with unknown input, audit, rollback, role denial and replay.
Exact-head actual browser/PostGIS/regression CI pending at preparation. Existing
PR #319 handoff will identify final passing SHA and review checklist. Production
and original GIS/FLW sources remain unchanged; no new preview launched here.

## October 24 display names in network wiring

Greg's AUX-I review shows a recorded cross-stage chain from WV-03 through eight
Who Forest controllers and into Whoville, ending at CTRL 1061 with a resistor.
He reports difficulty identifying Tree 8 (CTRL 1094) from asset IDs alone; the
screenshots are evidence of the recorded chain, not confirmation that all intended
controllers or the physical wiring are verified. The current repeat preview has
no new CLEAN EXIT receipt yet.

Display the assigned physical display name below each Controller ID in the IN /
Controller / OUT table and alongside IDs in choices and the chain description.
Use existing ref.controller_display/ref.display relationships already exposed in
snapshot load_lineage, including controllers without power connections. Never use
wiring-source template names in place of physical display names, infer tree order
from IDs or stage order, rename controller assets, or copy names into installation
records. Show all assigned display names and an explicit no-display fallback.
Reuse the same labeling helpers on both screens. This is presentation only: network
eligibility, topology, power, audit and stage filtering remain unchanged.

### V0.4.18-display-names implementation

Both screens reuse physical display names already supplied by snapshot load_lineage;
no SQL, new schema, stored name copy or new assignment source is introduced. Names
appear beneath IDs in port tables and alongside IDs in IN/OUT choices, controller
selection and the full chain. All assigned names are shown; absent assignments have
an explicit fallback. Existing wiring-source template names do not replace physical
copy names. Local FieldWiring 220 tests PASS. Browser regression covers a physical
copy with a different template name, choices, chain, both screens and multiple/no
assignment labels. Exact-head CI pending at preparation. Latest AUX-I screenshots
show a recorded cross-stage chain ending in a resistor, with physical verification
still UNVERIFIED. No clean exit for this repeat review received yet; do not overlap
reviews. Production/source files unchanged.


## October 25 controller list sort — final operator refinement

Greg accepts V0.4.18's physical display names in network wiring and supplies CLEAN
EXIT with port 8898 and GIS source lock released. Retain earlier panel/breaker/
waypoint, Racing Arches and Elf Choir acceptance; physical wiring stays UNVERIFIED.

Add a visible Sort by selector in the left Controller list: Controller ID (default)
or Display name. Sort the existing filtered inventory response locally, using its
physical display_names, with natural numeric/case-insensitive name ordering,
unnamed/unassigned controllers last and numeric Controller ID as tie-breaker.
The choice remains active during filtering/refresh in this page. Sorting must only
rerender the list, retaining selected controller and unsaved detail/connection edits.
Do not change stage filters, network chain order, assignments, schemas or API.
Reuse the existing browser regression and disposable preview mechanism.


### V0.4.19-controller-sort implementation

The existing Controller Inventory list now offers Controller ID / Display name.
The filtered response is sorted without fetching or rebuilding the detail editor;
natural name comparison, unassigned-last and ID ties are explicit. List refresh
retains the selected sort. No SQL/API/topology changes. Local FieldWiring regression:
220 passed. Existing browser workflow extended for natural/tied/unassigned ordering,
stage scope, selected controller, unsaved network/power edits and refresh retention.
Exact-head browser and required CI pending at preparation; PR #319 holds final
candidate SHA/run results and the existing disposable handoff. V0.4.18 display names
accepted by Greg with screenshot and CLEAN EXIT; V0.4.19 sort acceptance pending.


## October 25 picker sorting follows Controller list

Greg accepts V0.4.19 left-list sorting, but screenshots 053857 / 054133 show the
IN/OUT controller options remain in ID order when the list uses Display name.
CLEAN EXIT confirms port 8898/source lock available. Extend the same sort choice
and comparison rules to both port pickers, initially and immediately on sort changes.
Keep non-controller choices first, preserve selected values and unsaved edits, and
retain all eligible controllers across stages. Reorder existing options without
triggering connection-change handlers, reloads or saves. Do not sort the recorded
chain or change eligibility, topology, power, database or source files.


### V0.4.20-picker-sort implementation

A shared comparator now orders the left inventory and IN/OUT controller choices.
Options are reordered in place, preserving selected values, special choices and
dirty edits; choice builders also apply current order after origin/input changes
and editor loading. Stage scope is not applied to eligible connection options.
Local FieldWiring 220 passed; browser regression extends the existing dirty-edit
sort test to both pickers, preserving eligibility sets and selected values in both
sort modes. Exact-head CI pending at preparation; final results and candidate pin
belong to the existing PR #319 handoff. V0.4.19 left-list accepted and CLEAN EXIT
received. V0.4.20 picker review pending. Production and source files unchanged.


## October 25 Production approval and observed live baseline

Greg approved V0.4.20-picker-sort at 439ab237beaae4ac648e7590f824a774969cd84f
for Production after ALL SORTS PASS and CLEAN EXIT. This approval persists.
No repeat feature review is required for unchanged accepted application bytes.

Read-only host receipt:
- shared /opt/fieldwiring: 17c522c4f8ec06549bf7a6d9e8530c61276203f7, clean;
  FieldWiring V0.4.2-controller-uid-explorer, postgres/ok.
- /opt/msb-setup: e3c39f2781b5a97648dce1f00965110becd2edd6, clean;
  Setup V0.3.87-catalog-scene-refresh-r3, postgres/ok.
- Controller real/ONLINE, database_fenced=false, read continuity OFF,
  last_error=null; all seven governed services/containers active/running,
  including Work Management. NAS mounted; replication current_run_ok=true.
- Local/NAS PostgreSQL and Directus backups available. The controller's October 22
  snapshot is historical, not this release's frozen rollback archive.
- Remote printservice sessions are normal while ONLINE; the controller fence,
  not a manual edit pause, must exclude them during the mutation window.

Current server runbooks were retrieved: Production_Database_Change_Deployment_Runbook,
Production_Database_Maintenance_Mode, FieldWiring_Production_Runtime and
Setup_Production_Runtime. Their historical SHA labels do not override this receipt.

Full #319 is DATABASE-CHANGING. Reuse setup_maintenance_deploy.py and its existing
profile pattern, deployment lock, controller, journal and fail-closed containment.
The September Controller launcher is not this release's installer. Never run it.
The source acceptance helper explicitly targets the disposable database and must
not be redirected to Production or have that guard weakened.

Before finalizing the release profile, collect current GIS/FLW catalog, row counts,
source bindings and operator capability using 171_site_production_preflight.sql.
This read-only transaction also establishes whether bootstrap is applicable or
existing stable identities require reconciliation; no TRUNCATE/recreate shortcut.
Verify the two accepted content-addressed cache files without changing their bytes.
No new schema, runner, source parser, Directus grant store or inventory is authorized.
Do not copy a preview database or disposable operator wiring into Production.
Release profile, its fault tests, exact migration/source identities and the merged
release target remain pending. No maintenance entry, merge or Production mutation
has occurred. Scope approval is not a claim that deployment engineering is complete.


## October 25 release profile preparation

Second read-only receipt: PostGIS 3.5.2, only ref.site_network with 27 rows,
existing Manager read/manage capability true. Accepted cached GPX/FLW hashes OK.
No waypoint/power/FLW tables/functions detected. Initial installation is applicable;
existing network IDs/rows must survive unchanged.

setup_171_release.py is a profile of the existing setup_maintenance_deploy.py,
not a replacement runner. Default source/live hooks extracted without changing
historical behavior; existing profiles' helper-byte pins refreshed accordingly.
setup_171_transport.py reuses existing committed-byte packaging. One existing-pattern
PowerShell wrapper provides foreground execution and PreflightOnly. The profile
holds both established deployment/source locks, preserves frozen business and
Directus rows, and loads sources through the existing parser/import functions via
the proved local administrator socket. Disposable source gate remains unchanged.

Accepted application SHA stays 439ab237beaae4ac648e7590f824a774969cd84f; later
commits are deployment tooling/documentation only. Profile requires that approved
application be contained in main before host execution. Local fault/default-profile
regression: 58 passed. CI adds real disposable PostGIS socket/import/replay refusal
and Windows transport/parse proof. Exact-head CI pending at preparation.
Production remains ONLINE and unchanged. No claim of server release success until
a retained host receipt proves snapshot, migration, source validation/promotion
and ONLINE health. A committed/uncertain failure retains maintenance and report.


### Release adapter integration proof and final schema gate

Tooling head 22e79b7b5488ec56643627908e3ebaf307e8aea8 passed all four existing
CI workflows: Setup, Site reference/PostGIS, release tooling, Engineering Compliance.
The actual ephemeral PostgreSQL test proves container-local admin connection,
initial GPX/FLW load, archive restoration and repeat-install refusal. Earlier CI
caught socket symlink traversal, string/Path normalization and missing ExpertGPS
labels in the synthetic fixture; all corrected before host execution.
The final preflight additionally compares existing site_network column types,
nullability and generated-identity mode against the operator's catalog receipt.
Local profile/default-runner failure checks: 60 passed. Exact final-head checks
are recorded in PR #319 before merge; no application bytes change.
Broader Setup/Acceptance: 153 passed, 2 skipped, six historical #88 report-contract
failures, each reproduced on the approved application baseline. No #88 report
implementation changes are part of this release. Production deployment and
protected live-browser closeout still require the retained host receipt.

## October 25 Production receipt and panel-entry follow-up

PR319 merged as 6aa23c399cea5dad7ba6b9cef619d469fe024991. Greg returned server
PASS for accepted application 439ab237beaae4ac648e7590f824a774969cd84f,
FieldWiring V0.4.20-picker-sort / Setup V0.3.91-integrated-power. Report:
/home/msbadmin/setup-deployment-reports/PR319-GIS-20261025T062215Z.
Preflight, freeze, snapshot, three migrations, GPX/FLW intake, database validation
and return to service all passed. Snapshot details remain in the retained report;
no separate archive path/hash was pasted. Do not rerun initial installation.

Greg is now entering real Production panels/breakers and provided WV-00 Panel 10
screenshots/photo. He reports the interface usable but needs the missing final
slots and clearer colors/groupings. This is not a claim that all follow-up UI
acceptance is complete. Preserve his Production entries.

Final correction: Number of slots in Panel setup, nullable until recorded;
1–200 actual numbered positions excluding main. No amperage inference or fixed
40-position expansion. Store on ref.site_panel via the existing audited command;
reject shrink and breaker placement beyond occupied extent. MSB light-blue and
City light-orange ownership labels, distinct selection, primary Save/Add,
outlined circuit assignment controls, neutral secondary actions, stronger breaker
groups and concise disclosures retaining uncertainty/safety details.

Candidate V0.4.21-panel-entry is engineering only. The incremental migration
171_panel_slot_count.sql extends the existing panel and command boundary; initial
schema/import files remain unchanged. Existing tests cover configured slot limits,
atomic denial, role boundary, 40-slot UI entry, reload and both ownership themes.
Local Python regression: 230 passed; isolated PostgreSQL command suite and slot
range/occupied-bound checks passed. Browser execution is delegated to existing CI
because this local runtime denies Chromium's Unix socket; no browser PASS claimed
until that workflow completes. Exact candidate and CI results belong to the PR.
Preview must clone current Production, apply only the incremental migration and
its read-only validation, and use existing saved panel data. No GPX/FLW reimport.

## October 25 — V0.4.22 follow-up candidate

Greg reviewed 70c856ce and confirmed CLEAN EXIT, port 8898 and GIS source lock
available. Further changes requested; this is not acceptance for deployment.
V0.4.22-panel-navigation adds Greg's supplied 19 breaker ratings (10–200 A),
preserves additional saved values without duplicates, restores panel context on
waypoint return, aligns screen navigation and distinguishes gray settings from
teal navigation actions in both themes. Custom rating entry was superseded by
Greg's explicit supplied list. Existing count migration remains the only migration.
Browser regression covers both return routes, filter/disclosure/scroll restoration,
rating choices and action colors. Exact CI evidence and preview SHA belong to PR455.
Production and original GIS sources remain untouched; preview uses a fresh current
Production clone, not the initial source importer. The observed 142M dump has not
yet been attributed to measured relation sizes; no source evidence is removed.

## October 25 — PR455 browser accepted; Production preparation

Greg reported PR455 PASS and CLEAN EXIT for exact
0fd7fabd48dce287722112405bafb8e3aa65f637. PR455 merged as
6a421e47c80bd4e1976a67137fe1686bfa92caac. Fresh read-only host evidence:
clean shared and Setup HEAD 439ab237beaae4ac648e7590f824a774969cd84f;
FieldWiring V0.4.20-picker-sort, Setup V0.3.91-integrated-power, Procedures V0.1.0;
controller ONLINE/unfenced, all services healthy and NAS replication current;
preview port/source lock available. Migration baseline matches: count column
absent, command MD5 49ed9c2fda6accb89dd9c72966aa4b78, command EXECUTE allowed,
direct panel DML denied. Inventory observations: 17 panels/55 breakers/92 circuits/
240 waypoints. Do not freeze those counts while normal edits continue.

The initial preflight mistakenly used 127.0.0.1; health listeners bind
192.168.5.9. Corrected complete command passed. No Production mutation occurred.
Physical database size 413 MB; retained source observations 111 MB and FLW tests
79 MB support the larger dump explanation without establishing exact compressed
attribution. Keep all evidence. Pending release uses the existing maintenance
orchestrator with the panel-only profile; no initial importer or Setup promotion.
Preparation does not claim deployment. Retain final report/snapshot and ONLINE
proof, then verify the protected Production screen before closeout.

## October25 PR455 server PASS; breaker notes follow-up

Greg returned complete maintenance/freeze/snapshot/migration/validation/source
promotion/ONLINE server PASS. Report:
/home/msbadmin/setup-deployment-reports/PR455-Panels-20261025T084618Z.
The release installs accepted0fd7fabd / V0.4.22; Setup unchanged. Snapshot
metadata remains in that report directory; exact path/hash transcription pending.
Protected Production use exposed notes initialization/display defect. V0.4.23
source-only correction restores existing source_evidence when opening settings
and displays it on the board. No waypoint required for local receptacles or gate
loads. No Production data repair is inferred; already overwritten notes, if any,
require audit evidence before recovery. Candidate review pending.

## October25 PR457 review — circuit notes correction

Breaker notes save; screenshot2 shows Upper Panel GFI's on breaker2/4 while6/8
is cropped. Assignment notes rejected note-only saves. V0.4.24 introduces an
independent Circuit notes field using existing description, displays each leg's
notes on the board and labels assignment evidence separately. Note-only saves
preserve feeds, breaker notes and the sibling circuit. Source-only; Production
unchanged. Latest preview CLEAN EXIT has not yet been reported; do not launch
another preview until the existing review exits and releases8898/source lock.


## October 25 — PR457 seasonal state engineering / next disposable test

Greg requested the final engineering candidate after confirming breaker/circuit notes save and display, and reusable preview CLEAN EXIT (8898 and GIS lock available). Implemented V0.4.25-breaker-state: text-labeled green ON/red OFF/gray unknown board state, season/phase context, grouped observation confirmation, change-only checklist with completed/configuration views, print, and maintained panel-waypoint map deep link. Existing note fixes remain included.

`171_breaker_state.sql` narrowly extends the installed post-slot-count command body with atomic observation-action resolution and existing append-only event insertion. No new state tables, imports, inferred positions or task updates. A saved observation captures breaker impact and authenticated actor through existing commands. Read-only validation is `171_breaker_state_validation.sql`. The disposable runner allowlist includes this pair. Production already contains the slot-count migration: next preview applies ONLY the new breaker-state migration, never the initial GIS/FLW load or slot migration.

Local checks: full FieldWiring application 220 passed; Setup application plus GIS preview contracts 902 passed; reference allowlist 10 passed; isolated existing command acceptance and new breaker-state acceptance passed; map deep-link and existing map harness passed. Actual Chromium and real PostGIS CI are required before handing off the exact candidate; CI disposition/exact SHA will be recorded in PR457. No local browser result is claimed. Protected operator acceptance and Production deployment remain pending.

Release scope now includes an incremental database command change plus FieldWiring and Setup map scripts; later release requires the governed DATABASE-CHANGING maintenance procedure and source promotion for both application trees. Previous source-only notes-release classification is superseded. Production remains untouched during engineering. PR455 server report remains `/home/msbadmin/setup-deployment-reports/PR455-Panels-20261025T084618Z`; preserve snapshot/report evidence. Task57's October9 80% report is unchanged, and cannot establish which breakers were switched.

Final test: check unchanged targets omitted, ON/OFF and OFF/ON setup/restoration requirements, no-waypoint and two-pole breakers, ON/OFF board colors and actor/time after reload, completed view, previous-season noncompletion, map panel focus, print, and retained breaker/circuit notes. Finish with ENTER and retain CLEAN EXIT/report. Existing laptop review worktree is reused; final exact-SHA command belongs in PR457 handoff.


## October 25 — V0.4.26 field-review corrections / replacement test

V0.4.25 operator review: FE-00 eight-slot entry not discoverable, email instead of name, unwanted restoration wording and confirmation box, and no apparent PDF/exception report. Preview ended CLEAN EXIT, port8898 and source lock available. Not accepted for Production; supersedes the preceding test handoff.

V0.4.26-breaker-reports adds 8 to the existing 1–200 slot suggestions and a real editor/save test. The new unreleased breaker-state migration now inserts direct REPORTED observations without a fabricated impact-review acknowledgment; authenticated actor, impact snapshot, append-only history, revision and exact replay remain. It also extends the existing read-only snapshot to resolve Directus first/last names for event/audit display, preserving stored identity. Season ON/OFF replaces restoration in the normal UI.

A visible report section and authenticated read-only PDF download evaluate every active breaker, including equal targets. Wrong state, no observation, earlier season, other season mode, and unknown required target are distinct exceptions. Existing change-only checklist remains available. PDFs contain panel/breaker/description, required and recorded positions, names/times, totals, revision, generation time and page numbers. PDF generation uses the application runtime's standard library; no Production environment package install is required. A rendered 60-breaker/four-page fixture was visually inspected and parsed independently; no missing rows or emails. It is synthetic QA, not Production data.

Validation and exact replacement SHA are recorded in PR457. Browser regression covers direct recording without a dialog, exact retry after lost confirmation, 8-slot save/display, unchanged-target exceptions and an actual PDF download generated from fixture PostgreSQL. Same disposable mechanism: only revised 171_breaker_state.sql plus its validation on a fresh current-Production clone; never replay installed slot-count or initial GIS/FLW migrations. Production remains unchanged. User acceptance and governed database-changing release remain pending.

## October 25 — accepted release / Panelboard and Controller Install Part 2 handoff

Greg accepted V0.4.26-breaker-reports at exact application SHA `72a94be772f2e4ae8bfaed74051f667fc87201a6`, confirmed reusable preview CLEAN EXIT (8898/source lock available), and authorized Production release. PR457 merged as `c56e3a63c6ad3c0c0d21618a0ef65ec865b25c2c`. Greg will enter initial breaker states: do not backfill them from desired settings, photos, task57 or the discarded preview database.

**Historical release preparation — completed by the Production receipt at the top of this checkpoint.** Governing authority: Server Management Production_Database_Change_Deployment_Runbook.md and Production_Database_Maintenance_Mode.md. Use a pinned breaker profile of the existing Setup maintenance orchestrator and committed-byte transport. Expected last proven baselines: FieldWiring `/opt/fieldwiring` = `0fd7fabd48dce287722112405bafb8e3aa65f637` / V0.4.22-panel-navigation; Setup `/opt/msb-setup` = `439ab237beaae4ac648e7590f824a774969cd84f` / V0.3.91-integrated-power. Preflight must verify these live, not assume them. Promote both trees to the accepted application SHA (Setup map deep link is included). The application SHA is distinct from release-tooling and merged-main identities.

Apply only `Database/EngineeringTools/sql/171_breaker_state.sql`, validate with `Database/Acceptance/171_breaker_state_validation.sql`; slot-count and initial GIS migrations are already installed. Existing post-slot command MD5 must be `9f54909d2ce75cd0425cdf6338268f88`; reject replay/drift. Hold existing deployment/source locks; require ONLINE/services/backups, detached candidate regressions, then controller ON/freeze/validated snapshot, migration, exact function/privilege validation and all-business-row preservation, both source promotions, controller OFF and ONLINE/health/negative-auth proof. No automatic OFF or database restore after failure. Retain report, state.json, snapshot.json and hashes. A later thread must inspect actual receipt/controller/catalog before any retry.

### Part 2 — resume scope after release closeout

Continue #171/#230 under #122 with the existing schema/application, not a new wiring or inventory system. Read this checkpoint and owning integrated design, then reconcile live release evidence before engineering. Do not repeat accepted panel notes, slots, breaker sizes, sort, controller IN/OUT/daisy chains, or seasonal-recording decisions.

Accepted in this release: breaker and per-circuit notes without waypoints; 8–200 slot entry (database accepts 1–200); green ON/red OFF/gray unknown; one-click observations with names/time and Season ON/OFF wording; all-breaker/exception/completed PDF reports, including equal-target wrong-state exceptions; retained change-only checklist; panel GIS links. Existing Production controller/display wiring remains authoritative.

Remaining work to assess and finish in Part 2:
- Controller power/plug assignments with real installation data, coordinated with panel/circuit/waypoint inventory; distinguish not populated/not field-tested from missing implementation. Preserve reciprocal IN/OUT, cross-stage same-network chains and controller/display-name sorting.
- Panel/circuit amperage reporting and Display→Controller→Circuit lineage: existing nominal rollups are implemented but basis/incomplete loads and field usefulness need reconciliation. Do not present unknown auxiliary/controller loads or nominal headroom as verified capacity.
- Additional Combo equipment within existing REF inventory: switches, power supplies, splitters, LOR repeaters and replacement of failed components. Extend inventory verification, not automatic installed-component creation from network expectations. Future 24mm labels remain deferred unless included explicitly in Part 2 scope.
- Simplified FLW cable history: latest recorded test, direction-independent same-network endpoint pairs, passing speed/footage, known 1970 tester-date defect. FLW remains physical-cable authority; GPX is route geometry. Future incremental FLW intake must preserve previously imported tests; this intake was explicitly deferred from this release.
- Future governed GPX comparison/snapshot/ingest workflow and known map inaccuracies: preserve current PostgreSQL references and original GPX/FLW evidence, never silently replace the reviewed master. Keep QGIS/basemap calibration work under its existing GIS owner.
- Reconcile panel-versus-breaker seasonal behavior and waypoint electrical-safety presentation with actual field inventory; task57's October9 80% crew report is historical and must not be overwritten by inferred checklist progress.

Server deployment receipt and source/snapshot identities are now recorded above. Protected Production browser acceptance remains pending; documentation closeout does not imply it passed. Preserve the existing laptop review worktree for sequential Part 2 tests and return the shell to `C:\lor\ImportExport\VSCode`.

## October 25 — Part 2 performance candidate (not deployed)

Operator supplied localized Production evidence: snapshot 6.872 s / ~2013 KB;
waypoint projection 4.632 s vs 38.499 ms materialized; duplicated Controller
requirement work ~1 s; all breaker impacts only 76.7 ms. Do not repeat broad
profiling or blame hardware/network. Current main at engineering start:
`06a881b73a4fa8ea103312df46a8a62530fba760`.

V0.4.27-panel-performance changes only the snapshot query shape and panel-selection
rendering. Request-local materialized network availability/Controller requirements
feed existing JSON output; no command, source file, identity or eligibility policy
change. Panel/list selection and checklist/report-to-panel links retain unrelated
DOM. Full snapshot refresh still renders all surfaces.

Incremental migration: `Database/EngineeringTools/sql/171_power_snapshot_performance.sql`.
Read-only validation: `Database/Acceptance/171_power_snapshot_performance_validation.sql`.
Baseline snapshot body MD5 `90d9a9a08645e6611e1216f80bdc774c` is required;
optimized body MD5 `1409b5a8bada107ecfd5954c8f49a18d`. Unexpected baseline or replay
stops. Existing owner, ACL, SECURITY DEFINER, STABLE and search_path retained.
Do not apply initial GIS/FLW, slot-count or PR457 migrations again.

Local evidence: 230 FieldWiring application tests, 10 allowlist tests; actual
PostgreSQL-engine synthetic fixture matches supplied counts (17 panels, 83 breakers,
139 circuits, 240 waypoints, 1091 load-lineage rows, 182 requirements, 890 eligibility,
517 LinkIQ rows, 475 FLW rows, 400 audit rows). Full JSON content/multiplicity,
waypoint ordering, changed evidence/duplicate network keys, role denial, grants and
replay refusal tested. PGlite timing samples before 812/813/813 ms; after
314/326/311 ms. These are synthetic engine timings, not Production latency.

Existing GitHub workflows run actual Chromium and PostgreSQL16/PostGIS gates;
results and exact candidate SHA belong in the PR before operator handoff. Local
Chromium download was unavailable; do not claim local browser PASS. Reuse existing
8898 current-Production-clone preview, original laptop review worktree and saved
source paths; apply only the new migration/validation and no GIS source import.
Check port/source-lock ownership, wait for BROWSER REVIEW READY, review rapid panel
switching and controller selections alongside retained notes/slots/reports/states,
then CLEAN EXIT and return to C:\lor\ImportExport\VSCode. Read-only validation prints
current clone timing and actual counts; field edits may legitimately change counts.
Production remains unchanged; protected PR457 Production spot check still pending.
Broader Part 2 features and screen-specific API partitioning remain later work.

## October 25 — PR460 accepted / Production release authorized

Greg reports noticeable Controller assignment improvement and breaker-status saves
~2 seconds versus ~6 seconds, with both PASS. Preview ended CLEAN EXIT, exit0;
report `/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20261025T150003.txt`;
Flask log `/tmp/Setup_Disposable_Browser_Preview_Flask_20261025T150003.log`.
Live Setup after preview remained `72a94be772f2e4ae8bfaed74051f667fc87201a6`.
No isolated SQL timing line was supplied. No repeat browser acceptance is required
merely for that omission. Greg then explicitly authorized Production release.

PR460 merged as `6cc1f9377c7faa7c7547793a55966b59f2b742cf`; accepted application
SHA stays `875003c504e8a60c5851c530ec6496e4430945d9`. Exact application CI passed
Setup/FieldWiring/Chromium, PostgreSQL16/PostGIS and Engineering Compliance.
Synthetic CI SQL medians 571→207ms; panel-click JS medians 8.95→3.3ms. These are
engineering fixture timings, separate from the operator's observed ~2-second save.

Release tooling is a pinned profile of the existing maintenance orchestrator and
committed-byte transport: `setup_171_performance_release.py/.json`,
`setup_171_performance_transport.py`, `run_setup_171_performance_release.ps1`.
Preflight verifies both roots at PR457 and baseline function/security; source
promotion advances only FieldWiring. Setup remains at PR457. Single new snapshot
migration only; no old migrations, source intake or backfilled observations.
Tests cover failure containment, drift/replay refusal, exact pins, security gates,
fingerprints and unchanged Setup; existing CI covers PostgreSQL16 preservation
and Windows committed-byte transport. Release-tooling exact head/results belong
in its PR. Production receipt, snapshot and protected browser check remain pending;
this authorization/preparation is not a deployment claim.


## October 25 — isolated unassigned-breaker correction candidate

Greg found mistaken two-pole entries (FC-00 position2 example) impossible to correct despite no assignments. Separate branch `fix/171-unassigned-breaker-correction` from main8836efaa; V0.4.29-breaker-correction. PR463 equipment/cable work remains separate and untouched. Incremental `171_unassigned_breaker_correction.sql` extends the existing command and changes circuit-name uniqueness to active rows; it never deletes historical rows, imports sources, seeds state or changes the optimized snapshot. Pole reduction retires unused extra legs; removal retires the breaker/legs and automatic observation actions, keeping events and audit. Active dependencies block before mutation.

Only this new migration and `171_unassigned_breaker_correction_validation.sql` belong in its disposable current-Production review; PR457/PR460 are prerequisites, not migrations to replay. The command baseline guard intentionally rejects concurrent equipment-migration drift: reconcile migration composition explicitly if PR463 deploys first. Do not overwrite that branch or bypass the guard. Use the existing reusable preview mechanism after the other review has CLEAN EXIT and port8898/source lock are proven free; no concurrent preview launch is authorized here. Production and original GIS files remain unchanged.

Operator acceptance: correct unassigned two-pole to one; verify retained notes, free slot and reload; remove another mistaken breaker and reuse its positions; confirm a connected breaker is blocked with dependency details; confirm state-event history remains. Native/browser CI and exact candidate identity are recorded in the correction PR. Operator acceptance and release remain pending. Milbank/tandem presentation is excluded.

## October 25 — PR464 accepted / Production release authorized

Greg corrected/deleted ST-00's mistaken breaker and recreated four independent Milbank entries, accepting that scope. Exact accepted application: `2548edd130b5cebad33a44786bc1811c2b089bf8` / V0.4.29-breaker-correction. Preview CLEAN EXIT released8898/source lock and restored review/171-equipment-ea080130; shell C:\lor\ImportExport\MSB-Main. Greg then authorized Production release before further Part2 engineering. PR464 merged as `af8b6efc0c7a57975071b32fd46bd784e077f2b2`.

This thread owns the release window. Prepare a pinned correction profile of the existing Setup maintenance orchestrator and committed-byte transport. Expected prior FieldWiring875003c504e8a60c5851c530ec6496e4430945d9 / V0.4.27; Setup72a94be772f2e4ae8bfaed74051f667fc87201a6 / V0.3.91. Verify live identities, services, snapshot/command bodies and clean source before any mutation; reject drift rather than overwrite concurrent work. Apply only171_unassigned_breaker_correction.sql and its validation. Promote only FieldWiring; preserve Setup, optimized snapshot, every existing business row and original GIS source files. Existing controller freeze/validated rollback snapshot/preservation/ONLINE gates and failure containment govern. No auto repair of Greg's panel data; preview edits are discarded and Greg will repeat corrections after release. PR463 is excluded and must reconcile the changed command baseline before its own release. Production execution/receipt remains pending.
