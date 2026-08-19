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

## Historical / Engineering Source Artifact — `DMX Control Addressing.xlsx`

A user-supplied workbook named:

```text
DMX Control Addressing.xlsx
```

was historically used to track E1.31/DMX universes, physical controller outputs, and IP addresses.

This workbook is valuable engineering evidence because it records the physical controller grouping that the generic LOR compatibility rows do not expose clearly.

It is **not** being declared the permanent Controller Inventory authority. The workbook contains multiple configuration eras, including columns such as `IP 2023`, `IP 2024`, `Original Config`, and `2023 Config`, so values must be treated as historical/configuration evidence until reconciled with the current physical inventory held separately.

The workbook currently records this E1.31 IP/controller map:

```text
Show PC
    10.10.5.5

Mega Tree
    10.10.5.10
    Alpha Pix / Flex48 Controller

Mega Ball
    10.10.5.11
    PixCon 16

Mega Cube Controller 1
    10.10.5.12
    PixCon 16

Mega Cube Controller 2
    10.10.5.13
    PixCon 16

Mega Cube Controller 3
    10.10.5.14
    PixCon 16

Mega Star Controller 1
    10.10.5.15
    PixCon 16

Mega Star Controller 2
    10.10.5.16
    PixCon 16

Mt. Crumpit
    10.10.5.17
    PixCon 16

Northern Lights / PixieLink
    10.10.5.30
```

The Northern Lights entry is network-infrastructure evidence only. Northern Lights remains the DMX/DumbRGB presentation family rather than the dense E1.31 RGB controller family.

### Why this workbook matters to FieldWiring

The workbook demonstrates that the physical controller grouping was already tracked outside LOR using three kinds of information together:

```text
physical controller / controller output
IP address
universe/channel assignment
```

That is close to the enrichment FieldWiring ultimately needs from Controller Inventory and Network Infrastructure.

The workbook should therefore be retained as a source artifact for later reconciliation rather than manually transcribed into a new schema without review.

---

## Mega Tree and Mega Ball

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

> the Mega Tree uses one 48-output AlphaPix controller.

The addressing workbook agrees with that physical model. Its Mega Tree sheet maps AlphaPix Outputs 1 through 48 to Universes 1 through 48.

The workbook also records configuration-history columns from prior controller/IP arrangements. Those historical columns must not be confused with the current permanent controller identity.

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

> the Mega Ball uses one PixCon 16 controller.

The workbook agrees and maps physical controller Outputs 1 through 16 to Universes 49 through 64.

The current topology therefore preserves a clean boundary immediately after the Mega Tree universe block:

```text
Mega Tree -> 1-48
Mega Ball -> 49-64
```

The permanent controller labels/asset identities still come from Controller Inventory when that source becomes available.

---

## Mega Cube — Three Physical PixCon Controllers Confirmed by Addressing Workbook

The current Master Musical Preview contains:

```text
lor_comment = WA-MegaCube
device_type = DMX
string_type = RGB
```

Operator-confirmed physical hardware:

> the Mega Cube uses three PixCon controllers.

The addressing workbook independently records three PixCon 16 controller IPs:

```text
Controller 1 -> 10.10.5.12
Controller 2 -> 10.10.5.13
Controller 3 -> 10.10.5.14
```

and maps physical PixCon outputs to the Mega Cube row/top sections and universe ranges.

The current V7 DMX materialization for the master Prop exposes generic start-universe records at:

```text
65
73
93
101
```

with large channel spans.

The legacy-compatible field-lead view exposes those values as generic `Controller` rows, but that row shape does **not** directly identify the three physical PixCon controller boxes.

This is now a stronger acceptance case:

> FieldWiring must not derive physical controller count by counting compatibility-view `Controller` rows for E1.31 Displays.

The workbook provides useful physical grouping evidence until the permanent Controller Inventory source is available.

---

## Mega Star — Two PixCon 16 Controllers

The current Master Musical Preview contains:

```text
lor_comment = FT-MegaStar
device_type = DMX
string_type = RGB
parm1 = 4
parm2 = 150
```

The current V7 DMX materialization exposes active universe rows spanning:

```text
113 through 140
```

The addressing workbook records two physical PixCon 16 controllers:

```text
Mega Star Controller 1 -> 10.10.5.15
Mega Star Controller 2 -> 10.10.5.16
```

Its Mega Star sheet maps:

```text
Controller 1 outputs 1-16 -> Universes 113-128
Controller 2 outputs 1-12 -> Universes 129-140
```

and shows controller outputs 13-16 / Universes 141-144 without current Display-section labels in that historical configuration sheet.

For FieldWiring, Universes 113-140 are addressing details. The operator-facing result should use the two physical controller contexts and physical outputs when that mapping is accepted/current.

