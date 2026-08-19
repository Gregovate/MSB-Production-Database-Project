# FieldWiring E1.31 Dense RGB Field Presentation Contract

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction; controller-inventory mapping pending |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Schema status | No schema change authorized |

## Purpose

FieldWiring must distinguish dense RGB Displays driven through the MSB E1.31 network from both conventional LOR/Pixie hookups and the simpler DMX/DumbRGB fixture case.

The current V7 snapshot represents the reviewed dense RGB examples with:

```text
device_type = DMX
string_type = RGB
```

and materializes their universe/channel topology through the current DMX-channel relations and the legacy-compatible wiring views.

For these Displays, the compatibility-view `Controller` value is a universe/addressing value, **not the physical AlphaPix/PixCon controller identity** the installer sees.

FieldWiring must therefore translate the current LOR/E1.31 topology into physical controller/network/output language instead of simply rendering the compatibility `Controller / StartChannel` columns.

---

## E1.31 Is a Separate Field Presentation Family

The accepted FieldWiring families now include:

```text
Traditional LOR
    -> conventional A/C controller / numbered output

LOR + RGB
    -> Pixie controller / numbered RGB output

DMX + DumbRGB
    -> DMX network / fixture hookup

DMX + RGB — reviewed dense RGB examples
    -> E1.31 network / intelligent pixel-controller hookup
```

The last two families both use `device_type = DMX` in the current parser model, but their physical hookup is not the same.

`string_type` is therefore important:

```text
device_type = DMX + string_type = DumbRGB
    -> DMX fixture/network presentation

device_type = DMX + string_type = RGB
    -> dense-pixel/E1.31 presentation for the reviewed MSB examples
```

Do not generalize every possible `DMX + RGB` Prop outside the reviewed MSB cases without confirming the physical design.

---

## Physical Field Model

Dense RGB Displays use intelligent pixel controllers connected to the E1.31 network.

The field operator should normally think in terms such as:

```text
Display / Display section
physical pixel controller
physical controller output/port
E1.31 network connection
```

Raw universe/channel ranges remain essential engineering/configuration data but should not be presented as though each universe were a separate physical controller.

The current controller inventory is still needed to supply permanent physical controller identities, controller models, and authoritative port/output mapping where those facts cannot be derived safely from reviewed current topology.

---

## Current Snapshot Evidence — Mega Tree and Mega Ball

The Master Musical Preview currently contains:

### Mega Tree

```text
lor_comment = TR-MegaTreeRGBTree
device_type = DMX
string_type = RGB
parm1 = 48
parm2 = 100
```

The current V7 DMX materialization exposes 48 universe rows:

```text
Universes 1 through 48
Start channel 1
End channel 300
```

Operator-confirmed physical hardware:

> the Mega Tree uses one 48-channel AlphaPix controller.

This is a strong example of why the compatibility `Controller` column must not be interpreted literally. The 48 universe values represent E1.31 addressing for one physical 48-output controller, not 48 physical controllers.

### Mega Ball

```text
lor_comment = TR-MegaTreeRGBBall
device_type = DMX
string_type = RGB
parm1 = 16
```

The current V7 DMX materialization exposes 16 universe rows:

```text
Universes 49 through 64
```

Operator-confirmed physical hardware:

> the Mega Ball uses one PixCon controller.

The current topology therefore preserves a clean boundary immediately after the Mega Tree universe block:

```text
Mega Tree -> 1-48
Mega Ball -> 49-64
```

The permanent controller labels/asset identities still come from Controller Inventory when that source becomes available.

---

## Mega Cube — Physical Controller Count Is Not Recoverable From the Generic Rows Alone

The current Master Musical Preview contains:

```text
lor_comment = WA-MegaCube
device_type = DMX
string_type = RGB
```

Operator-confirmed physical hardware:

> the Mega Cube uses three PixCon controllers.

The current V7 DMX materialization for the master Prop exposes four stored start-universe records at:

```text
65
73
93
101
```

with large channel spans.

The legacy-compatible field-lead view exposes those values as generic `Controller` rows.

That row shape does **not** directly identify the three physical PixCon controller boxes or their output-port mapping.

This is an important acceptance case:

> FieldWiring must not derive physical controller count by counting compatibility-view `Controller` rows for E1.31 Displays.

Controller Inventory/deployment data or another reviewed physical mapping is required to label the three actual controllers and their ports correctly.

---

## Mega Star

The current Master Musical Preview contains:

```text
lor_comment = FT-MegaStar
device_type = DMX
string_type = RGB
parm1 = 4
parm2 = 150
```

The current V7 DMX materialization exposes 28 universe rows spanning:

```text
113 through 140
```

The operator has identified Mega Star as another dense RGB Display on the E1.31 network.

