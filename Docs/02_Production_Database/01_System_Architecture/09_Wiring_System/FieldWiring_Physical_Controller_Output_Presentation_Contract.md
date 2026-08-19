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

This means FieldWiring does **not** need Controller Inventory merely to know which presentation model applies.

Controller Inventory is still needed to identify and label the actual permanent physical controller asset and to group LOR address ranges that belong to that physical controller across Displays.

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
        -> physical-output presentation

Operator sees:
    physical controller label/identity when available
    physical output / plug number
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
Pixie 4  -> outputs 1 through 4
Pixie 8  -> outputs 1 through 8
Pixie 16 -> outputs 1 through 16
```

Each output is one physical plug/pigtail to the field operator.

However, LOR assigns a range of Unit IDs across those outputs because each RGB/pixel string requires many sequencing channels. Consequently:

> A raw LOR Unit ID within a Pixie address range is not a separate physical controller.

FieldWiring must not present every Unit ID in a Pixie range as though the volunteer were looking at a different controller.

### Verified Church example

Current V7 data for:

```text
CH-RGBTree-16x100-180
```

identifies the Prop as:

```text
device_type = LOR
string_type = RGB
base UID = 30
```

The current field-lead rows span:

```text
30
31
32
33
34
35
36
37
38
39
3A
3B
3C
3D
3E
3F
```

with `StartChannel = 1` on each logical LOR output row.

Physically, this is one 16-output Pixie controller and the volunteer sees:

```text
Output 1
Output 2
...
Output 16
```

not sixteen separate controllers numbered `30` through `3F`.

The raw range `30-3F` remains useful engineering/configuration information but should not be the primary hookup instruction.

## What Can Be Done Before Controller Inventory Exists

The current V7 data already provides enough information to distinguish the A/C and RGB presentation paths using `string_type`.

Therefore FieldWiring can avoid the most misleading presentation immediately:

```text
Traditional LOR
    -> present StartChannel as physical Output/Plug

RGB LOR
    -> do not label every raw Unit ID as a separate physical Controller
```

For a single RGB Display whose current LOR structure clearly spans one contiguous logical Unit-ID sequence, FieldWiring may test deriving an output ordinal from the ordered logical rows for that Display:

```text
first logical output row  -> Output 1
second logical output row -> Output 2
...
```

The `CH-RGBTree-16x100-180` `30-3F` case is the initial acceptance example for that presentation.

This is an **interim presentation derivation under test**, not a substitute for Controller Inventory.

Without Controller Inventory, FieldWiring must not assume that separate RGB Displays with nearby or contiguous Unit IDs necessarily belong to the same physical Pixie controller. Physical-controller grouping across Displays requires an authoritative controller asset/deployment relationship.

## Controller Inventory Integration

The existing Controller Inventory subsystem remains the future authority for the physical hardware asset.

When implemented, it should provide FieldWiring with at least enough relationship data to answer:

```text
Which permanent physical controller is this?
What controller type/model is it?
How many physical outputs does it have?
What LOR Unit-ID/base-address range belongs to it for the current deployment?
Which physical output number corresponds to this wiring row?
```

LOR remains authoritative for show topology and addressing. Controller Inventory adds the physical-asset identity and deployment interpretation needed for human-friendly field presentation; it does not replace LOR topology.

## Operator Presentation Direction

The normal FieldWiring table should eventually emphasize physical hookup terms rather than raw addressing terms.

Conceptually:

### A/C controller

```text
Controller: <physical controller label>
Output:     7
Channel Name: CH ...
Display:      CH-...
Network:      Regular
```

### Pixie controller

```text
Controller: <physical Pixie label>
Output:     12
Channel Name: CH-RGBTree-16x100-180 ...
Display:      CH-RGBTree-16x100-180
Network:      Aux N
```

Raw LOR Unit ID/address remains available under engineering details when needed.

Until physical controller identities exist in PostgreSQL, prototypes may show an explicitly temporary engineering identifier, but they must not teach operators that Pixie Unit IDs are separate physical controllers.

## Acceptance Cases

FieldWiring controller/output presentation testing must include at minimum:

1. one conventional 16-channel A/C controller proving `StartChannel 1-16` maps directly to physical Output 1-16;
2. `CH-RGBTree-16x100-180`, proving raw Unit IDs `30-3F` are presented as one Pixie 16 with Outputs 1-16 rather than sixteen controllers;
3. a Pixie 8 example proving eight logical output rows become Outputs 1-8;
4. a Pixie 4 example when a current example is identified;
5. multiple separate RGB Displays with nearby Unit IDs, proving FieldWiring does not incorrectly merge them into one physical controller before Controller Inventory supplies that relationship;
6. engineering-details access to the raw LOR Unit ID/address and other topology fields;
7. no regression to the LOR-authoritative wiring topology or field-lead row relationships.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Controller Inventory and Labeling Plan](../08_Controller_Inventory/Controller_Inventory_and_Labeling_Plan.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
