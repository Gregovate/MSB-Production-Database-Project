# FieldWiring Physical Controller / Output Presentation Contract

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction; controller-inventory integration pending |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Schema status | No schema change authorized; Controller Inventory is not yet implemented in PostgreSQL |

## Purpose

FieldWiring must translate LOR-authoritative addressing into the physical hookup language used by volunteers in the park.

The raw LOR wiring fields are technically correct, but they are not always the same thing as the physical controller and physical plug/output a volunteer sees.

This matters because MSB uses materially different controller/output models, including:

- conventional LOR A/C controllers; and
- LOR Pixie RGB/pixel controllers.

FieldWiring must not assume that one raw LOR `Controller`/Unit ID always equals one physical controller.

## Existing V7 Discriminator — `string_type`

The current V7 snapshot already carries `string_type` on current Props and SubProps.

For the two LOR cases covered by this contract:

```text
string_type = Traditional
    -> conventional A/C-style field hookup

string_type = RGB
    -> Pixie / pixel-controller-style field hookup
```

`string_type` is sufficient to choose the **presentation family**. It is not, by itself, sufficient to determine the physical controller asset or physical output number for every RGB topology.

Controller Inventory is still needed to identify and label the actual permanent physical controller asset and, where LOR addressing is reused or ambiguous, to map the LOR topology to the physical controller/output assignment.

Other current values such as `DumbRGB`, and DMX-controlled devices, are outside this specific A/C-versus-Pixie rule and must not be forced into either presentation without their own reviewed contract.

## Field Principle

The operator-facing question is:

> Which physical controller and numbered output/plug do I connect this Display to?

Raw hexadecimal LOR Unit IDs, address ranges, RGB channel spans, and other sequencing details remain engineering data. They should not be the primary field instruction when a simpler physical hookup description exists.

Conceptually:

```text
LOR topology / addressing
        -> current FieldWiring read model
        -> inspect string_type
        -> interpret the applicable physical-output pattern
        -> enrich with Controller Inventory when required

Operator sees:
    physical controller label/identity when available
    physical output / plug number when determinable
    Channel Name
    Display Name
    Network when useful

Engineering details retain:
    raw LOR Unit ID / address
    raw StartChannel
    source/device metadata
```

## Conventional A/C Controllers — `string_type = Traditional`

A conventional 16-channel A/C controller has one LOR Unit ID and sixteen numbered physical outputs.

For normal field hookup the relationship is one-to-one:

```text
LOR StartChannel 1  -> physical Output 1
LOR StartChannel 2  -> physical Output 2
...
LOR StartChannel 16 -> physical Output 16
```

Therefore the field-facing **Output** value may be taken directly from `StartChannel` for this controller model.

The LOR Unit ID remains necessary for LOR configuration and engineering traceability, but a volunteer plugging a Display into a numbered controller output does not need to understand hexadecimal addressing.

Once Controller Inventory is implemented, the normal FieldWiring page should identify the physical A/C controller by its permanent/human-readable controller label or asset identity. The raw LOR Unit ID should move to optional engineering details.

## Pixie RGB / Pixel Controllers — `string_type = RGB`

A Pixie controller is physically different.

A Pixie controller has a fixed number of numbered physical RGB outputs:

```text
Pixie 2  -> outputs 1 through 2
Pixie 4  -> outputs 1 through 4
Pixie 8  -> outputs 1 through 8
Pixie 16 -> outputs 1 through 16
```

Each output is one physical plug/pigtail to the field operator.

However, LOR assigns Unit IDs/circuit ranges to the pixel data carried by those outputs. Consequently:

> A raw LOR Unit ID within a Pixie assignment is not automatically a separate physical controller.

FieldWiring must not present every RGB Unit ID as though the volunteer were looking at a different controller.

There are multiple valid RGB topology patterns in the current Church data. One universal "Unit ID = output" rule will not work.

## Church RGB Pattern 1 — One Prop Spans All Outputs of One Pixie

### `CH-RGBTree-16x100-180`

The LOR Prop Definition identifies:

```text
Type: Pixels RGB
Actual # of Controller Ports Used: 16
Exact # of RGB Nodes per Controller Port: 100
Start Unit IDs: 30 through 3F
Start Circuit: 1 for each port
```

