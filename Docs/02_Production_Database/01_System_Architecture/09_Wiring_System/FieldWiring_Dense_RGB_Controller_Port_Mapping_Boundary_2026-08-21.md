# FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21

| Item | Value |
|---|---|
| Status | ENGINEERING CONCLUSION — LOR controller routing confirmed; MSB AlphaPix Flex 48 output programming is controller-local and not retrievable by FieldWiring |
| Sub-project | FieldWiring |
| Schema status | No schema, parser, controller, or renderer change authorized by this conclusion |

## Purpose

This record preserves the dense-RGB architecture conclusion reached after inspecting the Run 50 FieldWiring snapshot, the current live Master Musical Preview, the current LOR E1.31 Network Configuration, vendor documentation, and operator-confirmed behavior of the two MSB AlphaPix Flex 48 systems.

The investigation has established that Light-O-Rama contains substantial logical component/string and DMX/E1.31 addressing information. LOR Network Configuration additionally defines which universe range is sent to each named E1.31 controller/IP target.

The final internal relationship between that incoming E1.31 data and the physical SPI outputs is controller-local.

For the two MSB AlphaPix Flex 48 systems specifically, the operator confirmed that the units are programmed physically inside the controller. FieldWiring cannot retrieve or inspect an internal output configuration from them. They receive the output sent by LOR Network Configuration.

Therefore FieldWiring must **not wait for an AlphaPix Flex 48 web configuration/export that is not available in the MSB installation**.

## Confirmed Architecture Layers

```text
LOR Preview / V7
    -> Display identity binding
    -> source component/string identity where authored
    -> custom pixel geometry where authored
    -> DMX/E1.31 universe/channel topology

LOR Network Configuration
    -> named E1.31 controller context
    -> universe range routed to that controller
    -> configured target IP / port

physical controller
    -> receives the assigned E1.31 data
    -> controller-local programming determines physical SPI output behavior

Controller Inventory
    -> permanent ctrl_id
    -> exact model/capability
    -> current Display/controller assignment
    -> reviewed current configuration facts that are actually obtainable

FieldWiring
    -> joins LOR topology to the known current physical controller context
    -> presents only physical-output facts that are supported by available evidence
```

## Evidence From LOR Preview

The live Preview exposes useful logical topology, including:

- Mega Tree: 48 logical DMX legs for 48 ribbons;
- Mega Ball: 16 logical DMX legs;
- Mega Cube: three named source components (`Left`, `Front`, `Top`) with four large DMX address blocks;
- Whoville Matrix: a complete custom 40 x 40 pixel map with two large DMX address blocks; and
- Mega Star: ten named source components and 28 DMX legs.

The Preview does not expose a generic dense-RGB field equivalent to:

```text
physical controller output / port number
```

for the cases inspected.

## Evidence From Current LOR E1.31 Network Configuration

Operator-supplied current LOR configuration screenshots establish the following routing contexts:

```text
Mega Tree Flex 48              U1-U48     -> 10.10.5.10
Mega Tree Ball PixCon16        U49-U64    -> 10.10.5.11
Mega Cube Flex 48              U65-U108   -> 10.10.5.12
Mega Star 1 PixCon16           U113-U128  -> 10.10.5.15
Mega Star 2 PixCon16           U129-U144  -> 10.10.5.16
Northern Lights PixieLink      U145-U146  -> 10.10.5.30
Mt Crumpit / Whoville PixCon16 U147-U162  -> 10.10.5.17
Gift Conveyor PixCon16         U163-U167  -> 10.10.5.18
Open/Close Sign PixCon16       U168-U169  -> 10.10.5.19
```

The Open/Close Sign controller definition is new for 2026 and is not yet installed.

These values are current LOR routing configuration evidence. IP address remains mutable configuration data, not permanent controller identity.

No controller definition supplied in this evidence covers Universes 109-112. Do not invent a use for that range.

## AlphaPix Flex 48 — MSB-Specific Boundary

The two confirmed 48-output systems are:

```text
Mega Tree -> 1 HolidayCoro AlphaPix Flex 48-output system
Mega Cube -> 1 HolidayCoro AlphaPix Flex 48-output system
```

Operator confirmation for the installed MSB systems:

- programming is performed physically inside the controller;
- FieldWiring cannot retrieve an internal output mapping from those units;
- there is no AlphaPix Flex 48 configuration export that FieldWiring should wait for in this recovery work; and
- the units receive the E1.31 output defined by LOR Network Configuration.

This supersedes the earlier recovery assumption that the next required evidence for Mega Tree/Mega Cube should be a controller web/output-configuration capture.

### Mega Tree

Current LOR topology provides 48 logical DMX legs at Universes 1-48, and operator-confirmed physical design provides 48 ribbons on one AlphaPix Flex 48 controller with one physical controller output per ribbon.

That is enough to establish the controller grouping and logical field topology. FieldWiring must not fabricate an exact `Universe N = physical Output N` rule unless that relationship is separately known and accepted.

### Mega Cube

Current LOR source provides:

```text
Left  -> block beginning U65
Front -> block beginning U73
Top   -> blocks beginning U93 and U101
```

LOR Network Configuration routes U65-U108 to the one Mega Cube AlphaPix Flex 48 system.

The physical controller has 48-output capability, but the exact internal output assignment is not retrievable from the installed unit. FieldWiring should present the known component/addressing/controller context without inventing unavailable port numbers.

## PixCon16 Boundary

The operator confirmation above applies specifically to the two AlphaPix Flex 48 systems.

The current physical PixCon16 contexts remain:

```text
Mega Ball       -> 1 PixCon16
Whoville Matrix -> 1 PixCon16
Mega Star       -> 2 PixCon16
Gift Conveyor   -> PixCon16 controller context in current LOR Network Configuration
Open/Close Sign -> PixCon16 controller context; new 2026, not yet installed
```

Where exact PixCon16 output-port mappings are unavailable, FieldWiring must likewise leave them unresolved rather than deriving them solely from universe order.

A future obtainable PixCon configuration may enrich FieldWiring, but it is not a prerequisite for completing the AlphaPix Flex 48 recovery path.

## Parser / Read-Model Distinction

A separate issue exists for Mega Cube and Mega Star: the raw Preview contains useful component Names, but the current DMX parser/read model consolidates same-Display source rows onto one canonical master and therefore loses those component Names from normal FieldWiring rows.

Examples of useful source names currently flattened include:

```text
MC Mega Cube Front
MC Mega Cube Top
MS Long Spire 2 4x150
MS Short Spire 3 2x150
MS Center Hub Back
```

That source-component preservation issue is independent of whether the exact physical controller port number can be retrieved.

FieldWiring needs to preserve the LOR source component/string context even when physical port mapping remains unavailable.

## Controller Inventory Requirement

Controller Inventory must not be designed around the assumption that every controller exposes a retrievable per-port configuration artifact.

For the AlphaPix Flex 48 systems, Controller Inventory should preserve facts that can actually be reviewed and maintained, including:

- permanent `ctrl_id`;
- exact controller family/model/capability;
- current assignment to Mega Tree or Mega Cube;
- current LOR E1.31 controller/range context where useful;
- mutable management/network configuration where operationally useful; and
- any reviewed physical-output information that can be established independently.

It should not manufacture a detailed per-port map merely to satisfy a database model.

LOR/V7 continues to own current Display/component/universe topology.

## FieldWiring Consequence

Dense-RGB completion should now proceed without waiting for unavailable AlphaPix Flex 48 internals.

For Mega Tree and Mega Cube, FieldWiring can safely use:

```text
current LOR component/string topology
        +
current LOR E1.31 controller routing
        +
operator-confirmed physical controller model/grouping
```

and explicitly omit exact physical port numbering where it has not been independently established.

The immediate remaining engineering problem is therefore the parser/read-model loss of raw DMX source-component identity, not AlphaPix controller access.

## Related Documents

- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
