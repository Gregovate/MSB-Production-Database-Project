# Controller Inventory Pre-DDL Design Details — 2026-08-29

| Document control | Value |
|---|---|
| Status | CURRENT PRE-DDL SUPPORTING DESIGN — subordinate to the Engineering Acceptance Baseline |
| Subsystem | Controller Inventory |
| Source salvaged from | `docs/controller-inventory-v1-review` |
| Salvage date | 2026-08-29 |
| PostgreSQL DDL | NOT AUTHORIZED by this document |
| Parent authority | [Controller Inventory Engineering Acceptance Baseline — 2026-08-29](Controller_Inventory_Engineering_Acceptance_Baseline_2026-08-29.md) |

## Purpose

This document preserves valid Controller Inventory design details that were still stranded on the stale `docs/controller-inventory-v1-review` branch after the current Engineering Acceptance Baseline and Grouping Acceptance Register were promoted to `main`.

It is intentionally narrower than the old V1 architecture draft. Only details that remain valid after the current FieldWiring, LOR, and Controller Inventory corrections are promoted here.

The stale branch is recovery evidence, not current engineering authority.

## Canonical Model / Revision Authority

A permanent physical controller row must reference a controlled canonical model/revision record rather than promoting free-text workbook spelling directly into production authority.

The current design direction remains conceptually:

```text
ref.controller_model
    controller_model_id
    manufacturer
    short canonical model / firmware-family code
    full model name
    hardware revision / generation when required
    device/controller family
    physical output/resource capability where applicable
    Display-assignment capability
    source / notes metadata
```

Exact hardware models remain distinct. In particular:

```text
PixCon16 != Pixie16
```

The working spreadsheet may continue to use compact model codes during Pre-DDL review. PostgreSQL must eventually preserve both the useful short canonical code and the manufacturer/revision detail required for safe firmware and capability decisions.

Unknown model/revision detail must remain unknown or verification-required rather than being guessed.

## Firmware Authority and Safety

Firmware compatibility is a controlled model relationship, not a free-text property copied from a spreadsheet.

Manufacturer information is the authority for which firmware versions apply to which model/revision. The production design must preserve multiple valid historical firmware versions rather than keeping only a single `latest firmware` value.

The design direction remains conceptually:

```text
ref.controller_firmware_version
    controller_firmware_version_id
    controller_model_id
    firmware_version
    manufacturer/source metadata
    publication/current metadata
```

The expected compatibility uniqueness is:

```text
UNIQUE(controller_model_id, firmware_version)
```

A physical controller references an installed firmware version only when known or verified. Unknown installed firmware remains null/unverified.

The database, not only the future UI, must prevent an incompatible model/firmware pairing.

Firmware history follows permanent `controller_id`. Repair and troubleshooting history remains in Work Orders.

## Capacity Validation

Controller capacity must not be validated by counting assigned Displays.

This is invalid:

```text
number of assigned Displays <= controller output count
```

Capacity must instead be evaluated from:

```text
exact model/revision capability
+
current LOR-derived occupied physical outputs/resources
+
controller-family-specific interpretation
```

For conventional A/C controllers, validation is based on distinct occupied physical outputs, not raw LOR row count. Multiple LOR relationships may legitimately describe one physical circuit/output.

For Pixie and E1.31 hardware, capacity follows the applicable UID-block, physical-port, universe/resource, and model-specific semantics.

## LOR-Derived Facts Remain Read Only

The Controller Inventory subsystem must not create editable competing copies of current LOR facts such as:

```text
Network
UID / UID range
start_channel / channel
LOR-derived physical output position
universe
Stage / Preview / Scene context
current Display wiring
SPARE / PHANTOM source state
```

Do not create independent editable Controller Inventory subsystems equivalent to:

```text
controller_uid
controller_channel
controller_network
controller_spare_channel
```

Current LOR/V7 remains the source for those facts.

### SPARE lifecycle

A physical controller remains the same permanent `controller_id` while individual LOR outputs change between SPARE and active Display use.

Controller Inventory therefore consumes current LOR output occupancy; it does not own a duplicate spare-channel inventory.

## Stage / Preview Context Boundary

Stage and Preview are resolution/context evidence, not controller identity and not a uniqueness constraint.

The same programmed address may exist on separate physical controllers in separate Stage/Preview/Display contexts. Therefore a global test such as:

```text
Network + UID exists somewhere
```

is insufficient for physical-controller reconciliation.

Current grouping/reconciliation may need Stage, Preview, Display, model, location, or `For What` evidence to distinguish physical boxes while permanent identity remains only `controller_id`.

One permanent Stage may also legitimately contain multiple LOR Previews. That multi-Preview behavior is owned by the current FieldWiring/Stage architecture and must not be converted into duplicate Controller Inventory Stage ownership.