The physical controller model/count and port grouping should remain pending until the current controller inventory or another accepted physical mapping is available. FieldWiring must not turn universe `113-140` into 28 apparent physical controllers.

---

## Mt. Crumpit Matrix

The current Master Musical Preview contains:

```text
lor_comment = WV-WhoMatrix
device_type = DMX
string_type = RGB
```

The current V7 DMX materialization contains large channel blocks beginning at universes:

```text
147
155
```

The operator has identified the Mt. Crumpit Matrix as another dense RGB Display on the E1.31 network.

As with Mega Cube, the current compatibility rows are addressing evidence, not sufficient physical-controller inventory. FieldWiring should preserve the universe information under Engineering Details while waiting for the physical controller/port mapping.

---

## What the Operator Should See

Where Controller Inventory supplies the physical relationship, the normal E1.31 field result should look conceptually like:

```text
Display: Mega Tree
Network: E1.31
Controller: <physical AlphaPix label>
Output: <physical port number>
Display section/string: <field-facing connection label>
```

or:

```text
Display: Mega Cube
Network: E1.31
Controller: <physical PixCon label>
Output: <physical port number>
Display section/string: <field-facing connection label>
```

Raw configuration values such as:

```text
universe
start channel
end channel
LOR compatibility Controller value
source/device metadata
```

belong under Engineering Details unless a specific troubleshooting workflow requires them in the main view.

---

## What Can Be Done Before Controller Inventory Is Available

FieldWiring development does not need to stop while the current controller inventory is delayed.

The current data is already sufficient to:

- classify reviewed `device_type = DMX` + `string_type = RGB` dense Displays into the E1.31 presentation family;
- avoid presenting universe numbers as physical controller identities;
- preserve current universe/channel topology for engineering details;
- use operator-confirmed physical hardware facts for acceptance prototypes; and
- expose where permanent physical-controller/output relationships are still missing.

The current accepted physical facts are:

```text
Mega Tree
    one 48-channel AlphaPix controller
    V7 universe block 1-48

Mega Ball
    one PixCon controller
    V7 universe block 49-64

Mega Cube
    three PixCon controllers
    current generic V7 row shape does not directly encode those three boxes

Mega Star
    E1.31 dense RGB
    physical controller grouping pending

Mt. Crumpit Matrix
    E1.31 dense RGB
    physical controller grouping pending
```

Do not invent permanent controller IDs or port assignments while the inventory source is unavailable.

---

## Relationship to DMX / DumbRGB

Northern Lights and the dense E1.31 Displays demonstrate why `device_type = DMX` cannot by itself select the field presentation.

```text
Northern Lights
    device_type = DMX
    string_type = DumbRGB
    field task = DMX-network fixture hookup

Mega Tree / Mega Ball / Mega Cube / Mega Star / Mt. Crumpit Matrix
    device_type = DMX
    string_type = RGB
    field task = E1.31 network + intelligent pixel-controller hookup
```

The shared compatibility view can remain useful for topology/parity testing, but FieldWiring must use the current Prop/SubProp metadata and physical-controller relationships to produce the normal operator view.

---

## Controller Inventory Requirements Exposed by E1.31

The future Controller Inventory/deployment model must be able to represent at least:

- permanent physical controller identity;
- controller family/model, including AlphaPix and PixCon where used;
- physical output/port count;
- current Stage/Scene/Display deployment;
- E1.31 network relationship;
- current universe/address ranges used by that controller/deployment; and
- physical output/port to Display/string/section mapping.

Universe number is not the physical-controller primary identity.

One Display may use multiple physical controllers, as demonstrated by Mega Cube.

One physical controller may serve many E1.31 universes, as demonstrated by the Mega Tree.

---

## Acceptance Requirements

At minimum, E1.31 FieldWiring testing must prove:

1. reviewed `device_type = DMX` + `string_type = RGB` dense Displays are not rendered as DMX/DumbRGB fixtures;
2. Mega Tree universe values `1-48` are not rendered as 48 physical controllers;
3. Mega Ball universe values `49-64` are not rendered as 16 physical controllers;
4. Mega Cube is capable of being presented as three physical PixCon controllers once the physical mapping is available, regardless of the generic compatibility row count;
5. Mega Star universe values `113-140` remain engineering addressing rather than physical-controller labels;
6. Mt. Crumpit Matrix universe blocks remain engineering addressing rather than physical-controller labels;
7. E1.31 network hookup is visible to the operator;
8. permanent controller labels/output ports are supplied from Controller Inventory when available rather than invented from universe values; and
9. no current LOR/E1.31 topology is rewritten merely to simplify the browser presentation.

---

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [Controller Inventory and Labeling Plan](../08_Controller_Inventory/Controller_Inventory_and_Labeling_Plan.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