The current V7 snapshot carries:

```text
lor_comment = CH-RGBTree-16x100-180
string_type = RGB
device_type = LOR
base UID = 30
parm1 = 16
parm2 = 100
```

and the current field-lead rows span logical Unit IDs:

```text
30 31 32 33 34 35 36 37
38 39 3A 3B 3C 3D 3E 3F
```

with `StartChannel = 1` on each logical output row.

Physically this is one Pixie 16. The field operator sees sixteen pigtails numbered 1 through 16.

For this pattern, the ordered logical rows inside the single Display/Prop can be presented as:

```text
30 -> Output 1
31 -> Output 2
...
3F -> Output 16
```

The raw `30-3F` range remains engineering/configuration information, not the primary hookup instruction.

A wiring/background image may additionally show physical orientation, such as the accepted Tree example where outputs 1 through 16 start at the bottom-left and proceed across the Tree.

## Church RGB Pattern 2 — One Display Spans Multiple Outputs of One Small Pixie

### RGB Crosses

The Church Crosses are separate RGB Displays using Pixie 2 controllers.

Current examples are:

```text
CH-RGBCross-LH  -> logical Unit IDs 42-43
CH-RGBCross-RH  -> logical Unit IDs 44-45
```

Current V7 data identifies these Props as `string_type = RGB`; the field-lead view exposes two logical output rows for each Cross. The current Prop records also carry `separate_ids = 1`.

Based on the operator-confirmed physical design, each Cross is one physical Pixie 2 and should be presented as:

```text
Cross Left
    Output 1
    Output 2

Cross Right
    Output 1
    Output 2
```

The raw Unit IDs `42-43` and `44-45` remain engineering details.

This is similar to the Tree in that multiple logical rows belong to one physical RGB Display/controller relationship, but the physical output count is two instead of sixteen.

## Church RGB Pattern 3 — Multiple Physical Pixies Intentionally Reuse the Same Unit-ID Range

### RGB Candy Canes

The Church Candy Canes demonstrate why LOR Unit ID cannot be treated as a unique physical-controller identity.

Eight separate RGB Candy Cane Displays are programmed as:

```text
Candy Cane 01 -> Unit ID 21
Candy Cane 02 -> Unit ID 22
Candy Cane 03 -> Unit ID 23
Candy Cane 04 -> Unit ID 24

Candy Cane 05 -> Unit ID 21
Candy Cane 06 -> Unit ID 22
Candy Cane 07 -> Unit ID 23
Candy Cane 08 -> Unit ID 24
```

Physically, this is **two Pixie 4 controllers**, each with outputs 1 through 4.

The second controller deliberately uses the same `21-24` Unit-ID range as the first so the paired Candy Canes repeat the same programming:

```text
Candy Cane 01 and 05 -> same programmed signal
Candy Cane 02 and 06 -> same programmed signal
Candy Cane 03 and 07 -> same programmed signal
Candy Cane 04 and 08 -> same programmed signal
```

This duplication is intentional and must not be "fixed" by FieldWiring or reconciliation.

The current V7 snapshot accurately preserves the duplication. It contains eight `string_type = RGB` Props, with Unit IDs `21-24` repeated across the two sets.

### Critical consequence

The LOR topology alone does **not** identify which physical Pixie 4 a Candy Cane is plugged into.

For example, Unit ID `21` legitimately corresponds to both:

```text
Candy Cane 01 -> physical Pixie A / Output 1
Candy Cane 05 -> physical Pixie B / Output 1
```

Therefore FieldWiring must not infer physical controller identity from Unit ID uniqueness, because Unit ID uniqueness does not exist in this valid installation.

Until Controller Inventory/deployment relationships identify the two physical Pixie 4 controllers, FieldWiring can show the authoritative Display and LOR topology but must not invent a physical controller label.

Once Controller Inventory exists, the desired presentation becomes approximately:

```text
Pixie A
    Output 1 -> Candy Cane 01
    Output 2 -> Candy Cane 02
    Output 3 -> Candy Cane 03
    Output 4 -> Candy Cane 04

Pixie B
    Output 1 -> Candy Cane 05
    Output 2 -> Candy Cane 06
    Output 3 -> Candy Cane 07
    Output 4 -> Candy Cane 08
```

