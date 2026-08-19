# FieldWiring Field Presentation Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction |
| Sub-project | FieldWiring |
| Predecessor reference | FormView 0.3.1 Wiring View |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

This document records the field-facing presentation requirements for the browser-based FieldWiring application.

The requirements are derived from FormView, current V7/PostgreSQL data, and operator review of the actual physical hookup tasks performed during setup.

FieldWiring must preserve LOR-authoritative topology while translating technical addressing into the physical language the installer sees in the park.

---

## Field Objective

The normal FieldWiring screen should answer:

> What physical connection does this Display require, and what information does the installer need to make that connection correctly?

That answer is not identical for every controller/device family.

Current accepted presentation families are:

```text
Traditional LOR
    -> conventional A/C controller / numbered-output hookup

RGB LOR
    -> Pixie controller / numbered RGB-output hookup

DMX + DumbRGB
    -> DMX network / fixture hookup
```

FieldWiring must not force all three into one generic `Controller / Channel` interpretation merely because the compatibility wiring view uses those column names.

---

## Wiring Data Is the Primary Field Product

The authoritative result is the current V7/PostgreSQL wiring/topology set for the resolved Stage/Sub-stage/Scene and selected Background/Static or Musical context.

A wiring image is supplemental rough-location guidance only.

Therefore:

- missing imagery must never suppress otherwise valid hookup data;
- a valid field result may have no image;
- the browser should state `NO WIRING IMAGE AVAILABLE` when appropriate;
- a same-scope `PreviewBackground` may be shown as context only; and
- FieldWiring must not borrow a parent Stage wiring image for a resolved Scene/Sub-stage.

Conceptually:

```text
FIELD WIRING RESULT
    current hookup data    REQUIRED / PRIMARY
    published wiring image OPTIONAL
    context image          OPTIONAL
```

---

## Presentation Family Comes Before Column Labels

FieldWiring must inspect current Prop/SubProp/device metadata before deciding what the normal operator columns mean.

### Traditional LOR / A/C

For a conventional A/C controller, the physical output is one-to-one with the LOR channel/output number.

Normal field concepts are approximately:

```text
Controller
Output
Channel Name
Display
Network
```

`StartChannel` may be presented as **Output** for this family.

The hexadecimal LOR Unit ID is engineering/configuration information and should not be emphasized when a permanent physical controller label becomes available.

### RGB / Pixie

For `string_type = RGB`, raw Unit IDs may represent logical pixel-output addressing rather than separate physical controllers.

The normal field result should emphasize:

```text
Physical Pixie / accepted temporary group
Output / pigtail number
Display
Channel Name when useful
Network
```

The mapping rules are defined in [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md).

### DMX + DumbRGB

For current `device_type = DMX` and `string_type = DumbRGB` cases, generic `Controller` and `StartChannel` values may represent DMX universe/channel addressing rather than numbered physical hookup plugs.

The normal field result should emphasize the fixture/Display and DMX-network hookup rather than pretending the raw universe/channel is an A/C or Pixie controller/output pair.

The initial acceptance case is `16-Northern Lights-NL` and is defined in [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md).

---

## FormView Controls to Preserve Functionally

FormView provides three useful independent wiring controls:

- **Field Wiring** — reduced practical FIELD connection set versus fuller wiring map;
- **Displays Only** — optional master Display/`PROP` restriction; and
- **Hide SPAREs** — suppress intentionally unused spare rows.

FieldWiring does not need to reproduce the Tkinter controls literally, but equivalent behavior must remain available where applicable.

### Field Wiring checked versus unchecked

**Field Wiring OFF** presents the fuller engineering wiring map.

**Field Wiring ON** presents the reduced practical field-connection set.

A valid field row may originate from either a master Prop or a SubProp. Therefore Field Wiring must not be implemented as `Source = 'PROP'`.

A valid field connection can legitimately have:

```text
Source = SUBPROP
ConnectionType = FIELD
```

The reduced FIELD view remains the default field-installation mode, but its operator rendering is device-family aware.

---

## Core Human-Facing Information

Across the supported presentation families, the operator normally needs some combination of:

```text
Display / Fixture
physical controller identity or temporary group when applicable
physical Output / Plug when applicable
Channel Name when useful for field identification
Network / connection type
```

Raw engineering fields remain available but are not automatically normal operator columns.

---

## Display Name

Display Name is the physical Display identity/name and should be prominent.

It does not need to repeat on every row when consecutive rows belong to the same Display. The UI may group rows under one Display heading while retaining complete underlying data.

Grouping is presentation only and must not alter wiring identity or collapse shared relationships.

---

## Controller / Output Terminology

The browser should prefer **Output** or **Plug** when referring to the numbered physical connector the installer sees.

Do not assume the raw compatibility-view `Controller` field always means a physical controller:

```text
Traditional LOR
    raw controller/unit information can closely represent controller addressing

Pixie RGB
    raw Unit IDs can represent logical output addressing within one physical Pixie

DMX/DumbRGB
    raw Controller value can represent DMX universe addressing
```

