# FieldWiring Church RGB Tree Star Controller Context — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING FINDING — operator-confirmed LOR Prop Definition evidence |
| Sub-project | FieldWiring |
| Display | `CH-RGBTree-Star` |
| Scene | `15-Church-CH` |
| Schema status | No schema change authorized or required |

## Purpose

This finding corrects an incorrect assumption introduced during the 2026-08-20 FieldWiring recovery work.

`CH-RGBTree-Star` must **not** be attached to the Church Tree Pixie 16 (`CH-RGBTree-16x100-180`, LOR Unit IDs `30-3F`) as Output 16.

The operator inspected the current LOR Prop Definition for the Star and confirmed it is a separate RGB/Pixie controller context.

## Current LOR Evidence

The Prop Definition shows:

```text
Name:       CH RGB Star Nested
Comment:    CH-RGBTree-Star
Tag:        RGB Tree 16x50 Star
Type:       Pixels RGB
Network:    Aux N
```

The channel allocation shown in LOR spans Unit IDs `40-41`:

```text
row 1: Aux N / Unit ID 40 / circuits 1-240
row 2: Aux N / Unit ID 40 circuit 241 -> Unit ID 41 circuit 120
row 3: Aux N / Unit ID 41 / circuits 121-240
row 4: Aux N / Unit ID 41 / circuits 241-300
```

The Prop Definition also shows:

```text
Separate Unit ID for each RGB string: unchecked
```

## Accepted Interpretation

The evidence is sufficient to establish:

```text
CH-RGBTree-Star
    -> separate Pixie controller context
    -> Network Aux N
    -> LOR addressing spans 40-41
    -> NOT part of the Church Tree Pixie 16 at 30-3F
```

The evidence is **not** sufficient by itself to establish the exact physical Pixie model or physical output count.

The four LOR channel-allocation rows must not be interpreted as four physical Pixie outputs merely because four rows are visible in the Prop Definition. Likewise, the two Unit IDs `40-41` must not automatically be interpreted as a Pixie 2.

Until physical controller evidence or Controller Inventory reconciliation establishes the model/output mapping, normal FieldWiring may present:

```text
PIXIE CONTROLLER · CH-RGBTree-Star
LOR Unit IDs: 40-41
Network: Aux N
Physical Output / Plug: not yet established
```

This is a **known separate controller context**, not `PIXIE · GROUPING REVIEW REQUIRED`.

## Regression Requirement

FieldWiring tests must prove all of the following simultaneously for Church Musical:

1. `CH-RGBTree-16x100-180` remains one Pixie 16 at `30-3F`, Outputs 1-16;
2. `CH-RGBTree-Star` is a separate Pixie controller context at `40-41`;
3. the Star is never attached to Tree Output 16;
4. the Star does not display as `GROUPING REVIEW REQUIRED` when the current context matches the confirmed `Aux N` / `40-41` evidence;
5. exact Star Pixie model/output count remains unresolved until supported by authoritative physical evidence;
6. Church Crosses and repeated Candy Cane Pixie groups remain independent of both Tree contexts.

## Controller Inventory Boundary

This finding does not create permanent physical controller identity.

As with the rest of FieldWiring:

- LOR Unit IDs are topology/addressing evidence;
- the `40-41` range is not a permanent controller key;
- Controller Inventory will later provide stable physical controller identity and deployment history;
- FieldWiring must preserve the useful current addressing evidence without promoting it to permanent identity.

## Related Documents

- [FieldWiring RGB Controller Pattern Findings — 2026-08-19](FieldWiring_RGB_Controller_Pattern_Findings_2026-08-19.md)
- [FieldWiring Accepted Baseline Recovery — 2026-08-20](FieldWiring_Accepted_Baseline_Recovery_2026-08-20.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
