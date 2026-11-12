# Controller Inventory / FieldWiring Repeated-Address and Duplicated-Channel Cases — 2026-08-30

Status: ACCEPTED OPERATOR CLARIFICATION

## Purpose

This document records the specific physical cases that Controller Inventory and FieldWiring must support now that permanent controller identity has been created in PostgreSQL.

The governing rule is:

- `ref.controller.controller_id` is permanent physical controller identity.
- LOR/V7 remains authoritative for current wiring topology, Network, Unit ID/range, E1.31 universe/channel relationships, and whether a Display has wiring represented in the approved preview/snapshot.
- `ref.controller_display` is the Controller-owned physical relationship that distinguishes permanent controllers when LOR addressing is intentionally reused.
- Repeated Unit IDs/ranges are valid and must never be treated as duplicate physical identity.
- `wiring_source_display_id` is the explicit bridge for a physical Display/controller relationship that intentionally uses another Display's LOR wiring definition.

## Open / Close Signs — not an ambiguity case

There are two different physical Displays:

- the older LED Open/Close sign; and
- the new 2026 Matrix Open/Close sign.

The new Matrix is a separate Display and has a permanent Controller Inventory record, but it is not currently represented in any LOR Preview.

Therefore:

- Controller Inventory may show/manage the new Matrix and its controller;
- FieldWiring must not invent wiring for it;
- if no current approved LOR/V7 wiring rows exist for the Display, it must not appear as something to wire merely because Controller Inventory contains the asset.

## Highway 42 signs — repeated UID across five controllers

The Highway 42 signs use five different physical controllers that intentionally share the same UID.

Resolution rule:

- same UID is allowed;
- physical controller identity comes from `controller_id`;
- the controller-to-Display relationship distinguishes which physical sign/controller is being viewed;
- no uniqueness rule may be added on Network/UID that would collapse or reject these five controllers.

## Church RGB Candy Canes — two Pixie4D controllers with the same UID range

The Church has two groups of four Candy Canes.

Each group is served by its own physical Pixie4D controller, and the two controllers intentionally use the same programmed UID range.

Resolution rule:

- each Pixie4D remains a separate permanent controller;
- each controller is related to the four physical Candy Cane Displays it serves;
- repeated UID is valid and is not sufficient identity;
- FieldWiring resolves the controller from the physical Display/controller relationship and then renders the LOR wiring for those Displays.

## Candyland RGB Candy Canes — three Pixie4D controllers with the same UID range

Candyland has three groups of four Candy Canes.

Each group is served by its own physical Pixie4D controller, and all three controllers intentionally use the same programmed UID range.

Resolution rule is the same as Church:

- three permanent controller identities;
- four physical Candy Cane Displays associated with each controller;
- no UID uniqueness assumption;
- Controller Inventory supplies the physical grouping while LOR supplies the current wiring rows.

## Glistening Grove — duplicated-channel physical copies

Glistening Grove contains the following physical Display groups:

- 4 Eldon
- 4 Felix
- 4 Ralphie
- 4 Zuzu

For each group, only the first Display has the controller/channel definition represented directly in LOR. The remaining three physical copies intentionally duplicate the channels of the first.

There is also a V2 pattern:

- 2 Eldon V2
- 2 Felix V2
- 2 Ralphie V2
- 2 Zuzu V2

For each V2 pair, the first Display has the LOR controller/channel definition and the second intentionally duplicates that wiring.

Controller Inventory / FieldWiring must not try to infer separate wiring definitions for the duplicate copies from UID alone.

The intended representation is:

- `ref.controller_display.display_id` identifies the actual physical Display being managed/presented;
- when that Display's wiring is intentionally copied from another Display, `ref.controller_display.wiring_source_display_id` identifies the first Display whose current LOR wiring definition is authoritative for that copy;
- FieldWiring renders the source Display's current approved LOR wiring while keeping the permanent physical controller and physical Display identity of the copy.

This supports either one controller serving several physical Displays or several physical controllers using the same programmed wiring pattern without making UID the permanent identity. The actual permanent `controller_display` rows determine which physical-controller arrangement applies.

## Resulting FieldWiring resolver contract

FieldWiring does not need a second generalized Controller-to-LOR assignment table for these known cases.

For a physical Display/controller relationship:

1. start with `ref.controller_display` and the permanent `controller_id`;
2. use `display_id` as the physical Display relationship;
3. if `wiring_source_display_id` is NULL, use the Display's own current approved LOR/V7 wiring;
4. if `wiring_source_display_id` is populated, use that source Display's current approved LOR/V7 wiring while presenting the actual physical Display/controller relationship;
5. if the physical Display has no current LOR/V7 wiring and no reviewed wiring source, FieldWiring does not invent wiring.

This preserves the authority boundary:

```text
Controller Inventory = physical asset identity + physical Display relationship
LOR/V7               = current wiring topology
FieldWiring           = combines the two for the technician
```

## App implication

Controller Inventory should be implemented as a controlled maintenance module within the Wiring System, while the existing FieldWiring browser remains the operational wiring consumer.

Controller maintenance must support:

- controller search/detail;
- model, firmware verification state, status, location and notes;
- controller-to-Display assignment;
- optional `wiring_source_display_id` selection for duplicated-channel cases;
- label/scan management later;
- no editing of LOR wiring from Controller Inventory.

FieldWiring should consume these permanent relationships read-only.
