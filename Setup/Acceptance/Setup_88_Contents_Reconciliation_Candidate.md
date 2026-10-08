# #88 Container contents reconciliation candidate

| Document control | Value |
|---|---|
| Status | DRAFT — implementation verified locally; current-clone/browser acceptance pending |
| Owner | #88; commanding #122 / DBG-2026-007, 009, 010 |
| Reviewed | 2026-10-07 |
| Baseline main | `3ddda03221ae475ffec5399ea4955e9c1e728419` |
| Branch | `fix/88-container-contents-reconciliation` |
| Release | `V0.3.46-container-drop-intent` |
| Exact application candidate | Pending publication of V0.3.46 |
| Migration | `070_reconcile_setup_container_contents.sql` — functions only |
| Preview allocation | Setup `8898` |

## Reconnaissance and implementation boundary

Current main was refreshed before editing and again before candidate preparation.
The latest #88 and #122 debug comments were read. Existing #88 PR #266 is an
older, separate offline-training draft, not the owning implementation for these
new physical-contents decisions. Open PR #308 changes Perform Work presentation;
this candidate starts at current main and preserves its accepted installed source.
Do not merge older renderer wording over the new provenance fields, and refresh
main/reconcile deliberately if #308 lands before this candidate is accepted.

Migration 065's single command gives grouped unloads the *new* Container
observation's location. It cannot put reconciled Displays at a separate prior
observation atomically with a Workshop return. Its state projection also overwrites
named context with NULL on GPS-only observations. Its existing event types,
event-display effects, notes, GPS fields, UUIDs, state tables and privileges are
sufficient; **no new table, column, constraint or parallel event model is needed**.

Migration 070 replaces the existing command to add unload guards, parent locking,
TASK_UNLOAD support and continuity, and adds a narrow reconciliation wrapper.
The wrapper snapshots/locks current attached active Displays, validates the
reviewed anchor/contents, creates deterministic child TASK_UNLOAD events using
prior location evidence, then records the Container observation/RETURNED in the
same transaction. Failure rolls the entire operation back. Existing Home and
`ref.display.container_id` assignments are never rewritten.

## Resulting workflow

Record Location opens on **Record Container drop — keep Displays attached**.
This records only the Container location, with no removal IDs or reconciliation
claim. **Displays physically removed from this Container** opens the retained
compact Stage-group method. **Check what is physically on this Container** opens
**Empty / Not Empty / Not Sure** for missed-removal reconciliation.
Pick Mode retains its separately accepted immediate PICKED interaction.

- **Observed physical removal here:** explicitly enter the removal view and
  select existing Stage groups, **All listed Stage groups were removed**, or
  **Clear selected groups**. Group labels and Display Names remain
  visible. Selected Displays detach at the current confirmed location using the
  original grouped-unload command. Unselected Displays keep following the Container.
  No prior-location inference applies to an unload observed here.
- Stage rows show the Stage name/count; **Show Displays** expands names on demand.
  A fixed action dock keeps current selection counts, the location basis, selected
  Stage names and **Review and record** visible while the operator scrolls.
- **Check what is physically on this Container** opens the separate contents
  view. The three intent buttons switch views and clear the other operation's
  selections; returning to Container drop cannot retain hidden removal IDs.
- Partial contents has Display Name search. Checked remaining IDs are held in
  asset-local state, not visible DOM checkboxes; filtering, including zero matches,
  preserves all selections. The dock shows staying/unloading counts across filters.
- Container review uses a modal panel with current Container destination,
  HERE/PRIOR unload basis and selected Stage/count summaries. Affected Display
  Names and unchanged contents are expandable. Back / Escape cancels without a
  write and preserves the selection. A review in progress blocks repeated Record
  requests and incoming asset replacement.
- Current-unload selection and prior-location reconciliation are mutually
  exclusive. Choosing a contents answer clears the current-unload selection;
  selecting a Stage group clears the inferred-reconciliation choice. Final review
  names every affected Display and identifies the actual location basis.

