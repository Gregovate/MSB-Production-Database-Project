# FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21

| Item | Value |
|---|---|
| Status | ENGINEERING CONCLUSION — vendor-confirmed controller-local configuration architecture; exact MSB controller port assignments still pending direct inspection |
| Sub-project | FieldWiring |
| Schema status | No schema, parser, controller, or renderer change authorized by this conclusion |

## Purpose

This record preserves the dense-RGB architecture conclusion reached after inspecting the Run 50 FieldWiring snapshot, the current live Master Musical Preview, and HolidayCoro AlphaPix product/support documentation.

The investigation has established that Light-O-Rama Preview data contains substantial logical component/string and DMX/E1.31 addressing information, while the exact mapping from that addressing to physical AlphaPix/PixCon output ports is configured at the controller layer rather than being represented as a physical-output field in the LOR Preview.

The vendor documentation confirms that AlphaPix controllers are configured by assigning incoming E1.31/DMX universe/channel data to physical SPI outputs through the controller configuration interface. The exact current MSB output assignments still require direct inspection of the applicable controllers or an authoritative configuration export/capture.

## Evidence From LOR Preview

The live Preview exposes useful logical topology, including examples such as:

- Mega Tree: 48 logical DMX legs for 48 ribbons;
- Mega Ball: 16 logical DMX legs;
- Mega Cube: three named source components (`Left`, `Front`, `Top`) with four large DMX address blocks;
- Whoville Matrix: a complete custom 40 x 40 pixel map with two large DMX address blocks; and
- Mega Star: ten named source components and 28 DMX legs.

The Preview has not exposed a field equivalent to:

```text
physical controller output / port number
```

for these dense-RGB Displays.

## Vendor Confirmation — AlphaPix Controller Configuration

The operator supplied the HolidayCoro AlphaPix 16 Classic V3 product page:

`https://www.holidaycoro.com/AlphaPix-16-Pixel-Controller-V3-p/721-v3.htm`

HolidayCoro's current AlphaPix product/support documentation confirms the architecture relevant to FieldWiring:

- the AlphaPix receives E1.31 / sACN data over Ethernet;
- the AlphaPix Classic 16 has 16 physical SPI pixel outputs;
- each Classic 16 SPI output can consume up to two DMX universes;
- controller settings are configured through the controller's web interface;
- the controller supports per-output configuration such as RGB color mapping, reverse DMX addressing, and zig-zag/matrix addressing;
- HolidayCoro's AlphaPix support procedure explicitly instructs the operator to determine which props/pixels are connected to each physical output and then configure the controller using the web interface; and
- HolidayCoro examples configure specific universe assignments for individual SPI outputs, demonstrating that universe-to-output association is controller configuration rather than a physical-port identity supplied by the sequencing Preview.

HolidayCoro reference pages inspected:

- AlphaPix Classic 16 V3 product page: `https://www.holidaycoro.com/AlphaPix-16-Pixel-Controller-V3-p/721-v3.htm`
- AlphaPix support page: `https://www.holidaycoro.com/kb_results.asp?ID=118`
- AlphaPix repeated-universe / SPI-output example: `https://www.holidaycoro.com/kb_results.asp?ID=150`

### 48-output AlphaPix/Flex relevance

The linked product is the 16-output AlphaPix Classic, not the 48-output hardware class used for the operator-confirmed Mega Tree and Mega Cube controller contexts.

HolidayCoro's Flex system documentation separately confirms a modular AlphaPix Evolution/HinksPix architecture supporting up to 48 SPI outputs through three 16-port expansion boards. HolidayCoro also documents that Flex physical outputs retain explicit output numbering, including output ranges such as 33-48 on the third expansion board.

Relevant HolidayCoro references:

- Flex 48-output controller: `https://www.holidaycoro.com/48-Output-Pixel-Ready2Run-Assembled-Controller-p/952-8.htm`
- Flex output numbering explanation: `https://www.holidaycoro.com/kb_results.asp?ID=207`

