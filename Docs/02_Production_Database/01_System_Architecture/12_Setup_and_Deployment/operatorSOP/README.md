# Setup and Deployment Operator Procedures

| Document Control | Value |
|---|---|
| Document Type | Operator Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB reviewers, managers, and Setup operators |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-15 |

Use this area for plain-English instructions for working in the Setup application. Engineering, database, service, permission, and deployment details belong in [`../engineering/`](../engineering/README.md).

## Current Application

```text
https://my.sheboyganlights.org/setup/
2025 — Historical Verification
Client V0.3.13
```

The 2025 review uses real Production data.

## Start Here

- [Review and Correct the 2025 Setup History](Review_2025_Setup_History.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)

## Display / Container Material

Use **Uses Display / Container Material** only for reusable tasks that actually need current Displays for their Stage or real Scene. LOR remains the source of current Display membership.

If one material-bearing task owns the scope, resolution remains automatic. If several material-bearing tasks share the same Stage/real-Scene scope, use **Display Ownership** so each resolved Display has one effective reusable task owner.

For normal-sized scopes, click, Ctrl/Cmd-click, or Shift-click to select Displays and drag them between task columns. For large scopes, select the Display(s), choose the destination under **Move selected to**, and click **Move selected**. **Coverage complete** means every current resolved Display has an effective owner.

Display Ownership does not change LOR membership or the Display's normal Container.

## Task Extra Materials

Selected reusable tasks now show **Extra Materials Required by This Task**. Managers may add/edit/remove a requirement and retain required quantity, UOM, size, length, color, quantity qualifier, verification state, and notes.

A task requirement answers **what the work requires**. It is separate from the Kit/Container where something is normally stored and separate from the physical count currently on hand.

If a migrated value says `UNVERIFIED` or `NEEDS_REVIEW`, treat it as reconstruction evidence that still needs human review. Unknown quantity/specification stays unknown; do not guess.

## Kit Boxes and Kit Inventory

Use **Kit Boxes** in task detail to assign existing physical Kit Box Containers to reusable tasks. The same Kit Box may support multiple tasks. Assigned Kit names/IDs are shown in Material / Logistics and can be removed directly.

Open **Kit Inventory** from Setup or at:

```text
https://my.sheboyganlights.org/setup/kit-inventory/
```

The default Kit Inventory view is for review: find a Kit, then read its Setup-task count, Display count, expected-item count, counted-item count, and Remainder state.

- **Expected Kit Contents** = what should normally be in the Kit.
- **On Hand** = physical balance created only by inventory events.
- **Setup task assignment** = why the physical Kit is needed; it is not a content list.
- **Displays stored in this Kit** = current `Display -> Container` truth; it is read-only here.
- **Unverified Items / Remainders** = unresolved procedure/reconstruction notes; they are not automatically confirmed inventory.

Managers may open **Add expected item** or **Edit** only when the expected-content definition needs work. **Count / Adjust** opens the physical-inventory panel for the selected expected row. Do not use expected quantity as a physical count unless the item was actually counted.

## T-Post Inventory

Open **T-Post Inventory** from Kit Inventory or at:

```text
https://my.sheboyganlights.org/setup/t-post-inventory/
```

Choose the physical Container being inventoried. The list separates **Shared / Bulk T-Post Stock** from **T-Posts Stored With Kits / Displays**.

Each row describes one physical T-Post variant in that Container. **Planning / Known Qty** is reference evidence, not the count. **Physical On Hand** comes only from recorded inventory events.

Managers use **Add new T-Post row** / **Edit stock definition** only when the stored-stock definition itself is wrong or missing. Use **Count physical stock** for an actual count or later adjustment. Initial Count establishes the first physical balance; later events are signed changes such as receipt, return, correction, loss, consumption, transfer in/out, or other documented change.

T-Post storage location does not create a task requirement. Task/installation requirements remain in reusable task Extra Materials.

## Resources

Search for an existing resource before creating anything new. Task-specific quantity, Required-vs-Preferred, and task notes stay separate from reusable Resource Catalog identity and notes.

Use **Manage Resource Catalog** to correct the reusable resource entry itself.

## Prerequisites

Hold **Shift** before left-button-down on the later/dependent task, drag it onto the task that must happen first, and release. Normal drag without Shift still moves/reorders tasks.

Open task detail for the canonical prerequisite list and manual Add / Up / Down / Remove controls.

## Important Boundaries

- 2025 review uses real Production data.
- Reusable Task changes may affect future seasons.
- Display Ownership, Kit assignment, task Extra Materials, expected Kit contents, resources, and prerequisites are reusable knowledge.
- Physical inventory events are separate append-only operational facts.
- There is no 2026 Setup Session yet.
- Pick List generation, staged release scheduling, Container/Display movement/scanning writes, and park-location execution evidence are not yet live.
- Do not create fake records merely to test the UI.

## Related Documents

- [Setup and Deployment](../README.md)
- [Review and Correct the 2025 Setup History](Review_2025_Setup_History.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Kit Inventory / T-Post Production Acceptance](../../../../../Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md)
- [Engineering handoff](../engineering/README.md)
