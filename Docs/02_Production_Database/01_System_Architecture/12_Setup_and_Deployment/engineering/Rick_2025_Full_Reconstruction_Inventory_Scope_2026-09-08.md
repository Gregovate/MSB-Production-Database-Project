# Rick 2025 Full Reconstruction Inventory Scope — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Reconstruction Inventory Scope |
| System | Production Database — Setup Session |
| Status | CURRENT — supersedes the earlier narrow Batch 01 interpretation |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; issue #132 |

## Purpose

Correct the scope of the Rick Hoffmann 2025 spreadsheet reconstruction effort.

The earlier Batch 01 pass intentionally identified only a small set of high-confidence rows that mapped directly to existing Production tasks. That subset was useful as a proof of import mechanics, but it was **not** a complete reconstruction inventory and must not be treated as such.

The operator review correctly identified that the two 2025 spreadsheets contain far more Setup work than the current Production catalog represents.

## Source Window

Current reconstruction review window:

```text
2025-09-30 through Thanksgiving 2025
```

Primary source files supplied in the engineering session:

```text
Copy of Copy of 2025 Work (1).xlsx
MSB Rick Recorded Hours 2025(1).xlsx
```

The current Production snapshot supplied for mapping contained 69 2025 reusable/annual task identities.

## Preliminary Full-Pass Scale

A broader clause-by-clause pass through the source window produced:

```text
157 dated field-work / evidence rows

89  activity mentions with no clean current reusable-task match
21  clean existing-task matches
16  existing-task partial / too-broad matches
22  shorthand / ambiguous items requiring review
8   repair / database / other non-Setup items that should not be forced into Setup
1   cross-stage support/training evidence item
```

These are **activity/evidence mentions, not 157 unique reusable tasks**. Repeated work on different days is intentionally preserved because it may become multiple progress entries on one reusable task.

The scale nevertheless confirms that the current 69-task Production snapshot is materially incomplete as a representation of real 2025 Setup work.

## Examples of Material Catalog Gaps

The source window contains explicit work for areas/steps that have no clean current reusable-task identity or are represented only by an overly broad task.

Examples include:

```text
Dancing Forest field flags / layout
Festive Trees field flags / cord laying / later partial progress
Santa's Station interior delivery, exterior setup, panel layout, sign, lights
Post Office panels, roof, truck/tarp positioning
Northern Lights placement, aiming/tightening, later repair
Glistening Grove field work / labeling
OMW locates, panels, network locating
Train panels
Peanuts panels and harness
Deer 1 & 2 panel layout / installation
Frying Santa panel layout
Kingsbury panel layout
Church Tree candy canes
Front Gate wraps and harness work
Volunteer Trail work
conveyor-belt scaffold
Santa-bag scaffold
Snow Storm bull line
Elf Choir panel and harness work beyond the current broad tasks
Whoville harness / panels / Goal harness
Horse & Sleigh delivery / placement / movement
Santa's Workshop frame delivery
Kranks VW
Bells harness
Food Collection Star / lasers / arrows / Thank You sign / north and south wraps
Quarry interior / exterior / cord work
Global Warming connection
Sledders net lighting / strobes / string-light follow-up
Lake Park network locating
Christmas Story panels
Winter Wonderland cord/hookup work
Speed Limit signs
Frosty delivery / controller-securement questions
Mega Star
Flick Pole shims
UTV hut
Polar Bear panel cords
Front Entrance cord laying
Claymation cord laying
```

This list is representative, not exhaustive.

## Important Interpretation Rule

The goal is **not** to create one reusable task for every sentence fragment in Rick's notes.

Each source activity must be normalized into one of these outcomes:

```text
EXISTING_MATCH
  -> add 2025 progress / crew / duration evidence to the correct existing task

EXISTING_PARTIAL
  -> current reusable task exists but is too broad, missing a phase, or has the wrong boundary

CATALOG_GAP
  -> real repeatable/plannable Setup work appears to be missing from Production

REVIEW_REQUIRED
  -> shorthand or mixed notes are not strong enough to normalize without operator review

WORK_ORDER_OR_NON_SETUP
  -> repair, database cleanup, documentation, or other work that should not be forced into Setup execution history
```

## Progress Versus Reusable Knowledge

A dated work occurrence and a reusable task definition are different records.

For example:

```text
2025-11-11 Festive Tree cords approximately 60% complete
crew = Paul H., Randy, Dan, Deb
```

should become:

```text
reusable task
  Festive Trees — Lay Cords

2025 progress evidence
  date = 2025-11-11
  crew = 4
  progress = approximately 60%
```

It should not be buried as a free-text annual note.

## Multi-Day / Cross-Stage Model

Repeated activity across several dates is expected and must remain visible.

The planner must not assume:

```text
finish Stage A
then start Stage B
```

Real Setup work moves between Stages and task families based on people, skills, equipment, weather, readiness, and what can be productively completed that day.

Therefore reconstruction must preserve multiple progress rows against one reusable task when the same work continues on later days.

## Crew and Duration Evidence

The full inventory should capture crew and duration only where the source supports them.

Strong examples already identified include:

```text
2025-10-06 Magic Igloo skins
crew = 6
duration = 300 minutes
source explicitly says 9:00–2:00 and excludes bungees

2025-10-13 Mt Crumpit
crew = 4

2025-10-13 Icicle Tunnel
crew = 6

2025-10-15 Northern Lights
crew = 5

2025-11-11 Festive Tree cords
crew = 4
progress = approximately 60%

2025-11-13 Stars
crew = 5
source says Paul + Rich with three people on the ground
```

The two Rotary Saturdays also provide useful aggregate turnout evidence:

```text
2025-10-04 = 12 morning / 9 afternoon
approximately half on panels and half on Magic Igloo

2025-10-11 = 10 morning / 7 afternoon
task allocation not remembered
```

Do not fabricate per-task crew-hours from shared crews or daily totals without allocation evidence.

## Required Production Path

The spreadsheets are useful only if normalized evidence reaches Production.

Required path:

```text
1. build the complete reconstruction inventory
2. map clean rows to existing reusable task IDs
3. identify reusable catalog gaps / task-boundary corrections
4. create/review missing reusable tasks where evidence is strong
5. add per-progress duration support (issue #132)
6. create a reconstruction-safe importer for 2025 work-day/progress evidence
7. test the exact import against a current Production clone
8. operator-review unresolved mappings
9. controlled Production import under the Production Database deployment runbook
```

Do not manually type dozens or hundreds of spreadsheet-derived records through the browser when a controlled reconstruction package can preserve provenance and be validated first.

## Current Conclusion

The current task catalog is not merely missing a handful of details. The 2025 source evidence demonstrates a much larger normalization and reconstruction workload.

The immediate engineering objective is therefore **full inventory and normalization**, not another tiny hand-selected import batch.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Crew Work Reporting Contract](Setup_Crew_Work_Reporting_Contract_2026-09-08.md)
- [2025 Live Review Work Ledger](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md)
- GitHub issue #122
- GitHub PR #125
- GitHub issue #132
