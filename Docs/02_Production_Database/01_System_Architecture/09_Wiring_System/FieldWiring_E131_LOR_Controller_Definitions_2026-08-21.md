# FieldWiring E1.31 LOR Controller Definitions — 2026-08-21

| Item | Value |
|---|---|
| Status | OPERATOR-SUPPLIED CURRENT LOR CONFIGURATION EVIDENCE |
| Sub-project | FieldWiring |
| Source | Screenshots of LOR E1.31 (sACN) Controller setup supplied 2026-08-21 |
| Scope | LOR-side universe-range to named-controller/IP routing |
| Schema status | No parser, PostgreSQL schema, Controller Inventory schema, or renderer change authorized by this finding |

## Purpose

This record captures the current LOR-side E1.31 controller definitions supplied during FieldWiring dense-RGB recovery.

These definitions establish the routing layer between Display/Prop `ChannelGrid` universe usage and the named E1.31 controller context to which LOR sends those universes.

They do **not** by themselves establish the controller's internal SPI-output mapping, permanent controller identity, or permanent IP-based identity.

## Current LOR E1.31 Definitions

| LOR controller name | Universe range | LOR target IP | Port | FieldWiring context |
|---|---:|---|---:|---|
| `Mega Tree Flex 48 SPI Output AlphaPix Controller` | 1-48 | `10.10.5.10` | 5568 | Mega Tree — HolidayCoro AlphaPix Flex 48-output system |
| `Mega Tree Ball LOR Pixcon16 Controller` | 49-64 | `10.10.5.11` | 5568 | Mega Tree Ball — PixCon16 |
| `Mega Cube Controller Flex 48 SPI Output AlphaPix Controller` | 65-108 | `10.10.5.12` | 5568 | Mega Cube — HolidayCoro AlphaPix Flex 48-output system |
| `Mega Star 1 LOR Pixcon16 Controller` | 113-128 | `10.10.5.15` | 5568 | Mega Star controller context 1 — PixCon16 |
| `Mega Star 2 LOR Pixcon16 Controller` | 129-144 | `10.10.5.16` | 5568 | Mega Star controller context 2 — PixCon16 |
| `Northern Lights LOR PixieLink` | 145-146 | `10.10.5.30` | 5568 | Northern Lights — PixieLink E1.31 bridge context |
| `Mt Crumpet LOR Pixcon16 Controller` | 147-162 | `10.10.5.17` | 5568 | `WV-WhoMatrix` / Whoville Matrix physical PixCon16 context |
| `Gift Conveyor LOR Pixcon16 Controller` | 163-167 | `10.10.5.18` | 5568 | Gift Conveyor — PixCon16 context |
| `Open/Close Sign LOR Pixcon16 Controller` | 168-169 | `10.10.5.19` | 5568 | Open/Close Sign — new 2026 definition; operator states not installed yet |

All supplied definitions use the standard sACN port `5568` and the LOR `Specify` IP mode.

## Important Universe Observations

### Mega Tree

The LOR controller definition owns Universes `1-48`.

The current dense-RGB source inspection found 48 Mega Tree logical DMX legs at Universes `1-48`, so the Display topology and LOR controller definition align exactly at the universe-range level.

This still does not prove that physical AlphaPix Flex Output 1 equals Universe 1, Output 2 equals Universe 2, etc. That exact SPI-output mapping remains controller-local configuration evidence.

### Mega Tree Ball

The LOR controller definition owns Universes `49-64`.

The current source inspection found sixteen logical Mega Ball legs at Universes `49-64`. The LOR Display topology and the one-PixCon16 controller definition therefore align exactly at the 16-universe range level.

Exact physical PixCon16 output order remains controller-local.

### Mega Cube

The LOR controller definition owns Universes `65-108`.

Raw Preview inspection established these current Mega Cube source blocks:

```text
Left  -> starts U65
Front -> starts U73
Top   -> starts U93 and U101
```

The controller definition proves that all of those current Mega Cube universe blocks route to one named HolidayCoro AlphaPix Flex 48-output system context.

The defined controller range extends through Universe 108. The source Preview inspection does not currently use every universe in the range; unused/reserved universe capacity must not be fabricated into Display wiring rows.

