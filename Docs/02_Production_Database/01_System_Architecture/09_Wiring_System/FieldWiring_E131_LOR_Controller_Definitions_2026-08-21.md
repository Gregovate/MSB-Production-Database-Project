# FieldWiring E1.31 LOR Controller Definitions — 2026-08-21

| Item | Value |
|---|---|
| Status | OPERATOR-SUPPLIED CURRENT LOR CONFIGURATION EVIDENCE |
| Sub-project | FieldWiring |
| Source | Screenshots of LOR E1.31 (sACN) Controller setup plus direct Show-PC registry inspection and full read-only registry dump supplied 2026-08-21 |
| Scope | LOR-side universe-range to named-controller/IP routing |
| Schema status | No parser, PostgreSQL schema, Controller Inventory schema, or renderer change authorized by this finding |

## Purpose

This record captures the current LOR-side E1.31 controller definitions supplied during FieldWiring dense-RGB recovery.

These definitions establish the routing layer between Display/Prop `ChannelGrid` universe usage and the named E1.31 controller context to which LOR sends those universes.

They do **not** make IP address, universe number, or LOR controller name into permanent physical-controller identity.

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

## Show-PC Storage Location — Directly Verified 2026-08-21

The current LOR Network Preferences are **not stored as an XML/JSON file under `C:\LOR`** on the Show PC.

Direct inspection of the Show PC established that the active LOR network preferences are stored under the current Windows user's registry hive at:

```text
HKEY_CURRENT_USER\SOFTWARE\Light-O-Rama\Shared\NetworkF420399CE04C4EC08C7ED0A2C62A1051
```

The root records:

```text
Created = 2026-08-21T06:11:03.5050697-05:00
```

The Sequencer trace independently showed the startup sequence:

```text
LightORama.Sequencer.SeqRegistry
    SeqRegistry.ctor completed

LightORama.Sequencer.Form1
    FormBase.RegistryKey set

LightORama.OS.Windows.WinNetworkPrefLoader
    Reading network preferences

LightORama.DotNetShared.NetworkPreferences
    FinishUpdate LOR cnt=16, DMX cnt=165, enh=7FFE
```

The full read-only registry dump confirms that LOR stores one E1.31 record per DMX universe under subkeys such as:

```text
...\DMX1
...\DMX2
...
```

Representative active universe keys contain:

```text
Uses E131            REG_DWORD 0x1
Adapter              REG_SZ
Protocol             REG_DWORD 0x0
E131 IP Address      REG_SZ    <target IP>
E131 IP Address Type REG_DWORD 0x1
E131 Send To Port    REG_DWORD 0x15c0
AdjustArtNetUniv     REG_DWORD 0x0
Comment              REG_SZ    <controller/context comment>
```

`0x15c0` is decimal `5568`, matching the sACN port shown in the LOR UI.

The same routing values are repeated across every configured universe belonging to the same LOR controller context. A future read-only extractor can therefore preserve the raw per-universe records and derive contiguous controller routing ranges from repeated active values.

### Universes 109-112 — explicitly inactive

The registry dump resolves the previously unexplained gap between Mega Cube and Mega Star.

The `DMX109`, `DMX110`, `DMX111`, and `DMX112` keys each contain:

```text
Uses E131         REG_DWORD 0x0
E131 IP Address   REG_SZ    <blank>
E131 Send To Port REG_DWORD 0x0
Comment           REG_SZ    <blank>
```

Therefore Universes `109-112` are **not currently configured for E1.31** on the Show PC. FieldWiring must not invent a controller assignment for them.

### Registry comment precision

Registry `Comment` values are source configuration text and include spelling/spacing variants such as `Pixi-con` and `Pixi-Link`. They are useful evidence but are not permanent controller identity. Normal FieldWiring presentation may continue to use reviewed controller labels while preserving raw source text in engineering detail/provenance.

### Consequence for FieldWiring / future extraction

If MSB later chooses to capture LOR Network Configuration automatically, that extraction is a **separate Windows-registry source adapter**, not part of `.lorprev` XML parsing.

Conceptually:

```text
.lorprev parser
    -> Preview / Prop / ChannelGrid topology

Windows LOR Network Preferences adapter
    -> LOR network/controller routing configuration
    -> per-universe E1.31 target settings

Controller Inventory
    -> permanent ctrl_id / reviewed physical-controller state

FieldWiring
    -> consumes the resolved layers
```