## Glistening Grove `DeviceType=None` Boundary

The V1 review established a Controller Inventory limitation that remains important for future grouping and bootstrap work.

Current Glistening Grove evidence includes controller-bearing physical copies where:

- the wired `-01` representative carries the actual LOR Network/UID/channel wiring;
- physical replica rows may be `DeviceType=None` with no direct wiring of their own; and
- the inspected controller-bearing replicas had no usable `MasterPropId` relationship from which their wiring source could be derived automatically.

Therefore the system must not assume that every physical controller-bearing Display can be resolved directly from its own LOR address row.

For these reviewed replica cases, Controller Inventory needs a permanent, reviewed relationship to the applicable wiring-source `display_id` or equivalent durable physical relationship basis.

Do not infer that relationship from a name suffix such as `-02 -> -01` merely because the names look related.

Ordinary `DeviceType=None` objects remain outside Controller Inventory unless independent evidence establishes managed physical controller hardware.

## Technician Write Boundary

The future controlled Controller Inventory workflow may write Production Database-owned physical facts and reviewed physical relationships, including:

- canonical model/revision selection;
- compatible installed firmware selection;
- serial number when available;
- first-known-use information when supportable;
- controller/device status;
- notes;
- verification state;
- current physical controller-to-Display relationships; and
- reviewed confirmation that a permanent controller applies to a current LOR-derived address/context without editing the LOR address itself.

The future workflow must not allow technicians to edit LOR-derived Network, UID, channel, universe, Stage/Preview/Scene topology, or SPARE state through Controller Inventory.

The database permission/constraint boundary must enforce the same ownership rule as the UI.

## Inventory / Verification Workflow

Powered field verification is not required before a permanent physical `controller_id` can exist.

The intended bootstrap/review sequence remains:

```text
manufacturer/model evidence
    -> controlled model/firmware catalog

working physical/grouping evidence
    -> identify one real managed device per future controller_id

current LOR/V7 wiring
    -> authoritative current address/output relationships

unambiguous physical groupings
    -> engineering accept where evidence is sufficient

shared/reused-address or non-wired controller-bearing cases
    -> preserve reviewed physical grouping and require field verification where necessary

unknown powered-only facts
    -> remain null / verification-required
```

Later physical inventory work updates the existing permanent controller record rather than recreating controller identity in a spreadsheet.

## Repository / Application Boundary

The original V1 review reserved:

```text
/Controllers/
```

for future executable Controller Inventory application source, with engineering documentation under:

```text
Docs/02_Production_Database/01_System_Architecture/08_Controller_Inventory/
```

and operator/technician procedures under:

```text
Docs/02_Production_Database/02_Operational_SOPs/Controllers/
```

The exact future application route and implementation remain design details; this layout reservation does not authorize application implementation yet.

## Remaining DDL Review Decisions

Before final Controller Inventory migration DDL is accepted, engineering still needs to settle at least:

- exact table and column names for the broad managed-device scope;
- exact model/revision representation;
- exact controller/device status lookup values;
- firmware-history columns and compatibility enforcement;
- audit/actor columns and triggers following current Production Database standards;
- delete/retire behavior;
- role/permission boundaries for technician writes versus catalog administration;
- exact representation of any durable physical-controller-to-current-LOR-context confirmation relationship that proves necessary during the grouping fit test;
- how reviewed wiring-source relationships such as Glistening Grove are represented; and
- bootstrap/seed rules once the current grouping acceptance work is sufficiently complete.

These are implementation-detail gates. They do not reopen the accepted identity rule, many-to-many controller/Display relationship, repeated-address behavior, or LOR read-only authority boundary.

## Material Not Salvaged From the Old Branch

The following old-branch material is deliberately **not** promoted as current Controller Inventory authority:

- the obsolete proposal to split Rotary Trees and Traffic Signs into separate permanent Stages;
- the deleted `HW-EventTrafficRight-01 / Regular / UID 08` spreadsheet row as a current grouping issue;
- the crossed Rotary Trees SPARE definition already corrected in current LOR;
- pre-PR95 FieldWiring multi-Preview presentation defects that have since been fixed and production-accepted; and
- stale technician TODO items that were tied to those superseded findings.

The old branch may retain those items as historical recovery evidence, but current work must use `main` plus the accepted Controller Inventory baseline/register.

## Rule Established

> The Controller Inventory Pre-DDL design must preserve canonical model/firmware authority, family-specific capacity validation, read-only LOR-derived topology, explicit handling of controller-bearing objects that do not carry their own LOR wiring, and a technician write boundary limited to Production Database-owned physical facts. These details are subordinate to the current Engineering Acceptance Baseline and do not authorize DDL until the active grouping review is accepted.