### Mega Star

The LOR controller definitions establish two distinct controller routing contexts:

```text
Mega Star 1 -> U113-128
Mega Star 2 -> U129-144
```

Raw Preview inspection found:

```text
Long Spires  -> U113-128
Short Spires -> U129-136
Center Hubs  -> U137-140
```

Therefore the LOR routing configuration directly confirms the candidate two-controller split that was previously only inferred from topology:

```text
Mega Star controller context 1 -> U113-128
Mega Star controller context 2 -> U129-144
```

The current Preview uses U129-140 on controller context 2. Universes U141-144 are within that controller's configured range but are not represented by the current Mega Star Preview legs inspected. Do not invent physical hookup rows for that unused/reserved range.

Exact physical PixCon16 output numbers within each controller context still require controller-local configuration evidence.

### Northern Lights

Northern Lights is configured as a named `LOR PixieLink` E1.31 target for Universes `145-146`.

This supports the existing FieldWiring distinction that Northern Lights is not a normal dense-RGB PixCon/AlphaPix physical-output presentation family. The PixieLink is an E1.31 bridge/infrastructure context and must not be mislabeled as a PixCon16 pixel controller.

### Whoville / Mt Crumpet Matrix

The LOR controller definition `Mt Crumpet LOR Pixcon16 Controller` owns Universes `147-162`.

Raw Preview inspection of `WV-WhoMatrix` established two large logical blocks beginning at Universes `147` and `155`, with a complete 40 x 40 custom matrix topology. The controller definition now confirms that both blocks route to one named PixCon16 controller context covering U147-162.

This materially strengthens the one-PixCon16 architecture finding while still leaving exact physical port numbers controller-local.

### Gift Conveyor

The supplied LOR configuration defines one PixCon16 controller context for Universes `163-167` at `10.10.5.18`.

No further Display/output interpretation is authorized by this finding alone. FieldWiring should use current LOR/V7 Display topology when that Display is accepted.

### Open/Close Sign

The supplied LOR configuration defines one PixCon16 controller context for Universes `168-169` at `10.10.5.19`.

Operator status:

```text
New for 2026
not installed yet
```

Therefore the LOR configuration exists, but FieldWiring / Controller Inventory must not represent the physical installation as completed until installation/current assignment is actually confirmed.

## Three-Layer E1.31 Architecture

The evidence now establishes three separate current-state layers:

```text
LOR Prop / ChannelGrid
    -> Display/component/string universe/channel topology

LOR E1.31 controller definition
    -> universe-range routing
    -> named controller context
    -> target IP / sACN port

physical controller configuration
    -> incoming universe/channel mapping to physical SPI outputs/ports
```

Controller Inventory adds permanent physical identity/current assignment without replacing the LOR-owned topology:

```text
Controller Inventory
    -> permanent ctrl_id
    -> exact model/capability
    -> current assignment to the LOR controller/addressing context
    -> reviewed current controller-local output mapping when captured
```

FieldWiring consumes the layers; it does not make IP address, universe number, or controller name into permanent physical identity.

## IP Authority Clarification

These screenshots are newer than previously documented stale/unverified E1.31 IP evidence and establish the current **LOR-configured target IPs** for the named definitions above.

They do not make IP address a permanent controller identifier.

They also do not, by themselves, prove physical installation/current assignment for every configured target. The Open/Close Sign is the explicit example: LOR has a configured target, but the physical installation is not yet complete.

The Controller Inventory current-state review remains the authority for permanent `ctrl_id` and reviewed physical assignment/configuration facts.

## Current Gaps

The supplied screenshots do not show:

- controller-local SPI physical output/port assignments;
- permanent `ctrl_id` values;
- serial/MAC/hardware identity;
- firmware state; or
- whether every configured universe within each controller range is currently used by a Display.

Those facts must come from the appropriate controller configuration / Controller Inventory evidence rather than being inferred.

## Related Documents

- [FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21](FieldWiring_Dense_RGB_Controller_Port_Mapping_Boundary_2026-08-21.md)
- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [Controller Inventory E1.31 IP Current-State Correction — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_E131_IP_Current_State_Correction_2026-08-20.md)