---

## Mt. Crumpit Matrix — One PixCon 16 Controller in the Addressing Workbook

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

The addressing workbook provides the missing physical interpretation:

```text
Mt. Crumpit
    PixCon 16
    IP 10.10.5.17
    Outputs 1-16
    Universes 147-162
```

Therefore the generic compatibility rows must not be interpreted as multiple physical controllers. The workbook indicates one physical PixCon 16 controller spanning that universe range.

This remains historical/configuration evidence until reconciled with the current Controller Inventory, but it is strong enough to use as an engineering acceptance example.

---

## What the Operator Should See

Where the physical relationship is accepted/current, the normal E1.31 field result should look conceptually like:

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
IP address
```

belong under Engineering Details unless a specific field or troubleshooting workflow requires them in the main view.

---

## What Can Be Done Before Controller Inventory Is Available

FieldWiring development does not need to stop while the current controller inventory is delayed.

The current V7 topology plus the addressing workbook are already sufficient to:

- classify reviewed `device_type = DMX` + `string_type = RGB` dense Displays into the E1.31 presentation family;
- avoid presenting universe numbers as physical controller identities;
- preserve current universe/channel topology for engineering details;
- use operator-confirmed and workbook-supported physical hardware facts for acceptance prototypes; and
- expose where permanent physical-controller identity still remains missing.

The current accepted physical facts/evidence are:

```text
Mega Tree
    one 48-output AlphaPix / Flex48 controller
    IP evidence: 10.10.5.10
    V7 universe block 1-48

Mega Ball
    one PixCon 16
    IP evidence: 10.10.5.11
    V7 universe block 49-64

Mega Cube
    three PixCon 16 controllers
    IP evidence: 10.10.5.12 / .13 / .14
    generic V7 row shape does not directly encode those three boxes

Mega Star
    two PixCon 16 controllers
    IP evidence: 10.10.5.15 / .16
    active V7 universe block 113-140

Mt. Crumpit Matrix
    one PixCon 16 in the addressing workbook
    IP evidence: 10.10.5.17
    workbook universe/output map 147-162
```

Do not invent permanent controller IDs while the actual Controller Inventory source is unavailable.

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

The addressing workbook includes a Northern Lights/PixieLink IP record, but that is a network-device record and does not convert Northern Lights into the dense E1.31 RGB presentation family.

The shared compatibility view can remain useful for topology/parity testing, but FieldWiring must use current Prop/SubProp metadata plus accepted physical-controller evidence to produce the normal operator view.

---

## Controller Inventory Requirements Exposed by E1.31

The future Controller Inventory/deployment model must be able to represent at least:

- permanent physical controller identity;
- controller family/model, including AlphaPix and PixCon where used;
- physical output/port count;
- current Stage/Scene/Display deployment;
- E1.31 network relationship;
- current controller-management IP address where operationally required;
- current universe/address ranges used by that controller/deployment; and
- physical output/port to Display/string/section mapping.

Universe number is not the physical-controller primary identity.

IP address is also not the permanent controller identity; it is deployment/configuration data that may change.

One Display may use multiple physical controllers, as demonstrated by Mega Cube and Mega Star.

One physical controller may serve many E1.31 universes, as demonstrated by Mega Tree.

The historical addressing workbook should be compared with the current Controller Inventory source when that source becomes available rather than treated as a replacement for it.

---

## Acceptance Requirements

At minimum, E1.31 FieldWiring testing must prove:

1. reviewed `device_type = DMX` + `string_type = RGB` dense Displays are not rendered as DMX/DumbRGB fixtures;
2. Mega Tree universe values `1-48` are not rendered as 48 physical controllers and may be presented as one AlphaPix 48-output context when the workbook/physical mapping is accepted;
3. Mega Ball universe values `49-64` are not rendered as 16 physical controllers and may be presented as one PixCon 16 context;
4. Mega Cube can be presented as three physical PixCon controllers using accepted physical mapping rather than generic compatibility row count;
5. Mega Star can be presented as two physical PixCon 16 controller contexts, with active outputs/universes mapped according to the accepted current configuration;
6. Mt. Crumpit Matrix can be presented as one PixCon 16 context when the workbook mapping is confirmed current;
7. E1.31 network hookup is visible to the operator;
8. raw universe/channel/IP information remains available for engineering/troubleshooting without becoming the primary field instruction;
9. permanent controller labels/output ports are supplied from Controller Inventory when available rather than invented from universe or IP values; and
10. no current LOR/E1.31 topology is rewritten merely to simplify the browser presentation.

---

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [Controller Inventory and Labeling Plan](../08_Controller_Inventory/Controller_Inventory_and_Labeling_Plan.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
