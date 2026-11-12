# Controller Inventory Grouping Acceptance Register

| Document control | Value |
|---|---|
| Status | CURRENT — update during active Pre-DDL grouping review |
| Scope | Physical controller grouping decisions and unresolved grouping questions |
| DDL authority | None by itself; evidence for later DDL review |
| Parent authority | [Controller Inventory Engineering Acceptance Baseline — 2026-08-29](Controller_Inventory_Engineering_Acceptance_Baseline_2026-08-29.md) |

## Purpose

This is the durable register for physical-controller grouping conclusions reached during the Pre-DDL Controller Inventory review.

The temporary spreadsheet is useful for assembling hypotheses, but an accepted grouping must not remain only in the spreadsheet or in chat.

As soon as a grouping materially affects later schema, seed, resolver, FieldWiring, labeling, or technician-workflow decisions, record its status here before later engineering depends on it.

## Evidence Rule

Current LOR/V7 wiring is authoritative for the electrical/show topology it represents.

Physical grouping is reconstructed from the combination of:

- current LOR wiring/address/output relationships;
- controller-family behavior;
- model/output capability evidence;
- Stage/Preview/Display context where it helps distinguish repeated addresses;
- physical/location evidence when available;
- operator/technician knowledge; and
- the temporary workbook grouping fields, including the deliberate `For What` grouping column.

The spreadsheet is not an independent source of truth against which LOR is graded. It is the current working attempt to assemble the physical grouping that best explains the LOR wiring before the complete physical inventory is presented.

## Acceptance States

### PROPOSED

Best current grouping hypothesis. No known contradiction, but engineering has not yet accepted it for durable bootstrap/schema use.

### ENGINEERING_ACCEPTED

The grouping fits the current LOR wiring, applicable controller-family semantics, and all currently known physical facts well enough to drive schema/relationship design and bootstrap planning.

This does not claim the physical hardware has already been inspected in the field.

### FIELD_VERIFICATION_REQUIRED

The available evidence cannot distinguish the physical grouping sufficiently. Preserve the ambiguity; do not manufacture certainty for DDL or bootstrap data.

### PHYSICALLY_VERIFIED

Later field/inventory inspection confirms the actual physical hardware/grouping.

### SUPERSEDED

A prior grouping or interpretation was replaced by better evidence. Preserve the reason for supersession when it matters to later engineering.

## Structural Grouping Decisions Already Accepted

These are architecture-level grouping facts rather than a complete controller inventory.

### Permanent identity is separate from grouping evidence

**Status:** ENGINEERING_ACCEPTED

One future PostgreSQL-generated `controller_id` represents one permanent physical managed device/controller. Network, UID/range, channel, IP, universe, Display, Stage, Scene, and workbook row are not permanent identity.

### Controller-to-Display is many-to-many

**Status:** ENGINEERING_ACCEPTED

The system must support both:

```text
one controller -> multiple Displays
one Display    -> multiple controllers
```

### Repeated LOR addresses may represent multiple physical controllers

**Status:** ENGINEERING_ACCEPTED

The same current Network + UID/range, and even the same channel pattern, may legitimately apply to separate physical controllers.

Known evidence includes HWY-42 conventional controllers and repeated Pixie Candy Cane groups.

Address reuse is not an error and must not be blocked by a physical-controller uniqueness constraint.

### One physical Pixie may span multiple UIDs

**Status:** ENGINEERING_ACCEPTED

Pixie physical grouping follows controller-family UID-block/output semantics rather than one-UID-equals-one-controller logic.

Unused positions in a physical Pixie range are valid.

### E1.31 physical grouping is not universe identity

**Status:** ENGINEERING_ACCEPTED

One physical E1.31 controller may span many universes. Universe and IP are mutable/current addressing facts, not permanent physical identity.

### LOR may be unable to distinguish physical copies

**Status:** ENGINEERING_ACCEPTED

When separate physical controllers are intentionally programmed identically, LOR may prove the common electrical command context without proving how many physical boxes exist.

In those cases the accepted physical split must come from reviewed grouping/field evidence rather than an invented address rule.

## Current Working Artifact Notes — 2026-08-29

Working artifacts supplied for the current fit test:

```text
Controller Inventory & Testing 2026(6).xlsx
lor_output_v7_scene(20260829-194137).db
```

The exact uploaded files are already known to lag two current corrections:

### Old HWY-42 Regular/08 workbook row

**Status:** SUPERSEDED

The old row using:

```text
HW-EventTrafficRight-01
Regular / UID 08
CTB32LG3
```

has been removed from the current working spreadsheet. Do not treat its presence in the uploaded `(6)` file as a current grouping conflict.

### Rotary Trees SPARE

**Status:** SUPERSEDED

The uploaded SQLite still contains older crossed SPARE evidence. Current LOR has corrected:

```text
42 10-09 SPARE
Regular / UID 10 / channel 9
```

Do not reopen that source correction from the older uploaded SQLite.

## Active Review Rule

For each material grouping reviewed from this point forward, add or update an entry here with:

```text
Grouping / physical context
Acceptance state
LOR/V7 evidence
Controller-family/model reasoning
Spreadsheet `For What` / grouping evidence when useful
Known physical evidence
Why accepted or why verification remains required
FieldWiring consequence if any
```

Do not try to document every raw LOR row here. LOR/V7 remains the wiring authority; this register records the physical-grouping conclusion that LOR alone cannot permanently own.

## Future Transition

Once PostgreSQL Controller Inventory is implemented and accepted, accepted physical identities/groupings become maintained Production Database facts through the controlled Controller Inventory workflow.

At that point this register remains engineering design/history evidence, while the spreadsheet becomes historical bootstrap evidence rather than an ongoing operational tool.
