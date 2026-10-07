# #88 Container contents reconciliation candidate

| Document control | Value |
|---|---|
| Status | DRAFT — implementation verified locally; current-clone/browser acceptance pending |
| Owner | #88; commanding #122 / DBG-2026-007, 009, 010 |
| Reviewed | 2026-10-07 |
| Baseline main | `3ddda03221ae475ffec5399ea4955e9c1e728419` |
| Branch | `fix/88-container-contents-reconciliation` |
| Release | `V0.3.43-container-reconciliation` |
| Exact application candidate | `e8bd3d5258a57f4c2d6c7fb0f277e792fd7466d7` |
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

Record Location asks each selected Container **Empty / Not Empty / Not Sure**.
Pick Mode retains its separately accepted immediate PICKED interaction.

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
- Executable Node UI tests cover defaults, decisions, Display Names, review/cancel,
  feet, protected objects, no-context behavior and dependent offline context.
  Attached Display tests exercise No / Not Sure, unconfirmed assigned Stage,
  explicit actual Stage without GPS, cancelled final review, one-Display payload,
  protected objects and the queued Display overlay. API tests reject No / Not Sure
  writes and Yes without an actual Stage.
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
    .\Setup\Acceptance\run_setup_88_contents_browser_review.ps1 -CandidateSha 'e8bd3d5258a57f4c2d6c7fb0f277e792fd7466d7'
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

Review these cases:

1. C030 or another already-empty Container: Empty -> Return Empty to the named
   Home Location, GPS off; detached Displays must keep their park evidence.
2. C216 or another mixed Container: Not Empty -> identify remaining names;
   uncheck one known removed Display; review must name the complement and prior
   location. After record, move Container again and verify that Display stays put.
3. Empty with Displays still attached: all reconcile at the *prior* observation,
   including a return initiated at Workshop without GPS.
4. Not Sure / cannot identify: no detach; event indicates later contents review.
5. Standalone C199 and a singular Display Pallet: no Empty/unload path; normal
   Container location recording remains available. Multi-Display Pallet unloads
   must remain usable.
6. C095-style named observation followed by GPS-only: newer GPS/time plus retained
   earlier named context; accuracy in feet.
7. No prior location: detach is marked inferred/unresolved, never Home.
8. Warm offline drop -> empty/partial -> reload -> reconnect: queue survives,
   predecessor order is retained and each command applies exactly once. Changing
   server contents before replay must leave a visible conflict for review.
9. Review cancellation and repeated rapid scan/Record input: no unintended writes.
10. Scan an attached Display such as CH-PeaceOnEarth: No / Not Sure records
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

## Remaining gates

Current-clone acceptance, exact-candidate browser/operator disposition and real
offline rugged-tablet/Zebra acceptance remain pending. Then merge to main,
refresh/prove ancestry, and perform the separately authorized migration-bearing
Production deployment under Server Management's maintenance/rollback runbook.
Do not run a source-only installer across migration 070. #88 and the debug entries
stay open until their applicable acceptance/deployment/repository gates are proven.
