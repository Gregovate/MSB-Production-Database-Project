# FieldWiring Candyland Stale Snapshot Output Mapping — 2026-08-20

| Item | Value |
|---|---|
| Status | ACCEPTED — browser-observed stale-snapshot presentation |
| Sub-project | FieldWiring |
| Scene | `17-Candyland-CL` |
| Scope | Candy Cane Pixie grouping vs. stale snapshot output mapping |
| Schema status | No schema change authorized or required |

## Purpose

This finding clarifies the accepted FieldWiring behavior when a physical controller grouping is already operator-confirmed but the development snapshot predates a known LOR correction.

## Confirmed Physical Grouping

Candyland Musical uses twelve RGB Candy Canes on three physical Pixie 4 controllers:

```text
Pixie group 1 -> Candy Canes 01-04
Pixie group 2 -> Candy Canes 05-08
Pixie group 3 -> Candy Canes 09-12
```

The intended/current live Preview address pattern is three repeated `21-24` blocks.

## Stale Development Snapshot

The current development snapshot was created before the live Preview correction to Candy Cane 12. It therefore still contains:

```text
Candy Cane 09 -> 21
Candy Cane 10 -> 22
Candy Cane 11 -> 23
Candy Cane 12 -> 22
```

The live Preview was later corrected so Candy Cane 12 uses Unit ID `24`, but no new controlled snapshot has yet been imported.

## Accepted FieldWiring Presentation

The stale snapshot must not cause the third physical controller to be presented as `GROUPING REVIEW REQUIRED` because the third Pixie 4 grouping is already operator-confirmed.

At the same time, FieldWiring must not silently rewrite the stale snapshot from `22` to `24`.

Therefore the current stale snapshot must present:

```text
PIXIE 4 · Pixie group 3

Output 1 -> CL-RGBCandyCane-09
Output 2 -> CL-RGBCandyCane-10
            CL-RGBCandyCane-12
Output 3 -> CL-RGBCandyCane-11
Output 4 -> no current snapshot relationship
```

This preserves both truths simultaneously:

- physical grouping: Candy Canes 09-12 belong to the third Pixie 4 controller;
- current snapshot topology: Candy Cane 12 still resolves to the same programmed address/output as Candy Cane 10 until a refreshed snapshot is imported.

## Browser Acceptance — 2026-08-20

Operator browser acceptance on the laptop confirmed the current FieldWiring result for Candyland Musical after commit `b830f1bfcb2d3de3e4c263478407498f7392d5a7` (`Scope stale Candyland controller mapping to Candyland scene`).

Observed browser result:

```text
PIXIE 4 · Pixie group 3
LOR UNIT IDS 21-24
NETWORK Aux A

Output 1
  CL-RGBCandyCane-09

Output 2
  CL-RGBCandyCane-10
  CL-RGBCandyCane-12

Output 3
  CL-RGBCandyCane-11
```

The third controller was no longer shown as `GROUPING REVIEW REQUIRED`.

The operator explicitly confirmed: **this presentation is correct for the current stale development snapshot**.

This is browser-observed acceptance of the Candyland stale-snapshot behavior. It does not change the source data and does not claim that Cane 12 has already moved to Output 4 in the current development snapshot.

## Refresh Behavior

After the normal parser/import cycle produces a new snapshot containing the corrected live Preview value:

```text
CL-RGBCandyCane-12 -> 24
```

FieldWiring should naturally present:

```text
Output 1 -> Candy Cane 09
Output 2 -> Candy Cane 10
Output 3 -> Candy Cane 11
Output 4 -> Candy Cane 12
```

No special data rewrite or migration is required in FieldWiring.

## Rule Established

A known physical controller grouping and its current snapshot output relationships are separate concerns.

FieldWiring may preserve an operator-confirmed physical controller grouping while still presenting the exact current snapshot wiring relationships inside that group. It must not discard the group merely because the snapshot contains a known stale assignment, and it must not silently repair source topology outside the controlled parser/import process.

## Related Documents

- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring RGB Controller Pattern Findings — 2026-08-19](FieldWiring_RGB_Controller_Pattern_Findings_2026-08-19.md)
- [FieldWiring Accepted Baseline Recovery — 2026-08-20](FieldWiring_Accepted_Baseline_Recovery_2026-08-20.md)