- **Empty:** all active Displays still WITH_CONTAINER are reconciled as detached.
- **Not Empty:** location only until the operator chooses “I can identify what
  remains.” The list uses Display Names; all names are initially checked. Checked
  names remain WITH_CONTAINER; the unchecked complement is reconciled.
- **Not Sure / cannot identify:** location only, unchanged attachment state,
  `contents_review_required=true` in the new event notes.
- A final review names the Displays remaining and detaching, and the inferred
  prior location, before any reconciliation write. Cancelling records nothing.
- **Return Empty:** requires Empty confirmation, displays canonical Home Location,
  and records RETURNED without GPS. Already detached Displays stay independent.
- Standalone synthetic wrappers and singular Display Pallets cannot be emptied or
  unloaded. Both UI and the governed command enforce this, including legacy
  grouped and direct Display paths. Multi-Display Pallets remain valid loads.
- No prior usable field observation means **unloaded / location unresolved**.
  Workshop/Home is never invented as the Display unload location. A recorded
  RETURNED is a boundary against reusing an earlier season-trip park observation.

Inferred child events keep the confirmation timestamp, prior observation GPS/fix
metadata, parent client UUID and prior event ID in notes. Their event type/status
is the existing TASK_UNLOAD and their Display effect is UNLOADED. Perform Work
labels the inference, or unresolved unload location, rather than claiming a new
direct Display observation.

The C095 correction preserves newer raw coordinates/time and derives earlier
named context separately on read, including legacy NULL state. The installed
material resolver, support-Container, assignment-source and Manager/Pick readiness
queries all carry it.
Movement-only events retain the prior actual location observation while latest
movement status remains separate. Retained names are labelled as earlier context.
No historical events or existing Production state are repaired by this migration.
Operator GPS accuracy remains in feet; stored `gps_accuracy_m` remains meters.

### Individual Display placement confirmation

An attached Display scan asks **“Is this Display at its setup location now?”**
with **Yes / No / Not Sure**. No and Not Sure leave it attached and record nothing;
the operator can scan the Container for its location instead. Yes requires an
explicit actual Stage confirmation and final review. Assigned LOR Stages are
labelled suggestions, never automatic arrival evidence. The operator can confirm
an assigned Stage, select another actual Stage, or choose a nearest GPS Stage.
Stage names are available without GPS. GPS suggestions remain optional and must
be confirmed, following the existing Field Wiring scan location-confirmation pattern.

The existing DISPLAY_MOVE command records direct placement and detaches **only
the scanned Display**, using the confirmed Stage and optional current GPS. Notes
identify direct placement rather than an inferred Container unload. Other Displays
continue following the Container, and permanent assignments remain unchanged.
This is the Peace on Earth missed-unload recovery path; later Container movement
does not move the placed Display. Protected Standalone/singular Pallets keep their
existing prohibition. Already detached Displays retain normal location recording.
Missing Stage context blocks placement until reconnect/rescan. Warm Display
context and locally queued direct scans support the existing ordered offline queue.

## Offline contract

The existing IndexedDB movement queue and idempotency identity are retained.
Warm Container context is cached by season and Container. Pending local scans
are projected over that cached/read context for later scans of the same Container.
A dependent return carries its predecessor's client UUID; replay resolves the
committed predecessor to the server event ID and still validates attached IDs.
Older queued observations drain before new observations. Failed/conflicting
replay stays in the queue and blocks dependent reconciliation for review.
Queued direct unloads also remove Displays from cached Stage groups, preserving
the same selection rules for the next offline scan.
With no cached contents, Not Sure/location-only remains available; Empty/Return
Empty cannot guess the contents. Training still performs no writes or queueing.

## Local verification

- Full `Setup/Application` and `Setup/Acceptance`: **753 passed** (710 application + 43 tooling).
- Targeted guided reconciliation, installed location projection and movement
  contracts: **46 passed**.
