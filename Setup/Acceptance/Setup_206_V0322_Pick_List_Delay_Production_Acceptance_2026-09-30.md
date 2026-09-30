# Setup #206 V0.3.22 Pick List Delay Production Acceptance — 2026-09-30

| Field | Accepted value |
|---|---|
| Owning issue | #206 |
| Release | `V0.3.22-pick-list-delay` |
| Visible client badge | `Client V0.3.22` |
| Exact accepted/deployed application SHA | `6f53d7f0c4b15f7175e773a2069595eef3f0e698` |
| Release-identity PR | #257 |
| Deployment-tooling PRs | #258, #259 |
| Approved migration | `Setup/Database/063_add_setup_pick_list_delay.sql` |
| Migration blob | `45d1f71e226ab9e358e40f331945135cbe19cfb8` |
| Deployment result | PASS |
| Deployment report | `/home/msbadmin/setup-deployment-reports/Setup_206_V0322_Pick_List_Delay_Production_Deploy_20260930T091257.txt` |
| Rollback archive | `/home/msbadmin/backups/setup-206/msb-pre-setup-206-v0322-pick-list-delay-20260930T091257.dump` |
| Rollback SHA256 | `1415868b93bca4b0ad073b65d741087f34851d134dd8ce18346cce45061154af` |

## Accepted scope

This release completes the bounded #206 launch slice for current Pick List demand and transient Manager Pick Delay.

Accepted behavior includes:

- direct scheduled material demand remains authoritative;
- downstream look-ahead stops at the first incomplete material-bearing task on each dependency branch;
- COMPLETE material-bearing tasks may be crossed when finding the next incomplete frontier;
- DEFERRED branches stop;
- deadline-first Pick List ordering remains intact;
- Manager **Delay Pick** applies only to anticipated downstream Container demand;
- delayed items remain visible with **DELAYED — DO NOT PICK YET**;
- delayed picks may be hidden/shown with the accepted filter;
- **Resume Pick** removes the transient delay;
- direct scheduled or Manager-override demand cannot be delayed;
- scheduling one of the downstream tasks that created the anticipated demand automatically removes the Pick Delay;
- Pick Delay is annual/transient logistics state only and does not become reusable Catalog knowledge.

Persisted physical PICKED/movement execution is not part of this release. That write contract belongs to issue #88; #206 owns demand, ordering, Pick Delay, and the Pick List entry surface.

## Release identity correction

The previously browser-accepted #206 candidate still carried the inherited #205 identity `V0.3.21-scheduling-gates`.

Before Production deployment, server/client release identity was advanced together to:

```text
V0.3.22-pick-list-delay
Client V0.3.22
```

The repository-wide release identity rule was then added under:

`System_Documentation/Project_Rules/Release_Identity_and_Versioning_Rule.md`

The exact V0.3.22 candidate was re-run through the required bounded acceptance gates.

## Pre-Production acceptance

Exact V0.3.22 candidate:

`6f53d7f0c4b15f7175e773a2069595eef3f0e698`

Full Setup/Application regression:

```text
PASS
```

Reusable current-Production disposable acceptance:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
Production Setup fingerprint before: c7bfe0bdf54c07011d44e4a8e36457ec
Production Setup fingerprint after:  c7bfe0bdf54c07011d44e4a8e36457ec
Live Setup SHA before: 9a614c1fa2eea0b425b03bdb4ac3e1790634c760
Live Setup SHA after:  9a614c1fa2eea0b425b03bdb4ac3e1790634c760
Exit status: 0
```

Retained disposable report:

`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260930T084003.txt`

Disposable browser smoke confirmed:

- visible `Client V0.3.22`;
- `/api/health` = `V0.3.22-pick-list-delay`;
- Pick List loaded;
- Peanuts Container Pick Delay became visible;
- after Peanuts was unblocked/scheduled, the delay automatically cleared;
- clean preview teardown;
- Production fingerprint and live Setup checkout unchanged.

Retained preview report:

`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260930T084138.txt`

## Production deployment

Production deployment was explicitly approved after pre-Production acceptance and was governed by:

`Gregovate/MSB-Server-Management/docs/server/Production_Database_Change_Deployment_Runbook.md`

Only this migration was authorized:

`Setup/Database/063_add_setup_pick_list_delay.sql`

The separate historical Extra Material files also carrying 063/064 numbering were explicitly excluded from this deployment.

### First deployment attempt — fail-closed harness stop

The first Production attempt reached post-deployment source verification, then stopped with exit code 25 because the deployment harness incorrectly required the literal `Show delayed picks` in `setup_pick_list.js`.

That literal is owned by `pick_list.html`; the JS owns the delayed warning and Pick Delay API path.

Fail-closed recovery was verified from the retained report:

- Setup checkout restored to `9a614c1fa2eea0b425b03bdb4ac3e1790634c760`;
- Setup service stopped before migration rollback;
- Pick Delay migration rollback PASS;
- governed Setup fingerprint unchanged;
- rollback archive retained.

PR #259 corrected only that deployment assertion and added contract coverage for the HTML-vs-JS ownership split. The accepted application source and migration did not change.

### Final Production deployment — PASS

Final wrapper result:

```text
SETUP #206 V0.3.22 PICK LIST DELAY PRODUCTION DEPLOYMENT WRAPPER: PASS
Exit status: 0
```

Production-after evidence:

```text
Frozen Setup fingerprint: 4b6ab1b5f61530d24bfd547555f4eacb
Final Setup fingerprint:  4b6ab1b5f61530d24bfd547555f4eacb
PASS: governed Setup data fingerprint unchanged

2026 Setup Session count before: 1
2026 Setup Session count after:  1
PASS: 2026 Setup Session count unchanged
```

The final deployment runner also required all of the following before returning PASS:

- exact deployed Setup SHA = `6f53d7f0c4b15f7175e773a2069595eef3f0e698`;
- clean live Setup worktree;
- Setup health = `V0.3.22-pick-list-delay`;
- V0.3.22 client/Pick Delay source contract PASS;
- protected unauthenticated material-readiness negative path PASS;
- authenticated 2026 Pick List/Pick Delay read PASS;
- live Setup/Application regression PASS;
- final Pick Delay row count = 0;
- 2026 Setup Session count unchanged;
- governed Setup fingerprint unchanged.

## Production runtime after acceptance

```text
application SHA = 6f53d7f0c4b15f7175e773a2069595eef3f0e698
version         = V0.3.22-pick-list-delay
client badge    = Client V0.3.22
migration       = Setup/Database/063_add_setup_pick_list_delay.sql
migration blob  = 45d1f71e226ab9e358e40f331945135cbe19cfb8
2026 Session    = 1
Pick Delay rows = 0 at deployment close
```

## Rollback boundary

This release is migration-bearing.

A source-only checkout rollback is not a complete rollback because migration 063 installs:

- `ops.setup_pick_list_delay`;
- `ops.set_setup_pick_list_delay(...)`;
- `ops.clear_setup_pick_list_delay_on_schedule()`;
- `trg_setup_pick_list_delay_schedule_release`.

Use the Production Database Change Deployment Runbook and retained rollback evidence for recovery. Do not restore the database archive without reconciling legitimate post-deployment Production work.

## Handoff

#206 is complete for the accepted launch scope.

Ownership after closeout:

```text
#206 = what should be picked / Pick List demand + Pick Delay + Pick List entry UX
#88  = persisted physical pick/movement events and offline/sync execution
#113 = scanner/tablet capture plumbing
#171 = GIS / map / spatial interpretation
#230 = Manager reference data / Home Location maintenance
```

Do not reopen #206 to implement the #88 movement-event model.
