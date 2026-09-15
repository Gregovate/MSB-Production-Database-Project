# Setup and Deployment

| Document Control | Value |
|---|---|
| Document Type | Operator / User Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB volunteers, reviewers, managers, and Setup operators |
| Status | CURRENT |
| Last Reviewed | 2026-09-15 |

Open the protected Setup application at:

```text
https://my.sheboyganlights.org/setup/
```

Current shared session and client:

```text
2025 — Historical Verification
Client V0.3.13
```

The 2025 session uses real Production data. Start with [Review and Correct the 2025 Setup History](operatorSOP/Review_2025_Setup_History.md).

## Display / Container Material

Use **Uses Display / Container Material** only for reusable tasks that actually need current Displays for their Stage or real Scene. LOR remains authoritative for current Display membership.

If one material-bearing task owns the scope, material resolution remains automatic. If several material-bearing tasks share the same Stage/real-Scene scope, use **Display Ownership** so each resolved Display has one effective reusable task owner.

For large scopes, select the Display(s), choose the destination under **Move selected to**, and click **Move selected** instead of dragging across the full board. **Coverage complete** means every current resolved Display has an effective owner.

Display Ownership does not change LOR membership or the Display's current Container.

## Kit Boxes, Extra Materials, and Inventory

Use **Kit Boxes** to assign existing physical Kit Box Containers to reusable tasks. The same Kit Box may support multiple tasks. Task-to-Kit assignment is logistics context; it does not define the Kit's contents.

Reusable task detail now includes **Extra Materials Required by This Task**. Managers may maintain quantity, UOM, size/length/color, quantity qualifier, verification state, and notes. Expected source Containers are displayed separately from the task requirement.

Use the standalone protected inventory pages for physical Kit and T-Post work:

```text
https://my.sheboyganlights.org/setup/kit-inventory/
https://my.sheboyganlights.org/setup/t-post-inventory/
```

**Kit Inventory** shows expected Kit contents, physical on-hand counts, current reusable task assignments, current Displays stored in the Kit, and Unverified Items / Remainders. Expected quantity and physical on-hand are separate facts: editing expected contents never creates an inventory count, and recording inventory events never rewrites expected contents.

**T-Post Inventory** records physical T-Posts by the Container where they are intentionally stored. Shared/bulk stock is grouped separately from T-Posts stored with Kits or Displays. Storage location does not assign T-Posts to Displays, panels, Stages, Scenes, or Setup tasks; reusable task requirements remain separate.

Reconstructed procedure-derived values are intentionally `UNVERIFIED` or `NEEDS_REVIEW` until reviewed. Do not copy an expected/planning quantity into physical on-hand unless the stock was actually counted.

## Other Current Work

Managers may maintain reusable tasks, resources, prerequisites, crew/time/readiness information, Setup procedure context, Extra Material requirements, Kit expected contents/Remainders, and stock definitions where their access allows. Authorized inventory operators may record append-only physical inventory events.

Shift-drag remains the fast prerequisite gesture; ordinary drag remains task movement/reorder. The sticky **ACTIVE TASK** identity remains visible while long task detail is scrolled.

## Current Boundary

There is no 2026 Setup Session yet. The durable Extra Material / Kit Inventory / T-Post foundation and the one-time reconstruction are live. Final reusable Catalog acceptance and disposable 2026 seed proof remain before the real 2026 Session.

Pick List generation, staged release scheduling, Container/Display movement/scanning writes, and park-location execution evidence remain separate work.

## Related Documents

- [2025 review procedure](operatorSOP/Review_2025_Setup_History.md)
- [Setup operator procedures](operatorSOP/README.md)
- [Detailed Manager Review Guide](../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Engineering handoff](engineering/README.md)
- [Kit Inventory / T-Post Production Acceptance](../../../../../Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md)
- [Setup Assignment Layer V0.3.13 Production Acceptance](../../../../../Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md)
