# Extra Materials and Kit Inventory

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Setup and Deployment |
| Audience | Setup Managers, reviewers, Kit inventory operators |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-28 |
| Keywords | Extra Materials, Expected Source Containers, Kit Inventory, Expected, On Hand, Count Adjust, Edit Remove |

## Purpose

Use this procedure when correcting Extra Materials, deciding what belongs in a Kit, or counting what is physically on hand.

These are related facts, but they are **not the same thing**. Keeping them separate prevents one correction from silently changing something else.

## The Four Questions

### 1. What does the task need?

Use **Extra Materials Required by This Task**.

Examples include T-Posts, spacers, bungees, stakes, bases, ratchet straps, cribbing, or other physical material that belongs to or directly supports the installation.

A Procedure mention by itself does **not** make something an Extra Material.

Do not turn general work items into Extra Materials just because the Procedure names them. Examples include:

- hearing protection / ear plugs;
- fall protection;
- gloves;
- safety glasses;
- general tools;
- fuel;
- normal crew supplies.

Those belong in the appropriate Procedure, PPE, Equipment / Resources, or operating instructions.

If the task quantity, size, color, or other detail is not known, **do not guess**.

### 2. Where should the crew find it?

Use **Expected Source Containers** on the task.

Every new task Extra Material must have a source Container. The source answers:

> Where should the crew expect to find this material?

If you know the Container but do not know the quantity in that Container, record the source and leave the source quantity unknown/unverified. Do not invent a quantity merely to make the allocation look balanced.

Container search accepts the number or the human-readable Container label, such as:

- `145`
- `C145`
- `c145`
- `C030`

### 3. What should normally be in this Kit?

Open **Kit Inventory** and review **Expected Kit Contents**.

Use **Edit / Remove** when correcting what belongs in the Kit.

Examples:

- remove an item that was incorrectly reconstructed as Kit content;
- correct expected quantity or specification when the durable expectation is known;
- leave an uncertain item unverified rather than guessing.

**Edit / Remove does not record a physical count.**

If an item should not belong in the Kit, remove it from expected contents. Do not enter a count of zero just to make it disappear.

### 4. What is physically on hand right now?

Use **Count / Adjust** only when somebody actually counted or physically corrected stock.

This records durable inventory history.

Examples:

- initial physical count;
- count correction;
- actual quantity adjustment after a physical change.

**Do not use Count / Adjust to change what should belong in the Kit.**

Expected quantity and On Hand are different facts:

- **Expected** = what should normally be there.
- **On Hand** = what somebody physically observed/counts.

## Why There Are Separate Steps

The separation is intentional:

```text
Task Extra Material
    = what the job needs

Expected Source Container
    = where the crew should find it

Kit Expected Content
    = what should normally be in that physical Kit

Physical Inventory
    = what somebody actually counted
```

Changing one does not automatically prove the others should change.

For example, deleting a mistaken task requirement does not automatically delete an unrelated Kit-content row unless the system can prove they are the same authority.

## Common Examples

### Church Tree — Plywood

The Church plywood is represented as Displays stored in its Display Container, not as Extra Material in the Church Tree Kit.

Correct cleanup:

1. delete the bad Plywood task Extra Material requirement;
2. open Church Tree Kit C145;
3. use **Edit / Remove** on the stale Plywood expected-content row;
4. choose **Remove Expected Item**;
5. do **not** create an inventory count to remove it.

### Church Tree — Cribbing / Shim

If you know the cribbing is in C145 but do not know how many pieces are there:

- keep/record C145 as the Expected Source Container;
- leave source quantity blank;
- keep verification as Unverified or Needs Review;
- add a useful note if needed.

Do not invent a count.

### Northern Lights — Historical T-Post Authority

If Material Audit shows older authority that is actually correct, use the Manager restore action instead of moving source rows to a newly reconstructed requirement.

A restore keeps the existing source Containers attached to the restored requirement.

### Magic Igloo — Same Ratchet Straps Used More Than Once

The same physical ratchet straps can be used during more than one step of the Magic Igloo setup.

Repeated Procedure mentions do not mean there are multiple sets of straps.

Do not multiply physical stock or Pick List demand merely because the same reusable item is used at different points in the work.

## Reading Kit Inventory Task-Link Messages

- **Linked to task** — the material/source relationship is recorded and the compared details match.
- **Linked to task — details differ** — the source relationship is recorded, but task and Kit descriptions/specifications are not identical.
- **No task link recorded** — no active task/source relationship is recorded for that material in the Kit.

**Linked to task — details differ does not mean the source assignment failed.**

A Kit may legitimately contain more than the task needs. Example: a Kit can contain 3 T-Posts while the task requires a minimum of 2.

## Before You Save

Ask:

1. Am I changing what the task needs, where it comes from, what should be in the Kit, or what was physically counted?
2. Am I using the screen that matches that question?
3. Do I actually know this quantity/detail, or am I guessing?
4. Is this PPE/tool/equipment instead of Extra Material?
5. Is this the same reusable physical item being mentioned more than once?

If the answer is unclear, stop and flag it for review. **Unknown is better than invented authority.**

## Related Instructions

- [Setup Operator Procedure Index](README.md)
- [Setup Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup and Deployment](../README.md)