- Actual migration executed using PostgreSQL/WASM against the explicitly
  synthetic local fixture: `SETUP_88_LOCAL_POSTGRES_RECONCILIATION_PASS`.
  Cases cover partial complement, named/GPS prior evidence, TASK_UNLOAD provenance,
  atomic retry, stale/mismatched contents, zero remaining under Not Empty,
  GPS-free canonical return, unchanged already detached Displays, uncertainty,
  Standalone/singular legacy/direct guards, valid multi-Display Pallet,
  predecessor-client replay, missing prior evidence, and full rollback when the
  final Container command fails. The individual placement probe executes the
  installed Stage-assignment query, confirms an actual Stage different from the
  assigned Stage, and proves only the scanned Display detaches and survives later
  Container movement, with unchanged permanent assignment and atomic retry.
- Compact-screen UI tests cover collapsed names, unchanged row/focus on group
  changes, persistent summary counts/Stage names, mode switching, filtered hidden
  remaining selections (including zero matches), modal back/cancel and duplicate
  Record while review is open.
- Executable Node UI tests cover defaults, decisions, Display Names, review/cancel,
  feet, protected objects, no-context behavior and dependent offline context.
  Attached Display tests exercise No / Not Sure, unconfirmed assigned Stage,
  explicit actual Stage without GPS, cancelled final review, one-Display payload,
  protected objects and the queued Display overlay. API tests reject No / Not Sure
  writes and Yes without an actual Stage.
- C034-style Stage-group regression tests exercise explicitly opened groups,
  multiple Display Names per group, all/none, current-location payloads, cancellation,
  exclusion of ambiguous groups, protected objects, switching to prior-location
  reconciliation, and queued group projection. Actual PostgreSQL movement checks
  prove observed group unloads retain current GPS/names after later Container moves.
- C095-style continuity is exercised through the real installed Production API
  chain, including latest PICKED with older location evidence.

These are engineering gates, **not** current-Production-clone, PostgreSQL 16
production-audit, real-browser, rugged-tablet or Zebra acceptance. This workspace
has no established private MSB SSH access. The checked-in launcher below prepares
those gates through the existing workstation/server procedure. Production is untouched.

## Publication

Greg authorized branch publication, a draft PR and issue evidence updates on
2026-10-07. Publication does not authorize merge or Production deployment.

## Exact-candidate workstation handoff

First finish any active Setup review with ENTER and retain its **CLEAN EXIT**.
Reuse 8898; never replace an unknown listener. The shared launcher enforces this.

Use the PowerShell block below from the existing primary MSB repository. It
creates a separate adjacent worktree and leaves the primary checkout in place.
Do not create a second worktree if this branch is already checked out elsewhere;
use that clean existing worktree instead. Every native failure stops the sequence.
The literal below pins the tested application commit; later evidence-only commits
do not change that application identity.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    function Invoke-Git88 {
        & git @args
        if ($LASTEXITCODE -ne 0) { throw "STOP: Git failed: $args" }
    }
    $Primary = (Invoke-Git88 rev-parse --show-toplevel).Trim()
    if (Invoke-Git88 -C $Primary status --porcelain) { throw 'STOP: preserve primary checkout changes first.' }
    Invoke-Git88 -C $Primary fetch origin
    $Review = "$Primary-88-contents-review"
    if (Test-Path $Review) { throw 'STOP: inspect the existing review worktree; do not overwrite it.' }
    Invoke-Git88 -C $Primary worktree add -b fix/88-container-contents-reconciliation $Review origin/fix/88-container-contents-reconciliation
    Set-Location $Review
    .\Setup\Acceptance\run_setup_88_contents_browser_review.ps1 -CandidateSha 'c9aac967190b262cce4d85869c3503e4e5f698c5'
}
```

The wrapper runs the full Windows Setup/Application regression, then reusable
current-Production-clone acceptance with migration 070 and
`setup_88_contents_reconciliation_disposable_validation.sql`, then launches a
fresh exact-candidate browser clone. All writes are clone-only. Normal Production
activity remains online, with explicit concurrent-write mode. Open
`http://127.0.0.1:8898/record-location/?season_year=2026` only after **BROWSER REVIEW
READY**; use normal mode inside the disposable clone to verify actual persistence.