The normal UI must translate rather than merely rename the raw columns.

---

## Network

Network remains useful field information, but its meaning must be presentation-family aware.

LOR network aliases such as `Regular`, `Aux A`, `Aux N`, and similar values are retained as technical topology data.

For DMX/DumbRGB, the physical field terminology for the DMX network/cable must be confirmed before automatically substituting a friendly label for the raw LOR network alias.

---

## Source Classification

Source is useful engineering metadata but should not consume a wide normal column.

Useful concepts include:

- Display/master Prop;
- SubProp;
- DMX source; and
- Spare when SPAREs are shown.

The browser may use a narrow badge/marker or Engineering Details rather than a full-width Source column.

When Hide SPAREs is enabled, Spare rows disappear entirely.

---

## ConnectionType / DeviceType / LORTag

These fields remain important for interpretation and troubleshooting but should not consume permanent horizontal space in the normal field view.

### ConnectionType

- hidden from the normal compact table;
- used by the Field Wiring reduction logic; and
- available under Engineering Details/export.

### DeviceType

DeviceType is normally hidden, but FieldWiring may use it internally to choose the presentation family. In particular, `device_type = DMX` is significant for DMX/DumbRGB handling.

### LORTag

LORTag remains optional programming/engineering information and is hidden by default.

---

## Recommended Operator Layouts

### Traditional A/C example

```text
Display: <Display Name>
Controller | Output | Channel Name | Network
```

### Pixie example

```text
Display / Pixie group
Output | Display / connection | Network
```

Raw Unit ID/address is available under Engineering Details.

### DMX/DumbRGB example

```text
Display / Fixture
Connection: DMX network
```

Raw DMX universe/channel information is available under Engineering Details unless a later field workflow proves it belongs in the normal view.

The UI does not need to use one identical table for all device families.

---

## Compact Display Grouping

Where a table is appropriate, Display grouping is preferred to avoid repeating the largest label on every row.

For conventional/Pixie hookups, the group may be arranged by physical controller/output when that relationship is known.

Shared-circuit or repeated-address relationships must remain visible and must not be deduplicated merely because technical addresses repeat.

---

## Image / Context Presentation

The image area is secondary to the hookup information.

```text
Published same-scope wiring image exists
    -> show as supplemental field guidance

No published wiring image
    -> show NO WIRING IMAGE AVAILABLE
    -> optionally show same-scope PreviewBackground as context

No image at all
    -> hookup data remains usable
```

On phone/tablet layouts, a large image must not push the primary hookup information off-screen.

---

## Sorting

Sorting must follow the physical presentation model rather than blindly sorting raw technical addresses.

Traditional A/C normally sorts by physical controller then Output.

Pixie results normally sort by physical/temporary Pixie group then Output.

DMX/DumbRGB may sort by fixture/Display unless a reviewed field workflow establishes a more useful physical chain order.

Raw hexadecimal-aware address sorting remains available in Engineering Details.

---

## Phone and Tablet Real-Estate Rule

On narrow screens:

- Display/Fixture identity remains prominent;
- physical Output/Plug remains immediately visible when applicable;
- Channel Name receives space when it is useful to field hookup;
- engineering-only fields move to optional details;
- images are collapsible or placed after primary hookup information; and
- DMX/DumbRGB results are not forced into wide controller/channel tables when the physical task is simply a network connection.

---

## Printing / Hard Reports

Hard reports should reproduce the same physical hookup interpretation shown on screen.

A Traditional/Pixie report may emphasize:

```text
Display
physical controller/group
Output
Channel Name
Network
```

A DMX/DumbRGB report may instead emphasize:

```text
Display / Fixture
DMX network connection
```

with raw universe/channel information in a technical appendix/details section if needed.

A missing image does not prevent a valid report from being generated.

Every hard report remains subject to the FieldWiring expiration/currentness contract.

---

## Acceptance Examples

FieldWiring presentation testing must include at minimum:

1. Field Wiring OFF, confirming the fuller engineering map remains available;
2. Field Wiring ON, confirming the reduced practical connection set;
3. conventional A/C output 1-16 presentation;
4. Pixie 16 Tree output 1-16 presentation;
5. Pixie 2 and Pixie 4 examples;
6. repeated Pixie address blocks without collapsing physical controllers;
7. shared circuits and repeated technical addresses without data loss;
8. Hide SPAREs behavior;
9. Displays Only behavior distinct from Field Wiring;
10. `16-Northern Lights-NL`, proving DMX/DumbRGB is not rendered as physical controller `145/146` with numbered plugs;
11. narrow phone/tablet layout;
12. printable/hard report using the applicable presentation family;
13. Engineering Details exposing raw Source, ConnectionType, DeviceType, LORTag, Unit ID, DMX universe/channel, and other technical addressing as applicable;
14. a resolved wiring scope with no image, proving the primary field result remains usable; and
15. a same-scope PreviewBackground shown only as clearly labeled context.

---

## Related Documents

- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [Wiring System](README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