while both physical controllers may legitimately retain the same LOR address range `21-24`.

## What Can Be Done Before Controller Inventory Exists

The current V7 data already provides enough information to distinguish Traditional versus RGB presentation using `string_type` and to avoid the most misleading raw-address presentation.

FieldWiring may safely do the following now:

```text
Traditional LOR
    -> present StartChannel as physical Output/Plug

RGB LOR
    -> do not label every raw Unit ID as a separate physical Controller
```

For an RGB Display whose own LOR Prop/field-lead structure clearly contains multiple ordered logical output rows, an output ordinal may be tested **within that Display only** when the physical design has been validated. The Tree and Cross examples are current acceptance cases.

FieldWiring must **not** generalize that rule across separate RGB Displays.

In particular, repeated or nearby Unit IDs across separate RGB Displays do not prove that those Displays share one controller, belong to different controllers, or identify which physical controller owns them. The Candy Cane installation proves that multiple physical controllers can intentionally share the same LOR Unit-ID range.

When the current data cannot deterministically identify a physical controller/output relationship, the normal field presentation must say so rather than fabricate one. The raw LOR address remains available as engineering information until the physical relationship is supplied by Controller Inventory.

## Controller Inventory Integration

The existing Controller Inventory subsystem remains the future authority for the physical hardware asset.

When implemented, it should provide FieldWiring with enough relationship data to answer:

```text
Which permanent physical controller is this?
What controller type/model is it?
How many physical outputs does it have?
What LOR Unit-ID/base-address range is assigned to it for the current deployment?
Which physical output number corresponds to this Display/wiring relationship?
```

A key requirement exposed by the Candy Cane example is:

> **LOR Unit ID or Unit-ID range must not be treated as a unique key for a physical controller.**

The controller/deployment model must allow two or more distinct physical controllers to intentionally carry the same LOR Unit-ID range when that is how the show is programmed.

LOR remains authoritative for show topology and addressing. Controller Inventory adds physical-asset identity and deployment interpretation needed for human-friendly field presentation; it does not replace or "normalize away" valid LOR duplication.

## Operator Presentation Direction

The normal FieldWiring table should emphasize physical hookup terms rather than raw addressing terms whenever the physical mapping is known.

### A/C controller

```text
Controller: <physical controller label>
Output:     7
Channel Name: CH ...
Display:      CH-...
Network:      Regular
```

### Pixie 16 Tree

```text
Controller: <physical Pixie label when available>
Output:     12
Display:    CH-RGBTree-16x100-180
Network:    Aux N
```

### Pixie 2 Cross

```text
Controller: <physical Pixie label when available>
Output:     1 or 2
Display:    CH-RGBCross-LH
Network:    Aux N
```

### Pixie 4 Candy Cane before Controller Inventory

```text
Display:        CH-RGBCandyCane-05
Physical controller: NOT YET IDENTIFIED
Raw LOR address: 21   [engineering/detail]
Network:        Aux N
```

After Controller Inventory supplies the deployment mapping, the raw address can remain hidden by default while the physical controller label and Output 1-4 become the normal hookup instruction.

## Acceptance Cases

FieldWiring controller/output presentation testing must include at minimum:

1. one conventional 16-channel A/C controller proving `StartChannel 1-16` maps directly to physical Output 1-16;
2. `CH-RGBTree-16x100-180`, proving raw Unit IDs `30-3F` are presented as one Pixie 16 with Outputs 1-16 rather than sixteen controllers;
3. `CH-RGBCross-LH` and `CH-RGBCross-RH`, proving two logical RGB rows can represent Outputs 1-2 of one Pixie 2 per Cross;
4. all eight Church RGB Candy Canes, proving duplicate Unit IDs `21-24` remain valid and are not merged into one physical controller;
5. two distinct physical Pixie 4 controller records eventually carrying the same `21-24` deployment range without violating Controller Inventory identity rules;
6. engineering-details access to the raw LOR Unit ID/address and other topology fields;
7. no regression to the LOR-authoritative wiring topology or field-lead row relationships; and
8. no physical-controller/output inference when the available data does not support one deterministic answer.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Controller Inventory and Labeling Plan](../08_Controller_Inventory/Controller_Inventory_and_Labeling_Plan.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