Windows launcher correction: the first operator attempt stopped during local
pytest collection because Linux deployment-tool tests in Setup/Acceptance import
`fcntl`. Greg reports this is the second occurrence of this Windows/Linux
test-scope mistake. The launcher now runs Setup/Application on Windows; the full combined
753-test Linux engineering gate remains separately verified. No server contact
occurred before that collection stop. That launcher-only correction left the
application candidate and migration unchanged.

The next Windows attempt passed 708 tests, skipped one existing Node renderer
check, and failed when the new guided-workflow test tried to start missing Node.
The new harness now follows the existing optional-Node convention and sends UTF-8
JavaScript through stdin to avoid Windows command-line length and encoding limits.
The exact review SHA advances to include this test correction, because the server
also runs tests from the pinned candidate. Runtime application files and migration
070 are unchanged. Missing-Node checks are skips, never claimed as executed passes;
the engineering run with Node still executes both checks.
Verification after this correction: full Linux suite with Node **753 passed**;
local dependency-absence simulation without Node or fcntl **708 passed, 2 skipped**.
Actual Windows retry and current-clone/browser acceptance remain pending.

### Operator review regression — C034

Greg opened the f9748464 browser candidate and rejected the missing accepted
Stage-group unload controls when scanning Container 34. The earlier candidate had
replaced the original **What came off here?** workflow with missed-unload
reconciliation; this was a regression, not an accepted workflow change.
V0.3.44 restores that observed-unload path alongside prior-location reconciliation.
The event model, migration 070 and permanent assignments are unchanged. Previous
browser disposition does not accept the new candidate; start a fresh review.

### Compact-screen correction and preview cleanup

Greg subsequently reported that the expanded names required many screenfuls,
leaving operators unable to remember checked groups by the time they reached the
record controls. V0.3.45 replaces that layout with compact Stage rows, a persistent
selection/action dock, a separate contents view, persistent filtered selections and
a focused modal review. The existing command payloads, event model, migration 070,
current-vs-prior location rules and protected-object guards are retained.

Greg reported **SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT** before
preparation of this candidate. No full report path/identity accompanied that line;
it records cleanup, not acceptance of the compact candidate. A new exact-candidate
clone/browser review is required. The local cloud-browser layout check stalled;
no visual/tablet-browser pass is claimed from it. Executable workflow tests cover
the new interaction and the engineering gates below remain required.

Review these cases:

1. C034 or another multi-Stage Container: **What came off here?** must immediately
   initially show Container drop with no Stage selection. Record a location-only
   drop and verify all Display attachments remain unchanged. Rescan and choose
   **Displays physically removed from this Container** to expose compact Stage rows/counts. Names expand only with **Show Displays**;
   expanding must not change the checkbox. The dock must stay visible at the top
   and bottom of the list, including narrow/tablet widths. Selected Stage names
   and counts must update without collapsing an open details list. Select one group, cancel
   review once, then record at a current park reference. Selected Displays use that
   current location; other groups stay attached. Verify all/none controls and a
   later Container move. Then use **Check what is physically on this Container** to verify the separate
   contents view; switching back must leave no hidden contents selection.
2. C030 or another already-empty Container: Empty -> Return Empty to the named
   Home Location, GPS off; detached Displays must keep their park evidence.
3. C216 or another mixed Container: Not Empty -> identify remaining names;
   uncheck one known removed Display; filter its name out, search for zero
   matches, then clear search. Counts and checkboxes must retain the selection;
   review must show the complement and prior location with expandable names. After record, move Container again and verify that Display stays put.
4. Empty with Displays still attached: all reconcile at the *prior* observation,
   including a return initiated at Workshop without GPS.
