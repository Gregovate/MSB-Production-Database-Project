# #122 — 2026 Setup Launch Control Register

**Status:** ACTIVE / governance draft, awaiting PR review. **Authority:** commanding [#122](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122); subordinate owning issues and accepted engineering design remain authoritative. **Snapshot date:** 2026-10-21. **Source main:** `2d65781d73c761f0320eefd35fc06a5bf7b7dfa9`.

> This document is a compact coordination index, not a second system of record. It never proves current Production release state by itself. A PR, merge, source test, clone test, browser test, and live field verification are different stages. The lines below are observations from issue/PR reconnaissance, not implied acceptances.

## Field-window priorities and next accountable actions

| Field deliverable | Owning issue / existing implementation | Evidenced state on Oct 21 | Next ENGINEERING action | Greg needed now? |
|---|---|---|---|---|
| GIS Manager old/current/new Garmin/ExpertGPS reconciliation while lines visible | [#428](https://github.com/Gregovate/MSB-Production-Database-Project/issues/428), [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171); PRs [#378](https://github.com/Gregovate/MSB-Production-Database-Project/pull/378), [#425](https://github.com/Gregovate/MSB-Production-Database-Project/pull/425), [#319](https://github.com/Gregovate/MSB-Production-Database-Project/pull/319) | Open; PRs draft; PC-app acceptance not proven | Continue existing Windows PC app on Greg's laptop; establish bounded one-route old/current/new overlay and controlled proposed replacement against current master | Only real route/endpoint or field acceptance when requested |
| Remote LOR previews ready for Adam | [#299](https://github.com/Gregovate/MSB-Production-Database-Project/issues/299); PR [#300](https://github.com/Gregovate/MSB-Production-Database-Project/pull/300) | Open; PR draft; candidate/deployment not verified; Candyland omission/Elf On Shelf-3 revision discrepancy documented | Resume existing programmer-PC tool; reconcile approved PreviewIDs/content before safe distribution; preserve unrelated local previews | Verify programmer-machine result after engineering validation |
| FieldWiring circuit reports before hookup | Existing FieldWiring application, [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171) for infrastructure authority | Exact owning code path and end-to-end readiness not established by this review | Recon existing circuit schema/UI/permissions and make a narrow field-reporting acceptance checklist; do not conflate with deferred folded-wire printing #119 | Only missing physical circuit facts / short field acceptance |
| LinkIQ/cable tester evidence and wiring map | FieldWiring, [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171), PR [#319](https://github.com/Gregovate/MSB-Production-Database-Project/pull/319) | Source sync PR draft; approved cable test-to-map lifecycle unverified | Audit existing ingestion, stable endpoints, captured test facts and reviewed geometry projection; avoid rewriting historical source | Validate physical endpoint when evidence is ambiguous |
| Correct reusable and 2026 Setup unloading tasks | [#445](https://github.com/Gregovate/MSB-Production-Database-Project/issues/445), [#205](https://github.com/Gregovate/MSB-Production-Database-Project/issues/205), PR [#446](https://github.com/Gregovate/MSB-Production-Database-Project/pull/446) | PR draft; rollback-only probe, **NOT** an executed disposable PASS | Finish read-only source snapshot; review C034/48-Display ownership; validate actual clone; present tested candidate and no fabricated work history | No approval until reviewed acceptance |
| Container Record Location, unloading, reconcile returns/contents | [#88](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88), Scan [#113](https://github.com/Gregovate/MSB-Production-Database-Project/issues/113), PRs #309/#418 | Multiple partial/overlapping draft PRs and historical installed behavior; current end-to-end state not verified | Reconcile installed event model, current display attachments, Record Location and safe Manager resolve; test exact field sequence | Verify physical state only where unavoidable |
| Scan Display to location, release from Container, Ready for Wiring | [#88](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88), [#431](https://github.com/Gregovate/MSB-Production-Database-Project/issues/431) | Field workflow acceptance not established | Prove actual scan → observation → detachment when indicated → position/state projection, retaining original events | One bounded field test |
| Volunteer Work Orders access | [#447](https://github.com/Gregovate/MSB-Production-Database-Project/issues/447), [#419](https://github.com/Gregovate/MSB-Production-Database-Project/issues/419) | Known exact-email Person-link defect; manual repairs done; permanent entry correction not deployed | Reuse existing shared reconciler; no new role authority or broad permission grants; test Crew/Manager/denial | Quick access acceptance after verification |
| Active scheduling and release defects | [#205](https://github.com/Gregovate/MSB-Production-Database-Project/issues/205), #122 | Modal errors and stale report evidence recorded; CatalogScope PR #440 server deployment PASS per Oct 21 operator screenshot, browser verification/closeout outstanding | Verify current deployment receipt/browser and consolidate shared modal error contract; reconcile outstanding release PRs | Browser acceptance only after tests |

## Operator decision queue

All listed gates **not yet ready for approval** unless the owning issue demonstrates a completed technical candidate:
- GIS: select/approve a physical route change once old/current/new evidence is visualized.
- LOR: confirm Adam can safely receive approved previews without overwriting his other previews.
- Setup #445: review the material/dependency map after current-clone acceptance.
- #88: verify real physical Container/Display exceptions, not inferred movements.
- #447: check normal authorized account entry on the tested candidate.
- Every Production mutation: explicit authorization of exact tested SHA/migration, governed maintenance and snapshot.

## Status vocabulary and required checkpoint fields

Use `REPORTED`, `RECON`, `IMPLEMENTING`, `CANDIDATE`, `SOURCE-TESTED`, `DISPOSABLE-PASS`, `BROWSER-ACCEPTED`, `MERGED`, `DEPLOYED`, `FIELD-VERIFIED`, `BLOCKED`, or `SUPERSEDED`. Never promote an earlier stage to a later stage by inference. Each owning issue checkpoint must include:
- task/outcome, urgency and physical deadline;
- owning issue/PR and authoritative design;
- exact branch / SHA and refreshed main SHA;
- concrete regression and disposable evidence;
- exact deployed identity/receipt if any;
- known blocker and **one next engineering action**;
- **operator action**, only for unavailable physical facts, acceptance or approval.

## Update and recovery policy

1. First read the current [project rules](../../../../../System_Documentation/Project_Rules/README.md), current #122, and the appropriate owning engineering authority. This file is an index, not permission to skip that step.
2. An implementing conversation owns its branch, tests and child issue. It checkpoints before reaching an unsafe context size, at every significant transition, and **before** a user archives its predecessor. Never rely on token-capacity warnings.
3. The launch coordination conversation consumes those checkpoints and updates **this register via reviewed repository change**, with concise #122 status comments when needed. It does not execute unrelated implementation in the control thread.
4. New field findings are reconciled into an existing issue before creating another. No new control application, role model, synchronization engine or deployment procedure without approved design.
5. No asynchronous monitoring is presumed. Checkpoints reflect what was inspected as of their timestamps; a chat cannot see future work in other threads.
6. #122 remains open until explicit closeout approval and all controlling project rules are satisfied. Do not infer closeout from a merged PR.

## Chat rotation and sidebar archive contract

Start a fresh conversation with:

```text
Continue MSB Launch Control under issue #122. Read current
System_Documentation/Project_Rules/README.md and relevant linked rules,
the latest #122 comments, and
Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_122_Launch_Control_Register_2026.md.
Refresh GitHub and reconcile differences with each owning issue/PR.
Report only verified changes, current field blockers, next engineering
actions and the decisions requiring Greg. Do not treat a prior chat as
engineering authority; do not create replacement infrastructure or
close #122 without approval.
```

Archive an old implementation thread **only after** its owning issue records exact branch/SHA, outstanding work and next step, and the successor can retrieve it. Archiving is a ChatGPT UI action done by Greg; it does not close a GitHub issue. Rename the control conversation `MSB Launch Control — #122 — 2026-10`. Rotate by manageable work period rather than waiting for a full thread.
