# Setup Session Operator Procedures

This folder contains operator/Manager procedures for the live Setup Session application.

## Current State

```text
https://my.sheboyganlights.org/setup/
2025 — Historical Verification
Client V0.3.13
```

The 2025 shared review uses real Production data. There is currently no 2026 Setup Session.

## Start Here

- [Setup Session Manager Review Guide](Setup_Session_Manager_Review_Guide.md)
- [Setup system/operator portal](../../01_System_Architecture/12_Setup_and_Deployment/README.md)

## Material Applicability and Ownership

Reusable tasks use **Uses Display / Container Material** to participate in the LOR-derived material resolver.

When one material-bearing task owns the scope, material resolution remains automatic. When several material-bearing tasks share the same Stage/real-Scene scope, use **Display Ownership** so each resolved Display has one effective reusable task owner.

For large scopes, use **Move selected to** when drag would require scrolling across a very tall board. Ownership does not change LOR membership or the Display's current Container.

Use **Kit Boxes** separately to assign existing physical Kit Box Containers to reusable tasks. The same Kit Box may support multiple tasks.

## Extra Materials

Reusable task detail includes **Extra Materials Required by This Task**. The task requirement records what the work requires, including quantity/specification and review state where known. Expected source Containers are separate from that requirement.

Migrated reconstruction rows are intentionally reviewable. `UNVERIFIED` and `NEEDS_REVIEW` mean the value is not yet accepted field truth.

## Kit Inventory

Open:

```text
https://my.sheboyganlights.org/setup/kit-inventory/
```

Use Kit Inventory to review all physical Kit Boxes, including Assigned / Unassigned filters. Expected Kit contents, physical on-hand, task assignment context, current Displays stored in the Kit, and Remainders are shown separately.

Expected contents are not counts. Physical on-hand changes only through inventory events. Remainders preserve unresolved items/questions and must not be treated as confirmed inventory without review.

## T-Post Inventory

Open:

```text
https://my.sheboyganlights.org/setup/t-post-inventory/
```

T-Post Inventory records physical T-Post stock by the Container where it is actually stored. Shared/bulk stock and T-Posts stored with Kits/Displays are separate groups. Planning/known quantity is not physical on-hand. Actual stock changes only through inventory events.

Storage location does not assign T-Posts to a Setup task; reusable task requirements remain separate task/installation facts.

## Session-Year Safety

The selected annual Setup Session controls allowable operational dates. Audit timestamps remain real current timestamps.

Only a Setup Administrator may create/manage an annual Setup Session or promote annual planned order into the reusable future baseline.

There is currently no 2026 Setup Session.

## Current Implementation Boundary

Production-operational now includes 2025 historical review, reusable task maintenance, Stage/real-Scene organization, LOR-derived Display/Container resolution, Display Ownership, physical Kit Box assignment, structured task Extra Materials, expected Kit contents/Remainders, Kit Inventory, T-Post inventory, resource/effort/prerequisite maintenance, Procedure context, and protected browser access.

Still incomplete/separate work includes final reusable Catalog acceptance/disposable 2026 seed proof, structured readiness gating, Pick List generation/staged release scheduling, Container/Display movement/scanning writes, and park-location execution evidence.
