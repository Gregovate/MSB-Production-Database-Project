# FieldWiring Atomic DMX Context Scope Correction — 2026-08-31

| Item | Value |
|---|---|
| Status | CURRENT CORRECTION |
| Scope | FieldWiring V7.0.11+ atomic DMX source-detail replacement |
| Issue | #110 Controller Inventory / FieldWiring integration |

## Production symptom

A whole-Stage FieldWiring view could show DMX/E1.31 controller groups that belonged to unrelated Stages. The same foreign groups could appear repeatedly across many wiring views.

Observed examples included Mega Ball, Mega Star, Mega Tree, WA-MegaCube, WV-WhoMatrix, and other DMX/E1.31 groups appearing in a Racing Arches whole-Stage view where they did not belong.

## Cause

`wiring_data.py` correctly bounded the initial whole-Stage wiring package to the resolved `ref.display.stage_id`.

The later V7.0.11+ atomic-DMX replacement path then queried atomic DMX source-detail rows from the entire selected Preview. For a shared/master Preview this source set can legitimately contain DMX Displays from many Stages.

`replace_legacy_dmx_rows()` previously appended/replaced from that Preview-wide source set without restricting it back to the Display IDs already admitted by the resolved Stage/Scene package.

The result was context broadening:

```text
resolved Stage rows
    + Preview-wide atomic DMX rows
    = foreign DMX Displays shown in unrelated wiring views
```

## Correct contract

The already-resolved FieldWiring package is authoritative for membership in the current Display/Stage/Scene context.

Atomic DMX source detail is an **enrichment source only**. It may replace legacy DMX rows for a Display that is already in the resolved package, but it may never introduce a new Display into that package.

Therefore:

1. if the resolved context contains no legacy DMX rows, the atomic DMX loader does not add any;
2. if the resolved context contains DMX Displays, atomic source rows are filtered to those exact permanent `display_id` values;
3. V7.0.11+ still fails closed when an in-scope legacy DMX Display cannot be resolved to required atomic source detail;
4. Preview-wide DMX rows for other Displays are ignored even when they exist in the same shared/master Preview.

## Implementation

Corrected module:

```text
FieldWiring/Application/wiring_dmx_source.py
```

Regression coverage:

```text
FieldWiring/Application/test_wiring_dmx_scope_guard.py
```

The tests prove both:

- a non-DMX Stage cannot acquire DMX rows merely because its Preview contains them elsewhere;
- a Preview-wide source-detail result containing foreign Displays is filtered back to the Display IDs already present in the resolved context.

## Controller Inventory consequence

This correction is independent of permanent physical Controller Inventory resolution. It restores the prerequisite context boundary first.

Permanent Controller Inventory integration must operate only on the correctly scoped FieldWiring Displays and must never broaden Stage/Scene membership through controller addressing, shared UID values, universes, or shared Preview membership.
