# FieldWiring / Controller Inventory Cross-Link — 2026-08-31

| Item | Value |
|---|---|
| Status | CURRENT IMPLEMENTATION |
| Issue | #110 |
| Permanent Controller identity | `ref.controller.controller_id` |
| Physical assignment authority | `ref.controller_display` |
| Wiring topology authority | Current LOR / V7 |

## Operator requirement

A technician reading FieldWiring must be able to identify the permanent physical Controller asset that corresponds to the hookup context and open that Controller directly in Controller Inventory.

FieldWiring roll-up cards therefore expose permanent Controller links when Controller Inventory can resolve them safely.

Example:

```text
A/C CONTROLLER · UNIT ID 80
Controller: CTRL 1001 · CTB32
```

The `CTRL 1001 · CTB32` value links to:

```text
/fieldwiring/controllers?controller_id=1001
```

Controller Inventory accepts that deep link and opens the exact permanent Controller detail.

## Resolution rule

Permanent identity is never inferred from Network or Unit ID.

Resolution begins from the governed physical relationship:

```text
ref.controller
  -> ref.controller_display
      -> physical display_id
      -> optional wiring_source_display_id
```

The effective current wiring Display is:

```text
COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

Only after that relationship establishes the candidate physical Controller asset(s) may current programmed Network + UID range be used to distinguish which assigned A/C or Pixie controller applies to a current LOR wiring row.

This preserves the identity rule:

```text
controller_id = permanent physical identity
Network / UID = current programmed configuration
```

## Intentional duplicate addresses

Repeated Network/UID values remain legal.

When two or more assigned physical Controllers intentionally share the same current programmed address and therefore respond to the same wiring context, FieldWiring may show multiple permanent Controller links on that roll-up.

It must not collapse those Controllers into one asset merely because the address matches.

## E1.31 / DMX boundary

Controller Inventory does not yet contain a governed universe/output partition for every E1.31 physical-controller case.

When a Display has permanent Controller assignments but the exact E1.31/DMX roll-up cannot be mapped to one physical Controller without inference, FieldWiring shows:

```text
Assigned Controllers: CTRL ...
```

rather than claiming an exact controller-to-universe partition.

The presentation may identify all permanent Controllers assigned to that wiring Display, but it must not invent which one is `Controller 1`, `Controller 2`, or a specific universe range until that mapping is separately reviewed and stored.

## Controller label state

Controller Inventory now also exposes the existing `ref.controller` label state in the detail screen:

```text
label_required
print_label
label_print_count_cached
label_print_last_at_cached
```

This is read visibility only until the Manager maintenance workflow is enabled. Actual label-service handoff remains a separate integration with the established MSB label subsystem.

## Management boundary

The cross-link and label-state visibility do not make `fieldwiring_app` writable.

Manager create/update/assignment work remains governed by the Controller Inventory management workstream. Browser-native writes require an accepted authenticated Manager identity/write boundary; the read-only FieldWiring database role must not be broadened simply to expose edit controls.

## Regression coverage

Automated coverage:

```text
FieldWiring/Application/test_controller_fieldwiring_crosslinks.py
```

The tests verify:

- A/C permanent-controller matching uses assigned candidate + programmed Network/UID;
- Pixie rows resolve across contiguous programmed UID ranges;
- intentional duplicate addresses return multiple permanent Controllers;
- E1.31 multiple assignments remain assignment context rather than a false exact partition;
- FieldWiring loads the Controller cross-link assets;
- Controller Inventory accepts `controller_id` deep links;
- `print_label` and cached label state are visible in Controller detail.