5. Not Sure / cannot identify: no detach; event indicates later contents review.
6. Standalone C199 and a singular Display Pallet: no Empty/unload path; normal
   Container location recording remains available. Multi-Display Pallet unloads
   must remain usable.
7. C095-style named observation followed by GPS-only: newer GPS/time plus retained
   earlier named context; accuracy in feet.
8. No prior location: detach is marked inferred/unresolved, never Home.
9. Warm offline drop -> empty/partial -> reload -> reconnect: queue survives,
   predecessor order is retained and each command applies exactly once. Changing
   server contents before replay must leave a visible conflict for review.
10. Review cancellation and repeated rapid scan/Record input: no unintended writes.
11. Scan an attached Display such as CH-PeaceOnEarth: No / Not Sure records
    nothing. Yes without actual Stage confirmation cannot record. Confirm the
    actual Stage (assigned or nearest/manual), cancel once, then confirm and record.
    Only that Display detaches. Move its Container and verify the Display remains
    at the confirmed Stage; other Displays continue following the Container.

Record the report path, exact SHA/version, migration blob, chosen operator,
workstation/server port mapping, clone identity and browser disposition on #88.
Finish the preview with ENTER; retain **CLEAN EXIT** and the reports.

For local review worktree cleanup, only after the preview has ended and all review
changes are committed/preserved:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    # Use the actual primary and review paths printed/used above.
    if (git -C $Review status --porcelain) { throw 'STOP: review worktree has changes.' }
    if ($LASTEXITCODE -ne 0) { throw 'STOP: cannot inspect review worktree.' }
    Set-Location $Primary
    git -C $Primary worktree remove $Review
    if ($LASTEXITCODE -ne 0) { throw 'STOP: worktree cleanup failed.' }
}
```

Keep the unmerged feature branch. After accepted merge/deployment, refresh primary
main with `git pull --ff-only`, prove the accepted SHA is its ancestor, then remove
only this merged feature branch. Do not force-remove worktrees or change an
unrelated primary branch during review cleanup.

## C216 Production attachment discrepancy — event cause established; recovery pending

Greg's screenshot shows **CONT:216 — Mt Crumpit Panels & Peace on Earth** with
**0 Displays on Container**. Greg confirms the Mt. Crumpit panels remain physically
loaded and that only Peace on Earth was intended to leave the Container on
**2026-10-06**. Greg ran the read-only audit against Production and supplied the
Display-state and event-history results on **2026-10-07**. The Container/database
identity result set was not included in that first paste; the subsequent broader
audit explicitly reports database msb and the same Session 2. Repeated Display-state output in the paste is one result, not an
additional observation.

| Event | Observed America/Chicago | Capture | Display effects |
|---|---|---|---|
| 48 | 2026-10-06 08:24:21.587 | CAMERA_SCAN, online | CH-PeaceOnEarth only, UNLOADED; named 15-Church-Bells-CH |
| 122 | 2026-10-06 15:03:25.108 | HID_SCAN, online | Seven WV-MtCrumpitPanel Displays plus WV-WhoMatrix, all UNLOADED; destination note NULL |

Session **2 / PLANNING** now has all nine active permanent C216 assignments marked
DETACHED. CH-PeaceOnEarth (850) links to event 48. Mt. Crumpit panels 01–07
(6, 13, 1, 10, 12, 7, 9) and WV-WhoMatrix (213) link to event 122. Permanent
Container assignments are still 216. The contents query consequently excludes
all nine. This is established stored Production attachment state, not a missing
Stage-group rendering problem. Both events are CONTAINER_MOVE with UNLOADED
Display effects; event 122 is a later grouped unload, not the original one-panel
Peace on Earth action. Blank named location alone does not prove missing GPS;
coordinates were deliberately not included in this diagnostic.

The movement command detaches the explicitly supplied unloaded Display IDs on
Container moves. The audit establishes the affected list but does not retain the
operator's checkbox gestures, raw browser request, or installed client SHA; it
cannot distinguish a deliberate group/all selection from accidental or stale
selection. Do not blame an operator or invent a browser gesture from event scope.
The baseline client source has no final group-unload review; V0.3.45 now makes the
selected Stage/counts and HERE basis explicit before recording. That does not
repair existing attachment state.

Recovery scope: keep the valid Peace on Earth detachment at event 48. Restore only
physically confirmed loaded Displays to follow C216, using an audited corrective
attachment event/guarded projection and preserving events 48 and 122. The seven
panels are operator-confirmed loaded. **WV-WhoMatrix's physical location is not yet
confirmed**; do not automatically include it in an eight-Display repair. No
reattachment correction or Production write has been performed. Prepare and prove
the concrete guarded recovery separately before any Production approval.

[The C216 read-only audit](setup_88_c216_contents_readonly_audit.sql) captures current
assignment/status, attachment/event links and complete relevant 2026 event
scopes/names/effects. America/Chicago observation and receipt times are separate,
so delayed offline evidence remains visible. It executes only SELECT/local settings
inside READ ONLY and ends with ROLLBACK; syntax and synthetic-schema execution
passed. This workspace cannot route to the private MSB server.

## Container drop versus physical Display removal — workflow meaning correction

After the C216 audit, Greg explained the actual operator interpretation: Tom used
**unloading a Container** to mean taking the still-loaded Container off the truck
at park staging. He recorded unloads with many Container moves even though the
Displays remained on the Container. This is a wider workflow meaning problem;
C216 event 122 is one confirmed event, not necessarily the entire recovery scope.
Do not interpret the report as proof that every unload by either Tom actor was
incorrect. C216's earlier Peace on Earth event 48 remains valid.

V0.3.45 used generic **unload / came off** labels. Its selection review and
compact layout improved visibility but did not adequately remove this ambiguity.
V0.3.46 implements explicit intent before Display selection:

| Operator action | Attachment consequence |
|---|---|
| **Record Container drop — keep Displays attached** | Record the Container's new location; no Display detachment |
| **Displays physically removed from this Container** | Preserve the quick Stage-group method; only explicitly selected removed Displays detach here |
| **Check what is physically on this Container** | Empty / Not Empty / Not Sure and Display-Name remaining list; reconcile missed removal using prior evidence |

Use **removed from this Container / still on this Container**, rather than generic
**unload**, throughout the choices and confirmation. Removing the Container from
a vehicle is a Container move. Record location cannot silently select Displays
for removal. Stage assignment/park arrival is not evidence of physical removal.
Preserve the compact rows, expandable Display Names, persistent selected summary
and focused review; do not remove the accepted Stage-group capability again.
Tracked contents are **last recorded contents**, not an independently confirmed
physical count. A wrong historical empty projection must not be mistaken for an
operator's physical Empty confirmation. Current V0.3.45 is not accepted as the
final solution to this newly clarified meaning problem. V0.3.46 implements the
explicit-intent workflow; exact-candidate disposable/browser acceptance is pending.
The existing event/command model can represent Container-only moves and separate
Display removal without a new table or column.

[The broader read-only audit](setup_88_container_drop_unload_readonly_audit.sql)
reports all 2026 CONTAINER_MOVE events with UNLOADED Display effects, grouped by
recorded operator/Chicago date, then lists exact Container/Display scope and current
state. It intentionally does not assume which Tom actor Greg meant or label all
reported unloads incorrect. The review includes changed-since event state so we
avoid overwriting subsequent valid work. Read-only syntax and synthetic-schema
execution passed. Wider Production output was subsequently supplied and is
summarized below; physical confirmation remains pending except the C216 findings
already stated. Preserve legitimate unloads and history; prepare any guarded
recovery only after affected scope and current physical contents are confirmed.

## Wider Production audit — results supplied 2026-10-07

Greg supplied both result sets from the broader read-only audit. The summary
explicitly identifies **database msb, Session 2 / PLANNING**. Detail contains
**19 Container scan events across 18 distinct Containers, with 152 UNLOADED
Display effects** on October 5–6, America/Chicago. All 152 effects still match a
DETACHED Display state whose last movement event is that same scan. This is a
snapshot, not a guarantee that state stays unchanged before any future correction.
These are affected-event candidates, not 152 confirmed physical mistakes.

| Recorded operator | Chicago date | Events | Containers in this row | UNLOADED effects still current |
|---|---|---:|---:|---:|
| gliebig@sheboyganlights.org | 2026-10-05 | 2 | 2 | 6 |
| rmiller@sheboyganlights.org | 2026-10-05 | 1 | 1 | 16 |
| tshircel@sheboyganlights.org | 2026-10-05 | 2 | 2 | 2 |
| tprisland@sheboyganlights.org | 2026-10-06 | 1 | 1 | 1 |
| tshircel@sheboyganlights.org | 2026-10-06 | 13 | 13 | 127 |

C216 appears twice, so adding row-level Container counts would incorrectly yield
19 distinct Containers. The tshircel account has 15 events/15 Containers and 129
effects across both days; do not merge it with the separately recorded tprisland
account or assume all events from either account were mistakes.

| Event | Container | Description from audit | Chicago observation | Detached / still current |
|---|---|---|---|---:|
| 13 | C134 | Volunteer Trailer Power Cord Spool | 2026-10-05 10:07:57.926 | 1 / 1 |
| 14 | C192 | Volunteer Trailer Stairs | 2026-10-05 10:08:20.645 | 1 / 1 |
| 42 | C030 | Church Bells | 2026-10-05 13:57:18.911 | 16 / 16 |
| 43 | C177 | CH Steeple LH - Base (Container) | 2026-10-05 14:50:15.870 | 3 / 3 |
| 44 | C178 | CH Steeple RH - Base (Container) | 2026-10-05 14:50:53.461 | 3 / 3 |
| 48 | C216 | Mt Crumpit Panels & Peace on Earth | 2026-10-06 08:24:21.587 | 1 / 1 |
| 64 | C011 | Traditional Christmas panels including Peanuts | 2026-10-06 09:51:40.974 | 6 / 6 |
| 99 | C122 | GG-Scaffold Container | 2026-10-06 11:52:25.636 | 1 / 1 |
| 112 | C049 | Section C Wraps | 2026-10-06 13:33:44.497 | 16 / 16 |
| 113 | C051 | Section E Wraps | 2026-10-06 13:34:23.935 | 16 / 16 |
| 114 | C050 | Section D Wraps | 2026-10-06 13:35:00.272 | 16 / 16 |
| 115 | C047 | Section B Wraps | 2026-10-06 13:35:35.858 | 16 / 16 |
| 116 | C046 | Section A Wraps | 2026-10-06 13:35:59.917 | 16 / 16 |
| 117 | C065 | Santa's Workshop Kit | 2026-10-06 14:28:16.489 | 8 / 8 |
| 118 | C149 | Santa and Sleigh Panels & Scaffolding & Santa's Conveyor Scaffolding | 2026-10-06 14:28:51.163 | 5 / 5 |
| 119 | C066 | Post Office Kit | 2026-10-06 14:33:09.227 | 6 / 6 |
| 120 | C004 | Global Warming, Elf on Shelf #5, Elf Conductor panel and Post Office panel | 2026-10-06 14:44:22.999 | 12 / 12 |
| 122 | C216 | Mt Crumpit Panels & Peace on Earth | 2026-10-06 15:03:25.108 | 8 / 8 |
| 123 | C199 | Bruce the Spruce | 2026-10-06 15:18:51.525 | 1 / 1 |

Review findings and boundaries:

- Five Wrap Containers, **C049/C051/C050/C047/C046**, events 112–116,
  account for **80 effects** from 13:33:44.497 to 13:35:59.917 on October 6.
  The rapid sequence is consistent with Greg's reported Container-drop meaning;
  timing alone does not prove which Displays stayed loaded. Confirm physical
  contents rather than reversing the whole batch from timestamps or actor alone.
- **C177/C178/C199** currently have type Standalone Display and seven effects
  across events 43/44/123. This exposes the type-contract cases that the new
  unload guards address; existing stored detachments are not fixed by a new guard.
  Current type evidence does not establish historical type changes or justify
  erasing events. Multi-Display Display Pallets are not automatically invalid.
- **C216 event 48 remains the known valid Peace on Earth removal**. Event 122's
  seven Mt. Crumpit panels are confirmed physically loaded; WhoMatrix still needs
  explicit physical confirmation. Preserve the valid one-Display operation.
- Event 99 removed **EC-Scaffold** from C122 while its current permanent Container
  is NULL. Recovery cannot use permanent assignment as the only membership test.
  Establish prior operational attachment/event evidence before any reattachment.
- Event 122 now explicitly reports GPS present, accuracy **13 feet**, despite a
  blank named location. Blank destination notes are not proof of missing location.
  All events except 48 report GPS; event 48 has a named location instead. All 19
  report online capture. No coordinates are exposed by this audit.
- The pasted aggregate Display-name cells are truncated near 255 characters.
  Event/Container/count evidence is usable, but this paste is not a complete
  Display-ID/Name recovery manifest. Obtain full per-Display rows or an untruncated
  export only when the physically confirmed correction scope is established.
- The current missed-removal reconciliation works on attached Displays. It cannot
  reattach Displays that were already detached incorrectly. Historical recovery
  therefore needs a separately proved, guarded, auditable attachment correction
  using the existing movement/event model. The current command does not accept
  DISPLAY_REATTACH simply because that enum exists. No repair command is ready,
  and no Production correction has been executed or authorized.

V0.3.46 now implements explicit Container-drop versus physical-removal intent
while retaining compact Stage-group removal. Next: accept the disposable/browser
workflow, confirm physical contents
of audit candidates, prepare exact Display IDs and current-state preconditions,
prove recovery on a disposable clone, then obtain separate Production approval
under the current Server Management runbook. Original history and subsequent valid
work must survive. Do not infer physical emptiness from the broken stored projection.

## V0.3.46 explicit Container intent — 2026-10-07

New scans open on the Container-drop view. Its existing CONTAINER_MOVE payload
has an empty unloaded_display_ids list, no reconciliation object, and the existing
notes field records container_drop_contents_unchanged=true. This changes no API,
SQL function or schema. Protected/no-context Containers can still record location
only; physical-removal selection is unavailable without valid selectable groups.
The review explicitly says no Display attachment changes. Physical removal retains
compact Stage rows, expandable names, all-groups/clear, selected summary and modal
review. Its HERE basis and contents checking's PRIOR basis remain separate.
Switching intents clears both removal and contents selections; changes are blocked
while recording/reviewing. Return Empty appears only in the contents view and
requires explicit Empty. Last recorded counts, including zero, say that physical
contents are unconfirmed. A mistaken historical detach still requires recovery.

Validation on V0.3.46 source: 753 full Setup tests; 46 targeted movement/location
checks; executable UI payload/cancellation/transition checks PASS; no-Node Windows
application simulation 708 passed / two explicit engineering checks skipped; JS
syntax and diff checks PASS. SQL migration 070 is unchanged from the previously
executed PostgreSQL/WASM fixture. No new visual/browser or Production-clone pass
is claimed. Exact candidate and browser acceptance are recorded separately below.

## Remaining gates

Current-clone acceptance, exact-candidate browser/operator disposition and real
offline rugged-tablet/Zebra acceptance remain pending. Then merge to main,
refresh/prove ancestry, and perform the separately authorized migration-bearing
Production deployment under Server Management's maintenance/rollback runbook.
Do not run a source-only installer across migration 070. #88 and the debug entries
stay open until their applicable acceptance/deployment/repository gates are proven.