This separation is intentional. A change to LOR Preview XML should not force the registry-network-preference extraction to change, and a change to Windows Network Preferences storage should not make the `.lorprev` parser fragile.

Registry data remains LOR-owned configuration evidence. MSB-owned wiring annotations such as `assembly_required_at_setup` remain separately managed by the Wiring system and preserved with approved wiring snapshots.

## Important Universe Observations

### Mega Tree

The LOR controller definition owns Universes `1-48`.

The current dense-RGB source inspection found 48 Mega Tree logical DMX legs at Universes `1-48`, so the Display topology and LOR controller definition align exactly at the universe-range level.

Separate Prop/channel authoring evidence also establishes the 48 controller-port/string rows used by the Mega Tree. That port-row evidence comes from the Prop/channel model; the registry evidence documented here supplies the E1.31 routing/target layer.

### Mega Tree Ball

The LOR controller definition owns Universes `49-64`.

The current source inspection found sixteen logical Mega Ball legs at Universes `49-64`. The LOR Display topology and the one-PixCon16 controller definition therefore align exactly at the 16-universe range level.

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

The registry dump additionally confirms that U109-U112 are inactive rather than merely undocumented.

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

Therefore the LOR routing configuration directly confirms the two-controller split:

```text
Mega Star controller context 1 -> U113-128
Mega Star controller context 2 -> U129-144
```

The current Preview uses U129-140 on controller context 2. Universes U141-144 are within that controller's configured range but are not represented by the current Mega Star Preview legs inspected. Do not invent physical hookup rows for that unused/reserved range.

Separate Prop/channel authoring evidence preserves the Mega Star component Names and component-local controller-port/string rows; those must not be flattened away.

### Northern Lights

Northern Lights is configured as a named `LOR PixieLink` E1.31 target for Universes `145-146`.

This supports the existing FieldWiring distinction that Northern Lights is not a normal dense-RGB PixCon/AlphaPix physical-output presentation family. The PixieLink is an E1.31 bridge/infrastructure context and must not be mislabeled as a PixCon16 pixel controller.

### Whoville / Mt Crumpet Matrix

The LOR controller definition `Mt Crumpet LOR Pixcon16 Controller` owns Universes `147-162`.

Raw Preview inspection of `WV-WhoMatrix` established two large logical blocks beginning at Universes `147` and `155`, with a complete 40 x 40 custom matrix topology. The controller definition confirms that both blocks route to one named PixCon16 controller context covering U147-162.

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

The evidence establishes separate current-state layers:

```text
LOR Prop / ChannelGrid
    -> Display/component/string universe/channel topology
    -> component-local controller-port/string authoring where represented

LOR Network Preferences / E1.31 controller configuration
    -> universe routing
    -> named controller context
    -> target IP / sACN port

physical controller state
    -> actual installed controller/network/configuration state
```

Controller Inventory adds permanent physical identity/current assignment without replacing the LOR-owned topology:

```text
Controller Inventory
    -> permanent ctrl_id
    -> exact model/capability
    -> current assignment to the LOR controller/addressing context
    -> reviewed current configuration facts
```

FieldWiring consumes the layers; it does not make IP address, universe number, or controller name into permanent physical identity.

## IP Authority Clarification

The supplied LOR screenshots and direct registry evidence establish current **LOR-configured target IPs** for the named definitions above.

They do not make IP address a permanent controller identifier.

They also do not, by themselves, prove physical installation/current assignment for every configured target. The Open/Close Sign is the explicit example: LOR has a configured target, but the physical installation is not yet complete.

The Controller Inventory current-state review remains the authority for permanent `ctrl_id` and reviewed physical assignment/configuration facts.

## Current Gaps

The current evidence does not yet establish:

- permanent `ctrl_id` values;
- serial/MAC/hardware identity;
- firmware state; or
- whether every configured universe within each controller range is currently used by a Display.

Those facts must be inventoried from the appropriate source rather than inferred.

## Related Documents

- [FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21](FieldWiring_Dense_RGB_Controller_Port_Mapping_Boundary_2026-08-21.md)
- [FieldWiring Dense RGB LOR Controller-Port Recovery — 2026-08-21](FieldWiring_Dense_RGB_LOR_Controller_Port_Recovery_2026-08-21.md)
- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [Controller Inventory E1.31 IP Current-State Correction — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_E131_IP_Current_State_Correction_2026-08-20.md)
