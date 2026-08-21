# FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21

| Item | Value |
|---|---|
| Status | ENGINEERING CONCLUSION — physical port mapping likely controller-local; direct controller configuration evidence still pending |
| Sub-project | FieldWiring |
| Schema status | No schema, parser, controller, or renderer change authorized by this conclusion |

## Purpose

This record preserves the current dense-RGB architecture conclusion reached after inspecting the Run 50 FieldWiring snapshot and the current live Master Musical Preview.

The investigation has established that Light-O-Rama Preview data contains substantial logical component/string and DMX/E1.31 addressing information, but the exact mapping from that addressing to physical AlphaPix/PixCon output ports has not been found in the Preview source inspected so far.

The current engineering conclusion is therefore that the final universe/addressing-to-physical-port relationship is likely configured inside the physical controller. This conclusion must remain distinguishable from direct controller-configuration evidence until an actual AlphaPix/PixCon configuration/export is inspected.

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

## Current Layering Conclusion

The architecture now appears to separate naturally into these layers:

```text
LOR / V7
    -> Display identity binding
    -> source component/string identity where authored
    -> custom pixel geometry where authored
    -> DMX/E1.31 universe/channel topology

physical AlphaPix / PixCon controller configuration
    -> E1.31 addressing accepted by the controller
    -> physical output/port assignment

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

For example, the fact that a logical block begins at Universe 147 does not by itself prove that it is connected to PixCon Output 1. Likewise, a contiguous range such as Universes 113-128 strongly supports a logical controller block but does not, without controller configuration evidence, prove the exact physical port numbering.

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

## Next Evidence

The next authoritative evidence, when available, should come from actual controller configuration for one or more of these devices.

The purpose of that inspection is to confirm:

- how E1.31 universe/address ranges are assigned to physical outputs/ports;
- whether output numbering follows universe order in the reviewed MSB configurations;
- how unused outputs are represented; and
- what current-state fields Controller Inventory needs to preserve so FieldWiring can later replace temporary controller-resolution rules with permanent `ctrl_id` mappings.

Until that evidence is inspected, the physical-port mapping remains unresolved rather than guessed.

## Related Documents

- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