These vendor references confirm the same architectural boundary for the 48-output class: E1.31 data enters the controller, and the controller configuration determines which physical SPI output receives which addressing/data stream.

They do **not** prove the exact present-day MSB mapping for Mega Tree or Mega Cube. Those current assignments still require controller-specific inspection or an authoritative configuration capture.

## Current Layering Conclusion

The architecture separates naturally into these layers:

```text
LOR / V7
    -> Display identity binding
    -> source component/string identity where authored
    -> custom pixel geometry where authored
    -> DMX/E1.31 universe/channel topology

physical AlphaPix / PixCon controller configuration
    -> E1.31 universe/channel data accepted by the controller
    -> physical SPI output/port assignment
    -> controller-local output behavior/configuration

Controller Inventory current-state resolver
    -> permanent ctrl_id
    -> current assignment to the Display/addressing context
    -> exact model/capability
    -> current physical-port mapping when captured/available

FieldWiring
    -> joins the current LOR topology to the current physical controller/port context
    -> presents the resulting field hookup
```

## Important Boundary

FieldWiring must not infer permanent controller identity or physical output number solely from universe order.

For example, the fact that a logical block begins at Universe 147 does not by itself prove that it is connected to PixCon Output 1. Likewise, a contiguous range such as Universes 113-128 strongly supports a logical controller block but does not, without the applicable controller configuration, prove the exact physical port numbering.

Vendor documentation confirms that controllers can be configured with per-output universe/address behavior, so a convenient sequential universe pattern in LOR must not be silently promoted to a permanent physical-output rule.

## Parser / Read-Model Distinction

A separate issue exists for Mega Cube and Mega Star: the raw Preview contains useful component Names, but the current DMX parser/read model consolidates same-Display source rows onto one canonical master and therefore loses those component Names from normal FieldWiring rows.

That source-component preservation issue is distinct from the controller-port mapping issue documented here.

FieldWiring ultimately needs both:

```text
LOR source component/string context
        +
physical ctrl_id / controller port context
```

Neither layer should be forced to stand in for the other.

## Current Physical Controller Map

Operator-confirmed physical controller contexts remain:

```text
Mega Tree       -> 1 x 48-output AlphaPix
Mega Ball       -> 1 x PixCon16
Mega Cube       -> 1 x 48-output AlphaPix
Whoville Matrix -> 1 x PixCon16
Mega Star       -> 2 x PixCon16
```

These are accepted physical grouping facts. Exact permanent controller identities and current IP/controller configuration values remain part of the Controller Inventory/current configuration work.

## Controller Inventory Requirement Exposed

The Controller Inventory / FieldWiring return interface must eventually preserve enough current controller configuration to resolve:

```text
LOR universe/channel context
        -> permanent ctrl_id
        -> physical controller output/port
```

This does **not** require Controller Inventory to duplicate all LOR string/display topology. LOR/V7 continues to own the logical Display/component/addressing side.

Controller Inventory needs the current physical-controller assignment/configuration facts required to bridge from LOR addressing to the permanent physical controller and its output port.

This requirement is especially important for:

- one controller spanning many universes;
- one Display using multiple controllers;
- one controller serving multiple logical Display/component relationships; and
- configurations where universe order is not guaranteed to equal physical output order.

No PostgreSQL table/column design is authorized by this finding.

## Next Evidence

The next authoritative evidence, when practical, should come from actual controller configuration for one or more of these devices.

The purpose of that inspection is to capture:

- how E1.31 universe/address ranges are assigned to physical outputs/ports;
- whether output numbering follows universe order in the reviewed MSB configurations;
- how unused outputs are represented;
- whether the controller provides an export or other reusable configuration artifact; and
- what current-state fields Controller Inventory needs so FieldWiring can later replace temporary controller-resolution rules with permanent `ctrl_id` mappings.

Until an MSB controller configuration is inspected, the exact physical-port mapping remains unresolved rather than guessed.

## Related Documents

- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
