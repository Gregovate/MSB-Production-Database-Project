# Setup #88 — Pick Mode and Movement Capture Design — 2026-09-29

| Document Control | Value |
|---|---|
| Status | ACTIVE IMPLEMENTATION DESIGN — V0.3.29 pick-clarity successor |
| Issue | #88 |
| Branch | `agent/setup-88-pick-mode-movement` |
| Baseline main | `ff6cc0b6f7c65fe736f85ce12297dbc141a69267` |
| Production Setup runtime | `6f53d7f0c4b15f7175e773a2069595eef3f0e698` / `V0.3.22-pick-list-delay` |
| Owner | Setup movement / Labeling and Scanning integration |

## October 19 Setup closeout logistics — truthful empty/return eligibility (small operational slice)

**Focused implementation issue:** [#430 — actual removable-cargo Empty, show-base stay versus return-ready, physical receipt](https://github.com/Gregovate/MSB-Production-Database-Project/issues/430). Permanent physical/synthetic role comes from [#429](https://github.com/Gregovate/MSB-Production-Database-Project/issues/429); no duplicate #230 editing here. Final installed/ready-for-wiring is independent [#431](https://github.com/Gregovate/MSB-Production-Database-Project/issues/431).

**Operator requirement:** a volunteer who scans a physical Container or selects it in Setup must be able to see **whether its removable cargo is actually accounted for**, whether its physical base remains a show Display, and whether it can **actually go back to the Workshop**. This is a focused #88 operational completion deliverable, not the whole #230 editor or #231 Testing overhaul.

For each real Container in the active annual Session, show readable name/C-number, permanent cargo expectations and *current recorded* assignments, optional verified integral LOR Display, latest valid park location/source/time/accuracy and explicit one of:
- **Cargo remains / partial unload** — name exactly which removable Displays still recorded onboard; allow actual selected Stage removals as documented, retain previously unloaded items.
- **Empty of removable cargo — return eligible** — confirmed physical Empty for a transport-only Container, no still-required cargo/task work. It is a **proposal to return**, not a RETURNED event.
- **Empty of removable cargo — show base stays** — physical Container is an integral Display/carrier now installed at its show position (Ginger Bread House, Peanuts/Thank You, U.S. Flag etc), **not** due to Workshop even if its cargo count is zero.
- **Empty status uncertain / field check required** — contradictory current association, old inferred contents state, missing scan or unresolved review; do not silently declare Empty/Returned.
- **Actually Returned to Workshop/Home** — only with actual physical return receipt/scan; show canonical Home rack separately from last park observation.

Do not infer Empty from task 100% or a null cargo list, and do not treat permanently assigned integral Display as missing removable cargo. Do not call a synthetic Testing wrapper a physical Container awaiting pickup. The existing #418 Manager Contents Review/Resolution must handle historical errors with before/after scope, evidence, actor and last-event guard, preserving valid later independent scans. The ordinary volunteer's immediate field view must be short, prominent, searchable by C-number and human Display Names, support partial unload, and distinguish operator confirmed, inferred prior, and no verification. A captain need not use raw Directus, SQL, GIS editor or Testing UI to make a physical return decision.

**Acceptance cases:** C009 one integral 909 plus twelve detachable; Traditional Christmas/Peanuts Thank You sign; U.S. Flag show base; C131 Antenna Trailer recorded empty/park with previous DBG-2026-012 missing named Command Center picker; C034 multi-stop mile loop; C052/C053 RETURNED but recorded-attached 32 already-installed wraps; C216 genuine newer Display observation; historical synthetic Standalone never becomes a Return Empty suggestion. No bulk movement or DML against live Production based on these examples.

**Boundary:** #230 governs permanent reference integral/synthetic/physical role; #88 governs current physical cargo and actual return event; #132 owns installed-Setup-task closeout and wiring readiness; #231 Testing uses confirmed physical assets and eventual returned receipts. No new invented movement ledger or automatic stage/position GPS.

## October 19 operator scope correction — repeated Containers that become Displays; Antenna Trailer independent regression

**The C009 identity defect is a repeatable MSB pattern, not a rare single-Container exception.** Greg confirms the **Traditional Christmas / Peanuts Container** transports contents and becomes the **Thank You for Visiting** sign in the show, and the **U.S. Flag Container** similarly becomes the physical U.S. Flag Display. **Both were moved into show position October 19**. The exact Container/Display IDs and current event chronology for these two cases are not yet read back and must not be guessed from labels/descriptions. A normal Setup unloading action must remove only *removable cargo*, preserve the integral physical show/display identity, and keep the base present at its confirmed park location. The actual per-Display physical role is reference authority owned by #230, not a hardcoded C009 special case or a child-count heuristic.

**Physical serialization/labels matter:** Candy Cane Rows and Tumbling Gingerbread have permanent Display records but many lacked practical label placement; Greg requests a **24mm Display QR label option** where physically possible, with Labeling/Scanning owner verifying QR/readability/media and #230 tracking true affixed/missing/unlabelable state. Some shapes (e.g. Church Bells) remain truly physically unlabelable. Do not equate a Display database ID with an affixed scan tag or fabricate scan records; task-scoped visual confirmation remains valid when authorized.

**C131 Antenna Trailer must be investigated separately:** Greg reports a bug during this multi-Display unload. Existing #122 **DBG-2026-012** specifically documents a missing Command Center location in the Setup drop picker and GPS unavailable at a separate stop despite hotspot connectivity; operator previously confirmed C131 recorded empty and remained physically in the park. Do not infer a C009-style physical integral child or a new erroneous unload from the generic report. Read existing C131 event/child state and reference-picker snapshot before any repair; preserve actual valid Stage partial unload and truthful park position. #88 owns movement and #171/#230 the named drop-location reference consumer.

**The single owning permanent classification contract is the #230 [Reference Data Manager Physical Identity/Labelability contract (DRAFT)](https://github.com/Gregovate/MSB-Production-Database-Project/blob/docs/230-integral-show-container-label-inventory-20261019/Docs/02_Production_Database/01_System_Architecture/04_Containers_and_Storage/engineering/Reference_Data_Manager_Physical_Identity_and_Labelability_Contract.md).** This #88 document consumes that reference classification to guard Setup event writing and current projections; it is not a duplicate `ref.*` editor design. Both proposed changes remain unaccepted; no Production DML or redeployment from this documentation.

## October 19 follow-up — C009 current-state readback resolves PRIOR inference and exposes mixed show-base problem

**Observed user-supplied Production SQL result** (current 2026 Setup Session per the query, no write): C009 Description **Ginger Bread House**, `container_type_name='Display Pallet'`, `home_location='Z-BLDG-A-EAST'`; 13 assigned `ref.display` IDs all `position_mode='DETACHED'` with last movement IDs **538–550**, all `TASK_UNLOAD`, all timestamp **2026-10-19 13:53:03.728 America/Chicago**. Their actual notes include `reconciliation_parent=359c7891-15bc-480a-98b5-b46e0105deec; inferred_unload=true; prior_event_id=250; contents_decision=EMPTY`. This now definitively establishes the **PRIOR** location source for these 13 inferred removals; there is no longer any need to call HERE vs PRIOR ambiguous for C009. Current C009 `display_pallet` field rendered **blank** in this readback despite Greg's separate report that he checked it in Directus; this discrepancy is still open until a direct `display_pallet IS TRUE` readback (the query may predate the edit; do not claim it saved or failed without proof).

**Specific physical identity exception:** C009 is a **mixed-use Display Pallet**: Display **909 / CL-GingerbreadHouse is the integral Ginger Bread House carried by the physical C009 base**. The other **12** permanently assigned Displays are removable items, including six Candy Cane Rows, three Tumbling Gingerbread, Welcome to Candyland, ElfOnShelf-03 and SW-WorkshopSign. Greg confirms C009's physical base **remains at the Candyland Stage** as part of the show after those additional contents are unloaded. Do not reattach all 13 or mark the Container Returned Home. Preserve the true unload evidence/history of the 12 separately removable Displays while **scoping a guarded historical state correction** to the erroneous inference for Display 909. Avoid overwriting any later independently scanned observation (check current last-event guard at correction time).

**Data model/rule defect:** Existing `Display Pallet` protection checks **one ACTIVE assigned Display**. C009 has 13 permanent assignments, so the guard permits `EMPTY` reconciliation to detach even the **integral base Display 909**. This is an invalid assumption: physical integral status cannot be derived solely from the count of assigned Displays, and a `display_pallet=true` flag on a *Container* does not itself identify which of its children is the inseparable integral Display. A mixed pallet may have zero *removable cargo* aboard while **its integral Display remains physically with it**. If 909 is corrected to `WITH_CONTAINER`, current load-state `1 WITH_CONTAINER + 12 DETACHED = PARTIAL` would still misrepresent **cargo empty**. The #88 effective load projection and guarded contents reconciler need a verified integral-versus-cargo classification from the existing #230 authoritative reference model (or minimal reviewed data addition only if no existing attribute/relationship expresses it). Do not add an unreviewed duplicate master field/table, blindly toggle type/flag, or leave the physical integral Display vulnerable to a future "Empty" scan. Owner: #230 permanent integral relationship; #88 seasonal movement/contents/effective status; #231 Testing synthetic/integral physical identity; #171 read-only map presentation.

**Trailer distance correction:** C034 is physically the **Arch Trailer** that completes roughly a **one-mile circuit** to distribute Displays at many separate Stage locations. Hundreds of feet between legitimate successive unload stops are expected field geometry, **not** a GPS/reconciliation anomaly. Preserve per-Stage `HERE` observations and their historical `PRIOR` source rules; classify discrepancies only using exact event provenance, not a simplistic distance threshold. This supersedes any earlier preliminary distance-anomaly implication for C034.

**Recovery sequence (no direct Production DML):** verify C009 integral linkage and 12 removable cargo by read-only current-master and #250/#551 receipt audit; confirm saved `display_pallet` flag explicitly; document field-confirmed C009/909 physical unity; implement minimal source-consistent #88/#230 guard so future `EMPTY` cannot detach 909 while permitting mixed-cargo unload; use existing #418 Manager authorized, audited, exact-current-state-guarded correction to repair 909 **only**, preserving original #544 and any later real scans. Distinguish cargo-empty/in-park show base from `RETURNED`. Full disposable/browser/tablet acceptance and separate Production authority apply. This document records design/factual evidence, not authorization to update Production rows.

## October 19 DBeaver Production evidence — movement event 520–654 audit

**Read-only operator-supplied DBeaver SELECT result, not a direct server session by engineering.** This is only the **first** exported query result; 250 rows represent **135 unique movement events (#520–#654)** in 2026. The export does not contain `ref.container` master details or current `ops.setup_display_state` readback, so it cannot certify C009's post-edit description/display_pallet flag, present Container physical role, or which derived location currently wins for every item. Preserve time-of-export and rerun targeted current-state SELECT when needed.

- **Event-type census:** 87 unique `TASK_UNLOAD`, 21 `CONTAINER_MOVE`, 21 individual `DISPLAY_MOVE`, four `RETURNED`, two `PICKED`. The 250 result rows include *multiple Display effect rows per one `CONTAINER_MOVE` event*, so counting rows as individual scans is incorrect. `capture_method` on derived `TASK_UNLOAD` events is NOT proof of a separately observed physical Display QR/camera scan.
- **Actual operator individual Candyland evidence:** Greg's account recorded **16 separate Candyland Tree Bench `DISPLAY_MOVE`** events (#553–#604, 13:54–13:58 Chicago), with device-reported uncertainty from ±6 to ±30 ft; one Potter's Pole Base individual Display #537 (13:51:38, ±10 ft). GG individual direct scans visible at #520, #521, #522, #525 with `rneerhof@sheboyganlights.org` captured email. These are direct observed movement events, not retrospective `installed=true` certification. Do not infer all Candyland/GG scans from this limited event-window result.
- **C009 unload:** #551 `CONTAINER_MOVE` at 13:53:03.728 Chicago, coordinate 43.776682/-87.746585, source CAMERA_SCAN, recorded under Greg. At the *exact same captured timestamp*, **13 separate `TASK_UNLOAD` events #538–550** were created for the permanently assigned C009 Displays (including `CL-GingerbreadHouse`, three `CL-TumbleGinger-*`, six `CL-CandyCaneRow-*`, `CL-WelcomeTo-CandylandCandyLand`, and two additional names `SW-WorkshopSign`, `ElfOnShelf-03`). All 13 child events share 43.776756/-87.746535 (reported ±17 ft), **about 30 ft from parent C009's (reported ±9 ft)**. This is **bulk contents inference / detachment evidence**, *not* 13 independently scanned as-built installed GPS points. Whether their source was the documented `PRIOR` versus `HERE` location needs read-only `notes`/event provenance from full current DB. Those two non-CL names in C009 demand manifest/physical review before any Stage-wide verification shortcut; do not assume they're incorrect solely from names.
- **Distances between parent/child observations can be larger:** C010 #622 at 14:01:38 is ~736 ft from concurrent same-timestamp 17 `TASK_UNLOAD` child events #605–621; C141 #628 is ~756 ft from five child unload locations #623–627; C186 #651 is ~394 ft from concurrent child events #648–650. This is **not inherently a calculation defect**: governed unloading uses prior recorded Container stop for `PRIOR` inference and a new location for `HERE`. Display and Container events sharing capture timestamp can legitimately have different coordinates. However, map must clearly identify provenance; never represent these child coordinates as independently GPS-scanned final Display position.
- **Non-monotonic capture chronology:** movement **#530 `PICKED`** has `occurred_at` 09:16:56, while lower-ID **#529 `CONTAINER_MOVE`** has 10:27:19. Highest server event ID does **not** always mean newest field capture. Use verified per-asset observation `occurred_at` plus source/current-state guards and stable idempotency; never last-ID-wins for a direct Display position. The export does not include `received_at` or `offline_captured`, so this alone does NOT prove offline replay was the cause.

**Required implementation/acceptance:** read-only current C009 `ref.container` and `ops.setup_container_state`, attached/detached last-event source per permanent `ref.display`, #538–551 raw notes/source mode, #537 Potter source, and today’s later individual Display scans. Then classify as `DIRECT_DISPLAY_OBSERVATION`, `CONTAINER_HERE_UNLOAD`, `INFERRED_PRIOR_UNLOAD`, `WITH_CONTAINER`, `UNVERIFIED`, `INDEPENDENTLY_INSTALLED_CONFIRMED` (where actual proof exists) for Manager report and #171 read-only map. Do not rewrite original event/GPS or mark group unload as task completion. No Production mutation or deployment authorized by this evidence.

## October 19 actual Candyland field failure — DISP:88, disconnected Setup API and no-label physical evidence

**Field observations (operator-supplied images, not independently live-host probed):** Tablet Chrome at approximately 2:07 PM CDT displays **`DISP:88 — Failed to fetch`**, **`ONLINE`**, **`Offline queue: 0`**, **`GPS STALE — waiting for current fix`**, signed in as Greg (Administrator). The browser shows cellular signal. No successful asset context, movement/installation acknowledgement or queued observation is visible. Screenshot SHA-256 `120daf6c64a701cb0b0753ed57c4576be1711f5ecae05a243beb936251682724`. This is **not** proof of a saved Display movement and not proof of a particular network/Cloudflare/server failure cause. Preserve tablet site cache and failed queue evidence; do not advise clearing site data.

Two physical Candyland photos document **the Gingerbread House with candy cane structures** and **three Tumbling Gingerbread panels** at the show site; Greg confirms some cannot have physically practical labels. SHA-256: `7515207b6a35a7355b909b91ffc2f1c83b9b0d61f591fbe89e301dd335f4c773` and `6a8679cebc1535d4694fb9b8b4c03b2735b753ba29e8d7fa614f1c95c4d05f9b`. Do not infer exact SQL Display IDs, GPS positions, or installed-scan receipts from these pictures. Retain them as task/Scene-scoped **visually verified / cannot label** candidates under the Crew Work Reporting design.

### Verified existing source failure and bounded correction

- Current `setup_record_location.js` status uses only `navigator.onLine`, which means network hardware/browser connectivity **not** authenticated Setup API reachability. The exact combination browser `ONLINE` and API `Failed to fetch` is therefore possible and misleading.
- `fetchState()` / `fetchContainerContents()` save per-asset localStorage only **after a successful previous API read**, then on error try cached state **only if `navigator.onLine` is false**. An API transport error while Chrome still reports online skips cached fallback and surfaces `Failed to fetch`; no Record action/IndexedDB queue is reached. This source failure matches the symptom. Authentication/server HTTP errors remain distinct, and must **not** be hidden by stale cached authority.
- The Record Location service worker caches its navigation shell and location-reference assets; it **does not prepackage all current Display/Container state or Stage membership**. A previously unseen `DISP:88` cannot be presumed field-ready offline. The existing broad catch in `selectIdentity()` can invent `OFFLINE — CURRENT CONTEXT UNAVAILABLE` as a pseudo state; this must **fail closed** for a Display/Container with no authorized cached context rather than proceed with a false movement/placement claim.
- Source-only correction scope: distinguish **browser network indicator** from observed Setup API reachability, use previously verified per-asset offline context on genuine transport failures irrespective of `navigator.onLine`, explicitly block uncached asset with **No cached context / No observation saved** and retain visible queue, preserve 401/403/4xx authorization denial, no dummy offline movement state. Existing `sendOrQueue` will continue queueing genuine network-failed **POST** only after a valid asset and location review.
- **Full offline field readiness is a separate unfinished requirement:** choose a governed authorized Setup task/Stage/context preflight while connected, bulk/versioned **read-only** cache of the specifically required canonical Display/Container identities and relevant current state, visible count/fingerprint/age with refresh and fail closed on stale/conflicting data, existing IndexedDB event queue for actual writes, and exactly-once replay proof. Do not quietly preload all `ref.display` objects or make an unrestricted public static asset dump. Real LTE/no Wi-Fi and absent LTE/tablet field tests are required. Until such a candidate passes, an unseen Display may not be scanned offline safely.
- Offline queue state is not the same as installed/on-server. A valid local queued observation is pending; only accepted idempotent server receipt makes it synced. Expired/unauthorized cached access must not silently grant movement rights while online. Existing no-GPS named location can be used only when actually confirmed, not by manufactured coordinates.

**Incident ownership:** #122 active DBG-2026-016; #88 movement scan offline correction and current state; #113 hardware/browser connectivity; #132/#175 actual task completion verification; #171 map read consumer; #230 identity/type. PR #418 is existing implementation vehicle for narrow source correction, with full disposable/browser and real tablet field acceptance still pending. Production data, runtime, Cloudflare Access and Setup schema are unchanged by this design.

## October 19 operator simplification — final-position Yes/No, GG existing scans, C009 identity and unlabelable Displays

**Operator-confirmed facts and evidence, not Production row verification:**

- For a normal scanned Display, the operator wants **one obvious question** using the actual human Display Name: **"Is [Display Name] in its final show position?" — Yes / No.** Yes is adequate to attest physical installed position at the observed GPS / confirmed named location, with operator, time, and source; don't require a series of redundant separate checks just because a Display was already `DETACHED`. No must **not** record installation or detach a protected unit. Distinguish the movement's basic location observation from final-installation attestation; don't silently reinterpret all old `DISPLAY_MOVE` rows as installed.
- Greg confirms **all GG Displays are physically in their final positions**; Rich made individual GG scans October 19 (example GG-Elden-20-02 event525). **Do not create new fake Rich scans or require every GG Display to be rescanned just to annotate intent** if valid individual event/source identity is already on file. Instead provide a Manager/authorized-crew scoped **review of actual GG Display scans**, comparing current latest event/real actor/GPS uncertainty/season/name and any newer records, then an separately attributed **final-position attestation of those particular actual events**, subject to field confirmation. Unseen/unsynced/no-event GG Displays remain unverified; a statement about the whole set is not permission to synthesize per-Display GPS.
- **Some Church Bells Displays physically cannot carry QR labels because of their geometry.** For genuine physically unlabelable pieces, a phone lookup per Display is not practical, so a future task/Scene-scoped **visual verification workflow** must show the known required human Display Names and allow compact scoped crew confirmation/exception reporting without searching each ID. This must be recorded as **visual confirmation, QR unavailable**, not as an individual QR scan, with responsible actor, dated physical scope, actual Stage and source. Do not automatically confirm pieces outside that scoped task, and don't invent a precise coordinate for each grouped piece. Keep known-but-unlabeled groups out of false 'missing label = not installed' failure states and provide a future field acceptance test using Church Bells.
- **Actual supplied Directus screenshot:** Display `909` `CL-GingerbreadHouse` has `container_id = 9`, while the Container selection text is `9 - Candy Land panels - Z-BLDG-A-EA...` (name truncated). Greg identifies the physical Gingerbread House as **CONT:9**. This is **proven DB assignment + user-reported physical identity**, not proof that Container 9 has no other assigned Displays or is a synthetic testing wrapper. Reconcile current type/flags, all active child Display Names, physical show-base role, the real Container description and labels before any master-data rename or detachment.
- The existing `setup_movement_repository.search_assets()` searches Container **ID/description** and Display **ID/name** as independent results. It does **not** search Containers by the Names of their assigned Displays, so looking for `GingerbreadHouse` may find `DISP:909` but not immediately reveal its linked `CONT:9`. **Required existing-app read-only UX:** Display-to-Container and Container-to-Display cross-lookup with both canonical IDs, readable linked Names and physical type; direct navigation to the correct existing Record Location/Manager Container view without Directus or DBeaver. This must never infer a second physical item merely from separate database IDs.

**Yes/No acceptance and safety:** Scanning a normal Display, whether currently `WITH_CONTAINER` or `DETACHED`, visibly prompts final position. A Yes can be recorded as a distinct confirmation with actual location and actor, optionally using a known assigned Stage only if the user **explicitly sees and confirms that actual Stage**. No does not mark installed; if the user is merely recording an interim location, preserve the accepted separate location-only action. For protected Standalone/single-Display-Pallet, resolve the linked Container action without false detachment and offer the same Yes/No physical-unit confirmation. If a prior independently observed location is newer, or current GPS is stale/poor, warn and require deliberate review; no blind overlay update or hard distance rejection. Treat a repeated confirmation of the **same physical Display** as verification/update history rather than two separate installed counts.

**2026 behavior:** optional final-position confirmation and scoped post-scan attestation only; do **not** add a hard Report Work task-completion gate this year. 2027 task-linked mandatory verification remains governed by [Crew Work Reporting](Setup_Crew_Work_Reporting_Contract_2026-09-08.md), including approved actual no-label exceptions. #230 owns permanent C009 description/type/manifest reconciliation; #231 owns synthetic Test Session wrappers; #88 owns current movement observations and correction; #171 map consumes only reviewed outcomes.

## October 19 follow-up — verified 2026 recovery scans and physical Container role boundaries

**Status: design clarification for review; implementation/field acceptance not yet completed.** The actual issue is not simply repeated scanning: 2026 Container-drop/unload observations have been confused with installed Display location, and Container/Display IDs have distinct physical interpretations. Recovery must **permit valid newer field evidence** without creating duplicate current-state items or silently corrupting valid later observations. #122 commands acceptance, #88 owns movement/event truth, #132/#175 owns task-specific installed-Display verification, #230 permanent relationships, #231 testing identity and #423 fast takedown. This subsection governs the #88 field intake and read-projection behavior; it does not create a second persisted ledger or change 2026 completion requirements.

### Display rescans: reasonableness review, not a new guessed-location gate

A crew may visit installed Displays now and record actual position evidence **without reopening previously completed 2026 Setup tasks**. Classify each candidate from its immutable canonical Display ID plus current season and real #88 movement/attachment history:

1. **Canonical physical identity:** resolve `DISP:` to the exact `ref.display.display_id`; resolve `CONT:` separately. A duplicate receipt/client UUID is an idempotent retry, not a second movement. A later intentional scan of the same Display is a new observation, but must **not increment a once-per-Display installation checklist count twice**. Recheck any locally queued earlier scan before submitting an additional one.
2. **Current evidence:** compare the latest *valid* independent Display observation, Container inherited location if still attached, unloaded/prior-location inference and any newer guarded Manager corrections. Preserve earlier original events and actor/time; a later Container scan may move only still-attached Displays. A later scanned Display position can supersede old inferred unloaded-at-Container GPS for that Display **when it is a valid direct field observation**, but must never roll back newer valid evidence. Offline receipt ordering, capture time and current-state guards remain authoritative; do not choose by database receive time alone.
3. **Spatial sanity, not rigid radius:** show prior point/source/time, candidate fix age, reported accuracy **in feet**, selected actual Stage and any known LOR/Setup expected Stage, then compare distance between them with both uncertainty estimates and location context. If a large apparent displacement arises from old incorrect Container-drop evidence, label it a **possible correction**, not a rejection. No arbitrary fixed 10/25/50-foot acceptance threshold, no nearest-GIS-marker auto-selection, no snapped coordinates, and no survey-accuracy claim.
4. **Review conditions:** stale/no GPS, poor device accuracy, assigned-Stage mismatch, surprising movement, wrong identity/container type, earlier offline queue, and conflicting newer observations require clear operator confirmation or Manager review. Preserve the difference between a confirmed named Stage and an actual device point. Location-only evidence must not silently become task installation-complete. Allow a truthful field correction with an explicit small reason such as **Correct earlier Container unload position** and optional note, linked to the original event when known.
5. **Fast repeated scanning:** same Display at the same place should be reported as **already recorded / verify again** rather than counted as a newly installed second Display. An intentional new check must remain possible and auditable. A GPS fix with overlapping uncertainty is only an observation-level possible repeat, **not** proof that the two physical placements are equal. Never silently discard a real user-confirmed current observation as a duplicate because it is near another point or another Display.
6. **Source integrity:** no bulk changing every Display on a Stage to the Container/Stage waypoint; no DBeaver, Production SQL, synthetic GIS geometry or automatic task-completion changes. If current exact position cannot be verified, preserve named Stage, uncertainty and **Location not independently verified**; route unresolved data to the existing #88 Manager review.

**Acceptance matrix:** prior wrong C216 detach vs newer PeaceOnEarth event226, C052/C053 installed wraps, later GG individual scans, same-device repeat, stale captured older offline event received later, two different Displays scanned within one accuracy circle, distant legitimate repair move, Stage mismatch, poor/no GPS, and protected Standalone/Display-Pallet. Confirm latest 2026 movement state before correction; current October17 snapshot through event494 is insufficient now.

### Physical Container/Display identity — do not equate IDs with separate objects

The following are **different operational classes requiring source-driven, per-Container review**. Existing `ref.display.container_id`, `ref.container.container_type_id`, `ref.container.display_pallet`, test identity and annual #88 modes are candidate evidence, **not** a guaranteed approved role classification by themselves. Read current Production cardinality and confirm which physical structures remain in the park; do not infer from labels alone.

| Physical reality | Scan/Setup identity contract | Movement and installation effect |
| --- | --- | --- |
| **Synthetic Standalone Display for testing** | One actual Display with a separate **synthetic** Container identity to support Container-based testing. Some objects carry a `CONT:` label, a `DISP:` label, both, or the operator may have only one usable label. | Scanning either verified existing identity should resolve the **same** linked physical unit and show both IDs, with one current physical location/installation confirmation. **No detachment, fake Empty unload, two location pins or separate twice-counted installation**. Existing protected Controller/Testing/Scan routes retain their meanings. If a label is missing, use authorized canonical lookup instead of inventing an ID or demanding unnecessary new tags. |
| **Singular physical Display-Pallet** | One integral Display physically remains with its supporting pallet/Container. | Treat as a combined physical show unit; preserve `WITH_CONTAINER`, move/verify the Container at its show position, no physical-contents removal. Unlike the synthetic Standalone, the pallet can be a real physical object. |
| **Normal transport-only Container / multi-Display load** | One Container carries separable Displays; not necessarily itself a show component. | Unload only actual selected Stage/Display cargo. Detached items subsequently have separate installed-position scans. Once empty, a physical Workshop return may be appropriate, but **Empty does not prove Returned**. |
| **Multi-Display Pallet/Container that BECOMES part of the show** | One physical Container carries multiple separable Displays, then the base/frame/pallet **stays at the Stage and is used in the installed show**. Both its Container identity and the carried Display identities are meaningful. | Remove/independently locate its cargo, keep the remaining physical Container anchored at its confirmed **show/base position**, and explicitly confirm its in-show disposition. It may have **zero cargo left but is NOT Returned Home**. It must stay visible on the park map and in pickup/return readiness as `in park / show structure`, not as an empty transport pallet due back at Workshop. At takedown it can again be the target carrier for scanned Displays; only confirmed contents and an actual Workshop receipt change its return status. |

**Important existing implementation limitation:** `setup_movement_repository.py` uses type name `Standalone Display` or a `Display Pallet` with *exactly one active attached Display* to block removals; `070_reconcile_setup_container_contents.sql` has matching protection. **A multi-Display Pallet is otherwise allowed to unload, but the code does not explicitly distinguish “cargo removed, base remains deployed in show” from “empty transport Container due Home.”** The existing `display_pallet` flag may help classify the physical base, but cannot be equated blindly to an accepted show-component status without verifying affected records and the governed meaning of the flag.

**Acceptable label handling:** A physical Standalone with both `CONT:` and `DISP:` labels must not create duplicate physically located objects, and one with only one label must remain operable. Preserve both permanent IDs and existing testing relationships; link them through the existing canonical `ref.display.container_id`. Do not hard-code a new `CONT:` alias to arbitrary Displays or auto-rewrite labels. In January packing, a synthetic Standalone is one object, not a Container that must be filled with another copy of itself.

**Required downstream semantics:** Distinguish `contents empty`, `physical show base still in park`, `workshop return eligible`, `actually returned`, `physically installed` and `January packed/ready-to-transfer`. These are not synonyms. The annual movement/disposition representation, whether existing attributes/events suffice, and role-gated Manager correction must be proven before proposing new schema/columns. The Show PC is not a development workstation and needs no DBeaver.

## October 19, 2026 — explicit installed-Display verification and January 2027 takedown

**Current operator direction — #88 / commanding #122, with #423 owning January takedown readiness.** This section supersedes the **October 7 proposed takedown shortcut** where it says that expected contents can be loaded without individual Display scans. The newer [#423 takedown requirements](https://github.com/Gregovate/MSB-Production-Database-Project/issues/423) require a fast **scan each actual Display** confirmation, not a group-wide assertion of physical presence. Historical sections remain evidence of the earlier design, not currently approved January loading behavior. This is a design/acceptance checkpoint, **not an installed function or permission to mutate 2026 Production rows**.

### October 19 clarification — the Setup *work-completion* gate is the owner, not a standalone location button

Greg's later operator clarification establishes that **unloading only delivers Displays to the park for Setup; the installing task must require scanning each Display as installed before declaring that task verified complete**. A generic optional "At Show Position" button in Record Location alone would still leave installation tasks reporting 100% without verification and would **not** solve the systemic issue. The [controlled Setup Crew Work Reporting contract — October 19](Setup_Crew_Work_Reporting_Contract_2026-09-08.md#october-19-2026--display-installation-is-part-of-setup-task-completion-not-container-unloading) now owns the end-to-end 2026 learning exception, 2027 required task-linked Display confirmation, partial progress and later-verification distinction. It supersedes any suggestion immediately below that fixing the Record Location button alone is sufficient.

The #88 scan/movement application supplies **real per-Display installation-position observations and guarded current location evidence** consumed by #132/#175 task completion; it must not create a second task-completion ledger. A newer valid Display scan supersedes old unload-derived GPS for that Display, but no automatic completion promotion or invented coordinates. **Do not impose required scans retrospectively on 2026**; identify unverified current installations for voluntary real-position field review and preserve all accepted 2026 work reports.

### 2026 Setup sequence and missing final-placement confirmation

The required physical workflow is:

1. **Pick** Container or independent Display at Workshop when it is taken from inventory; do not fabricate a pick if the actual field movement occurred without one.
2. **Move / Drop**: scan the Container when it stops (including intermediate staging); record that location and current physical contents, without interpreting its removal from a truck as removal of Displays from the Container.
3. **Physically unload by Stage or selected Display scope**: choose one/multiple/all Stage groups actually removed HERE. These Displays stop inheriting subsequent Container moves, but being unloaded **does not establish installation at a show position**. Keep other groups attached and handle C034/C131 mixed stops normally.
4. **Container disposition**: ordinary emptied transport/storage Containers return to their governed Workshop/Home rack only after physically received; Standalone/singular Display-Pallet Containers remain as the combined Display object, move to their actual show position, and are **never falsely emptied/detached**.
5. **Installed / at actual show position**: scan each physically placed Display at an appropriate point in Setup, including those already `DETACHED`, and confirm that it is **installed now**, actual Stage/site position and the observation source/accuracy. The last *valid* Display-specific placement or authorized correction becomes its current Display location evidence; a later Container scan cannot move that detached Display. This final-setup confirmation must be visible as a distinct annual operational fact, **not** inferred from `PICKED`, `UNLOADED`, `DETACHED`, task 100% or any generic location scan.
   
   **Current implementation gap:** `setup_record_location.js::needsDisplayPlacement()` asks "Is this Display at its setup location now?" for an **attached** ordinary Display; `DETACHED` skips that question and sees only general "Recording its current location moves only this Display." `DISPLAY_MOVE` does not universally distinguish final installation from interim re-location. Standalone directs the user to its Container without a separate explicit show-position acknowledgement. This fails the intended proof across all Display states. Extend the existing #88 event/current-state/field interface deliberately; do not invent a competing Scan application or new physical QR payload.

**Fast operator UI direction:** After scanning a Display, make **At Show Position / Location Only** meaningful explicit choices in the established Record Location workflow for eligible normal Displays, irrespective of whether already detached. For Standalone/singular-Pallet objects, offer an equivalent **At Show Position** confirmation on the actual Container scan instead of violating its protection. Require a quick final review and confirmed actual Stage or trustworthy location evidence; do not automatically choose the assigned LOR Stage or nearest GIS marker. Use reusable field context and large buttons to reduce taps. If GPS is poor/unavailable, preserve the named Stage or location evidence with honest approximate/unresolved positioning, not a fabricated per-Display coordinate. Remember GPS accuracy in feet and operator attribution. Field capture must not require a developer, a DBeaver connection, or a Show PC.

**Present recovery:** Some 2026 Displays currently show Container-drop coordinates after erroneous bulk unloads. Resolve by read-only event chronology (older unload/inference vs later individual scans), preserve genuine later observations, then record verified actual installation/current location through the existing #88 movement path or scoped, role-gated and audited Manager correction in **draft #418**. When a precise Display coordinate was never observed, do not make one up or bulk stamp a Stage anchor into every Display. The corrected park map consumes resulting #88 state under #171; it does not perform movement repairs.

### January 2027 takedown: fast Container-first return-to-home loop (#423)

**Deadline:** operational, tablet/Zebra and offline acceptance *before January 1, 2027*. Takedown of the 2026 show is the first physical preparation for 2027 Setup/testing, but must keep season identity explicit.

1. **Select/scan a Container once** using the current canonical `CONT:` identity. Persist the current Container context on the tablet, showing actual Container number/name, expected human Display Names, and expected / scanned / missing / exception counts. Do not navigate to unrelated scan destinations on each read.
2. **Rapidly scan every actual `DISP:` as loaded** using continuous Zebra/HID scans with immediate distinctive success/error signal and almost no touchscreen interaction for correct items. Each unique accepted scan confirms that actual Display was observed at the **selected correct Container**, with captured actor/time, device, current session and idempotency. A duplicate is visible but cannot increment totals twice. Container context must survive rapid successive scans, poor connectivity, tablet sleep/reload and queue replay; the scan itself must not silently rewrite permanent `ref.display.container_id`.
3. **Mismatch/exception**: wrong Container, damaged/unscannable tag, extra unknown item, missing expected Display, uncertain physical load, or interrupted session must produce a safe actionable exception with minimum taps. Warn clearly and do not count a mismatched Display as verified loaded or silently reassign it to the current Container. An authorized later reconciliation can close a verified exception without rewriting its initial evidence.
4. **Container full / Ready to Transfer** is a distinct explicit, guarded operator decision after all expected contents are scanned or the remaining differences are individually accounted for and confirmed. A count of expected items is not itself proof of loading; partial Containers remain IN PROGRESS. Ready to Transfer does **not** mean already Returned Home.
5. **Return Loaded / Home**: once transported, scan the Container upon Workshop receipt, confirm the canonical `ref.container.location_code` destination and recorded contents/exception status; only then update physical return/receipt evidence. Do not force the 2026 Setup `Return Empty` behavior. Expected Home is not proof that the Container physically arrived.
6. **January testing**: preserve condition/repair findings and hand off to #231 Container-based Test Sessions and the existing #419 Work Order system; `PACKED`/`RETURNED` never means `TESTED` or `REPAIRED`. Do not change permanent membership or annual status merely to complete tests.

**Field practicality:** crew may work in snow, cold, rain, gloves and intermittent/no park network. Large readable status, audible/haptic where supported, one-scan-per-Display happy path, rapid scan debounce without lost events, clear next-Container action, resumable/locally durable queue, deterministic replay and visible unresolved status are mandatory. A timed real rugged-tablet + Zebra session with ordinary volunteers and realistic Containers/labels is an acceptance gate. Do not build a slow per-Display confirmation page. Design a safe fallback for damaged/unreadable labels without pretending a missing scan occurred. Physical correctness outranks artificial throughput.

**Takedown status:** #423 requirements captured; implementation and governed acceptance pending. Historical `DISPLAY_REATTACH` / `REATTACHED` names in constraints are not evidence that the current movement command/API/UI supports packing. Source, migration and workflow shape require fresh schema/repository reconnaissance and existing #88/#113/#230/#231 boundaries before coding; avoid a new duplicate ledger.

**Owner & operational boundaries:** #88 maintains movement/Display-Container annual associations; #423 owns January implementation/field rehearsal under #122; #113 owns scanner provisioning; #230 owns permanent storage relationships; #171 consumes spatial observations; #231 owns testing; #419 owns Work Orders. Every saved action must retain its original event and operator history. None of these changes requires DBeaver or development tools on the Show PC.

## 2026-10-07 contents reconciliation successor — candidate

The DBG-2026-007/009/010 physical decision model adds missed-unload reconciliation
alongside the accepted “What came off here?” Stage-group unload controls. The
first reconciliation candidate incorrectly removed those controls; V0.3.44
restores current-location group unloading without mixing it with prior-location
inference. See the
[current candidate and review contract](../../../../../Setup/Acceptance/Setup_88_Contents_Reconciliation_Candidate.md).
Every selected Container now has Empty / Not Empty / Not Sure decisions;
partial reconciliation asks which Display Names remain. Inference uses prior
last-known evidence; Return Empty uses canonical Home without Workshop GPS.
No schema additions or historical repairs. Production/operator acceptance is pending.

## Purpose

Define the launch Pick Mode and shared Setup movement-capture contract without creating a second movement model, changing permanent labels, or turning the Pick List into a location-tracking screen.

#88 owns persisted movement events/current movement state. #206 owns Pick List demand/order/delay and the Pick List entry point. #113 owns scanner/tablet provisioning and HID behavior. #171 owns GIS/reference spatial interpretation.

## Accepted scanner fact

The current DS3678 V5 ADF configuration is the scanner-side normalization layer for existing Display/Container QR labels.

Existing physical labels remain full URLs:

```text
https://db.sheboyganlights.org/scan/CONT/216
https://db.sheboyganlights.org/scan/DISP/323
```

The accepted V5 ADF behavior sends compact HID values with Enter:

```text
CONT:216 + Enter
DISP:323 + Enter
```

Pick Mode therefore does not require new permanent labels or a new `PICK:` payload.

The existing Pick List row QR remains the upper-rack fallback. When the ER scanner reads that on-screen full-URL QR, the same V5 scanner rule normalizes it to the same compact canonical HID identity.

Because physical-label and on-screen-row QR scans intentionally converge to the same HID token, the application must not claim it can distinguish which one the scanner read. The truthful launch capture method is `HID_SCAN`.

## Pick Mode operator contract

Entry point:

```text
Setup -> Pick List -> Start Picking
```

Entering Pick Mode explicitly arms the action `PICKED`.

Normal sequence:

```text
Pick Mode armed
 -> operator drives to the item's Home Location
 -> preferred: scan physical asset label
 -> upper-rack fallback: visually verify row/item and scan that row's QR on the mounted tablet
 -> browser receives CONT:<id> or DISP:<id> + Enter
 -> validate against current Pick List
 -> valid active item records PICKED immediately
 -> large success feedback
 -> item disappears/suppresses from active Pick List
 -> Pick Mode remains armed for the next scan
```

A second touchscreen confirmation is not required for a normal valid pick. The explicit mode establishes the movement action and the subsequent scan is the operator confirmation.

While Pick Mode is armed:

- Manager override/edit inputs are hidden or disabled;
- HID input is captured regardless of scroll position and without a visible focused text field;
- the Pick List remains visible and scrollable;
- no scan keystrokes may land in another text input;
- a reload/new browser session returns to non-mutating browse mode unless an explicit accepted resume mechanism is later added.

## Required scan feedback

```text
ACTIVE PICK
 -> GREEN: PICKED
 -> record event
 -> remove/suppress from active queue

DELAYED
 -> RED: DELAYED — DO NOT PICK YET
 -> no event

NOT CURRENT ACTIVE PICK
 -> AMBER warning
 -> no event

ALREADY PICKED / CURRENTLY OUT
 -> clear already-moved feedback
 -> no duplicate event

INVALID / UNKNOWN IDENTITY
 -> error
 -> no state change

OFFLINE VALID PICK
 -> QUEUED OFFLINE
 -> visible queue count/state
 -> replay later with original event identity/time
```

The validation must use the complete current demand set so a delayed item still produces the correct red warning even when the operator has hidden delayed rows from the visible list.

## Movement modes after Pick

Do not infer physical meaning from scan order.

The same explicit-mode pattern should support the launch movement chain:

```text
WORKSHOP / HOME
 -> PICKED
 -> LOADED
 -> IN_TRANSIT              where used
 -> DELIVERED / UNLOADED
 -> STAGED
 -> PLACED / RELOCATED
 -> RETURNED / AT_HOME
```

The UI may later group buttons where field operation proves that safe, but the persisted event must retain the explicit action.

## Existing database foundation to evolve

Reuse:

```text
ops.setup_movement_event
ops.setup_movement_event_display
ops.setup_container_state
ops.setup_display_state
```

Do not create a parallel movement history.

Current legacy event types include:

```text
CONTAINER_MOVE
TASK_UNLOAD
DISPLAY_MOVE
DISPLAY_REATTACH
TASK_COMPLETION_RECONCILE
```

The current event constraint also requires a destination Stage or destination location note. That is incompatible with a truthful `PICKED`, `LOADED`, or `IN_TRANSIT` event and must be deliberately evolved rather than satisfied with a fabricated destination.

## Required launch event evidence

The server-side event contract must preserve, as applicable:

- durable client-generated idempotency identity;
- Setup Session identity;
- explicit movement action;
- Container or Display permanent identity;
- original captured/occurred timestamp;
- server received timestamp;
- authenticated actor;
- stable device identity;
- capture method;
- GPS latitude/longitude;
- reported GPS accuracy;
- source/Home Location snapshot where applicable;
- destination Stage/location evidence where applicable;
- whether capture originated from the offline queue.

Online and offline capture must converge on this same event contract.

## Current movement state

Movement action and physical location are separate facts.

The current-state tables need an explicit movement status/action separate from `current_stage_id` / `current_location_note`.

The Pick List must not use "any movement event exists" as a permanent synonym for "already picked".

For current demand, an asset is already out/not pickable when current state is an outbound/field state such as:

```text
PICKED
LOADED
IN_TRANSIT
DELIVERED / UNLOADED
STAGED
PLACED
RELOCATED
```

A later `RETURNED` / `AT_HOME` state allows later valid demand for the same physical item to become pickable again.

## Container versus Display movement

Container movement does not create synthetic Display GPS observations.

A Display may have an explainable effective location inherited from its Container while it remains with that Container, but only an actual Display movement/scan becomes a Display observation.

Permanent `ref.display.container_id` remains master assignment truth and is not rewritten by transient movement.

## Return-home launch boundary

Location barcode deployment is not required for normal Container return.

```text
Return mode
 -> scan CONT:<id>
 -> resolve ref.container.location_code
 -> display canonical Home Location prominently in Review and record
 -> final action names the exact location (for example: Returned CONT:36 to RA03-A-01)
 -> material handler confirms the return
```

Material handlers do not type/select permanent Home Location.

If the database Home Location is missing or wrong, that is a Manager correction exception shared with #230. Do not guess a rack and do not overwrite Home Location from movement activity.

## Offline contract

Offline is launch-critical.

The browser must maintain a durable local queue, preferably IndexedDB rather than transient in-memory state.

Each queued event is created before attempting network delivery and contains at minimum:

- client event UUID/idempotency key;
- canonical asset identity;
- explicit movement action;
- original capture timestamp;
- Setup Session context available at capture time;
- device identity;
- GPS/accuracy snapshot when available;
- queue/sync status.

Required behavior:

```text
capture while online
 -> attempt same server command

capture while offline
 -> durable queue
 -> visible QUEUED OFFLINE state

reload while offline
 -> application shell and queue survive
 -> no queued event lost

connectivity returns
 -> replay in capture order
 -> server deduplicates by client event identity
 -> original event time preserved
 -> visible sync result
```

Offline mode must not create a second event schema.

## Planned access dates do not override observed physical evidence

Planned material-access dates are planning context, not a blocker against recording reality.

If an authenticated operator deliberately scans/selects an asset in **Record Location** and provides valid location evidence, that observation must be recorded even when:

- the planned park-access date has not arrived;
- the item has no prior `PICKED` event;
- the material reached the park through an exception or unrecorded prior movement.

A real movement/location observation is durable physical evidence. Do not invent a prerequisite movement merely to satisfy the plan, and do not discard a real observation because planned sequence was bypassed.

The command still requires valid identity, operator authorization, location evidence where applicable, idempotency, and normal movement-state integrity.

## Application boundary

Pick List owns demand presentation.

Movement/Scan owns:

- explicit movement actions;
- latest movement state;
- movement history;
- GPS/location evidence;
- staging/placement/return context;
- offline event queue/sync.

Pick List consumes the resulting movement truth only to decide whether an item still needs picking.

## Implementation shape

The smallest safe implementation path is:

1. database migration evolving the existing movement event/current-state contract;
2. one governed movement-record command with idempotency;
3. Setup movement API around that command;
4. Pick Mode UI in the existing Pick List screen;
5. current Pick List suppression based on explicit current movement state;
6. durable browser offline queue and replay;
7. movement-mode screen/actions for the remainder of the launch movement chain;
8. acceptance on disposable current-Production clone;
9. exact-candidate browser review;
10. real rugged-tablet + Zebra ER field acceptance.

No Production mutation is part of implementation or disposable acceptance.

## Acceptance

Acceptance must prove:

- current full Setup regression passes;
- duplicate client event replay is idempotent;
- active Pick scan records exactly one PICKED event;
- delayed scan produces no event;
- non-demand scan produces no event;
- already-picked scan produces no duplicate;
- upper-rack on-screen Pick List QR works with the ER/V5 profile;
- HID capture works without visible input focus;
- repeated successful scans require no touchscreen interaction;
- reload exits mutating Pick Mode;
- offline pick survives reload and later syncs exactly once;
- original event time is retained through offline replay;
- GPS/accuracy is retained when supplied;
- Container event does not fabricate Display observation rows;
- permanent Home Location is unchanged by movement;
- return flow displays canonical Home Location without requiring LOC barcode;
- real field movement/location evidence is accepted regardless of planned access date, while retaining normal identity/location/idempotency safeguards;
- Production fingerprint/live runtime remain unchanged throughout disposable/browser acceptance.

Production deployment remains a separate explicit runbook-authorized step.





## 2026-09-30 V0.3.29 pick-clarity successor

The V0.3.28 browser review validated the major field-evidence changes and materially improved Pick response time. It also exposed two final clarity issues in the picker surface.

### Pick List counters are physical-material counters

Do not mix Setup task-assignment counts with picker throughput in the same summary strip.

The Pick List summary is:

- **Items to pick** — demanded physical items not delayed and not already moved/out;
- **Delayed items** — demanded physical items currently held by Pick Delay;
- **Items already moved** — demanded physical items whose current movement state is already out/moved, whether Container or standalone Display;
- **Containers picked** — demanded Containers with an actual `PICKED` event in the current Setup Session.

A Container discovered in the park by Record Location may be **already moved** without ever having a Pick event. That observation must suppress it from the Needs pick working set, but it must **not** increase **Containers picked**.

This makes Containers picked a truthful throughput measure rather than a synonym for current outbound state.

### Remove obsolete Movement / Scanning shared-app view

The old **Movement / Scanning** Setup tab is no longer an operational workflow. It only linked back to Pick List and showed diagnostic movement-state row counts.

The accepted operational entry points are now:

```text
Pick List
    = workshop pull / PICKED workflow

Record Location
    = deliberate field location/movement observation
```

Remove the obsolete shared-app tab/view and stop fetching movement-summary solely to populate it. Keep the protected movement-summary API until separate system-wide review proves no remaining consumer needs it.

### Offline gate remains separate

Offline queue / cold start / reconnect / idempotent replay remains a required physical-device acceptance gate. Picker-summary and navigation cleanup do not substitute for that test.


## 2026-09-30 V0.3.28 field-evidence successor

The V0.3.27 browser review established three additional launch facts.

### Observed movement outranks planned sequence

A real Record Location observation must not be rejected by the historical/planned October 5 material-access date. The system records physical evidence even when a prior Pick event is missing. Planning sequence and actual movement history remain separate facts.

### Return Home must name the destination

For Container return, the Review/Record surface must expose canonical `ref.container.location_code` and the confirmation action must name it. A generic **Returned to Home Location** action with no visible destination is not acceptable.

If Home Location is missing, the return action fails closed to Manager reference-data correction under #230. Movement does not invent or rewrite Home Location.

### Pick validation/performance

Disposable `SETUP_PERF` evidence measured normal online Pick scans at roughly:

```text
POST /api/setup/movements          ~1.28–1.38 s
GET  /api/setup/material-readiness ~1.32–1.44 s
combined server application work   ~2.60–2.81 s
```

The delay is caused by two serial full material-readiness builds: one solely to validate the scanned item and one synchronous list refresh after the successful write.

The accepted optimization boundary is:

1. keep authoritative server-side demand / delay / already-outbound validation;
2. validate only the scanned asset against the same current scheduling/material authorities instead of constructing the entire Pick List;
3. after a successful governed write, settle the scanned row/count immediately from the authoritative movement response;
4. refresh full material readiness in the background without making the operator wait for that rebuild;
5. preserve conservative offline validation/idempotent replay.

#222 remains the performance cross-reference and Production measurement authority. #88 owns the Pick workflow behavior and acceptance.


## 2026-09-30 browser-review successor — V0.3.27 field training UX

The V0.3.26 disposable browser review completed safely but was **not operator-accepted**. The review established that the movement/data rules were safe while several field/operator interactions still needed correction.

The successor release identity is:

```text
V0.3.27-field-training-ux
```

This section supersedes earlier UI details where they conflict.

### Training applies to both material-handler workflows

Training is deliberately read-only but uses the real authenticated Production context and real device hardware.

```text
Workshop Pick List — TRAINING
    -> real current Pick List
    -> real Zebra HID / manual identity validation
    -> delayed / not-demanded / already-moved feedback remains real
    -> WOULD PICK feedback
    -> NO movement POST
    -> NO offline movement queue
    -> NO real Pick List suppression
    -> NO change to persisted Containers-picked totals

Record Location — TRAINING
    -> real Container/Display lookup
    -> real Zebra / camera / GPS / reference data
    -> real mixed-Container review
    -> WOULD RECORD feedback
    -> NO movement POST
    -> NO offline movement queue
```

Training entry remains explicit and confirmation-gated. Active training must continuously show **TRAINING MODE — NOTHING WILL BE RECORDED** and provide an obvious Exit Training action.

### Pick List field feedback

While Pick Mode is armed, the sticky scanner panel must keep the real **Containers picked** count visible so the forklift/material handler does not lose throughput visibility while scrolling the rack list.

Training may additionally show an in-memory **Training picks** counter. It is not database state and resets with the training page/session.

### Record Location interaction order

The accepted field interaction is:

```text
1. Scan / select asset
2. Establish or confirm location evidence
3. Review asset + exact location evidence together
4. Record
```

A current GPS fix alone is valid location evidence. Selecting a nearby named reference is optional confirmation/context, not a second required identity.

The final Record action must not appear ready before valid location evidence exists. The review step must show what will be recorded, for example:

```text
CONT:036 — T-Posts - Used For Panels
Location confirmed: 01-Front Entrance-FE
GPS ±18 ft
Record CONT:036 at 01-Front Entrance-FE
```

On phone/tablet, successful identity selection should guide the operator to Location Evidence and a compact workflow status should keep the selected asset/location readiness visible near the action.

Explicit GPS Start/Stop remains required. Do not force high-accuracy GPS continuously.

### Perform Work labor KPI meaning

Keep schedule workload visibility separate from performance comparison:

- **Planned labor** = planned person-hours for the active Captain scope, independent of whether completed rows are currently hidden;
- **Actual labor** = reported person-hours for that Captain scope;
- **Completed-work variance** = actual person-hours minus planned person-hours using completed assignments only.

Future scheduled work must not distort completed-work variance. If any completed assignment in the comparison lacks a plan estimate, variance remains TBD with an explicit completed-assignment missing-estimate count.

### Acceptance consequence

V0.3.26 browser-review evidence remains historical review evidence only. V0.3.27 must restart the exact-candidate chain:

```text
full Setup/Application regression
 -> reusable current-Production disposable acceptance
 -> fresh exact-candidate disposable browser review
 -> physical rugged-tablet + Zebra / camera / GPS review
 -> Wi-Fi loss / offline replay proof
 -> formal Scan Node-runtime test
 -> separate governed Production deployment authorization
```


## Historical 2026-09-30 launch checkpoint — Oct. 2 closed-loop target

This checkpoint records the earlier closed-loop candidate and is superseded by the V0.3.28 contract above. The implementation remains under #88 / PR #255. Historical candidate identity:

```text
V0.3.23-movement-loop
```

The Oct. 2 launch target is not merely a PICKED proof. The scanner surface must support the same governed event contract through Pick, Load, Depart/In Transit, Unload, Stage, Place/Relocate, and Return Empty. GPS/accuracy evidence is persisted on the movement event and exposed on current-state reads; it does not become permanent GIS/reference identity. Return Empty must surface canonical Home Location and fail closed to a Manager correction when Home Location is missing.


## 2026-09-30 Production deployment authority split

The first V0.3.29 Production attempt correctly stopped before mutation when the feature-owned deployment runner compared the live Scan artifact against the obsolete September 3 Controller baseline. Read-only reconciliation then proved the live Scan runtime is the still-useful #219 `/scan/field-test` harness used for #171 GIS/reference evidence.

The Production deployment boundary is therefore deliberately split by runtime authority:

```text
Step 1 — Production Database / Setup authority
    -> exact accepted Setup application SHA
    -> Setup write freeze
    -> validated PostgreSQL rollback archive
    -> migration 065 only
    -> transactional movement validation
    -> /opt/msb-setup exact-target promotion
    -> Setup restart / health / live regression
    -> NO Directus/Scan file mutation

Step 2 — MSB-Server-Management Scan authority
    -> merged Production Database Scan candidate
    -> isolated Directus endpoint-extension validation
    -> verify current live #219 field-harness baseline
    -> create/hash fresh immediately-current Scan rollback
    -> replace only Scan dist/index.js
    -> Directus restart / route regression
    -> preserve /scan/field-test
    -> verify explicit Display/Container Record Location handoffs
```

The #88 Setup/PostgreSQL runner must not copy, stage, back up, restart, or otherwise administer the Directus Scan extension. Scan runtime mutation belongs to the Server Management Scan deployment/recovery runbook and its reviewed repository-owned wrappers.

The current live #219 field harness remains useful while #171 is open. A later Setup release must not silently regress or remove that route merely because its own Scan delta was based on an older source artifact.

Required order for V0.3.29 Production is Setup/PostgreSQL first, then Scan. This avoids exposing Record Location links before the target Setup route/movement API exists.

The failed preflight that exposed the stale Scan baseline made no database, Setup checkout, or Scan runtime mutation.


## 2026-09-30 Production recovery — shared audit prerequisite already fixed in source

The first bounded V0.3.29 Setup/PostgreSQL Production attempt committed migration 065, then stopped during the rollback-only #88 movement validation before the application checkout advanced.

Failure evidence:

```text
ops.setup_container_state.updated_by = NULL
during record_setup_movement_event(...) UPSERT
```

This is not a new movement-model defect. It is the already-known shared audit-attribution defect reproduced during prior #122/#88 acceptance using the existing person/user 36 case.

The accepted database-wide source repair already exists:

```text
Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql
```

The prior defect allowed an UPDATE trigger to retain an old non-null updater carried forward in `NEW` instead of stamping the currently resolved actor. The shared repair corrects that update-attribution rule and hardens usable actor-name resolution.

The earlier disposable #88 acceptance passed because the accepted order was:

```text
shared audit repair
-> database-wide audit rollback validation
-> migration 065
-> #88 movement rollback validation
```

The Production deployment incorrectly omitted the shared repair after assuming it was already live. It was not.

Current Production recovery state after the failed attempt:

- migration 065 is committed;
- rollback-only movement validation did not leave movement evidence;
- governed Setup business fingerprint remained unchanged;
- Setup runtime recovered to V0.3.22;
- Scan/Directus was not changed.

Therefore recovery is forward-only:

```text
prove 065 already installed
-> create fresh post-065 / pre-audit PostgreSQL rollback archive
-> apply the already-reviewed shared audit repair
-> database-wide audit rollback validation
-> #88 movement rollback validation
-> only if both PASS, promote exact V0.3.29 Setup application
```

Do not reapply migration 065 and do not invent a new #88-specific audit workaround.

## 2026-10-03 V0.3.36 Record Location scanner-mode correction

Physical rugged-tablet testing after the accepted Setup releases showed that the workshop Pick scanner path was reliable while the separate Record Location surface could fail to select a Zebra/HID-scanned Container or Display.

Read-only source tracing established that both applications already used the same capture-phase document HID collector and compact V5 Zebra payload + Enter contract. The relevant difference was scanner arming/focus policy:

```text
Pick Mode
    -> Start Picking explicitly arms HID capture
    -> active editable control is blurred
    -> repeated scanner input is handled by the focusless document collector

Record Location before V0.3.36
    -> HID collector was always installed
    -> collector intentionally ignored editable targets
    -> no explicit scanner-armed state established focus ownership
```

The correction is an explicit Record Location scanner mode rather than changing scanner programming, permanent QR identity, or movement semantics.

V0.3.36 candidate behavior:

- **Start Scanner** explicitly arms Record Location HID capture;
- starting scanner mode stops any active camera scan;
- camera scanning is disabled while scanner mode is armed;
- scanner activation blurs the currently active control so Android HID starts in the same focusless capture state used by Pick Mode;
- **Stop Scanner** disarms the document HID collector and re-enables camera scanning;
- scanner mode remains armed while the operator starts/stops GPS, chooses a GPS-derived nearby reference, chooses a known park reference, or adds an exception/location note;
- editable location controls may temporarily own focus while the operator enters information, but completing that interaction restores focusless scanner capture so the next Zebra scan does not require another **Start Scanner** tap;
- camera/manual/search/Scan-handoff identity paths remain available when scanner mode is not armed;
- camera, HID, manual, touch/search, and Scan-handoff identities converge on the same Record Location identity-selection logic;
- the visible identity input is updated with the resolved canonical `CONT:` / `DISP:` value regardless of capture source;
- free-text location notes remain observation evidence for later review; they do not automatically create or alter #171 GIS/reference authority or #230 permanent Home Location/reference records;
- Pick List behavior is unchanged;
- Zebra V5 ADF / Enter behavior is unchanged;
- permanent label / QR payload identity is unchanged;
- PostgreSQL movement schema and movement semantics are unchanged.

The Record Location service-worker cache generation advances from v6 to v7 and the JavaScript asset pin advances to `2026-10-03.1` so tablet acceptance cannot be satisfied by a stale pre-scanner-mode shell.

This candidate is based on current `main` after V0.3.35 schedule-usability, so the scanner correction uses the distinct release identity `V0.3.36-record-location-scanner`.

Required acceptance remains exact-candidate Setup regression, disposable/browser review, then real rugged-tablet + Zebra/camera/GPS verification before Production deployment.

## 2026-10-03 V0.3.37 browser-review correction

The first V0.3.36 disposable browser review was intentionally stopped as **CHANGES REQUIRED** after the operator proved initial focusless HID capture, then found the next-asset workflow too dependent on browser focus after entering location evidence.

Observed failure mode:

```text
Start Scanner
  -> CONT:<id> + Enter works
  -> operator enters/selects location evidence
  -> editable field temporarily owns keyboard focus
  -> scanner still says ON, but operator must understand blur/focus details
  -> successful Record leaves prior identity visible
  -> next-asset readiness is not explicit
```

This is an operator-workflow defect, not operator error and not a Zebra programming defect.

The corrected V0.3.37 contract is:

```text
Start Scanner
  -> scanner ready; no field focus required
  -> scan asset
  -> Zebra Enter terminates the asset identity only
  -> scanner pauses while that asset is pending
  -> operator chooses a known/nearby reference or enters a manual location note
  -> Record or Clear
  -> prior identity/location-entry evidence is cleared
  -> scanner explicitly returns to ready
  -> scan next asset without Use and without re-focusing the identity field
```

The Record action remains explicit. The scanner's Enter suffix never Records movement. Enter in a free-text location/GPS-quality note only finishes note editing; scanner capture remains paused until the pending asset is Record/Clear. A second scan cannot silently replace the pending asset.

The corrected candidate uses the visible release `V0.3.37-record-location-scanner`, Record Location cache generation v10, Record Location JavaScript pin `2026-10-03.3`, Record Location CSS pin `2026-10-03.1`, and shared Setup client-build asset pin `2026-10-03.2`.


### 2026-10-03 launch reference refresh

For launch, the known-location chooser continues to use a curated versioned reference file until #171 provides a proper maintenance/import workflow.

The launch-time authority is ExpertGPS / Garmin GIS data in the accepted working CRS:

`EPSG:8158 — NAD83 HARN WISCRS Sheboygan County Feet (USft)`

The 2026-10-03 Church correction supplied by the operator updates `15-Church-Bells-CH` and adds `15-Church-ParkingLot`. The source Easting/Northing values are retained in the reference JSON together with the transformed browser-facing WGS84 latitude/longitude values. This is a temporary curated launch mechanism, not a new permanent GIS store.

### Scanner-on desktop layout correction

A later V0.3.37 disposable browser review exposed a presentation defect when **Start Scanner** was enabled at desktop width. The identity entry area collapsed into a narrow strip because the scanner/camera action column was sized as `auto` and its longer Scanner ON status text consumed most of the grid width.

The corrected layout gives the identity column a real desktop minimum width, bounds the action column so its controls/status wrap internally, and stacks the two areas below 900 px. This is presentation-only; it does not change scanner state, movement semantics, or release identity.

### Pick-style compact scanner presentation

A later V0.3.37 browser review showed that simply preserving desktop widths was still not the right field design. The operator confirmed that when Scanner is armed, Record Location should follow the same compact interaction pattern already accepted for Workshop Pick.

Required presentation:

```text
Scanner OFF
    -> full normal Record Location entry
    -> manual entry / Find / camera visible

Scanner ON, waiting for asset
    -> compact Step 1 scanner strip
    -> identity input + Stop Scanner + scanner status
    -> camera and explanatory help hidden

Scanner ON, asset pending
    -> Step 1 collapses further
    -> pending asset + Stop Scanner remain visible
    -> screen priority moves to Location Evidence + Review / Record
    -> scanner remains paused until Record or Clear

Stop Scanner
    -> full normal entry surface restored
```

This is presentation-only and deliberately mirrors the accepted Pick List scanner-mode body-class pattern. It does not change the V0.3.37 scanner state machine, movement semantics, or release identity.

Record Location service-worker cache generation advances to v11 and the CSS asset pin advances to `2026-10-03.2` so browser acceptance cannot reuse the prior non-compact layout.

### Compact location-evidence presentation

Browser review also showed duplicate nearest-reference text and buttons consumed unnecessary tablet space.

For V0.3.37:
- the three nearest-reference choices are shown as vertically stacked buttons to the right of the **Where is it now?** / GPS summary at wider widths;
- the duplicate inline `Nearest: ...` text is hidden from normal operator view;
- the layout stacks naturally at narrower widths;
- **Known park reference** remains below the GPS/nearest-choice area;
- **Reference data** provenance is hidden during normal operation and remains available only in Training/device-test mode.

This is presentation-only. Reference ranking, selected-reference meaning, raw GPS evidence, and movement semantics are unchanged.

### Operator GPS diagnostics boundary

Launch Record Location should not ask unload operators to rate GPS quality.

The normal operator surface now retains the useful evidence automatically:

- browser latitude / longitude;
- device-reported accuracy;
- fix timestamp / age;
- chosen known reference when confirmed;
- manually entered location when the real location is not in the known-reference list.

The former **GPS quality / uncertainty** operator controls are removed from Record Location. Movement payloads continue to carry the existing neutral `UNASSESSED` / no-note values so the persisted contract remains compatible without implying an operator judgment that was never made.

The fallback free-text control is intentionally framed as **Location not listed? Enter another location**. It exists for a meaningful real-world drop location that is not yet in the curated known-reference set, not as a general diagnostic comment field.

Engineering GPS/device quality work remains owned by the read-only `/scan/field-test` harness under #219.

The failed V0.3.36 browser review does not carry acceptance forward. V0.3.37 must restart exact-candidate regression, reusable disposable acceptance, and browser review.


### V0.3.45 compact contents interaction — 2026-10-08

The restored group unload exposed every Display Name by default, making a large
Container span many screens. Greg rejected that interaction because checked
groups and final controls were separated by excessive paging. Stage rows now
show Stage/count, with names in a separate disclosure. A fixed summary/action
dock shows selected Stage names, unloading/staying counts and location basis.
Missed-unload contents checking occupies a separate view; view changes reset the
other operation. Remaining Display IDs are held in asset-local state so name
filtering never drops hidden checked rows. A focused modal review shows affected
Stage/counts and HERE/PRIOR basis, with names expandable. Back/Escape cancels,
preserves selection and writes nothing; an open review blocks repeated commands
and asset replacement. Movement/event payloads and migration 070 are unchanged.
Browser/tablet acceptance of this candidate is still required.


### Container drop and physical Display removal — operator meaning, 2026-10-07

Greg reports that an operator interpreted "unload Container" as removing the
loaded Container from its vehicle at park staging. Many scans therefore combined
a Container location observation with Display detachment even though Displays
stayed physically loaded. C216 Production event 48 detached only Peace on Earth
correctly; later event 122 detached seven Mt. Crumpit panels and WhoMatrix. The
panels are confirmed still loaded. This establishes a wider workflow meaning
problem; it does not prove all unload events are wrong or confirm WhoMatrix's
physical contents. See the controlled candidate handoff for evidence and the
broader SELECT-only audit.

The next interaction must separate Container drop (contents stay attached),
Displays physically removed (explicit Stage-group selection and here-location
review), and current physical contents checking (Empty / Not Empty / Not Sure;
prior evidence for missed removal). Generic "unload" or "came off" cannot supply
operator intent. Park arrival/Stage suggestion cannot select removal. Retain the
quick grouped method, compact rows, expandable names and persistent summary.
Label historical derived contents as last recorded contents rather than physical
confirmation. V0.3.45's labels and review did not resolve the reported meaning problem.
V0.3.46 implements these explicit intent views; disposable/browser acceptance
remains pending.
No new schema/event model is justified. Historical correction is separate from
preventing new mistaken commands: audit all relevant grouped-unload events,
confirm actual contents, preserve subsequent valid work and original history,
and prove a guarded corrective event/projection before Production authorization.


### Wider Production audit supplied — 2026-10-07

The operator supplied the read-only audit summary and event detail: database msb,
Session 2 / PLANNING, October 5–6 Chicago observations, 19 Container scans across
18 distinct Containers and 152 UNLOADED Display effects. All 152 still match the
current DETACHED state's last movement event at the query snapshot. The tshircel
account has 13 October 6 scans/127 effects and two October 5 scans/two effects.
Five Wrap Containers account for 80 effects within 2m15s; these are physical-review
candidates, not automatically proven mistakes. C177/C178/C199 currently have
Standalone Display type and seven effects, exposing the type-contract cases.
C216 event 48 remains the valid Peace on Earth removal; seven panels from event
122 are physically confirmed loaded and WhoMatrix remains unconfirmed. Event 122
has GPS with 13-foot accuracy despite its blank named destination. Event 99's
EC-Scaffold has no current permanent Container, so permanent assignment alone is
not a recovery membership proof. Full event table and recovery boundaries are in
the linked candidate handoff. Aggregate Display-name cells in the supplied paste
are truncated; they cannot serve as a complete Display recovery manifest.

Missed-removal reconciliation cannot restore Displays already incorrectly detached.
Historical correction needs a separately proved, guarded, auditable attachment
operation; the existing movement command does not accept DISPLAY_REATTACH despite
that enum being present. No correction command is ready and no Production repair
has been performed. Keep physical confirmation, exact membership/current-state
proof, disposable recovery validation and Production authorization separate from
preventing future mistakes in the explicit-intent operator workflow.


### V0.3.46 explicit Container intent — 2026-10-07

New scans default to Container drop: existing CONTAINER_MOVE, empty removal IDs,
no reconciliation claim, and container_drop_contents_unchanged=true in existing
notes. Physical Display removal explicitly opens compact Stage-group selection;
physical contents checking explicitly opens Empty / Not Empty / Not Sure. Switching
intents clears hidden selections and cannot change an open review. Return Empty is
shown only during contents checking and requires explicit Empty. Historical derived
counts, including zero, say physical contents are unconfirmed. No schema, API or SQL
change was necessary. Full Setup regression 753 passed, targeted movement/location
46 passed, no-Node Windows application simulation 708 passed / two skipped. Real
browser/current-Production-clone acceptance remains pending; no historical repair.


### Scan-at-stop clarification — 2026-10-07

Greg restated the already intended physical workflow: scans normally occur when
Containers stop; pick is not required. Ordinary loads need a guided Empty / Not
Empty / Not Sure check at the stop, including an all-still-here shortcut and
remaining Display Names when contents changed. Missing contents use the previous
scanned Container location before the new location is recorded. V0.3.46 instead
makes contents checking optional behind three intent views; this does not yet
satisfy the instructional workflow and final browser acceptance is paused.

Preserve the accepted trailer scan -> Location/GPS -> Stage-group physical removal
-> move -> repeat method. Independent Display placement can detach only that Display
without a Container move or prior pick. Standalone Displays never detach. Helpers
without accounts need not have recorded earlier removal; an authorized operator
can report later physical contents, without claiming to be the earlier remover.
January Container-based testing remains separately undesigned and is not a
Standalone exception. Workshop-only Empty/Home return is recommended when prior
field evidence is trustworthy; a compulsory park-departure scan remains an open
choice. Full scenario table and acceptance boundary are in the candidate handoff's
Scan-at-stop design authority section. No application change in this clarification.


Repeated interim stops can retain the entire load: Workshop -> temporary staging
-> another temporary stop -> Display staging does not imply removal at any point.
Advance Container/attached-Display location after each unchanged-load confirmation;
use the latest prior stop for inferred missing contents only if a subsequent scan
actually reports a contents change. Fewer/empty are conditional branches, not an
expected next-stop state. Add consecutive unchanged loaded stops to acceptance,
with quick confirmation and no per-Display re-entry. Road-work staging and network
repairs make low-attention, offline-capable operation a launch requirement. This
clarification changes no application source and requests no further browser test.


### Delayed Not Sure review — required completion gap, 2026-10-07

Greg asks about desk review two/three days later with nobody near the Container.
Current source writes contents_review_required=true in notes; no UI consumer or
resolution command exists. Not Sure payloads have no frozen expected contents or
pinned prior event, and Container-only event-display rows do not preserve the full
attached scope. A fresh scan/latest-stop reconciliation is not historical review.

#88 needs a Manager contents-review queue retaining the original uncertain stop,
known snapshot/prior anchor, subsequent movement evidence and unresolved scope.
Desk actions must capture documented evidence, actual observation versus recording
time and guarded audited corrections linked to the original event, preserving
later valid work. Confirmed-now facts cannot automatically resolve earlier unknown
physical history. Partial/no-evidence cases remain unresolved; derived Display
location must show uncertainty. Reporting helpers need not have accounts. No new
model/schema is justified without first proving use of existing event/notes scope.
Full proposed tool and acceptance cases are in the candidate handoff's Delayed
contents review section. This capability is unimplemented and required before the
Not Sure workflow can be considered complete; no runtime or Production change.


Greg proposes using existing Display scans to double-check location instead of
expecting a full-Display scan inventory. Offer a one-Display check with recorded
location/provenance and explicit actual-location confirmation. The candidate already
supports attached independent placement with confirmed Stage; still loaded at the
Container's location must not be interpreted as detachment. Standalone remains
attached. Fresh verification helps only the established Display scope/current
facts; it cannot prove older unknown contents or close the whole Container review.
Linking this evidence into the delayed Manager queue and detached-Display checks
remains proposed/unimplemented; no implicit movement on unrelated scan intents.


### Takedown reverse flow — proposed requirement, 2026-10-07

Greg asks about loading Containers during takedown. Explicit confirmed Display
loading must attach only the selected Display Names/groups to the actual Container
so they follow later moves; uncollected Displays remain independent in the park.
Provide partial/all-confirmed loading without requiring individual Display scans.
Loaded Home return must be distinct from Return Empty. Standalone never detaches.
DISPLAY_REATTACH/REATTACHED exist in constraints but current command/API/UI does
not implement them. Current projection uses permanent ref.display.container_id
plus annual attachment mode; alternate temporary carrier support is unproven.
Whether alternate Containers can carry Displays is an open operational question;
prove representation within current objects before any schema proposal. Preserve
permanent assignments, event history and reason/source for historical corrections.
Detailed reverse-flow requirements and acceptance are in the candidate handoff.
This is not an implemented takedown feature or a new Production change.

### Field visibility before further operator testing — 2026-10-08

Greg needs a current operational picture and a short crew briefing. The supplied
October 5–6 audit does not describe October 7. A reusable read-only report now lives
at `Setup/Acceptance/setup_88_daily_field_picture_readonly.sql`; the candidate
handoff documents its four result sets, query-time state, validation and limits.
No Production results are claimed. Live Today activity, Container picture and
Manager review/resolution tools remain required, unimplemented work. Confirmed
physical Load/Remove uses All / None / Select while ordinary stops lead with the
Empty question; takedown reattachment remains proposed. Preserve the accepted
trailer shortcut. No runtime/schema change or additional operator test requested.

### V0.3.47 field report candidate — 2026-10-07 Chicago

The visibility gap above now has an implemented source candidate, not a deployed
report. Exact application SHA `321e4cfc10f98b276d82654787455520f7255886` adds Manager
Material Status -> Production Report, printable Container/Display event trails,
full names/effects, current recorded assignments, historical review flags, all
unresolved material-authority reasons, receipt comparison after event 123 and
GPS accuracy in feet. GPS-only evidence no longer renders as No Setup observation.
The Material Status expected-demand list is labelled Expected material.

The screenshot's 15 unresolved are authority requirement rows; no movement repair
is justified by their count. Review individual reasons in Material Audit. Report
queries reuse existing events/state/assignments in a read-only repeatable-read
snapshot; planning reuses the existing resolver separately. No new schema or write.
No all-edit/daily-history reconstruction, unsynced/unrecorded physical knowledge,
historical repair or resolved-review claim. Candidate handoff owns detailed
validation and remaining gates: 761 full Setup, 62 targeted, read-only SQL execution
and synthetic browser/print/tablet checks PASS; actual Production clone/operator
acceptance and guided-stop/Not Sure correction/takedown capabilities remain pending.

### V0.3.48 nearest-reference report extension — 2026-10-08 Chicago

Greg's laptop report feedback asks for nearest Stage names from GPS. Exact source
`9719a4e65f05d022821e6d2cc9bb2f19e0482029` reuses the existing location-evidence helper
and versioned `2026-stage-reference-20261003.1` points. GPS-only report headings use
Near [reference] — GPS estimate, with feet to the point and GPS accuracy/quality
retained. C216 event 122 is nearest Whoville (61 ft), C095 event 33 Church Parking
Lot (44 ft), C049 event 112 Santa's Workshop (88 ft). Detached Displays use their
own last event; named observations and raw evidence stay unchanged. This is
presentation inference, not Stage assignment, Stage boundary containment or
physical-contents repair. Missing coordinates/references retain fallback labels.

766 full Setup and 40 targeted tests, synthetic browser/print/tablet and UI date
gate PASS. Source version V0.3.48-nearest-stage-report, footer October 8. SQL reads
and schema unchanged. Existing running previews retain their exact source until
clean exit/relaunch; current-clone/operator acceptance for V0.3.48, guided-stop
alignment, delayed Not Sure resolution and takedown remain pending. No Production
change. The candidate handoff owns exact preview instructions and evidence.

Greg clarified the provenance labels: both saved and calculated location must be
visible together. Current presentation correction source
`b47f51089c2d5066ff05c243a8d24e0493bb8953` pairs Recorded destination / Recorded GPS
with Calculated nearest Stage reference (from recorded GPS) on current cards and
history. GPS-only events say no Stage/name recorded; prior context stays separate.
V0.3.48/date retained under the presentation-only version exception. 766 full,
40 targeted and synthetic browser checks rerun PASS. Existing preview wording
persists until clean exit/relaunch. Laptop relaunch handoff is in the candidate
record; no Production change or operator acceptance implied.

The same correction names the report/button/browser title Container Movement,
per Greg's request. Production Report was misleading for this operational trail.
Route and permissions unchanged; the final exact source above includes the rename.
Browser checks proved the visible button, report heading and tab title, alongside
766 full and 40 targeted tests. Current preview retains its earlier source until
clean exit/relaunch. No report-name-specific migration or new release version.


### V0.3.49 required guided Container stops — 2026-10-08 Chicago

Exact source `fe801e18f58acc58c0d4d6798d9ab6c334648b2e` replaces optional default Drop with mandatory
Empty / Not Empty / Not Sure at every ordinary stop. Not Empty explicitly offers
All last recorded Displays still here, searchable remaining Display Names, or
unidentified contents for review. Repeated interim stops can keep the full load
without paging a list. Selected missing complements use prior observation;
compact physically removed HERE Stage-group selection remains available and
retains current observed location/GPS. Standalone/singular Display-Pallet has
no Empty/removal controls. Return Empty canonical Home needs no GPS. Independent
Display actual-setup-location confirmation remains unchanged.

Uncertain commands freeze captured Display IDs/Names and prior-observation fields
in existing reconciliation notes for later evidence; no prior notes recursion,
new schema or migration 070 change. These snapshots do not resolve review or
make historical attachments verified. Delayed Manager resolve/correct tools,
guarded erroneous-detach recovery and takedown loading remain open. No Production
mutation/deployment. Keep #88 and draft #309 open.

Validation: 766 full Setup tests; 59 targeted; no-Node simulation 720 application
passed / 3 engineering-only skipped. Actual migration and exact disposable SQL
execute on synthetic PostgreSQL/WASM; repeated unchanged stops detach zero and
retain uncertainty snapshots. Real Chromium app-route/JS checks with synthetic
repo/API command captures cover mandatory choices, quick full load, filtered
names, cancel, compact HERE groups, Not Sure, Return without GPS, protected scans,
training no writes and tablet layout; inspected screenshots and report/print
regression PASS. Diff/JS/exact source UI date gate PASS. This does not substitute
for current-Production-clone/audit/privilege/operator/tablet acceptance. Reusable
8898 exact-candidate handoff is in the acceptance record.

## 2026-10-15 launch debug intake — Container Locate operator workflow

**Owner directive:** Greg spoke with Tom and reports additional problems using Container Locate / Record Location / Container Empty. This must be managed as a **separate #122 launch debug**, implemented and tested under existing **#88**, not absorbed into #205 KPI/Manager-email PR #394. The specific problems Tom found are **not yet described**; do not speculate, assume the current candidate is installed, or change movement data or business rules until observations and current Production identity are verified.

**Next reconnaissance:** capture Tom's actual screen/scan sequence, the expected versus observed result, affected Containers, empty/partial/uncertain choices, connectivity/device and displayed app version where available. Compare installed Record Location behavior with existing #88 engineering/acceptance sources and the controlled movement/event model. Retain original events, source identities and operator audit. Derive an isolated debug correction and browser/tablet acceptance under #122; no Production changes authorized by this intake note.

## October 18 — actionable Container Exceptions and Manager review

Owner #88 under #122; implementation continues in existing PR #418, based on
main `a770e755` after reconciling the governance change. This supersedes prior
statements that a historical review flag alone is an operational review tool.

**Entry and scope.** Material Status and the Setup Manager navigation expose
Container Exceptions. Default list contains current contradictions and unresolved
contents reviews only, one compact card per Container. Filter by reason/status
and search Container number/name or Display Name. Full Container Movement remains
supporting evidence, linked directly to the selected Container. A separate desk
entry can open any Container number for a known concern such as C216; healthy
inventory is not automatically added to the exception list. Show recorded
location and calculated nearest reference separately, last activity, outstanding
Display Names, original flagged event/operator and the next action. Do not mix
material-source audit requirements, task completion, or every GPS-only stop into
this queue. No automatic physical placement from nearest-reference calculations.

**Rules preserved.** Ordinary/interim stops can retain the complete load. Explicit
HERE/group unloading for trailers remains unchanged. Setup Containers return Home
empty: remaining Displays stay at the prior reported park location, with inference
and its source event shown. C052/C053's installed Festive Trees wraps use prior
park events145/143; keep valid returns183/182 and later valid Display observations.
No Workshop GPS, repeated field scan, or exact historical unload time is required
for that inference. Food Collection interim staging alone does not prove unload.
Standalone/single-Display Pallets stay attached; repairs of erroneous detachments
restore that relationship rather than physically unloading the wrapper.

**Review actions.** An authorized Manager can record Needs field check, confirm
selected current records, correct selected Displays to an explicitly chosen Stage
or recorded prior-park anchor, and restore selected erroneous detachments to their
assigned Container. Show a review summary before saving. Require evidence/source,
observation time and reason; the recording time and signed-in reviewer are server
controlled. Helpers supplying facts need no account. Select exact Display Names;
never silently select every current assignment. Explicitly resolve selected
original review flags only when their complete captured scope has been accounted
for. Unknown/missing legacy scope requires explicit whole-case attestation; partial
work leaves the flag open. Current contradictions cannot be dismissed by a note.
Needs field check stays visible; later flags are new cases even after an earlier
review. Historical resolved flags remain available in the case timeline.

**Model inventory and minimal schema necessity.** Existing
`ops.setup_movement_event` stores immutable destination-bearing movement events;
its allowed event types and destination constraint cannot represent a review,
field-check disposition, or resolution without fabricating movement. Its notes
contain capture snapshots but no linked resolution state. No general Setup
management-event ledger exists. The existing
`ref.setup_container_extra_material_review` is a permanent per-Container free-text
extra-material note, without Session, flagged-event scope or resolution history;
`ops.setup_schedule_event` is schedule-specific. Neither can serve this lifecycle
without changing its established meaning. Therefore add one append-only
`ops.setup_container_review_event` ledger, not a competing movement/location
model. Store source flag IDs, selected Display IDs, evidence/observed time,
reviewer/receipt time, request UUID, guarded snapshot and resulting movement IDs.
No rewrite of original flags, movement history or permanent assignments. Grant
SELECT plus one Manager-only SECURITY DEFINER command; no app table DML grants.

**Concurrency and correction.** Reuse permanent parent locking and current
Container/Display state from #88. A server-generated snapshot includes current
master membership/type, Container/Display state/event IDs, movement history receipt
watermark and review watermark. Reject changed snapshots and mismatched retry UUIDs.
Execute corrections atomically using existing movement events/effects/current-state
projection; location corrections reuse `record_setup_movement_event`. An explicitly
guarded attachment correction uses existing DISPLAY_REATTACH / REATTACHED model
values, clears independent location and keeps permanent ownership. Reject attachment
to a returned Container, and reject unloading protected identities. Prior-park
inference requires a returned ordinary Container and the last eligible observation
before that return within the same trip. Copy source GPS with provenance, never
claim it was measured at correction time. Review/correction is recorded now with
separate supplied evidence time; no fabricated historical scan.

**Acceptance boundary.** GET never writes. Manager authorization and the existing
same-origin JSON command guard apply. Tests must cover old flags, absent snapshots,
partial resolution, later valid Display placement/stale submission, idempotency,
protected identities, returned-with-attached cases, prior-park inference, review
history, XSS and tablet layout. Full Setup tests, exact current-Production-clone SQL
validation and protected disposable browser/operator acceptance precede Production.
Reuse the established disposable browser runner on8898; no new host deployment
mechanism or Node dependency on Greg's workstation. No Production change is
performed or authorized by this design record.
