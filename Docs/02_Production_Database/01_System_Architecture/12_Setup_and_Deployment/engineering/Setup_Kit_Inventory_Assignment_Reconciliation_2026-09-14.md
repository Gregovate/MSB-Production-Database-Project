# Setup Kit Inventory Assignment Reconciliation — 2026-09-14

## Status

Current Production review confirms that all task-assignable Kit Boxes have explicit reusable Setup task assignments through `ref.setup_task_container_support` / `relationship_type='KIT'`.

The remaining unassigned `container_type_id=2` rows are not ordinary task Kits:

- Container 69 — Network Cable;
- Containers 123, 124, 125, 128 — shared `Display Spacers 21` stock;
- Container 129 — shared `Misc Size Spacers` stock.

These should not be forced into a task-owned KIT relationship merely to remove an `UNASSIGNED` status. Shared stock remains a source/allocation concern under #167.

## Reconciliation consequence

The old migration-043 phrase `sole current Stage Kit candidate` is no longer the preferred matching rule for reconstruction work.

Current assignment-driven precedence is:

1. Explicit current Container evidence in the procedure wins.
2. Current physical Container identity can itself prove a material family when the identity is explicit. Example: Container 60 is named `Elf Choir Kit includes spacers`; this supports one UNVERIFIED `Standard Panel Spacer` expected-content row while exact spacer size/count remain unknown.
3. If procedure evidence belongs to a current reusable task and that task has one assigned Kit, that Kit is the default expected-content candidate unless the material is known shared stock or another source is explicitly named.
4. If one task has multiple assigned Kits, do not duplicate material into every Kit. Use explicit Container/content evidence where available; otherwise keep source unresolved/reviewable.
5. If one Kit supports multiple reusable tasks, expected contents remain Container-level facts and may legitimately support all those tasks.
6. T-Posts and shared spacer stock remain separate physical sources and are not Kit contents merely because an assigned task requires them. This does not prohibit an explicitly evidenced Kit from having its own spacer/T-Post contents.
7. Resources/tools retain Resource Catalog authority even when physically stored in a Kit.
8. Current Display contents remain `ref.display.container_id` truth and are shown separately from Extra Material contents.

### Spacer review finding

Browser review on 2026-09-14 exposed an important distinction:

- **C060 Elf Choir Kit** — current Container description explicitly says the Kit includes spacers. Migration 047 therefore normalizes `Standard Panel Spacer` as expected Kit content with NULL quantity and UNVERIFIED state until physical inventory establishes size/count.
- **C061 Polar Bears & Sliding Penguins Kit** — no equivalent current Container/procedure evidence was found in the reviewed reconstruction set. Do not invent a spacer row merely because panel work may use shared spacers. Its non-Display contents remain a physical/review question.
- **C123/C124/C125/C128** remain shared standard-spacer stock and **C129** remains miscellaneous spacer stock. Kit-specific spacer evidence does not replace shared stock.

## Verification query

`Setup/Acceptance/setup_167_assigned_kit_inventory_coverage.sql` is the read-only coverage report for current Production or disposable review. It shows each assigned Kit with:

- current reusable task assignments;
- normalized expected Extra Material rows;
- procedure-derived reconstruction row count;
- durable Remainder / Unverified Items state;
- current physical Display contents;
- a coverage classification identifying assigned Kits that still have no reconstructed inventory evidence.

It also reports shared T-Post/spacer stock separately so those Containers are not confused with task Kits.

## Next reconciliation gate

Use the coverage report against current Production after all task-assignable Kits are assigned. For any assigned Kit classified `NO RECONSTRUCTED INVENTORY` or `REMAINDER ONLY`, return to the preserved procedure evidence and map supported inventory using the precedence above. Unknown contents remain reviewable rather than being guessed.
