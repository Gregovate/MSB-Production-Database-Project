# Review and Correct the 2025 Setup History

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | Production Database — Setup and Deployment |
| Task | Review and correct the 2025 Setup history and reusable Setup knowledge |
| Audience | Authorized Setup reviewers and managers |
| Status | CURRENT |
| Last Reviewed | 2026-09-18 |

Use the real 2025 Setup Session to preserve/correct 2025 history while improving reusable Setup knowledge before the 2026 Setup Session is created.

Open:

```text
https://my.sheboyganlights.org/setup/
2025 — Historical Verification
Client V0.3.14
```

Keep annual 2025 facts separate from reusable Setup knowledge.

## Material Review

Use **Uses Display / Container Material** only when the reusable task needs current LOR-derived Displays for its Stage or real Scene.

If one material-bearing task owns the scope, material resolution remains automatic. If several material-bearing tasks share the same Stage/real-Scene scope, use **Display Ownership** so every current resolved Display has one effective reusable task owner.

For large scopes, select Display(s), choose the destination under **Move selected to**, and click **Move selected**. A completed assignment shows **Coverage complete**.

Display Ownership does not change LOR membership or the Display's current Container.

## Kit Boxes

Use **Kit Boxes** when a reusable task requires a physical Kit Box. Search the existing physical Kit Box list, assign the appropriate box, review assigned names/IDs, and remove a wrong assignment directly. The same Kit Box may support multiple reusable tasks.

Expected Kit contents, Extra Materials, quantities/specifications, and expected source Containers are now live review workflows. Keep task requirement, expected source, expected Kit contents, and physical on-hand as separate facts.

## What Must Be Validated Before 2026

The final Catalog pass is now primarily a **work-step and prerequisite review**.

For each reusable task, confirm:

- the task represents real Setup work that MSB actually performs;
- the task is at the correct Park Infrastructure / Stage / real-Scene scope;
- duplicate, obsolete, reconstruction-only, or unnecessarily granular tasks are removed/deactivated as appropriate; and
- hard prerequisites are correct.

Do **not** create a separate task merely to represent a condition that must be true before work can begin.

Example:

~~~text
Not a separate Setup task:
City Approval to Lay Cords/Network

Reusable task:
Lay Cords/Network

Readiness:
Ensure grass cutting is complete before laying cords.
~~~

A readiness condition is scheduling context, not an independent work step, unless MSB itself must perform and complete distinct work to satisfy it.

## Planning Information Can Be Corrected Later

V0.3.14 allows Managers to correct planning information from the Scheduling Board before actual work exists. Therefore final Catalog verification does **not** need to wait for perfect values for:

- normal crew guidance;
- expected duration;
- physical effort;
- readiness condition;
- weather note; or
- completion point.

Enter those values now when they are known and supported. If they are still uncertain, leave them for planning/scheduling rather than inventing values or delaying verification of the task itself.

Expected duration remains reusable planning knowledge. Do not copy a one-off 2025 elapsed time into it unless the evidence supports that as the normal reusable expectation.

## Other Review Work

Correct only information supported by reliable evidence. Material/Kit/Resource relationships and published procedures remain reusable knowledge, but the launch-critical Catalog pass is task identity/scope plus prerequisite correctness.

Fast prerequisite entry remains Shift-drag; normal drag without Shift remains task movement/reorder.

Do not create fake records, fake Scenes, or fake tasks to work around missing planning information or readiness conditions.

## 2026 Gate

There is currently no 2026 Setup Session. Complete the reusable work-step/prerequisite review, then perform final Catalog acceptance and disposable 2026 seed proof before real 2026 Session creation. Crew/time/readiness planning details may continue to improve during scheduling before actual work exists.

## Related Documents

- [Setup operator procedures](README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup engineering handoff](../engineering/README.md)
